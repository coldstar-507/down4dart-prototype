import 'dart:async';

import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl/cbl.dart';

import 'package:down4/src/data_objects/couch.dart';
import 'package:down4/src/data_objects/_data_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:camera/camera.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'src/login.dart';
import 'src/globals.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  showMessageNotification(message);
  if (message.data.isNotEmpty) {
    final doc = MutableDocument.withId(Down4ID().unique);
    doc.setData(message.data);
    tempDB.saveDocument(doc);
  }
}

Future<void> _initNotificationPlugin() async {
  channel = const AndroidNotificationChannel(
    'Down4AndroidNotificationChannel',
    'Default Importance Notifications for Down4AndroidNotificationChannel',
    importance: Importance.defaultImportance,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const initializationSettingsAndroid = AndroidInitializationSettings(
    "@mipmap/ic_down4_inverted_white",
  );

  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Initializing couchdb
  {
    await CouchbaseLiteFlutter.init();
    tempDB = await Database.openAsync("temp");
    nodesDB = await Database.openAsync("nodes");
    mediasDB = await Database.openAsync("medias");
    messagesDB = await Database.openAsync("messages");
    reactionsDB = await Database.openAsync("reactions");
    personalDB = await Database.openAsync("personal");
    paymentsDB = await Database.openAsync("payments");
    utxosDB = await Database.openAsync("utxos");
    billsDB = await Database.openAsync("bills");
    await loadIndexes();
  }

  // Init notifications settings and background message listener
  {
    _initNotificationPlugin();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // loading some asset in memory, not having those assets in memory cause
  // stutter in transitions for example, loading image from assets is
  // actually slow
  {
    final a1 = await rootBundle.load("assets/images/50.png");
    final a2 = await rootBundle.load("assets/images/filled.png");
    final a3 = await rootBundle.load("assets/images/redArrow.png");
    final d1 = await rootBundle.load("assets/images/Dollar_Sign_1.png");
    final d2 = await rootBundle.load("assets/images/Dollar_Sign_2.png");
    final d3 = await rootBundle.load("assets/images/Dollar_Sign_3.png");
    final ph = await rootBundle.load("assets/images/place_holder.png");
    final bg = await rootBundle.load("assets/images/triangles.png");

    final lg = await rootBundle.load("assets/images/down4_inverted_white.png");
    g.lg = Image.memory(lg.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.d1 = Image.memory(d1.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.d2 = Image.memory(d2.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.d3 = Image.memory(d3.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.ph = Image.memory(ph.buffer.asUint8List(),
        fit: BoxFit.cover, gaplessPlayback: true);
    g.fifty = Image.memory(a1.buffer.asUint8List(),
        fit: BoxFit.contain, gaplessPlayback: true);
    g.black = Image.memory(a2.buffer.asUint8List(),
        fit: BoxFit.contain, gaplessPlayback: true);
    g.red = Image.memory(a3.buffer.asUint8List(),
        fit: BoxFit.contain, gaplessPlayback: true);
    g.background = bg.buffer.asUint8List();
  }

  // load application directory folder
  {
    await g.loadAppDirPath();
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
