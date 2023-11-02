import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '_data_utils.dart';

const _nShards = 2;

String pushKey() =>
    Down4Server().shards[Region.america]![0].realtimeDB.ref().push().key!;

int calculateShard(String unique) =>
    unique.codeUnits.fold(0, (p, e) => p + e) % _nShards;

class Down4ServerShard {
  FirebaseDatabase realtimeDB;
  FirebaseStorage staticStore;
  FirebaseStorage temporaryStore;
  Down4ServerShard({
    required this.realtimeDB,
    required this.staticStore,
    required this.temporaryStore,
  });
}

final regex = RegExp(r'^[a-zA-Z_]+\d*$');
Future<bool> isUsernameValid(String username) async {
  if (username.length < 3) {
    print("username=$username is too small");
    return false;
  }
  if (username.length > 32) {
    print("username=$username is too big");
    return false;
  }
  final bool regMatch = regex.hasMatch(username);
  if (!regMatch) {
    print("username=$username does not fit regex rules");
    return false;
  }

  final bool exists = await Down4Server()
      .masterFS
      .collection("users")
      .doc(username)
      .get()
      .then((value) => value.exists);

  if (exists) {
    print("username=$username already exists");
    return false;
  }

  return true;
}

class Down4Cache {
  static final Down4Cache _instance = Down4Cache._();
  Down4Cache._();
  factory Down4Cache() => _instance;
  final Map<Down4ID, Locals> _cch = {};

  void cache(Locals obj, {bool ifAbsent = false}) {
    if (ifAbsent) {
      _cch[obj.id] ??= obj;
    } else {
      _cch[obj.id] = obj;
    }
  }

  Locals? at(Down4ID id) => _cch[id];
  Locals? unCache(Down4ID id) => _cch.remove(id);
}

class Down4Server {
  static final Down4Server _instance = Down4Server._();
  Down4Server._() {
    print("CREATED DOWN4 SERVER");
  }
  factory Down4Server() => _instance;

  // static Down4Server get instance => _instance ??= Down4Server();

  // Down4Server() {
  //   print("CREATED DOWN4 SERVER");
  // }

  final masterFS = FirebaseFirestore.instance;
  final app = Firebase.app();

  // > Server instance are accessed first by region then by index of the shard
  //   that is calculated(once) and saved on any objects that goes onto servers
  //   by calculating once and saving, we can push updates so that new users
  //   will have an index on newer shards possibly, allowing dynamic scaling
  // > User region is calculated on initialization, all objects created by this
  //   user will be in the same regions. Users are the root of all things
  // > There is a masterDB that holds all (usernames:region)
  late final Map<Region, List<Down4ServerShard>> shards = {
    Region.america: [
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL: "https://down4-26ee1-fd90e-us1.firebaseio.com/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us1",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us1-tmp",
        ),
      ),
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL: "https://down4-26ee1-c65d2-us2.firebaseio.com/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us2",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-us2-tmp",
        ),
      ),
    ],
    Region.europe: [
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-30b1c-eu1.europe-west1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu1",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu1-tmp",
        ),
      ),
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-e487b-eu2.europe-west1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu2",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-eu2-tmp",
        ),
      ),
    ],
    Region.asia: [
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-8511f-sea1.asia-southeast1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea1",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea1-tmp",
        ),
      ),
      Down4ServerShard(
        realtimeDB: FirebaseDatabase.instanceFor(
          app: app,
          databaseURL:
              "https://down4-26ee1-d98a8-sea2.asia-southeast1.firebasedatabase.app/",
        ),
        staticStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea2",
        ),
        temporaryStore: FirebaseStorage.instanceFor(
          app: app,
          bucket: "down4-26ee1-sea2-tmp",
        ),
      ),
    ],
  };
}

class Down4Local {
  static final Down4Local _instance = Down4Local._();
  Down4Local._();
  factory Down4Local() => _instance;

  late sql.Database db;
  late String appDirPath, cacheDirPath, dbPath;
  Future<Down4Local> initDb() async {
    appDirPath = (await getApplicationDocumentsDirectory()).path;
    cacheDirPath = (await getApplicationCacheDirectory()).path;
    dbPath = "$appDirPath${Platform.pathSeparator}down4.db";
    db = sql.sqlite3.open(dbPath);
    db.execute("PRAGMA journal_mode=WAL;");
    return _instance;
  }

  String makeMediaPath(Down4ID id, {bool cache = false}) {
    return "${cache ? cacheDirPath : appDirPath}${Platform.pathSeparator}${id.unik}";
  }

  void createDbIfNotExists() {
    db.execute("""
    CREATE TABLE IF NOT EXISTS nodes (
      id TEXT NOT NULL PRIMARY KEY,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      connection TEXT NOT NULL,
      unik TEXT NOT NULL,
      messagingTokens TEXT,
      mainDeviceID TEXT,
      treeHash TEXT,
      ownerID TEXT,
      lastName TEXT,
      isPrivate TEXT,
      longitude TEXT,
      latitude TEXT,
      mediaID TEXT,
      children TEXT,
      posts TEXT,
      privates TEXT,
      admins TEXT,
      neuter TEXT,
      members TEXT,
      deviceID TEXT,
      isConnected TEXT,
      activity TEXT
    )
    """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT NOT NULL PRIMARY KEY,
      type TEXT NOT NULL,
      senderID TEXT NOT NULL,
      root TEXT,
      reactions TEXT,
      isSent TEXT,
      isRead TEXT,
      reactionID TEXT,
      forwardedFromID TEXT,
      paymentID TEXT,
      nodes TEXT,
      replies TEXT,
      tips TEXT,
      reactors TEXT,
      txt TEXT,
      timestamp TEXT,
      mediaID TEXT,
      messageID TEXT,
      tempMediaID TEXT,
      tempMediaTS TEXT,
      tempPaymentID TEXT,
      tempPaymentTS TEXT,
      sticks TEXT,
      snipSize TEXT
    )
    """);

    db.execute("""
    CREATE INDEX IF NOT EXISTS root_index
      ON messages (root)
      """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS medias (
      id TEXT NOT NULL PRIMARY KEY,
      ownerID TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      mime TEXT NOT NULL,
      isReversed TEXT NOT NULL,
      isSquared TEXT NOT NULL,
      isEncrypted TEXT NOT NULL,
      width TEXT NOT NULL,
      height TEXT NOT NULL,
      isPaidToView TEXT NOT NULL,
      isPaidToOwn TEXT NOT NULL,
      isLocked TEXT NOT NULL,
      tinyThumbnail TEXT,
      isSaved TEXT NOT NULL,
      lastUse TEXT NOT NULL,
      tempID TEXT,
      tempTS TEXT,
      txt TEXT
    )
    """);

    db.execute("""
    CREATE INDEX IF NOT EXISTS is_saved_index
      ON medias (isSaved, mime)
      """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS payments (
      id TEXT NOT NULL PRIMARY KEY,
      txid TEXT NOT NULL,
      safe TEXT NOT NULL,
      ts TEXT NOT NULL,
      plusMinus TEXT NOT NULL,      
      spender TEXT,
      tempTS TEXT,
      tempID TEXT,
      txt TEXT
    )
    """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS txouts (
      id TEXT NOT NULL PRIMARY KEY,
      txid TEXT NOT NULL,
      secret TEXT NOT NULL,
      outIndex TEXT NOT NULL,
      spent TEXT NOT NULL,
      sats TEXT NOT NULL,
      type TEXT NOT NULL,
      script TEXT NOT NULL,
      receiver TEXT
    )
    """);

    db.execute("DROP TABLE IF EXISTS utxos");

    db.execute("""
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT NOT NULL PRIMARY KEY,
      secret TEXT NOT NULL,
      ins TEXT NOT NULL,
      outs TEXT NOT NULL,
      versionNo TEXT NOT NULL,
      nLockTime TEXT NOT NULL,
      confirmations TEXT NOT NULL,
      maker TEXT
    )
    """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS txins (
      id TEXT NOT NULL PRIMARY KEY,
      utxoTXID TEXT NOT NULL,
      utxoIndex TEXT NOT NULL,
      sequenceNo TEXT NOT NULL,
      scriptSig TEXT NOT NULL,
      satSpent TEXT NOT NULL,
      spender TEXT
    )
    """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS spents (
      id TEXT NOT NULL PRIMARY KEY
    )
    """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS personals (
      id TEXT NOT NULL PRIMARY KEY,
      keys TEXT,
      ix TEXT,
      themeName TEXT,
      rate TEXT,
      lastUpdate TEXT,
      currentPage TEXT
    )
    """);

    db.execute("""
    CREATE TABLE IF NOT EXISTS themes (
    id TEXT NOT NULL PRIMARY KEY,
    themeName TEXT
    )
    """);

    db.execute("""
    INSERT OR IGNORE INTO personals (id)
    VALUES ('single')
    """);
  }
}
