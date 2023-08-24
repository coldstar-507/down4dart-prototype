import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl/cbl.dart';

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

// import 'package:timezone/timezone.dart' as tz;
// import 'package:push/push.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'src/login.dart';
import 'src/globals.dart';

// final FlutterLocalNotificationsPlugin _mainNotificationPlugin =
//     FlutterLocalNotificationsPlugin();

// Future<void> _initLocalNotifications(FlutterLocalNotificationsPlugin p) async {
//   const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');
//   const InitializationSettings initializationSettings =
//       InitializationSettings(android: initializationSettingsAndroid);
//   await p.initialize(initializationSettings);
// }

// @pragma("vm:entry-point")
// Future<void> showNotification(RemoteMessage rmt,
//     {FlutterLocalNotificationsPlugin? np}) async {

//   print("getting proper plugin");
//   FlutterLocalNotificationsPlugin p = np ?? _mainNotificationPlugin;
//   print("notif plugin is initialized: ${p}");

//   print("init android details");
//   const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//       'channel_id', 'Channel Name',
//       channelDescription: 'Channel Description',
//       priority: Priority.high,
//       importance: Importance.max);

//   print("init platform details");
//   const NotificationDetails platformDetails =
//       NotificationDetails(android: androidDetails);

//   final title = rmt.data!["h"] as String;
//   final body = rmt.data!["b"] as String;

//   print("title: $title, body: $body");

//   // tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 4 ));
//   // _flutterLocalNotificationsPlugin.zonedSchedule(-1, title, body, scheduledDate, platformDetails, uiLocalNotificationDateInterpretation: ${6:uiLocalNotificationDateInterpretation});

//   // if (np == null) {
//     print("showing the notification");
//     await p.show(-1, title, body, platformDetails); // platformDetails);
//   // } else {
//   //   print("scheduled notif for 4 secs");
//   //   tz.TZDateTime scheduledDate =
//   //       tz.TZDateTime.now(tz.local).add(const Duration(seconds: 4));
//   //   p.zonedSchedule(-1, title, body, scheduledDate, platformDetails,
//   //       uiLocalNotificationDateInterpretation:
//   //           UILocalNotificationDateInterpretation.absoluteTime);
//   // }

//   return print("done showing the notification");
//   // payload:  'notification_payload');
// }

// // Simulating the scenario where the app receives a message
// // and triggers a function to display a notification
// // Future<void> receiveMessageAndDisplayNotification(
// //     Map<String, dynamic> message) async {
// //   final notificationTitle = message['title'];
// //   final notificationBody = message['body'];

// //   await _showNotification(notificationTitle, notificationBody);
// // }

// ///////////////////////////////////

// // const AndroidNotificationChannel globalChannel = AndroidNotificationChannel(
// //   'Down4AndroidNotificationChannel',
// //   'Default Importance Notifications for Down4AndroidNotificationChannel',
// //   importance: Importance.defaultImportance,
// // );

// // final FlutterLocalNotificationsPlugin globalPlugin =
// //     FlutterLocalNotificationsPlugin();

// /////////////////

// Future<void> backgroundMessageHandler(RemoteMessage rmt) async {
//   print("\n####### BACKGROUND MESSAGE HANDLER #######\n");

//   // since this is running in it's own isolate, we must do similar
//   // initialization we are doing in main
//   // try {
//   // init firebase

//   print("ensuring initialization");
//   WidgetsFlutterBinding.ensureInitialized();
//   print("initialization has been ensured!");

//   {
//     print("### initializing firebase app");
//     await Firebase.initializeApp();
//     print("### initialized firebase app");
//   }

//   final FlutterLocalNotificationsPlugin bgNotificationPlugin =
//       FlutterLocalNotificationsPlugin();

//   await _initLocalNotifications(bgNotificationPlugin);

//   // _bgNotificationPlugin.show(${1:id}, ${2:title}, ${3:body}, ${4:notificationDetails});

//   // initNotificationPlugin(${1:plugin}, ${2:channel});

//   print("\n\nSHOW THAT FUCKING NOTIFICATION MY NIGGA\n\n");
//   return showNotification(rmt, np: bgNotificationPlugin);

//   // init notification channels
//   // print("### making local notif channel");
//   // const AndroidNotificationChannel localChannel = AndroidNotificationChannel(
//   //     'Down4AndroidNotificationChannel',
//   //     'Default Importance Notifications for Down4AndroidNotificationChannel',
//   //     importance: Importance.defaultImportance);

//   // print("### making local plugin");
//   // final FlutterLocalNotificationsPlugin localPlugin =
//   //     FlutterLocalNotificationsPlugin();

//   // print("### init notif plugin");
//   // await initNotificationPlugin(localPlugin, localChannel);

//   // init the databases // this might break idk
//   // seems to work just right tbh
//   // print("### init the dbs");

//   // // await CouchbaseLite.initSecondary(CouchbaseLite.context);
//   // final dbForNodes = await Database.openAsync("nodes");
//   // final dbForMedias = await Database.openAsync("medias");

//   // const getSelf = "SELECT id FROM _ WHERE type = 'self'";
//   // final q = await AsyncQuery.fromN1ql(dbForNodes, getSelf);
//   // final e = await q.execute();
//   // final r = await e.allResults();
//   // if (r.length != 1) throw 'error getting selfID in backgroundMessageHandler';
//   // print(r.first);
//   // final selfID = ComposedID.fromString(r.first.string("id"))!;

//   // print("### showing the notification");
//   // await showMessageNotification(rmt,
//   //     // chan: localChannel,
//   //     // plug: localPlugin,
//   //     selfID: selfID,
//   //     mediaDB: dbForMedias,
//   //     nodeDB: dbForNodes);
//   // } catch (e) {
//   //   print("\n == ERROR HANDLEING BACKGROUND MESSAGE: $e == \n");
//   // }
// }

// // Future<void> myNameIsJeff(Object context, RootIsolateToken rootIsolateToken) async {
// //   print("\n####### BACKGROUND MESSAGE HANDLER #######\n");

// //   BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
// //   // since this is running in it's own isolate, we must do similar
// //   // initialization we are doing in main
// //   // try {
// //   // init firebase
// //   {
// //     print("### initializing firebase app");
// //     await Firebase.initializeApp();
// //     print("### initialized firebase app");
// //   }

// //   // init notification channels
// //   print("### making local notif channel");
// //   const AndroidNotificationChannel localChannel = AndroidNotificationChannel(
// //       'Down4AndroidNotificationChannel',
// //       'Default Importance Notifications for Down4AndroidNotificationChannel',
// //       importance: Importance.defaultImportance);

// //   print("### making local plugin");
// //   final FlutterLocalNotificationsPlugin localPlugin =
// //       FlutterLocalNotificationsPlugin();

// //   print("### init notif plugin");
// //   await initNotificationPlugin(localPlugin, localChannel);

// //   // init the databases // this might break idk
// //   // seems to work just right tbh
// //   print("### init the dbs");

// //   await CouchbaseLite.initSecondary(context);
// //   print("did init lol");
// //   final dbForNodes = await Database.openAsync("nodes");
// //   final dbForMedias = await Database.openAsync("medias");

// //   const getSelf = "SELECT id FROM _ AS id WHERE type = 'self'";
// //   final q = await AsyncQuery.fromN1ql(dbForNodes, getSelf);
// //   final e = await q.execute();
// //   final r = await e.allResults();
// //   if (r.length != 1) throw 'error getting selfID in backgroundMessageHandler';
// //   final selfID = ComposedID.fromString(r.first.string("id"))!;

// //   print("lol but not funny, it works, selfID: ${selfID.value}");
// //   // } catch (e) {
// //   //    print("\n == ERROR HANDLEING BACKGROUND MESSAGE: $e == \n");
// //   // }
// // }

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
  ComposedID? selfID,
  Database? mediaDB,
  Database? nodeDB,
  ComposedID? currentRoot,
}) async {
  final nodesDatabase = nodeDB ?? nodesDB;
  final mediasDatabase = mediaDB ?? mediasDB;
  final self = selfID ?? g.self.id;

  final sc = <Down4ID, Locals>{};
  if (data.isEmpty) return;

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
      sc: sc, sdb: nodesDatabase, doFetch: true, doMergeIfFetch: true);

  if (sender != null) {
    print("### getting senderMedia");
    senderImage = await global<Down4Image>(sender.mediaID,
        sc: sc, sdb: mediasDatabase, doFetch: true, doMergeIfFetch: true);
  }

  if (rtID != null) {
    final rootNode = await global<ChatN>(rtID,
        sc: sc, sdb: nodesDatabase, doFetch: true, doMergeIfFetch: true);
    if (rootNode is GroupN) {
      group = rootNode;
      print("### getting groupMedia");
      groupImage = await global<Down4Image>(group.mediaID,
          sc: sc, sdb: mediasDatabase, doFetch: true, doMergeIfFetch: true);
    }
  }

  final senderImageProfilePath = await senderImage?.profilePath;
  final groupImageProfilePath = await groupImage?.profilePath;

  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 1,
      channelKey: 'def',
      title: header,
      body: body,
      largeIcon: groupImageProfilePath ?? senderImageProfilePath,
      icon: 'resource://drawable/ic_stat_down4_white',
      notificationLayout: group != null
          ? NotificationLayout.MessagingGroup
          : NotificationLayout.Messaging,
    ),
  );
}

late Object cblCtx;

void initSqlite() async {
  print("initing sqlite");

  final appdir = await getApplicationDocumentsDirectory();
  final appDirPath = appdir.path;
  final dbPath = "$appDirPath${Platform.pathSeparator}down4.db";

  g.initdb(sql.sqlite3.open(dbPath));
  g.db.execute("""
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
      group TEXT,
      deviceID TEXT,
      isConnected TEXT,
      activity TEXT
    )
    """);



  g.db.execute("""
    INSERT OR REPLACE INTO nodes (id, type, name, connection)
    VALUES ('jeff_id', 'user', 'jeff', 'trololol')
    """);

  print("done initing sqlite");
}

Future<void> fcmHandler(FcmSilentData silentData) async {
  print("NEW SILENT DATA BABY");
  final data = silentData.data!;
  final body = data['b'];
  final header = data['h'];

  final appdir = await getApplicationDocumentsDirectory();
  final appDirPath = appdir.path;
  final db = sql.sqlite3.open("$appDirPath${Platform.pathSeparator}down4.db");

  final r = db.select("SELECT name, type FROM nodes WHERE id = 'jeff_id'");

  final sql.Row d = r.single;
  print("jeff name: ${d['name']}, jeff type: ${d['type']}");

  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 1,
      channelKey: 'def',
      title: header,
      body: body,
      // largeIcon: groupImageProfilePath ?? senderImageProfilePath,
      icon: 'resource://drawable/ic_stat_down4_white',
      // notificationLayout: group != null
      //     ? NotificationLayout.MessagingGroup
      //     : NotificationLayout.Messaging,
    ),
  );
  
  // print("Trying to init secondary couchbase bro");
  // await CouchbaseLite.initSecondary(cblCtx);
  // print("should have succeeded init the couchbasebro, init dbs now...");
  // final dbForNodes = await Database.openAsync("nodes");
  // final dbForMedias = await Database.openAsync("medias");
  // print("dbs are init, woohoo!");

  // const getSelf = "SELECT id FROM _ WHERE type = 'self'";
  // final q = await AsyncQuery.fromN1ql(dbForNodes, getSelf);
  // final e = await q.execute();
  // final r = await e.allResults();
  // if (r.length != 1) throw 'error getting selfID in backgroundMessageHandler';
  // final selfID = ComposedID.fromString(r.first.string("id"))!;

  // await showMessageNotification(data,
  //     selfID: selfID, mediaDB: dbForMedias, nodeDB: dbForNodes);

  // return print("shown notification!");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("\n\n ** SUCCES INITIALIZING FIREBASE APP ** \n\n");
  } catch (e) {
    print("\n\n xx ERROR INITIALIZING FIREBASE APP xx \n\n");
  }
  // load application directory folder
  {
    await g.loadAppDirPath();
  }

  initSqlite();

  // Initializing couchdb
  {
    await CouchbaseLiteFlutter.init();
    tempDB = await Database.openAsync("temp");
    nodesDB = await Database.openAsync("nodes");
    mediasDB = await Database.openAsync("medias");
    messagesDB = await Database.openAsync("messages");
    personalDB = await Database.openAsync("personal");
    paymentsDB = await Database.openAsync("payments");
    utxosDB = await Database.openAsync("utxos");
    billsDB = await Database.openAsync("bills");
    await loadIndexes();
  }

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

    // await _initLocalNotifications(_mainNotificationPlugin);
    // initNotificationPlugin(globalPlugin, globalChannel);
  }

  // special top-level background message handle for android
  // Push.instance.onBackgroundMessage.listen(backgroundMessageHandler);
  // FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);

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
    g.loadTheme(await FireTheme.currentTheme);

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

  final cred = await FirebaseAuth.instance.signInAnonymously();
  runApp(MaterialApp(home: Material(child: Down4(user: cred.user))));
}
