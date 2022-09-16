import 'package:flutter_testproject/src/simple_bsv.dart';
import 'package:hive/hive.dart';
import '../main.dart' as main;
import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'data_objects.dart';

var db = FirebaseDatabase.instance.ref();
var fs = FirebaseFirestore.instance;
var st = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");

Future<Down4Media?> getMessageMedia(Identifier mediaID) async {
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
      snip;
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
        snip = Hive.box("Snips"),
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

  Map<String, dynamic>? loadExchangeRate() {
    final rate = user.get("exchangeRate");
    if (rate == null) return null;
    return jsonDecode(rate);
  }

  void saveExchangeRate(Map<String, dynamic> exchangeRate) {
    user.put("exchangeRate", jsonEncode(exchangeRate));
  }

  void deleteVideo(Identifier id) {
    videos.delete(id);
  }

  void saveSnip(Down4Media snip) {
    images.put(snip.id, jsonEncode(snip));
  }

  Down4Media loadSnip(Identifier id) {
    return Down4Media.fromJson(jsonDecode(snip.get(id)));
  }

  void deleteSnip(Identifier id) {
    snip.delete(id);
  }

  void saveUser(Node u) {
    user.put("user", jsonEncode(u));
  }

  Node loadUser() {
    return Node.fromJson(jsonDecode(user.get("user")));
  }

  void saveWallet(Wallet w) {
    user.put("wallet", jsonEncode(w));
  }

  Wallet loadWallet() {
    return Wallet.fromJson(jsonDecode(user.get("wallet")));
  }

  void saveNode(Node p) {
    home.put(p.id, jsonEncode(p));
  }

  Node loadNode(Identifier id) {
    return Node.fromJson(jsonDecode(home.get(id)));
  }

  void deleteNode(Identifier id) {
    final node = loadNode(id);
    for (final msgID in node.messages ?? <String>[]) {
      messages.delete(msgID);
    }
    home.delete(id);
  }

  void saveMessage(Down4Message msg) {
    messages.put(msg.messageID, jsonEncode(msg.toJson(false)));
    if (msg.media != null) {
      messageMedias.put(msg.media!.id, jsonEncode(msg.media!));
    }
  }

  Down4Message loadMessage(Identifier id) {
    var msgJson = jsonDecode(messages.get(id));
    String? mediaID = msgJson["m"]?["id"];
    if (mediaID != null) {
      final mediaJson = jsonDecode(messageMedias.get(mediaID));
      msgJson["m"] = mediaJson;
    }
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

  static Boxes get instance => _instance ??= Boxes();
}

class Sizes {
  static double h = 0;
  static double w = 0;
}

class Sizes2 {
  Sizes2._()
      : w = 0,
        h = 0;
  double w, h;
  static Sizes2? _instance;
  static Sizes2 get instance => _instance ??= Sizes2._();
}
