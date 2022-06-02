import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'boxes.dart';
import 'web_requests.dart' as r;

typedef Identifier = String;

class MoneyInfo {
  String mnemonic, down4Priv, master;
  int upperIndex, upperChange, lowerIndex, lowerChange;

  MoneyInfo({
    required this.mnemonic,
    required this.master,
    required this.down4Priv,
    required this.lowerIndex,
    required this.upperIndex,
    required this.lowerChange,
    required this.upperChange,
  });

  factory MoneyInfo.fromJson(Map<String, dynamic> decodedJson) {
    return MoneyInfo(
      mnemonic: decodedJson["mnemonic"],
      master: decodedJson["master"],
      down4Priv: decodedJson["down4priv"],
      lowerIndex: decodedJson["lowerindex"],
      upperIndex: decodedJson["upperindex"],
      lowerChange: decodedJson["lowerchange"],
      upperChange: decodedJson["upperchange"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "mnemonic": mnemonic,
      "master": master,
      "down4priv": down4Priv,
      "lowerindex": lowerIndex,
      "upperindex": upperIndex,
      "lowerchange": lowerChange,
      "upperchange": upperChange,
    };
  }
}

// class Down4MediaMetadata {
//   final bool toReverse, shareable, payToView, payToOwn, isVideo;
//   final Identifier owner;
//   Down4MediaMetadata({
//     required this.owner,
//     this.isVideo = false,
//     this.toReverse = false,
//     this.payToOwn = false,
//     this.shareable = true,
//     this.payToView = false,
//   });

//   factory Down4MediaMetadata.fromJson(Map<String, dynamic> decodedJson) {
//     return Down4MediaMetadata(
//       owner: decodedJson["o"],
//       isVideo: decodedJson["vid"] == "true",
//       toReverse: decodedJson["trv"] == "true",
//       payToOwn: decodedJson["pto"] == "true",
//       shareable: decodedJson["shr"] == "true",
//       payToView: decodedJson["ptv"] == "true",
//     );
//   }

//   factory Down4MediaMetadata.fromString(String s) {
//     final values = s.split("*");
//     if (values.length != 6) {
//       throw "Invalid string to create metadata: $s\n";
//     }
//     return Down4MediaMetadata(
//       owner: values[0],
//       isVideo: values[1] == "true",
//       toReverse: values[2] == "true",
//       payToOwn: values[3] == "true",
//       shareable: values[4] == "true",
//       payToView: values[5] == "true",
//     );
//   }

//   @override
//   String toString() {
//     return [
//       owner,
//       isVideo.toString(),
//       toReverse.toString(),
//       payToOwn.toString(),
//       shareable.toString(),
//       payToView.toString(),
//     ].join("*");
//   }

//   Map<String, String> toJson() {
//     return {
//       "o": owner,
//       "vid": isVideo.toString(),
//       "trv": toReverse.toString(),
//       "pto": payToOwn.toString(),
//       "shr": shareable.toString(),
//       "ptv": payToView.toString(),
//     };
//   }
// }

class Down4Video {
  Identifier id;
  String url;
  Uint8List? thumbnail;

  Down4Video({
    required this.id,
    required this.url,
    this.thumbnail,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "url": url,
        if (thumbnail != null) "tn": base64Encode(thumbnail!)
      };

  factory Down4Video.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Video(
      id: decodedJson["id"],
      url: decodedJson["url"],
      thumbnail: decodedJson["tn"] != null && decodedJson["tn"] != ""
          ? base64Decode(decodedJson["tn"])
          : null,
    );
  }
}

class Down4Image {
  Identifier id;
  Uint8List data;
  Uint8List? thumbnail;

  Down4Image({
    required this.id,
    required this.data,
    this.thumbnail,
  });

  Future<Uint8List> generateThumbnail() async {
    return thumbnail = await FlutterImageCompress.compressWithList(
      data,
      minWidth: 10,
      minHeight: 10,
      quality: 50,
    );
  }

  factory Down4Image.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Image(
      id: decodedJson["id"],
      data: base64Decode(decodedJson["d"]),
      thumbnail: decodedJson["tn"] != null && decodedJson["tn"] != ""
          ? base64Decode(decodedJson["tn"])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "d": base64Encode(data),
        if (thumbnail != null) "tn": base64Encode(thumbnail!),
      };
}

enum MessageTypes {
  friendRequest, // friend request
  bill, // bill
  payment, // payment
  chat, // message
}

enum NodeTypes {
  rt,
  usr,
  cht,
  mkt,
  cpt,
  jnl,
  itm,
  evt,
  tkt,
}

class Reaction {
  final Identifier id, sender;
  final Down4Image image; // target, sender
  final List<String> messageTargets;
  Reaction({
    required this.id,
    required this.messageTargets,
    required this.sender,
    required this.image,
  });

  factory Reaction.fromJson(Map<String, dynamic> decodedJson) {
    return Reaction(
      id: decodedJson["id"],
      messageTargets: decodedJson["mtg"],
      sender: decodedJson["sd"],
      image: Down4Image.fromJson(decodedJson["m"]),
      // image: Down4Image.fromString(decodedJson["m"]),
    );
  }

  factory Reaction.fromLocal(String id) {
    final decodedJson = jsonDecode(Boxes.instance.reactions.get(id));
    return Reaction.fromJson(decodedJson);
  }

  Map<String, dynamic> toLocal() => {
        'id': id,
        'sd': sender,
        'mtg': messageTargets,
        'm': image.toJson(),
      };
}

class MessageNotification {
  final MessageTypes type;
  final Identifier id, sender, root;
  final Identifier? imageID;
  final int timestamp;
  final String base64Thumbnail, name;
  final String? text, videoURL;
  final List<Identifier>? nodes, reactions;
  final bool isChat;
  MessageNotification({
    required this.type,
    required this.id,
    required this.sender,
    required this.root,
    required this.base64Thumbnail,
    required this.name,
    required this.isChat,
    required this.timestamp,
    this.videoURL,
    this.imageID,
    this.text,
    this.nodes,
    this.reactions,
  });

  factory MessageNotification.fromNotification(
      Map<String, dynamic> notification) {
    return MessageNotification(
      timestamp: int.tryParse(notification["ts"]) ?? 0,
      type: MessageTypes.values.byName(notification["t"]),
      id: notification["id"],
      sender: notification["sd"],
      imageID: notification["m"],
      root: notification["rt"],
      base64Thumbnail: notification["tn"],
      name: notification["nm"],
      isChat: notification["ch"] == "true",
      text: notification["txt"] == "" ? null : notification["txt"],
      videoURL: notification["url"] == "" ? null : notification["url"],
      nodes: notification["n"] == ""
          ? null
          : (notification["n"] as String).split(" "),
      reactions: notification["r"] == ""
          ? null
          : (notification["r"] as String).split(" "),
    );
  }

  Future<Down4Message> toDown4Message() async {
    Down4Image? m;
    Down4Video? v;
    if (imageID != null) {
      m = await r.getMessageMedia(imageID!);
    }
    return Down4Message(
      id: id,
      thumbnail: base64Decode(base64Thumbnail),
      sender: sender,
      root: root,
      name: name,
      timestamp: timestamp,
    );
  }
}

class MessageRequest {
  final Identifier sender;
  final List<Identifier> targets;
  final String b64Thumbnail, name;
  final String? text;
  final num timestamp;
  final List<Identifier>? reactions, nodes;
  final bool isChat, isVideo;
  final Uint8List? media;
  MessageRequest({
    required this.sender,
    required this.targets,
    required this.b64Thumbnail,
    required this.name,
    required this.isChat,
    required this.timestamp,
    required this.isVideo,
    this.media,
    this.text,
    this.reactions,
    this.nodes,
  });

  Map<String, dynamic> toGoogle() => {
        "sd": sender,
        "tg": targets,
        "tn": b64Thumbnail,
        "nm": name,
        "ts": timestamp,
        "ch": isChat,
        "vid": isVideo,
        if (text != null) "txt": text,
        if (reactions != null) "r": reactions,
        if (nodes != null) "n": nodes,
        if (media != null) "m": base64Encode(media!),
      };
}

class Down4Message {
  final Identifier id, sender, name, root;
  final Uint8List thumbnail;
  final Down4Image? image;
  final Down4Video? video;
  final String? text;
  final int timestamp;
  final bool isChat; // true is chat, false is post
  final List<Identifier>? reactions, nodes; // reactions, nodes
  Down4Message({
    required this.id,
    required this.thumbnail,
    required this.sender,
    required this.root,
    required this.name,
    required this.timestamp,
    this.video,
    this.isChat = true,
    this.text,
    this.image,
    this.reactions,
    this.nodes,
  });

  factory Down4Message.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Message(
      id: decodedJson["id"],
      thumbnail: base64Decode(decodedJson["tn"]),
      image: Down4Image.fromJson(decodedJson["m"]),
      sender: decodedJson["sd"],
      root: decodedJson["rt"],
      name: decodedJson["nm"],
      isChat: decodedJson["ch"] == "true",
      text: decodedJson["txt"],
      timestamp: int.parse(decodedJson["ts"]),
      reactions:
          decodedJson["r"] != null ? List<String>.from(decodedJson["r"]) : null,
      nodes:
          decodedJson["n"] != null ? List<String>.from(decodedJson["n"]) : null,
    );
  }

  factory Down4Message.fromLocal(String id) {
    final decodedJson = jsonDecode(Boxes.instance.messages.get(id));
    return Down4Message.fromJson(decodedJson);
  }

  Map<String, String> toFirebase() => {
        'id': id,
        'sd': sender,
        'rt': root,
        'tn': base64Encode(thumbnail),
        'nm': name,
        'ts': timestamp.toString(),
        'ch': isChat.toString(),
        if (text != null) 'txt': text!,
        if (reactions != null) 'r': reactions!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
        if (image != null) 'im': image!.id,
      };

  Map<String, dynamic> toLocal() => {
        'id': id,
        'sd': sender,
        'rt': root,
        'tn': base64Encode(thumbnail),
        'nm': name,
        'ts': timestamp.toString(),
        'ch': isChat.toString(),
        if (text != null) 'txt': text!,
        if (reactions != null) 'r': reactions!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
        if (image != null) 'im': image!.toJson(),
      };

  void saveLocally() {
    Boxes.instance.messages.put(id, jsonEncode(this));
  }
}

class Node {
  final Identifier id;
  final NodeTypes type;
  final String name;
  final String? lastName;
  final Down4Image image;
  List<Identifier>? admins, childs, parents, friends; // admin, childs, parents
  List<Identifier>? messages; // messages / either post or chat
  Node({
    required this.type,
    required this.id,
    required this.name,
    required this.image,
    this.lastName,
    this.messages,
    this.admins,
    this.childs,
    this.parents,
  });

  factory Node.fromJson(Map<String, dynamic> decodedJson) {
    return Node(
      id: decodedJson["id"],
      type: decodedJson["t"] == ""
          ? NodeTypes.usr
          : NodeTypes.values.byName(decodedJson["t"]),
      name: decodedJson["nm"],
      lastName: decodedJson["ln"],
      image: Down4Image.fromJson(decodedJson["im"]),
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
    );
  }

  Map<String, dynamic> toFirebase() => {
        "id": id,
        "t": type.name,
        "nm": name,
        "ln": lastName,
        "im": image.id,
        "msg": messages,
        "adm": admins,
        "chl": childs,
        "prt": parents,
      };

  Map<String, dynamic> toLocal() => {
        "id": id,
        "t": type.name,
        "nm": name,
        "ln": lastName,
        "im": image.toJson(),
        "msg": messages,
        "adm": admins,
        "chl": childs,
        "prt": parents,
      };

  void saveLocally() {
    if (type == NodeTypes.usr) {
      Boxes.instance.friends.put(id, jsonEncode(toLocal()));
    } else {
      Boxes.instance.others.put(id, jsonEncode(toLocal()));
    }
  }

  factory Node.fromLocal(String id, bool isFriend) {
    if (isFriend) {
      final decodedJson = jsonDecode(Boxes.instance.friends.get(id));
      return Node.fromJson(decodedJson);
    } else {
      final decodedJson = jsonDecode(Boxes.instance.others.get(id));
      return Node.fromJson(decodedJson);
    }
  }
}
