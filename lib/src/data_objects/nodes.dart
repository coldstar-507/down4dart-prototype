import 'dart:async';
import 'dart:convert';

import 'package:down4/src/bsv/_bsv_utils.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:down4/src/globals.dart';
import 'package:down4/src/themes.dart';
import 'package:flutter/material.dart' show Color;
import 'package:cbl/cbl.dart';

import '../_dart_utils.dart';
import '../bsv/types.dart';

import '_data_utils.dart';
import 'couch.dart';
import 'medias.dart';
import 'messages.dart';

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

class MessageTarget with Jsons {
  final ComposedID userID;
  final String device;
  final String token;
  bool success;

  String get messageSuccessKey => "${userID.value}%$device%$token";

  MessageTarget({
    required this.userID,
    required this.device,
    required this.token,
    this.success = false,
  });
  @override
  Map<String, String> toJson({bool toLocal = false}) => {
        "userID": userID.value,
        "device": device,
        "token": token,
        "success": success.toString(),
      };

  factory MessageTarget.fromJson(dynamic json) {
    return MessageTarget(
      userID: ComposedID.fromString(json["userID"])!,
      device: json["device"],
      token: json["token"],
      success: json["success"] == "true",
    );
  }
}

abstract class Down4Node extends Locals {
  @override
  Database get dbb => nodesDB;

  final Down4ID _id;
  final String? _deviceID, _mainDeviceID;
  int _activity;
  int? _lastOnline;
  String _name;
  String? _lastName, _description;
  Map<String, String>? _messagingTokens;
  final Down4Keys? _neuter;
  ComposedID? _mediaID;
  bool? _isConnected, _isPrivate;
  final Set<ComposedID>? _group, _children, _privates, _posts, _admins;
  final ComposedID? _ownerID;
  double? _longitude, _latitude;

  @override
  Down4ID get id => _id;
  ComposedID? get mediaID;
  Color get color;
  Nodes get type;
  String get displayID;
  String get displayName;
  int get activity => _activity;
  Map<ComposedID, String>? _treeHash;

  String get publicHash;

  Map<String, String>? get _jsonTreeHash =>
      _treeHash?.map((key, value) => MapEntry(key.value, value));

  @override
  Map<String, String> toJson({
    bool toLocal = true,
    bool includePublic = true,
    bool includeConnection = true,
  }) {
    return {
      "id": id.value,
      "type": (this is Self && !toLocal) ? Nodes.user.name : type.name,
      "name": _name,
      if (toLocal) "unique": id.unique,
      if (_messagingTokens != null)
        "messagingTokens": jsonEncode(_messagingTokens),
      if (_mainDeviceID != null) "mainDeviceID": _mainDeviceID!,
      if (_treeHash != null) "treeHash": jsonEncode(_treeHash),
      if (_ownerID != null) "ownerID": _ownerID!.value,
      if (_lastName != null) "lastName": _lastName!,
      if (_longitude != null) "longitude": _longitude!.toString(),
      if (_latitude != null) "latitude": _latitude!.toString(),
      if (_mediaID != null) "mediaID": _mediaID!.value,
      if (_children != null) "children": _children!.values,
      if (_posts != null) "posts": _posts!.values,
      if (_privates != null) "privates": _privates!.values,
      if (_admins != null) "admins": _admins!.values,
      if (_neuter != null) "neuter": _neuter!.toYouKnow(),
      if (_group != null) "group": _group!.values,
      if (toLocal && _deviceID != null) "deviceID": _deviceID!,
      if (toLocal && _isConnected != null) "isFriend": _isConnected!.toString(),
      if (toLocal) "activity": _activity.toString(),
    };
  }

  Map<String, dynamic> toJson2({
    bool includeLocal = true,
    bool includePublic = true,
    bool includePrivate = false,
    bool includeConnection = true,
  }) {
    return {
      if (includeConnection)
        "connection": {
          if (_lastOnline != null) "lastOnline": _lastOnline,
          "publicHash": publicHash,
        },
      if (includePublic)
        "public": {
          "id": id.value,
          "type": (this is Self && !includeLocal) ? Nodes.user.name : type.name,
          "name": _name,
          if (_messagingTokens != null) "messagingTokens": _messagingTokens,
          if (_mainDeviceID != null) "mainDeviceID": _mainDeviceID,
          if (_treeHash != null) "treeHash": _jsonTreeHash,
          if (_ownerID != null) "ownerID": _ownerID!.value,
          if (_lastName != null) "lastName": _lastName,
          if (_longitude != null) "longitude": _longitude,
          if (_latitude != null) "latitude": _latitude,
          if (_mediaID != null) "mediaID": _mediaID!.value,
          if (_children != null) "children": _children!.values,
          if (_posts != null) "posts": _posts!.values,
          if (_privates != null) "privates": _privates!.values,
          if (_admins != null) "admins": _admins!.values,
          if (_neuter != null) "neuter": _neuter!.toYouKnow(),
          if (_group != null) "group": _group!.values,
        },
      if (includePrivate)
        "private": {
          if (_privates != null) "privates": _privates!,
        },
      if (includeLocal)
        "local": {
          if (_deviceID != null) "deviceID": _deviceID,
          if (_isConnected != null) "isConnected": _isConnected,
          "unique": id.unique,
          "activity": _activity,
        }
    };
  }

  factory Down4Node.fromJson2(dynamic json2) {
    final connection = jsonDecode(json2["connection"]);
    final private = json2["private"];
    final public = json2["public"];
    final local = json2["local"];

    final id = Down4ID.fromString(public["id"]);
    final mainDeviceID = public["mainDeviceID"];
    final type = Nodes.values.byName(public["type"]);
    final mediaID = ComposedID.fromString(public["mediaID"]);
    final latitude = public["latitude"];
    final longitude = public["longitude"];
    final ownerID = ComposedID.fromString(public["ownerID"]);
    final name = public["name"];
    final isPrivate = public["isPrivate"];
    final lastName = public["lastName"];
    final messagingTokens = public["messagingTokens"];
    final description = public["description"];
    final children = (public["children"] as String?)?.toComposedIDs();
    final privates = (public["privates"] as String?)?.toComposedIDs();
    final admins = (public["admins"] as String?)?.toComposedIDs();
    final group = (public["group"] as String?)?.toComposedIDs();
    final neuter = public["neuter"] != null
        ? Down4Keys.fromYouKnow(public["neuter"] as String)
        : null;

    final deviceID = local["deviceID"];
    final activity = local["activity"];
    final isConnected = local["isConnected"];

    switch (type) {
      case Nodes.user:
        return User(id as ComposedID,
            activity: activity,
            name: name,
            mainDeviceID: mainDeviceID,
            messagingTokens: messagingTokens,
            isConnected: isConnected,
            children: children!,
            description: description,
            lastName: lastName,
            mediaID: mediaID,
            neuter: neuter!);
      case Nodes.hyperchat:
        return Hyperchat(id as ComposedID,
            activity: activity,
            mediaID: mediaID!,
            ownerID: ownerID!,
            firstWord: name,
            secondWord: lastName,
            group: group!);
      case Nodes.self:
        return Self(id as ComposedID,
            deviceID: deviceID,
            activity: activity,
            name: name,
            description: description,
            lastName: lastName,
            mainDeviceID: mainDeviceID,
            messagingTokens: messagingTokens,
            neuter: neuter!,
            mediaID: mediaID!,
            children: children!,
            privates: privates!);
      case Nodes.group:
        return Group(id as ComposedID,
            activity: activity,
            name: name,
            mediaID: mediaID!,
            ownerID: ownerID!,
            isPrivate: isPrivate,
            group: group!);
      case Nodes.root:
      // TODO: Handle this case.
      case Nodes.market:
      // TODO: Handle this case.
      case Nodes.checkpoint:
      // TODO: Handle this case.
      case Nodes.journal:
      // TODO: Handle this case.
      case Nodes.item:
      // TODO: Handle this case.
      case Nodes.event:
      // TODO: Handle this case.
      case Nodes.ticket:
      // TODO: Handle this case.
      case Nodes.payment:
      // TODO: Handle this case.
      case Nodes.theme:
      // TODO: Handle this case.
    }

    throw 'Down4Node fromJson not yet implemented for type: $type';
  }

  Down4Node(
    Down4ID id, {
    String? deviceID,
    String? mainDeviceID,
    required int activity,
    required String name,
    int? lastOnline,
    String? lastName,
    bool? isFriend,
    bool? isHidden,
    bool? isPrivate,
    String? description,
    Map<String, String>? messagingTokens,
    Down4Keys? neuter,
    double? longitude,
    double? latitude,
    ComposedID? mediaID,
    ComposedID? ownerID,
    Set<ComposedID>? children,
    Set<ComposedID>? privates,
    Set<ComposedID>? posts,
    Set<ComposedID>? admins,
    Set<ComposedID>? group,
  })  : _id = id,
        _activity = activity,
        _lastOnline = lastOnline,
        _name = name,
        _mainDeviceID = mainDeviceID,
        _deviceID = deviceID,
        _lastName = lastName,
        _isConnected = isFriend,
        _isPrivate = isPrivate,
        _latitude = latitude,
        _longitude = longitude,
        _messagingTokens = messagingTokens,
        _description = description,
        _neuter = neuter,
        _mediaID = mediaID,
        _ownerID = ownerID,
        _privates = privates,
        _group = group,
        _admins = admins,
        _posts = posts,
        _children = children;

  Down4Node copy() => Down4Node.fromJson(toJson(toLocal: true));

  void updateActivity([int? newActivity]) {
    _activity = newActivity ?? makeTimestamp();
    merge({"activity": _activity.toString()});
  }

  factory Down4Node.fromJson(Map<String, Object?> json) {
    final id = Down4ID.fromString(json["id"] as String);
    final deviceID = json["deviceID"] as String?;
    final mainDeviceID = json["mainDeviceID"] as String?;
    final activity = int.parse(json["activity"] as String? ?? "0");
    final type = Nodes.values.byName(json["type"] as String);
    final mediaID = ComposedID.fromString(json["mediaID"] as String?);
    final latitude = double.tryParse(json["latitude"] as String? ?? "");
    final longitude = double.tryParse(json["longitude"] as String? ?? "");
    final ownerID = ComposedID.fromString(json["ownerID"] as String?);
    final name = json["name"] as String;
    final isFriend = json["isFriend"] == "true";
    final isPrivate = json["isPrivate"] == "true";
    final lastName = json["lastName"] as String?;
    final tokensStr = json["messagingTokens"] as String? ?? '{}';
    final messagingTokens = Map<String, String>.from(jsonDecode(tokensStr));
    final description = json["description"] as String?;
    final children = (json["children"] as String?)?.toComposedIDs();
    final privates = (json["privates"] as String?)?.toComposedIDs();
    final admins = (json["admins"] as String?)?.toComposedIDs();
    final group = (json["group"] as String?)?.toComposedIDs();
    final neuter = json["neuter"] != null
        ? Down4Keys.fromYouKnow(json["neuter"] as String)
        : null;

    switch (type) {
      case Nodes.user:
        return User(id as ComposedID,
            mainDeviceID: mainDeviceID!,
            activity: activity,
            name: name,
            lastName: lastName,
            mediaID: mediaID,
            messagingTokens: messagingTokens,
            isConnected: isFriend,
            children: children!,
            neuter: neuter!,
            description: description,
            longitude: longitude,
            latitude: latitude);

      case Nodes.hyperchat:
        return Hyperchat(id as ComposedID,
            activity: activity,
            ownerID: ownerID!,
            mediaID: mediaID!,
            firstWord: name,
            secondWord: lastName!,
            group: group!);

      case Nodes.group:
        return Group(id as ComposedID,
            isPrivate: isPrivate,
            activity: activity,
            ownerID: ownerID!,
            name: name,
            mediaID: mediaID!,
            group: group!);

      case Nodes.self:
        return Self(id as ComposedID,
            mainDeviceID: mainDeviceID!,
            deviceID: deviceID!,
            activity: activity,
            name: name,
            description: description,
            messagingTokens: messagingTokens,
            lastName: lastName,
            mediaID: mediaID!,
            children: children!,
            privates: privates!,
            neuter: neuter!,
            latitude: latitude,
            longitude: longitude);

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

mixin BranchNode on Down4Node {
  @override
  ComposedID get id => _id as ComposedID;

  Map<ComposedID, String>? get treeHash;
  set treeHash(Map<ComposedID, String>? t) => _treeHash = t;
  Iterable<ComposedID> get children;

  Future<void> _calculateTreeHash() async {
    final tree = <ComposedID, String>{};
    for (final c in children) {
      final n = await global<Down4Node>(c);
      if (n != null) {
        if (n is BranchNode) {
          await n._calculateTreeHash();
          tree.addAll(n._treeHash!);
        } else {
          tree[n.id as ComposedID] = n.publicHash;
        }
      }
    }
    await merge({"treeHash": jsonEncode(treeHash = tree)});
  }

  @override
  String get publicHash {
    if ((treeHash ?? {}).isEmpty) return "";
    final intHashes = treeHash!.values.map((e) => utf8.encode(e)).toList();
    final hashLen = intHashes.first.length;
    final nHash = intHashes.length;
    List<int> hash = List<int>.generate(hashLen, (index) => 0);
    for (int l = 0; l < hashLen; l++) {
      for (int n = 0; n < nHash; n++) {
        hash[n] = intHashes[n][l] ^ hash[n];
      }
    }
    return utf8.decode(hash);
  }
}

mixin ChildNode on Down4Node {
  ComposedID get ownerID;
}

mixin ChatNode on Down4Node {
  @override
  ComposedID get id => _id as ComposedID;

  // This includes the senders tokens, because we can be multi device
  // we might send messages to ourselves
  // For CHATS, we remove only remove the token of the sender current device
  // this way, all participating devices will receive a message except sender's
  // current device
  // for CASH, we remove sender's tokens and receivers non-mainDevice tokens
  // This is done in the messages sending functions
  Future<List<MessageTarget>> allTargets() async {
    final nodeRef = this;
    List<MessageTarget> targets = [];
    // List<MessageTarget> selfTargets = [];
    final people = nodeRef is GroupNode
        ? (await globall<PersonNode>(nodeRef.group))
        : nodeRef.id == g.self.id
            ? [g.self]
            : [g.self, nodeRef as PersonNode];

    for (final person in people) {
      for (final token in person.messagingTokens.entries) {
        if (person.id == g.self.id && token.key == g.self.deviceID) continue;
        targets.add(MessageTarget(
            userID: person.id, device: token.key, token: token.value));
        // if (person.id == g.self.id) {
        //   if (token.key != g.self.deviceID) continue;
        //   selfTargets.add(MessageTarget(
        //       userID: g.self.id, device: token.key, token: token.value));
        // } else {
        //   targets.add(MessageTarget(
        //       userID: person.id, device: token.key, token: token.value));
        // }
      }
    }

    return targets;
    // return (selfTargets, targets);
  }

  Future<Pair<Iterable<ComposedID>, AsyncListenStream<QueryChange<ResultSet>>>>
      getTheChat() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '${id.value}' AND isSnip = 'false'
        ORDER BY id DESC
        """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    return Pair(
      (await r.allResults())
          .map((e) => ComposedID.fromString(e.toPlainMap()["id"] as String)!),
      q.changes(),
    );
  }

  Future<Iterable<ComposedID>> unreadSnipIDs() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '${id.value}' AND isSnip = 'true' AND isRead = 'false'
        ORDER BY id ASC
        """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    return (await r.allResults())
        .map((e) => ComposedID.fromString(e.toPlainMap()["id"] as String)!);
  }

  Stream<Snip> loadSnips() async* {
    final raw = "SELECT * FROM _ WHERE type = 'snip' AND root = '${id.value}'";
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    await for (final a in r.asStream()) {
      final json = a.toPlainMap()["messages"] as Map<String, String?>;
      yield Down4Message.fromJson(json) as Snip;
    }
  }

  Future<Chat?> lastChatMessage() async {
    final raw = """
            SELECT * FROM _ AS m
            WHERE root = '${id.value}' AND isSnip = 'false'
            ORDER BY META(m).id DESC LIMIT 1
            """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    final a = await r.allResults();

    if (a.isEmpty) return null;
    final json = a.single.toPlainMap()["m"] as Map<String, Object?>;
    return Down4Message.fromJson(json) as Chat;
  }

  Future<bool> lastChatFromOtherIsUnread() async {
    final raw = """
            SELECT * FROM _
            WHERE root = '${id.value}'
              AND isSnip = 'false'
              AND isRead = 'false'
              AND senderID != '${g.self.id.value}'
            ORDER BY META().id DESC LIMIT 1
            """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    final a = await r.allResults();

    return a.isNotEmpty;
  }

  Future<(Chat?, Iterable<ComposedID>, bool)> homeChatInfo() async {
    final val = await Future.wait([
      lastChatMessage(),
      unreadSnipIDs(),
      lastChatFromOtherIsUnread(),
    ]);
    return (val[0] as Chat?, val[1] as Iterable<ComposedID>, val[2] as bool);
  }
}

mixin GroupNode on ChatNode, ChildNode {
  Iterable<ComposedID> get group;
  @override
  String get displayID => group.map((id) => "@${id.unique}").join(" ");
}

mixin PersonNode on ChatNode, GeoNode, BranchNode {
  String get mainDeviceID;

  @override
  ComposedID get id => _id as ComposedID;

  String get firstName;
  String? get description;
  String? get lastName;

  Map<String, String> get messagingTokens => _messagingTokens!;

  Down4Keys get neuter;

  Future<void> updateMessagingToken(Map<String, String> newToken) async {
    _messagingTokens = {...?_messagingTokens, ...newToken};
    await merge({"messagingToken": jsonEncode(_messagingTokens)});
  }

  @override
  String get displayID => "@${id.unique}";

  @override
  String get displayName =>
      firstName + ((lastName != null) ? " $lastName" : "");
}

mixin EditNode on Down4Node {
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

mixin GeoNode on Geo, Down4Node {
  Future<void> updateLocation(double lon, double lat) async {
    _longitude = lon;
    _latitude = lat;
    await merge({"longitude": lon.toString(), "latitude": lat.toString()});
  }
}

mixin RemoteNode on Down4Node {
  @override
  ComposedID get id;

  bool get isRemoteMutable {
    dynamic ref = this;
    return ref is Self || (ref is ChildNode && ref.ownerID == g.self.id);
  }

  Future<void> remoteDelete() async {
    if (isRemoteMutable) {
      try {
        await id.userRef.remove();
      } catch (e) {
        print(
            "error deleting node id=${id.value}, node type=$runtimeType, err=$e");
      }
    } else {
      throw "node type=$runtimeType, id=${id.unique} isn't remoteMutable";
    }
  }

  Future<bool> remoteMerge({Map<String, dynamic>? data}) async {
    if (isRemoteMutable) {
      try {
        await id.userRef.update(data ?? toJson(toLocal: false));
        return true;
      } catch (e) {
        print("error remoteMerge node id=${id.unique}");
        return false;
      }
    } else {
      throw "node type=$runtimeType, id=${id.unique} isn't remoteMutable";
    }
  }
}

class User extends Down4Node
    with BranchNode, ChatNode, Geo, GeoNode, PersonNode {
  User(
    super.id, {
    required super.activity,
    required super.name,
    required String mainDeviceID,
    required Map<String, String> messagingTokens,
    required bool isConnected,
    required Set<ComposedID> children,
    required super.description,
    required super.lastName,
    required super.mediaID,
    required Down4Keys neuter,
    super.latitude,
    super.longitude,
  }) : super(
            mainDeviceID: mainDeviceID,
            messagingTokens: messagingTokens,
            isFriend: isConnected,
            children: children,
            neuter: neuter);

  Future<void> updateFriendStatus(bool newFriendStatus) async {
    _isConnected = newFriendStatus;
    Map<String, String> mergeInfo = {};
    mergeInfo["isFriend"] = _isConnected.toString();
    if (_isConnected!) mergeInfo["isHidden"] = false.toString();
    await merge(mergeInfo);
  }

  @override
  Map<String, String> get messagingTokens => _messagingTokens!;

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

  bool get isFriend => _isConnected!;

  @override
  Iterable<ComposedID> get children => _children!;

  @override
  Color get color =>
      g.theme.nodeColors[isFriend ? NodesColor.friend : NodesColor.nonFriend]!;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  ComposedID? get mediaID => _mediaID;

  @override
  String get firstName => _name;

  @override
  Down4Keys get neuter => _neuter!;

  @override
  Nodes get type => Nodes.user;

  @override
  Map<ComposedID, String>? get treeHash => _treeHash;

  @override
  double? get latitude => _latitude;

  @override
  double? get longitude => _longitude;

  @override
  String get mainDeviceID => _mainDeviceID!;
}

class Self extends Down4Node
    with RemoteNode, BranchNode, ChatNode, Geo, GeoNode, PersonNode, EditNode {
  Self(
    super.id, {
    required String deviceID,
    required super.activity,
    required super.name,
    required super.description,
    required super.lastName,
    required String mainDeviceID,
    required Map<String, String> messagingTokens,
    required Down4Keys neuter,
    required ComposedID mediaID,
    required Set<ComposedID> children,
    required Set<ComposedID> privates,
    super.latitude,
    super.longitude,
  }) : super(
            deviceID: deviceID,
            mainDeviceID: mainDeviceID,
            mediaID: mediaID,
            children: children,
            neuter: neuter,
            messagingTokens: messagingTokens,
            privates: privates);

  String get deviceID => _deviceID!;

  String get currentMessagingToken => messagingTokens[deviceID]!;

  @override
  Map<String, String> get messagingTokens => _messagingTokens!;

  @override
  Color get color => g.theme.nodeColors[NodesColor.self]!;

  @override
  Iterable<ComposedID> get children => _children!;

  @override
  String? get description => _description;

  @override
  String? get lastName => _lastName;

  @override
  ComposedID get mediaID => _mediaID!;

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

  @override
  Map<ComposedID, String>? get treeHash => _treeHash;

  Future<void> calculateTreeHash() => _calculateTreeHash();

  @override
  double? get latitude => _latitude;

  @override
  double? get longitude => _longitude;

  @override
  String get mainDeviceID => _mainDeviceID!;
}

class Group extends Down4Node
    with RemoteNode, ChatNode, ChildNode, GroupNode, EditNode {
  Group(
    super.id, {
    required super.activity,
    required super.name,
    required ComposedID mediaID,
    required ComposedID ownerID,
    required bool isPrivate,
    required Set<ComposedID> group,
  }) : super(
            group: group,
            isPrivate: isPrivate,
            mediaID: mediaID,
            ownerID: ownerID);

  @override
  ComposedID get ownerID => _ownerID!;

  Future<void> addMembersRef(Iterable<ComposedID> memberIDs) async {
    _group!.addAll(memberIDs);
    await merge({"group": group.join(" ")});
  }

  bool get isPrivate => _isPrivate!;

  @override
  Color get color => g.theme.nodeColors[NodesColor.group]!;

  @override
  String get displayName => _name;

  @override
  Iterable<ComposedID> get group => _group!;

  @override
  ComposedID? get mediaID => _mediaID;

  @override
  Nodes get type => Nodes.group;

  @override
  String get publicHash =>
      // we hash ids to get fixed size
      XORedStrings(
          group.map((e) => sha1(e.unique.codeUnits).toUtf16()).toList());
}

class Hyperchat extends Down4Node
    with RemoteNode, ChatNode, ChildNode, GroupNode {
  Hyperchat(
    super.id, {
    required super.activity,
    required ComposedID mediaID,
    required ComposedID ownerID,
    required String firstWord,
    required String secondWord,
    required Set<ComposedID> group,
  }) : super(
            mediaID: mediaID,
            group: group,
            name: firstWord,
            lastName: secondWord,
            ownerID: ownerID);

  @override
  ComposedID get ownerID => _ownerID!;

  @override
  Color get color => g.theme.nodeColors[NodesColor.hyperchat]!;

  @override
  String get displayName => "$_name $_lastName";

  @override
  Iterable<ComposedID> get group => _group!;

  @override
  ComposedID? get mediaID => _mediaID;

  @override
  Nodes get type => Nodes.hyperchat;

  @override
  String get publicHash =>
      // we hash ids to get fixed size
      XORedStrings(
          group.map((e) => sha1(e.unique.codeUnits).toUtf16()).toList());
}

class PaymentNode extends Down4Node {
  @override
  Database get dbb => throw "Don't merge palette payment";

  @override
  int get activity => _payment.timestamp;

  @override
  ComposedID? get mediaID => null;

  final Down4Payment _payment;
  final ComposedID selfID;
  PaymentNode(
    super.id, {
    required Down4Payment payment,
    required this.selfID,
  })  : _payment = payment,
        super(activity: payment.timestamp, name: payment.id.unique);

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

  @override
  String get publicHash => _payment.id.unique;
}

class NodeTheme extends Down4Node {
  final Down4Theme theme;
  NodeTheme(this.theme)
      : super(Down4ID(unique: theme.font), activity: 0, name: theme.name);

  @override
  Color get color => g.theme.paletteTextColor;

  @override
  String get displayID => "font : ${theme.font}";

  @override
  String get displayName => _name;

  @override
  ComposedID? get mediaID => null;

  @override
  Nodes get type => Nodes.theme;

  @override
  String get publicHash => theme.name;
}
