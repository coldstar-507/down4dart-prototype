import 'dart:async';
import 'dart:convert';

import 'package:down4/src/_dart_utils.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '_data_utils.dart';
import 'medias.dart';
import 'messages.dart';
import 'nodes.dart';
import '../globals.dart';

import '../bsv/types.dart';
import '../bsv/wallet.dart';

import 'package:cbl/cbl.dart';

late sql.Database db;

late AsyncDatabase nodesDB,
    tempDB,
    personalDB,
    mediasDB,
    messagesDB,
    utxosDB,
    paymentsDB,
    billsDB;

Future<List<T>> globall<T extends Locals>(
  Iterable<Down4ID>? ids, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  Iterable<ComposedID>? tempIDs,
  Database? sdb,
  Map<Down4ID, Locals>? sCache,
}) async {
  if (ids == null) return [];
  final reqs = await Future.wait(ids.indexed
      .map((e) => global<T>(e.$2,
          doCache: doCache,
          doFetch: doFetch,
          doMergeIfFetch: doMergeIfFetch,
          tempID: tempIDs?.elementAt(e.$1)))
      .toList());
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

Future<void> loadIndexes() async {
  final nodeTypeIndexConfig = ValueIndexConfiguration(["type"]);

  final lastUseMediaIndexConfig = ValueIndexConfiguration(["lastUse"]);
  final isSavedMediaIndexConfig = ValueIndexConfiguration(["isSaved"]);

  final isSnipMessageIndexConfig = ValueIndexConfiguration(["isSnip"]);
  final rootMessageIndexConfig = ValueIndexConfiguration(["root"]);

  final paymentTimestampIndexConfig = ValueIndexConfiguration(["ts"]);

  await nodesDB.createIndex("typeIndex", nodeTypeIndexConfig);

  await mediasDB.createIndex("lastUseIndex", lastUseMediaIndexConfig);
  await mediasDB.createIndex("isSavedIndex", isSavedMediaIndexConfig);

  await messagesDB.createIndex("isSnipIndex", isSnipMessageIndexConfig);
  await messagesDB.createIndex("rootIndex", rootMessageIndexConfig);

  await paymentsDB.createIndex("timestampIndex", paymentTimestampIndexConfig);
}

Future<T?> fetch<T extends Locals>(
  ComposedID? id, {
  bool doMerge = false,
  bool doCache = true,
  ComposedID? tempID,
  Database? sdb,
  Map<Down4ID, Locals>? sc,
}) async {
  Future<T?> fetchNode() async {
    if (id == null) return null;
    final ss = await id.nodeRef.get();
    if (!ss.exists) return null;
    final jsn = Map<String, String?>.from(ss.value as Map);
    final node = Down4Node.fromJson(jsn);
    if (doCache) node.cache(sc: sc);
    if (doMerge) node.merge(null, sdb);
    return node as T;
  }

  Future<T?> fetchMessage() async {
    if (id == null) return null;
    final m = await id.messageRef.get();
    if (!m.exists) return null;
    final jsn = Map<String, String?>.from(m.value as Map);
    final msg = Down4Message.fromJson(jsn) as Messages;
    if (doCache) msg.cache(sc: sc);
    if (doMerge) msg.merge(null, sdb);
    return msg as T;
  }

  Future<Down4Media?> fetchMedia() async {
    if (id == null && tempID == null) return null;
    final fromNodes = tempID == null;
    final idValue = tempID?.value ?? id?.value;
    print("FETCHING MEDIA ID = $idValue FROM NODES = $fromNodes");
    final ref = fromNodes ? id!.staticStoreRef : tempID.tempStoreRef;
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
        media.merge(null, sdb);
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
    try {
      final compressed = await ref.getData();
      if (compressed == null) return null;
      return Down4Payment.fromCompressed(compressed);
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

Database gdb<T extends Locals>() {
  switch (T) {
    case Down4Node:
      return nodesDB;
    case BranchN:
      return nodesDB;
    case ChatN:
      return nodesDB;
    case GroupN:
      return nodesDB;
    case PersonN:
      return nodesDB;
    case EditN:
      return nodesDB;
    case User:
      return nodesDB;
    case Self:
      return nodesDB;
    case Group:
      return nodesDB;
    case Hyperchat:
      return nodesDB;
    case Down4Media:
      return mediasDB;
    case Down4Video:
      return mediasDB;
    case Down4Image:
      return mediasDB;
    case Messages:
      return messagesDB;
    case Chat:
      return messagesDB;
    case Snip:
      return messagesDB;
    case Down4TXOUT:
      return utxosDB;
    case Down4Payment:
      return paymentsDB;
    case ExchangeRate:
      return personalDB;
    case Wallet:
      return personalDB;
  }

  throw 'No db exists for type: $T';
}

Future<T?> local<T extends Locals>(Down4ID id,
    {bool doCache = false, Map<Down4ID, Locals>? sc, Database? sdb}) async {
  final db = sdb ?? gdb<T>();
  final doc = await db.document(id.value);
  if (doc == null) return null;
  final jsns = Map<String, String?>.from(doc.toPlainMap());
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
  Database? sdb,
  Map<Down4ID, Locals>? sc,
}) async {
  if (id == null) return null;
  final cached = cache<T>(id, sc: sc);
  if (cached != null) {
    print("RETRIEVED $T ID: ${id.value} FROM CACHE");
    return cached;
  }
  final localed = await local<T>(id, sdb: sdb, doCache: doCache, sc: sc);
  if (localed != null) {
    print("RETRIEVED $T ID: ${id.value} FROM LOCAL");
    if (doCache) localed.cache(sc: sc);
    return localed;
  }
  if (!doFetch) return null;
  final fetched = await fetch<T>(id as ComposedID,
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
  Database? sdb,
  Map<Down4ID, Locals>? sc,
}) async {
  if (id == null) return (null, GetType.miss);
  final cached = cache<T>(id, sc: sc);
  if (cached != null) {
    print("RETRIEVED $T ID: ${id.value} FROM CACHE");
    return (cached, GetType.cache);
  }
  final localed = await local<T>(id, sdb: sdb, doCache: doCache, sc: sc);
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

Future<List<Chat>> unsentMessages() async {
  final raw = """
        SELECT * FROM _ AS m
        WHERE m.isSent = 'false' AND m.type = 'chat'
          AND m.senderID = '${g.self.id.value}'
        """;
  final q = await AsyncQuery.fromN1ql(messagesDB, raw);
  final e = await q.execute();
  final r = await e.allResults();

  return r.map((e) {
    final jsn = Map<String, String?>.from(e.toPlainMap()["m"] as Map);
    return Down4Message.fromJson(jsn) as Chat;
  }).toList();
}

Future<List<PersonN>> searchLocalsByUnique(Iterable<String> uniques) async {
  final raw = """
    SELECT * FROM _ as n
    WHERE n.unique IN ${uniques.map((e) => "'$e'").toString()} 
    """;

  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final e = await q.execute();
  final r = await e.allResults();

  return r.map((e) {
    final jsn = Map<String, String?>.from(e.toPlainMap()["n"] as Map);
    return fromJson<PersonN>(jsn);
  }).toList();
}

Future<Set<ComposedID>> allGroupIDs() async {
  const rawq = """
    SELECT group FROM _ 
    WHERE nodes.type in ('hyperchat', 'group')
    """;
  final q = await AsyncQuery.fromN1ql(nodesDB, rawq);
  final e = await q.execute();
  final r = await e.allResults();
  return r.fold<Set<ComposedID>>(Set<ComposedID>.identity(), (value, element) {
    final sGroup = element.toPlainMap()["group"] as String;
    value.addAll(sGroup.split(" ").map((e) => ComposedID.fromString(e)!));
    return value;
  });
}

Future<Set<ComposedID>> allMediaReferences() async {
  const nq = "SELECT mediaID FROM _";
  final q1 = await AsyncQuery.fromN1ql(messagesDB, nq);
  final q2 = await AsyncQuery.fromN1ql(nodesDB, nq);
  final e1 = await q1.execute();
  final e2 = await q2.execute();
  final a1 = await e1.allResults();
  final a2 = await e2.allResults();

  const rq = "SELECT reactions FROM _";
  final qr = await AsyncQuery.fromN1ql(messagesDB, rq);
  final er = await qr.execute();
  final ar = await er.allResults();
  final rs = ar
      .map((e) {
        final jsn = List.from(youKnowDecode(e.string("reactions")!));
        return jsn.map((e) {
          final jsns = Map<String, String?>.from(e as Map);
          return Down4Message.fromJson(jsns) as Reaction;
        });
      })
      .expand((e) => e)
      .map((e) => e.mediaID);

  return a1
      .followedBy(a2)
      .map((a) => ComposedID.fromString(a.string("mediaID")))
      .whereType<ComposedID>()
      .followedBy(rs)
      .toSet();
}

Future<void> messagesDeletingRoutine() async {
  final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4));
  final raw = """
    SELECT * FROM _ AS m
    WHERE TONUMBER(m.timestamp) < ${fourDaysAgo.millisecondsSinceEpoch}
      AND m.isSaved = 'false'
      AND m.root != '${g.self.id.value}'
    """;
  final q = await AsyncQuery.fromN1ql(messagesDB, raw);
  final e = await q.execute();
  await for (final m in e.asStream()) {
    final jsn = Map<String, String?>.from(m.toPlainMap()["m"] as Map);
    final msg = Down4Message.fromJson(jsn) as Locals;
    msg.delete();
  }
}

// This should be called after messages and palettes routine
Future<void> mediaDeletingRoutine() async {
  const raw = "SELECT * FROM _ AS m WHERE isSaved = 'false'";
  final allMediaRefs = await allMediaReferences();
  final q = await AsyncQuery.fromN1ql(mediasDB, raw);
  final e = await q.execute();
  await for (final r in e.asStream()) {
    final jsn = Map<String, String?>.from(r.toPlainMap()["m"] as Map);
    final media = Down4Media.fromJson(jsn);
    if (!allMediaRefs.contains(media.id)) media.delete();
  }
}

Future<List<ChatN>> loadHome() async {
  const raw = """
    SELECT * FROM _ AS n
    WHERE n.type in ('hyperchat', 'group', 'user')
    """;

  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final r = await q.execute();
  final a = await r.allResults();
  return a.map((e) {
    final jsn = Map<String, String?>.from(e.toPlainMap()["n"] as Map);
    print("Loading home node id =${jsn['id']}");
    return fromJson<ChatN>(jsn)..cache();
  }).toList();
}

Future<List<ConnectN>> loadConnectionNodes() async {
  const raw = """
    SELECT * FROM _ as n
    WHERE n.isConnected = 'true'
    """;

  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final r = await q.execute();
  return Future.wait((await r.allResults()).map((e) async {
    final jsn = Map<String, String?>.from(e.toPlainMap()["n"] as Map);
    print("Loading home node id = '${jsn['id']}'");
    return fromJson<ConnectN>(jsn)..cache();
  }).toList());
}

Future<List<Down4Node>> loadAllNodes() async {
  const raw = "SELECT * FROM _ as n";
  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final r = await q.execute();
  return Future.wait((await r.allResults()).map((e) async {
    final jsn = Map<String, String?>.from(e.toPlainMap()["n"] as Map);
    print("Loading home node id = '${jsn['id']}'");
    return fromJson<Down4Node>(jsn)..cache();
  }).toList());
}

Future<AsyncListenStream<QueryChange<ResultSet>>> savedMediaIDs(
  MediaType t,
) async {
  final raw = """
        SELECT META().id FROM _
        WHERE mime IN ${mimeMap[t]!.sqlFmt} AND isSaved = 'true'
        ORDER BY lastUse DESC
        """;

  print("savedMediaIDs raw q = $raw");
  final query = await AsyncQuery.fromN1ql(mediasDB, raw);
  return query.changes();
}

extension WalletManager on Wallet {
  Stream<Down4Payment> get payments async* {
    const raw = "SELECT * FROM _ AS p ORDER BY p.ts DESC";
    final q = await AsyncQuery.fromN1ql(paymentsDB, raw);
    final r = await q.execute();
    await for (final p in r.asStream()) {
      final jsn = Map<String, String?>.from(p.toPlainMap()["p"] as Map);
      yield Down4Payment.fromJson(jsn);
    }
  }

  Stream<Down4Payment> nPayments({required int limit, int offset = 0}) async* {
    final raw = """
        SELECT * FROM _ AS p
        ORDER BY p.ts DESC
        OFFSET $offset LIMIT $limit
        """;
    final q = await AsyncQuery.fromN1ql(paymentsDB, raw);
    final r = await q.execute();
    await for (final p in r.asStream()) {
      final jsn = Map<String, String?>.from(p.toPlainMap()["p"] as Map);
      yield Down4Payment.fromJson(jsn);
    }
  }

  Stream<Down4TXOUT> get utxos async* {
    const raw = "SELECT * FROM _ AS u";
    final q = await AsyncQuery.fromN1ql(utxosDB, raw);
    final r = await q.execute();
    await for (final u in r.asStream()) {
      final jsn = Map<String, String?>.from(u.toPlainMap()["u"] as Map);
      yield Down4TXOUT.fromJson(jsn);
    }
  }

  Future<Down4TXOUT?> getUtxo(Down4ID id) async {
    return local<Down4TXOUT>(id);
  }

  Future<void> removeUtxo(Down4ID id) async {
    await gdb<Down4TXOUT>().purgeDocumentById(id.value);
  }

  Future<Down4Payment?> getPayment(Down4ID id) async {
    return local<Down4Payment>(id);
  }

  Future<void> removePayment(Down4ID id) async {
    await gdb<Down4Payment>().purgeDocumentById(id.value);
  }

  Future<void> setPayment(Down4Payment payment) async {
    await payment.merge();
  }

  Future<void> setUtxo(Down4TXOUT utxo) async {
    await utxo.merge();
  }

  Future<bool> isSpent(Down4ID utxoID) async {
    return (await dbb.document(id.value))?.string(utxoID.value) == "true";
  }

  Future<void> setSpent(Down4ID id, bool spent) async {
    await merge({id.value: spent.toString()});
  }

  static Future<Wallet?> load() async {
    return local<Wallet>(Down4ID(unique: "wallet"));
  }
}
