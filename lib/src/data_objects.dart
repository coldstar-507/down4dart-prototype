import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:down4/src/globals.dart';
import 'package:down4/src/render_objects/palette.dart';
import 'package:firebase_database/firebase_database.dart' as realtime;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '_down4_dart_utils.dart' as u;
import 'dart:typed_data' show Uint8List;
import 'bsv/types.dart';
import 'package:cbl/cbl.dart';

final _realtime = realtime.FirebaseDatabase.instance.ref();
final _firestore = firestore.FirebaseFirestore.instance;
final _nodeStore = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _messageStore = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

Map<ID, FireObject> _globalCache = {};

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

late AsyncDatabase _nodesDB,
    _mediasDB,
    _messagesDB,
    _utxosDB,
    _paymentsDB,
    _billsDB;

final isHiddenNodeIndexConfig = ValueIndexConfiguration(["isHidden"]);
final lastUseMediaIndexConfig = ValueIndexConfiguration(["lastUse"]);
final isSavedMediaIndexConfig = ValueIndexConfiguration(["isSaved"]);
final isVideoMediaIndexConfig = ValueIndexConfiguration(["isVideo"]);

Future<Set<ID>> allGroupIDs() async {
  final q = await const AsyncQueryBuilder()
      .select(SelectResult.property("group"))
      .from(DataSource.database(_nodesDB))
      .where(Expression.property("type").in_([
        Expression.string("hyperchat"),
        Expression.string("group"),
      ]))
      .execute();

  return (await q.allResults()).fold(<ID>{}, (value, element) async {
    final sGroup = element.toPlainMap()["group"] as String;
    return (await value)..addAll(sGroup.split(" "));
  });
}

Future<List<Palette2<Chatable>>> loadHomePalettes(
    {required bool isHidden}) async {
  final isHiddenProp = isHidden.toString();
  final q = const QueryBuilder()
      .select(SelectResult.all())
      .from(DataSource.database(_nodesDB).as("nodes"))
      .join(Join.leftJoin(DataSource.database(_mediasDB).as("medias")).on(
          Expression.property("media")
              .from("nodes")
              .equalTo(Meta.id.from("medias"))))
      .where(Expression.property("isHidden")
          .from("nodes")
          .equalTo(Expression.string(isHiddenProp))
          .and(Expression.property("type").from("nodes").in_([
            Expression.string("hyperchat"),
            Expression.string("group"),
            Expression.string("user"),
            Expression.string("self"),
          ])));
  final r = await q.execute();
  return Future.wait((await r.allResults()).map((e) async {
    final fullJson = e.toPlainMap();
    final nodeJson = fullJson["nodes"] as Map<String, String?>;
    final mediaJson = fullJson["medias"] as Map<String, String?>?;
    final n = _fromJson<Chatable>(nodeJson);
    FireMedia? m = mediaJson != null ? FireMedia.fromJson(mediaJson) : null;
    if (!isHidden && m == null) {
      m = await _fetch<FireMedia>(n.media!,
          merge: true, withData: true, fromNodes: true);
    }

    return Palette2<Chatable>(node: n, image: m);
  }).toList());
}

Stream<Down4TXOUT> allUtxos() async* {
  const raw = 'SELECT * FROM _';
  final query = await AsyncQuery.fromN1ql(_utxosDB, raw);
  final resultSet = await query.execute();
  await for (final r in resultSet.asStream()) {
    yield Down4TXOUT.fromJson(r.toPlainMap());
  }
}

Stream<FireMedia> savedMedia(bool images) async* {
  final isVideo = images ? "'false'" : "'true'";
  final raw = """
        SELECT * FROM _ 
        WHERE isSaved = 'true' AND isVideo = $isVideo
        ORDER BY lastUse DESC""";
  final query = await AsyncQuery.fromN1ql(_mediasDB, raw);
  final results = await query.execute();
  await for (final r in results.asStream()) {
    yield FireMedia.fromJson(r.toPlainMap().cast());
  }
}

typedef ID = String;

enum GetType {
  cache,
  local,
  fetch,
  empty,
}

Future<T?> _fetch<T extends FireObject>(
  ID id, {
  bool merge = false,
  bool withData = false,
  bool fromNodes = false,
}) async {
  Future<FireNode?> fetchNode(ID id, {bool merge = false}) async {
    final snapshot = await _firestore
        .collection("Nodes")
        .doc(id)
        .get(const firestore.GetOptions(source: firestore.Source.server));
    if (!snapshot.exists) return null;
    final node = FireNode.fromJson(snapshot.data()!.cast());
    if (merge) await node._merge();
    return node;
  }

  Future<FireMessage?> fetchMessage(ID id, {bool merge = false}) async {
    final snapshot = await _realtime.child("Message").child(id).get();
    if (!snapshot.exists) return null;
    final json = Map<String, String?>.from(snapshot.value as Map);
    final message = FireMessage.fromJson(json);
    if (merge) message._merge();
    return message;
  }

  Future<FireMedia?> fetchMedia(
    ID id, {
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
      if (isVideo) {
        final url = await ref.getDownloadURL();
        media.cachedImage = videoThumbnail = await VideoThumbnail.thumbnailData(
          video: url,
          quality: 50,
        );
      }
      if (merge) {
        media._merge();
        if (withData) {
          await media.write(
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

Database db_<T extends FireObject>() {
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

Future<T?> _local<T extends FireObject>(ID id) async {
  final doc = await db_<T>().document(id);
  if (doc == null) return null;
  return _fromJson<T>(doc.toPlainMap().cast());
}

Future<(T?, GetType)> global<T extends FireObject>(
  ID? id, {
  bool fetch = false,
  bool merge = false,
  bool mediaData = false,
  bool nodesMedia = false,
}) async {
  const def = (null, GetType.empty);
  if (id == null) return def;
  final cached = _globalCache[id];
  if (cached != null && cached is T) return (cached, GetType.cache);
  final localed = await _local<T>(id);
  if (localed != null) return (_globalCache[id] = localed, GetType.cache);
  if (!fetch) return def;
  final fetched = await _fetch<T>(id,
      merge: merge, withData: mediaData, fromNodes: nodesMedia);
  if (fetched != null) return (_globalCache[id] = fetched, GetType.fetch);
  return def;
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

abstract class Down4Object {
  final ID id;
  const Down4Object(this.id);
}

abstract class StaticObject extends Down4Object {
  const StaticObject(super.id);
  Database get db;
  Map<String, Object> toJson();
  Future<void> delete() async {
    await db.purgeDocumentById(id);
  }

  Future<bool> save() async {
    final doc = MutableDocument.withId(id)..setData(toJson());
    return await db.saveDocument(doc);
  }
}

abstract class FireObject extends Down4Object {
  const FireObject(super.id);
  Database _db();

  Future<void> _delete() async => await _db().purgeDocumentById(id);

  Map<String, String> toJson({bool withLocalValues = false});

  Future<void> _merge([Map<String, String>? values]) async {
    var db = _db();
    // first, we get the current doc in the db
    var document = (await db.document(id))?.toMutable();
    bool wasLocal = (document != null);
    // if it wasn't local, we create it
    if (!wasLocal) document = MutableDocument.withId(id);

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
  final ID sender;
  final ID? media, onlineMedia;
  final String? text;
  final Set<ID>? replies, nodes;
  final String? forwarderID;
  final int timestamp;
  bool _isRead, _isSent;

  FireMessage(
    super.id, {
    required this.sender,
    required this.timestamp,
    bool isSaved = false,
    this.media,
    this.onlineMedia,
    this.forwarderID,
    this.text,
    this.nodes,
    this.replies,
    bool isRead = false,
    bool isSent = false,
  })  : _isRead = isRead,
        _isSent = isSent;

  bool get isRead => _isRead;
  bool get isSent => _isSent;

  // Creates a new instance of a messages that will be uploaded
  // removes the replies and local data
  // puts a new timestamp and forwarderID as forwarder and a new ID
  FireMessage forwarded(ID forwarder) {
    return FireMessage(messagePushId(),
        sender: sender,
        timestamp: u.timeStamp(),
        forwarderID: forwarder,
        text: text,
        nodes: nodes,
        onlineMedia: onlineMedia);
  }

  factory FireMessage.fromJson(Map<String, String?> decodedJson) {
    return FireMessage(decodedJson["id"] as ID,
        sender: decodedJson["sender"] as ID,
        forwarderID: decodedJson["forwarderID"],
        text: decodedJson["text"],
        isSaved: decodedJson["isSaved"] == "true",
        media: decodedJson["media"],
        onlineMedia: decodedJson["onlineMedia"],
        timestamp: int.parse(decodedJson["timestamp"] ?? "0"),
        isRead: decodedJson["isRead"] == "true",
        isSent: decodedJson["isSent"] == "true",
        nodes: decodedJson["nodes"]?.split(" ").toSet(),
        replies: decodedJson["replies"]?.split(" ").toSet());
  }

  // Future<void> addReference(ID ref) async {
  //   _references.add(ref);
  //   await _merge({"references": references.join(" ")});
  // }

  // Future<void> removeReference(ID ref) async {
  //   _references.remove(ref);
  //   if (references.isEmpty) return _delete();
  //   await _merge({"references": references.join(" ")});
  // }

  Future<void> markRead() async {
    if (isRead) return;
    _isRead = true;
    await _merge({"isRead": "true"});
  }

  Future<void> markSent() async {
    if (isSent) return;
    _isSent = true;
    await _merge({"isSent": "true"});
  }

  @override
  Map<String, String> toJson({bool withLocalValues = false}) => {
        'id': id,
        if (text != null) 'text': text!,
        'sender': sender,
        'timestamp': timestamp.toString(),
        if (media != null) 'media': media!,
        if (onlineMedia != null) 'onlineMedia': onlineMedia!,
        // if (withLocalValues) 'references': _references.join(" "),
        // if (withLocalValues) 'isSaved': _isSaved.toString(),
        if (withLocalValues) 'isRead': isRead.toString(),
        if (withLocalValues) 'isSent': isSent.toString(),
        if (forwarderID != null) 'forwarderID': forwarderID!,
        if (replies != null) 'replies': replies!.join(" "),
        if (nodes != null) 'nodes': nodes!.join(" "),
      };

  @override
  Database _db() => _messagesDB;
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
  ID? _media;
  bool? _isFriend, _isHidden, _isPrivate;
  final Set<ID>? _snips, _messages;
  final Set<ID>? _group, _publics, _privates, _posts, _admins;
  final String? _owner;
  // final Set<Id>? _nfts;
  // final Set<Id>? _images;
  // final Set<Id>? _videos;
  // final Set<ID>? _children;

  @override
  Database _db() => _nodesDB;

  ID? get media;
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
        if (_publics != null) "children": _publics!.join(" "),
        if (_neuter != null) "neuter": _neuter!.toYouKnow(),
        if (_group != null) "group": _group!.join(" "),
        // if (withLocalValues && _images != null) "images": _images!.join(" "),
        // if (withLocalValues && _videos != null) "videos": _videos!.join(" "),
        // if (withLocalValues && _nfts != null) "nfts": _nfts!.join(" "),
        // if (withLocalValues && _messages != null)
        //   "messages": _messages!.join(" "),
        // if (withLocalValues && _snips != null) "snips": _snips!.join(" "),
        if (withLocalValues) "activity": _activity.toString(),
      };

  FireNode(
    super.id, {
    required int activity,
    required String name,
    String? lastName,
    bool? isFriend,
    bool? isHidden,
    bool? isPrivate,
    String? description,
    Down4Keys? neuter,
    ID? media,
    ID? owner,
    Set<ID>? publics,
    Set<ID>? privates,
    Set<ID>? posts,
    Set<ID>? admins,
    Set<ID>? messages,
    Set<ID>? snips,
    Set<ID>? group,
  })  : _activity = activity,
        _name = name,
        _lastName = lastName,
        _isFriend = isFriend,
        _isPrivate = isPrivate,
        _isHidden = isHidden,
        _description = description,
        _neuter = neuter,
        _media = media,
        _owner = owner,
        _messages = messages,
        _privates = privates,
        _snips = snips,
        _group = group,
        _admins = admins,
        _posts = posts,
        _publics = publics;

  void updateActivity([int? newActivity]) {
    _activity = newActivity ?? u.timeStamp();
    _merge({"activity": _activity.toString()});
  }

  factory FireNode.fromJson(Map<String, String?> json) {
    final id = json["id"] as ID;
    final activity = int.parse(json["activity"] ?? "0");
    final type = Nodes.values.byName(json["type"] as String);
    final media = json["media"];

    final name = json["name"] as String;
    final isFriend = json["isFriend"] == "true";
    final isHidden = json["isHidden"] == "true";
    final isPrivate = json["isPrivate"] == "true";
    final lastName = json["lastName"];
    final description = json["description"];
    final publics = json["publics"]?.split(" ").toSet();
    final privates = json["privates"]?.split(" ").toSet();
    final admins = json["admins"]?.split(" ").toSet();
    final neuter = json["neuter"] != null
        ? Down4Keys.fromYouKnow(json["neuter"] as String)
        : null;
    final group = json["group"]?.split(" ").toSet();
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
            publics: publics!,
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
            isPrivate: isPrivate,
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
            publics: publics!,
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
    throw '$type is not an avaiblable FireNode type';
  }
}

abstract mixin class Branchable implements FireNode {
  Iterable<ID> get children;
}

abstract mixin class Chatable implements FireNode {
  Iterable<ID> get messages;
  Iterable<ID> get snips;
  bool get _noMessagesNorSnips => messages.isEmpty && snips.isEmpty;

  Future<void> addMessageRef(ID msgID) async {
    _messages!.add(msgID);
    _activity = u.timeStamp();
    _isHidden = false;
    await _merge({
      "messages": messages.join(" "),
      "isHidden": _isHidden.toString(),
      "activity": activity.toString(),
    });
  }

  Future<void> _onMessageOrSnipRemoval() async {
    final n = this;
    final nodeIsDeletable = (n is Hyperchat || (n is User && !n.isFriend));
    if (nodeIsDeletable && _noMessagesNorSnips) {
      // need to check if this node is part of a group before deleting it
      // if it's part of a group, we hide it
      final groupIDs = await allGroupIDs();
      if (!groupIDs.contains(id)) {
        await _delete();
      } else {
        await _merge({
          "messages": messages.join(" "),
          "isHidden": true.toString(),
        });
      }
    } else {
      await _merge({
        "messages": messages.join(" "),
        "snips": snips.join(" "),
      });
    }
  }

  Future<void> removeMessageRef(ID msgID) async {
    _messages!.remove(msgID);
    await _onMessageOrSnipRemoval();
  }

  Future<void> addSnipRef(ID snipID) async {
    _snips!.add(snipID);
    _activity = u.timeStamp();
    _isHidden = false;
    await _merge({
      "snips": snips.join(" "),
      "isHidden": false.toString(),
      "activity": u.timeStamp().toString(),
    });
  }

  Future<void> removeSnip(FireMedia snip) async {
    _snips!.remove(snip.id);
    await _onMessageOrSnipRemoval();
  }

  Future<(bool isRead, String preview)> messagingPreview() async {
    //
    // final raw = "SELECT * FROM _ WHERE node = '$id' LIMIT 1";
    // final qq = (await (await AsyncQuery.fromN1ql(_messagesDB, raw)).execute());
    //

    final q = await const QueryBuilder()
        .select(SelectResult.all())
        .from(DataSource.database(_messagesDB).as("messages"))
        .where(Expression.property("node").equalTo(Expression.string(id)))
        .limit(Expression.integer(1))
        .execute();
    final r = await q.allResults();
    if (r.isEmpty) return const (true, "");
    final json = r.single.toPlainMap()["messages"] as Map<String, String?>;
    final msg = FireMessage.fromJson(json);
    final preview = (msg.text ?? "").isEmpty ? "&attachment" : msg.text!;
    return (msg.isRead, preview);

    // final q = await AsyncQuery.fromN1ql(_messagesDB, raw);

    // final def = Future.value(const u.Pair(true, ""));
    // if (messages.isEmpty) def;
    // final lastMsgID = messages.last;

    // final (msg, _) = await global<FireMessage>(lastMsgID);
    // if (msg == null) return def;
    // return u.Pair(msg.isRead, msg.text ?? "&attachment");
  }
}

abstract mixin class Groupable implements FireNode {
  Iterable<ID> get group;
  @override
  String get displayID => group.map((id) => "@$id").join(" ");
}

abstract mixin class Personable implements FireNode {
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

abstract mixin class Editable implements FireNode {
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
      final (m, gt) = await global<FireMedia>(media!);
      m?.removeReference(id);
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
    required Set<ID> publics,
    required Set<ID> messages,
    required Set<ID> snips,
    required super.description,
    required super.lastName,
    required super.media,
    required Down4Keys neuter,
  }) : super(
            isHidden: isHidden,
            isFriend: isFriend,
            publics: publics,
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
  Iterable<ID> get children => _publics!;

  @override
  NodesColor get colorCode =>
      isFriend ? NodesColor.friend : NodesColor.nonFriend;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  ID? get media => _media;

  @override
  String get firstName => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  Nodes get type => Nodes.user;

  @override
  Iterable<ID> get messages => _messages!;

  @override
  Iterable<ID> get snips => _snips!;
}

class Self extends FireNode with Branchable, Personable, Chatable, Editable {
  Self(
    super.id, {
    required super.activity,
    required super.name,
    required super.description,
    required super.lastName,
    required ID media,
    required Set<ID> publics,
    required Set<ID> messages,
    required Set<ID> snips,
  }) : super(
          media: media,
          publics: publics,
          messages: messages,
          snips: snips,
        );

  @override
  NodesColor get colorCode => NodesColor.self;

  @override
  Iterable<ID> get children => _publics!;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  ID get media => _media!;

  @override
  Iterable<ID> get messages => _messages!;

  @override
  String get firstName => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  Iterable<ID> get snips => _snips!;

  @override
  Nodes get type => Nodes.self;
}

class Group extends FireNode with Groupable, Editable, Chatable {
  Group(
    super.id, {
    required super.activity,
    required super.name,
    required bool isPrivate,
    required super.media,
    required Set<ID> messages,
    required Set<ID> snips,
    required Set<ID> group,
  }) : super(
            messages: messages,
            snips: snips,
            group: group,
            isPrivate: isPrivate);

  Future<void> addMembersRef(Iterable<ID> memberIDs) async {
    _group!.addAll(memberIDs);
    await _merge({"group": group.join(" ")});
  }

  bool get isPrivate => _isPrivate!;

  @override
  NodesColor get colorCode => NodesColor.group;

  @override
  String get displayName => _name;

  @override
  Iterable<ID> get group => _group!;

  @override
  ID? get media => _media;

  @override
  Iterable<ID> get messages => _messages!;

  @override
  Iterable<ID> get snips => _snips!;

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
    required Set<ID> messages,
    required Set<ID> snips,
    required Set<ID> group,
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
  Iterable<ID> get group => _group!;

  @override
  ID? get media => _media;

  @override
  Iterable<ID> get messages => _messages!;

  @override
  Iterable<ID> get snips => _snips!;

  @override
  Nodes get type => Nodes.hyperchat;
}

class Payment extends FireNode {
  @override
  int get activity => _payment.tsSeconds;

  @override
  ID? get media => null;

  final Down4Payment _payment;
  final ID selfID;
  Payment(
    super.id, {
    required Down4Payment payment,
    required this.selfID,
  })  : _payment = payment,
        super(activity: payment.tsSeconds, name: payment.id);

  @override
  String get displayName => payment.formattedName(selfID);

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
  final String tinyThumbnail;
  bool _isSaved;
  final ID owner;
  ID? _onlineId;
  int _onlineTimestamp;
  int _lastUse;
  final String extension;
  final String mimetype;
  final double aspectRatio;
  final String? text;
  final int timestamp;
  final Set<ID> _references;
  Uint8List? cachedImage;

  bool get isVideo => extension.isVideoExtension();

  Future<Uint8List?> get imageData async {
    final blob = (await _db().document(id))?.blob("image");
    return cachedImage = await blob?.content();
  }

  Future<Uint8List?> get videoData async {
    final blob = (await _db().document(id))?.blob("video");
    return blob?.content();
  }

  @override
  Database _db() => _mediasDB;

  int get onlineTimestamp => _onlineTimestamp;

  String? get onlineId => _onlineId;

  FireMedia(
    super.id, {
    required this.owner,
    required this.timestamp,
    required this.aspectRatio,
    required this.extension,
    required this.mimetype,
    required Set<ID> references,
    required this.tinyThumbnail,
    int onlineTimestamp = 0,
    int lastUse = 0,
    ID? onlineId,
    bool isSaved = false,
    this.isLocked = false,
    this.isPaidToView = false,
    this.isReversed = false,
    this.isPaidToOwn = false,
    this.isSquared = false,
    this.text,
  })  : _references = references,
        _lastUse = lastUse,
        _isSaved = isSaved,
        _onlineId = onlineId,
        _onlineTimestamp = onlineTimestamp;

  Future<void> use() async {
    _lastUse = u.timeStamp();
    await _merge({"lastUse": _lastUse.toString()});
  }

  Future<void> updateSaveStatus(bool newSaveStatus) async {
    if (!newSaveStatus && _references.isEmpty) return await _delete();
    _isSaved = newSaveStatus;
    await _merge({"isSaved": _isSaved.toString()});
  }

  Future<void> updateOnlineReference(ID newOnlineId, int newStamp) async {
    if (newStamp < onlineTimestamp) return;
    _onlineId = newOnlineId;
    _onlineTimestamp = newStamp;
    await _merge({
      "onlineTimestamp": _onlineTimestamp.toString(),
      "onlineId": newOnlineId,
    });
  }

  Future<void> addReference(ID reference) async {
    _references.add(reference);
    await _merge({"references": _references.join(" ")});
  }

  Future<void> removeReference(ID reference) async {
    _references.remove(reference);
    if (_references.isEmpty && !_isSaved) {
      await _delete();
    } else {
      await _merge({"references": _references.join(" ")});
    }
  }

  Future<void> delete() async => await _delete();

  Future<void> write({Uint8List? videoData, Uint8List? imageData}) async {
    if (videoData == null && imageData == null) return;
    final doc = MutableDocument.withId(id);
    if (isVideo) {
      final videoBlob = Blob.fromData(mimetype, videoData!);
      doc.setBlob(videoBlob, key: "video");
    }
    final imageMime = isVideo ? "image/png" : mimetype;
    final imageBlob = Blob.fromData(imageMime, imageData!);
    doc.setBlob(imageBlob, key: "image");
    doc.setData(toJson(withLocalValues: true));
    await _db().saveDocument(doc);
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
      lastUse: int.parse(decodedJson["lastUse"]!),
      tinyThumbnail: decodedJson["tinyThumbnail"]!,
      onlineTimestamp: int.parse(decodedJson["onlineTimestamp"]!),
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
        "tinyThumbnail": tinyThumbnail,
        "onlineTimestamp": onlineTimestamp.toString(),
        if (text != null) "text": text!,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isLocked": isLocked.toString(),
        "isPaidToView": isPaidToView.toString(),
        "isPaidToOwn": isPaidToOwn.toString(),
        "aspectRatio": aspectRatio.toString(),
        if (withLocalValues) "isVideo": isVideo.toString(), // for index
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

//   final query = await Query.fromN1qlAsync(_nodesDB, raw);
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
