import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_testproject/src/down4_utility.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'src/login.dart';

String docDirPath = "";

Future<void> _initBox() async {
  await Hive.openBox("User");
  await Hive.openBox("MessageQueue");
  await Hive.openBox("Home");
  await Hive.openBox("Images");
  await Hive.openBox("Videos");
  await Hive.openBox("Reactions");
  await Hive.openBox("Messages");
  await Hive.openBox("Bills");
  await Hive.openBox("Payments");
  await Hive.openBox("SavedMessages");
  await Hive.openBox("Snips");
  await Hive.openBox("MessageMedias");
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

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } else {
    // TODO kIsWeb
  }

  final dir = await getApplicationDocumentsDirectory();
  docDirPath = dir.path;
  Hive.init(docDirPath);
  await _initBox();

  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
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
        child: Down4(
          cameras: cameras,
        ),
      ),
    ),
  );
}
