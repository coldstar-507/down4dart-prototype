import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bip32/bip32.dart';
import 'web_requests.dart' as r;
import 'down4_utility.dart' as d4utils;

typedef Identifier = String;

enum Messages {
  chat,
  hyperchat,
  group,
  bill,
  payment,
  snip,
  ping,
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

class MessageNotification {
  final Messages type;
  final String? base64jsonData;
  MessageNotification({required this.type, this.base64jsonData});
}

class Down4Message {
  Identifier? id;
  final Identifier? root;
  final Identifier senderID;
  final Identifier? forwarderID;
  final String? text;
  Down4Media? media;
  final int timestamp;
  final List<Identifier>? replies, nodes; // reactions, nodes

  Down4Message({
    this.id,
    this.root,
    required this.timestamp,
    required this.senderID,
    this.forwarderID,
    this.media,
    this.text,
    this.nodes,
    this.replies,
  });

  Down4Message forwarded(Node self) {
    return Down4Message(
      id: id,
      text: text,
      timestamp: timestamp,
      senderID: senderID,
      forwarderID: self.id != senderID ? self.id : null,
      media: media,
      nodes: nodes,
      replies: replies,
    );
  }

  factory Down4Message.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Message(
      id: decodedJson["id"],
      senderID: decodedJson["s"],
      forwarderID: decodedJson["f"],
      text: decodedJson["txt"],
      media: decodedJson["m"]?["d"] != null
          ? Down4Media.fromJson(decodedJson["m"])
          : null,
      timestamp: decodedJson["ts"],
      replies: ((decodedJson["r"] as String?) ?? "").isNotEmpty
          ? List<String>.from(decodedJson["r"].split(" "))
          : null,
      nodes: ((decodedJson["n"] as String?) ?? "").isNotEmpty
          ? List<String>.from(decodedJson["n"].split(" "))
          : null,
    );
  }

  Map<String, dynamic> toJson([bool withMediaData = true]) => {
        'id': id,
        if (text != null) 'txt': text,
        's': senderID,
        'ts': timestamp,
        if (forwarderID != null) 'f': forwarderID,
        if (replies != null) 'r': replies!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
        if (media != null)
          'm': withMediaData
              ? media!.toJson()
              : {
                  "id": media!.id,
                },
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
  bool withUpload;
  final List<Identifier> targets;
  final Node? rootNode;

  MessageRequest({
    required this.msg,
    required this.targets,
    this.rootNode,
    this.withUpload = false,
  });

  Map<String, dynamic> toJson() => {
        "wu": withUpload,
        if (rootNode != null)
          "g": {
            "id": rootNode!.id,
            "im": rootNode!.image,
            "nm": rootNode!.name,
            if (rootNode!.lastName != null) "ln": rootNode!.lastName,
          },
        "msg": msg.toJson(withUpload),
        "trgts": targets,
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
