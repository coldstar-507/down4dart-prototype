import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bip32/bip32.dart';
import 'down4_utility.dart' as d4utils;
import 'simple_bsv.dart';

typedef Identifier = String;

enum Messages {
  chat,
  payment,
  bill,
  snip,
}

enum Nodes {
  user,
  friend,
  nonFriend,
  hyperchat,
  group,
  root,
  market,
  checkpoint,
  journal,
  item,
  event,
  ticket,
}

class Down4Media {
  Identifier id;
  MediaMetadata metadata;
  Uint8List data;
  String? networkUrl;
  String? path;
  File? file;
  Uint8List? thumbnail;

  Down4Media({
    required this.id,
    required this.metadata,
    required this.data,
    this.thumbnail,
    this.networkUrl,
    this.path,
    this.file,
  });

  factory Down4Media.fromJson(Map<String, dynamic> decodedJson) {
    final metadata = MediaMetadata.fromJson(decodedJson["md"]);
    return Down4Media(
      id: decodedJson["id"],
      metadata: metadata,
      data: base64Decode(decodedJson["d"]),
      thumbnail: decodedJson["tn"] != null && decodedJson["tn"] != ""
          ? base64Decode(decodedJson["tn"])
          : null,
    );
  }

  factory Down4Media.fromCamera(String filePath, MediaMetadata md) {
    final file = File(filePath);
    final data = file.readAsBytesSync();
    return Down4Media(
      id: d4utils.generateMediaID(data),
      data: data,
      metadata: md,
      path: filePath,
      file: file,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "md": metadata.toJson(),
        "d": base64Encode(data),
        if (thumbnail != null) "tn": base64Encode(thumbnail!),
      };
}

class MessageNotification {
  final Messages type;
  final String? base64jsonData;
  MessageNotification({required this.type, this.base64jsonData});
}

class Down4Message {
  Messages type;
  Identifier? id;
  final Identifier senderID;
  final Identifier? root, forwarderID, paymentID, mediaID;
  final String? text;
  final int timestamp;
  final List<Identifier>? replies, nodes; // reactions, nodes

  Down4Message({
    required this.senderID,
    this.type = Messages.chat,
    required this.timestamp,
    this.id,
    this.root,
    this.mediaID,
    this.paymentID,
    this.forwarderID,
    this.text,
    this.nodes,
    this.replies,
  });

  Down4Message forwarded(Node self) {
    return Down4Message(
      type: type,
      id: id,
      text: text,
      timestamp: timestamp,
      senderID: senderID,
      forwarderID: self.id != senderID ? self.id : null,
      mediaID: mediaID,
      paymentID: paymentID,
      nodes: nodes,
      replies: replies,
    );
  }

  factory Down4Message.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Message(
      type: Messages.values.byName(decodedJson["t"]),
      id: decodedJson["id"],
      senderID: decodedJson["s"],
      forwarderID: decodedJson["f"],
      text: decodedJson["txt"],
      mediaID: decodedJson["m"],
      paymentID: decodedJson["p"],
      timestamp: decodedJson["ts"],
      replies: ((decodedJson["r"] as String?) ?? "").isNotEmpty
          ? List<String>.from(decodedJson["r"].split(" "))
          : null,
      nodes: ((decodedJson["n"] as String?) ?? "").isNotEmpty
          ? List<String>.from(decodedJson["n"].split(" "))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        't': type.toString(),
        'id': id,
        if (text != null) 'txt': text,
        's': senderID,
        'ts': timestamp,
        if (forwarderID != null) 'f': forwarderID,
        if (replies != null) 'r': replies!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
        if (paymentID != null) 'p': paymentID,
        if (mediaID != null) 'm': mediaID,
      };
}

class Node {
  final Identifier id;
  final BIP32? neuter;

  String name;
  String? lastName;
  Down4Media? image;
  String? description;
  Nodes type;
  int activity;
  List<Identifier>? admins;
  List<Identifier>? childs;
  List<Identifier>? parents;
  List<Identifier>? friends;
  List<Identifier>? snips;
  List<Identifier>? group;
  List<Identifier>? messages;
  List<Identifier>? posts; // messages / either post or chat
  Node({
    required this.type,
    required this.id,
    required this.name,
    this.image,
    this.neuter,
    this.description,
    this.activity = 0,
    this.lastName,
    this.posts,
    this.messages,
    this.admins,
    this.childs,
    this.group,
    this.parents,
    this.friends,
    this.snips,
  });

  void mutateType(Nodes t) => type = t;

  void updateActivity() => activity = d4utils.timeStamp();

  void merge(Node mergeNode) {
    childs = mergeNode.childs;
    parents = mergeNode.parents;
    admins = mergeNode.admins;
    friends = mergeNode.friends;
    posts = mergeNode.posts;
    description = mergeNode.description;
    image = mergeNode.image;
    name = mergeNode.name;
    lastName = mergeNode.lastName;
  }

  factory Node.fromJson(Map<String, dynamic> decodedJson) {
    return Node(
      id: decodedJson["id"],
      name: decodedJson["nm"],
      lastName: decodedJson["ln"],
      activity: decodedJson["a"] ?? 0,
      image: decodedJson["im"] != null
          ? Down4Media.fromJson(decodedJson["im"])
          : null,
      type: Nodes.values.byName(decodedJson["t"]),
      messages: decodedJson["msg"] != null
          ? List<String>.from(decodedJson["msg"])
          : null,
      admins: decodedJson["adm"] != null
          ? List<String>.from(decodedJson["adm"])
          : null,
      childs: decodedJson["chl"] != null
          ? List<String>.from(decodedJson["chl"])
          : null,
      parents: decodedJson["prt"] != null
          ? List<String>.from(decodedJson["prt"])
          : null,
      posts: decodedJson["pst"] != null
          ? List<String>.from(decodedJson["pst"])
          : null,
      group: decodedJson["grp"] != null
          ? List<String>.from(decodedJson["grp"])
          : null,
      friends: decodedJson["frd"] != null
          ? List<String>.from(decodedJson["frd"])
          : null,
      snips: decodedJson["snp"] != null
          ? List<String>.from(decodedJson["snp"])
          : null,
    );
  }

  Map<String, dynamic> toJson([bool withMedia = true]) => {
        "id": id,
        "t": type.name,
        "a": activity,
        "nm": name,
        if (lastName != null) "ln": lastName,
        if (image != null) "im": withMedia ? image!.toJson() : image!.id,
        if (messages != null) "msg": messages,
        if (admins != null) "adm": admins,
        if (childs != null) "chl": childs,
        if (parents != null) "prt": parents,
        if (posts != null) "pst": posts,
        if (group != null) "grp": group,
        if (snips != null) "snp": snips,
      };
}

class MessageRequest {
  Down4Message msg;
  final List<Identifier> targets;
  Down4Media? media;
  Down4Payment? payment;
  final Node? rootNode;

  MessageRequest({
    required this.msg,
    required this.targets,
    this.rootNode,
    this.media,
    this.payment,
  });

  Map<String, dynamic> toJson() => {
        if (rootNode != null)
          "g": {
            "id": rootNode!.id,
            "im": rootNode!.image!.toJson(),
            "nm": rootNode!.name,
            if (rootNode!.lastName != null) "ln": rootNode!.lastName,
          },
        "msg": msg.toJson(),
        "trgts": targets,
        if (media != null) "m": media!.toJson(),
        if (payment != null) "p": payment!.toJson(),
      };
}

class ChatRequest {
  Down4Message msg;
  List<Identifier> targets;
  Down4Media? media;

  ChatRequest({
    required this.msg,
    required this.targets,
    this.media,
  });

  Map<String, dynamic> toJson([bool withMedia = false]) => {
        "msg": msg.toJson(),
        "trgts": targets,
        if (withMedia && media != null) "m": media!.toJson(),
      };
}

class HyperchatRequest extends ChatRequest {
  List<String> wordPairs;
  HyperchatRequest({
    required Down4Message msg,
    required List<Identifier> targets,
    Down4Media? media,
    required this.wordPairs,
  }) : super(msg: msg, targets: targets, media: media);

  @override
  Map<String, dynamic> toJson([bool withMedia = false]) => {
        "msg": msg.toJson(),
        "prompts": wordPairs,
        "trgts": targets,
        if (withMedia && media != null) "m": media!.toJson(),
      };
}

class GroupRequest extends ChatRequest {
  String name;
  bool private;
  Down4Media groupImage;
  GroupRequest({
    required this.private,
    required this.name,
    required this.groupImage,
    required Down4Message msg,
    Down4Media? media,
    required List<Identifier> targets,
  }) : super(msg: msg, media: media, targets: targets);

  @override
  Map<String, dynamic> toJson([bool withMedia = false]) => {
        "msg": msg.toJson(),
        "pv": private,
        "nm": name,
        "im": groupImage.toJson(),
        "trgts": targets,
        if (withMedia && media != null) "m": media!.toJson(),
      };
}

class PaymentRequest extends ChatRequest {
  Down4Payment payment;
  PaymentRequest({
    required this.payment,
    required Down4Message msg,
    required List<Identifier> targets,
  }) : super(msg: msg, targets: targets);

  @override
  Map<String, dynamic> toJson([bool withMedia = false]) => {
        "msg": msg.toJson(),
        "trgts": targets,
        "p": payment.toJson(),
      };
}

class MediaMetadata {
  final bool toReverse, shareable, payToView, isVideo, payToOwn;
  final Identifier owner;
  final double? aspectRatio;
  final String? text;
  int timestamp;
  MediaMetadata({
    required this.owner,
    required this.timestamp,
    this.isVideo = false,
    this.shareable = true,
    this.payToView = false,
    this.toReverse = false,
    this.payToOwn = false,
    this.aspectRatio,
    this.text,
  });

  factory MediaMetadata.fromJson(Map<String, dynamic> decodedJson) {
    return MediaMetadata(
      owner: decodedJson["o"],
      timestamp: int.parse(decodedJson["ts"]),
      isVideo: decodedJson["vid"] == "true",
      toReverse: decodedJson["trv"] == "true",
      shareable: decodedJson["shr"] == "true",
      payToView: decodedJson["ptv"] == "true",
      payToOwn: decodedJson["pto"] == "true",
      text: decodedJson["txt"],
      aspectRatio: decodedJson["ar"] != "null" && decodedJson["ar"] != null
          ? double.parse(decodedJson["ar"])
          : null,
    );
  }

  Map<String, String> toJson() {
    return {
      "o": owner,
      "ts": timestamp.toString(),
      "vid": isVideo.toString(),
      "trv": toReverse.toString(),
      "shr": shareable.toString(),
      "ptv": payToView.toString(),
      "pto": payToOwn.toString(),
      "ar": aspectRatio.toString(),
      if (text != null) "txt": text!,
    };
  }
}

// class Reaction {
//   final Identifier id, sender;
//   final Down4Media image; // target, sender
//   final List<String> messageTargets;
//   Reaction({
//     required this.id,
//     required this.messageTargets,
//     required this.sender,
//     required this.image,
//   });
//
//   factory Reaction.fromJson(Map<String, dynamic> decodedJson) {
//     return Reaction(
//       id: decodedJson["id"],
//       messageTargets: decodedJson["mtg"],
//       sender: decodedJson["sd"],
//       image: Down4Media.fromJson(decodedJson["m"]),
//     );
//   }
//
//   Map<String, dynamic> toLocal() => {
//         'id': id,
//         'sd': sender,
//         'mtg': messageTargets,
//         'm': image.toJson(),
//       };
// }
