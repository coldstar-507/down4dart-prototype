import 'dart:async';
import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';

import 'package:down4/src/data_objects/couch.dart';
import 'package:down4/src/data_objects/_data_utils.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:down4/src/data_objects/medias.dart';
import 'package:down4/src/data_objects/nodes.dart';
import 'package:down4/src/web_requests.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:camera/camera.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:sqlite3/sqlite3.dart';

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
  required ComposedID? currentRoot,
}) async {
  final self = selfID;
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

  try {
    print("### getting the sender");
    sender = await global<PersonN>(sdrID, doFetch: true, doMergeIfFetch: true);

    if (sender != null) {
      print("### getting senderMedia");
      senderImage = await global<Down4Image>(sender.mediaID,
          doFetch: true, doMergeIfFetch: true);
    }

    if (rtID != null) {
      final rootNode =
          await global<ChatN>(rtID, doFetch: true, doMergeIfFetch: true);
      if (rootNode is GroupN) {
        group = rootNode;
        print("### getting groupMedia");
        groupImage = await global<Down4Image>(group.mediaID,
            doFetch: true, doMergeIfFetch: true);
      }
    }
  } catch (e) {
    return print("error quering infos in showMessageNotification: $e");
  }

  // final senderImagePath = senderImage?.mainPath;
  // final groupImagePath = groupImage?.mainPath;
  final senderImagePath = await senderImage?.profilePath;
  final groupImagePath = await groupImage?.profilePath;

  final isGroup = group != null;
  print("isGroup = $isGroup");

  // final pathForImage = groupImageProfilePath ?? senderImageProfilePath;
  final pathForImage = groupImagePath ?? senderImagePath;

  print("PATH FOR IMAGE: $pathForImage");

  print("showing notification!");
  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: Random().nextInt(200000),
      channelKey: 'def',
      groupKey: rtID?.value ?? sdrID?.value,
      title: header,
      body: body,
      summary: '',
      roundedLargeIcon: !isGroup,
      largeIcon: "file://$pathForImage",
      // bigPicture: groupImageProfilePath != null
      //     ? "file://$groupImageProfilePath"
      //     : null,
      icon: 'resource://drawable/ic_down4_inverted_white',
      notificationLayout: isGroup
          ? NotificationLayout.MessagingGroup
          : NotificationLayout.Messaging,
    ),
  );
  print("showed notification!");
}

Future<void> fcmHandler(FcmSilentData silentData) async {
  try {
    print("Initializing firebase app in fcmHandler");
    await Firebase.initializeApp();
  } catch (e) {
    print("Error initializing firebase app in fcmHandler: $e");
  }

  print("NEW SILENT DATA BABY");
  final data = silentData.data!;
  final loc = await Down4Local().initDb(walMode: true);

  ResultSet r2;
  try {
    const q = "SELECT currentPage FROM personals WHERE id = 'single'";
    r2 = loc.db.select(q);
  } catch (e) {
    return print("error selecting currentPage in fcmHandler: $e");
  }

  ComposedID? rtID;
  final String? currentPage = r2.single["currentPage"];
  if ((currentPage?.length ?? 0) > 5) {
    final (e1, e2) = (currentPage?.substring(0, 4), currentPage?.substring(5));
    if (e1 == "chat") rtID = ComposedID.fromString(e2);
  }

  if (currentPage != null) return print("\tAPP IS LIVE, NOT DOING ANYTHING");
  print("\tAPP NOT LIVE, SHOWING NOTIFICATION");
  ComposedID selfID;
  try {
    final r = loc.db.select("SELECT id FROM nodes WHERE type = 'self'");
    selfID = ComposedID.fromString(r.single["id"])!;
  } catch (e) {
    return print("error reading selfID in fcmHandler: $e");
  }

  await showMessageNotification(data, selfID: selfID, currentRoot: rtID);
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

  await Down4Local().initDb(walMode: true);

  {
    // inits notifications settings
    AwesomeNotifications().initialize(
        'resource://drawable/ic_down4_inverted_white',
        [
          NotificationChannel(
              icon: 'resource://drawable/ic_down4_inverted_white',
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
    await g.theme.readMapStyle();

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
  runApp(MaterialApp(
      theme: ThemeData(useMaterial3: false),
      home: const Material(child: Down4())));
}
