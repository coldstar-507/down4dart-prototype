import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/kernel.dart';

Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message, Box queue) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  queue.add(message.data);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  var dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  var messageQueue = await Hive.openBox("MessageQueue");

  FirebaseMessaging.onBackgroundMessage(
      (message) => _firebaseMessagingBackgroundHandler(message, messageQueue));

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (err) {
    print("Available cameras error $err");
  }

  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: "Alice"),
      home: Scaffold(
        body: SafeArea(
          child: Down4(cameras: cameras, messageQueue: messageQueue),
        ),
      ),
    ),
  );
}
