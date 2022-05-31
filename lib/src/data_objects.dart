import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'boxes.dart';

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

class Down4Media {
  Identifier id;
  Uint8List data;
  Uint8List? thumbnail;

  // Down4MediaMetadata metadata;
  // String data, thumbnail, url; // base64
  // bool usePlaceHolder;

  Down4Media({
    required this.id,
    required this.data,
    this.thumbnail,
    // required this.metadata,
    // this.url = "",
    // this.thumbnail = "",
    // this.data = "",
    // this.usePlaceHolder = false,
  });

  void localSave() {
    Boxes.instance.friends.put(id, jsonEncode(this));
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "d": base64Encode(data),
      if (thumbnail != null) "tn": base64Encode(thumbnail!),
    };
    // return {
    //   "md": metadata.toJson(),
    //   "id": id,
    //   "d": data,
    //   "tn": thumbnail,
    //   "url": url,
    // };
  }

  // @override
  // String toString() {
  //   return [id, metadata.toString(), url, thumbnail].join("^");
  // }

  // factory Down4Image.fromString(String s) {
  //   final values = s.split("^");
  //   if (values.length != 4) {
  //     throw "Invalid string to create down4media: $s\n";
  //   }
  //   return Down4Image(
  //     id: values[0],
  //     metadata: Down4MediaMetadata.fromString(values[1]),
  //     url: values[2],
  //     thumbnail: values[3],
  //   );
  // }

  factory Down4Media.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Media(
      id: decodedJson["id"],
      data: base64Decode(decodedJson["d"]),
      thumbnail:
          decodedJson["tn"] != null ? base64Decode(decodedJson["tn"]) : null,
    );
    // return Down4Image(
    //   id: decodedJson["id"],
    //   metadata: Down4MediaMetadata.fromJson(decodedJson["md"]),
    //   data: decodedJson["d"],
    //   thumbnail: decodedJson["tn"],
    //   url: decodedJson["url"],
    // );
  }

  factory Down4Media.fromLocal(String id) {
    final decodedJson = jsonDecode(Boxes.instance.images.get(id));
    return Down4Media.fromJson(decodedJson);
  }

  // Future<String> downloadURL() async {
  //   var ref = FirebaseStorage.instance.ref(id);
  //   return url = await ref.getDownloadURL();
  // }

  // Future<void> downloadData() async {
  //   var ref = FirebaseStorage.instance.ref(id);
  //   ref.getData().then((value) => data = base64Encode(value ?? []));
  // }

  Future<Uint8List> generateThumbnail() async {
    return thumbnail = await FlutterImageCompress.compressWithList(
      data,
      minWidth: 10,
      minHeight: 10,
      quality: 50,
    );
  }

  // bool get hasURL => url != "";

  // String get ownerid => metadata.owner;

  // bool get isVideo => metadata.isVideo;

  // bool get isImage => !metadata.isVideo;

  // Down4MediaMetadata get down4metadata => metadata;

  // Map<String, String> get jsonMetadata => metadata.toJson();

  // bool get hasData => data != "";

  // bool get hasThumbnail => thumbnail != "";

  // bool get isOnlyOnDatabase => !hasData;
}

enum MessageTypes {
  fr, // friend request
  b, // bill
  p, // payment
  m, // message
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
  final Down4Media image; // target, sender
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
      image: Down4Media.fromJson(decodedJson["m"]),
      // image: Down4Image.fromString(decodedJson["m"]),
    );
  }

  factory Reaction.fromLocal(String id) {
    final decodedJson = jsonDecode(Boxes.instance.reactions.get(id));
    return Reaction.fromJson(decodedJson);
  }

  void saveLocally() {
    Boxes.instance.reactions.put(id, jsonEncode(this));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sd': sender,
        'mtg': messageTargets,
        'm': image.id,
      };
}

class MessageRequest {
  final Identifier sender;
  final List<Identifier> targets;
  final String b64Thumbnail, name;
  final String? text;
  final num timestamp;
  final List<Identifier>? reactions, nodes;
  final bool isChat;
  final Uint8List? media;
  MessageRequest({
    required this.sender,
    required this.targets,
    required this.b64Thumbnail,
    required this.name,
    required this.isChat,
    required this.timestamp,
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
        if (text != null) "txt": text,
        if (reactions != null) "r": reactions,
        if (nodes != null) "n": nodes,
        if (media != null) "m": base64Encode(media!)
      };
}

class Down4Message {
  final Identifier id, sender, name;
  final Uint8List thumbnail;
  final Down4Media? media;
  final List<Identifier> targets;
  final String? text;
  //final Down4Media? media;
  final int timestamp;
  final bool isChat, isVideo; // true is chat, false is post
  final List<Identifier>? reactions, nodes; // reactions, nodes
  Down4Message({
    required this.id,
    required this.thumbnail,
    required this.sender,
    required this.targets,
    required this.name,
    required this.timestamp,
    this.isVideo = false,
    this.isChat = true,
    this.text,
    this.media,
    this.reactions,
    this.nodes,
  });

  factory Down4Message.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Message(
      id: decodedJson["id"],
      thumbnail: base64Decode(decodedJson["tn"]),
      sender: decodedJson["sd"],
      targets: decodedJson["tgt"],
      name: decodedJson["nm"],
      isChat: decodedJson["ch"] == "true",
      isVideo: decodedJson["vid"] == "true",
      text: decodedJson["txt"],
      timestamp: int.parse(decodedJson["ts"]),
      media: Down4Media.fromJson(decodedJson["m"]),
      reactions: decodedJson["r"],
      nodes: decodedJson["n"],
    );
  }

  factory Down4Message.fromLocal(String id) {
    final decodedJson = jsonDecode(Boxes.instance.messages.get(id));
    return Down4Message.fromJson(decodedJson);
  }

  Map<String, String> toFirebase() => {
        'id': id,
        'sd': sender,
        'tg': targets.join(" "),
        'tn': base64Encode(thumbnail),
        'nm': name,
        'ts': timestamp.toString(),
        'ch': isChat.toString(),
        'vid': isVideo.toString(),
        if (text != null) 'txt': text!,
        if (reactions != null) 'r': reactions!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
        if (media != null) 'im': media!.id,
      };

  Map<String, dynamic> toLocal() => {
        'id': id,
        'sd': sender,
        'tg': targets.join(" "),
        'tn': base64Encode(thumbnail),
        'nm': name,
        'ts': timestamp.toString(),
        'ch': isChat.toString(),
        'vid': isVideo.toString(),
        if (text != null) 'txt': text!,
        if (reactions != null) 'r': reactions!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
        if (media != null) 'im': media!.toJson(),
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
  final Down4Media image;
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
      type: NodeTypes.values.byName(decodedJson["t"]),
      name: decodedJson["nm"],
      lastName: decodedJson["ln"],
      image: Down4Media.fromJson(decodedJson["im"]),
      messages: decodedJson["msg"],
      admins: decodedJson["adm"],
      childs: decodedJson["chl"],
      parents: decodedJson["prt"],
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
