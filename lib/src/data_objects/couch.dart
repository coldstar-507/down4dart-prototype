import 'dart:async';

import 'package:down4/src/_dart_utils.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '_data_utils.dart';
import 'medias.dart';
import 'messages.dart';
import 'nodes.dart';
import '../globals.dart';

import '../bsv/types.dart';
import '../bsv/wallet.dart';

late sql.Database db;

// late AsyncDatabase nodesDB,
//     tempDB,
//     personalDB,
//     mediasDB,
//     messagesDB,
//     utxosDB,
//     paymentsDB,
//     billsDB;

Future<List<T>> globall<T extends Locals>(
  Iterable<Down4ID>? ids, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  Iterable<ComposedID>? tempIDs,
  sql.Database? sdb,
  Map<Down4ID, Locals>? sCache,
}) async {
  if (ids == null) return [];
  final reqs = await Future.wait(ids.indexed
      .map((e) => global<T>(e.$2,
          doCache: doCache,
          doFetch: doFetch,
          sdb: sdb,
          doMergeIfFetch: doMergeIfFetch,
          tempID: tempIDs?.elementAt(e.$1)))
      .toList());
  return reqs.whereType<T>().toList();
}

List<T> locall<T extends Locals>(
  Iterable<Down4ID>? ids, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  Iterable<ComposedID>? tempIDs,
  sql.Database? sdb,
  Map<Down4ID, Locals>? sCache,
}) {
  if (ids == null) return [];
  final reqs = ids.indexed
      .map((e) => local<T>(e.$2, doCache: doCache, sdb: sdb))
      .toList();
  return reqs.whereType<T>().toList();
}

Map<Down4ID, Locals> _globalCache = {};

Locals? unCache(Down4ID id) => _globalCache.remove(id);

void cacheObj(Locals obj,
    {bool ifAbsent = false, Map<Down4ID, Locals>? sCache}) {
  final c = sCache ?? _globalCache;
  if (ifAbsent) {
    c[obj.id] ??= obj;
  } else {
    c[obj.id] = obj;
  }
}

// Future<void> loadIndexes() async {
//   final nodeTypeIndexConfig = ValueIndexConfiguration(["type"]);

//   final lastUseMediaIndexConfig = ValueIndexConfiguration(["lastUse"]);
//   final isSavedMediaIndexConfig = ValueIndexConfiguration(["isSaved"]);

//   final isSnipMessageIndexConfig = ValueIndexConfiguration(["isSnip"]);
//   final rootMessageIndexConfig = ValueIndexConfiguration(["root"]);

//   final paymentTimestampIndexConfig = ValueIndexConfiguration(["ts"]);

//   await nodesDB.createIndex("typeIndex", nodeTypeIndexConfig);

//   await mediasDB.createIndex("lastUseIndex", lastUseMediaIndexConfig);
//   await mediasDB.createIndex("isSavedIndex", isSavedMediaIndexConfig);

//   await messagesDB.createIndex("isSnipIndex", isSnipMessageIndexConfig);
//   await messagesDB.createIndex("rootIndex", rootMessageIndexConfig);

//   await paymentsDB.createIndex("timestampIndex", paymentTimestampIndexConfig);
// }

Future<T?> fetch<T extends Locals>(
  Down4ID? id, {
  bool doMerge = false,
  bool doCache = true,
  ComposedID? tempID,
  sql.Database? sdb,
  Map<Down4ID, Locals>? sc,
}) async {
  Future<T?> fetchNode() async {
    if (id is! ComposedID) return null;
    final ss = await id.nodeRef.get();
    if (!ss.exists) return null;
    final jsn = Map<String, String?>.from(ss.value as Map);
    final node = Down4Node.fromJson(jsn);
    if (doCache) node.cache(sc: sc);
    if (doMerge) node.merge(sdb: sdb);
    return node as T;
  }

  Future<T?> fetchMessage() async {
    if (id is! ComposedID) return null;
    final m = await id.messageRef.get();
    if (!m.exists) return null;
    final jsn = Map<String, String?>.from(m.value as Map);
    final msg = Down4Message.fromJson(jsn) as Messages;
    if (doCache) msg.cache(sc: sc);
    if (doMerge) msg.merge(sdb: sdb);
    return msg as T;
  }

  Future<Down4Media?> fetchMedia() async {
    Reference ref;
    if (id is ComposedID && tempID == null) {
      ref = id.staticStoreRef;
    } else if (tempID != null) {
      ref = tempID.tempStoreRef;
    } else {
      return null;
    }

    final idValue = tempID?.value ?? id?.value;
    print("FETCHING MEDIA ID = $idValue FROM NODES = ${tempID == null}");
    try {
      final futureMedia = ref.getMetadata();
      // for now seems, good to only get the data if we local merge
      // no need for another parameter
      final rawData = doMerge ? (await ref.getData()) : null;

      // will throw if no metadata, so we can use !
      final mediaJson = (await futureMedia).customMetadata!;
      final media = Down4Media.fromJson(mediaJson);
      if (doCache) media.cache(sc: sc);

      if (doMerge) {
        media.merge(sdb: sdb);
        if (rawData != null) await media.write(rawData);
      }
      return media;
    } catch (e) {
      print("Error downloading media id: $id from storage, err: $e");
      return null;
    }
  }

  Future<Down4Payment?> fetchPayment() async {
    if (id == null || tempID == null) return null;
    final ref = tempID.tempStoreRef;
    final compressed = await ref.getData();
    if (compressed == null) return null;
    printWrapped("compressed payment:\n$compressed");
    return Down4Payment.fromCompressed(compressed);
    try {
      print("TODO");
    } catch (e) {
      print("error fetching payment: $e");
      return null;
    }
  }

  switch (T) {
    case Messages:
      return fetchMessage();
    case Chat:
      return fetchMessage();
    case Snip:
      return fetchMessage();
    case Down4Node:
      return fetchNode();
    case BranchN:
      return fetchNode();
    case ChatN:
      return fetchNode();
    case GroupN:
      return fetchNode();
    case PersonN:
      return fetchNode();
    case EditN:
      return fetchNode();
    case User:
      return fetchNode();
    case Self:
      return fetchNode();
    case Group:
      return fetchNode();
    case Hyperchat:
      return fetchNode();
    case Down4Media:
      return fetchMedia() as Future<T?>;
    case Down4Video:
      return fetchMedia() as Future<T?>;
    case Down4Image:
      return fetchMedia() as Future<T?>;
    case Down4Payment:
      return fetchPayment() as Future<T?>;
  }

  throw 'Unsupported type for fetching $T';
}

String gdb<T extends Locals>() {
  switch (T) {
    case Down4Node:
      return "nodes";
    case BranchN:
      return "nodes";
    case ChatN:
      return "nodes";
    case GroupN:
      return "nodes";
    case PersonN:
      return "nodes";
    case EditN:
      return "nodes";
    case User:
      return "nodes";
    case Self:
      return "nodes";
    case Group:
      return "nodes";
    case Hyperchat:
      return "nodes";
    case Down4Media:
      return "medias";
    case Down4Video:
      return "medias";
    case Down4Image:
      return "medias";
    case Messages:
      return "messages";
    case Chat:
      return "messages";
    case Snip:
      return "messages";
    case Down4TXIN:
      return "txins";
    case Down4TXOUT:
      return "txouts";
    case Down4Payment:
      return "payments";
    case ExchangeRate:
      return "personals";
    case Wallet:
      return "personals";
    case Down4TX:
      return "transactions";
  }

  throw 'No db exists for type: $T';
}

T? local<T extends Locals>(Down4ID id,
    {bool doCache = false, Map<Down4ID, Locals>? sc, sql.Database? sdb}) {
  final cached = cache<T>(id, sc: sc);
  if (cached != null) return cached;
  return _local<T>(id, doCache: doCache, sc: sc, sdb: sdb);
}

T? _local<T extends Locals>(Down4ID id,
    {bool doCache = false, Map<Down4ID, Locals>? sc, sql.Database? sdb}) {
  final db_ = sdb ?? db;
  final r = db_.select("SELECT * FROM ${gdb<T>()} WHERE id = '${id.value}'");
  if (r.isEmpty) return null;
  final jsns = Map<String, String?>.from(r.single);
  final element = fromJson<T>(jsns);
  if (doCache) element.cache(sc: sc);
  return element;
}

T? cache<T extends Locals>(Down4ID? id, {Map<Down4ID, Locals>? sc}) {
  final c = sc ?? _globalCache;
  final element = id == null ? null : c[id] as T?;
  return element;
}

Future<T?> global<T extends Locals>(
  Down4ID? id, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  ComposedID? tempID,
  sql.Database? sdb,
  Map<Down4ID, Locals>? sc,
}) async {
  if (id == null) return null;
  final cached = cache<T>(id, sc: sc);
  if (cached != null) {
    print("RETRIEVED $T ID: ${id.value} FROM CACHE");
    return cached;
  }
  final localed = _local<T>(id, sdb: sdb, doCache: doCache, sc: sc);
  if (localed != null) {
    print("RETRIEVED $T ID: ${id.value} FROM LOCAL");
    if (doCache) localed.cache(sc: sc);
    return localed;
  }
  if (!doFetch) return null;
  final fetched = await fetch<T>(id,
      doCache: doCache,
      doMerge: doMergeIfFetch,
      tempID: tempID,
      sc: sc,
      sdb: sdb);
  if (fetched != null) {
    print("RETRIEVED $T ID: ${id.value} FROM FETCH");
    return fetched;
  }
  return null;
}

enum GetType { miss, cache, local, fetch }

Future<(T?, GetType)> globalgt<T extends Locals>(
  Down4ID? id, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  ComposedID? tempID,
  sql.Database? sdb,
  Map<Down4ID, Locals>? sc,
}) async {
  if (id == null) return (null, GetType.miss);
  final cached = cache<T>(id, sc: sc);
  if (cached != null) {
    print("RETRIEVED $T ID: ${id.value} FROM CACHE");
    return (cached, GetType.cache);
  }
  final localed = _local<T>(id, sdb: sdb, doCache: doCache, sc: sc);
  if (localed != null) {
    print("RETRIEVED $T ID: ${id.value} FROM LOCAL");
    if (doCache) localed.cache(sc: sc);
    return (localed, GetType.local);
  }
  if (!doFetch) return (null, GetType.miss);
  final fetched = await fetch<T>(id as ComposedID,
      doCache: doCache,
      doMerge: doMergeIfFetch,
      tempID: tempID,
      sc: sc,
      sdb: sdb);
  if (fetched != null) {
    print("RETRIEVED $T ID: ${id.value} FROM FETCH");
    return (fetched, GetType.fetch);
  }
  return (null, GetType.miss);
}

T fromJson<T extends Locals>(Map<String, String?> json) {
  switch (T) {
    case Reaction:
      return Down4Message.fromJson(json) as T;
    case Down4Node:
      return Down4Node.fromJson(json) as T;
    case BranchN:
      return Down4Node.fromJson(json) as T;
    case ChatN:
      return Down4Node.fromJson(json) as T;
    case GroupN:
      return Down4Node.fromJson(json) as T;
    case PersonN:
      return Down4Node.fromJson(json) as T;
    case EditN:
      return Down4Node.fromJson(json) as T;
    case User:
      return Down4Node.fromJson(json) as T;
    case Self:
      return Down4Node.fromJson(json) as T;
    case Group:
      return Down4Node.fromJson(json) as T;
    case Hyperchat:
      return Down4Node.fromJson(json) as T;
    case Down4Media:
      return Down4Media.fromJson(json) as T;
    case Down4Image:
      return Down4Media.fromJson(json) as T;
    case Down4Video:
      return Down4Media.fromJson(json) as T;
    case Chat:
      return Down4Message.fromJson(json) as T;
    case Snip:
      return Down4Message.fromJson(json) as T;
    case Down4TXOUT:
      return Down4TXOUT.fromJson(json) as T;
    case Down4Payment:
      return Down4Payment.fromJson(json) as T;
    case ExchangeRate:
      return ExchangeRate.fromJson(json) as T;
    case Wallet:
      return Wallet.fromJson(json) as T;
  }

  throw 'Cannot create Down4Object from json for this type: $T';
}

Iterable<Chat> unsentMessages() sync* {
  final q = """
        SELECT * FROM messages
        WHERE isSent = 'false' AND type = 'chat'
          AND senderID = '${g.self.id.value}'
        """;

  final r = db.select(q);

  for (final row in r) {
    final jsn = Map<String, String?>.from(row);
    yield Down4Message.fromJson(jsn) as Chat;
  }
}

Iterable<PersonN> searchLocalsByUnique(Iterable<String> uniques) sync* {
  final sbuf = StringBuffer("SELECT * FROM nodes WHERE unik IN (");
  sbuf.writeAll(uniques.map((_) => "?"), ",");
  sbuf.write(")");

  final r = db.select(sbuf.toString(), uniques.toList());
  for (final row in r) {
    final jsns = Map<String, String?>.from(row);
    yield Down4Node.fromJson(jsns) as PersonN;
  }
}

Future<Set<ComposedID>> allGroupIDs() async {
  const q = """
    SELECT group FROM nodes 
    WHERE type in ('hyperchat', 'group')
    """;

  final r = db.select(q);
  return r.fold<Set<ComposedID>>(Set<ComposedID>.identity(), (value, element) {
    final sGroup = element["group"] as String;
    value.addAll(sGroup.split(" ").map((e) => ComposedID.fromString(e)!));
    return value;
  });
}

Future<Set<ComposedID>> allMediaReferences() async {
  const nq = "SELECT mediaID FROM nodes";
  const mq = "SELECT mediaID FROM messages";

  final rn = db.select(nq);
  final rm = db.select(mq);

  const rq = "SELECT reactions FROM messages";
  final rr = db.select(rq);
  final rs = rr
      .map((e) {
        final jsn = List.from(youKnowDecode(e["reactions"]));
        return jsn.map((e) {
          final jsns = Map<String, String?>.from(e);
          return Down4Message.fromJson(jsns) as Reaction;
        });
      })
      .expand((e) => e)
      .map((e) => e.mediaID);

  return rn
      .followedBy(rm)
      .map((a) => ComposedID.fromString(a["mediaID"]))
      .whereType<ComposedID>()
      .followedBy(rs)
      .toSet();
}

// TODO: could be optimized
Future<void> messagesDeletingRoutine() async {
  final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4));

  final alternate = """
    DELETE FROM messages
    WHERE CAST(timestamp AS INTEGER) < ${fourDaysAgo.millisecondsSinceEpoch}
      AND isSaved = 'false'
      AND root != '${g.self.id.value}'
    """;

  db.execute(alternate);
}

// This should be called after messages and palettes routine
// TODO: this should be optmized aswell
// could be a single sql query
Future<void> mediaDeletingRoutine() async {
  final allMediaRefs = await allMediaReferences();
  final alternate = """
    DELETE FROM medias
    WHERE isSaved = 'false'
      AND id NOT IN ${allMediaRefs.map((id) => id.value)}
  """;

  db.execute(alternate);
}

Iterable<ChatN> loadHome() sync* {
  const q = """
    SELECT * FROM nodes
    WHERE type in ('hyperchat', 'group', 'user')
    """;
  final r = db.select(q);
  for (final row in r) {
    final jsns = Map<String, String?>.from(row);
    yield fromJson<ChatN>(jsns)..cache();
  }
}

Iterable<ConnectN> loadConnectionNodes() sync* {
  const q = """
    SELECT * FROM nodes
    WHERE isConnected = 'true'
    """;

  final r = db.select(q);
  for (final row in r) {
    final jsns = Map<String, String?>.from(row);
    yield Down4Node.fromJson(jsns) as ConnectN;
  }
}

Iterable<Down4Node> loadAllNodes() sync* {
  const q = "SELECT * FROM nodes";
  final r = db.select(q);

  for (final row in r) {
    final jsns = Map<String, String?>.from(row);
    yield Down4Node.fromJson(jsns);
  }
}

Iterable<Down4ID> savedMediaIDs(MediaType t) sync* {
  final q = """
    SELECT id FROM medias
    WHERE mime IN ${mimeMap[t]!.sqlFmt} AND isSaved = 'true'
    ORDER BY lastUse DESC
    """;

  final rows = db.select(q);
  for (final row in rows) {
    yield Down4ID.fromString(row['id'])!;
  }
}
