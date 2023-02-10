import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/_down4_dart_utils.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:firebase_database/firebase_database.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'data_objects.dart';
import 'bsv/types.dart';
import 'bsv/wallet.dart';

// import '../main.dart' as main;

final g = Singletons.instance;
final db = FirebaseDatabase.instance.ref();
// var _fs = FirebaseFirestore.instance;
final _st = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _st_node = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

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

String _mediaPath(String mediaID, {bool isThumbnail = false}) =>
    "${g.boxes.docPath}/$mediaID${isThumbnail ? "-TN" : ""}";

Future<void> _deleteMediaFile(String path) async {
  try {
    await File(path).delete();
  } on PathNotFoundException catch (e) {
    print("Cannot delete, this file is external: $e");
  } catch (e) {
    print("Cannot delete this file for this reason: $e");
  }
}

String messagePushId() => db.child("Messages").push().key!;

Future<MessageMedia?> downloadAndWriteMedia(
  String mediaID, {
  bool isNodeMedia = false,
}) async {
  final mediaRef = isNodeMedia ? _st_node.ref(mediaID) : _st.ref(mediaID);
  try {
    final futureMediaData = mediaRef.getData(31457280); // 30mib
    final fullMetadata = await mediaRef.getMetadata();
    final customMetadata = fullMetadata.customMetadata as Map<String, String>;
    final mediaMetadata = MediaMetadata.fromJson(customMetadata);
    final path = "${g.boxes.docPath}/$mediaID";
    final mediaData = await futureMediaData;
    if (mediaData != null) {
      await File(path).writeAsBytes(mediaData);
    }
    return MessageMedia(id: mediaID, path: path, metadata: mediaMetadata);
  } catch (e) {
    print("Error downloading mediaID: $mediaID, isNode: $isNodeMedia\n$e");
    return null;
  }
}

// Future<MediaMetadata?> _downloadMediaMetadata(String mediaID) async {
//   try {
//     final fullMetadata = await _st.ref(mediaID).getMetadata();
//     final jsonMetadata = fullMetadata.customMetadata as Map<String, String>;
//     return MediaMetadata.fromJson(jsonMetadata);
//   } catch (e) {
//     return null;
//   }
// }

Future<bool> uploadOrUpdateMedia(
  MessageMedia media, {
  bool skipCheck = false, // usually for camera uploads
}) async {
  if (media.file == null) return false;
  final mediaRef = _st.ref(media.id);
  if (skipCheck) {
    try {
      await mediaRef.putFile(
        media.file!,
        SettableMetadata(customMetadata: media.metadata.toJson()),
      );
      return true;
    } on FirebaseException catch (e) {
      print("Error uploading file $e");
      return false;
    }
  } else {
    try {
      print("Checking if media ${media.id} is already on firebase!");
      final metadata = (await mediaRef.getMetadata());
      final down4Metadata = MediaMetadata.fromJson(metadata.customMetadata!);
      if (down4Metadata.timestamp.shouldBeUpdated) {
        final newTimeStamp = timeStamp();
        if (newTimeStamp > down4Metadata.timestamp) {
          down4Metadata.timestamp = newTimeStamp;
          await mediaRef.updateMetadata(
            SettableMetadata(customMetadata: down4Metadata.toJson()),
          );
          print("Updated the metadata");
          return true;
        }
      }
      print("No need to update the metadata right away!");
      return true;
    } catch (e) {
      // TODO, find the actual exception we are looking for, docs aren't clear
      // If there's an exception, it should mean that there is no media, so we
      // do the full upload
      try {
        media.metadata.timestamp = timeStamp();
        await mediaRef.putFile(media.file!,
            SettableMetadata(customMetadata: media.metadata.toJson()));
        return true;
      } on FirebaseException catch (e) {
        print("Error uploading file $e");
        return false;
      }
    }
  }
}

Future<File> writeMedia({
  required Uint8List mediaData,
  required String mediaID,
  bool isThumbnail = false,
}) async =>
    File(_mediaPath(mediaID, isThumbnail: isThumbnail)).writeAsBytes(mediaData);

Future<File> copyMedia({
  required String fromPath,
  required String mediaID,
  bool isThumbnail = false,
}) async =>
    File(fromPath).copy(_mediaPath(mediaID, isThumbnail: isThumbnail));

Future<File?> makeThumbnail({
  required String videoPath,
  required String mediaID,
}) async {
  final tn = await VideoThumbnail.thumbnailData(video: videoPath, quality: 90);
  if (tn != null) {
    return writeMedia(mediaData: tn, mediaID: mediaID, isThumbnail: true);
  }
  return null;
}

extension ExchangeRateSave on ExchangeRate {
  void save() {
    g.boxes.personal.put("exchangeRate", jsonEncode(this));
  }

  static ExchangeRate load() {
    final jsonEncoded = g.boxes.personal.get("exchangeRate");
    if (jsonEncoded == null) return ExchangeRate(lastUpdate: 0, rate: 0);
    return ExchangeRate.fromJson(jsonDecode(jsonEncoded));
  }
}

extension Getters on Identifier {
  MessageMedia? getLocalMessageMedia() {
    final String? jsonEncoded = g.boxes.medias.get(this);
    if (jsonEncoded == null) return null;
    return MessageMedia.fromJson(jsonDecode(jsonEncoded));
  }

  Message? getLocalMessage() {
    final String? jsonEncoded = g.boxes.messages.get(this);
    if (jsonEncoded == null) return null;
    return Message.fromJson(jsonDecode(jsonEncoded));
  }

  BaseNode? getLocalNode() {
    final String? jsonEncoded = g.boxes.nodes.get(this);
    if (jsonEncoded == null) return null;
    return BaseNode.fromJson(jsonDecode(jsonEncoded));
  }

  Future<void> deleteLocalNode() async {
    return g.boxes.nodes.delete(this);
  }
}

extension MessageSave on Message {
  Future<void> onReceipt() async {
    await save();
    if (mediaID != null) {
      MessageMedia? media = mediaID?.getLocalMessageMedia();
      media ??= await downloadAndWriteMedia(mediaID!);
      if (media != null && media.extension.isVideoExtension()) {
        // we generate a thumbnail
        final tn =
            await VideoThumbnail.thumbnailData(video: media.path, quality: 90);
        if (tn != null) {
          final f = await writeMedia(
              mediaData: tn, mediaID: mediaID!, isThumbnail: true);
          media.thumbnail = f.path;
        }
      }

      media
        ?..references.add(id)
        ..save();
    }
    return;
  }

  Future<void> save() async {
    return g.boxes.messages.put(id, jsonEncode(toJson(toLocal: true)));
  }

  Future<void> delete() async {
    final MessageMedia? media = mediaID?.getLocalMessageMedia();
    if (media != null) {
      media.references.remove(id);
      media.delete();
    }
    await g.boxes.messages.delete(id);
    return;
  }
}

extension NodeSave on BaseNode {
  void save() {
    if (this is Self) {
      g.boxes.personal.put("self", jsonEncode(toJson(toLocal: true)));
    } else {
      g.boxes.nodes.put(id, jsonEncode(toJson(toLocal: true)));
    }
  }

  void delete() {
    var node = this;
    if (node is ChatableNode && node is! Self) {
      for (var messageID in node.messages) {
        var msg = messageID.getLocalMessage();
        if (msg != null && !msg.isSaved) msg.delete();
      }
      g.boxes.nodes.delete(id);
    }
  }
}

extension MediaSave on MessageMedia {
  Future<void> save() async {
    return g.boxes.medias.put(id, jsonEncode(toJson(toLocal: true)));
  }

  Future<void> delete() async {
    if (references.isEmpty && !isSaved) {
      print("References are empty, deleting the file!");
      g.boxes.medias.delete(id);
      _deleteMediaFile(path);
      if (thumbnail != null) {
        _deleteMediaFile(thumbnail!);
      }
    }
    return;
  }
}

extension PaymentSave on Down4Payment {
  Future<void> save() => g.boxes.payments.put(id, jsonEncode(this));
}

extension WalletSave on Wallet {
  void save() {
    g.boxes.personal.put("wallet", jsonEncode(this));
  }

  static Wallet load() {
    final asJson = g.boxes.personal.get("wallet");
    return Wallet.fromJson(jsonDecode(asJson));
  }
}

extension SelfSave on Self {
  void save() {
    // this will be split so we don't save the whole thing everytime
    g.boxes.personal.put("self", jsonEncode(toJson(toLocal: true)));
  }

  static Self load() {
    // this will be remade so we load many different parts to make the self
    final asJson = jsonDecode(g.boxes.personal.get("self"));
    return BaseNode.fromJson(asJson) as Self;
  }

  static bool notYetInitialized() {
    return g.boxes.personal.get("self") == null;
  }
}

class Boxes {
  late String docPath, tempPath;
  Box personal, nodes, messages, medias, messageQueue, bills, payments;
  Boxes._()
      : medias = Hive.box("Medias"),
        personal = Hive.box("Personal"),
        nodes = Hive.box("Nodes"),
        messages = Hive.box("Messages"),
        messageQueue = Hive.box("MessageQueue"),
        bills = Hive.box("Bills"),
        payments = Hive.box("Payments");
}

class Sizes {
  Sizes._()
      : h = 0,
        w = 0,
        fullHeight = 0,
        headerHeight = 0;
  double h;
  double w;
  double fullHeight;
  double headerHeight;
  Size get fullSize => Size(w, fullAspectRatio);
  Size get paddedSize => Size(w, h);
  double get viewPaddingHeight => fullHeight - h;
  double get fullAspectRatio => w / fullHeight;
  double get paddedAspectRatio => w / h;
}

class Singletons {
  static final Singletons _instance = Singletons();
  static Singletons get instance => _instance;

  Self? _self;
  Wallet? _wallet;
  Sizes? _sizes;
  Boxes? _boxes;
  ExchangeRate? _exchangeRate;
  late List<CameraDescription> cameras;

  Self get self => _self ??= SelfSave.load();
  Wallet get wallet => _wallet ??= WalletSave.load();
  Boxes get boxes => _boxes ??= Boxes._();
  Sizes get sizes => _sizes ??= Sizes._();
  ExchangeRate get exchangeRate => _exchangeRate ??= ExchangeRateSave.load();

  bool get notYetInitialized => SelfSave.notYetInitialized();

  void initWallet(Uint8List s1, Uint8List s2) {
    _wallet = Wallet.fromSeed(s1, s2)..save();
  }

  void initSelf(Identifier id, NodeMedia media, Down4Keys neuter, String name,
      String? lastName) {
    _self = Self(
      id: id,
      media: media,
      firstName: name,
      lastName: lastName,
      neuter: neuter,
      images: {},
      videos: {},
      nfts: {},
      children: {},
      messages: {},
      snips: {},
    )..save();
  }
}
