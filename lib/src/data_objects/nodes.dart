import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:down4/src/bsv/_bsv_utils.dart';
import 'package:down4/src/globals.dart';
import 'package:down4/src/themes.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart' show Color;

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
  String get table => "nodes";

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
  final Set<ComposedID>? _members, _children, _privates, _posts, _admins;
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
  String get publicHash => md5(publicData.codeUnits).toBase64();

  Map<String, String>? get _jsonTreeHash =>
      _treeHash?.map((key, value) => MapEntry(key.value, value));

  static (String, String b, int) parseConnection(String conn) {
    final s = conn.split("~");
    return (s[0], s[1], int.parse(s[2]));
  }

  String get publicData {
    return id.unik +
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
        (_members?.join(" ") ?? "");
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
      if (includeLocal) "unik": id.unik,
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
      if (_members != null) "members": _members!.values,
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
    Map<ComposedID, String>? treeHash,
    Set<ComposedID>? children,
    Set<ComposedID>? privates,
    Set<ComposedID>? posts,
    Set<ComposedID>? admins,
    Set<ComposedID>? members,
  })  : _id = id,
        _activity = activity,
        _lastOnline = lastOnline ?? 0,
        _name = name,
        _treeHash = treeHash,
        _isConnected = isConnected,
        _mainDeviceID = mainDeviceID,
        _deviceID = deviceID,
        _lastName = lastName,
        _blueArrowHash = blueArrowHash ?? id.unik,
        _isPrivate = isPrivate,
        _latitude = latitude,
        _longitude = longitude,
        _messagingTokens = messagingTokens,
        _description = description,
        _neuter = neuter,
        _mediaID = mediaID,
        _ownerID = ownerID,
        _privates = privates,
        _members = members,
        _admins = admins,
        _posts = posts,
        _children = children;

  Down4Node copy() => Down4Node.fromJson(toJson());

  void updateActivity([int? newActivity]) {
    _activity = newActivity ?? makeTimestamp();
    merge(vals: {"activity": _activity.toString()});
  }

  factory Down4Node.fromJson(Map<String, String?> json) {
    final (_, blueH, lastO) = parseConnection(json["connection"]!);

    final encTokens = json["messagingTokens"];
    Map<String, String>? messagingTokens;
    if (encTokens != null) {
      messagingTokens = Map<String, String>.from(youKnowDecode(encTokens));
    }

    final encTreeHash = json["treeHash"];
    Map<ComposedID, String>? treeHash;
    if (encTreeHash != null) {
      final jsnTree = Map<String, String>.from(youKnowDecode(encTreeHash));
      treeHash = jsnTree.map((k, v) => MapEntry(ComposedID.fromString(k)!, v));
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
    final members = json["members"]?.toComposedIDs();
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
            treeHash: treeHash,
            latitude: latitude);

      case Nodes.hyperchat:
        return Hyperchat(id as ComposedID,
            activity: activity,
            ownerID: ownerID!,
            mediaID: mediaID!,
            blueArrowHash: blueH,
            firstWord: name,
            secondWord: lastName!,
            members: members!,
            treeHash: treeHash,
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
            treeHash: treeHash,
            members: members!);

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
  void updateConnectionStatus(bool isConnected) {
    _isConnected = isConnected;
    merge(vals: {"isConnected": isConnected.toString()});
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
    treeHash = tree;
    final jsnTree = tree.map((key, value) => MapEntry(key.value, value));
    merge(vals: {"treeHash": youKnowEncode(jsnTree)});
  }

  @override
  String get publicHash {
    if ((treeHash ?? {}).isEmpty) return "empty";
    final hashes =
        treeHash!.values.map((e) => List<int>.from(e.codeUnits)).toList();

    final mx = hashes.fold(0, (val, h) => max(val, h.length));
    for (final hash in hashes) {
      final dif = mx - hash.length;
      hash.addAll(List.filled(dif, 0));
    }

    var hash = hashes.first;
    for (int i = 1; i < hashes.length; i++) {
      for (int j = 0; j < mx; j++) {
        hash[j] = hash[j] ^ hashes[i][j];
      }
    }

    return hash.toBase64();
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
  String? delete({bool stmt = false}) {
    print("DELETING ChatN, unik: ${id.unik}");
    // must also delete all related chats
    const q = "SELECT * FROM messages WHERE root = ?";
    final r = db.select(q, [root_]);
    final msgs = r.map((m) {
      final jsns = Map<String, String?>.from(m);
      return Down4Message.fromJson(jsns) as Messages;
    });

    for (final m in msgs) {
      m.delete();
    }
    super.delete();
    return null;
  }

  String root(ComposedID selfID) {
    if (this is GroupN) return id.value;
    final st = [selfID, id]..sort((a, b) => a.unik.compareTo(b.unik));
    final cat = st.map((e) => e.value).join("!");
    return cat;
  }

  String get root_ => root(g.self.id);

  Future<List<PersonN>> get messageTargets async {
    if (this is GroupN) {
      final g = await globall<PersonN>(_members);
      return g;
    } else if (g.self == this) {
      return [g.self];
    } else {
      return [g.self, this as PersonN];
    }
  }

  Iterable<ComposedID> fullChatIDs() sync* {
    final q = """
        SELECT id FROM messages
        WHERE root = '$root_' AND type = 'chat'
        ORDER BY id DESC
        """;
    final r = db.select(q);
    for (final row in r) {
      yield ComposedID.fromString(row['id'])!;
    }
  }

  Iterable<ComposedID> unreadSnipIDs() sync* {
    final q = """
        SELECT id FROM messages
        WHERE root = '$root_' AND type = 'snip' AND isRead = 'false'
        ORDER BY id ASC
        """;
    final r = db.select(q);
    for (final row in r) {
      yield ComposedID.fromString(row['id'])!;
    }
  }

  Iterable<Snip> loadSnips() sync* {
    final q = "SELECT * FROM messages WHERE type = 'snip' AND root = '$root_'";
    final r = db.select(q);
    for (final row in r) {
      final jsns = Map<String, String?>.from(row);
      yield Down4Message.fromJson(jsns) as Snip;
    }
  }

  Chat? lastChatMessage() {
    final q = """
            SELECT * FROM messages
            WHERE root = '$root_' AND type = 'chat'
            ORDER BY id DESC LIMIT 1
            """;

    final r = db.select(q);
    if (r.isEmpty) return null;
    final jsns = Map<String, String?>.from(r.single);
    return Down4Message.fromJson(jsns) as Chat;
  }

  bool lastChatFromOtherIsUnread() {
    final q = """
            SELECT * FROM messages
            WHERE root = '$root_'
              AND type = 'chat'
              AND isRead = 'false'
              AND senderID != '${g.self.id.value}'
            ORDER BY id DESC LIMIT 1
            """;

    final r = db.select(q);
    return r.isNotEmpty;
  }
}

mixin GroupN on ChatN, ChildN {
  Iterable<ComposedID> get members;
  @override
  String get displayID => members.map((id) => "@${id.unik}").join(" ");

  @override
  String get publicHash {
    if (members.isEmpty) return "empty";
    final uniks = members.map((e) => List<int>.from(e.unik.codeUnits)).toList();

    final maxu = uniks.fold(0, (val, e) => max(val, e.length));
    for (final u in uniks) {
      final diff = maxu - u.length;
      u.addAll(List.filled(diff, 0));
    }

    final hash = uniks.first;
    for (int i = 1; i < uniks.length; i++) {
      for (int j = 0; j < hash.length; j++) {
        hash[j] = hash[j] ^ uniks[i][j];
      }
    }

    return hash.toBase64();
  }
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

  void updateLastOnline(int? lastOnline) {
    if (lastOnline == null) return;
    _lastOnline = lastOnline;
    merge(vals: {"lastOnline": _lastOnline.toString()});
  }

  void updateMessagingToken(Map<String, String> newToken) {
    _messagingTokens = {...?_messagingTokens, ...newToken};
    merge(vals: {"messagingTokens": jsonEncode(messagingTokens)});
  }

  @override
  String get displayID => "@${id.unik}";

  @override
  String get displayName =>
      firstName + ((lastName != null) ? " $lastName" : "");
}

mixin EditN on Down4Node {
  void editName(String newName) {
    _name = newName;
    merge(vals: {"name": _name});
  }

  void editLastName(String? newLastName) {
    _lastName = newLastName;
    merge(vals: {"lastName": _lastName ?? ""});
  }

  void editImage(Down4Media newImage) {
    _mediaID = newImage.id;
    merge(vals: {"mediaID": _mediaID!.value});
  }

  void editDescription(String newDescription) {
    _description = newDescription;
    merge(vals: {"description": _description!});
  }
}

mixin GeoN on Geo, Down4Node {
  void updateLocation(double lon, double lat) {
    _longitude = lon;
    _latitude = lat;
    merge(vals: {"longitude": lon.toString(), "latitude": lat.toString()});
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
      throw "node type=$runtimeType, id=${id.unik} isn't remoteMutable";
    }
  }

  Future<bool> remoteMerge({Map<String, Object>? data}) async {
    if (isRemoteMutable) {
      try {
        await id.nodeRef.update(data ?? toJson(includeLocal: false));
        return true;
      } catch (e) {
        print("error remoteMerge node id=${id.unik}\nerror=$e\n");
        return false;
      }
    } else {
      throw "node type=$runtimeType, id=${id.unik} isn't remoteMutable";
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
    super.treeHash,
  }) : super(
            lastOnline: lastOnline,
            isConnected: isConnected,
            mainDeviceID: mainDeviceID,
            messagingTokens: messagingTokens,
            children: children,
            neuter: neuter);

  @override
  Map<String, String> get messagingTokens => _messagingTokens!;

  bool hasMessages() {
    final q = """
      SELECT id FROM messages 
      WHERE root = '$root_'
      LIMIT 1
      """;

    final r = db.select(q);
    return r.isNotEmpty;
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

  static Self? loadSelf() {
    const q = "SELECT * FROM nodes WHERE type = 'self'";
    final r = db.select(q);

    if (r.isEmpty) return null;
    final sMap = Map<String, String?>.from(r.single);
    final self = fromJson<Self>(sMap)..cache();
    local<Down4Media>(self.mediaID);
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
    required Set<ComposedID> members,
    super.treeHash,
  }) : super(
            isConnected: isConnected,
            members: members,
            isPrivate: isPrivate,
            mediaID: mediaID,
            ownerID: ownerID);

  @override
  ComposedID get ownerID => _ownerID!;

  void addMembersRef(Iterable<ComposedID> memberIDs) {
    _members!.addAll(memberIDs);
    merge(vals: {"members": members.values});
  }

  bool get isPrivate => _isPrivate!;

  @override
  Color get color => g.theme.nodeColors[NodesColor.group]!;

  @override
  String get displayName => _name;

  @override
  Iterable<ComposedID> get members => _members!;

  @override
  ComposedID? get mediaID => _mediaID;

  @override
  Nodes get type => Nodes.group;

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
    required Set<ComposedID> members,
    super.treeHash,
  }) : super(
            isConnected: isConnected,
            mediaID: mediaID,
            members: members,
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
  Iterable<ComposedID> get members => _members!;

  @override
  ComposedID? get mediaID => _mediaID;

  @override
  Nodes get type => Nodes.hyperchat;

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
  String get displayName => payment.formattedName;

  Down4Payment get payment => _payment;

  @override
  String get displayID {
    final buf = StringBuffer("Confirmations: ");
    final confs = payment.confirmations;
    if (confs > 100) {
      buf.write("100+");
    } else if (confs > 0) {
      buf.write(confs.toString());      
    } else if (confs == -1) {
      buf.write("unsettled");
    } else if (confs == 0) {
      buf.write("accepted");
    }
    return buf.toString();
  }

  @override
  Color get color {
    final confs = payment.confirmations;
    if (confs == -1) {
      return g.theme.nodeColors[NodesColor.unsafeTx]!;
    } else if (confs < 6) {
      return g.theme.nodeColors[NodesColor.mediumTx]!;
    } else {
      return g.theme.nodeColors[NodesColor.safeTx]!;
    }
  }

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
  Down4ID get id => Down4ID(unik: theme.name);

  @override
  ComposedID? get mediaID => null;

  @override
  int get activity => 0;
}
