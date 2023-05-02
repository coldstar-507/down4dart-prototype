import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart' as realtime;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'globals.dart';

import '_dart_utils.dart';
import 'bsv/types.dart';
import 'bsv/wallet.dart';

import 'package:cbl/cbl.dart';
import 'data_objects.dart';

final _realtime = realtime.FirebaseDatabase.instance.ref();
final _firestore = firestore.FirebaseFirestore.instance;
final _nodeStore = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");
final _messageStore =
    FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");

late AsyncDatabase nodesDB,
    personalDB,
    mediasDB,
    messagesDB,
    utxosDB,
    paymentsDB,
    billsDB;

Future<List<T>> globall<T extends FireObject>(
  Iterable<ID>? ids, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  Pair<bool, ID?>? mediaInfo,
}) async {
  if (ids == null) return [];
  final reqs = await Future.wait(ids
      .map((e) => global<T>(e,
          doCache: doCache,
          doFetch: doFetch,
          doMergeIfFetch: doMergeIfFetch,
          mediaInfo: mediaInfo))
      .toList());
  return reqs.whereType<T>().toList();
}

Map<ID, FireObject> _globalCache = {};

void gCache(FireObject obj) => _globalCache[obj.id] = obj;

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

  await nodesDB.createIndex("hiddenIndex", isHiddenNodeIndexConfig);
  await nodesDB.createIndex("typeIndex", nodeTypeIndexConfig);

  await mediasDB.createIndex("lastUseIndex", lastUseMediaIndexConfig);
  await mediasDB.createIndex("isSavedIndex", isSavedMediaIndexConfig);
  await mediasDB.createIndex("isVideoIndex", isVideoMediaIndexConfig);

  await messagesDB.createIndex("isSavedIndex", isSavedMessageIndexConfig);
  await messagesDB.createIndex("isSnipIndex", isSnipMessageIndexConfig);
  await messagesDB.createIndex("rootIndex", rootMessageIndexConfig);

  await paymentsDB.createIndex("timestampIndex", paymentTimestampIndexConfig);
}

Future<T?> fetch<T extends FireObject>(
  ID id, {
  bool doMerge = false,
  Pair<bool, ID?>? mediaInfo, // fireMedia specific
  // bool doHide = false, // fireNode specific
}) async {
  Future<T?> fetchNode() async {
    final snapshot = await _firestore
        .collection("Nodes")
        .doc(id)
        .get(const firestore.GetOptions(source: firestore.Source.server));
    if (!snapshot.exists) return null;
    final node = FireNode.fromJson(snapshot.data()!.cast());
    if (doMerge) {
      print("MERGING NODE ID=$id");
      await node.merge();
    }
    print("===RETRIEVED NODE ID=$id FROM FETCH===");
    return node as T;
  }

  Future<FireMessage?> fetchMessage() async {
    final snapshot = await _realtime.child("Messages").child(id).get();
    if (!snapshot.exists) return null;
    final json = Map<String, Object?>.from(snapshot.value as Map);
    if (json["root"] == g.self.id) json["root"] = json["senderID"];
    final message = FireMessage.fromJson(json);
    if (doMerge) {
      print("MERGING MESSAGE ID: $id");
      message.merge();
    }
    print("===RETRIEVED MESSAGE ID=$id FROM FETCH===");
    return message;
  }

  Future<FireMedia?> fetchMedia() async {
    final onlineID = mediaInfo!.second;
    final withData = mediaInfo.first;
    final fromNodes = onlineID == null;
    final ref = fromNodes ? _nodeStore.ref(id) : _messageStore.ref(onlineID);
    try {
      final futureFullMetadata = ref.getMetadata();
      final mediaData = withData ? await ref.getData() : null;
      // will throw if no metadata, so we can use !
      final mediaJson = (await futureFullMetadata).customMetadata!;
      final media = FireMedia.fromJson(mediaJson);
      Uint8List? videoThumbnail;
      final bool isVideo = media.isVideo;
      if (isVideo) {
        final url = await ref.getDownloadURL();
        media.cachedImage = videoThumbnail = await VideoThumbnail.thumbnailData(
          video: url,
          quality: 50,
        );
      } else {
        media.cachedImage = mediaData;
      }
      if (doMerge) {
        await media.merge();
        print("MERGING MEDIA ID: $id");
        if (withData && mediaData != null) {
          if (isVideo) {
            await File(media.videoPath).writeAsBytes(mediaData);
          }
          await media.write(imageData: isVideo ? videoThumbnail! : mediaData);
        }
      }
      print("===RETRIEVED MEDIA ID=$id FROM FETCH===");
      return media;
    } catch (e) {
      print("Error downloading media id: $id from storage, err: $e");
      return null;
    }
  }

  switch (T) {
    case FireNode:
      return fetchNode();
    case Branchable:
      return fetchNode();
    case Chatable:
      return fetchNode();
    case Groupable:
      return fetchNode();
    case Personable:
      return fetchNode();
    case Editable:
      return fetchNode();
    case User:
      return fetchNode();
    case Self:
      return fetchNode();
    case Group:
      return fetchNode();
    case Hyperchat:
      return fetchNode();
    case FireMedia:
      return fetchMedia() as Future<T?>;
    case FireMessage:
      return fetchMessage() as Future<T?>;
    case Down4Payment:
      return downloadPayment(id) as Future<T?>;
  }

  throw 'Unsupported type for fetching $T';
}

Database gdb<T extends FireObject>() {
  switch (T) {
    case FireNode:
      return nodesDB;
    case Branchable:
      return nodesDB;
    case Chatable:
      return nodesDB;
    case Groupable:
      return nodesDB;
    case Personable:
      return nodesDB;
    case Editable:
      return nodesDB;
    case User:
      return nodesDB;
    case Self:
      return nodesDB;
    case Group:
      return nodesDB;
    case Hyperchat:
      return nodesDB;
    case FireMedia:
      return mediasDB;
    case FireMessage:
      return messagesDB;
    case Down4TXOUT:
      return utxosDB;
    case Down4Payment:
      return paymentsDB;
    case Token:
      return personalDB;
    case ExchangeRate:
      return personalDB;
    case Wallet:
      return personalDB;
  }

  throw 'No db exists for type: $T';
}

Future<T?> local<T extends FireObject>(ID id) async {
  final doc = await gdb<T>().document(id);
  if (doc == null) return null;
  final element = fromJson<T>(doc.toPlainMap().cast());
  print("===RETRIEVED $T WITH ID=$id FROM LOCAL===");
  return element;
}

T? cache<T extends FireObject>(ID? id) {
  final element = id == null ? null : _globalCache[id] as T?;
  if (element != null) {
    print("===RETRIEVED $T WITH ID=$id FROM CACHE===");
    return element;
  }
  return null;
}

Future<T?> global<T extends FireObject>(
  ID? id, {
  bool doCache = true,
  bool doFetch = false,
  bool doMergeIfFetch = false,
  Pair<bool, ID?>? mediaInfo,
}) async {
  if (id == null) return null;
  final cached = cache<T>(id);
  if (cached != null) return cached;
  final localed = await local<T>(id);
  if (localed != null) return doCache ? _globalCache[id] = localed : localed;
  if (!doFetch) return null;
  final fetched =
      await fetch<T>(id, doMerge: doMergeIfFetch, mediaInfo: mediaInfo);
  if (fetched != null) return doCache ? _globalCache[id] = fetched : fetched;
  return null;
}

T fromJson<T extends FireObject>(Map<String, Object?> json) {
  switch (T) {
    case FireNode:
      return FireNode.fromJson(json) as T;
    case Branchable:
      return FireNode.fromJson(json) as T;
    case Chatable:
      return FireNode.fromJson(json) as T;
    case Groupable:
      return FireNode.fromJson(json) as T;
    case Personable:
      return FireNode.fromJson(json) as T;
    case Editable:
      return FireNode.fromJson(json) as T;
    case User:
      return FireNode.fromJson(json) as T;
    case Self:
      return FireNode.fromJson(json) as T;
    case Group:
      return FireNode.fromJson(json) as T;
    case Hyperchat:
      return FireNode.fromJson(json) as T;
    case FireMedia:
      return FireMedia.fromJson(json) as T;
    case FireMessage:
      return FireMessage.fromJson(json) as T;
    case Down4TXOUT:
      return Down4TXOUT.fromJson(json) as T;
    case Down4Payment:
      return Down4Payment.fromJson(json) as T;
    case Token:
      return Token.fromJson(json) as T;
    case ExchangeRate:
      return ExchangeRate.fromJson(json) as T;
    case Wallet:
      return Wallet.fromJson(json) as T;
  }

  throw 'Cannot create FireObject from json for this type: $T';
}

Future<List<FireMessage>> unsentMessages() async {
  const raw = """
        SELECT * FROM _ AS m
        WHERE m.isSent = 'false' AND m.isSnip = 'false'
        """;
  final q = await AsyncQuery.fromN1ql(messagesDB, raw);
  final e = await q.execute();
  final r = await e.allResults();

  return r.map((e) {
    final json = e.toPlainMap()["m"] as Map<String, Object?>;
    return FireMessage.fromJson(json);
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

Future<Set<ID>> allGroupIDs() async {
  const rawq = "SELECT group FROM _ WHERE nodes.type in ('hyperchat', 'group')";
  final q = await AsyncQuery.fromN1ql(nodesDB, rawq);
  final e = await q.execute();
  final r = await e.allResults();
  return r.fold<Set<ID>>(Set<ID>.identity(), (value, element) {
    final sGroup = element.toPlainMap()["group"] as String;
    return value..addAll(sGroup.split(" "));
  });
}

Future<Set<ID>> allMediaReferences() async {
  const nq = "SELECT mediaID FROM _";
  final q1 = await AsyncQuery.fromN1ql(messagesDB, nq);
  final q2 = await AsyncQuery.fromN1ql(nodesDB, nq);
  final e1 = q1.execute();
  final e2 = q2.execute();

  return (await (await e1).allResults())
      .followedBy(await (await e2).allResults())
      .map((e) => e.string("mediaID"))
      .whereType<String>()
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

Future<List<Chatable>> loadHome() async {
  const raw = """
    SELECT * FROM _ AS n
    WHERE n.type in ('hyperchat', 'group', 'user')
    """;

  final q = await AsyncQuery.fromN1ql(nodesDB, raw);
  final r = await q.execute();
  return Future.wait((await r.allResults()).map((e) async {
    final nodeJson = e.toPlainMap()["n"] as Map<String, Object?>;
    print("Loading home node id =${nodeJson["id"]}");
    return fromJson<Chatable>(nodeJson)..cache();
  }).toList());
}

Stream<FireMedia> savedMedia(bool images) async* {
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
    final json = r.toPlainMap()["im"] as Map<String, Object?>;
    print("image ID=${json['id']}");
    yield FireMedia.fromJson(json);
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
      yield Down4Payment.fromJson(p.toPlainMap()["p"]);
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
      yield Down4Payment.fromJson(p.toPlainMap()["p"]);
    }
  }

  Stream<Down4TXOUT> get utxos async* {
    const raw = "SELECT * FROM _ AS u";
    final q = await AsyncQuery.fromN1ql(utxosDB, raw);
    final r = await q.execute();
    await for (final u in r.asStream()) {
      yield Down4TXOUT.fromJson(u.toPlainMap()["u"]);
    }
  }

  Future<Down4TXOUT?> getUtxo(ID id) async {
    return local<Down4TXOUT>(id);
  }

  Future<void> removeUtxo(ID id) async {
    await gdb<Down4TXOUT>().purgeDocumentById(id);
  }

  Future<Down4Payment?> getPayment(ID id) async {
    return local<Down4Payment>(id);
  }

  Future<void> removePayment(ID id) async {
    await gdb<Down4Payment>().purgeDocumentById(id);
  }

  Future<void> setPayment(Down4Payment payment) async {
    await payment.merge();
  }

  Future<void> setUtxo(Down4TXOUT utxo) async {
    await utxo.merge();
  }

  Future<bool> isSpent(ID utxoID) async {
    return (await dbb.document(id))?.boolean(utxoID) ?? false;
  }

  Future<void> setSpent(ID id, bool spent) async {
    await merge({id: spent});
  }

  static Future<Wallet?> load() async {
    return local<Wallet>("wallet");
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
