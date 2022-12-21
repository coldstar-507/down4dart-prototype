import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import '../main.dart' as main;
import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'data_objects.dart';
import 'web_requests.dart' as r;
import 'bsv/types.dart';
import 'bsv/wallet.dart';

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

String messagePushId() => db.child("Messages").push().key!;

Future<Down4Media?> getMessageMediaFromEverywhere(Identifier mediaID) async {
  if (b.messageMedias.containsKey(mediaID)) {
    return Down4Media.fromJson(jsonDecode(b.messageMedias.get(mediaID)));
  } else if (b.images.containsKey(mediaID)) {
    return Down4Media.fromJson(jsonDecode(b.images.get(mediaID)));
  } else if (b.videos.containsKey(mediaID)) {
    return Down4Media.fromJson(jsonDecode(b.videos.get(mediaID)));
  } else {
    final media = await r.getMessageMedia(mediaID);
    if (media != null) media.save();
    return media;
  }
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

Future<Down4Media?> getMessageMediaFromDB(Identifier mediaID) async {
  var ref = st.ref(mediaID);
  var fmd = ref.getMetadata();
  var fd = ref.getData();

  var md = (await fmd).customMetadata;
  var d = (await fd);
  if (md != null && d != null) {
    return Down4Media(
      id: mediaID,
      metadata: MediaMetadata.fromJson(md),
      data: d,
    );
  }
  return null;
}

extension MessageSave on Down4Message {
  Future<void> save() =>
      b.messages.put(id, jsonEncode(toJson(withReadStatus: true)));
}

extension NodeSave on BaseNode {
  Future<void> save({bool isSelf = false}) => isSelf
      ? b.user.put(id, jsonEncode(this))
      : b.home.put(id, jsonEncode(this));
  Future<void> saveUser() => b.user.put(id, jsonEncode(this));
}

extension MediaSave on Down4Media {
  void writeFile() {
    var f = File("${b.dirPath}/$id");
    f.writeAsBytesSync(data);
    file = f;
  }

  Future<void> save({bool toPersonal = false, bool toSnips = false}) {
    if (!toPersonal) {
      return b.messageMedias.put(id, jsonEncode(this));
    } else if (toSnips) {
      return b.snips.put(id, jsonEncode(this));
    } else {
      if (metadata.isVideo) {
        return b.videos.put(id, jsonEncode(this));
      } else {
        return b.images.put(id, jsonEncode(this));
      }
    }
  }
}

extension PaymentSave on Down4Payment {
  Future<void> save() => b.payments.put(id, jsonEncode(this));
}

extension WalletSave on Wallet {
  Future<void> save() => b.user.put("wallet", jsonEncode(this));
}

class Boxes {
  static Boxes? _instance;
  List<String> fileIDs;
  String dirPath;
  Box images,
      videos,
      user,
      reactions,
      home,
      messages,
      messageQueue,
      bills,
      payments,
      savedMessages,
      messageMedias,
      snips;
  Boxes()
      : dirPath = main.docDirPath,
        fileIDs = [],
        user = Hive.box("User"),
        images = Hive.box("Images"),
        videos = Hive.box("Videos"),
        home = Hive.box("Home"),
        reactions = Hive.box("Reactions"),
        messages = Hive.box("Messages"),
        messageQueue = Hive.box("MessageQueue"),
        bills = Hive.box("Bills"),
        payments = Hive.box("Payments"),
        savedMessages = Hive.box("SavedMessages"),
        snips = Hive.box("Snips"),
        messageMedias = Hive.box("MessageMedias");

  File writeMediaToFile(Down4Media m) {
    var f = File(dirPath + "/" + m.id);
    f.writeAsBytes(m.data);
    return f;
  }

  void saveImage(Down4Media im) {
    images.put(im.id, jsonEncode(im));
  }

  Down4Media loadSavedImage(Identifier id) {
    return Down4Media.fromJson(jsonDecode(images.get(id)));
  }

  void deleteSavedImage(Identifier id) {
    images.delete(id);
  }

  void saveVideo(Down4Media im) {
    videos.put(im.id, jsonEncode(im));
  }

  Down4Media loadSavedVideo(Identifier id) {
    return Down4Media.fromJson(jsonDecode(videos.get(id)));
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

  void saveSnip(Down4Media snip) {
    images.put(snip.id, jsonEncode(snip));
  }

  Down4Media loadSnip(Identifier id) {
    return Down4Media.fromJson(jsonDecode(snips.get(id)));
  }

  void deleteSnip(Identifier id) {
    snips.delete(id);
  }

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

  void saveMessage(Down4Message msg) {
    messages.put(msg.id, jsonEncode(msg));
  }

  Down4Message? loadMessage(Identifier id) {
    var msg = messages.get(id);
    if (msg is! String) return null;
    var msgJson = jsonDecode(messages.get(id));
    if (msgJson == null) return null;
    return Down4Message.fromJson(msgJson);
  }

  void deleteMessage(Identifier id) {
    final msgJson = jsonDecode(messages.get(id));
    final mediaID = msgJson["m"]?["id"];
    if (mediaID != null) messageMedias.delete(mediaID);
    messages.delete(id);
  }

  bool mediaIsLocal(Identifier mediaID) {
    final isSavedImage = images.containsKey(mediaID);
    final isSavedVideo = videos.containsKey(mediaID);
    final isMessageMedia = messageMedias.containsKey(mediaID);
    return isSavedImage || isSavedVideo || isMessageMedia;
  }

  Down4Media? loadMessageMediaFromLocal(Identifier mediaID) {
    final isSavedImage = images.containsKey(mediaID);
    if (isSavedImage) {
      return Down4Media.fromJson(jsonDecode(images.get(mediaID)));
    } else {
      final isMessageMedia = messageMedias.containsKey(mediaID);
      if (isMessageMedia) {
        return Down4Media.fromJson(jsonDecode(messageMedias.get(mediaID)));
      } else {
        final isSavedVideo = videos.containsKey(mediaID);
        if (isSavedVideo) {
          return Down4Media.fromJson(jsonDecode(videos.get(mediaID)));
        }
      }
    }
    return null;
  }

  static Boxes get instance => _instance ??= Boxes();
}

class Sizes {
  static double h = 0;
  static double w = 0;
  static double fullHeight = 0;
  static double get headerHeight => 32;
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
