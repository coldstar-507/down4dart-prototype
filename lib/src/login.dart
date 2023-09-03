import 'dart:async';
import 'dart:convert';

import 'package:awesome_notifications_fcm/awesome_notifications_fcm.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:down4/src/data_objects/nodes.dart';
import 'package:down4/src/pages/loading_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:push/push.dart';

import 'data_objects/_data_utils.dart';
import 'data_objects/medias.dart';
import 'globals.dart';
import '_dart_utils.dart' as d4utils;
import 'home.dart';
import 'bsv/_bsv_utils.dart';

import 'pages/init_page.dart';
// import 'pages/loading_page.dart';

class Down4 extends StatefulWidget {
  const Down4({Key? key}) : super(key: key);

  @override
  State<Down4> createState() => _Down4State();
}

class _Down4State extends State<Down4> {
  Widget _view = const LoadingPage2();
  UserCredential? _cred;

  @override
  void initState() {
    super.initState();
    login();
  }

  // void loadTokenChangeListener() {
  //   // // FirebaseMessaging.instance.onTokenRefresh.listen((newToken)
  //   // Push.instance.onNewToken.listen((newToken)
  //   //     async {
  //   //   final res = await r.refreshTokenRequest(newToken);
  //   //   if (res == 200) g.self.updateMessagingToken({g.self.deviceID: newToken});
  //   // });
  // }

  Future<void> logName([String? name]) async {
      await _cred?.user?.updateDisplayName(name ?? g.self.id.value);
  }
  
  Future<void> login() async {
    _cred = await FirebaseAuth.instance.signInAnonymously();
    g.loadExchangeRate(ExchangeRate.exchangeRate);
    // this initialized self it it exists
    if (g.notYetInitialized) {
      createUser();
    } else {
      // final isEnabled = await Push.instance.areNotificationsEnabled();
      // if (!isEnabled) await Push.instance.requestPermission();
      await logName();
      g.loadWallet();
      home();
    }
  }

  Future<void> initUser({
    required ComposedID id,
    required String deviceID,
    required String name,
    required String lastName,
    required double longitude,
    required double latitude,
    required Down4Media media,
  }) async {
    _view = const LoadingPage2();
    setState(() {});    
    
    // update login for database rules    
    await logName(id.value);

    void onFailure(String msg) => createUser(errorMessage: msg);

    // final token = await FirebaseMessaging.instance.getToken();
    final token = await AwesomeNotificationsFcm().requestFirebaseAppToken();
    // final token = await Push.instance.token;
    if (token.isEmpty) {
      print("error getting firebase messaging token");
      return onFailure("Check if valid internet connection!");
    }

    // exception, recalculate the media information with the proper ID
    // this is because the mediaID is calculated with the userID
    // and when it was calculated in the init user, we are not sure if
    // the ID was the proper one
    final goodMedia = await media.userInitRecalculation(id)
      ..cache()
      ..staticUpload();

    final seed1 = unsafeSeed(32);
    final seed2 = unsafeSeed(32);
    final secret = hash256(seed1 + seed2);
    g.initWallet(seed1, seed2);
    final neuter = g.wallet.neuter;

    final fs = Down4Server.instance.masterFS;
    final ref = fs.collection("users").doc(id.unik);
    final success = await fs.runTransaction<bool>((transaction) async {
      final exists = await transaction.get(ref).then((value) => value.exists);
      if (exists) return false;
      transaction.set(ref, {
        "id": id.value,
        "secret": secret.toBase58(),
        "neuter": neuter.toYouKnow(),
        "token": token,
        "longitude": longitude,
        "latitude": latitude,
      });
      return true;
    });

    if (!success) return onFailure("Please try again");

    final devHash = base64Encode(md5(utf8.encode(deviceID)));

    g.initSelf(Self(id,
        deviceID: devHash,
        activity: d4utils.makeTimestamp(),
        name: name,
        description: "",
        lastName: lastName,
        lastOnline: d4utils.makeTimestamp(),
        mainDeviceID: devHash,
        messagingTokens: {devHash: token},
        neuter: neuter,
        mediaID: goodMedia.id,
        children: {},
        privates: {})
      ..cache()
      ..merge()
      ..remoteMerge());

    home();
  }

  void home() {
    // loadTokenChangeListener();
    _view = const Home();
    setState(() {});
  }

  Future<void> createUser({String? errorMessage}) async {
    // final loc = await requestGeoloc(askPermission: true);
    _view = UserMakerPage(
      initUser: initUser,
      errorMessage: errorMessage,
      deviceID: await getDeviceID() ?? Down4ID().value,
      closestRegion: null, //Geo.closestRegion(loc),
      longitude: 0, //loc?.longitude ?? 0,
      latitude: 0, //loc?.latitude ?? 0,
    );
    setState(() {});
  }

  // void welcomePage() {
  //   _view = WelcomePage(
  //     mnemonic: "No giving it bro sorry",
  //     userInfo: _user!,
  //     understood: home,
  //   );
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final truePadding = mediaQuery.viewPadding;
    final headerHeight = size.height * 0.056;
    final allPadding = truePadding.top + truePadding.bottom + headerHeight;
    final sizes = Sizes(
        h: size.height - allPadding,
        w: size.width - truePadding.left - truePadding.right,
        fullHeight: size.height, // - truePadding.top - truePadding.bottom,
        headerHeight: headerHeight);

    g.loadSizes(sizes);

    // ImageCache().maximumSize = 0;

    return _view;
  }
}
