// import 'package:down4/src/_down4_dart_utils.dart';
import 'package:realm/realm.dart'; // import realm package

import 'bsv/types.dart' show Down4Keys;
//     show Down4Payment, Down4TXIN, Down4TXOUT, Down4TX, Down4Keys;

import '_down4_dart_utils.dart' show timeStamp;

import 'data_objects.dart' show Nodes, NodesColor;

part 'realm.g.dart'; // declare a part file.

typedef ID = String;

final config = Configuration.local([
  RNode.schema,
  RMedia.schema,
  RMessage.schema,
]);

final realm = Realm(config);

@RealmModel()
class _RPayment {
  @PrimaryKey()
  late ID id;
  late Set<_RTX> txs;
  late String? textNote;
  late bool safe;
  late int tsSeconds;
}

@RealmModel()
class _RUTXO {
  @PrimaryKey()
  late ID id;
  late String scriptPubKey;
  late int scriptPubKeyLen;
  late bool isChange;
  late bool isFee;
  late ID receiver;
  late int outIndex;
  late String secret;
  late String txid;
  late int sats;
}

@RealmModel(ObjectType.embeddedObject)
class _RTXIN {
  late ID spender;
  late int scriptSigLen;
  late String utxoTXID;
  late int utxoIndex;
  late String scriptSig;
  late int sequenceNo;
}

@RealmModel()
class _RTX {
  @PrimaryKey()
  late ID id;
  late ID maker;
  late String down4Secret;
  late int versionNo, nLockTime;
  late Set<_RTXIN> txsIn;
  late Set<_RUTXO> txsOut;
  late int inCounter, outCounter;
  late String txID;
  late int confirmations;
}

@RealmModel()
class _RMedia {
  @PrimaryKey()
  late ID id;
  late String data;
  late String metadata;
  @Indexed()
  late bool isSaved;
  @Indexed()
  late int lastUse;
}

@RealmModel()
class _RMessage {
  @PrimaryKey()
  late ID id;
  late ID senderID;
  late ID? mediaID;
  late String? text;
  late ID? replies, nodes;
  late ID? forwarderID;
  late int timestamp;
  late String sents, reads;
}

@RealmModel()
class _RNode {
  @PrimaryKey()
  late ID id;
  late String name;
  late String type;
  late int activity;

  late _RMedia? media;
  late String? keys;
  late String? lastName, description;
  late Set<_RNode> public, private, group;
  late Set<_RMedia> snips;
  late Set<_RMessage> messages;
  late bool? isFriend;
}

abstract class BaseNode {
  ID get id;
  _RMedia? get media;
  NodesColor get colorCode;
  String get name;
  String get displayID;
  Map<String, dynamic> toJson({bool toLocal});
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
          messages: Set<ID>.from(decodedJson["msg"] ?? []),
          snips: Set<ID>.from(decodedJson["snp"] ?? []),
          children: Set<ID>.from(decodedJson["chl"] ?? []),
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
          group: Set<ID>.from(decodedJson["grp"] ?? []),
          messages: Set<ID>.from(decodedJson["msg"] ?? []),
          snips: Set<ID>.from(decodedJson["snp"] ?? []),
          media: NodeMedia.fromJson(decodedJson["im"]),
          activity: decodedJson["a"],
        );

      case Nodes.group:
        return Group(
          isPrivate: decodedJson["pv"],
          name: decodedJson["nm"],
          id: id,
          media: NodeMedia.fromJson(decodedJson["im"]),
          group: Set<ID>.from(decodedJson["grp"]),
          messages: Set<ID>.from(decodedJson["msg"] ?? <ID>[]),
          snips: Set<ID>.from(decodedJson["snp"] ?? <ID>[]),
          activity: decodedJson["a"],
        );

      case Nodes.self:
        return Self(
          firstName: decodedJson["nm"],
          lastName: decodedJson["ln"],
          activity: decodedJson["a"],
          neuter: Down4Keys.fromYouKnow(decodedJson["nt"]),
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
        break;
      // return Payment(payment: Down4Payment.fromYouKnow(decodedJson["pay"]));
    }
    throw 'invalid node type: $type';
  }
}

abstract class ChatableNode implements BaseNode {
  int get activity;
  Set<_RMessage> get messages;
  Set<_RMedia> get snips;
  set messages(Set<_RMessage> messages);
  set snips(Set<_RMedia> messages);
}

abstract class BranchableNode implements ChatableNode {
  Set<ID> get children;
  set children(Set<ID> children);
}

abstract class GroupNode extends ChatableNode {
  Set<Person> get group;
  @override
  RMedia get media;
}

abstract class Person implements BranchableNode {
  String get firstName;
  set firstName(String firstName);
  String? get lastName;
  set lastName(String? lastName);
  String? get description;
  set description(String? description);
  Down4Keys get neuter;
}

@RealmModel()
class _User implements Person {
  @override
  late int activity;

  @override
  late final ID id;

  @override
  late _RMedia? media;

  @override
  late Set<ID> children;

  @override
  late Set<_RMedia> snips;
  @override
  late Set<_RMessage> messages;

  @override
  String get displayID => "@$id";

  @override
  String get name => firstName + ((lastName != null) ? " $lastName" : "");

  late bool isFriend;
  @override
  late String firstName;
  @override
  late String? lastName, description;
  late final String rawKeys;

  @override
  Down4Keys get neuter => Down4Keys.fromYouKnow(rawKeys);

  @override
  NodesColor get colorCode =>
      isFriend ? NodesColor.friend : NodesColor.nonFriend;

  @override
  Map<String, dynamic> toJson({bool toLocal = true}) => {
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
        // if (toLocal) "im": media!.toJson() else "im": media!.id,
      };
}

// class Self extends Person {
//   Set<ID> images, videos, nfts;
//   @override
//   NodeMedia media;

//   @override
//   Set<ID> children;

//   Self({
//     required String firstName,
//     String? lastName,
//     String? description,
//     required Down4Keys neuter,
//     required this.images,
//     required this.videos,
//     required this.nfts,
//     required ID id,
//     int? activity,
//     required this.media,
//     required this.children,
//     required Set<ID> messages,
//     required Set<ID> snips,
//   }) : super(
//           id: id,
//           messages: messages,
//           neuter: neuter,
//           snips: snips,
//           firstName: firstName,
//           lastName: lastName,
//           activity: activity,
//           description: description,
//         );

//   @override
//   Map<String, dynamic> toJson({bool toLocal = true}) => {
//         "t": toLocal ? Nodes.self.name : Nodes.user.name,
//         "id": id,
//         "nm": firstName,
//         if (lastName != null) "ln": lastName,
//         "chl": children.toList(),
//         "nt": neuter.toYouKnow(),
//         if (toLocal) "img": images.toList(),
//         if (toLocal) "vid": videos.toList(),
//         if (toLocal) "nft": nfts.toList(),
//         if (toLocal) "msg": messages.toList(),
//         if (toLocal) "snp": snips.toList(),
//         if (toLocal) "a": activity,
//         if (toLocal) "m": media.toJson() else "m": media.id,
//       };

//   @override
//   NodesColor get colorCode => NodesColor.self;
// }

// class Group extends GroupNode {
//   @override
//   String name;
//   bool isPrivate;
//   Group({
//     required this.isPrivate,
//     required this.name,
//     required ID id,
//     required NodeMedia media,
//     required Set<ID> group,
//     required Set<ID> messages,
//     required Set<ID> snips,
//     int? activity,
//   }) : super(
//           id: id,
//           media: media,
//           group: group,
//           activity: activity,
//           messages: messages,
//           snips: snips,
//         );

//   @override
//   String get displayID => group.map((id) => "@$id").join(" ");

//   @override
//   NodesColor get colorCode => NodesColor.group;

//   @override
//   Map<String, dynamic> toJson({bool toLocal = true}) => {
//         "t": Nodes.group.name,
//         "pv": isPrivate,
//         "im": toLocal ? media.toJson() : media.id,
//         "nm": name,
//         "id": id,
//         "grp": group.toList(),
//         if (toLocal) "msg": messages.toList(),
//         if (toLocal) "snp": snips.toList(),
//         if (toLocal) "a": activity,
//       };
// }

// class Hyperchat extends GroupNode {
//   final String firstWord, secondWord;
//   Hyperchat({
//     required ID id,
//     required this.firstWord,
//     required this.secondWord,
//     required Set<ID> group,
//     required Set<ID> messages,
//     required Set<ID> snips,
//     required NodeMedia media,
//     int? activity,
//   }) : super(
//             id: id,
//             media: media,
//             group: group,
//             activity: activity,
//             messages: messages,
//             snips: snips);

//   @override
//   String get displayID => group.map((id) => "@$id").join(" ");

//   @override
//   String get name => "$firstWord $secondWord";

//   @override
//   NodesColor get colorCode => NodesColor.hyperchat;

//   @override
//   Map<String, dynamic> toJson({bool toLocal = true}) => {
//         "t": Nodes.hyperchat.name,
//         "id": id,
//         "nm": firstWord,
//         "ln": secondWord,
//         "im": toLocal ? media.toJson() : media.id,
//         if (toLocal) "a": activity,
//         "grp": group.toList(),
//         if (toLocal) "msg": messages.toList(),
//         if (toLocal) "snp": snips.toList(),
//       };
// }
