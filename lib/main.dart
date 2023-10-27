import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';

import 'package:down4/src/data_objects/couch.dart';
import 'package:down4/src/data_objects/_data_utils.dart';
import 'package:down4/src/data_objects/medias.dart';
import 'package:down4/src/data_objects/nodes.dart';
import 'package:down4/src/web_requests.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:camera/camera.dart';

import 'package:firebase_core/firebase_core.dart';

import 'src/login.dart';
import 'src/globals.dart';

// TODO: this is no good actually, can't call g
Future<void> handleTokenChange(String newToken) async {
  print("new token lol: $newToken");
  final res = await refreshTokenRequest(newToken);
  if (res == 200) {
    g.self.updateMessagingToken({g.self.deviceID: newToken});
  }
}

Future<void> showMessageNotification(
  Map<String, String?> data, {
  required ComposedID selfID,
  required sql.Database sdb,
  required String appDir,
  required ComposedID? currentRoot,
}) async {
  final db_ = sdb; //  ?? db;
  final self = selfID; // ?? g.self.id;

  final sc = <Down4ID, Locals>{};
  if (data.isEmpty) return print("data is empty");

  final header = data["h"];
  final body = data["b"];
  final root = data["r"];
  final sdrID = ComposedID.fromString(data["s"]);
  ComposedID? rtID;
  if (root != null && root.isNotEmpty) {
    rtID = idOfRoot(root: root, selfID: self);
  }

  print("rtID: ${rtID?.value}, currentRoot: ${currentRoot?.value}");
  if (rtID != null && currentRoot == rtID) {
    return print("no need to notify");
  }

  PersonN? sender;
  GroupN? group;
  Down4Image? senderImage, groupImage;

  print("### getting the sender");
  sender = await global<PersonN>(sdrID,
      sc: sc, sdb: db_, doFetch: true, doMergeIfFetch: true);

  if (sender != null) {
    print("### getting senderMedia");
    senderImage = await global<Down4Image>(sender.mediaID,
        sc: sc, sdb: db_, doFetch: true, doMergeIfFetch: true);
  }

  if (rtID != null) {
    final rootNode = await global<ChatN>(rtID,
        sc: sc, sdb: db_, doFetch: true, doMergeIfFetch: true);
    if (rootNode is GroupN) {
      group = rootNode;
      print("### getting groupMedia");
      groupImage = await global<Down4Image>(group.mediaID,
          sc: sc, sdb: db_, doFetch: true, doMergeIfFetch: true);
    }
  }

  final senderImageProfilePath = await senderImage?.profilePath(appDir);
  final groupImageProfilePath = await groupImage?.profilePath(appDir);

  print("PATH FOR IMAGE: ${groupImageProfilePath ?? senderImageProfilePath}");

  print("showing notification!");
  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: Random().nextInt(200000),
      channelKey: 'def',
      groupKey: rtID?.value ?? sdrID?.value,
      title: header,
      body: body,
      summary: '',
      roundedLargeIcon: true,
      largeIcon: "file://$senderImageProfilePath",
      bigPicture: groupImageProfilePath != null
          ? "file://$groupImageProfilePath"
          : null,
      icon: 'resource://drawable/ic_stat_down4_white',
      notificationLayout: group != null
          ? NotificationLayout.MessagingGroup
          : NotificationLayout.Messaging,
    ),
  );
  print("showed notification!");
}

void initSqlite() async {
  print("initing sqlite");

  final appdir = await getApplicationDocumentsDirectory();
  final appDirPath = appdir.path;
  final dbPath = "$appDirPath${Platform.pathSeparator}down4.db";
  db = sql.sqlite3.open(dbPath);

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

  db.execute("PRAGMA journal_mode=WAL;");
  print("done initing sqlite");
}

Future<void> fcmHandler(FcmSilentData silentData) async {
  // return print("notifs disabled for debugging payments");
  print("NEW SILENT DATA BABY");
  final data = silentData.data!;

  final appdir = await getApplicationDocumentsDirectory();
  final appDirPath = appdir.path;
  final db_ = sql.sqlite3.open("$appDirPath${Platform.pathSeparator}down4.db");
  db_.execute("PRAGMA journal_mode=WAL;");

  final r = db_.select("SELECT id FROM nodes WHERE type = 'self'");
  final r2 =
      db_.select("SELECT currentPage FROM personals WHERE id = 'single'");

  print("got ${r.length} self");
  final id = ComposedID.fromString(r.single["id"])!;
  ComposedID? rtID;
  final String? currentPage = r2.single["currentPage"];
  if ((currentPage?.length ?? 0) > 5) {
    final (e1, e2) = (currentPage?.substring(0, 4), currentPage?.substring(5));
    if (e1 == "chat") rtID = ComposedID.fromString(e2);
  }

  if (currentPage != null) {
    print("""
      \t APP IS LIVE, WAITING 2 SECONDS TO SHOW NOTIFICATION
      \t TO AVOID DOUBLE FETCHING OF DATA
      """);
    await Future.delayed(const Duration(seconds: 3));
  }

  print("should be showing notification");
  await showMessageNotification(data,
      selfID: id, sdb: db_, appDir: appDirPath, currentRoot: rtID);
  print("should have shown notification");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("\n\n ** SUCCES INITIALIZING FIREBASE APP ** \n\n");
  } catch (e) {
    print("\n\n xx ERROR INITIALIZING FIREBASE APP xx \n\n");
    print(e);
  }
  // load application directory folder
  {
    await g.loadAppDirPaths();
  }

  initSqlite();

  {
    // inits notifications settings
    AwesomeNotifications().initialize(
        'resource://drawable/ic_state_down4_white',
        [
          NotificationChannel(
              icon: 'resource://drawable/ic_stat_down4_white',
              channelKey: 'def',
              channelName: 'default',
              channelDescription: 'default channel'),
        ],
        debug: true);
  }

  {
    // this handles firebase message notifications
    AwesomeNotificationsFcm().initialize(
        onFcmTokenHandle: handleTokenChange,
        onFcmSilentDataHandle: fcmHandler,
        debug: true);
  }

  // loading some asset in memory, not having those assets in memory cause
  // stutter in transitions for example, loading image from assets is
  // actually slow
  {
    final d1 = await rootBundle.load("assets/images/Dollar_Sign_1.png");
    final d2 = await rootBundle.load("assets/images/Dollar_Sign_2.png");
    final d3 = await rootBundle.load("assets/images/Dollar_Sign_3.png");
    final ph = await rootBundle.load("assets/images/place_holder.png");

    g.d1 = Image.memory(d1.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.d2 = Image.memory(d2.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.d3 = Image.memory(d3.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.ph = Image.memory(ph.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
  }

  // initializing cameras
  {
    try {
      g.cameras = await availableCameras();
    } catch (err) {
      print("Available cameras error $err");
    }
  }

  // INIT THE THEME
  {
    g.loadTheme(await CurrentTheme.currentTheme);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: g.theme.topStatusIconBrightness,
        systemNavigationBarColor: g.theme.bottomNavigationBarColor,
        systemNavigationBarIconBrightness:
            g.theme.bottonNavigationIconBrightness,
      ),
    );
  }

  // debugRepaintRainbowEnabled = true;
  runApp(const MaterialApp(home: Material(child: Down4())));
}
