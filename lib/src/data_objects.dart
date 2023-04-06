import 'dart:async';
import 'dart:io';

import 'package:down4/src/globals.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/render_objects/palette.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'couch.dart';
import '_dart_utils.dart' as u;
import 'dart:typed_data' show Uint8List;
import 'bsv/types.dart';
import 'package:cbl/cbl.dart';

final _messageStore =
    FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _nodesStore = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

typedef ID = String;

abstract class Down4Object {
  ID get id;
}

abstract class FireObject extends Down4Object {
  Database get dbb;

  void cache() => gCache(this);

  Future<void> delete() async => await dbb.purgeDocumentById(id);

  Map<String, Object> toJson({bool toLocal = false});

  Future<void> merge([Map<String, Object?>? values]) async {
    // first, we get the current doc in the db
    var document = (await dbb.document(id))?.toMutable();
    bool wasLocal = (document != null);
    // if it wasn't local, we create it
    if (!wasLocal) document = MutableDocument.withId(id);

    Map<String, Object?> toMerge;
    if (!wasLocal) {
      // then we need to merge the whole thing with the parameter values
      toMerge = {...toJson(toLocal: true), ...?values};
    } else {
      // we merge given values, or the values from the probably freshly
      // fetched object without the local values to not overwrite them
      toMerge = (values ?? toJson(toLocal: false));
    }

    toMerge.forEach((key, value) {
      document!.setValue(value, key: key);
    });

    await dbb.saveDocument(document);
  }

  // static T fromJson<T extends FireObject>(Map<String, Object?> json) {
  //   switch (T) {
  //     case FireMessage:
  //       return FireMessage.fromJson(json.cast()) as T;
  //     case FireNode:
  //       return FireNode.fromJson(json.cast()) as T;
  //     case FireMedia:
  //       return FireMedia.fromJson(json.cast()) as T;
  //   }
  //   throw '$T is not a supported type for the fromJson function';
  // }
}

class FireMessage extends FireObject {
  @override
  Database get dbb => messagesDB;

  @override
  final ID id;
  final ID senderID, root;
  final ID? mediaID, onlineMediaID;
  final String? text;
  final Set<ID>? replies, nodes;
  final String? forwarderID;
  final int timestamp;
  final bool isSnip;
  bool _isRead, _isSent, _isSaved;

  FireMessage(
    this.id, {
    required this.root,
    required this.senderID,
    required this.timestamp,
    bool isSaved = false,
    this.mediaID,
    this.onlineMediaID,
    this.forwarderID,
    this.text,
    this.nodes,
    this.replies,
    required this.isSnip,
    bool isRead = false,
    bool isSent = false,
  })  : _isRead = isRead,
        _isSent = isSent,
        _isSaved = isSaved;

  bool get isRead => _isRead;
  bool get isSent => _isSent;

  // Creates a new instance of a messages that will be uploaded
  // removes the replies and local data
  // puts a new timestamp and forwarderID as forwarder and a new ID
  FireMessage forwarded(ID forwarder, ID root) {
    return FireMessage(messagePushId(),
        root: root,
        senderID: senderID,
        timestamp: u.makeTimestamp(),
        forwarderID: forwarder,
        text: text,
        nodes: nodes,
        isSnip: false,
        onlineMediaID: onlineMediaID);
  }

  factory FireMessage.fromJson(Map<String, String?> decodedJson) {
    return FireMessage(decodedJson["id"] as ID,
        root: decodedJson["root"] as ID,
        senderID: decodedJson["senderID"] as ID,
        forwarderID: decodedJson["forwarderID"],
        text: decodedJson["text"],
        isSaved: decodedJson["isSaved"] == "true",
        mediaID: decodedJson["mediaID"],
        isSnip: decodedJson["isSnip"] == "true",
        onlineMediaID: decodedJson["onlineMediaID"],
        timestamp: int.parse(decodedJson["timestamp"] ?? "0"),
        isRead: decodedJson["isRead"] == "true",
        isSent: decodedJson["isSent"] == "true",
        nodes: decodedJson["nodes"]?.split(" ").toSet(),
        replies: decodedJson["replies"]?.split(" ").toSet());
  }

  Future<void> markRead() async {
    if (isRead) return;
    _isRead = true;
    await merge({"isRead": "true"});
  }

  Future<void> markSent() async {
    if (isSent) return;
    _isSent = true;
    await merge({"isSent": "true"});
  }

  Future<void> updateSavedStatus(bool isSaved) async {
    _isSaved = isSaved;
    await merge({"isSaved": _isSaved.toString()});
  }

  @override
  Map<String, String> toJson({bool toLocal = false}) => {
        'id': id,
        'root': root,
        if (text != null) 'text': text!,
        'senderID': senderID,
        'timestamp': timestamp.toString(),
        if (mediaID != null) 'mediaID': mediaID!,
        if (onlineMediaID != null) 'onlineMediaID': onlineMediaID!,
        'isSnip': isSnip.toString(),
        if (toLocal) 'isRead': isRead.toString(),
        if (toLocal) 'isSent': isSent.toString(),
        if (forwarderID != null) 'forwarderID': forwarderID!,
        if (replies != null) 'replies': replies!.join(" "),
        if (nodes != null) 'nodes': nodes!.join(" "),
      };
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
  @override
  final ID id;
  int _activity;
  String _name;
  String? _lastName, _description;
  final Down4Keys? _neuter;
  ID? _mediaID;
  bool? _isFriend, _isHidden, _isPrivate;
  final Set<ID>? _group, _publics, _privates, _posts, _admins;
  final ID? _ownerID;

  ID? get mediaID;
  NodesColor get colorCode;
  Nodes get type;
  String get displayID;
  String get displayName;
  int get activity => _activity;

  @override
  Map<String, String> toJson({bool toLocal = true}) => {
        "type": type.name,
        "id": id,
        "name": _name,
        if (_ownerID != null) "ownerID": _ownerID!,
        if (toLocal && _isFriend != null) "isFriend": _isFriend!.toString(),
        if (toLocal && _isHidden != null) "isHidden": _isHidden!.toString(),
        if (_lastName != null) "lastName": _lastName!,
        if (_mediaID != null) "mediaID": _mediaID!,
        if (_publics != null) "publics": _publics!.join(" "),
        if (_posts != null) "posts": _posts!.join(" "),
        if (_privates != null) "privates": _privates!.join(" "),
        if (_admins != null) "admins": _admins!.join(" "),
        if (_neuter != null) "neuter": _neuter!.toYouKnow(),
        if (_group != null) "group": _group!.join(" "),
        if (toLocal) "activity": _activity.toString(),
      };

  FireNode(this.id,
      {required int activity,
      required String name,
      String? lastName,
      bool? isFriend,
      bool? isHidden,
      bool? isPrivate,
      String? description,
      Down4Keys? neuter,
      ID? mediaID,
      ID? owner,
      Set<ID>? publics,
      Set<ID>? privates,
      Set<ID>? posts,
      Set<ID>? admins,
      Set<ID>? group})
      : _activity = activity,
        _name = name,
        _lastName = lastName,
        _isFriend = isFriend,
        _isPrivate = isPrivate,
        _isHidden = isHidden,
        _description = description,
        _neuter = neuter,
        _mediaID = mediaID,
        _ownerID = owner,
        _privates = privates,
        _group = group,
        _admins = admins,
        _posts = posts,
        _publics = publics;

  void updateActivity([int? newActivity]) {
    _activity = newActivity ?? u.makeTimestamp();
    merge({"activity": _activity.toString()});
  }

  factory FireNode.fromJson(Map<String, String?> json) {
    final id = json["id"] as ID;
    final activity = int.parse(json["activity"] ?? "0");
    final type = Nodes.values.byName(json["type"] as String);
    final mediaID = json["mediaID"];

    final ownerID = json["ownerID"];
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

    switch (type) {
      case Nodes.user:
        return User(id,
            activity: activity,
            name: name,
            lastName: lastName,
            mediaID: mediaID,
            isHidden: isHidden,
            isFriend: isFriend,
            publics: publics!,
            neuter: neuter!,
            description: description);

      case Nodes.hyperchat:
        return Hyperchat(id,
            activity: activity,
            firstWord: name,
            secondWord: lastName!,
            mediaID: mediaID,
            group: group!);

      case Nodes.group:
        return Group(id,
            isPrivate: isPrivate,
            activity: activity,
            name: name,
            mediaID: mediaID,
            group: group!);

      case Nodes.self:
        return Self(id,
            activity: activity,
            name: name,
            description: description,
            lastName: lastName,
            mediaID: mediaID!,
            publics: publics!,
            privates: privates!,
            neuter: neuter!);

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

mixin Branchable on FireNode {
  Iterable<ID> get children;
}

mixin Chatable on FireNode {
  Future<Iterable<ID>> orderedChatIDs() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '$id' AND isSnip = 'false'
        ORDER BY id DESC
        """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    return (await r.allResults()).map((e) => e.toPlainMap()["id"] as ID);
  }

  Future<Iterable<ID>> unreadSnipIDs() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '$id' AND isSnip = 'true' AND isRead = 'false'
        ORDER BY id ASC
        """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    return (await r.allResults()).map((e) => e.toPlainMap()["id"] as ID);
  }

  Stream<FireMessage> loadSnips() async* {
    final raw = "SELECT * FROM _ WHERE isSnip = 'true' AND root = '$id'";
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    await for (final a in r.asStream()) {
      final json = a.toPlainMap()["messages"] as Map<String, String?>;
      yield FireMessage.fromJson(json);
    }
  }

  Future<FireMessage?> lastMessage() async {
    final raw = """
            SELECT * FROM _ AS m
            WHERE root = '$id'
            ORDER BY META(m).id DESC LIMIT 1
            """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    final a = await r.allResults();

    if (a.isEmpty) return null;
    final json = a.single.toPlainMap()["m"] as Map<String, String?>;
    return FireMessage.fromJson(json);
  }
}

mixin Groupable on Chatable {
  Iterable<ID> get group;
  @override
  String get displayID => group.map((id) => "@$id").join(" ");
}

mixin Personable on Chatable {
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
    await merge({"name": _name});
  }

  Future<void> editLastName(String? newLastName) async {
    _lastName = newLastName;
    await merge({"lastName": _lastName ?? ""});
  }

  Future<void> editImage(FireMedia newImage) async {
    _mediaID = newImage.id;
    await merge({"media": _mediaID!});
  }

  Future<void> editDescription(String newDescription) async {
    _description = newDescription;
    await merge({"description": _description!});
  }
}

class User extends FireNode with Branchable, Chatable, Personable {
  @override
  Database get dbb => nodesDB;

  User(
    super.id, {
    required super.activity,
    required super.name,
    required bool isHidden,
    required bool isFriend,
    required Set<ID> publics,
    required super.description,
    required super.lastName,
    required super.mediaID,
    required Down4Keys neuter,
  }) : super(isHidden: isHidden, isFriend: isFriend, publics: publics);

  Future<void> updateFriendStatus(bool newFriendStatus) async {
    _isFriend = newFriendStatus;
    Map<String, String> mergeInfo = {};
    mergeInfo["isFriend"] = _isFriend.toString();
    if (_isFriend!) mergeInfo["isHidden"] = false.toString();
    await merge(mergeInfo);
  }

  Future<void> updateHiddenStatus(bool newHiddenStatus) async {
    _isHidden = newHiddenStatus;
    await merge({"isHidden": _isHidden.toString()});
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
  ID? get mediaID => _mediaID;

  @override
  String get firstName => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  Nodes get type => Nodes.user;
}

class Self extends FireNode with Branchable, Chatable, Personable, Editable {
  @override
  Database get dbb => nodesDB;

  Self(
    super.id, {
    required super.activity,
    required super.name,
    required super.description,
    required super.lastName,
    required Down4Keys neuter,
    required ID mediaID,
    required Set<ID> publics,
    required Set<ID> privates,
  }) : super(
            mediaID: mediaID,
            publics: publics,
            neuter: neuter,
            privates: privates);

  @override
  NodesColor get colorCode => NodesColor.self;

  @override
  Iterable<ID> get children => _publics!;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  ID get mediaID => _mediaID!;

  @override
  String get firstName => _name;

  @override
  Down4Keys get neuter => _neuter!;

  static Future<Self?> loadSelf() async {
    const raw = "SELECT * FROM _ AS n WHERE n.type = 'self'";

    final q = await AsyncQuery.fromN1ql(nodesDB, raw);
    final e = await q.execute();
    final r = await e.allResults();

    if (r.isEmpty) return null;
    final json = r.single.toPlainMap();
    final jsonNode = Map<String, String?>.from(json["n"] as Map);
    final self = fromJson<Self>(jsonNode)..cache();
    await global<FireMedia>(self.mediaID);
    return self;
  }

  @override
  Nodes get type => Nodes.self;
}

class Group extends FireNode with Chatable, Groupable, Editable {
  @override
  Database get dbb => nodesDB;

  Group(
    super.id, {
    required super.activity,
    required super.name,
    required bool isPrivate,
    required super.mediaID,
    required Set<ID> group,
  }) : super(group: group, isPrivate: isPrivate);

  Future<void> addMembersRef(Iterable<ID> memberIDs) async {
    _group!.addAll(memberIDs);
    await merge({"group": group.join(" ")});
  }

  bool get isPrivate => _isPrivate!;

  @override
  NodesColor get colorCode => NodesColor.group;

  @override
  String get displayName => _name;

  @override
  Iterable<ID> get group => _group!;

  @override
  ID? get mediaID => _mediaID;

  @override
  Nodes get type => Nodes.group;
}

class Hyperchat extends FireNode with Chatable, Groupable {
  @override
  Database get dbb => nodesDB;

  Hyperchat(
    super.id, {
    required super.activity,
    required String firstWord,
    required String secondWord,
    required super.mediaID,
    required Set<ID> group,
  }) : super(group: group, name: firstWord, lastName: secondWord);

  @override
  NodesColor get colorCode => NodesColor.group;

  @override
  String get displayName => "$_name $_lastName";

  @override
  Iterable<ID> get group => _group!;

  @override
  ID? get mediaID => _mediaID;

  @override
  Nodes get type => Nodes.hyperchat;
}

class Payment extends FireNode {
  @override
  Database get dbb => throw "Don't merge palette payment";

  @override
  int get activity => _payment.tsSeconds;

  @override
  ID? get mediaID => null;

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
  @override
  Database get dbb => mediasDB;

  @override
  final ID id;
  final bool isReversed, isLocked, isPaidToView, isPaidToOwn, isSquared;
  String? cachePath, cachedUrl;
  String? tinyThumbnail;
  bool _isSaved;
  final ID ownerID;
  ID? _onlineID;
  int _onlineTimestamp;
  int _lastUse;
  final String mime;
  final double aspectRatio;
  final String? text;
  final int timestamp;
  Uint8List? cachedImage;

  String get extension => extensionFromMime(mime);

  bool get isVideo => extension.isVideoExtension();

  Future<File?> get file async {
    if (cachePath == null) return null;
    if (!await File(cachePath!).exists()) return null;
    return File(cachePath!);
  }

  Future<String?> get url async {
    if (!onlineTimestamp.isExpired && onlineID != null) {
      // online time stamp is not expired, online id isn't null
      // good chances we will find the message media URL
      try {
        return cachedUrl = await _messageStore.ref(onlineID!).getDownloadURL();
      } catch (e) {
        return null;
      }
      // else if can try to fetch a node image
    } else {
      try {
        return cachedUrl = await _nodesStore.ref(id).getDownloadURL();
      } catch (e) {
        return null;
      }
    }
  }

  Future<Uint8List?> get imageData async {
    final blob = (await dbb.document(id))?.blob("image");
    return cachedImage = await blob?.content();
  }

  Future<Uint8List?> get videoData async {
    final blob = (await dbb.document(id))?.blob("video");
    return blob?.content();
  }

  int get onlineTimestamp => _onlineTimestamp;

  String? get onlineID => _onlineID;

  FireMedia(this.id,
      {required this.ownerID,
      required this.timestamp,
      required this.aspectRatio,
      required this.mime,
      this.cachePath,
      this.tinyThumbnail,
      int onlineTimestamp = 0,
      int lastUse = 0,
      ID? onlineID,
      bool isSaved = false,
      this.isLocked = false,
      this.isPaidToView = false,
      this.isReversed = false,
      this.isPaidToOwn = false,
      this.isSquared = false,
      this.text})
      : _lastUse = lastUse,
        _isSaved = isSaved,
        _onlineID = onlineID,
        _onlineTimestamp = onlineTimestamp;

  FireMedia copy() {
    return FireMedia.fromJson(toJson(toLocal: true));
  }

  Future<FireMedia?> withNewOwnership(ID newOwner,
      {bool recalculateID = false}) async {
    final json = toJson(toLocal: true);
    json["ownerID"] = newOwner;
    if (recalculateID) {
      Uint8List? data;
      if (cachePath != null) {
        data = File(cachePath!).readAsBytesSync();
      } else {
        data = await (isVideo ? videoData : imageData);
      }
      if (data == null) {
        print("Cannot recalculate the ID in withNewOwnership: no data");
        return null;
      }
      json["id"] = u.deterministicMediaID(data, newOwner);
    }
    return FireMedia.fromJson(json)..cachePath = cachePath;
  }

  Future<void> use() async {
    _lastUse = u.makeTimestamp();
    await merge({"lastUse": _lastUse.toString()});
  }

  Future<void> updateSaveStatus(bool newSaveStatus) async {
    _isSaved = newSaveStatus;
    await merge({"isSaved": _isSaved.toString()});
  }

  Future<void> updateOnlineReference(ID newOnlineId, int newStamp) async {
    if (newStamp < onlineTimestamp) return;
    _onlineID = newOnlineId;
    _onlineTimestamp = newStamp;
    await merge({
      "onlineTimestamp": _onlineTimestamp.toString(),
      "onlineId": newOnlineId,
    });
  }

  Future<void> writeFromCachedPath() async {
    if (cachePath == null) return;
    final d = File(cachePath!).readAsBytesSync();
    Uint8List? tn;
    if (isVideo) {
      tn = await VideoThumbnail.thumbnailData(video: cachePath!, quality: 80);
    }
    await write(imageData: isVideo ? tn! : d, videoData: isVideo ? d : null);
  }

  Future<void> write({
    Uint8List? videoData,
    required Uint8List imageData,
  }) async {
    tinyThumbnail ??= makeTiny(imageData);
    final doc = MutableDocument.withId(id);
    doc.setData(toJson(toLocal: true));
    if (isVideo && videoData != null) {
      final videoBlob = Blob.fromData(mime, videoData);
      doc.setBlob(videoBlob, key: "video");
    }
    final imageMime = isVideo ? "image/png" : mime;
    final imageBlob = Blob.fromData(imageMime, imageData);
    doc.setBlob(imageBlob, key: "image");
    final success = await dbb.saveDocument(doc);
    if (!success) print("Error writing media document!");
    return;
  }

  factory FireMedia.fromJson(Map<String, String?> decodedJson) {
    return FireMedia(decodedJson["id"]!,
        ownerID: decodedJson["ownerID"]!,
        timestamp: int.parse(decodedJson["timestamp"]!),
        mime: decodedJson["mime"]!,
        onlineID: decodedJson["onlineID"],
        lastUse: int.parse(decodedJson["lastUse"] ?? "0"),
        tinyThumbnail: decodedJson["tinyThumbnail"],
        onlineTimestamp: int.parse(decodedJson["onlineTimestamp"]!),
        isSaved: decodedJson["isSaved"] == "true",
        isReversed: decodedJson["isReversed"] == "true",
        isSquared: decodedJson["isSquared"] == "true",
        isLocked: decodedJson["isLocked"] == "true",
        isPaidToOwn: decodedJson["isPaidToView"] == "true",
        isPaidToView: decodedJson["isPaidToOwn"] == "true",
        aspectRatio: double.parse(decodedJson["aspectRatio"]!),
        text: decodedJson["text"]);
  }

  @override
  Map<String, String> toJson({bool toLocal = true}) => {
        "id": id,
        "ownerID": ownerID,
        "timestamp": timestamp.toString(),
        "mime": mime,
        if (onlineID != null) "onlineID": onlineID!,
        if (tinyThumbnail != null) "tinyThumbnail": tinyThumbnail!,
        "onlineTimestamp": onlineTimestamp.toString(),
        if (text != null) "text": text!,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isLocked": isLocked.toString(),
        "isPaidToView": isPaidToView.toString(),
        "isPaidToOwn": isPaidToOwn.toString(),
        "aspectRatio": aspectRatio.toString(),
        if (toLocal) "lastUse": _lastUse.toString(),
        if (toLocal) "isVideo": isVideo.toString(),
        if (toLocal) "isSaved": _isSaved.toString(),
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

class ExchangeRate extends FireObject {
  @override
  Database get dbb => personalDB;

  @override
  ID get id => "exchangeRate";
  int lastUpdate;
  double rate;
  ExchangeRate({required this.lastUpdate, required this.rate});

  static Future<ExchangeRate> get exchangeRate async {
    final doc = await personalDB.document("exchangeRate");
    if (doc == null) return ExchangeRate(lastUpdate: 0, rate: 0)..merge();
    return ExchangeRate.fromJson(doc.toPlainMap());
  }

  factory ExchangeRate.fromJson(Map<String, Object?> decodedJson) {
    return ExchangeRate(
      lastUpdate: decodedJson["lastUpdate"] as int,
      rate: decodedJson["rate"] as double,
    );
  }

  @override
  Map<String, Object> toJson({bool toLocal = true}) => {
        "rate": rate,
        "lastUpdate": lastUpdate,
      };
}

class Token extends FireObject {
  @override
  Database get dbb => personalDB;

  @override
  ID get id => "token";

  String token;
  Token(this.token);

  @override
  Map<String, String> toJson({bool toLocal = true}) => {"token": token};

  factory Token.fromJson(Map<String, Object?> json) {
    return Token(json["token"] as String);
  }
}
