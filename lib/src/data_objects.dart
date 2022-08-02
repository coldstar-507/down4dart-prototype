import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:dartsv/dartsv.dart' as sv;
import 'boxes.dart';
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

class MoneyInfo {
  String mnemonic;
  sv.HDPrivateKey down4priv, master;
  int upperIndex, upperChange, lowerIndex, lowerChange;

  MoneyInfo({
    required this.mnemonic,
    required this.master,
    required this.down4priv,
    required this.lowerIndex,
    required this.upperIndex,
    required this.lowerChange,
    required this.upperChange,
  });

  factory MoneyInfo.fromJson(Map<String, dynamic> decodedJson) {
    return MoneyInfo(
      mnemonic: decodedJson["mnemonic"],
      master: sv.HDPrivateKey.fromXpriv(decodedJson["master"]),
      down4priv: sv.HDPrivateKey.fromXpriv(decodedJson["down4priv"]),
      lowerIndex: decodedJson["lowerindex"],
      upperIndex: decodedJson["upperindex"],
      lowerChange: decodedJson["lowerchange"],
      upperChange: decodedJson["upperchange"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "mnemonic": mnemonic,
      "master": master.toString(),
      "down4priv": down4priv.toString(),
      "lowerindex": lowerIndex,
      "upperindex": upperIndex,
      "lowerchange": lowerChange,
      "upperchange": upperChange,
    };
  }
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

  Future<Uint8List?> generateThumbnail() async {
    if (!metadata.isVideo) {
      return thumbnail = await FlutterImageCompress.compressWithList(
        data,
        minWidth: 10,
        minHeight: 10,
        quality: 50,
      );
    }
    return null;
  }

  factory Down4Media.fromJson(Map<String, dynamic> decodedJson) {
    final metadata = MediaMetadata.fromJson(decodedJson["md"]);
    if (metadata.isVideo) {
      final path = Boxes.instance.dirPath + "/" + decodedJson["id"];
      var file = File(path);
      final data = base64Decode(decodedJson["d"]);
      file.writeAsBytesSync(data);
      return Down4Media(
        id: decodedJson["id"],
        file: file,
        path: path,
        metadata: MediaMetadata.fromJson(decodedJson["md"]),
        data: data,
        thumbnail: decodedJson["tn"] != null && decodedJson["tn"] != ""
            ? base64Decode(decodedJson["tn"])
            : null,
      );
    } else {
      return Down4Media(
        id: decodedJson["id"],
        metadata: metadata,
        data: base64Decode(decodedJson["d"]),
        thumbnail: decodedJson["tn"] != null && decodedJson["tn"] != ""
            ? base64Decode(decodedJson["tn"])
            : null,
      );
    }
  }

  factory Down4Media.fromCamera(String filePath, MediaMetadata md) {
    final data = File(filePath).readAsBytesSync();
    return Down4Media(
      id: d4utils.generateMediaID(data),
      data: data,
      metadata: md,
      path: filePath,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "md": metadata.toJson(),
        "d": base64Encode(data),
        if (thumbnail != null) "tn": base64Encode(thumbnail!),
      };

  void save() {
    metadata.isVideo
        ? Boxes.instance.videos.put(id, jsonEncode(this))
        : Boxes.instance.images.put(id, jsonEncode(this));
  }

  void writeToFile() {
    path = Boxes.instance.dirPath + "/" + id;
    file = File(path!);
    file!.writeAsBytesSync(data);
  }

  void deleteFile() {
    file?.delete();
  }

  factory Down4Media.fromSave(String id) {
    return Down4Media.fromJson(jsonDecode(Boxes.instance.images.get(id)));
  }
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

  Map<String, dynamic> toLocal() => {
        'id': id,
        'sd': sender,
        'mtg': messageTargets,
        'm': image.toJson(),
      };
}

class MessageNotification {
  final Messages type;
  final Identifier msgID, senderID, root;
  final Identifier? mediaID, forwarderID;
  final int timestamp;
  final String senderThumbnail, senderName;
  final String? text, forwarderThumbnail, forwarderName;
  final String? hyperchatName, hyperchatLastName, hyperchatID, hyperchatMediaID;
  final String? groupName, groupID, groupMediaID;
  final List<Identifier>? nodes, reactions, groupFriends, hyperchatFriends;
  final bool isChat;
  MessageNotification({
    required this.type,
    required this.msgID,
    required this.root,
    required this.isChat,
    required this.timestamp,
    required this.senderID,
    required this.senderName,
    required this.senderThumbnail,
    this.forwarderID,
    this.forwarderName,
    this.forwarderThumbnail,
    this.hyperchatID,
    this.hyperchatName,
    this.hyperchatLastName,
    this.hyperchatMediaID,
    this.hyperchatFriends,
    this.groupID,
    this.groupName,
    this.groupMediaID,
    this.groupFriends,
    this.mediaID,
    this.text,
    this.nodes,
    this.reactions,
  });

  factory MessageNotification.fromNotification(Map<String, String> ntf) {
    return MessageNotification(
      type: Messages.values.byName(ntf["t"]!),
      timestamp: int.parse(ntf["ts"] ?? "0"),
      msgID: ntf["msgid"] ?? "",
      mediaID: ntf["mid"],
      root: ntf["rt"] ?? "",
      senderID: ntf["sdrid"]!,
      senderThumbnail: ntf["sdrtn"]!,
      senderName: ntf["sdrnm"]!,
      forwarderID: ntf["fdrid"],
      forwarderName: ntf["fdrnm"],
      forwarderThumbnail: ntf["fdrid"],
      hyperchatID: ntf["hcid"],
      hyperchatName: ntf["hcnm"],
      hyperchatLastName: ntf["hcln"],
      hyperchatMediaID: ntf["hcim"],
      hyperchatFriends: ntf["hcfr"]?.split(" "),
      groupID: ntf["gid"],
      groupName: ntf["gnm"],
      groupMediaID: ntf["gim"],
      groupFriends: ntf["gfr"]?.split(" "),
      isChat: ntf["ischt"] == "true",
      text: ntf["txt"],
      nodes: ntf["n"]?.split(" "),
      reactions: ntf["r"]?.split(" "),
    );
  }

  Future<Down4Message> toDown4Message() async {
    Down4Media? m = mediaID != null || mediaID != ""
        ? await r.getMessageMedia(mediaID!)
        : null;
    return Down4Message(
      messageID: msgID,
      senderThumbnail: senderThumbnail,
      senderID: senderID,
      root: root,
      senderName: senderName,
      timestamp: timestamp,
      media: m,
      text: text,
      nodes: nodes,
      reactions: reactions,
      isChat: isChat,
      forwarderID: forwarderID,
      forwarderName: forwarderName,
      forwarderThumbnail: forwarderThumbnail,
    );
  }

  Future<Node?> nodeOfGroup() async {
    Down4Media? m;
    if (groupMediaID != null) {
      m = await r.getMessageMedia(groupMediaID!);
    }
    if (m != null &&
        groupName != null &&
        groupFriends != null &&
        groupID != null) {
      return Node(
        type: Nodes.group,
        id: groupID!,
        name: groupName!,
        image: m,
        group: groupFriends!,
        posts: [],
        messages: [],
        admins: [],
        childs: [],
        friends: [],
        parents: [],
        snips: [],
      );
    }
    return null;
  }

  Future<Node?> nodeOfHyperchat() async {
    Down4Media? m;
    if (hyperchatMediaID != null) {
      m = await r.getMessageMedia(hyperchatMediaID!);
    }
    if (m != null &&
        hyperchatName != null &&
        hyperchatFriends != null &&
        hyperchatID != null) {
      return Node(
        type: Nodes.hyperchat,
        id: hyperchatID!,
        name: hyperchatName!,
        image: m,
        group: hyperchatFriends!,
        friends: [],
        admins: [],
        messages: [],
        posts: [],
        childs: [],
        parents: [],
        snips: [],
      );
    }
    return null;
  }
}

class Down4Message {
  Identifier root;
  final Identifier messageID;
  final String? text;
  final Down4Media? media;
  final bool isChat; // true is chat, false is post
  final int timestamp;
  final List<Identifier>? reactions, nodes; // reactions, nodes

  final Identifier senderID;
  final String senderName;
  final String? senderLastName;
  final String senderThumbnail;

  final Identifier? forwarderID;
  final String? forwarderName, forwarderLastName;
  final String? forwarderThumbnail;

  Down4Message({
    required this.messageID,
    required this.root,
    required this.timestamp,
    required this.senderID,
    required this.senderName,
    required this.senderThumbnail,
    this.senderLastName,
    this.forwarderID,
    this.forwarderName,
    this.forwarderLastName,
    this.forwarderThumbnail,
    this.media,
    this.text,
    this.nodes,
    this.reactions,
    this.isChat = true,
  });

  Down4Message forwarded(Node self) {
    return Down4Message(
      messageID: messageID,
      root: root,
      text: text,
      timestamp: timestamp,
      senderID: senderID,
      senderName: senderName,
      senderThumbnail: senderThumbnail,
      forwarderID: self.id != senderID ? self.id : null,
      forwarderName: self.id != senderID ? self.name : null,
      forwarderThumbnail:
          self.id != senderID ? base64Encode(self.image.thumbnail!) : null,
      media: media,
      nodes: nodes,
      reactions: reactions,
      isChat: isChat,
    );
  }

  factory Down4Message.fromJson(Map<String, dynamic> decodedJson) {
    return Down4Message(
      root: decodedJson["rt"],
      messageID: decodedJson["msgid"],
      senderID: decodedJson["sdrid"],
      senderName: decodedJson["sdrnm"],
      senderLastName: decodedJson["sdrln"],
      senderThumbnail: decodedJson["sdrtn"],
      forwarderID: decodedJson["fdrid"],
      forwarderName: decodedJson["fdrnm"],
      forwarderLastName: decodedJson["fdrln"],
      forwarderThumbnail: decodedJson["fdrtn"],
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

  factory Down4Message.fromLocal(String id) {
    final decodedJson = jsonDecode(Boxes.instance.messages.get(id));
    return Down4Message.fromJson(decodedJson);
  }

  Map<String, dynamic> toJson([bool withMediaData = true]) => {
        'rt': root,
        'msgid': messageID,
        if (text != null) 'txt': text,
        'sdrid': senderID,
        'sdrtn': senderThumbnail,
        'sdrnm': senderName,
        if (senderLastName != null) 'sdrln': senderLastName!,
        'ts': timestamp,
        'ischt': isChat,
        if (forwarderID != null) 'fdrid': forwarderID,
        if (forwarderName != null) 'fdrnm': forwarderName,
        if (forwarderLastName != null) 'fdrln': forwarderLastName!,
        if (forwarderThumbnail != null) 'fdrtn': forwarderThumbnail,
        if (reactions != null) 'r': reactions,
        if (nodes != null) 'n': nodes,
        if (media != null)
          'm': withMediaData
              ? media!.toJson()
              : {
                  "id": media!.id,
                },
      };

  factory Down4Message.fromSave(String id) {
    Map<String, dynamic> saved = Boxes.instance.savedMessages.get(id);
    Down4Media? m;
    if (saved["m"]?["id"] != null) {
      m = Down4Media.fromSave(saved["m"]!["id"]);
    }
    saved["m"] = m;
    return Down4Message.fromJson(saved);
  }

  void save() {
    Boxes.instance.savedMessages.put(
      messageID,
      jsonEncode(toJson(false)),
    );
    media?.save();
  }

  void saveLocally() {
    Boxes.instance.messages.put(messageID, jsonEncode(this));
  }

  void deleteLocally() {
    Boxes.instance.messages.delete(messageID);
  }
}

class Node {
  final Identifier id;
  String name;
  String? lastName;
  Down4Media image;
  String? description;
  Nodes type;
  int activity;
  List<Identifier> admins = [];
  List<Identifier> childs = [];
  List<Identifier> parents = [];
  List<Identifier> friends = [];
  List<Identifier> snips = [];
  List<Identifier> group = [];
  List<Identifier> messages = [];
  List<Identifier> posts = []; // messages / either post or chat
  Node({
    required this.type,
    required this.id,
    required this.image,
    required this.name,
    this.description,
    this.activity = 0,
    this.lastName,
    required this.posts,
    required this.messages,
    required this.admins,
    required this.childs,
    required this.group,
    required this.parents,
    required this.friends,
    required this.snips,
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

  factory Node.fromLocal(Identifier id) {
    final decodedJson = jsonDecode(Boxes.instance.home.get(id));
    return Node.fromJson(decodedJson);
  }

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
        "pst": posts,
        "grp": group,
      };

  Map<String, dynamic> toLocal() => {
        "id": id,
        "t": type.name,
        "a": activity,
        "nm": name,
        "ln": lastName,
        "im": image.toJson(),
        "msg": messages,
        "adm": admins,
        "chl": childs,
        "prt": parents,
        "pst": posts,
        "grp": group,
      };

  void saveLocally() {
    Boxes.instance.home.put(id, jsonEncode(toLocal()));
  }

  void deleteLocally() {
    Boxes.instance.home.delete(id);
    for (final msgID in messages) {
      Boxes.instance.messages.delete(msgID);
    }
  }

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
  final List<Identifier> targets;
  bool? withUpload;
  final Node? rootNode;
  MessageRequest({
    required this.msg,
    required this.targets,
    this.rootNode,
    this.withUpload = false,
  });
  Map<String, dynamic> toJson() => {
        if (withUpload != null) "wu": withUpload,
        if (rootNode != null)
          "g": {
            "id": rootNode!.id,
            "im": rootNode!.image,
            "nm": rootNode!.name,
            if (rootNode!.lastName != null) "ln": rootNode!.lastName,
          },
        "msg": msg.toJson(withUpload == true),
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
