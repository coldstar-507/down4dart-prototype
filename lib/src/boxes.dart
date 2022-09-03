import 'package:flutter_testproject/src/simple_bsv.dart';
import 'package:hive/hive.dart';
import '../main.dart' as main;
import 'dart:convert';
import 'dart:io';

import 'data_objects.dart' as d;

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
        snip = Hive.box("Snips");

  File writeMediaToFile(d.Down4Media m) {
    var f = File(dirPath + "/" + m.id);
    f.writeAsBytes(m.data);
    return f;
  }

  void saveImage(d.Down4Media im) {
    images.put(im.id, jsonEncode(im));
  }

  d.Down4Media loadImage(d.Identifier id) {
    return d.Down4Media.fromJson(jsonDecode(images.get(id)));
  }

  void deleteImage(d.Identifier id) {
    images.delete(id);
  }

  void saveVideo(d.Down4Media im) {
    videos.put(im.id, jsonEncode(im));
  }

  d.Down4Media loadVideo(d.Identifier id) {
    return d.Down4Media.fromJson(jsonDecode(videos.get(id)));
  }

  Map<String, dynamic>? loadExchangeRate() {
    final rate = user.get("exchangeRate");
    if (rate == null) return null;
    return jsonDecode(rate);
  }

  void saveExchangeRate(Map<String, dynamic> exchangeRate) {
    user.put("exchangeRate", jsonEncode(exchangeRate));
  }

  void deleteVideo(d.Identifier id) {
    videos.delete(id);
  }

  void saveSnip(d.Down4Media snip) {
    images.put(snip.id, jsonEncode(snip));
  }

  d.Down4Media loadSnip(d.Identifier id) {
    return d.Down4Media.fromJson(jsonDecode(snip.get(id)));
  }

  void deleteSnip(d.Identifier id) {
    snip.delete(id);
  }

  void saveUser(d.Node u) {
    user.put("user", jsonEncode(u));
  }

  d.Node loadUser() {
    return d.Node.fromJson(jsonDecode(user.get("user")));
  }

  void saveWallet(Wallet w) {
    user.put("wallet", jsonEncode(w));
  }

  Wallet loadWallet() {
    return Wallet.fromJson(jsonDecode(user.get("wallet")));
  }

  void saveNode(d.Node p) {
    home.put(p.id, jsonEncode(p));
  }

  d.Node loadNode(d.Identifier id) {
    return d.Node.fromJson(jsonDecode(home.get(id)));
  }

  void deleteNode(d.Identifier id) {
    final node = loadNode(id);
    for (final msgID in node.messages ?? <String>[]) {
      messages.delete(msgID);
    }
    home.delete(id);
  }

  void saveMessage(d.Down4Message msg) {
    messages.put(msg.messageID, jsonEncode(msg));
  }

  d.Down4Message loadMessage(d.Identifier id) {
    return d.Down4Message.fromJson(jsonDecode(messages.get(id)));
  }

  void deleteMessage(d.Identifier id) {
    messages.delete(id);
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
