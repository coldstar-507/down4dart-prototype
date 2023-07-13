import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:video_thumbnail/video_thumbnail.dart';

import '_data_utils.dart';
import 'firebase.dart';
import 'medias.dart';
import 'messages.dart';
import 'nodes.dart';
import '../globals.dart';

import '../bsv/types.dart';
import '../bsv/wallet.dart';

import 'package:cbl/cbl.dart';

late AsyncDatabase nodesDB,
    personalDB,
    mediasDB,
    reactionsDB,
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

void gCache(Locals obj, {bool ifAbsent = false}) {
  if (ifAbsent) {
    _globalCache[obj.id] ??= obj;
  } else {
    _globalCache[obj.id] = obj;
  }
}

Future<void> loadIndexes() async {
  final isHiddenNodeIndexConfig = ValueIndexConfiguration(["isHidden"]);
  final nodeTypeIndexConfig = ValueIndexConfiguration(["type"]);

  final lastUseMediaIndexConfig = ValueIndexConfiguration(["lastUse"]);
  final isSavedMediaIndexConfig = ValueIndexConfiguration(["isSaved"]);
  final isVideoMediaIndexConfig = ValueIndexConfiguration(["isVideo"]);

  final isSavedMessageIndexConfig = ValueIndexConfiguration(["isSaved"]);
  final isSnipMessageIndexConfig = ValueIndexConfiguration(["isSnip"]);
  final rootMessageIndexConfig = ValueIndexConfiguration(["root"]);

  final paymentTimestampIndexConfig = ValueIndexConfiguration(["ts"]);

  final reactionMessageRefIndexConfig = ValueIndexConfiguration(["messageID"]);

  await nodesDB.createIndex("hiddenIndex", isHiddenNodeIndexConfig);
  await nodesDB.createIndex("typeIndex", nodeTypeIndexConfig);

  await mediasDB.createIndex("lastUseIndex", lastUseMediaIndexConfig);
  await mediasDB.createIndex("isSavedIndex", isSavedMediaIndexConfig);
  await mediasDB.createIndex("isVideoIndex", isVideoMediaIndexConfig);

  await messagesDB.createIndex("isSavedIndex", isSavedMessageIndexConfig);
  await messagesDB.createIndex("isSnipIndex", isSnipMessageIndexConfig);
  await messagesDB.createIndex("rootIndex", rootMessageIndexConfig);

  await paymentsDB.createIndex("timestampIndex", paymentTimestampIndexConfig);

  await reactionsDB.createIndex(
      "messageRefIndex", reactionMessageRefIndexConfig);
}

Future<T?> fetch<T extends Locals>(
  ComposedID? id, {
  bool doMerge = false,
  ComposedID? tempID,
}) async {
  Future<T?> fetchNode() async {
    if (id == null) return null;
    final ss = await id.userRef.get();
    if (!ss.exists) return null;
    final node = Down4Node.fromJson(ss.value as Map<String, String?>)..cache();
    if (doMerge) node.merge();
    // print("==== RETRIVED $T ID =${id.value} FROM FETCH");
    return node as T;

    // final snapshot = await _firestore
    //     .collection("Nodes")
    //     .doc(id)
    //     .get(const firestore.GetOptions(source: firestore.Source.server));
    // if (!snapshot.exists) return null;
    // final node = Down4Node.fromJson(snapshot.data()!.cast());
    // if (doMerge) {
    //   print("MERGING NODE ID=$id");
    //   await node.merge();
    // }
    // print("===RETRIEVED NODE ID=$id FROM FETCH===");
    // return node as T;
  }

  // Future<T?> fetchMessage() async {
  //   final snapshot = await _realtime.child("Messages").child(id).get();
  //   if (!snapshot.exists) return null;
  //   final json = Map<String, Object?>.from(snapshot.value as Map);
  //   if (json["root"] == g.self.id) json["root"] = json["senderID"];
  //   final message = fromJson<T>(json);
  //   if (doMerge) {
  //     print("MERGING MESSAGE ID: $id");
  //     await message.merge();
  //   }
  //   // print("===RETRIEVED MESSAGE ID=$id FROM FETCH===");
  //   return message;
  // }

  Future<Down4Media?> fetchMedia() async {
    if (id == null && tempID == null) return null;
    final fromNodes = tempID == null;
    print(
        "FETCHING MEDIA ID = ${tempID?.value ?? id?.value} FROM NODES = $fromNodes");
    final ref = fromNodes ? id!.staticStoreRef : tempID.tempStoreRef;
    try {
      final futureMedia = ref.getMetadata();
      // for now seems, good to only get the data if we local merge
      // no need for another parameter
      final rawData = doMerge ? (await ref.getData()) : null;

      // will throw if no metadata, so we can use !
      final mediaJson = (await futureMedia).customMetadata!;
      final media = Down4Media.fromJson(mediaJson)..cache();

      if (doMerge) {
        media.merge();
        if (rawData != null) await media.write(rawData);
      }
      return media;
    } catch (e) {
      print("Error downloading media id: $id from storage, err: $e");
      return null;
    }
  }

  switch (T) {
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
      final data = tempID?.tempStoreRef.getData().toString();
      final json = data != null ? jsonDecode(data) : null;
      if (json != null) return Down4Payment.fromJson(json) as Future<T>;
      return null;
  }

  throw 'Unsupported type for fetching $T';
}

Database gdb<T extends Locals>() {
  switch (T) {
    case Reaction:
      return reactionsDB;
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

Future<T?> local<T extends Locals>(Down4ID id) async {
  final doc = await gdb<T>().document(id.value);
  if (doc == null) return null;
  final element = fromJson<T>(doc.toPlainMap().cast());
  // print("===RETRIEVED $T WITH ID=$id FROM LOCAL===");
  return element;
}

T? cache<T extends Locals>(Down4ID? id) {
  final element = id == null ? null : _globalCache[id] as T?;
  if (element != null) {
    // print("===RETRIEVED $T WITH ID=$id FROM CACHE===");
    return element;
  }
  return null;
}

Future<T?> global<T extends Locals>(
  Down4ID? id, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  ComposedID? tempID,
}) async {
  // if (T is FireMedia && id != null) {
  //   if (mediaInfo?.withData == true) {
  //     final localMedia = cache<FireMedia>(id) ?? (await local<FireMedia>(id));
  //     final
  //   }
  // }

  if (id == null) return null;
  final cached = cache<T>(id);
  if (cached != null) {
    print("RETRIEVED $T ID: $id FROM CACHE");
    return cached;
  }
  final localed = await local<T>(id);
  if (localed != null) {
    print("RETRIEVED $T ID: $id FROM LOCAL");
    return doCache ? _globalCache[id] = localed : localed;
  }
  if (!doFetch) return null;
  final fetched =
      await fetch<T>(id as ComposedID, doMerge: doMergeIfFetch, tempID: tempID);
  if (fetched != null) {
    print("RETRIEVED $T ID: $id FROM FETCH");
    return doCache ? _globalCache[id] = fetched : fetched;
  }
  return null;
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

  throw 'Cannot create FireObject from json for this type: $T';
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
    final json = e.toPlainMap()["m"] as Map<String, Object?>;
    return Down4Message.fromJson(json) as Chat;
  }).toList();
}

// Future<List<User>> hiddenUsers() async {
//   const raw = """
//         SELECT * FROM _ AS n
//         WHERE n.type = 'user' AND n.isFriend = 'false'
//         """;
//
//   final q = await AsyncQuery.fromN1ql(nodesDB, raw);
//   final r = await q.execute();
//   final e = await r.allResults();
//   final trulyHidden = <User>[];
//   final users = e.map((e) {
//     final json = e.toPlainMap()["n"] as Map<String, Object?>;
//     return fromJson<User>(json);
//   }).toList();
//
//   for (final u in users) {
//
//   }
//
//   return trulyHidden;
// }

Future<List<PersonN>> searchLocalsByUnique(Iterable<String> uniques) async {
  final raw = """
    SELECT * FROM _ as n
    WHERE n.unique IN ${uniques.map((e) => "'$e'").toString()} 
  """;

  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final e = await q.execute();
  final r = await e.allResults();

  return r.map((e) {
    final json = e.toPlainMap()["n"] as Map<String, String?>;
    return fromJson<PersonN>(json);
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
  final e1 = q1.execute();
  final e2 = q2.execute();

  return (await (await e1).allResults())
      .followedBy(await (await e2).allResults())
      .map((e) => e.string("mediaID"))
      .whereType<String>()
      .map((e) => ComposedID.fromString(e)!)
      .toSet();
}

Future<void> mediaDeletingRoutine() async {
  final fourDaysAgo = DateTime.now()
      .toUtc()
      .subtract(const Duration(days: 4))
      .millisecondsSinceEpoch;
  final raw = """
      SELECT Meta.id() AS id FROM _
      WHERE TONUMBER(timestamp) < $fourDaysAgo AND isSaved = 'false'
      """;

  final allMediaRefs = await allMediaReferences();

  final q = await AsyncQuery.fromN1ql(mediasDB, raw);
  final e = await q.execute();
  await for (final r in e.asStream()) {
    final pot = r.toPlainMap()["id"] as String;
    if (!allMediaRefs.contains(pot)) {
      await mediasDB.purgeDocumentById(pot);
      final videoPath = "${g.appDirPath}/$pot";
      try {
        File(videoPath).delete();
      } catch (_) {
        continue;
      }
    }
  }
}

Future<List<ChatN>> loadHome() async {
  const raw = """
    SELECT * FROM _ AS n
    WHERE n.type in ('hyperchat', 'group', 'user')
    """;

  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final r = await q.execute();
  return Future.wait((await r.allResults()).map((e) async {
    final nodeJson = e.toPlainMap()["n"] as Map<String, String?>;
    print("Loading home node id =${nodeJson["id"]}");
    return fromJson<ChatN>(nodeJson)..cache();
  }).toList());
}

Future<List<ConnectN>> loadConnectionNodes() async {
  const raw = """
    SELECT * FROM _ as n
    WHERE n.isConnected = 'true'
    """;

  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final r = await q.execute();
  return Future.wait((await r.allResults()).map((e) async {
    final nodeJson = e.toPlainMap()["n"] as Map<String, String?>;
    print("Loading home node id =${nodeJson["id"]}");
    return fromJson<ConnectN>(nodeJson)..cache();
  }).toList());
}

Future<List<Down4Node>> loadAllNodes() async {
  const raw = "SELECT * FROM _ as n";
  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final r = await q.execute();
  return Future.wait((await r.allResults()).map((e) async {
    final nodeJson = e.toPlainMap()["n"] as Map<String, String?>;
    print("Loading home node id =${nodeJson["id"]}");
    return fromJson<Down4Node>(nodeJson)..cache();
  }).toList());
}

Stream<Down4MediaMetadata> savedMedia(bool images) async* {
  final isVideo = images ? "'false'" : "'true'";
  final raw = """
        SELECT * FROM _ AS im
        WHERE im.isSaved = 'true' AND im.isVideo = $isVideo
        ORDER BY im.lastUse DESC
        """;
  final query = await AsyncQuery.fromN1ql(mediasDB, raw);
  final results = await query.execute();
  await for (final r in results.asStream()) {
    print("returning an image!");
    final json = r.toPlainMap()["im"] as Map<String, String?>;
    print("image ID=${json['id']}");
    yield Down4MediaMetadata.fromJson(json);
  }
}

Future<AsyncListenStream<QueryChange<ResultSet>>> savedMediaIDs({
  required bool isVideo,
}) async {
  final raw = """
        SELECT META().id FROM _
        WHERE isSaved = 'true' AND isVideo = '$isVideo'
        ORDER BY lastUse DESC
        """;
  print("RAW Q = $raw");

  final query = await AsyncQuery.fromN1ql(mediasDB, raw);
  return query.changes();
}

// Stream<ID> savedMediaIDs(bool images) async* {
//   final isVideo = images ? "'false'" : "'true'";
//   final raw = """
//         SELECT META().id FROM _ AS id
//         WHERE im.isSaved = 'true' AND im.isVideo = $isVideo
//         ORDER BY im.lastUse DESC
//         """;
//   final query = await AsyncQuery.fromN1ql(mediasDB, raw);
//   final results = await query.execute();
//   await for (final r in results.asStream()) {
//     // print("returning an image!");
//     yield r.string("id")!;
//     // final json = r.toPlainMap()["im/id"]["id"] as Map<String, Object?>;
//     // print("image ID=${json['id']}");
//     // yield FireMedia.fromJson(json);
//   }
// }

extension WalletManager on Wallet {
  Stream<Down4Payment> get payments async* {
    const raw = "SELECT * FROM _ AS p ORDER BY p.ts DESC";
    final q = await AsyncQuery.fromN1ql(paymentsDB, raw);
    final r = await q.execute();
    await for (final p in r.asStream()) {
      yield Down4Payment.fromJson(p.toPlainMap()["p"] as Map<String, String?>);
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
      yield Down4Payment.fromJson(p.toPlainMap()["p"] as Map<String, String?>);
    }
  }

  Stream<Down4TXOUT> get utxos async* {
    const raw = "SELECT * FROM _ AS u";
    final q = await AsyncQuery.fromN1ql(utxosDB, raw);
    final r = await q.execute();
    await for (final u in r.asStream()) {
      yield Down4TXOUT.fromJson(u.toPlainMap()["u"] as Map<String, String?>);
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
    await merge({id.value: spent});
  }

  static Future<Wallet?> load() async {
    return local<Wallet>(Down4ID(unique: "wallet"));
  }
}

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
