import 'dart:convert';
import 'dart:async';

import 'package:down4/src/data_objects/firebase.dart';
import 'package:down4/src/data_objects/nodes.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'data_objects/_data_utils.dart';
import 'data_objects/medias.dart';
import 'web_requests.dart' as r;
import 'globals.dart';
import '_dart_utils.dart' as d4utils;
import 'home.dart';
import 'bsv/_bsv_utils.dart';

import 'pages/init_page.dart';
import 'pages/loading_page.dart';

class Down4 extends StatefulWidget {
  final auth.User? user;
  const Down4({required this.user, Key? key}) : super(key: key);

  @override
  State<Down4> createState() => _Down4State();
}

class _Down4State extends State<Down4> {
  Widget? _view;

  @override
  void initState() {
    super.initState();
    login();
  }

  void loadTokenChangeListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final res = await r.refreshTokenRequest(newToken);
      if (res == 200) g.self.updateMessagingToken({g.self.deviceID: newToken});
    });
  }

  Future<void> login() async {
    g.loadExchangeRate(await ExchangeRate.exchangeRate);
    // this initialized self it it exists
    if (await g.notYetInitialized) {
      createUser();
    } else {
      await g.loadWallet();
      await widget.user?.updateDisplayName(g.self.id.value);
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
    required FireMedia media,
  }) async {
    // update login for database rules
    await widget.user?.updateDisplayName(id.value);

    _view = const LoadingPage2();
    setState(() {});

    void onFailure(String msg) => createUser(errorMessage: msg);

    // exception, recalculate the media information with the proper ID
    // this is because the mediaID is calculated with the userID
    // and when it was calculated in the init user, we are not sure if
    // the ID was the proper one
    final goodMedia = (await media.userInitRecalculation(id))
      ?..writeFromCachedPath()
      ..staticUpload();

    if (goodMedia == null) {
      print("Error setting the correct ownership over user media");
      return onFailure("System failure");
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print("error getting firebase messaging token");
      return onFailure("Check if valid internet connection!");
    }

    final seed1 = unsafeSeed(32);
    final seed2 = unsafeSeed(32);
    final secret = hash256(seed1 + seed2);
    await g.initWallet(seed1, seed2);
    final neuter = g.wallet.neuter;

    final ref = Down4Server.instance.masterDB.ref('/users/${id.unique}');
    final initResult = await ref.runTransaction((value) {
      if (value != null) return Transaction.abort();
      return Transaction.success({
        "id": id.value,
        "secret": secret.toBase58(),
        "neuter": neuter.toYouKnow(),
        "token": token,
        "longitude": longitude,
        "latitude": latitude,
      });
    });

    if (!initResult.committed) return onFailure("Please try again");

    g.initSelf(Self(id,
        deviceID: deviceID,
        activity: d4utils.makeTimestamp(),
        name: name,
        description: "",
        lastName: lastName,
        mainDeviceID: deviceID,
        messagingTokens: {deviceID: token},
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
    loadTokenChangeListener();
    _view = const Home();
    setState(() {});
  }

  void createUser({String? errorMessage}) async {
    final loc = await requestGeoloc(askPermission: true);
    _view = UserMakerPage(
      initUser: initUser,
      errorMessage: errorMessage,
      deviceID: await getDeviceID() ?? Down4ID().value,
      closestRegion: Geo.closestRegion(loc),
      longitude: loc?.longitude ?? 0,
      latitude: loc?.latitude ?? 0,
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

    ImageCache().maximumSize = 0;

    return _view ?? const LoadingPage2();
  }
}
