import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'down4_utility.dart' as u;
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
  self,
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
  self,
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
    this.isSaved = false,
    Set<Identifier>? references,
  })  : references = references ?? Set<Identifier>.identity(),
        super(id: id, metadata: metadata, path: path);

  bool get isVideo => metadata.isVideo;

  File? get file => path != null ? File(path!) : null;

  Set<Identifier> references;

  bool isSaved;

  NodeMedia asNodeMedia() {
    return NodeMedia(id: id, metadata: metadata, path: path);
  }

  factory MessageMedia.fromJson(dynamic decodedJson) {
    return MessageMedia(
        id: decodedJson["id"],
        metadata: MediaMetadata.fromJson(decodedJson["md"]),
        path: decodedJson["p"],
        isSaved: decodedJson["sv"] ?? false,
        references: Set<Identifier>.from(decodedJson["ref"]));
  }

  Map<String, dynamic> toJson({bool toLocal = false}) => {
        "id": id,
        "md": metadata.toJson(),
        if (toLocal) "sv": isSaved,
        if (toLocal) "ref": references.toList(),
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
      data: b64Data != "" && b64Data != null ? base64Decode(b64Data) : null,
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
  // final Messages type;
  final Identifier id;
  final Identifier senderID;
  final Identifier? root, forwarderID, mediaID;
  final String? text;
  final int timestamp;
  final List<Identifier>? replies, nodes; // reactions, nodes
  bool isRead, isSaved;

  Message({
    required this.senderID,
    // required this.type,
    required this.timestamp,
    required this.id,
    this.mediaID,
    this.isRead = false,
    this.isSaved = false,
    this.root,
    this.forwarderID,
    this.text,
    this.nodes,
    this.replies,
  });

  Message forwarded(BaseNode self) {
    return Message(
      // type: type,
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
      // type: Messages.values.byName(decodedJson["t"]),
      id: decodedJson["id"],
      senderID: decodedJson["s"],
      forwarderID: decodedJson["f"],
      isRead: decodedJson["rs"] ?? false,
      isSaved: decodedJson["sv"] ?? false,
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

  Map<String, dynamic> toJson({bool toLocal = false}) => {
        // 't': type.name,
        'id': id,
        if (root != null) 'rt': root!,
        if (text != null) 'txt': text,
        's': senderID,
        'ts': timestamp,
        if (mediaID != null) 'm': mediaID,
        if (toLocal) 'rs': isRead,
        if (toLocal) 'sv': isSaved,
        if (forwarderID != null) 'f': forwarderID,
        if (replies != null) 'r': replies!.join(" "),
        if (nodes != null) 'n': nodes!.join(" "),
      };
}

abstract class BaseNode {
  NodesColor get colorCode;
  Identifier id;
  String get name;
  String get displayID;
  Map toJson({bool toLocal});
  int activity;
  BaseNode({required this.id, int? activity}) : activity = activity ?? 0;
  void updateActivity([int? newActivity]) =>
      activity = newActivity ?? u.timeStamp();
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
          messages: Set<Identifier>.from(decodedJson["msg"] ?? []),
          snips: Set<Identifier>.from(decodedJson["snp"] ?? []),
          children: Set<Identifier>.from(decodedJson["chl"] ?? []),
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
          group: Set<Identifier>.from(decodedJson["grp"] ?? []),
          messages: Set<Identifier>.from(decodedJson["msg"] ?? []),
          snips: Set<Identifier>.from(decodedJson["snp"] ?? []),
          media: NodeMedia.fromJson(decodedJson["im"]),
          activity: decodedJson["a"],
        );

      case Nodes.group:
        return Group(
          isPrivate: decodedJson["pv"],
          name: decodedJson["nm"],
          id: id,
          media: NodeMedia.fromJson(decodedJson["im"]),
          group: Set<Identifier>.from(decodedJson["grp"]),
          messages: Set<Identifier>.from(decodedJson["msg"] ?? <Identifier>[]),
          snips: Set<Identifier>.from(decodedJson["snp"] ?? <Identifier>[]),
          activity: decodedJson["a"],
        );

      case Nodes.self:
        return Self(
          firstName: decodedJson["nm"],
          lastName: decodedJson["ln"],
          activity: decodedJson["a"],
          neuter: Down4Keys.fromYouKnow(decodedJson["nt"]),
          savedMessages: Set.from(decodedJson["svm"]),
          images: Set.from(decodedJson["img"]),
          videos: Set.from(decodedJson["vid"]),
          nfts: Set.from(decodedJson["nft"]),
          id: id,
          media: NodeMedia.fromJson(decodedJson["m"]),
          children: Set.from(decodedJson["chl"]),
          messages: Set.from(decodedJson["msg"]),
          snips: Set.from(decodedJson["snp"]),
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
  Set<Identifier> messages, snips;
  ChatableNode({
    required Identifier id,
    int? activity,
    required this.messages,
    required this.snips,
  }) : super(id: id, activity: activity);

  Set<Identifier> calculateTargets(Identifier selfID) {
    if (this is GroupNode) {
      return Set<Identifier>.from((this as GroupNode).group)..remove(selfID);
    }
    return {id};
  }
}

abstract class GroupNode extends ChatableNode {
  Set<Identifier> group;
  NodeMedia media;
  GroupNode({
    required Identifier id,
    required this.group,
    required this.media,
    int? activity,
    required Set<Identifier> messages,
    required Set<Identifier> snips,
  }) : super(id: id, activity: activity, messages: messages, snips: snips);
}

mixin Branchable {
  Set<Identifier> get children; // can we remove that if we have set
  set children(Set<Identifier> c);
}

abstract class Person extends ChatableNode with Branchable {
  String firstName;
  String? lastName, description;
  final Down4Keys neuter;
  Person({
    required this.firstName,
    required this.neuter,
    this.lastName,
    this.description,
    int? activity,
    required Identifier id,
    required Set<Identifier> messages,
    required Set<Identifier> snips,
  }) : super(id: id, messages: messages, snips: snips, activity: activity);

  @override
  String get displayID => "@$id";

  @override
  String get name => firstName + ((lastName != null) ? " $lastName" : "");
}

class User extends Person {
  NodeMedia? media;
  bool isFriend;
  @override
  Set<Identifier> children;

  User({
    this.isFriend = false,
    required Identifier id,
    required String firstName,
    this.media,
    String? lastName,
    String? description,
    required Down4Keys neuter,
    required Set<Identifier> messages,
    required Set<Identifier> snips,
    required this.children,
    int? activity,
  }) : super(
          id: id,
          neuter: neuter,
          activity: activity,
          messages: messages,
          snips: snips,
          firstName: firstName,
          lastName: lastName,
          description: description,
        );

  @override
  NodesColor get colorCode =>
      isFriend ? NodesColor.friend : NodesColor.nonFriend;

  @override
  Map toJson({bool toLocal = true, bool withMedia = true}) => {
        "t": Nodes.user.name,
        "id": id,
        if (toLocal) "if": isFriend,
        "nm": firstName,
        "nt": neuter.toYouKnow(),
        if (toLocal) "msg": messages.toList(),
        "chl": children.toList(),
        if (toLocal) "snp": snips.toList(),
        if (toLocal) "a": activity,
        if (lastName != null) "ln": lastName,
        if (media != null)
          "im": withMedia ? media!.toJson() : {"id": media!.id},
      };
}

class Self extends Person {
  Set<Identifier> images, videos, nfts, savedMessages;
  NodeMedia media;

  @override
  Set<Identifier> children;

  Self({
    required String firstName,
    String? lastName,
    String? description,
    required Down4Keys neuter,
    required this.images,
    required this.videos,
    required this.nfts,
    required this.savedMessages,
    required Identifier id,
    int? activity,
    required this.media,
    required this.children,
    required Set<Identifier> messages,
    required Set<Identifier> snips,
  }) : super(
          id: id,
          messages: messages,
          neuter: neuter,
          snips: snips,
          firstName: firstName,
          lastName: lastName,
          activity: activity,
          description: description,
        );

  @override
  Map<String, dynamic> toJson({bool toLocal = true}) => {
        "t": toLocal ? Nodes.self.name : Nodes.user.name,
        "id": id,
        "nm": firstName,
        if (lastName != null) "ln": lastName,
        "chl": children.toList(),
        "nt": neuter.toYouKnow(),
        if (toLocal) "img": images.toList(),
        if (toLocal) "vid": videos.toList(),
        if (toLocal) "nft": nfts.toList(),
        if (toLocal) "msg": messages.toList(),
        if (toLocal) "snp": snips.toList(),
        if (toLocal) "svm": savedMessages.toList(),
        if (toLocal) "a": activity,
        if (toLocal) "m": media.toJson(withData: true, withPath: true),
      };

  @override
  NodesColor get colorCode => NodesColor.self;
}

class Group extends GroupNode {
  @override
  String name;
  bool isPrivate;
  Group({
    required this.isPrivate,
    required this.name,
    required Identifier id,
    required NodeMedia media,
    required Set<Identifier> group,
    required Set<Identifier> messages,
    required Set<Identifier> snips,
    int? activity,
  }) : super(
          id: id,
          media: media,
          group: group,
          activity: activity,
          messages: messages,
          snips: snips,
        );

  @override
  String get displayID => group.map((id) => "@$id").join(" ");

  @override
  NodesColor get colorCode => NodesColor.group;

  @override
  Map toJson({bool withMedia = true, bool toLocal = true}) => {
        "t": Nodes.group.name,
        "pv": isPrivate,
        "im": withMedia ? media.toJson() : media.id,
        "nm": name,
        "id": id,
        "grp": group.toList(),
        if (toLocal) "msg": messages.toList(),
        if (toLocal) "snp": snips.toList(),
        "a": activity,
      };
}

class Hyperchat extends GroupNode {
  final String firstWord, secondWord;
  Hyperchat({
    required Identifier id,
    required this.firstWord,
    required this.secondWord,
    required Set<Identifier> group,
    required Set<Identifier> messages,
    required Set<Identifier> snips,
    required NodeMedia media,
    int? activity,
  }) : super(
            id: id,
            media: media,
            group: group,
            activity: activity,
            messages: messages,
            snips: snips);

  @override
  String get displayID => group.map((id) => "@$id").join(" ");

  @override
  String get name => "$firstWord $secondWord";

  @override
  NodesColor get colorCode => NodesColor.hyperchat;

  @override
  Map toJson({bool toLocal = true}) => {
        "t": Nodes.hyperchat.name,
        "id": id,
        "nm": firstWord,
        "ln": secondWord,
        "im": media.toJson(),
        "a": activity,
        "grp": group.toList(),
        "msg": messages.toList(),
        "snp": snips.toList(),
      };
}

class Payment extends BaseNode {
  final Down4Payment _payment;
  Payment({required Down4Payment payment})
      : _payment = payment,
        super(id: payment.id);

  @override
  String get name => payment.formattedName;

  Down4Payment get payment => _payment;

  @override
  String get displayID =>
      "Confirmations: ${_payment.lastConfirmations > 100 ? "100+" : _payment.lastConfirmations}";

  @override
  NodesColor get colorCode => _payment.lastConfirmations == 0
      ? NodesColor.unsafeTx
      : _payment.lastConfirmations < 6
          ? NodesColor.mediumTx
          : NodesColor.safeTx;

  @override
  Map toJson({bool toLocal = true}) => {
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
      isVideo: decodedJson["vid"] == "true",
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
