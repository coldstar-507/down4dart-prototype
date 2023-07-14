import 'dart:async';
import 'dart:convert';

import 'package:down4/src/bsv/_bsv_utils.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:down4/src/globals.dart';
import 'package:down4/src/themes.dart';
import 'package:firebase_database/firebase_database.dart';
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

  String get messageSuccessKey => "${userID.value}~$device~$token";

  MessageTarget({
    required this.userID,
    required this.device,
    required this.token,
    this.success = false,
  });
  @override
  Map<String, Object> toJson({bool includeLocal = false}) => {
        "userID": userID.value,
        "device": device,
        "token": token,
        "success": success,
      };

  factory MessageTarget.fromJson(dynamic json) {
    return MessageTarget(
      userID: ComposedID.fromString(json["userID"])!,
      device: json["device"],
      token: json["token"],
      success: json["success"],
    );
  }
}

mixin PaletteN on Down4Object {
  Color get color;
  Nodes get type;
  String get displayID;
  String get displayName;
  ComposedID? get mediaID;
  int get activity;
}

abstract class Down4Node extends Locals with PaletteN {
  @override
  Database get dbb => nodesDB;

  final Down4ID _id;
  final String? _deviceID, _mainDeviceID;
  bool? _isConnected;

  int _activity;
  String _name;
  String? _lastName, _description;
  Map<String, String>? _messagingTokens;
  final Down4Keys? _neuter;
  ComposedID? _mediaID;
  bool? _isPrivate;
  final Set<ComposedID>? _group, _children, _privates, _posts, _admins;
  final ComposedID? _ownerID;
  double? _longitude, _latitude;
  Map<ComposedID, String>? _treeHash;

  @override
  int get activity => _activity;

  @override
  Down4ID get id => _id;

  String get _connection => [
        publicHash,
        _blueArrowHash,
        _lastOnline.toString(),
      ].join("~");
  String _blueArrowHash;
  int _lastOnline;
  String get publicHash => md5(publicData.asUtf8()).toBase64();

  Map<String, String>? get _jsonTreeHash =>
      _treeHash?.map((key, value) => MapEntry(key.value, value));

  static (String, String b, int) parseConnection(String conn) {
    final s = conn.split("~");
    print(s);
    return (s[0], s[1], int.parse(s[2]));
  }

  String get publicData {
    return id.unique +
        _name +
        (_lastName ?? "") +
        jsonEncode(_messagingTokens ?? {}) +
        (_mainDeviceID ?? "") +
        (jsonEncode(_jsonTreeHash ?? {})) +
        (_ownerID?.value ?? "") +
        (_mediaID?.value ?? "") +
        (_children?.join(" ") ?? "") +
        (_posts?.join(" ") ?? "") +
        (_admins?.join(" ") ?? "") +
        (_group?.join(" ") ?? "");
  }

  @override
  Map<String, Object> toJson({bool includeLocal = true}) {
    String? messagingTokens;
    if (_messagingTokens != null) {
      messagingTokens = jsonEncode(_messagingTokens!);
    }

    return {
      "id": id.value,
      "type": (this is Self && !includeLocal) ? Nodes.user.name : type.name,
      "name": _name,
      "connection": _connection,
      if (includeLocal) "unique": id.unique,
      if (_messagingTokens != null) "messagingTokens": messagingTokens!,
      if (_mainDeviceID != null) "mainDeviceID": _mainDeviceID!,
      if (_treeHash != null) "treeHash": _jsonTreeHash!,
      if (_ownerID != null) "ownerID": _ownerID!.value,
      if (_lastName != null) "lastName": _lastName!,
      if (_longitude != null) "longitude": _longitude!,
      if (_latitude != null) "latitude": _latitude!,
      if (_mediaID != null) "mediaID": _mediaID!.value,
      if (_children != null) "children": _children!.values,
      if (_posts != null) "posts": _posts!.values,
      if (_privates != null) "privates": _privates!.values,
      if (_admins != null) "admins": _admins!.values,
      if (_neuter != null) "neuter": _neuter!.toYouKnow(),
      if (_group != null) "group": _group!.values,
      if (includeLocal && _deviceID != null) "deviceID": _deviceID!,
      if (includeLocal && _isConnected != null) "isFriend": _isConnected!,
      if (includeLocal) "activity": _activity,
    };
  }

  // everything but the localValue we can see in toJson
  void mergeWith(Down4Node? other) {
    if (other == null) return;
    _lastOnline = other._lastOnline;
    _name = other._name;
    _lastName = other._lastName;
    _description = other._description;
    _messagingTokens = other._messagingTokens;
    _mediaID = other._mediaID;
    _isPrivate = other._isPrivate;
    _longitude = other._longitude;
    _latitude = other._latitude;
    _treeHash = other._treeHash;
  }

  // @override
  // Map<String, dynamic> toJson({
  //   bool includeLocal = true,
  //   bool includePublic = true,
  //   bool includePrivate = true,
  //   bool includeConnection = true,
  // }) {
  //   return {
  //     if (includeConnection)
  //       "connection": {
  //         if (_lastOnline != null) "lastOnline": _lastOnline,
  //         "publicHash": publicHash,
  //       },
  //     if (includePublic)
  //       "public": {
  //         "id": id.value,
  //         "type": (this is Self && !includeLocal) ? Nodes.user.name : type.name,
  //         "name": _name,
  //         if (_messagingTokens != null) "messagingTokens": _messagingTokens,
  //         if (_mainDeviceID != null) "mainDeviceID": _mainDeviceID,
  //         if (_treeHash != null) "treeHash": _jsonTreeHash,
  //         if (_ownerID != null) "ownerID": _ownerID!.value,
  //         if (_lastName != null) "lastName": _lastName,
  //         if (_longitude != null) "longitude": _longitude,
  //         if (_latitude != null) "latitude": _latitude,
  //         if (_mediaID != null) "mediaID": _mediaID!.value,
  //         if (_children != null) "children": _children!.values,
  //         if (_posts != null) "posts": _posts!.values,
  //         if (_privates != null) "privates": _privates!.values,
  //         if (_admins != null) "admins": _admins!.values,
  //         if (_neuter != null) "neuter": _neuter!.toYouKnow(),
  //         if (_group != null) "group": _group!.values,
  //       },
  //     if (includePrivate)
  //       "private": {
  //         if (_privates != null) "privates": _privates!,
  //       },
  //     if (includeLocal)
  //       "local": {
  //         if (_deviceID != null) "deviceID": _deviceID,
  //         if (_isConnected != null) "isConnected": _isConnected,
  //         "unique": id.unique,
  //         "activity": _activity,
  //       }
  //   };
  // }

  // factory Down4Node.fromJson(dynamic json) {
  //   final connection = json["connection"];
  //   final private = json["private"];
  //   final public = json["public"];
  //   final local = json["local"];
  //
  //   final id = Down4ID.fromString(public["id"]);
  //   final mainDeviceID = public["mainDeviceID"];
  //   final type = Nodes.values.byName(public["type"]);
  //   final mediaID = ComposedID.fromString(public["mediaID"]);
  //   final latitude = public["latitude"];
  //   final longitude = public["longitude"];
  //   final ownerID = ComposedID.fromString(public["ownerID"]);
  //   final name = public["name"];
  //   final isPrivate = public["isPrivate"];
  //   final lastName = public["lastName"];
  //   final messagingTokens = public["messagingTokens"];
  //   final description = public["description"];
  //   final children = (public["children"] as String?)?.toComposedIDs();
  //   final privates = (public["privates"] as String?)?.toComposedIDs();
  //   final admins = (public["admins"] as String?)?.toComposedIDs();
  //   final group = (public["group"] as String?)?.toComposedIDs();
  //   final neuter = public["neuter"] != null
  //       ? Down4Keys.fromYouKnow(public["neuter"] as String)
  //       : null;
  //
  //   final deviceID = local["deviceID"];
  //   final activity = local["activity"];
  //   final isConnected = local["isConnected"];
  //
  //   final lastOnline = connection["lastOnline"];
  //
  //   switch (type) {
  //     case Nodes.user:
  //       return User(id as ComposedID,
  //           activity: activity,
  //           name: name,
  //           lastOnline: lastOnline,
  //           mainDeviceID: mainDeviceID,
  //           messagingTokens: messagingTokens,
  //           isConnected: isConnected ?? false,
  //           children: children!,
  //           description: description,
  //           lastName: lastName,
  //           mediaID: mediaID,
  //           neuter: neuter!);
  //     case Nodes.hyperchat:
  //       return Hyperchat(id as ComposedID,
  //           activity: activity,
  //           mediaID: mediaID!,
  //           ownerID: ownerID!,
  //           firstWord: name,
  //           isConnected: isConnected ?? false,
  //           secondWord: lastName,
  //           group: group!);
  //     case Nodes.self:
  //       return Self(id as ComposedID,
  //           deviceID: deviceID,
  //           activity: activity,
  //           name: name,
  //           lastOnline: lastOnline,
  //           description: description,
  //           lastName: lastName,
  //           mainDeviceID: mainDeviceID,
  //           messagingTokens: messagingTokens,
  //           neuter: neuter!,
  //           mediaID: mediaID!,
  //           children: children!,
  //           privates: privates!);
  //     case Nodes.group:
  //       return Group(id as ComposedID,
  //           activity: activity,
  //           name: name,
  //           mediaID: mediaID!,
  //           ownerID: ownerID!,
  //           isConnected: isConnected ?? false,
  //           isPrivate: isPrivate,
  //           group: group!);
  //     case Nodes.root:
  //     // TODO: Handle this case.
  //     case Nodes.market:
  //     // TODO: Handle this case.
  //     case Nodes.checkpoint:
  //     // TODO: Handle this case.
  //     case Nodes.journal:
  //     // TODO: Handle this case.
  //     case Nodes.item:
  //     // TODO: Handle this case.
  //     case Nodes.event:
  //     // TODO: Handle this case.
  //     case Nodes.ticket:
  //     // TODO: Handle this case.
  //     case Nodes.payment:
  //     // TODO: Handle this case.
  //     case Nodes.theme:
  //     // TODO: Handle this case.
  //   }
  //
  //   throw 'Down4Node fromJson not yet implemented for type: $type';
  // }

  Down4Node(
    Down4ID id, {
    String? deviceID,
    String? mainDeviceID,
    required int activity,
    required String name,
    String? blueArrowHash,
    bool isConnected = false,
    int? lastOnline,
    String? lastName,
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
        _lastOnline = lastOnline ?? 0,
        _name = name,
        _isConnected = isConnected,
        _mainDeviceID = mainDeviceID,
        _deviceID = deviceID,
        _lastName = lastName,
        _blueArrowHash = blueArrowHash ?? id.unique,
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

  Down4Node copy() => Down4Node.fromJson(toJson());

  void updateActivity([int? newActivity]) {
    _activity = newActivity ?? makeTimestamp();
    merge({"activity": _activity});
  }

  factory Down4Node.fromJson(Map<String, Object?> json) {
    final (_, blueH, lastO) = parseConnection(json["connection"] as String);

    final encTokens = json["messagingTokens"] as String?;
    Map<String, String>? messagingTokens;
    if (encTokens != null) {
      final jsonTokens = jsonDecode(encTokens);
      messagingTokens = Map.from(jsonTokens).map((k, v) => MapEntry(k, v as String));
    }

    final id = Down4ID.fromString(json["id"] as String);
    final deviceID = json["deviceID"] as String?;
    final mainDeviceID = json["mainDeviceID"] as String?;
    final activity = json["activity"] as int? ?? 0;
    final type = Nodes.values.byName(json["type"] as String);
    final mediaID = ComposedID.fromString(json["mediaID"] as String?);
    final latitude = json["latitude"] as double?;
    final longitude = json["longitude"] as double?;
    final ownerID = ComposedID.fromString(json["ownerID"] as String?);
    final name = json["name"] as String;
    final isConnected = json["isConnected"] as bool? ?? false;
    final isFriend = json["isFriend"] as bool? ?? false;
    final isPrivate = json["isPrivate"] as bool?;
    final lastName = json["lastName"] as String?;
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
            blueArrowHash: blueH,
            lastOnline: lastO,
            lastName: lastName,
            mediaID: mediaID,
            messagingTokens: messagingTokens!,
            isConnected: isFriend!,
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
            blueArrowHash: blueH,
            firstWord: name,
            secondWord: lastName!,
            group: group!,
            isConnected: isConnected!);

      case Nodes.group:
        return Group(id as ComposedID,
            isPrivate: isPrivate!,
            activity: activity,
            ownerID: ownerID!,
            blueArrowHash: blueH,
            isConnected: isConnected!,
            name: name,
            mediaID: mediaID!,
            group: group!);

      case Nodes.self:
        return Self(id as ComposedID,
            mainDeviceID: mainDeviceID!,
            deviceID: deviceID!,
            activity: activity,
            name: name,
            blueArrowHash: blueH,
            lastOnline: lastO,
            description: description,
            messagingTokens: messagingTokens!,
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

mixin ConnectN on RemoteN, Down4Node {
  @override
  ComposedID get id;

  bool get isConnected;
  Future<void> updateConnectionStatus(bool isConnected) async {
    _isConnected = isConnected;
    await merge({"isConnected": isConnected});
  }

  Stream<DatabaseEvent> get connection {
    return id.userRef.child("connection").onChildChanged;
  }
}

mixin BranchN on ConnectN, Down4Node {
  @override
  ComposedID get id => _id as ComposedID;

  String get blueArrowHash => _blueArrowHash ??= "";

  Map<ComposedID, String>? get treeHash;
  set treeHash(Map<ComposedID, String>? t) => _treeHash = t;
  Iterable<ComposedID> get children;

  Future<void> _calculateTreeHash() async {
    final tree = <ComposedID, String>{};
    for (final c in children) {
      final n = await global<Down4Node>(c);
      if (n != null) {
        if (n is BranchN) {
          await n._calculateTreeHash();
          tree.addAll(n._treeHash!);
        } else if (n is ConnectN) {
          tree[n.id] = n.publicHash;
        }
      }
    }
    await merge({"treeHash": treeHash = tree});
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

mixin ChildN on Down4Node {
  ComposedID get ownerID;
}

mixin ChatN on Down4Node {
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
    final people = nodeRef is GroupN
        ? (await globall<PersonN>(nodeRef.group))
        : nodeRef.id == g.self.id
            ? [g.self]
            : [g.self, nodeRef as PersonN];

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

  Future<Pair<Iterable<Down4ID>, AsyncListenStream<QueryChange<ResultSet>>>>
      getTheChat() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '${id.value}' AND type = 'chat'
        ORDER BY id DESC
        """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    return Pair(
      (await r.allResults())
          .map((e) => Down4ID.fromString(e.toPlainMap()["id"] as String)!),
      q.changes(),
    );
  }

  Future<Iterable<ComposedID>> unreadSnipIDs() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '${id.value}' AND type = 'snip' AND isRead = false
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
            WHERE root = '${id.value}' AND type = 'chat'
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
              AND type = 'chat'
              AND isRead = 'false'
              AND senderID != '${g.self.id.value}'
            ORDER BY META().id DESC LIMIT 1
            """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    final a = await r.allResults();

    return a.isNotEmpty;
  }

  // Future<(Chat?, Iterable<ComposedID>, bool)> homeChatInfo() async {
  //   final val = await Future.wait([
  //     lastChatMessage(),
  //     unreadSnipIDs(),
  //     lastChatFromOtherIsUnread(),
  //   ]);
  //   return (val[0] as Chat?, val[1] as Iterable<ComposedID>, val[2] as bool);
  // }
}

mixin GroupN on ChatN, ChildN {
  Iterable<ComposedID> get group;
  @override
  String get displayID => group.map((id) => "@${id.unique}").join(" ");
}

mixin PersonN on ConnectN, ChatN, GeoN, BranchN {
  String get mainDeviceID;

  @override
  ComposedID get id => _id as ComposedID;

  int get lastOnline;

  String get firstName;
  String? get description;
  String? get lastName;

  Map<String, String> get messagingTokens => _messagingTokens!;

  Down4Keys get neuter;

  Future<void> updateLastOnline(int? lastOnline) async {
    if (lastOnline == null) return;
    _lastOnline = lastOnline;
    await merge({"lastOnline": _lastOnline});
  }

  Future<void> updateMessagingToken(Map<String, String> newToken) async {
    _messagingTokens = {...?_messagingTokens, ...newToken};
    await merge({"messagingTokens": messagingTokens});
  }

  @override
  String get displayID => "@${id.unique}";

  @override
  String get displayName =>
      firstName + ((lastName != null) ? " $lastName" : "");
}

mixin EditN on Down4Node {
  Future<void> editName(String newName) async {
    _name = newName;
    await merge({"name": _name});
  }

  Future<void> editLastName(String? newLastName) async {
    _lastName = newLastName;
    await merge({"lastName": _lastName ?? ""});
  }

  Future<void> editImage(Down4Media newImage) async {
    _mediaID = newImage.id;
    await merge({"mediaID": _mediaID!.value});
  }

  Future<void> editDescription(String newDescription) async {
    _description = newDescription;
    await merge({"description": _description!});
  }
}

mixin GeoN on Geo, Down4Node {
  Future<void> updateLocation(double lon, double lat) async {
    _longitude = lon;
    _latitude = lat;
    await merge({"longitude": lon, "latitude": lat});
  }
}

mixin RemoteN on Down4Node {
  @override
  ComposedID get id;

  bool get isRemoteMutable {
    dynamic ref = this;
    return ref is Self || (ref is ChildN && ref.ownerID == g.self.id);
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

  Future<bool> remoteMerge({Map<String, Object>? data}) async {
    if (isRemoteMutable) {
      try {
        await id.userRef.update(data ?? toJson(includeLocal: false));
        return true;
      } catch (e) {
        print("error remoteMerge node id=${id.unique}\nerror=$e\n");
        return false;
      }
    } else {
      throw "node type=$runtimeType, id=${id.unique} isn't remoteMutable";
    }
  }

  Future<RemoteN?> remoteFetch() async {
    final data = (await id.userRef.get()).value as Map<String, String>?;
    if (data == null) return null;
    return fromJson<RemoteN>(data);
  }
}

class User extends Down4Node
    with RemoteN, ConnectN, BranchN, ChatN, Geo, GeoN, PersonN {
  User(
    super.id, {
    required super.activity,
    required super.name,
    required String mainDeviceID,
    required Map<String, String> messagingTokens,
    required bool isConnected,
    required Set<ComposedID> children,
    required int lastOnline,
    super.blueArrowHash,
    required super.description,
    required super.lastName,
    required super.mediaID,
    required Down4Keys neuter,
    super.latitude,
    super.longitude,
  }) : super(
            lastOnline: lastOnline,
            isConnected: isConnected,
            mainDeviceID: mainDeviceID,
            messagingTokens: messagingTokens,
            children: children,
            neuter: neuter);

  // Future<void> updateFriendStatus(bool newFriendStatus) async {
  //   _isConnected = newFriendStatus;
  //   Map<String, String> mergeInfo = {};
  //   mergeInfo["isFriend"] = _isConnected.toString();
  //   if (_isConnected) mergeInfo["isHidden"] = false.toString();
  //   await merge(mergeInfo);
  // }

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

  // bool get isFriend => _isConnected!;

  @override
  Iterable<ComposedID> get children => _children!;

  @override
  Color get color => g.theme
      .nodeColors[isConnected ? NodesColor.friend : NodesColor.nonFriend]!;

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

  @override
  bool get isConnected => _isConnected!;

  @override
  int get lastOnline => _lastOnline;

  // @override
  // bool get isConnected => _isConnected;
}

class Self extends Down4Node
    with RemoteN, ConnectN, BranchN, ChatN, Geo, GeoN, PersonN, EditN {
  Self(
    super.id, {
    required String deviceID,
    required super.activity,
    required super.name,
    required super.description,
    required super.lastName,
    super.blueArrowHash,
    required int lastOnline,
    required String mainDeviceID,
    required Map<String, String> messagingTokens,
    required Down4Keys neuter,
    required ComposedID mediaID,
    required Set<ComposedID> children,
    required Set<ComposedID> privates,
    super.latitude,
    super.longitude,
  }) : super(
            lastOnline: lastOnline,
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
    final jsonNode = Map<String, String?>.from(json["n"] as Map);
    final self = fromJson<Self>(jsonNode)..cache();
    await global<Down4Media>(self.mediaID);
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

  @override
  int get lastOnline => _lastOnline;

  @override
  bool get isConnected => false;
}

class Group extends Down4Node
    with RemoteN, ConnectN, ChatN, ChildN, GroupN, EditN {
  Group(
    super.id, {
    required super.activity,
    required super.name,
    super.blueArrowHash,
    required bool isConnected,
    required ComposedID mediaID,
    required ComposedID ownerID,
    required bool isPrivate,
    required Set<ComposedID> group,
  }) : super(
            isConnected: isConnected,
            group: group,
            isPrivate: isPrivate,
            mediaID: mediaID,
            ownerID: ownerID);

  @override
  ComposedID get ownerID => _ownerID!;

  Future<void> addMembersRef(Iterable<ComposedID> memberIDs) async {
    _group!.addAll(memberIDs);
    await merge({"group": group.values});
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

  @override
  bool get isConnected => _isConnected!;
}

class Hyperchat extends Down4Node
    with RemoteN, ConnectN, ChatN, ChildN, GroupN {
  Hyperchat(
    super.id, {
    required super.activity,
    super.blueArrowHash,
    required bool isConnected,
    required ComposedID mediaID,
    required ComposedID ownerID,
    required String firstWord,
    required String secondWord,
    required Set<ComposedID> group,
  }) : super(
            isConnected: isConnected,
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

  @override
  bool get isConnected => _isConnected!;
}

class PaymentNode with Down4Object, PaletteN {
  // @override
  // Database get dbb => throw "Don't merge palette payment";
  //
  // @override
  // int get activity => _payment.timestamp;
  //
  // @override
  // ComposedID? get mediaID => null;

  final Down4Payment _payment;
  final ComposedID selfID;
  PaymentNode({
    required Down4Payment payment,
    required this.selfID,
  }) : _payment = payment;

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
  Down4ID get id => payment.id;

  @override
  ComposedID? get mediaID => null;

  @override
  int get activity => payment.timestamp;
}

class NodeTheme with Down4Object, PaletteN {
  final Down4Theme theme;
  NodeTheme(this.theme);

  @override
  Color get color => g.theme.paletteTextColor;

  @override
  String get displayID => "font : ${theme.font}";

  @override
  String get displayName => theme.name;

  @override
  Nodes get type => Nodes.theme;

  @override
  Down4ID get id => Down4ID(unique: theme.name);

  @override
  ComposedID? get mediaID => null;

  @override
  int get activity => 0;
}
