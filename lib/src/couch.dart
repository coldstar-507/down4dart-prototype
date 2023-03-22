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
final _node_storage =
    FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _message_storage =
    FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

extension ISetMaker on Iterable {
  ISet<T> toISet<T>() => ISet<T>(toSet().cast<T>());
}

class ISet<T> {
  final Set<T> _set;
  final int size;
  Iterable<T> get values => _set;
  ISet(Set<T> set)
      : _set = Set<T>.unmodifiable(set),
        size = set.length;
}

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

  Future<FireMedia?> fetchMedia(Id id,
      {bool merge = false,
      bool withData = false,
      bool fromNodes = false}) async {
    final ref = fromNodes ? _node_storage.ref(id) : _message_storage.ref(id);
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

cbl.Database db<T extends FireObject>() {
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
  final doc = await db<T>().document(id);
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

  //  async {
  //   final doc = await _db<T>().document(id);
  //   if (doc == null) return null;
  //   final Map<String, String?> docJson = doc.toPlainMap().cast();
  //   if (T is FireMessage) {
  //     return FireMessage.fromJson(docJson) as T;
  //   } else if (T is FireNode) {
  //     return FireNode.fromJson(docJson) as T;
  //   } else if (T is FireMedia) {
  //     return FireMedia.fromJson(docJson) as T;
  //   }
  //   throw "TODO: Implement this type $T";
  // }

  //  async {
  //   return (await _local<T>()) ?? (await _fetch<T>(withMerge: mergeIfOnline));
  // }

  //  async {
  //   if (T is FireNode) {
  //     final snapshot = await _firestore
  //         .collection("Nodes")
  //         .doc(id)
  //         .get(const GetOptions(source: Source.server));
  //     if (!snapshot.exists) return null;
  //     final node = FireNode.fromJson(snapshot.data()!.cast()) as T;
  //     if (withMerge) await node._merge<T>();
  //     return node;
  //   } else if (T is FireMessage) {
  //     final snapshot = await _realtime.child("Message").child(id).get();
  //     if (!snapshot.exists) return null;
  //     final json = Map<String, String?>.from(snapshot.value as Map);
  //     final message = FireMessage.fromJson(json) as T;
  //     if (withMerge) message._merge<T>();
  //     return message;
  //   } else if (T is FireMedia) {
  //     final ref = fromNodes ? _node_storage.ref(id) : _message_storage.ref(id);
  //     try {
  //       final futureFullMetadata = ref.getMetadata();
  //       final maybeFutureData = mediaWithData ? ref.getData() : null;
  //       // will throw if no metadata, so we can use !
  //       final mediaJson = (await futureFullMetadata).customMetadata!;
  //       final media = FireMedia.fromJson(mediaJson)!;
  //       Uint8List? videoThumbnail;
  //       final bool isVideo = media.isVideo;
  //       if (isVideo && mediaWithData) {
  //         final url = await ref.getDownloadURL();
  //         videoThumbnail = await VideoThumbnail.thumbnailData(
  //           video: url,
  //           quality: 50,
  //         );
  //       }
  //       if (withMerge) {
  //         media._merge<T>();
  //         if (mediaWithData) {
  //           await media._write(
  //             videoData: isVideo ? await maybeFutureData : null,
  //             imageData: isVideo ? videoThumbnail : await maybeFutureData,
  //           );
  //         }
  //       }
  //       return media as T;
  //     } catch (e) {
  //       print("Error downloading media id: $id from storage, err: $e");
  //       return null;
  //     }
  //   }
  //   return null;
  // }

  // if we know what we want to merge, we can specify values to be more efficient

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
  final ISet<Id>? replies, nodes;
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
      nodes: decodedJson["nodes"]?.split(" ").toISet(),
      replies: decodedJson["replies"]?.split(" ").toISet(),
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
        if (replies != null) 'replies': replies!.values.join(" "),
        if (nodes != null) 'nodes': nodes!.values.join(" "),
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
  final int _activity;
  final String _name;
  final String? _lastName, _description;
  final Down4Keys? _neuter;
  final Id? _media;
  final bool? _isFriend, _isHidden;
  final ISet<Id>? _messages;
  final ISet<Id>? _snips;
  final ISet<Id>? _group;
  final ISet<Id>? _nfts;
  final ISet<Id>? _images;
  final ISet<Id>? _videos;
  final ISet<Id>? _children;

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
        if (_children != null) "children": _children!.values.join(" "),
        if (_neuter != null) "neuter": _neuter!.toYouKnow(),
        if (_group != null) "group": _group!.values.join(" "),
        if (withLocalValues && _images != null)
          "images": _images!.values.join(" "),
        if (withLocalValues && _videos != null)
          "videos": _videos!.values.join(" "),
        if (withLocalValues && _nfts != null) "nfts": _nfts!.values.join(" "),
        if (withLocalValues && _messages != null)
          "messages": _messages!.values.join(" "),
        if (withLocalValues && _snips != null)
          "snips": _snips!.values.join(" "),
        if (withLocalValues) "activity": _activity.toString(),
      };

  const FireNode(
    super.id, {
    required int activity,
    required String name,
    String? lastName,
    bool? isFriend,
    bool? isHidden,
    String? description,
    Down4Keys? neuter,
    Id? media,
    ISet<Id>? messages,
    ISet<Id>? snips,
    ISet<Id>? group,
    ISet<Id>? nfts,
    ISet<Id>? images,
    ISet<Id>? videos,
    ISet<Id>? children,
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

  void updateActivity([int? newActivity]) =>
      super._merge({"activity": (newActivity ?? u.timeStamp()).toString()});

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
    final children = json["children"]?.split(" ").toISet<Id>();
    final neuter = json["neuter"] != null
        ? Down4Keys.fromYouKnow(json["neuter"] as String)
        : null;
    final group = json["group"]?.split(" ").toISet<Id>();
    final images = json["images"]?.split(" ").toISet<Id>();
    final videos = json["videos"]?.split(" ").toISet<Id>();
    final nfts = json["nfts"]?.split(" ").toISet<Id>();
    final messages = json["messages"]?.split(" ").toISet<Id>();
    final snips = json["snips"]?.split(" ").toISet<Id>();

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
  ISet<Id> get children;

  Future<void> addChildren(FireNode child) async {}
}

mixin Chatable on FireNode {
  ISet<Id> get messages;
  ISet<Id> get snips;

  Future<void> addMessage(FireMessage msg) async {
    await msg._merge();
    await _merge({
      "messages": messages.values.followedBy([msg.id]).join(" ")
    });
  }

  Future<void> removeMessage(Id msgID) async {
    await db<FireMessage>().purgeDocumentById(msgID);
    final ref = Set<Id>.from(messages.values);
    final deletion = ref.remove(msgID);
    if (!deletion) return;
    await _merge({"messages": ref.join(" ")});
  }

  Future<u.Pair<bool, String>> messagingPreview() async {
    final def = Future.value(const u.Pair(true, ""));
    if (messages.values.isEmpty) def;
    final lastMsgID = messages.values.last;
    final msg = await local<FireMessage>(lastMsgID);
    if (msg == null) return def;
    return u.Pair(msg.isRead, msg.text ?? "&attachment");
  }
}

mixin Groupable on FireNode {
  ISet<Id> get group;
  @override
  String get displayID => group.values.map((id) => "@$id").join(" ");
}

mixin Personable on FireNode {
  String get name;
  String? get description;
  String? get lastName;
  Down4Keys get neuter;

  @override
  String get displayID => "@$id";

  @override
  String get displayName => name + ((lastName != null) ? " $lastName" : "");
}

mixin Editable on FireNode {
  void editName(String newName) {
    // TODO
  }
  void editLastName(String? newLastName) {
    // TODO
  }
  void editImage(FireMedia newImage) {
    // TODO
  }
}

class User extends FireNode with Branchable, Personable, Chatable {
  const User(
    super.id, {
    required super.activity,
    required super.name,
    required bool isHidden,
    required bool isFriend,
    required ISet<Id> children,
    required ISet<Id> messages,
    required ISet<Id> snips,
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

  bool get isFriend => _isFriend!;

  @override
  ISet<Id> get children => _children!;

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
  ISet<Id> get messages => _messages!;

  @override
  String get name => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  ISet<Id> get snips => _snips!;

  @override
  Nodes get type => Nodes.user;
}

class Self extends FireNode with Branchable, Personable, Chatable, Editable {
  const Self(
    super.id, {
    required super.activity,
    required super.name,
    required super.description,
    required super.lastName,
    required Id media,
    required ISet<Id> children,
    required ISet<Id> messages,
    required ISet<Id> snips,
  }) : super(
          media: media,
          children: children,
          messages: messages,
          snips: snips,
        );

  @override
  NodesColor get colorCode => NodesColor.self;

  @override
  ISet<Id> get children => _children!;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  Id get media => _media!;

  @override
  ISet<Id> get messages => _messages!;

  @override
  String get name => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  ISet<Id> get snips => _snips!;

  @override
  Nodes get type => Nodes.self;
}

class Group extends FireNode with Groupable, Editable, Chatable {
  const Group(
    super.id, {
    required super.activity,
    required super.name,
    required super.media,
    required ISet<Id> messages,
    required ISet<Id> snips,
    required ISet<Id> group,
  }) : super(messages: messages, snips: snips, group: group);

  @override
  NodesColor get colorCode => NodesColor.group;

  @override
  String get displayName => _name;

  @override
  ISet<Id> get group => _group!;

  @override
  Id? get media => _media;

  @override
  ISet<Id> get messages => _messages!;

  @override
  ISet<Id> get snips => _snips!;

  @override
  Nodes get type => Nodes.group;
}

class Hyperchat extends FireNode with Groupable, Chatable {
  const Hyperchat(
    super.id, {
    required super.activity,
    required String firstWord,
    required String secondWord,
    required super.media,
    required ISet<Id> messages,
    required ISet<Id> snips,
    required ISet<Id> group,
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
  ISet<Id> get group => _group!;

  @override
  Id? get media => _media;

  @override
  ISet<Id> get messages => _messages!;

  @override
  ISet<Id> get snips => _snips!;

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
  final Id owner;
  final Id? onlineRef;
  final String imageDigest;
  final String? videoDigest;
  final String extension;
  final String mimetype;
  final double aspectRatio;
  final String? text;
  final int timestamp;

  bool get isVideo => extension.isVideoExtension();

  Future<Uint8List?> get imageData async {
    final blob = await _db().getBlob({"digest": imageDigest});
    return blob?.content();
  }

  Future<Uint8List?> get videoData async {
    if (videoDigest == null) return null;
    final blob = await _db().getBlob({"digest": videoDigest!});
    return blob?.content();
  }

  @override
  cbl.Database _db() => _mediasDB;

  const FireMedia(
    super.id, {
    required this.owner,
    required this.timestamp,
    required this.aspectRatio,
    required this.extension,
    required this.mimetype,
    required this.imageDigest,
    this.videoDigest,
    this.onlineRef,
    this.isLocked = false,
    this.isPaidToView = false,
    this.isReversed = false,
    this.isPaidToOwn = false,
    this.isSquared = false,
    this.text,
  });

  Future<void> _write({Uint8List? videoData, Uint8List? imageData}) async {
    if (videoData == null && imageData == null) return;
    if (isVideo) {
      await _db().saveBlob(cbl.Blob.fromData(mimetype, videoData!));
    }
    final imageMime = isVideo ? "image/png" : mimetype;
    await _db().saveBlob(cbl.Blob.fromData(imageMime, imageData!));
    return;
  }

  factory FireMedia.fromJson(Map<String, String?> decodedJson) {
    return FireMedia(
      decodedJson["id"] as String,
      owner: decodedJson["owner"] as String,
      timestamp: int.parse(decodedJson["timestamp"] as String),
      extension: decodedJson["extension"] as String,
      mimetype: decodedJson["mimetype"] as String,
      imageDigest: decodedJson["imageDigest"] as String,
      videoDigest: decodedJson["videoDigest"],
      onlineRef: decodedJson["onlineRef"],
      isReversed: decodedJson["isReversed"] == "true",
      isSquared: decodedJson["isSquared"] == "true",
      isLocked: decodedJson["isLocked"] == "true",
      isPaidToOwn: decodedJson["isPaidToView"] == "true",
      isPaidToView: decodedJson["isPaidToOwn"] == "true",
      aspectRatio: double.tryParse(decodedJson["aspectRatio"] as String) ?? 1.0,
      text: decodedJson["text"],
    );
  }

  @override
  Map<String, String> toJson({bool withLocalValues = true}) => {
        "owner": owner,
        "timestamp": timestamp.toString(),
        "extension": extension,
        "mimetype": mimetype,
        "imageDigest": imageDigest,
        if (videoDigest != null) "videoDigest": videoDigest!,
        if (onlineRef != null) "onlineRef": onlineRef!,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isLocked": isLocked.toString(),
        "isPaidToView": isPaidToView.toString(),
        "isPaidToOwn": isPaidToOwn.toString(),
        "aspectRatio": aspectRatio.toString(),
        if (text != null) "text": text!,
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
