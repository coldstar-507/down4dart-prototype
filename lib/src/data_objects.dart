import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'down4_utility.dart' as d4utils;
import 'bsv/types.dart';

typedef Identifier = String;

enum Messages {
  chat,
  payment,
  bill,
  snip,
}

enum Nodes {
  user,
  hyperchat,
  group,
  root,
  market,
  checkpoint,
  journal,
  item,
  event,
  ticket,
  payment,
}

enum NodesColor {
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
  safeTx,
  mediumTx,
  unsafeTx,
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
  final Messages type;
  final Identifier id;
  final Identifier senderID;
  final Identifier? root, forwarderID, paymentID, mediaID;
  final String? text;
  final int timestamp;
  final List<Identifier>? replies, nodes; // reactions, nodes

  Down4Message({
    required this.senderID,
    required this.type,
    required this.timestamp,
    required this.id,
    this.root,
    this.mediaID,
    this.paymentID,
    this.forwarderID,
    this.text,
    this.nodes,
    this.replies,
  });

  Down4Message forwarded(BaseNode self) {
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
    print("decodedJson message: $decodedJson");
    return Down4Message(
      type: Messages.values.byName(decodedJson["t"]),
      id: decodedJson["id"],
      senderID: decodedJson["s"],
      forwarderID: decodedJson["f"],
      text: decodedJson["txt"],
      mediaID: decodedJson["m"],
      paymentID: decodedJson["p"],
      timestamp: decodedJson["ts"],
      root: decodedJson["rt"],
      replies: (decodedJson["r"] ?? "").isNotEmpty
          ? List<String>.from(decodedJson["r"].split(" "))
          : null,
      nodes: (decodedJson["n"] ?? "").isNotEmpty
          ? List<String>.from(decodedJson["n"].split(" "))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        't': type.name,
        'id': id,
        if (root != null) 'rt': root!,
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

// class Node {
//   final Identifier id;
//   final Down4Keys? neuter;
//
//   final Down4Payment? payment;
//
//   String name;
//   String? lastName;
//   Down4Media? image;
//   String? description;
//   Nodes type;
//   int activity;
//   List<Identifier>? admins;
//   List<Identifier>? childs;
//   List<Identifier>? parents;
//   List<Identifier>? friends;
//   List<Identifier>? snips;
//   List<Identifier>? group;
//   List<Identifier>? messages;
//   List<Identifier>? posts; // messages / either post or chat
//   Node({
//     required this.type,
//     required this.id,
//     required this.name,
//     this.image,
//     this.neuter,
//     this.payment,
//     this.description,
//     this.activity = 0,
//     this.lastName,
//     this.posts,
//     this.messages,
//     this.admins,
//     this.childs,
//     this.group,
//     this.parents,
//     this.friends,
//     this.snips,
//   });
//
//   void mutateType(Nodes t) => type = t;
//
//   void updateActivity() => activity = d4utils.timeStamp();
//
//   void merge(Node mergeNode) {
//     childs = mergeNode.childs;
//     parents = mergeNode.parents;
//     admins = mergeNode.admins;
//     friends = mergeNode.friends;
//     posts = mergeNode.posts;
//     description = mergeNode.description;
//     image = mergeNode.image;
//     name = mergeNode.name;
//     lastName = mergeNode.lastName;
//   }
//
//   factory Node.fromJson(Map<String, dynamic> decodedJson) {
//     return Node(
//       id: decodedJson["id"],
//       name: decodedJson["nm"],
//       neuter: decodedJson["nt"] != null
//           ? Down4Keys.fromYouKnow(decodedJson["nt"])
//           : null,
//       lastName: decodedJson["ln"],
//       activity: decodedJson["a"] ?? 0,
//       image: decodedJson["im"] != null
//           ? Down4Media.fromJson(decodedJson["im"])
//           : null,
//       type: Nodes.values.byName(decodedJson["t"]),
//       messages: decodedJson["msg"] != null
//           ? List<String>.from(decodedJson["msg"])
//           : null,
//       admins: decodedJson["adm"] != null
//           ? List<String>.from(decodedJson["adm"])
//           : null,
//       childs: decodedJson["chl"] != null
//           ? List<String>.from(decodedJson["chl"])
//           : null,
//       parents: decodedJson["prt"] != null
//           ? List<String>.from(decodedJson["prt"])
//           : null,
//       posts: decodedJson["pst"] != null
//           ? List<String>.from(decodedJson["pst"])
//           : null,
//       group: decodedJson["grp"] != null
//           ? List<String>.from(decodedJson["grp"])
//           : null,
//       friends: decodedJson["frd"] != null
//           ? List<String>.from(decodedJson["frd"])
//           : null,
//       snips: decodedJson["snp"] != null
//           ? List<String>.from(decodedJson["snp"])
//           : null,
//     );
//   }
//
//   Map<String, dynamic> toJson([bool withMedia = true]) => {
//         "id": id,
//         "t": type.name,
//         "a": activity,
//         "nm": name,
//         if (neuter != null) "nt": neuter!.toYouKnow(),
//         if (lastName != null) "ln": lastName,
//         if (image != null) "im": withMedia ? image!.toJson() : image!.id,
//         if (messages != null) "msg": messages,
//         if (admins != null) "adm": admins,
//         if (childs != null) "chl": childs,
//         if (parents != null) "prt": parents,
//         if (posts != null) "pst": posts,
//         if (group != null) "grp": group,
//         if (snips != null) "snp": snips,
//       };
// }

abstract class BaseNode {
  NodesColor get colorCode;
  Identifier get id;
  String get name;
  String get displayID;
  // Image get image;
  Map toJson();
  int activity;
  BaseNode({int? activity}) : activity = activity ?? 0;
  void updateActivity() => activity = d4utils.timeStamp();
  factory BaseNode.fromJson(dynamic decodedJson) {
    final type = Nodes.values.byName(decodedJson["t"]);
    final id = decodedJson["id"];
    switch (type) {
      case Nodes.user:
        return User(
          id: id,
          firstName: decodedJson["nm"],
          isFriend: decodedJson["if"] ?? false,
          neuter: Down4Keys.fromYouKnow(decodedJson["nt"]),
          messages: List<Identifier>.from(decodedJson["msg"] ?? []),
          snips: List<Identifier>.from(decodedJson["snp"] ?? []),
          children: List<Identifier>.from(decodedJson["chl"] ?? []),
          lastName: decodedJson["ln"],
          activity: decodedJson["a"],
          media: decodedJson["im"]?["d"] != null
              ? Down4Media.fromJson(decodedJson["im"])
              : null,
        );

      case Nodes.hyperchat:
        // TODO: Handle this case.
        break;
      case Nodes.group:
        // TODO: Handle this case.
        break;
      case Nodes.root:
        // TODO: Handle this case.
        break;
      case Nodes.market:
        // TODO: Handle this case.
        break;
      case Nodes.checkpoint:
        // TODO: Handle this case.
        break;
      case Nodes.journal:
        // TODO: Handle this case.
        break;
      case Nodes.item:
        // TODO: Handle this case.
        break;
      case Nodes.event:
        // TODO: Handle this case.
        break;
      case Nodes.ticket:
        // TODO: Handle this case.
        break;
      case Nodes.payment:
        // TODO: Handle this case.
        break;
    }
    throw 'invalid node type: $type';
  }
}

abstract class ChatableNode extends BaseNode {
  List<Identifier> messages, snips;
  ChatableNode({int? activity, required this.messages, required this.snips})
      : super(activity: activity);

  List<Identifier> targets(Identifier selfID) {
    if (this is GroupNode) {
      return (this as GroupNode).group..remove(selfID);
    }
    return [id];
  }
}

abstract class GroupNode extends ChatableNode {
  List<Identifier> get group;
  set group(List<Identifier> group);
  Down4Media get media;
  // Image get image => Image.memory(
  //       media.data,
  //       fit: BoxFit.cover,
  //       gaplessPlayback: true,
  //     );
  GroupNode({
    int? activity,
    required List<Identifier> messages,
    required List<Identifier> snips,
  }) : super(activity: activity, messages: messages, snips: snips);
} // interface

abstract class BranchNode extends BaseNode {
  List<Identifier> get children;
  set children(List<Identifier> children);
} // interface

class User extends ChatableNode implements BranchNode {
  final Identifier id;
  final Down4Keys neuter;
  String firstName;
  List<Identifier> children;
  Down4Media? media;
  String? lastName;
  bool isFriend;
  String description;

  User({
    this.isFriend = false,
    required this.id,
    required this.firstName,
    this.media,
    this.lastName,
    required this.neuter,
    required List<Identifier> messages,
    required List<Identifier> snips,
    required this.children,
    String? description,
    int? activity,
  })  : description = description ?? "",
        super(activity: activity, messages: messages, snips: snips);

  String get displayID => "@" + id;

  String get name => firstName + ((lastName != null) ? lastName! : "");

  // Image get image => media != null
  //     ? Image.memory(media!.data, fit: BoxFit.cover)
  //     : Image.asset('lib/src/assets/hashirama.jpg', fit: BoxFit.cover);

  NodesColor get colorCode =>
      isFriend ? NodesColor.friend : NodesColor.nonFriend;

  Map toJson({bool toLocal = true, bool withMedia = true}) => {
        "t": Nodes.user.name,
        "id": id,
        if (toLocal) "if": isFriend,
        "nm": firstName,
        "nt": neuter.toYouKnow(),
        if (toLocal) "msg": messages,
        "chl": children,
        if (toLocal) "snp": snips,
        if (toLocal) "a": activity,
        if (lastName != null) "ln": lastName,
        if (media != null)
          "im": withMedia ? media!.toJson() : {"id": media!.id},
      };
}

class Group extends GroupNode {
  Identifier id;
  bool isPrivate;
  Down4Media media;
  String name;
  List<Identifier> group;
  Group({
    required this.isPrivate,
    required this.name,
    required this.id,
    required this.media,
    required this.group,
    required List<Identifier> messages,
    required List<Identifier> snips,
    int? activity,
  }) : super(activity: activity, messages: messages, snips: snips);

  String get displayID => group.map((id) => "@" + id).join(" ");

  NodesColor get colorCode => NodesColor.group;

  Map toJson({bool withMedia = true, bool toLocal = true}) => {
        "t": Nodes.group.name,
        "pv": isPrivate,
        "m": withMedia ? media.toJson() : media.id,
        "nm": name,
        "id": id,
        "grp": group,
        if (toLocal) "msg": messages,
        if (toLocal) "snp": snips,
        "a": activity,
      };
}

class Hyperchat extends GroupNode {
  final Identifier id;
  final String firstWord, secondWord;
  final Down4Media media;
  List<Identifier> group;
  Hyperchat({
    required this.id,
    required this.firstWord,
    required this.secondWord,
    required this.group,
    required List<Identifier> messages,
    required List<Identifier> snips,
    required this.media,
    int? activity,
  }) : super(activity: activity, messages: messages, snips: snips);

  String get displayID => group.map((id) => "@" + id).join(" ");

  String get name => firstWord + " " + secondWord;

  NodesColor get colorCode => NodesColor.hyperchat;

  Map toJson() => {
        "t": Nodes.hyperchat.name,
        "id": id,
        "fw": firstWord,
        "sw": secondWord,
        "im": media.toJson(),
        "a": activity,
        "grp": group,
        "msg": messages,
        "snp": snips,
      };
}

class Payment extends BaseNode {
  final Down4Payment payment;
  final Identifier id;
  final String name;
  Payment({required Down4Payment payment})
      : payment = payment,
        id = payment.id,
        name = payment.formattedName;

  String get displayID => "Confirmations: ${payment.lastConfirmations}";

  // Image get image => payment.independentGets < 2000000
  //     ? Image.asset('lib/src/assets/Dollar_Sign_1.png', fit: BoxFit.cover)
  //     : payment.independentGets < 10000000
  //         ? Image.asset('lib/src/assets/Dollar_Sign_2.png', fit: BoxFit.cover)
  //         : Image.asset('lib/src/assets/Dollar_Sign_3.png', fit: BoxFit.cover);

  NodesColor get colorCode => payment.lastConfirmations < 3
      ? NodesColor.unsafeTx
      : payment.lastConfirmations < 6
          ? NodesColor.mediumTx
          : NodesColor.safeTx;

  Map toJson() => {
        "t": Nodes.payment.name,
        "pay": payment.toYouKnow(),
      };
}

// class UserNode implements BaseNode {
//   String name;
//   String? lastName, description;
//   final Down4Keys neuter;
//   Down4Media media;
//   int activity;
//   List<Identifier> childs, snips,
//
// }

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

class Location {
  final String id;
  final String? at, type;
  int pageIndex;
  double? scroll;
  Location({
    required this.id,
    this.at,
    this.type,
    this.pageIndex = 0,
    this.scroll,
  });
}

class ExchangeRate {
  int lastUpdate;
  double rate;
  ExchangeRate({required this.lastUpdate, required this.rate});

  factory ExchangeRate.fromJson(dynamic decodedJson) {
    return ExchangeRate(
      lastUpdate: decodedJson["rate"],
      rate: decodedJson["lastUpdate"],
    );
  }

  Map<String, dynamic> toJson() => {
        "rate": rate,
        "lastUpdate": lastUpdate,
      };
}
