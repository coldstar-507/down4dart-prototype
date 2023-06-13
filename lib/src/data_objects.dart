import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:down4/src/globals.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/themes.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart' show Color, Image;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '_dart_utils.dart';
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

  @override
  bool operator ==(Object other) => other is Down4Object && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

abstract class FireObject extends Down4Object {
  Database get dbb;
  // @override
  // final ID id;
  // FireObject(this.id);

  void cache() => gCache(this);

  Future<void> delete() async {
    print("Deleting $runtimeType from dbb: ${dbb.name}");
    unCache(id);
    await dbb.purgeDocumentById(id);
    final ref = this;
    if (ref is FireMedia && ref.isVideo) {
      final f = ref.videoFile;
      f?.delete();
    }
  }

  Map<String, dynamic> toJson({bool toLocal = false});

  Future<void> merge([Map<String, Object?>? values]) async {
    print("DBB NAME=${dbb.name}");
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

abstract class FireSendable extends FireObject {
  @override
  final ID id;
  final ID root, senderID;
  final ID? mediaID;
  int? _onlineMediaTimestamp;
  ID? _onlineMediaID;
  bool _isSent;

  FireSendable(
    this.id, {
    required this.root,
    required this.senderID,
    this.mediaID,
    int? onlineMediaTimestamp,
    ID? onlineMediaID,
    bool? isSent,
  })  : _isSent = isSent ?? false,
        _onlineMediaTimestamp = onlineMediaTimestamp,
        _onlineMediaID = onlineMediaID;

  bool get isSent => _isSent;
  int get onlineMediaTimestamp => _onlineMediaTimestamp ?? 0;
  ID? get onlineMediaID => _onlineMediaID;

  Future<void> markSent() => merge({"isSent": (_isSent = true).toString()});

  // Future<void> setOnlineMediaInfo(ID onlineMediaID, int timestamp) async {
  //   if (timestamp > onlineMediaTimestamp) {
  //     _onlineMediaID = onlineMediaID;
  //     _onlineMediaTimestamp = timestamp;
  //     await merge({
  //       "onlineMediaID": _onlineMediaID,
  //       "onlineMediaTimestamp": _onlineMediaTimestamp,
  //     });
  //   }
  // }

  @override
  Map<String, String> toJson({bool toLocal = false}) => {
        "id": id,
        "root": root,
        "senderID": senderID,
        "isSent": isSent.toString(),
        if (mediaID != null) "mediaID": mediaID!,
        if (_onlineMediaID != null) "onlineMediaID": _onlineMediaID!,
        if (_onlineMediaTimestamp != null)
          "onlineMediaTimestamp": _onlineMediaTimestamp!.toString(),
      };
}

class ChatReaction extends FireSendable {
  @override
  ID get mediaID => super.mediaID!;

  final ID messageID;
  final Set<ID> reactors;

  int get reactionCount => reactors.length;

  ChatReaction(
    super.id, {
    required super.root,
    required super.senderID,
    super.onlineMediaID,
    super.onlineMediaTimestamp,
    super.isSent,
    required ID mediaID,
    required this.messageID,
    required this.reactors,
  }) : super(mediaID: mediaID);

  @override
  Database get dbb => reactionsDB;

  factory ChatReaction.fromJson(Map<String, Object?> json) {
    final onlineMediaTimestamp = json["onlineMediaTimestamp"] as String?;
    final isSent = json["isSent"] as String?;
    final reactors = json["reactors"] as String?;
    return ChatReaction(
      json["id"] as ID,
      root: json["root"] as ID,
      senderID: json["senderID"] as ID,
      mediaID: json["mediaID"] as ID,
      messageID: json["messageID"] as ID,
      onlineMediaID: json["onlineMediaID"] as ID?,
      onlineMediaTimestamp: int.tryParse(onlineMediaTimestamp ?? ""),
      isSent: bool.tryParse(isSent ?? ""),
      reactors: reactors?.split(" ").toSet() ?? {},
    );
  }

  Future<void> addReactor(ID reactor) async {
    reactors.add(reactor);
    await merge({"reactors": reactors.join(" ")});
  }

  @override
  Map<String, String> toJson({bool toLocal = false}) => {
        ...super.toJson(toLocal: toLocal),
        "messageID": messageID,
        if (toLocal) "reactors": reactors.join(" "),
      };
}

class FireMessage extends FireSendable {
  @override
  Database get dbb => messagesDB;

  // @override
  // final ID id;
  // final ID senderID, root;
  // final ID? mediaID;
  final String? text;
  final Set<ID>? replies, nodes;
  final String? forwardedFrom;
  final int timestamp;
  final bool isSnip;
  bool _isRead, _isSaved;
  // int? _onlineMediaTimestamp;
  // ID? _onlineMediaID;

  // ID? get onlineMediaID => _onlineMediaID;
  // int? get onlineMediaTimestamp => _onlineMediaTimestamp;

  @override
  Map<String, String> toJson({bool toLocal = false}) => {
        ...super.toJson(toLocal: toLocal),
        // 'id': id,
        // 'root': root,
        if (text != null) 'text': text!,
        // 'senderID': senderID,
        'timestamp': timestamp.toString(),
        // if (mediaID != null) 'mediaID': mediaID!,
        // if (_onlineMediaID != null) 'onlineMediaID': _onlineMediaID!,
        // if (_onlineMediaTimestamp != null)
        //   'onlineMediaTimestamp': _onlineMediaTimestamp!.toString(),
        'isSnip': isSnip.toString(),
        if (toLocal) 'isRead': isRead.toString(),
        if (toLocal) 'isSent': isSent.toString(),
        if (forwardedFrom != null) 'forwarderID': forwardedFrom!,
        if (replies != null) 'replies': replies!.join(" "),
        if (nodes != null) 'nodes': nodes!.join(" "),
      };

  FireMessage(super.id,
      {required super.root,
      required super.senderID,
      required this.timestamp,
      bool isSaved = false,
      super.mediaID,
      super.onlineMediaID,
      super.onlineMediaTimestamp,
      this.forwardedFrom,
      this.text,
      this.nodes,
      this.replies,
      required this.isSnip,
      bool isRead = false,
      bool isSent = false})
      :
        // _onlineMediaTimestamp = onlineMediaTimestamp,
        // _onlineMediaID = onlineMediaID,
        _isRead = isRead,
        _isSaved = isSaved,
        super(isSent: isSent);

  bool get isRead => _isRead;
  // bool get isSent => _isSent;

  // Creates a new instance of a messages that will be uploaded
  // removes the replies and local data
  // puts a new timestamp and forwarderID as forwarder and a new ID

  String get messagePreview => forwardedFrom != null
      ? ">> forwarded message"
      : (text ?? "").isEmpty
          ? "&attachment"
          : text!;

  // FireMessage copy() => FireMessage.fromJson(toJson(toLocal: true));

  Future<List<ChatReaction>> get reactions async {
    final raw = "SELECT * FROM _ WHERE messageID = '$id'";
    final q = await AsyncQuery.fromN1ql(reactionsDB, raw);
    final e = await q.execute();
    final r = await e.allResults();
    return r.map((e) {
      final json = e.toPlainMap()["_"] as Map<String, Object?>;
      print("CHAT REACTION JSON = $json");
      return ChatReaction.fromJson(json);
    }).toList();
  }

  FireMessage forwarded(ID newSenderID, ID newRoot) {
    return FireMessage(messagePushId(),
        root: newRoot,
        senderID: newSenderID,
        timestamp: u.makeTimestamp(),
        forwardedFrom: forwardedFrom ?? senderID,
        text: text,
        nodes: nodes,
        isSnip: false,
        mediaID: mediaID,
        onlineMediaID: _onlineMediaID);
  }

  factory FireMessage.fromJson(Map<String, Object?> decodedJson) {
    final omts = decodedJson["onlineMediaTimestamp"] as String?;
    return FireMessage(decodedJson["id"] as ID,
        root: decodedJson["root"] as ID,
        senderID: decodedJson["senderID"] as ID,
        forwardedFrom: decodedJson["forwarderID"] as ID?,
        text: decodedJson["text"] as String?,
        isSaved: decodedJson["isSaved"] == "true",
        mediaID: decodedJson["mediaID"] as ID?,
        isSnip: decodedJson["isSnip"] == "true",
        onlineMediaTimestamp: omts != null ? int.parse(omts) : null,
        onlineMediaID: decodedJson["onlineMediaID"] as ID?,
        timestamp: int.parse(decodedJson["timestamp"] as String),
        isRead: decodedJson["isRead"] == "true",
        isSent: decodedJson["isSent"] == "true",
        nodes: (decodedJson["nodes"] as String?)?.split(" ").toSet(),
        replies: (decodedJson["replies"] as String?)?.split(" ").toSet());
  }

  Future<void> markRead() async {
    if (isRead) return;
    _isRead = true;
    await merge({"isRead": "true"});
  }

  // Future<void> markSent() async {
  //   if (isSent) return;
  //   _isSent = true;
  //   await merge({"isSent": "true"});
  // }

  Future<void> updateSavedStatus(bool isSaved) async {
    _isSaved = isSaved;
    await merge({"isSaved": _isSaved.toString()});
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
  theme,
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
  Database get dbb => nodesDB;

  @override
  final ID id;
  int _activity;
  String _name;
  String? _lastName, _description;
  final Down4Keys? _neuter;
  ID? _mediaID;
  bool? _isFriend, _isPrivate; //, _isHidden;
  final Set<ID>? _group, _publics, _privates, _posts, _admins;
  final ID? _ownerID;

  ID? get mediaID;
  Color get color;
  // NodesColor get colorCode;
  Nodes get type;
  String get displayID;
  String get displayName;
  int get activity => _activity;

  @override
  Map<String, String> toJson({bool toLocal = true}) => {
        "id": id,
        "type": type.name,
        "name": _name,
        if (_ownerID != null) "ownerID": _ownerID!,
        if (toLocal && _isFriend != null) "isFriend": _isFriend!.toString(),
        // if (toLocal && _isHidden != null) "isHidden": _isHidden!.toString(),
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
        // _isHidden = isHidden ?? false,
        _description = description,
        _neuter = neuter,
        _mediaID = mediaID,
        _ownerID = owner,
        _privates = privates,
        _group = group,
        _admins = admins,
        _posts = posts,
        _publics = publics;

  FireMessage copy() => FireMessage.fromJson(toJson(toLocal: true));

  void updateActivity([int? newActivity]) {
    _activity = newActivity ?? u.makeTimestamp();
    merge({"activity": _activity.toString()});
  }

  factory FireNode.fromJson(Map<String, Object?> json) {
    final id = json["id"] as ID;
    final activity = int.parse(json["activity"] as String? ?? "0");
    final type = Nodes.values.byName(json["type"] as String);
    final mediaID = json["mediaID"] as ID?;

    final ownerID = json["ownerID"] as ID?;
    final name = json["name"] as String;
    final isFriend = json["isFriend"] == "true";
    // final isHidden = json["isHidden"] == "true";
    final isPrivate = json["isPrivate"] == "true";
    final lastName = json["lastName"] as String?;
    final description = json["description"] as String?;
    final publics = (json["publics"] as String?)?.split(" ").toSet();
    final privates = (json["privates"] as String?)?.split(" ").toSet();
    final admins = (json["admins"] as String?)?.split(" ").toSet();
    final neuter = json["neuter"] != null
        ? Down4Keys.fromYouKnow(json["neuter"] as String)
        : null;
    final group = (json["group"] as String?)?.split(" ").toSet();

    switch (type) {
      case Nodes.user:
        return User(id,
            activity: activity,
            name: name,
            lastName: lastName,
            mediaID: mediaID,
            // isHidden: isHidden,
            isFriend: isFriend,
            publics: publics ?? {},
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
      case Nodes.theme:
        // TODO: Handle this case.
        break;
    }
    throw '$type is not an avaiblable FireNode type';
  }
}

mixin Branchable on FireNode {
  Iterable<ID> get children;
}

mixin Chatable on FireNode {
  List<ID> targets({required ID selfID}) {
    final ref = this;
    if (ref is Groupable) {
      return List<ID>.from(ref.group)..remove(selfID);
    } else {
      return [ref.id];
    }
  }

  Future<Pair<Iterable<ID>, AsyncListenStream<QueryChange<ResultSet>>>>
      getTheChat() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '$id' AND isSnip = 'false'
        ORDER BY id DESC
        """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    return Pair(
      (await r.allResults()).map((e) => e.toPlainMap()["id"] as ID),
      q.changes(),
    );
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

  Future<FireMessage?> lastChatMessage() async {
    final raw = """
            SELECT * FROM _ AS m
            WHERE root = '$id' AND isSnip = 'false'
            ORDER BY META(m).id DESC LIMIT 1
            """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    final a = await r.allResults();

    if (a.isEmpty) return null;
    final json = a.single.toPlainMap()["m"] as Map<String, Object?>;
    return FireMessage.fromJson(json);
  }

  Future<bool> lastChatFromOtherIsUnread() async {
    final raw = """
            SELECT * FROM _
            WHERE root = '$id'
              AND isSnip = 'false'
              AND isRead = 'false'
              AND senderID != '${g.self.id}'
            ORDER BY META().id DESC LIMIT 1
            """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    final a = await r.allResults();

    return a.isNotEmpty;
  }

  Future<(FireMessage?, Iterable<ID>, bool)> homeChatInfo() async {
    final val = await Future.wait([
      lastChatMessage(),
      unreadSnipIDs(),
      lastChatFromOtherIsUnread(),
    ]);
    return (val[0] as FireMessage?, val[1] as Iterable<ID>, val[2] as bool);
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
  User(
    super.id, {
    required super.activity,
    required super.name,
    // required bool isHidden,
    required bool isFriend,
    required Set<ID> publics,
    required super.description,
    required super.lastName,
    required super.mediaID,
    required Down4Keys neuter,
  }) : super(
            // isHidden: isHidden,
            isFriend: isFriend,
            publics: publics,
            neuter: neuter);

  Future<void> updateFriendStatus(bool newFriendStatus) async {
    _isFriend = newFriendStatus;
    Map<String, String> mergeInfo = {};
    mergeInfo["isFriend"] = _isFriend.toString();
    if (_isFriend!) mergeInfo["isHidden"] = false.toString();
    await merge(mergeInfo);
  }

  // Future<void> updateHiddenStatus(bool newHiddenStatus) async {
  //   _isHidden = newHiddenStatus;
  //   await merge({"isHidden": _isHidden.toString()});
  // }

  Future<bool> hasMessages() async {
    final raw_ = """
      SELECT META().id FROM _ AS m 
      WHERE m.root = '$id'
      LIMIT 1
      """;

    final q_ = await AsyncQuery.fromN1ql(messagesDB, raw_);
    final r_ = await q_.execute();
    final e_ = await r_.allResults();
    return e_.isNotEmpty;
  }

  bool get isFriend => _isFriend!;

  @override
  Iterable<ID> get children => _publics!;

  @override
  Color get color =>
      g.theme.nodeColors[isFriend ? NodesColor.friend : NodesColor.nonFriend]!;

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
  Color get color => g.theme.nodeColors[NodesColor.self]!;

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
    final jsonNode = Map<String, Object?>.from(json["n"] as Map);
    final self = fromJson<Self>(jsonNode)..cache();
    await global<FireMedia>(self.mediaID);
    return self;
  }

  @override
  Nodes get type => Nodes.self;
}

class Group extends FireNode with Chatable, Groupable, Editable {
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
  Color get color => g.theme.nodeColors[NodesColor.group]!;

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
  Hyperchat(
    super.id, {
    required super.activity,
    required String firstWord,
    required String secondWord,
    required super.mediaID,
    required Set<ID> group,
  }) : super(group: group, name: firstWord, lastName: secondWord);

  @override
  Color get color => g.theme.nodeColors[NodesColor.hyperchat]!;

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
  int get activity => _payment.timeStamp;

  @override
  ID? get mediaID => null;

  final Down4Payment _payment;
  final ID selfID;
  Payment(
    super.id, {
    required Down4Payment payment,
    required this.selfID,
  })  : _payment = payment,
        super(activity: payment.timeStamp, name: payment.id);

  @override
  String get displayName => payment.formattedName(selfID);

  Down4Payment get payment => _payment;

  @override
  String get displayID =>
      "Confirmations: ${_payment.lastConfirmations > 100 ? "100+" : _payment.lastConfirmations}";

  @override
  Color get color => _payment.lastConfirmations == 0
      ? g.theme.nodeColors[NodesColor.unsafeTx]!
      : _payment.lastConfirmations < 6
          ? g.theme.nodeColors[NodesColor.mediumTx]!
          : g.theme.nodeColors[NodesColor.safeTx]!;

  @override
  Nodes get type => Nodes.payment;
}

class NodeTheme extends FireNode {
  final Down4Theme theme;
  NodeTheme(this.theme) : super(theme.font, activity: 0, name: theme.name);

  @override
  Color get color => g.theme.paletteTextColor;

  @override
  String get displayID => "font : ${theme.font}";

  @override
  String get displayName => _name;

  @override
  ID? get mediaID => null;

  @override
  Nodes get type => Nodes.theme;
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
  final double width, height;
  // final double aspectRatio;
  final String? text;
  final int timestamp;
  Uint8List? cachedMemory;

  Size get size => Size(width, height);

  double get aspectRatio => size.aspectRatio;

  String get extension => extensionFromMime(mime);

  bool get isVideo => extension.isVideoExtension();

  Future<VideoPlayerController?> get videoController async {
    if (!isVideo) throw 'Media needs to be a video';
    final f = (cachedFile) ?? videoFile;
    if (f != null) return VideoPlayerController.file(f);
    final url_ = await url;
    if (url_ != null) return VideoPlayerController.network(url_);
    return null;
  }

  String get videoPath => "${g.appDirPath}/$id";

  File? get cachedFile {
    if (cachePath == null) return null;
    if (!File(cachePath!).existsSync()) return null;
    return File(cachePath!);
  }

  File? get videoFile {
    if (!File(videoPath).existsSync()) return null;
    return File(videoPath);
  }

  Future<String?> get url async {
    if (cachedUrl != null) return cachedUrl;
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

  Future<Uint8List?> get localImageData async {
    final blob = (await dbb.document(id))?.blob("image");
    return cachedMemory = await blob?.content();
  }

  int get onlineTimestamp => _onlineTimestamp;

  String? get onlineID => _onlineID;

  Future<bool> get cachedAndReady async {
    if (cachedFile != null) return true;
    if (await localImageData != null) return true;
    if (await url != null) return true;
    return false;
  }

  Image? get displayCachedImage {
    if (cachedMemory != null) return Image.memory(cachedMemory!);
    if (cachedFile != null) return Image.file(cachedFile!);
    if (cachedUrl != null) return Image.network(cachedUrl!);
    return null;
  }

  FireMedia(this.id,
      {required this.ownerID,
      required this.timestamp,
      required this.width,
      required this.height,
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

  // FireMedia copy() {
  //   return FireMedia.fromJson(toJson(toLocal: true));
  // }

  FireMedia updated({required ID onlineID, required int onlineTS}) {
    final json = toJson(toLocal: true);
    json["onlineID"] = onlineID;
    json["onlineTimestamp"] = onlineTS.toString();
    return FireMedia.fromJson(json);
  }

  // special function upon user intialization
  Future<FireMedia?> userInitRecalculation(ID properID) async {
    final json = toJson(toLocal: true);
    final data = File(cachePath!).readAsBytesSync();
    json["ownerID"] = properID;
    json["id"] = u.deterministicMediaID(data, properID);
    return FireMedia.fromJson(json)..cachePath = cachePath;
  }

  Future<void> use() async {
    _lastUse = u.makeTimestamp();
    print("USING MEDIA ID = $id");
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
      "onlineID": newOnlineId,
    });
  }

  Future<void> writeFromCachedPath() async {
    if (cachePath == null) return;
    final d = File(cachePath!).readAsBytesSync();
    Uint8List? tn;
    if (isVideo) {
      tn = await VideoThumbnail.thumbnailData(video: cachePath!, quality: 80);
      await File(videoPath).writeAsBytes(d);
    }
    await write(imageData: tn ?? d);
  }

  Future<void> write({required Uint8List imageData}) async {
    tinyThumbnail ??= makeTiny(imageData);
    final imageMime = isVideo ? "image/png" : mime;
    final imageBlob = Blob.fromData(imageMime, imageData);
    await merge({"image": imageBlob});
  }

  factory FireMedia.fromJson(Map<String, Object?> decodedJson) {
    return FireMedia(decodedJson["id"] as String,
        ownerID: decodedJson["ownerID"] as String,
        timestamp: int.parse(decodedJson["timestamp"] as String),
        mime: decodedJson["mime"] as String,
        cachePath: decodedJson["cachePath"] as String?,
        onlineID: decodedJson["onlineID"] as String?,
        lastUse: int.parse(decodedJson["lastUse"] as String? ?? "0"),
        tinyThumbnail: decodedJson["tinyThumbnail"] as String?,
        onlineTimestamp: int.parse(decodedJson["onlineTimestamp"] as String),
        isSaved: decodedJson["isSaved"] == "true",
        isReversed: decodedJson["isReversed"] == "true",
        isSquared: decodedJson["isSquared"] == "true",
        isLocked: decodedJson["isLocked"] == "true",
        isPaidToOwn: decodedJson["isPaidToView"] == "true",
        isPaidToView: decodedJson["isPaidToOwn"] == "true",
        width: double.parse(decodedJson["width"] as String),
        height: double.parse(decodedJson["height"] as String),
        text: decodedJson["text"] as String?);
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
        // if (cachePath != null) "cachePath": cachePath!,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isLocked": isLocked.toString(),
        "isPaidToView": isPaidToView.toString(),
        "isPaidToOwn": isPaidToOwn.toString(),
        "width": width.toString(),
        "height": height.toString(),
        if (toLocal) "lastUse": _lastUse.toString(),
        if (toLocal) "isVideo": isVideo.toString(),
        if (toLocal) "isSaved": _isSaved.toString(),
      };
}

class FireTheme extends FireObject {
  String _themeName;
  FireTheme(ID themeName) : _themeName = themeName;

  String get themeName => _themeName;

  @override
  Database get dbb => personalDB;

  @override
  ID get id => "theme";

  Future<void> changeTheme(ID newThemeName) async {
    if (themesRegistry[newThemeName] == null) return;
    _themeName = newThemeName;
    await merge();
  }

  static Future<FireTheme> get currentTheme async {
    final doc = await personalDB.document("theme");
    if (doc != null) return FireTheme(doc.string("themeName")!);
    return FireTheme(themesRegistry.keys.first)..merge();
  }

  @override
  Map<String, dynamic> toJson({bool toLocal = false}) => {
        "themeName": _themeName,
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
    final lastUpdate = decodedJson["lastUpdate"] as int;
    final rate = decodedJson["rate"] as double;
    return ExchangeRate(lastUpdate: lastUpdate, rate: rate);
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
