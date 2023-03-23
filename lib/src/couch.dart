import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '_down4_dart_utils.dart' as u;
import 'dart:typed_data' show Uint8List;
import 'bsv/types.dart';
import 'package:cbl/cbl.dart' as cbl;

final _realtime = FirebaseDatabase.instance.ref();
final _firestore = FirebaseFirestore.instance;
final _nodeStore = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _messageStore = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

// extension on Iterable {
//   ISet<T> toISet<T>() => ISet<T>(toSet().cast<T>());
// }

// class ISet<T> {
//   final Set<T> _set;
//   final int size;
//   Iterable<T> get values => _set;
//   ISet(Set<T> set)
//       : _set = Set<T>.unmodifiable(set),
//         size = set.length;
// }

late cbl.AsyncDatabase _nodesDB,
    _mediasDB,
    _messagesDB,
    _utxosDB,
    _paymentsDB,
    _billsDB;

typedef Id = String;

Future<T?> fetch<T extends FireObject>(
  Id id, {
  bool merge = false,
  bool withData = false,
  bool fromNodes = false,
}) async {
  Future<FireNode?> fetchNode(Id id, {bool merge = false}) async {
    final snapshot = await _firestore
        .collection("Nodes")
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final node = FireNode.fromJson(snapshot.data()!.cast())!;
    if (merge) await node._merge();
    return node;
  }

  Future<FireMessage?> fetchMessage(Id id, {bool merge = false}) async {
    final snapshot = await _realtime.child("Message").child(id).get();
    if (!snapshot.exists) return null;
    final json = Map<String, String?>.from(snapshot.value as Map);
    final message = FireMessage.fromJson(json)!;
    if (merge) message._merge();
    return message;
  }

  Future<FireMedia?> fetchMedia(
    Id id, {
    bool merge = false,
    bool withData = false,
    bool fromNodes = false,
  }) async {
    final ref = fromNodes ? _nodeStore.ref(id) : _messageStore.ref(id);
    try {
      final futureFullMetadata = ref.getMetadata();
      final maybeFutureData = withData ? ref.getData() : null;
      // will throw if no metadata, so we can use !
      final mediaJson = (await futureFullMetadata).customMetadata!;
      final media = FireMedia.fromJson(mediaJson);
      Uint8List? videoThumbnail;
      final bool isVideo = media.isVideo;
      if (isVideo && withData) {
        final url = await ref.getDownloadURL();
        videoThumbnail = await VideoThumbnail.thumbnailData(
          video: url,
          quality: 50,
        );
      }
      if (merge) {
        media._merge();
        if (withData) {
          await media._write(
            videoData: isVideo ? await maybeFutureData : null,
            imageData: isVideo ? videoThumbnail : await maybeFutureData,
          );
        }
      }
      return media;
    } catch (e) {
      print("Error downloading media id: $id from storage, err: $e");
      return null;
    }
  }

  switch (T) {
    case FireNode:
      return fetchNode(id, merge: merge) as T;
    case FireMessage:
      return fetchMessage(id, merge: merge) as T;
    case FireMedia:
      return fetchMedia(id,
          merge: merge, withData: withData, fromNodes: fromNodes) as T;
  }
  throw 'Unsupported type for fetching $T';
}

cbl.Database db_<T extends FireObject>() {
  switch (T) {
    case FireNode:
      return _nodesDB;
    case FireMessage:
      return _messagesDB;
    case FireMedia:
      return _mediasDB;
  }
  throw 'No db exists for type: $T';
}

Future<T?> local<T extends FireObject>(Id id) async {
  final doc = await db_<T>().document(id);
  if (doc == null) return null;
  return _fromJson<T>(doc.toPlainMap().cast());
}

T _fromJson<T extends FireObject>(Map<String, String?> json) {
  switch (T) {
    case FireNode:
      return FireNode.fromJson(json) as T;
    case FireMessage:
      return FireMessage.fromJson(json) as T;
    case FireMedia:
      return FireMedia.fromJson(json) as T;
  }
  throw 'Cannot create fireobject from json for this type: $T';
}

abstract class FireObject {
  final String id;
  const FireObject(this.id);

  cbl.Database _db();

  Future<void> _delete() async => await _db().purgeDocumentById(id);

  Map<String, String> toJson({bool withLocalValues = false});

  Future<void> _merge([Map<String, String>? values]) async {
    var db = _db();
    // first, we get the current doc in the db
    var document = (await db.document(id))?.toMutable();
    bool wasLocal = (document != null);
    // if it wasn't local, we create it
    if (!wasLocal) document = cbl.MutableDocument.withId(id);

    Map<String, Object> toMerge;
    if (!wasLocal) {
      // then we need to merge the whole thing with the parameter values
      toMerge = {...toJson(withLocalValues: true), ...?values};
    } else {
      // we merge given values, or the values from the probably freshly
      // fetched object without the local values to not overwrite them
      toMerge = (values ?? toJson(withLocalValues: false));
    }

    toMerge.forEach((key, value) {
      document!.setValue(value, key: key);
    });

    await db.saveDocument(document);
  }

  static T fromJson<T extends FireObject>(Map<String, String?> json) {
    switch (T) {
      case FireMessage:
        return FireMessage.fromJson(json) as T;
      case FireNode:
        return FireNode.fromJson(json) as T;
      case FireMedia:
        return FireMedia.fromJson(json) as T;
    }
    throw '$T is not a supported type for the fromJson function';
  }
}

class FireMessage extends FireObject {
  final Id root;
  final Id sender;
  final Id? media;
  final String? text;
  final Set<Id>? replies, nodes;
  final String? forwarderID;
  final int timestamp;
  final bool isRead, isSent;

  const FireMessage(
    super.id, {
    required this.root,
    required this.sender,
    required this.timestamp,
    this.media,
    this.forwarderID,
    this.text,
    this.nodes,
    this.replies,
    this.isRead = false,
    this.isSent = false,
  });

  static FireMessage? fromJson(Map<String, String?> decodedJson) {
    return FireMessage(
      decodedJson["id"] as Id,
      root: decodedJson["root"] as Id,
      sender: decodedJson["sender"] as Id,
      forwarderID: decodedJson["forwarderID"],
      text: decodedJson["text"],
      media: decodedJson["media"],
      timestamp: int.parse(decodedJson["timestamp"] ?? "0"),
      isRead: decodedJson["isRead"] == "true",
      isSent: decodedJson["isSent"] == "true",
      nodes: decodedJson["nodes"]?.split(" ").toSet(),
      replies: decodedJson["replies"]?.split(" ").toSet(),
    );
  }

  @override
  Map<String, String> toJson({bool withLocalValues = false}) => {
        'id': id,
        if (text != null) 'text': text!,
        'root': root,
        'sender': sender,
        'timestamp': timestamp.toString(),
        if (media != null) 'media': media!,
        if (withLocalValues) 'isRead': isRead.toString(),
        if (withLocalValues) 'isSent': isSent.toString(),
        if (forwarderID != null) 'forwarderID': forwarderID!,
        if (replies != null) 'replies': replies!.join(" "),
        if (nodes != null) 'nodes': nodes!.join(" "),
      };

  @override
  cbl.Database _db() => _messagesDB;

  // @override
  // Future<FireObject?> _fetch({required bool withMerge}) {
  //       final snapshot = await _realtime.child("Message").child(id).get();
  //       if (!snapshot.exists) return null;
  //       final json = Map<String, String?>.from(snapshot.value as Map);
  //       final message = FireMessage.fromJson(json) as T;
  //       if (withMerge) message._merge<T>();
  //       return message;
  // }

  @override
  Future<bool> _isLocal() {
    // TODO: implement _isLocal
    throw UnimplementedError();
  }

  @override
  Future<FireObject?> _local() {
    // TODO: implement _local
    throw UnimplementedError();
  }

  @override
  Future<FireObject?> get({bool mergeIfOnline = false}) {
    // TODO: implement get
    throw UnimplementedError();
  }
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

abstract class FireNode extends FireObject {
  int _activity;
  String _name;
  String? _lastName, _description;
  final Down4Keys? _neuter;
  Id? _media;
  bool? _isFriend, _isHidden;
  final Set<Id>? _messages;
  final Set<Id>? _snips;
  final Set<Id>? _group;
  final Set<Id>? _nfts;
  final Set<Id>? _images;
  final Set<Id>? _videos;
  final Set<Id>? _children;

  @override
  cbl.Database _db() => _nodesDB;

  Id? get media;
  NodesColor get colorCode;
  Nodes get type;
  String get displayID;
  String get displayName;
  int get activity => _activity;

  @override
  Map<String, String> toJson({bool withLocalValues = true}) => {
        "type": type.name,
        "id": id,
        "name": _name,
        if (withLocalValues && _isFriend != null)
          "isFriend": _isFriend!.toString(),
        if (withLocalValues && _isHidden != null)
          "isHidden": _isHidden.toString(),
        if (_lastName != null) "lastName": _lastName!,
        if (_media != null) "media": _media!,
        if (_children != null) "children": _children!.join(" "),
        if (_neuter != null) "neuter": _neuter!.toYouKnow(),
        if (_group != null) "group": _group!.join(" "),
        if (withLocalValues && _images != null) "images": _images!.join(" "),
        if (withLocalValues && _videos != null) "videos": _videos!.join(" "),
        if (withLocalValues && _nfts != null) "nfts": _nfts!.join(" "),
        if (withLocalValues && _messages != null)
          "messages": _messages!.join(" "),
        if (withLocalValues && _snips != null) "snips": _snips!.join(" "),
        if (withLocalValues) "activity": _activity.toString(),
      };

  FireNode(
    super.id, {
    required int activity,
    required String name,
    String? lastName,
    bool? isFriend,
    bool? isHidden,
    String? description,
    Down4Keys? neuter,
    Id? media,
    Set<Id>? messages,
    Set<Id>? snips,
    Set<Id>? group,
    Set<Id>? nfts,
    Set<Id>? images,
    Set<Id>? videos,
    Set<Id>? children,
  })  : _activity = activity,
        _name = name,
        _lastName = lastName,
        _isFriend = isFriend,
        _isHidden = isHidden,
        _description = description,
        _neuter = neuter,
        _media = media,
        _messages = messages,
        _snips = snips,
        _group = group,
        _nfts = nfts,
        _images = images,
        _videos = videos,
        _children = children;

  void updateActivity([int? newActivity]) {
    _activity = newActivity ?? u.timeStamp();
    _merge({"activity": _activity.toString()});
  }

  static FireNode? fromJson(Map<String, String?> json) {
    final id = json["id"];
    if (id == null) return null;
    final activity = int.parse(json["activity"] ?? "0");
    final type = Nodes.values.byName(json["type"] as String);
    final media = json["media"];

    final name = json["name"] as String;
    final isFriend = json["isFriend"] == "true";
    final isHidden = json["isHidden"] == "true";
    final lastName = json["lastName"];
    final description = json["description"];
    final children = json["children"]?.split(" ").toSet();
    final neuter = json["neuter"] != null
        ? Down4Keys.fromYouKnow(json["neuter"] as String)
        : null;
    final group = json["group"]?.split(" ").toSet();
    final images = json["images"]?.split(" ").toSet();
    final videos = json["videos"]?.split(" ").toSet();
    final nfts = json["nfts"]?.split(" ").toSet();
    final messages = json["messages"]?.split(" ").toSet();
    final snips = json["snips"]?.split(" ").toSet();

    switch (type) {
      case Nodes.user:
        return User(id,
            activity: activity,
            name: name,
            lastName: lastName,
            media: media,
            isHidden: isHidden,
            isFriend: isFriend,
            children: children!,
            messages: messages!,
            snips: snips!,
            neuter: neuter!,
            description: description);

      case Nodes.hyperchat:
        return Hyperchat(id,
            activity: activity,
            firstWord: name,
            secondWord: lastName!,
            media: media,
            messages: messages!,
            snips: snips!,
            group: group!);

      case Nodes.group:
        return Group(id,
            activity: activity,
            name: name,
            media: media,
            messages: messages!,
            snips: snips!,
            group: group!);

      case Nodes.self:
        return Self(id,
            activity: activity,
            name: name,
            description: description,
            lastName: lastName,
            media: media!,
            children: children!,
            messages: messages!,
            snips: snips!);

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
    return null;
  }
}

mixin Branchable on FireNode {
  Iterable<Id> get children;
}

mixin Chatable on FireNode {
  Iterable<Id> get messages;
  Iterable<Id> get snips;

  Future<void> addMessage(FireMessage msg) async {
    // message will be merged on fetch
    _messages!.add(msg.id);
    Map<String, String> merges = {};
    merges["messages"] = _messages!.join(" ");
    if (this is User) merges["isHidden"] = false.toString();
    await _merge(merges);
  }

  Future<void> removeMessage(FireMessage msg) async {
    final n = this;
    if (msg.media != null) {
      final media = await local<FireMedia>(msg.media!);
      await media?.removeReference(msg.id);
    }
    _messages!.remove(msg.id);
    if (messages.isEmpty &&
        snips.isEmpty &&
        (n is Hyperchat || (n is User && !n.isFriend))) {
      _delete();
    } else {
      await _merge({"messages": messages.join(" ")});
    }

    await msg._delete();
  }

  Future<void> addSnip(FireMedia snip) async {
    _snips!.add(snip.id);
    Map<String, String> merges = {};
    merges["snips"] = snips.join(" ");
    if (this is User) merges["isHidden"] = false.toString();
    await _merge(merges);
  }

  Future<u.Pair<bool, String>> messagingPreview() async {
    final def = Future.value(const u.Pair(true, ""));
    if (messages.isEmpty) def;
    final lastMsgID = messages.last;
    final msg = await local<FireMessage>(lastMsgID);
    if (msg == null) return def;
    return u.Pair(msg.isRead, msg.text ?? "&attachment");
  }
}

mixin Groupable on FireNode {
  Iterable<Id> get group;
  @override
  String get displayID => group.map((id) => "@$id").join(" ");
}

mixin Personable on FireNode {
  String get firstName;
  String? get description;
  String? get lastName;
  Down4Keys get neuter;

  @override
  String get displayID => "@$id";

  @override
  String get displayName =>
      firstName + ((lastName != null) ? " $lastName" : "");
}

mixin Editable on FireNode {
  Future<void> editName(String newName) async {
    _name = newName;
    await _merge({"name": _name});
  }

  Future<void> editLastName(String? newLastName) async {
    _lastName = newLastName;
    await _merge({"lastName": _lastName ?? ""});
  }

  Future<void> editImage(FireMedia newImage) async {
    await newImage.addReference(id);
    if (media != null) {
      await (await local<FireMedia>(media!))?.removeReference(id);
    }
    _media = newImage.id;
    await _merge({"media": _media!});
  }

  Future<void> editDescription(String newDescription) async {
    _description = newDescription;
    await _merge({"description": _description!});
  }
}

class User extends FireNode with Branchable, Personable, Chatable {
  User(
    super.id, {
    required super.activity,
    required super.name,
    required bool isHidden,
    required bool isFriend,
    required Set<Id> children,
    required Set<Id> messages,
    required Set<Id> snips,
    required super.description,
    required super.lastName,
    required super.media,
    required Down4Keys neuter,
  }) : super(
            isHidden: isHidden,
            isFriend: isFriend,
            children: children,
            messages: messages,
            snips: snips);

  Future<void> updateFriendStatus(bool newFriendStatus) async {
    _isFriend = newFriendStatus;
    await _merge({"isFriend": _isFriend.toString()});
  }

  Future<void> updateHiddenStatus(bool newHiddenStatus) async {
    _isHidden = newHiddenStatus;
    await _merge({"isHidden": _isHidden.toString()});
  }

  bool get isHidden => _isHidden!;

  bool get isFriend => _isFriend!;

  @override
  Iterable<Id> get children => _children!;

  @override
  NodesColor get colorCode =>
      isFriend ? NodesColor.friend : NodesColor.nonFriend;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  Id? get media => _media;

  @override
  Iterable<Id> get messages => _messages!;

  @override
  String get firstName => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  Iterable<Id> get snips => _snips!;

  @override
  Nodes get type => Nodes.user;
}

class Self extends FireNode with Branchable, Personable, Chatable, Editable {
  Self(
    super.id, {
    required super.activity,
    required super.name,
    required super.description,
    required super.lastName,
    required Id media,
    required Set<Id> children,
    required Set<Id> messages,
    required Set<Id> snips,
  }) : super(
          media: media,
          children: children,
          messages: messages,
          snips: snips,
        );

  @override
  NodesColor get colorCode => NodesColor.self;

  @override
  Iterable<Id> get children => _children!;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  Id get media => _media!;

  @override
  Iterable<Id> get messages => _messages!;

  @override
  String get firstName => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  Iterable<Id> get snips => _snips!;

  @override
  Nodes get type => Nodes.self;
}

class Group extends FireNode with Groupable, Editable, Chatable {
  Group(
    super.id, {
    required super.activity,
    required super.name,
    required super.media,
    required Set<Id> messages,
    required Set<Id> snips,
    required Set<Id> group,
  }) : super(messages: messages, snips: snips, group: group);

  Future<void> addMembers(Iterable<Personable> members) async {
    final membersID = members.map((e) => e.id);
    _group!.addAll(membersID);
    final merges = members.map((e) => e._merge());
    await Future.wait(merges);
    await _merge({"group": group.join(" ")});
  }

  @override
  NodesColor get colorCode => NodesColor.group;

  @override
  String get displayName => _name;

  @override
  Iterable<Id> get group => _group!;

  @override
  Id? get media => _media;

  @override
  Iterable<Id> get messages => _messages!;

  @override
  Iterable<Id> get snips => _snips!;

  @override
  Nodes get type => Nodes.group;
}

class Hyperchat extends FireNode with Groupable, Chatable {
  Hyperchat(
    super.id, {
    required super.activity,
    required String firstWord,
    required String secondWord,
    required super.media,
    required Set<Id> messages,
    required Set<Id> snips,
    required Set<Id> group,
  }) : super(
            messages: messages,
            snips: snips,
            group: group,
            name: firstWord,
            lastName: secondWord);

  @override
  NodesColor get colorCode => NodesColor.group;

  @override
  String get displayName => "$_name $_lastName";

  @override
  Iterable<Id> get group => _group!;

  @override
  Id? get media => _media;

  @override
  Iterable<Id> get messages => _messages!;

  @override
  Iterable<Id> get snips => _snips!;

  @override
  Nodes get type => Nodes.hyperchat;
}

class Payment extends FireNode {
  @override
  int get activity => _payment.tsSeconds;

  @override
  Id? get media => null;

  final Down4Payment _payment;
  final FireObject selfID;
  Payment(
    super.id, {
    required Down4Payment payment,
    required this.selfID,
  })  : _payment = payment,
        super(activity: payment.tsSeconds, name: payment.id);

  @override
  String get displayName => payment.formattedName(selfID.id);

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
  Nodes get type => Nodes.payment;
}

class FireMedia extends FireObject {
  final bool isReversed, isLocked, isPaidToView, isPaidToOwn, isSquared;
  bool _isSaved;
  final Id owner;
  final Id? onlineId;
  final String extension;
  final String mimetype;
  final double aspectRatio;
  final String? text;
  final int timestamp;
  final Set<Id> _references;

  bool get isVideo => extension.isVideoExtension();

  Future<Uint8List?> get imageData async {
    final blob = (await _db().document(id))?.blob("image");
    return blob?.content();
  }

  Future<Uint8List?> get videoData async {
    final blob = (await _db().document(id))?.blob("video");
    return blob?.content();
  }

  @override
  cbl.Database _db() => _mediasDB;

  FireMedia(
    super.id, {
    required this.owner,
    required this.timestamp,
    required this.aspectRatio,
    required this.extension,
    required this.mimetype,
    required Set<Id> references,
    this.onlineId,
    bool isSaved = false,
    this.isLocked = false,
    this.isPaidToView = false,
    this.isReversed = false,
    this.isPaidToOwn = false,
    this.isSquared = false,
    this.text,
  })  : _references = references,
        _isSaved = isSaved;

  Future<void> updateSaveStatus(bool newSaveStatus) async {
    _isSaved = newSaveStatus;
    await _merge({"isSaved": _isSaved.toString()});
  }

  Future<void> addReference(Id reference) async {
    _references.add(reference);
    await _merge({"references": _references.join(" ")});
  }

  Future<void> removeReference(Id reference) async {
    _references.remove(reference);
    if (_references.isEmpty && !_isSaved) {
      await _delete();
    } else {
      await _merge({"references": _references.join(" ")});
    }
  }

  Future<void> _write({Uint8List? videoData, Uint8List? imageData}) async {
    if (videoData == null && imageData == null) return;
    final doc = (await _db().document(id))?.toMutable();
    if (isVideo) {
      final videoBlob = cbl.Blob.fromData(mimetype, videoData!);
      doc?.setBlob(videoBlob, key: "video");
    }
    final imageMime = isVideo ? "image/png" : mimetype;
    final imageBlob = cbl.Blob.fromData(imageMime, imageData!);
    doc?.setBlob(imageBlob, key: "image");
    return;
  }

  factory FireMedia.fromJson(Map<String, String?> decodedJson) {
    return FireMedia(
      decodedJson["id"]!,
      owner: decodedJson["owner"]!,
      timestamp: int.parse(decodedJson["timestamp"]!),
      extension: decodedJson["extension"]!,
      mimetype: decodedJson["mimetype"]!,
      onlineId: decodedJson["onlineRef"]!,
      references: decodedJson["references"]!.split(" ").toSet(),
      isSaved: decodedJson["isSaved"] == "true",
      isReversed: decodedJson["isReversed"] == "true",
      isSquared: decodedJson["isSquared"] == "true",
      isLocked: decodedJson["isLocked"] == "true",
      isPaidToOwn: decodedJson["isPaidToView"] == "true",
      isPaidToView: decodedJson["isPaidToOwn"] == "true",
      aspectRatio: double.tryParse(decodedJson["aspectRatio"]!) ?? 1.0,
      text: decodedJson["text"],
    );
  }

  @override
  Map<String, String> toJson({bool withLocalValues = true}) => {
        "owner": owner,
        "timestamp": timestamp.toString(),
        "extension": extension,
        "mimetype": mimetype,
        if (onlineId != null) "onlineRef": onlineId!,
        if (text != null) "text": text!,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isLocked": isLocked.toString(),
        "isPaidToView": isPaidToView.toString(),
        "isPaidToOwn": isPaidToOwn.toString(),
        "aspectRatio": aspectRatio.toString(),
        if (withLocalValues) "references": _references.join(" "),
        if (withLocalValues) "isSaved": _isSaved.toString(),
      };
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


// Stream<Palette2> loadHomePalettes({bool isHidden = false}) async* {
//   final raw = '''
//       SELECT * FROM nodes
//       LEFT JOIN ON medias.id = nodes.media
//       WHERE nodes.isHidden = ${isHidden.toString()}
//         AND nodes.type IN ('group', 'hyperchat', 'user', 'self')
//       ''';

//   final query = await cbl.Query.fromN1qlAsync(_nodesDB, raw);
//   final results = await query.execute();
//   await for (final result in results.asStream()) {
//     Map<String, String?> nodeJson = result.toPlainMap().cast();
//     Map<String, String?> mediaJson = result.toPlainMap().cast();
//     final node = FireNode.fromJson(nodeJson)!;
//     final media = FireMedia.fromJson(mediaJson);
//     yield Palette2(node: node, media: media);
//   }
// }

// Future<List<ChatMessage>> loadMessages(FireObject root,
//     {required int take, required int skip}) async {
//   final raw = '''
//         SELECT * FROM messages
//         LEFT JOIN ON medias.id = messages.media
//         WHERE messages.root = ${root.id}
//         LIMIT $take OFFSET $skip
//         ORDER BY messages.timestamp DESC
//     ''';
//   final query = await Query.fromN1qlAsync(_messagesDB, raw);
//   final results = await query.execute();
//   final all = await results.allResults();
//   return all.map((result) {
//     Map<String, String?> nodeJson = result.toPlainMap().cast();
//     Map<String, String?> mediaJson = result.toPlainMap().cast();
//     final message = FireNode.fromJson(nodeJson)!;
//     final media = FireMedia.fromJson(mediaJson);
//     return ChatMessage(
//         nodeRef: nodeRef,
//         nodes: nodes,
//         hasHeader: hasHeader,
//         message: message,
//         myMessage: myMessage,
//         hasGap: hasGap,
//         mediaInfo: mediaInfo,
//         openNode: openNode,
//         repliesInfo: repliesInfo,
//         select: select);
//   }).toList();
// }
