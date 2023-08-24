import 'dart:async';
import 'dart:convert';

import 'package:down4/src/bsv/_bsv_utils.dart';
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

// extension Tokens on List<MessageTarget> {
//   List<String> get tokens => map((mt) => mt.token).toList();
// }

// class MessageTarget implements Jsons {
//   final ComposedID userID;
//   final String device;
//   final String token;
//   bool success;

//   String get messageSuccessKey => "${userID.value}~$device~$token";

//   MessageTarget({
//     required this.userID,
//     required this.device,
//     required this.token,
//     this.success = false,
//   });

//   @override
//   Map<String, String> toJson({bool includeLocal = false}) => {
//         "userID": userID.value,
//         "device": device,
//         "token": token,
//         "success": success.toString(),
//       };

//   factory MessageTarget.fromJson(Map<String, String?> json) {
//     return MessageTarget(
//       userID: ComposedID.fromString(json["userID"])!,
//       device: json["device"]!,
//       token: json["token"]!,
//       success: json["success"] == "true",
//     );
//   }
// }

mixin PaletteN on Down4Object {
  Color get color;
  Nodes get type;
  String get displayID;
  String get displayName;
  ComposedID? get mediaID;
  int get activity;
}

abstract class Down4Node with Down4Object, Jsons, Locals, PaletteN {
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
  String get publicHash => md5(publicData.toUtf8()).toBase64();

  Map<String, String>? get _jsonTreeHash =>
      _treeHash?.map((key, value) => MapEntry(key.value, value));

  static (String, String b, int) parseConnection(String conn) {
    final s = conn.split("~");
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
  Map<String, String> toJson({bool includeLocal = true}) {
    String? messagingTokens;
    if (_messagingTokens != null) {
      messagingTokens = youKnowEncode(_messagingTokens!);
    }

    return {
      "id": id.value,
      "type": (this is Self && !includeLocal) ? Nodes.user.name : type.name,
      "name": _name,
      "connection": _connection,
      if (includeLocal) "unique": id.unique,
      if (_messagingTokens != null) "messagingTokens": messagingTokens!,
      if (_mainDeviceID != null) "mainDeviceID": _mainDeviceID!,
      if (_treeHash != null) "treeHash": youKnowEncode(_jsonTreeHash!),
      if (_ownerID != null) "ownerID": _ownerID!.value,
      if (_lastName != null) "lastName": _lastName!,
      if (_isPrivate != null) "isPrivate": _isPrivate!.toString(),
      if (_longitude != null) "longitude": _longitude!.toString(),
      if (_latitude != null) "latitude": _latitude!.toString(),
      if (_mediaID != null) "mediaID": _mediaID!.value,
      if (_children != null) "children": _children!.values,
      if (_posts != null) "posts": _posts!.values,
      if (_privates != null) "privates": _privates!.values,
      if (_admins != null) "admins": _admins!.values,
      if (_neuter != null) "neuter": _neuter!.toYouKnow(),
      if (_group != null) "group": _group!.values,
      if (includeLocal && _deviceID != null) "deviceID": _deviceID!,
      if (includeLocal && _isConnected != null)
        "isConnected": _isConnected!.toString(),
      if (includeLocal) "activity": _activity.toString(),
    };
  }

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
    merge({"activity": _activity.toString()});
  }

  factory Down4Node.fromJson(Map<String, String?> json) {
    final (_, blueH, lastO) = parseConnection(json["connection"]!);

    final encTokens = json["messagingTokens"];
    Map<String, String>? messagingTokens;
    if (encTokens != null) {
      messagingTokens = Map<String, String>.from(youKnowDecode(encTokens));
    }

    final id = Down4ID.fromString(json["id"])!;
    final deviceID = json["deviceID"];
    final mainDeviceID = json["mainDeviceID"];
    final activity = int.parse(json["activity"] ?? "0");
    final type = Nodes.values.byName(json["type"]!);
    final mediaID = ComposedID.fromString(json["mediaID"]);
    final latitude = double.tryParse(json["latitude"] ?? "");
    final longitude = double.tryParse(json["longitude"] ?? "");
    final ownerID = ComposedID.fromString(json["ownerID"]);
    final name = json["name"]!;
    final isConnected = json["isConnected"] == "true";
    final isPrivate = json["isPrivate"] == "true";
    final lastName = json["lastName"];
    final description = json["description"];
    final children = json["children"]?.toComposedIDs();
    final privates = json["privates"]?.toComposedIDs();
    final admins = json["admins"]?.toComposedIDs();
    final group = json["group"]?.toComposedIDs();
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
            isConnected: isConnected,
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
            isConnected: isConnected);

      case Nodes.group:
        return Group(id as ComposedID,
            isPrivate: isPrivate,
            activity: activity,
            ownerID: ownerID!,
            blueArrowHash: blueH,
            isConnected: isConnected,
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
    await merge({"isConnected": isConnected.toString()});
  }

  Stream<DatabaseEvent> get connection {
    return id.nodeRef.child("connection").onChildChanged;
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
}

mixin BranchN on ConnectN, Down4Node {
  @override
  ComposedID get id => _id as ComposedID;

  String get blueArrowHash => _blueArrowHash;

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

mixin ChildN on Down4Node {
  ComposedID get ownerID;
}

ComposedID idOfRoot({required String root, ComposedID? selfID}) {
  final sID = selfID ?? g.self.id;
  print("the root: $root");
  final cat = root.split("!");
  if (cat.length == 1) return ComposedID.fromString(cat[0])!;
  if (cat.every((element) => element == sID.value)) {
    return sID;
  } else {
    final uStrID = cat.findWhere((strID) => strID != sID.value);
    return ComposedID.fromString(uStrID)!;
  }
}

mixin ChatN on Down4Node, Locals {
  @override
  ComposedID get id => _id as ComposedID;

  @override
  Future<void> delete() async {
    print("DELETING ChatN, unique: ${id.unique}");
    // must also delete all related chats
    final raw = "SELECT * AS m FROM _ WHERE root = '$root_'";
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final e = await q.execute();
    final r = await e.allResults();
    final msgs = r.map((m) {
      final jsns = Map<String, String?>.from(m.toPlainMap()["m"] as Map);
      return Down4Message.fromJson(jsns) as Messages;
    });

    for (final m in msgs) {
      await m.delete();
    }
    await super.delete();
  }

  String root(ComposedID selfID) {
    if (this is GroupN) return id.value;
    final st = [selfID, id]..sort((a, b) => a.unique.compareTo(b.unique));
    final cat = st.map((e) => e.value).join("!");
    return cat;
  }

  String get root_ => root(g.self.id);

  Future<List<PersonN>> get messageTargets async {
    if (this is GroupN) {
      final g = await globall<PersonN>(_group);
      return g;
    } else {
      return [g.self, this as PersonN];
    }
  }

  // // This includes the senders tokens, because we can be multi device
  // // we might send messages to ourselves
  // // For CHATS, we remove only remove the token of the sender current device
  // // this way, all participating devices will receive a message except sender's
  // // current device
  // // for CASH, we remove sender's tokens and receivers non-mainDevice tokens
  // // This is done in the messages sending functions
  // /// A user can have multiple device, hence multiple tokens
  // /// This returns all possible device tokens except the token
  // /// of the device the user is using to send the message
  // Future<List<MessageTarget>> allTargets() async {
  //   final nodeRef = this;
  //   List<MessageTarget> targets = [];
  //   final people = nodeRef is GroupN
  //       ? (await globall<PersonN>(nodeRef.group))
  //       : nodeRef.id == g.self.id
  //           ? [g.self]
  //           : [g.self, nodeRef as PersonN];

  //   for (final person in people) {
  //     for (final token in person.messagingTokens.entries) {
  //       if (person.id == g.self.id && token.key == g.self.deviceID) continue;
  //       targets.add(MessageTarget(
  //         userID: person.id,
  //         device: token.key,
  //         token: token.value,
  //       ));
  //     }
  //   }

  //   return targets;
  // }

  Future<Pair<Iterable<Down4ID>, AsyncListenStream<QueryChange<ResultSet>>>>
      getTheChat() async {
    final raw = """
        SELECT META().id AS id FROM _
        WHERE root = '$root_' AND type = 'chat'
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
        WHERE root = '$root_' AND type = 'snip' AND isRead = 'false'
        ORDER BY id ASC
        """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    return (await r.allResults())
        .map((e) => ComposedID.fromString(e.toPlainMap()["id"] as String)!);
  }

  Stream<Snip> loadSnips() async* {
    final raw = "SELECT * FROM _ AS m WHERE type = 'snip' AND root = '$root_'";
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    await for (final a in r.asStream()) {
      final json = Map<String, String?>.from(a.toPlainMap()["m"] as Map);
      yield Down4Message.fromJson(json) as Snip;
    }
  }

  Future<Chat?> lastChatMessage() async {
    final raw = """
            SELECT * FROM _ AS m
            WHERE root = '$root_' AND type = 'chat'
            ORDER BY META(m).id DESC LIMIT 1
            """;
    final q = await AsyncQuery.fromN1ql(messagesDB, raw);
    final r = await q.execute();
    final a = await r.allResults();

    if (a.isEmpty) return null;
    final single = a.single.toPlainMap()["m"] as Map;
    final json = Map<String, String?>.from(single);
    return Down4Message.fromJson(json) as Chat;
  }

  Future<bool> lastChatFromOtherIsUnread() async {
    final raw = """
            SELECT * FROM _
            WHERE root = '$root_'
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
    await merge({"lastOnline": _lastOnline.toString()});
  }

  Future<void> updateMessagingToken(Map<String, String> newToken) async {
    _messagingTokens = {...?_messagingTokens, ...newToken};
    await merge({"messagingTokens": jsonEncode(messagingTokens)});
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
    await merge({"longitude": lon.toString(), "latitude": lat.toString()});
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
        await id.nodeRef.remove();
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
        await id.nodeRef.update(data ?? toJson(includeLocal: false));
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
    final data = (await id.nodeRef.get()).value;
    if (data == null) return null;
    final jsn = Map<String, String?>.from(data as Map);
    return fromJson<RemoteN>(jsn);
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

  @override
  Map<String, String> get messagingTokens => _messagingTokens!;

  Future<bool> hasMessages() async {
    final raw_ = """
      SELECT META().id FROM _ AS m 
      WHERE m.root = '$root_'
      LIMIT 1
      """;

    final q_ = await AsyncQuery.fromN1ql(messagesDB, raw_);
    final r_ = await q_.execute();
    final e_ = await r_.allResults();
    return e_.isNotEmpty;
  }

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
    final full = r.single.toPlainMap();
    final sMap = Map<String, String?>.from(full["n"] as Map);
    final self = fromJson<Self>(sMap)..cache();
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
  bool get isConnected => true;
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

class PaymentNode with Down4Object implements PaletteN {
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

class NodeTheme with Down4Object implements PaletteN {
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
