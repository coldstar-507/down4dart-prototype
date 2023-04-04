import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl/cbl.dart';
import 'package:down4/src/couch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:down4/src/_dart_utils.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'src/login.dart';
import 'src/globals.dart';

// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // If you're going to use other Firebase services in the background, such as Firestore,
//   // make sure you call `initializeApp` before using other Firebase services.
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   var messageQueue = await Hive.openBox("MessageQueue");
//   messageQueue.add(message.data);
//   messageQueue.close();
// }

late AndroidNotificationChannel channel;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    channel = const AndroidNotificationChannel(
      'Down4AndroidNotificationChannel', // id
      'Default Importance Notifications for Down4AndroidNotificationChannel',
      // title // description
      importance: Importance.defaultImportance,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    /// Create an Android Notification Channel.
    ///
    /// We use this channel in the `AndroidManifest.xml` file to override the
    /// default FCM channel to enable heads up notifications.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const initializationSettingsAndroid = AndroidInitializationSettings(
      "@mipmap/ic_down4_inverted_white",
    ); // <- default icon name is @mipmap/ic_launcher
    // var initializationSettingsIOS = IOSInitializationSettings(
    //     onDidReceiveLocalNotification: onDidReceiveLocalNotification);
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    ); // , initializationSettingsIOS);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    // ,onSelectNotification: onSelectNotification); // TODO onSelect

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If `onMessage` is triggered with a notification, construct our own
      // local notification to show to users using the created channel.
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android.smallIcon,
                // other properties...
              ),
            ));
      }
    });
  } else {
    // TODO kIsWeb
  }

  // Initializing couchdb
  {
    await CouchbaseLiteFlutter.init();
    nodesDB = await Database.openAsync("nodes");
    mediasDB = await Database.openAsync("medias");
    messagesDB = await Database.openAsync("messages");
    personalDB = await Database.openAsync("personal");
    paymentsDB = await Database.openAsync("payments");
    utxosDB = await Database.openAsync("utxos");
    billsDB = await Database.openAsync("bills");
    await loadIndexes();
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

    g.d1 = Image.memory(d1.buffer.asUint8List(), gaplessPlayback: true);
    g.d2 = Image.memory(d2.buffer.asUint8List(), gaplessPlayback: true);
    g.d3 = Image.memory(d3.buffer.asUint8List(), gaplessPlayback: true);
    g.ph = Image.memory(ph.buffer.asUint8List(), gaplessPlayback: true);
    g.fifty = Image.memory(a1.buffer.asUint8List(), gaplessPlayback: true);
    g.black = Image.memory(a2.buffer.asUint8List(), gaplessPlayback: true);
    g.red = Image.memory(a3.buffer.asUint8List(), gaplessPlayback: true);
    g.background = bg.buffer.asUint8List();
  }

  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // initializing cameras
  {
    try {
      g.cameras = await availableCameras();
    } catch (err) {
      print("Available cameras error $err");
    }
  }

  if (await hasNetwork()) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: "Alice"),
      home: const Material(child: Down4()),
    ),
  );
}
