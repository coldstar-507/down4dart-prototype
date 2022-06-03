import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/boxes.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'src/kernel.dart';

Future<void> _openAllBoxes() async {
  Hive.openBox("Images");
  await Hive.openBox("Friends");
  await Hive.openBox("User");
  Hive.openBox("Reactions");
  Hive.openBox("Others");
  await Hive.openBox("FriendRequests");
  Hive.openBox("Messages");
  await Hive.openBox("MessageQueue");
  Hive.openBox("Bills");
  Hive.openBox("Payments");
  await Hive.openBox("Hyperchats");
}

Future<void> _firebaseMessagingOnTokenChange() async {}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  var messageQueue = await Hive.openBox("MessageQueue");
  messageQueue.add(message.data);
  messageQueue.close();
}

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

  var dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  await _openAllBoxes();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (err) {
    print("Available cameras error $err");
  }

  print("Getting messaging token");
  final token = await FirebaseMessaging.instance.getToken();
  print("Got messaging token: $token");

  print(FirebaseAuth.instance.app);
  // await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: "Alice"),
      home: Scaffold(
        body: SafeArea(
          child: Down4(
            cameras: cameras,
            token: token,
          ),
        ),
      ),
    ),
  );
}
