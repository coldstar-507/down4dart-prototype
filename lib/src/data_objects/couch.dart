import 'dart:async';

import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '_data_utils.dart';
import 'medias.dart';
import 'messages.dart';
import 'nodes.dart';
import '../globals.dart';

import '../bsv/types.dart';
import '../bsv/wallet.dart';

// late sql.Database db;

// late AsyncDatabase nodesDB,
//     tempDB,
//     personalDB,
//     mediasDB,
//     messagesDB,
//     utxosDB,
//     paymentsDB,
//     billsDB;

Future<List<T>> globall<T extends Locals>(
  Iterable<Down4ID?>? ids, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  Iterable<ComposedID?>? tempIDs,
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

List<T> locall<T extends Locals>(
  Iterable<Down4ID?>? ids, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  Iterable<ComposedID>? tempIDs,
}) {
  if (ids == null) return [];
  final reqs =
      ids.indexed.map((e) => local<T>(e.$2, doCache: doCache)).toList();
  return reqs.whereType<T>().toList();
}

Future<T?> fetch<T extends Locals>(
  Down4ID? id, {
  bool doMerge = false,
  bool doCache = true,
  ComposedID? tempID,
}) async {
  Future<T?> fetchNode() async {
    if (id is! ComposedID) return null;
    final ss = await id.nodeRef.get();
    if (!ss.exists) return null;
    final jsn = Map<String, String?>.from(ss.value as Map);
    final node = Down4Node.fromJson(jsn);
    if (doCache) node.cache();
    if (doMerge) node.merge();
    return node as T;
  }

  Future<T?> fetchMessage() async {
    if (id is! ComposedID) return null;
    final m = await id.messageRef.get();
    if (!m.exists) return null;
    final jsn = Map<String, String?>.from(m.value as Map);
    final msg = Down4Message.fromJson(jsn) as Messages;
    if (doCache) msg.cache();
    if (doMerge) msg.merge();
    return msg as T;
  }

  Future<T?> fetchMedia() async {
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
      if (doCache) media.cache();

      if (doMerge) {
        media.merge();
        if (rawData != null) await media.write(rawData);
      }
      return media as T;
    } catch (e) {
      print("Error downloading media id: $id from storage, err: $e");
      return null;
    }
  }

  Future<T?> fetchPayment() async {
    if (id == null || tempID == null) return null;
    final ref = tempID.tempStoreRef;
    final compressed = await ref.getData();
    if (compressed == null) return null;
    printWrapped("compressed payment:\n$compressed");
    return Down4Payment.fromCompressed(compressed) as T;
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
      return fetchMedia();
    case Down4Video:
      return fetchMedia();
    case Down4Image:
      return fetchMedia();
    case Down4Payment:
      return fetchPayment();
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

T? local<T extends Locals>(Down4ID? id, {bool doCache = false}) {
  if (id == null) return null;
  final cached = cache<T>(id);
  if (cached != null) return cached;
  return _local<T>(id, doCache: doCache);
}

T? _local<T extends Locals>(Down4ID id, {bool doCache = false}) {
  final r = Down4Local()
      .db
      .select("SELECT * FROM ${gdb<T>()} WHERE id = '${id.value}'");
  if (r.isEmpty) return null;
  final jsns = Map<String, String?>.from(r.single);
  final element = fromJson<T>(jsns);
  if (doCache) element.cache();
  return element;
}

T? cache<T extends Locals>(Down4ID? id) {
  final element = id == null ? null : Down4Cache().at(id) as T?;
  return element;
}

Future<T?> global<T extends Locals>(
  Down4ID? id, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  ComposedID? tempID,
}) async {
  if (id == null) return null;
  final cached = cache<T>(id);
  if (cached != null) {
    print("RETRIEVED $T ID: ${id.value} FROM CACHE");
    return cached;
  }
  final localed = _local<T>(id, doCache: doCache);
  if (localed != null) {
    print("RETRIEVED $T ID: ${id.value} FROM LOCAL");
    if (doCache) localed.cache();
    return localed;
  }
  if (!doFetch) return null;
  final fetched = await fetch<T>(id,
      doCache: doCache, doMerge: doMergeIfFetch, tempID: tempID);
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
}) async {
  if (id == null) return (null, GetType.miss);
  final cached = cache<T>(id);
  if (cached != null) {
    print("RETRIEVED $T ID: ${id.value} FROM CACHE");
    return (cached, GetType.cache);
  }
  final localed = _local<T>(id, doCache: doCache);
  if (localed != null) {
    print("RETRIEVED $T ID: ${id.value} FROM LOCAL");
    if (doCache) localed.cache();
    return (localed, GetType.local);
  }
  if (!doFetch) return (null, GetType.miss);
  final fetched = await fetch<T>(id as ComposedID,
      doCache: doCache, doMerge: doMergeIfFetch, tempID: tempID);
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

  final r = Down4Local().db.select(q);

  for (final row in r) {
    final jsn = Map<String, String?>.from(row);
    yield Down4Message.fromJson(jsn) as Chat;
  }
}

Iterable<PersonN> searchLocalsByUnique(Iterable<String> uniques) sync* {
  final sbuf = StringBuffer("SELECT * FROM nodes WHERE unik IN (");
  sbuf.writeAll(uniques.map((_) => "?"), ",");
  sbuf.write(")");

  final r = Down4Local().db.select(sbuf.toString(), uniques.toList());
  for (final row in r) {
    final jsns = Map<String, String?>.from(row);
    yield Down4Node.fromJson(jsns) as PersonN;
  }
}

Set<ComposedID> allGroupIDs() {
  const q = """
    SELECT group FROM nodes 
    WHERE type in ('hyperchat', 'group')
    """;

  final r = Down4Local().db.select(q);
  return r.fold<Set<ComposedID>>(Set<ComposedID>.identity(), (value, element) {
    final sGroup = element["group"] as String;
    value.addAll(sGroup.split(" ").map((e) => ComposedID.fromString(e)!));
    return value;
  });
}

Set<ComposedID> allMediaReferences() {
  final rn = Down4Local().db.select("SELECT mediaID FROM nodes");
  final rm = Down4Local().db.select("SELECT mediaID FROM messages");
  final rmn = (rn.followedBy(rm))
      .map((e) => ComposedID.fromString(e["mediaID"]))
      .whereType<ComposedID>();

  const q = "SELECT reactions FROM messages";
  final Iterable<ComposedID> rr = Down4Local()
      .db
      .select(q)
      .map((e) {
        final reacs = e["reactions"];
        if (reacs == null) return null;
        final jsnl = Map.from(youKnowDecode(reacs));
        return jsnl.map((k, v) {
          final mid = ComposedID.fromString(v["mediaID"])!;
          return MapEntry(k, mid);
        }).values;
      })
      .whereType<Iterable<ComposedID>>()
      .expand((b) => b);

  return (rmn.followedBy(rr)).toSet();
}

// TODO: could be optimized // how?
void messagesDeletingRoutine() {
  final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4));

  final countStmt = """
  SELECT COUNT(*) AS c FROM messages
  WHERE
    (CAST(timestamp AS INTEGER) < ${fourDaysAgo.millisecondsSinceEpoch}
      AND ((root != ${g.self.id.sqlReady} AND type = 'chat') OR type = 'snip'))
    OR (type = 'snip' AND isRead = 'true')
  """;
  final count = Down4Local().db.select(countStmt).single["c"] as int;
  print("""
    //////////////////////////////
    // DELETING $count MESSAGES //
    //////////////////////////////
    """);

  final msgDeleteStmt = """
  DELETE FROM messages
  WHERE
    (CAST(timestamp AS INTEGER) < ${fourDaysAgo.millisecondsSinceEpoch}
      AND ((root != ${g.self.id.sqlReady} AND type = 'chat') OR type = 'snip'))
    OR (type = 'snip' AND isRead = 'true')
  """;

  Down4Local().db.execute(msgDeleteStmt);
}

// This should be called after messages and palettes routine
// TODO: this should be optmized aswell
// could be a single sql query
void mediasDeletingRoutine() {
  final allMediaRefs = allMediaReferences();
  final sbuf = StringBuffer()
    ..writeAll(allMediaRefs.map((e) => e.sqlReady), ',');

  final mediasToDeleteStmt = """
  SELECT * FROM medias
  WHERE isSaved = 'false'
    AND id NOT in (${sbuf.toString()})
  """;

  final mediasToDelete = Down4Local().db.select(mediasToDeleteStmt).map((e) {
    final jsns = Map<String, String?>.from(e);
    return Down4Media.fromJson(jsns);
  });

  int fileBytesDeleted = 0;
  int nMediasDeleted = 0;
  for (final m in mediasToDelete) {
    fileBytesDeleted += m.sizeInBytes;
    nMediasDeleted += 1;
    m.delete();
  }

  print("""
    ///////////////////////////////////////////////////////
    // deleted $nMediasDeleted medias                    //
    // ${fileBytesDeleted ~/ 1000000} mb of data removed //
    ///////////////////////////////////////////////////////
    """);
}

Iterable<ChatN> loadHome() sync* {
  const q = """
    SELECT * FROM nodes
    WHERE type in ('hyperchat', 'group', 'user')
    """;
  final r = Down4Local().db.select(q);
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

  final r = Down4Local().db.select(q);
  for (final row in r) {
    final jsns = Map<String, String?>.from(row);
    yield Down4Node.fromJson(jsns) as ConnectN;
  }
}

Iterable<Down4Node> loadAllNodes() sync* {
  const q = "SELECT * FROM nodes";
  final r = Down4Local().db.select(q);

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

  final rows = Down4Local().db.select(q);
  for (final row in rows) {
    yield Down4ID.fromString(row['id'])!;
  }
}
