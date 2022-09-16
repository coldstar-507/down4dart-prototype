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
    // if (metadata.isVideo) {
    //   final path = Boxes.instance.dirPath + "/" + decodedJson["id"];
    //   var file = File(path);
    //   final data = base64Decode(decodedJson["d"]);
    //   file.writeAsBytesSync(data);
    //   return Down4Media(
    //     id: decodedJson["id"],
    //     file: file,
    //     path: path,
    //     metadata: MediaMetadata.fromJson(decodedJson["md"]),
    //     data: data,
    //     thumbnail: decodedJson["tn"] != null && decodedJson["tn"] != ""
    //         ? base64Decode(decodedJson["tn"])
    //         : null,
    //   );
    // } else {
    return Down4Media(
      id: decodedJson["id"],
      metadata: metadata,
      data: base64Decode(decodedJson["d"]),
      thumbnail: decodedJson["tn"] != null && decodedJson["tn"] != ""
          ? base64Decode(decodedJson["tn"])
          : null,
    );
    // }
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

  // void save() {
  //   metadata.isVideo
  //       ? Boxes.instance.videos.put(id, jsonEncode(this))
  //       : Boxes.instance.images.put(id, jsonEncode(this));
  // }

  // void writeToFile() {
  //   path = Boxes.instance.dirPath + "/" + id;
  //   file = File(path!);
  //   file!.writeAsBytesSync(data);
  // }

  // void deleteFile() {
  //   file?.delete();
  // }

  // factory Down4Media.fromSave(String id) {
  //   return Down4Media.fromJson(jsonDecode(Boxes.instance.images.get(id)));
  // }
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

  // factory Reaction.fromLocal(String id) {
  //   final decodedJson = jsonDecode(Boxes.instance.reactions.get(id));
  //   return Reaction.fromJson(decodedJson);
  // }

  Map<String, dynamic> toLocal() => {
        'id': id,
        'sd': sender,
        'mtg': messageTargets,
        'm': image.toJson(),
      };
}

class MessageNotification {
  final Messages type;
  final String? base64jsonData;
  MessageNotification({required this.type, this.base64jsonData});
}

class Down4Message {
  Identifier? messageID;
  final Identifier senderID;
  final Identifier? forwarderID;
  final String? text;
  Down4Media? media;
  final bool isChat; // true is chat, false is post
  final int timestamp;
  final List<Identifier>? reactions, nodes; // reactions, nodes

  Down4Message({
    this.messageID,
    required this.timestamp,
    required this.senderID,
    this.forwarderID,
    this.media,
    this.text,
    this.nodes,
    this.reactions,
    this.isChat = true,
  });

  Down4Message forwarded(Node self) {
    return Down4Message(
      messageID: messageID,
      text: text,
      timestamp: timestamp,
      senderID: senderID,
      forwarderID: self.id != senderID ? self.id : null,
      media: media,
      nodes: nodes,
      reactions: reactions,
      isChat: isChat,
    );
  }

  factory Down4Message.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Message(
      messageID: decodedJson["msgid"],
      senderID: decodedJson["sdrid"],
      forwarderID: decodedJson["fdrid"],
      isChat: decodedJson["ischt"],
      text: decodedJson["txt"],
      media: decodedJson["m"] != null
          ? Down4Media.fromJson(decodedJson["m"])
          : null,
      timestamp: decodedJson["ts"],
      reactions:
          decodedJson["r"] != null ? List<String>.from(decodedJson["r"]) : null,
      nodes:
          decodedJson["n"] != null ? List<String>.from(decodedJson["n"]) : null,
    );
  }

  Map<String, dynamic> toJson([bool withMediaData = true]) => {
        'msgid': messageID,
        if (text != null) 'txt': text,
        'sdrid': senderID,
        'ts': timestamp,
        'ischt': isChat,
        if (forwarderID != null) 'fdrid': forwarderID,
        if (reactions != null) 'r': reactions,
        if (nodes != null) 'n': nodes,
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

  Node mutatedType(Nodes t) {
    return Node(
      id: id,
      name: name,
      lastName: lastName,
      image: image,
      description: description,
      type: t,
      activity: activity,
      admins: admins,
      childs: childs,
      parents: parents,
      friends: friends,
      group: group,
      messages: messages,
      posts: posts,
      snips: snips,
    );
  }

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

  // factory Node.fromLocal(Identifier id) {
  //   final decodedJson = jsonDecode(Boxes.instance.home.get(id));
  //   return Node.fromJson(decodedJson);
  // }

  factory Node.fromJson(Map<String, dynamic> decodedJson) {
    return Node(
      id: decodedJson["id"],
      name: decodedJson["nm"],
      lastName: decodedJson["ln"],
      activity: decodedJson["a"] ?? 0,
      image: Down4Media.fromJson(decodedJson["im"]),
      type: Nodes.values.byName(decodedJson["t"]),
      messages: List<String>.from(decodedJson["msg"] ?? []),
      admins: List<String>.from(decodedJson["adm"] ?? []),
      childs: List<String>.from(decodedJson["chl"] ?? []),
      parents: List<String>.from(decodedJson["prt"] ?? []),
      posts: List<String>.from(decodedJson["pst"] ?? []),
      group: List<String>.from(decodedJson["grp"] ?? []),
      friends: List<String>.from(decodedJson["frd"] ?? []),
      snips: List<String>.from(decodedJson["snp"] ?? []),
    );
  }

  // Map<String, dynamic> toFirebase() => {
  //       "id": id,
  //       "t": type.name,
  //       "nm": name,
  //       "ln": lastName,
  //       "im": image.id,
  //       "msg": messages,
  //       "adm": admins,
  //       "chl": childs,
  //       "prt": parents,
  //       "pst": posts,
  //       "grp": group,
  //       "snp": snips,
  //     };

  // Map<String, dynamic> toLocal() => {
  //       "id": id,
  //       "t": type.name,
  //       "a": activity,
  //       "nm": name,
  //       "ln": lastName,
  //       "im": image.toJson(),
  //       "msg": messages,
  //       "adm": admins,
  //       "chl": childs,
  //       "prt": parents,
  //       "pst": posts,
  //       "grp": group,
  //       "snp": snips,
  //     };

  Map<String, dynamic> toJson([bool withMedia = true]) => {
        "id": id,
        "t": type.name,
        "a": activity,
        "nm": name,
        "ln": lastName,
        "im": withMedia ? image!.toJson() : image!.id,
        "msg": messages,
        "adm": admins,
        "chl": childs,
        "prt": parents,
        "pst": posts,
        "grp": group,
        "snp": snips,
      };

  // void saveLocally() {
  //   Boxes.instance.home.put(id, jsonEncode(toLocal()));
  // }

  // void deleteLocally() {
  //   Boxes.instance.home.delete(id);
  //   for (final msgID in messages) {
  //     Boxes.instance.messages.delete(msgID);
  //   }
  // }

  // factory Node.fromLocal(String id, Box<dynamic> box) {
  //   if (isFriend) {
  //     final decodedJson = jsonDecode(Boxes.instance.friends.get(id));
  //     return Node.fromJson(decodedJson);
  //   } else {
  //     final decodedJson = jsonDecode(Boxes.instance.others.get(id));
  //     return Node.fromJson(decodedJson);
  //   }
  // }
  bool get isUser =>
      const [Nodes.friend, Nodes.nonFriend, Nodes.user].contains(type);
  bool get isGroupchat => const [Nodes.group, Nodes.hyperchat].contains(type);
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
