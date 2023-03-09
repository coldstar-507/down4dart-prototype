import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'src/login.dart';
import 'src/globals.dart';

// String docDirPath = "";
// String tempDirPath = "";
// List<CameraDescription> cameras = [];

Future<void> _initBox() async {
  await Hive.openBox("Personal");
  await Hive.openBox("MessageQueue");
  await Hive.openLazyBox("Hidden");
  await Hive.openLazyBox("Nodes");
  await Hive.openLazyBox("Messages");
  await Hive.openLazyBox("Bills");
  await Hive.openLazyBox("Payments");
  await Hive.openLazyBox("Medias");
  await Hive.openLazyBox("Utxos");
  await Hive.openLazyBox("Spents");
}

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
      'High Importance Notifications for Down4AndroidNotificationChannel', // title // description
      importance: Importance.high,
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
      "@mipmap/ic_down4_inverted_white", // TODO change to real icon
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

  final appDir = await getApplicationDocumentsDirectory();
  final tempDir = await getTemporaryDirectory();
  Hive.init(appDir.path);
  await _initBox();
  g.boxes.docPath = appDir.path;
  g.boxes.tempPath = tempDir.path;

  {
    final d1 = await rootBundle.load("assets/images/50.png");
    final d2 = await rootBundle.load("assets/images/filled.png");
    final d3 = await rootBundle.load("assets/images/redArrow.png");
    g.fifty = Image.memory(d1.buffer.asUint8List(), gaplessPlayback: true);
    g.black = Image.memory(d2.buffer.asUint8List(), gaplessPlayback: true);
    g.red = Image.memory(d3.buffer.asUint8List(), gaplessPlayback: true);
  }

  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    g.cameras = await availableCameras();
  } catch (err) {
    print("Available cameras error $err");
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
      home: Material(
        child: Down4(),
      ),
    ),
  );
}
