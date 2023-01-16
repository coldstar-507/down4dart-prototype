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

abstract class Media {
  final Identifier id;
  String? path;
  MediaMetadata metadata;
  Media({
    required this.id,
    required this.metadata,
    this.path,
  });

  String get url;
}

class MessageMedia extends Media {
  MessageMedia({
    required Identifier id,
    required MediaMetadata metadata,
    String? path,
  }) : super(id: id, metadata: metadata, path: path);

  NodeMedia asNodeMedia() {
    return NodeMedia(id: id, metadata: metadata, path: path);
  }

  factory MessageMedia.fromJson(dynamic decodedJson) {
    return MessageMedia(
      id: decodedJson["id"],
      metadata: MediaMetadata.fromJson(decodedJson["md"]),
      path: decodedJson["p"],
    );
  }

  Map<String, dynamic> toJson({bool toLocal = false}) => {
        "id": id,
        "md": metadata.toJson(),
        if (path != null && toLocal) "p": path!,
      };

  @override
  String get url => "https://storage.googleapis.com/down4-26ee1-messages/$id";
}

class NodeMedia extends Media {
  NodeMedia({
    required Identifier id,
    required MediaMetadata metadata,
    String? path,
    this.data,
  }) : super(id: id, metadata: metadata, path: path);

  Uint8List? data;

  MessageMedia asMessageMedia() {
    return MessageMedia(id: id, metadata: metadata, path: path);
  }

  factory NodeMedia.fromJson(dynamic decodedJson) {
    final b64Data = decodedJson["d"];
    return NodeMedia(
      id: decodedJson["id"],
      metadata: MediaMetadata.fromJson(decodedJson["md"]),
      path: decodedJson["p"],
      data: b64Data != "" || b64Data != null ? base64Decode(b64Data) : null,
    );
  }

  @override
  String get url => "https://storage.googleapis.com/down4-26ee1-nodes/$id";

  @override
  Map<String, dynamic> toJson({bool withData = true, bool withPath = false}) =>
      {
        "id": id,
        "md": metadata.toJson(),
        if (path != null && withPath) "p": path,
        if (data != null && withData) "d": base64Encode(data!),
      };
}

class MessageNotification {
  final Messages type;
  final String? base64jsonData;
  MessageNotification({required this.type, this.base64jsonData});
}

class Message {
  final Messages type;
  final Identifier id;
  final Identifier senderID;
  final Identifier? root, forwarderID, mediaID;
  final String? text;
  final int timestamp;
  final List<Identifier>? replies, nodes; // reactions, nodes
  bool read;

  Message({
    required this.senderID,
    required this.type,
    required this.timestamp,
    required this.id,
    this.mediaID,
    this.read = false,
    this.root,
    this.forwarderID,
    this.text,
    this.nodes,
    this.replies,
  });

  Message forwarded(BaseNode self) {
    return Message(
      type: type,
      id: id,
      text: text,
      timestamp: timestamp,
      senderID: senderID,
      forwarderID: self.id != senderID ? self.id : null,
      mediaID: mediaID,
      nodes: nodes,
      replies: replies,
    );
  }

  factory Message.fromJson(Map<String, dynamic> decodedJson) {
    print("decodedJson message: $decodedJson");
    return Message(
      type: Messages.values.byName(decodedJson["t"]),
      id: decodedJson["id"],
      senderID: decodedJson["s"],
      forwarderID: decodedJson["f"],
      read: decodedJson["rs"] ?? false,
      text: decodedJson["txt"],
      mediaID: decodedJson["m"],
      // mediaID: decodedJson["m"],
      // paymentID: decodedJson["p"],
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

  Map<String, dynamic> toJson({bool withReadStatus = false}) => {
        't': type.name,
        'id': id,
        if (root != null) 'rt': root!,
        if (text != null) 'txt': text,
        's': senderID,
        'ts': timestamp,
        if (mediaID != null) 'm': mediaID,
        if (withReadStatus) 'rs': read,
        if (forwarderID != null) 'f': forwarderID,
        if (replies != null) 'r': replies!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
      };
}

abstract class BaseNode {
  NodesColor get colorCode;
  Identifier get id;
  String get name;
  String get displayID;
  Map toJson();
  int activity;
  BaseNode({int? activity}) : activity = activity ?? 0;
  void updateActivity([int? newActivity]) =>
      activity = newActivity ?? d4utils.timeStamp();
  factory BaseNode.fromJson(dynamic decodedJson) {
    print("""
    ================================================
    decodedJson: $decodedJson
    ================================================
    """);
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
              ? NodeMedia.fromJson(decodedJson["im"])
              : null,
        );

      case Nodes.hyperchat:
        return Hyperchat(
          id: id,
          firstWord: decodedJson["nm"],
          secondWord: decodedJson["ln"],
          group: List<Identifier>.from(decodedJson["grp"] ?? []),
          messages: List<Identifier>.from(decodedJson["msg"] ?? []),
          snips: List<Identifier>.from(decodedJson["snp"] ?? []),
          media: NodeMedia.fromJson(decodedJson["im"]),
          activity: decodedJson["a"],
        );

      case Nodes.group:
        return Group(
          isPrivate: decodedJson["pv"],
          name: decodedJson["nm"],
          id: id,
          media: NodeMedia.fromJson(decodedJson["im"]),
          group: List<Identifier>.from(decodedJson["grp"]),
          messages: List<Identifier>.from(decodedJson["msg"] ?? <Identifier>[]),
          snips: List<Identifier>.from(decodedJson["snp"] ?? <Identifier>[]),
          activity: decodedJson["a"],
        );

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
        return Payment(payment: Down4Payment.fromYouKnow(decodedJson["pay"]));
    }
    throw 'invalid node type: $type';
  }
}

abstract class ChatableNode extends BaseNode {
  List<Identifier> messages, snips;
  ChatableNode({int? activity, required this.messages, required this.snips})
      : super(activity: activity);

  List<Identifier> calculateTargets(Identifier selfID) {
    if (this is GroupNode) {
      return List<Identifier>.from((this as GroupNode).group)..remove(selfID);
    }
    return [id];
  }
}

abstract class GroupNode extends ChatableNode {
  List<Identifier> get group;
  set group(List<Identifier> group);
  Media get media;
  GroupNode({
    int? activity,
    required List<Identifier> messages,
    required List<Identifier> snips,
  }) : super(activity: activity, messages: messages, snips: snips);
}

abstract class BranchNode extends BaseNode {
  List<Identifier> get children;
  set children(List<Identifier> children);
}

class User extends ChatableNode implements BranchNode {
  final Identifier id;
  final Down4Keys neuter;
  String firstName;
  List<Identifier> children;
  NodeMedia? media;
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

  String get displayID => "@$id";

  String get name => firstName + ((lastName != null) ? " $lastName" : "");

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
  NodeMedia media;
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
        "im": withMedia ? media.toJson() : media.id,
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
  final NodeMedia media;
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
        "nm": firstWord,
        "ln": secondWord,
        "im": media.toJson(),
        "a": activity,
        "grp": group,
        "msg": messages,
        "snp": snips,
      };
}

class Payment extends BaseNode {
  final Down4Payment _payment;
  final Identifier id;
  final String name;
  Payment({required Down4Payment payment})
      : _payment = payment,
        id = payment.id,
        name = payment.formattedName;

  Down4Payment get payment => _payment;

  String get displayID =>
      "Confirmations: ${_payment.lastConfirmations > 100 ? "100+" : _payment.lastConfirmations}";

  NodesColor get colorCode => _payment.lastConfirmations == 0
      ? NodesColor.unsafeTx
      : _payment.lastConfirmations < 6
          ? NodesColor.mediumTx
          : NodesColor.safeTx;

  Map toJson() => {
        "t": Nodes.payment.name,
        "pay": _payment.toYouKnow(),
      };
}

class MediaMetadata {
  final bool isReversed,
      isLocked,
      isPaidToView,
      isPaidToOwn,
      isSquared,
      isVideo,
      canSkipCheck;
  final Identifier owner;
  final double elementAspectRatio;
  final String? text;
  int timestamp;
  MediaMetadata({
    required this.owner,
    required this.timestamp,
    required this.elementAspectRatio,
    this.isVideo = false,
    this.isLocked = false,
    this.canSkipCheck = false,
    this.isPaidToView = false,
    this.isReversed = false,
    this.isPaidToOwn = false,
    this.isSquared = false,
    this.text,
  });

  MediaMetadata updatedTimestamp(int newTimeStamp) {
    return MediaMetadata(
      owner: owner,
      timestamp: newTimeStamp,
      elementAspectRatio: elementAspectRatio,
      isVideo: isVideo,
      isReversed: isReversed,
      isPaidToOwn: isPaidToOwn,
      canSkipCheck: false,
      isPaidToView: isPaidToView,
      isSquared: isSquared,
      isLocked: isLocked,
      text: text,
    );
  }

  factory MediaMetadata.fromJson(Map<String, dynamic> decodedJson) {
    return MediaMetadata(
      owner: decodedJson["o"],
      timestamp: int.parse(decodedJson["ts"]),
      isReversed: decodedJson["trv"] == "true",
      isLocked: decodedJson["lck"] == "true",
      isPaidToView: decodedJson["ptv"] == "true",
      isPaidToOwn: decodedJson["pto"] == "true",
      canSkipCheck: decodedJson["csc"] == "true",
      text: decodedJson["txt"],
      isSquared: decodedJson["sqr"] == "true",
      elementAspectRatio: double.tryParse(decodedJson["ar"]) ?? 1.0,
    );
  }

  Map<String, String> toJson() {
    return {
      "o": owner,
      "ts": timestamp.toString(),
      "trv": isReversed.toString(),
      "sqr": isSquared.toString(),
      "lck": isLocked.toString(),
      "ptv": isPaidToView.toString(),
      "csc": canSkipCheck.toString(),
      "pto": isPaidToOwn.toString(),
      "ar": elementAspectRatio.toString(),
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

  Location copy() => Location(
        id: id,
        at: at,
        type: type,
        pageIndex: pageIndex,
        scroll: scroll,
      );
}

class ExchangeRate {
  int lastUpdate;
  double rate;
  ExchangeRate({required this.lastUpdate, required this.rate});

  factory ExchangeRate.fromJson(dynamic decodedJson) {
    return ExchangeRate(
      lastUpdate: decodedJson["lastUpdate"],
      rate: decodedJson["rate"],
    );
  }

  Map<String, dynamic> toJson() => {
        "rate": rate,
        "lastUpdate": lastUpdate,
      };
}
