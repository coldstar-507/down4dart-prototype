// import 'dart:convert';
// import 'dart:typed_data';
// import 'dart:io';
//
// import 'package:down4/src/bsv/_bsv_utils.dart';
//
// import '_dart_utils.dart' as u;
// import 'bsv/types.dart';
//
// typedef ID = String;
//
// enum Messages {
//   chat,
//   payment,
//   bill,
//   snip,
// }
//
// enum Nodes {
//   user,
//   hyperchat,
//   group,
//   root,
//   market,
//   checkpoint,
//   journal,
//   item,
//   event,
//   ticket,
//   payment,
//   self,
// }
//
// enum NodesColor {
//   friend,
//   nonFriend,
//   hyperchat,
//   group,
//   root,
//   market,
//   checkpoint,
//   journal,
//   item,
//   event,
//   ticket,
//   safeTx,
//   mediumTx,
//   unsafeTx,
//   self,
// }
//
// abstract class Down4Object {
//   ID get id;
// }
//
// abstract class Media implements Down4Object {
//   @override
//   final ID id;
//
//   MediaMetadata metadata;
//   Media({
//     required this.id,
//     required this.metadata,
//   });
//
//   String get url;
// }
//
// class MessageMedia extends Media {
//   String path;
//   String? thumbnail;
//   MessageMedia({
//     required this.path,
//     required ID id,
//     required MediaMetadata metadata,
//     this.thumbnail,
//     this.isSaved = false,
//     Set<ID>? references,
//   })  : references = references ?? Set<ID>.identity(),
//         super(id: id, metadata: metadata);
//
//   String get extension => metadata.extension;
//
//   bool get isVideo => u.videoExtensions.contains(extension);
//
//   bool get isImage => u.imageExtensions.contains(extension);
//
//   bool get isAnimatedImage => u.animatedImageExtensions.contains(extension);
//
//   File? get file => hasFile ? File(path) : null;
//
//   bool get hasFile => File(path).existsSync();
//
//   bool get hasThumbnail =>
//       thumbnail == null ? false : File(thumbnail!).existsSync();
//
//   File? get thumbnailFile => !hasThumbnail ? null : File(thumbnail!);
//
//   Set<ID> references;
//
//   bool isSaved;
//
//   NodeMedia? asNodeMedia() {
//     if (file == null) return null;
//     return NodeMedia(
//       id: id,
//       metadata: metadata,
//       data: file!.readAsBytesSync(),
//     );
//   }
//
//   factory MessageMedia.fromJson(dynamic decodedJson) {
//     return MessageMedia(
//         id: decodedJson["id"],
//         metadata: MediaMetadata.fromJson(decodedJson["md"]),
//         path: decodedJson["p"],
//         isSaved: decodedJson["sv"] ?? false,
//         references: Set<ID>.from(decodedJson["ref"]),
//         thumbnail: decodedJson["tn"]);
//   }
//
//   Map<String, dynamic> toJson({bool toLocal = false}) => {
//         "id": id,
//         "md": metadata.toJson(),
//         if (toLocal && thumbnail != null) "tn": thumbnail,
//         if (toLocal) "sv": isSaved,
//         if (toLocal) "ref": references.toList(),
//         if (toLocal) "p": path,
//       };
//
//   @override
//   String get url => "https://storage.googleapis.com/down4-26ee1-messages/$id";
// }
//
// class NodeMedia extends Media {
//   Uint8List data;
//   NodeMedia({
//     required this.data,
//     required ID id,
//     required MediaMetadata metadata,
//   }) : super(id: id, metadata: metadata);
//
//   factory NodeMedia.fromJson(dynamic decodedJson) {
//     final b64Data = decodedJson["d"];
//     return NodeMedia(
//       id: decodedJson["id"],
//       metadata: MediaMetadata.fromJson(decodedJson["md"]),
//       data: base64Decode(b64Data),
//     );
//   }
//
//   @override
//   String get url => "https://storage.googleapis.com/down4-26ee1-nodes/$id";
//
//   Map<String, dynamic> toJson() => {
//         "id": id,
//         "md": metadata.toJson(),
//         "d": base64Encode(data),
//       };
// }
//
// class MessageNotification {
//   final Messages type;
//   final String? base64jsonData;
//   MessageNotification({required this.type, this.base64jsonData});
// }
//
// class Message implements Down4Object {
//   @override
//   final ID id;
//   final ID senderID;
//   final ID? mediaID;
//   final String? text;
//   final List<ID>? replies, nodes;
//   ID? forwarderID;
//   int timestamp;
//   Map<ID, bool> sents, reads;
//
//   bool read(ID id) => reads[id] ?? false;
//   bool sent(ID id) => sents[id] ?? false;
//
//   Message({
//     required this.senderID,
//     required this.timestamp,
//     required this.id,
//     this.mediaID,
//     this.forwarderID,
//     this.text,
//     this.nodes,
//     this.replies,
//     Map<ID, bool>? sents,
//     Map<ID, bool>? reads,
//   })  : sents = sents ?? {},
//         reads = reads ?? {};
//
//   void refresh() => timestamp = u.timeStamp();
//
//   factory Message.fromJson(Map<String, dynamic> decodedJson) {
//     return Message(
//       id: decodedJson["id"],
//       senderID: decodedJson["s"],
//       forwarderID: decodedJson["f"],
//       text: decodedJson["txt"],
//       mediaID: decodedJson["m"],
//       timestamp: decodedJson["ts"],
//       reads: decodedJson["rd"] != null
//           ? Map<ID, bool>.from(decodedJson["rd"])
//           : {},
//       sents: decodedJson["st"] != null
//           ? Map<ID, bool>.from(decodedJson["st"])
//           : {},
//       replies: (decodedJson["r"] ?? "").isNotEmpty
//           ? List<String>.from(decodedJson["r"].split(" "))
//           : null,
//       nodes: (decodedJson["n"] ?? "").isNotEmpty
//           ? List<String>.from(decodedJson["n"].split(" "))
//           : null,
//     );
//   }
//
//   Map<String, dynamic> toJson({bool toLocal = false}) => {
//         'id': id,
//         if (text != null) 'txt': text,
//         's': senderID,
//         'ts': timestamp,
//         if (mediaID != null) 'm': mediaID,
//         if (toLocal) 'rd': reads,
//         if (toLocal) 'st': sents,
//         if (forwarderID != null) 'f': forwarderID,
//         if (replies != null) 'r': replies!.join(" "),
//         if (nodes != null) 'n': nodes!.join(" "),
//       };
// }
//
// abstract class BaseNode implements Down4Object {
//   @override
//   ID id;
//
//   NodeMedia? get media;
//
//   NodesColor get colorCode;
//   String get name;
//   String get displayID;
//   Map<String, dynamic> toJson({bool toLocal});
//   int activity;
//   BaseNode({required this.id, int? activity}) : activity = activity ?? 0;
//   void updateActivity([int? newActivity]) =>
//       activity = newActivity ?? u.timeStamp();
//   factory BaseNode.fromJson(dynamic decodedJson) {
//     final type = Nodes.values.byName(decodedJson["t"]);
//     final id = decodedJson["id"];
//     switch (type) {
//       case Nodes.user:
//         return User(
//           id: id,
//           firstName: decodedJson["nm"],
//           isFriend: decodedJson["if"] ?? false,
//           neuter: Down4Keys.fromYouKnow(decodedJson["nt"]),
//           messages: Set<ID>.from(decodedJson["msg"] ?? []),
//           snips: Set<ID>.from(decodedJson["snp"] ?? []),
//           children: Set<ID>.from(decodedJson["chl"] ?? []),
//           lastName: decodedJson["ln"],
//           activity: decodedJson["a"],
//           media: decodedJson["im"]?["d"] != null
//               ? NodeMedia.fromJson(decodedJson["im"])
//               : null,
//         );
//
//       case Nodes.hyperchat:
//         return Hyperchat(
//           id: id,
//           firstWord: decodedJson["nm"],
//           secondWord: decodedJson["ln"],
//           group: Set<ID>.from(decodedJson["grp"] ?? []),
//           messages: Set<ID>.from(decodedJson["msg"] ?? []),
//           snips: Set<ID>.from(decodedJson["snp"] ?? []),
//           media: NodeMedia.fromJson(decodedJson["im"]),
//           activity: decodedJson["a"],
//         );
//
//       case Nodes.group:
//         return Group(
//           isPrivate: decodedJson["pv"],
//           name: decodedJson["nm"],
//           id: id,
//           media: NodeMedia.fromJson(decodedJson["im"]),
//           group: Set<ID>.from(decodedJson["grp"]),
//           messages: Set<ID>.from(decodedJson["msg"] ?? <ID>[]),
//           snips: Set<ID>.from(decodedJson["snp"] ?? <ID>[]),
//           activity: decodedJson["a"],
//         );
//
//       case Nodes.self:
//         return Self(
//           firstName: decodedJson["nm"],
//           lastName: decodedJson["ln"],
//           activity: decodedJson["a"],
//           neuter: Down4Keys.fromYouKnow(decodedJson["nt"]),
//           images: Set.from(decodedJson["img"]),
//           videos: Set.from(decodedJson["vid"]),
//           nfts: Set.from(decodedJson["nft"]),
//           id: id,
//           media: NodeMedia.fromJson(decodedJson["m"]),
//           children: Set.from(decodedJson["chl"]),
//           messages: Set.from(decodedJson["msg"]),
//           snips: Set.from(decodedJson["snp"]),
//         );
//
//       case Nodes.root:
//         // TODO: Handle this case.
//         break;
//       case Nodes.market:
//         // TODO: Handle this case.
//         break;
//       case Nodes.checkpoint:
//         // TODO: Handle this case.
//         break;
//       case Nodes.journal:
//         // TODO: Handle this case.
//         break;
//       case Nodes.item:
//         // TODO: Handle this case.
//         break;
//       case Nodes.event:
//         // TODO: Handle this case.
//         break;
//       case Nodes.ticket:
//         // TODO: Handle this case.
//         break;
//       case Nodes.payment:
//         break;
//       // return Payment(payment: Down4Payment.fromYouKnow(decodedJson["pay"]));
//     }
//     throw 'invalid node type: $type';
//   }
// }
//
// abstract class BranchableNode implements BaseNode {
//   Set<ID> get children;
//   set children(Set<ID> chld);
// }
//
// abstract class ChatableNode extends BaseNode {
//   Set<ID> messages, snips;
//   ChatableNode({
//     required ID id,
//     int? activity,
//     required this.messages,
//     required this.snips,
//   }) : super(id: id, activity: activity);
//
//   Set<ID> calculateTargets(ID selfID) {
//     if (this is GroupNode) {
//       return Set<ID>.from((this as GroupNode).group)..remove(selfID);
//     }
//     return {id};
//   }
// }
//
// abstract class GroupNode extends ChatableNode {
//   Set<ID> group;
//   @override
//   NodeMedia media;
//   GroupNode({
//     required ID id,
//     required this.group,
//     required this.media,
//     int? activity,
//     required Set<ID> messages,
//     required Set<ID> snips,
//   }) : super(id: id, activity: activity, messages: messages, snips: snips);
// }
//
// abstract class Person extends ChatableNode implements BranchableNode {
//   String firstName;
//   String? lastName, description;
//   final Down4Keys neuter;
//   Person({
//     required this.firstName,
//     required this.neuter,
//     this.lastName,
//     this.description,
//     int? activity,
//     required ID id,
//     required Set<ID> messages,
//     required Set<ID> snips,
//   }) : super(id: id, messages: messages, snips: snips, activity: activity);
//
//   @override
//   String get displayID => "@$id";
//
//   @override
//   String get name => firstName + ((lastName != null) ? " $lastName" : "");
// }
//
// class User extends Person {
//   bool isFriend;
//   @override
//   Set<ID> children;
//   @override
//   NodeMedia? media;
//
//   User({
//     this.isFriend = false,
//     required ID id,
//     required String firstName,
//     this.media,
//     String? lastName,
//     String? description,
//     required Down4Keys neuter,
//     required Set<ID> messages,
//     required Set<ID> snips,
//     required this.children,
//     int? activity,
//   }) : super(
//           id: id,
//           neuter: neuter,
//           activity: activity,
//           messages: messages,
//           snips: snips,
//           firstName: firstName,
//           lastName: lastName,
//           description: description,
//         );
//
//   @override
//   NodesColor get colorCode =>
//       isFriend ? NodesColor.friend : NodesColor.nonFriend;
//
//   @override
//   Map<String, dynamic> toJson({bool toLocal = true}) => {
//         "t": Nodes.user.name,
//         "id": id,
//         if (toLocal) "if": isFriend,
//         "nm": firstName,
//         "nt": neuter.toYouKnow(),
//         if (toLocal) "msg": messages.toList(),
//         "chl": children.toList(),
//         if (toLocal) "snp": snips.toList(),
//         if (toLocal) "a": activity,
//         if (lastName != null) "ln": lastName,
//         if (toLocal) "im": media!.toJson() else "im": media!.id,
//       };
// }
//
// class Self extends Person {
//   Set<ID> images, videos, nfts;
//   @override
//   NodeMedia media;
//
//   @override
//   Set<ID> children;
//
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
//
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
//
//   @override
//   NodesColor get colorCode => NodesColor.self;
// }
//
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
//
//   @override
//   String get displayID => group.map((id) => "@$id").join(" ");
//
//   @override
//   NodesColor get colorCode => NodesColor.group;
//
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
//
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
//
//   @override
//   String get displayID => group.map((id) => "@$id").join(" ");
//
//   @override
//   String get name => "$firstWord $secondWord";
//
//   @override
//   NodesColor get colorCode => NodesColor.hyperchat;
//
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
//
// class Payment extends BaseNode {
//   @override
//   int get activity => _payment.tsSeconds;
//
//   @override
//   final NodeMedia? media = null;
//   final Down4Payment _payment;
//   final ID selfID;
//   Payment({required Down4Payment payment, required this.selfID})
//       : _payment = payment,
//         super(id: payment.id);
//
//   @override
//   String get name => payment.formattedName(selfID);
//
//   Down4Payment get payment => _payment;
//
//   @override
//   String get displayID =>
//       "Confirmations: ${_payment.lastConfirmations > 100 ? "100+" : _payment.lastConfirmations}";
//
//   @override
//   NodesColor get colorCode => _payment.lastConfirmations == 0
//       ? NodesColor.unsafeTx
//       : _payment.lastConfirmations < 6
//           ? NodesColor.mediumTx
//           : NodesColor.safeTx;
//
//   @override
//   Map<String, dynamic> toJson({bool toLocal = true}) => {
//         // "t": Nodes.payment.name,
//         // "selfID": selfID,
//         // "pay": _payment.toYouKnow(),
//       };
// }
//
// class MediaMetadata {
//   final bool isReversed, isLocked, isPaidToView, isPaidToOwn, isSquared;
//   bool canSkipCheck;
//   final ID owner;
//   final String extension;
//   final double elementAspectRatio;
//   final String? text;
//   int timestamp;
//   MediaMetadata({
//     required this.owner,
//     required this.timestamp,
//     required this.elementAspectRatio,
//     required this.extension,
//     this.isLocked = false,
//     this.canSkipCheck = false,
//     this.isPaidToView = false,
//     this.isReversed = false,
//     this.isPaidToOwn = false,
//     this.isSquared = false,
//     this.text,
//   });
//
//   factory MediaMetadata.fromJson(Map<String, dynamic> decodedJson) {
//     // print(decodedJson);
//     return MediaMetadata(
//       owner: decodedJson["o"],
//       timestamp: int.parse(decodedJson["ts"]),
//       extension: decodedJson["ex"],
//       isReversed: decodedJson["trv"] == "true",
//       isLocked: decodedJson["lck"] == "true",
//       isPaidToView: decodedJson["ptv"] == "true",
//       isPaidToOwn: decodedJson["pto"] == "true",
//       canSkipCheck: decodedJson["csc"] == "true",
//       text: decodedJson["txt"],
//       isSquared: decodedJson["sqr"] == "true",
//       elementAspectRatio: double.tryParse(decodedJson["ar"]) ?? 1.0,
//     );
//   }
//
//   Map<String, String> toJson() {
//     return {
//       "o": owner,
//       "ts": timestamp.toString(),
//       "ex": extension,
//       "trv": isReversed.toString(),
//       "sqr": isSquared.toString(),
//       "lck": isLocked.toString(),
//       "ptv": isPaidToView.toString(),
//       "csc": canSkipCheck.toString(),
//       "pto": isPaidToOwn.toString(),
//       "ar": elementAspectRatio.toString(),
//       if (text != null) "txt": text!,
//     };
//   }
// }
//
// class Location {
//   final String id;
//   final String? at, type;
//   int pageIndex;
//   double? scroll;
//   Location({
//     required this.id,
//     this.at,
//     this.type,
//     this.pageIndex = 0,
//     this.scroll,
//   });
//
//   Location copy() => Location(
//         id: id,
//         at: at,
//         type: type,
//         pageIndex: pageIndex,
//         scroll: scroll,
//       );
// }
//
// class ExchangeRate {
//   int lastUpdate;
//   double rate;
//   ExchangeRate({required this.lastUpdate, required this.rate});
//
//   factory ExchangeRate.fromJson(dynamic decodedJson) {
//     return ExchangeRate(
//       lastUpdate: decodedJson["lastUpdate"],
//       rate: decodedJson["rate"],
//     );
//   }
//
//   Map<String, Object> toJson() => {
//         "rate": rate,
//         "lastUpdate": lastUpdate,
//       };
// }
