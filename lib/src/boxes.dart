import 'dart:convert';
import 'dart:io';

import 'package:down4/src/down4_utility.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
// import 'package:sqflite/sql.dart' as sql;

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'data_objects.dart';
import 'web_requests.dart' as r;
import 'bsv/types.dart';
import 'bsv/wallet.dart';

import '../main.dart' as main;

const golden = 1.618;

var b = Boxes.instance;
var db = FirebaseDatabase.instance.ref();
var fs = FirebaseFirestore.instance;
var st = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
var st_node = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

class ButtonKeys {
  final List<GlobalKey> topButtonKeys;
  final List<GlobalKey> bottomButtonKeys;
  ButtonKeys._()
      : topButtonKeys = [
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
        ],
        bottomButtonKeys = [
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
        ];

  static ButtonKeys? _instance;
  static ButtonKeys get instance => _instance ??= ButtonKeys._();
}

String mediaPath(String mediaID) => "${b.dirPath}/$mediaID";

Future<void> deleteMediaFile(String mediaID) async {
  try {
    File(mediaPath(mediaID)).delete();
  } catch (_) {}
}

String messagePushId() => db.child("Messages").push().key!;

Future<MessageMedia?> getMessageMediaFromEverywhere(Identifier mediaID) async {
  final String? jsonEncodedMedia = b.medias.get(mediaID);
  if (jsonEncodedMedia != null) {
    return MessageMedia.fromJson(jsonDecode(jsonEncodedMedia));
  }
  return downloadAndWriteMedia(mediaID) as Future<MessageMedia?>;
}

Future<List<BaseNode>> getNodesFromEverywhere(List<Identifier> ids) async {
  final locals = ids.where((id) => b.home.containsKey(id)).toList();
  final externals = ids.toSet().difference(locals.toSet()).toList();
  var externalNodes = r.getNodes(externals);
  List<BaseNode> localNodes = [];
  for (final localNodeID in locals) {
    localNodes.add(b.loadNode(localNodeID));
  }
  return localNodes + (await externalNodes ?? <BaseNode>[]);
}

Future<Media?> downloadAndWriteMedia(
  String mediaID, {
  bool isNodeMedia = false,
}) async {
  final mediaRef = isNodeMedia ? st_node.ref(mediaID) : st.ref(mediaID);
  try {
    final futureMediaData = mediaRef.getData();
    final fullMetadata = await mediaRef.getMetadata();
    final customMetadata = fullMetadata.customMetadata as Map<String, String>;
    final mediaMetadata = MediaMetadata.fromJson(customMetadata);

    final path = "${b.dirPath}/$mediaID";

    final mediaData = await futureMediaData;
    if (mediaData != null) {
      File(path).writeAsBytes(mediaData);
    }
    return isNodeMedia
        ? NodeMedia(id: mediaID, path: path, metadata: mediaMetadata)
        : MessageMedia(id: mediaID, path: path, metadata: mediaMetadata);
  } catch (e) {
    return null;
  }
}

Future<MediaMetadata?> downloadMediaMetadata(String mediaID) async {
  try {
    final fullMetadata = await st.ref(mediaID).getMetadata();
    final jsonMetadata = fullMetadata.customMetadata as Map<String, String>;
    return MediaMetadata.fromJson(jsonMetadata);
  } catch (e) {
    return null;
  }
}

Future<void> uploadOrUpdateMedia(
  Media media, {
  bool skipCheck = false, // usually for camera uploads
}) async {
  if (media.path == null) return;
  final mediaRef = st.ref(media.id);
  if (skipCheck) {
    mediaRef.putFile(
      File(media.path!),
      SettableMetadata(customMetadata: media.metadata.toJson()),
    );
  } else {
    try {
      final metadata = (await mediaRef.getMetadata());
      final down4Metadata = MediaMetadata.fromJson(metadata.customMetadata!);
      if (down4Metadata.timestamp.shouldBeUpdated) {
        final newTimeStamp = timeStamp();
        if (newTimeStamp > down4Metadata.timestamp) {
          mediaRef.updateMetadata(
            SettableMetadata(
              customMetadata:
                  down4Metadata.updatedTimestamp(timeStamp()).toJson(),
            ),
          );
        }
      }
    } catch (e) {
      // TODO, find the actual exception we are looking for, docs aren't clear
      // If there's an exception, it should mean that there is no media, so we
      // do the full upload
      mediaRef.putFile(
        File(media.path!),
        SettableMetadata(
          customMetadata: media.metadata.updatedTimestamp(timeStamp()).toJson(),
        ),
      );
    }
  }
}

// void writeMedia({
//   required Uint8List data,
//   required String id,
//   bool temp = false,
// }) async {
//   if (temp) {
//     File("$temporaryPath/$id").writeAsBytesSync(data);
//   } else {
//     File("$documentPath/$id").writeAsBytesSync(data);
//   }
// }

extension Getters on Identifier {
  MessageMedia? getMessageMedia() {
    final String? jsonEncoded = b.medias.get(this);
    if (jsonEncoded == null) return null;
    return MessageMedia.fromJson(jsonDecode(jsonEncoded));
  }

  Message? getMessage() {
    final String? jsonEncoded = b.medias.get(this);
    if (jsonEncoded == null) return null;
    return Message.fromJson(jsonDecode(jsonEncoded));
  }

  BaseNode? getNode() {
    final String? jsonEncoded = b.medias.get(this);
    if (jsonEncoded == null) return null;
    return BaseNode.fromJson(jsonDecode(jsonEncoded));
  }
}

extension MessageSave on Message {
  Future<void> onReceipt() async {
    save();
    if (mediaID != null) {
      MessageMedia? localMedia = mediaID?.getMessageMedia();
      if (localMedia == null) {
        // try and download it
        (await downloadAndWriteMedia(mediaID!) as MessageMedia?)
          ?..references.add(id)
          ..save();
      } else {
        localMedia
          ..references.add(id)
          ..save();
      }
    }
  }

  Future<void> save() async {
    b.messages.put(id, jsonEncode(toJson(toLocal: true)));
  }

  Future<void> delete() async {
    final MessageMedia? media = mediaID?.getMessageMedia();
    if (media != null) {
      media.references.remove(id);
      if (media.references.isEmpty && !media.isSaved) {
        b.medias.delete(media.id);
        deleteMediaFile(media.id);
      }
    }
    b.messages.delete(id);
  }
}

extension NodeSave on BaseNode {
  Future<void> save({bool isSelf = false}) => isSelf
      ? b.user.put(id, jsonEncode(this))
      : b.home.put(id, jsonEncode(this));
}

extension MediaSave on MessageMedia {
  void save() {
    b.medias.put(id, jsonEncode(toJson(toLocal: true)));
  }
}

extension PaymentSave on Down4Payment {
  Future<void> save() =>
      b.payments.put(id, jsonEncode(toJson(withImages: true)));
}

extension WalletSave on Wallet {
  Future<void> save() => b.user.put("wallet", jsonEncode(this));
}

class Boxes {
  static Boxes? _instance;
  // List<String> fileIDs;
  String dirPath;
  Box
      // images,
      //     videos,
      user,
      imageIDs,
      videoIDs,
      nftIDs,
      // reactions,
      home,
      messages,
      medias,
      messageQueue,
      bills,
      payments;
  // savedMessages,
  // savedMessageMedias,
  // messageMedias,
  // snipMedias;
  // messageImages,
  // messageVideos,
  // snipImages,
  // snipVideos;
  Boxes()
      : dirPath = main.docDirPath,
        imageIDs = Hive.box("ImageIDs"),
        videoIDs = Hive.box("VideoIDs"),
        nftIDs = Hive.box("NftIDs"),
        medias = Hive.box("Medias"),

        // fileIDs = [],
        user = Hive.box("User"),
        // images = Hive.box("Images"),
        // videos = Hive.box("Videos"),
        home = Hive.box("Home"),
        // reactions = Hive.box("Reactions"),
        messages = Hive.box("Messages"),
        messageQueue = Hive.box("MessageQueue"),
        bills = Hive.box("Bills"),
        payments = Hive.box("Payments");
  // savedMessages = Hive.box("SavedMessages"),
  // snipMedias = Hive.box('SnipMedias'),
  // savedMessageMedias = Hive.box('SavedMessageMedias'),
  // snipImages = Hive.box("SnipImages"),
  // snipVideos = Hive.box("SnipVideos"),
  // messageMedias = Hive.box('MessageMedias');
  // messageImages = Hive.box("MessageImages"),
  // messageVideos = Hive.box("MessageVideos");

  // File writeMediaToFile(Down4Media m) {
  //   var f = File(dirPath + "/" + m.id);
  //   f.writeAsBytes(m.data);
  //   return f;
  // }

  // String writeToDocs({required String cachedPath, required String mediaID}) {
  //   var f = File("$documentPath/$mediaID");
  //   final data = File(cachedPath).readAsBytesSync();
  //   f.writeAsBytesSync(data);
  //   return f.path;
  // }

  void saveImage(Media im) {
    images.put(im.id, jsonEncode(im));
  }

  MessageMedia loadSavedImage(Identifier id) {
    return MessageMedia.fromJson(jsonDecode(images.get(id)));
  }

  void deleteSavedImage(Identifier id) {
    try {
      File("$dirPath/$id").delete();
    } catch (_) {}
    images.delete(id);
  }

  void saveVideo(Media im) {
    videos.put(im.id, jsonEncode(im));
  }

  MessageMedia loadSavedVideo(Identifier id) {
    return MessageMedia.fromJson(jsonDecode(videos.get(id)));
  }

  ExchangeRate loadExchangeRate() {
    final rate = user.get("exchangeRate");
    if (rate == null) return ExchangeRate(lastUpdate: 0, rate: 0.0);
    return ExchangeRate.fromJson(jsonDecode(rate));
  }

  void saveExchangeRate(ExchangeRate exchangeRate) {
    user.put("exchangeRate", jsonEncode(exchangeRate));
  }

  void deleteVideo(Identifier id) {
    videos.delete(id);
  }

  void saveSnip(Media snip) {
    snipMedias.put(snip.id, jsonEncode(snip));
  }

  Media loadSnip(Identifier id) {
    return MessageMedia.fromJson(jsonDecode(snipMedias.get(id)));
  }

  // void deleteSnip(Identifier id) {
  //   snipImages.delete(id);
  // }

  void saveUser(User u) {
    user.put("user", jsonEncode(u));
  }

  User loadUser() {
    return BaseNode.fromJson(jsonDecode(user.get("user"))) as User;
  }

  void saveWallet(Wallet w) {
    user.put("wallet", jsonEncode(w));
  }

  Wallet loadWallet() {
    return Wallet.fromJson(jsonDecode(user.get("wallet")));
  }

  void saveNode(BaseNode p) {
    home.put(p.id, jsonEncode(p));
  }

  BaseNode loadNode(Identifier id) {
    return BaseNode.fromJson(jsonDecode(home.get(id)));
  }

  void deleteNode(Identifier id) {
    final node = loadNode(id);
    if (node is ChatableNode) {
      for (final msgID in node.messages) {
        messages.delete(msgID);
      }
    }
    home.delete(id);
  }

  void saveMessage(Message msg) {
    messages.put(msg.id, jsonEncode(msg));
  }

  Message? loadMessage(Identifier id) {
    var msg = messages.get(id);
    if (msg is! String) return null;
    var msgJson = jsonDecode(messages.get(id));
    if (msgJson == null) return null;
    return Message.fromJson(msgJson);
  }

  // void deleteMessage(Identifier id) {
  //   final msgJson = jsonDecode(messages.get(id));
  //   final mediaID = msgJson["m"];
  //   if (mediaID != null) {
  //     messageImages.delete(mediaID);
  //     messageVideos.delete(mediaID);
  //     if (!images.keys.contains(mediaID) || !videos.keys.contains(mediaID)) {
  //       try {
  //         File("$dirPath/$mediaID").delete();
  //       } catch (_) {}
  //     }
  //   }
  //   messages.delete(id);
  // }

  // bool mediaIsLocal(Identifier mediaID) {
  //   final isSavedImage = images.containsKey(mediaID);
  //   final isSavedVideo = videos.containsKey(mediaID);
  //   final isMessageMedia = messageImages.containsKey(mediaID);
  //   return isSavedImage || isSavedVideo || isMessageMedia;
  // }

  // Media? loadMessageMediaFromLocal(Identifier mediaID) {
  //   final isSavedImage = images.containsKey(mediaID);
  //   if (isSavedImage) {
  //     return MessageMedia.fromJson(jsonDecode(images.get(mediaID)));
  //   } else {
  //     final isMessageMedia = messageImages.containsKey(mediaID);
  //     if (isMessageMedia) {
  //       return MessageMedia.fromJson(jsonDecode(messageImages.get(mediaID)));
  //     } else {
  //       final isSavedVideo = videos.containsKey(mediaID);
  //       if (isSavedVideo) {
  //         return MessageMedia.fromJson(jsonDecode(videos.get(mediaID)));
  //       }
  //     }
  //   }
  //   return null;
  // }

  static Boxes get instance => _instance ??= Boxes();
}

class Sizes {
  static double h = 0;
  static double w = 0;
  static double fullHeight = 0;
  static double headerHeight = 0;
  static Size get fullSize => Size(w, fullAspectRatio);
  static Size get paddedSize => Size(w, h);
  static double get viewPaddingHeight => fullHeight - h;
  static double get fullAspectRatio => w / fullHeight;
  static double get paddedAspectRatio => w / h;
}

class Sizes2 {
  Sizes2._()
      : w = 0,
        h = 0;
  double w, h;
  static Sizes2? _instance;
  Sizes2 get instance => _instance ??= Sizes2._();
}
