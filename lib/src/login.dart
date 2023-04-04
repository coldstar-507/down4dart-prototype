import 'dart:convert';
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'web_requests.dart' as r;
import 'globals.dart';
import '_dart_utils.dart' as d4utils;
import 'home.dart';
import 'data_objects.dart';
import 'bsv/_bsv_utils.dart';

import 'pages/init_page.dart';
import 'pages/loading_page.dart';

class Down4 extends StatefulWidget {
  const Down4({Key? key}) : super(key: key);

  @override
  State<Down4> createState() => _Down4State();
}

class _Down4State extends State<Down4> {
  // ============================================================ VARIABLES ============================================================ //
  // Self? _self;
  // Wallet? _wallet;
  Widget? _view;

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    FirebaseDatabase.instance.setPersistenceEnabled(false);
    loadTokenChangeListener();
    loadUser();
  }

  void loadTokenChangeListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final res = await r.refreshTokenRequest(newToken);
      if (res == 200) Token(newToken).merge();
    });
  }

  Future<void> loadUser() async {
    g.loadExchangeRate(await ExchangeRate.exchangeRate);
    g.loadWallet();
    // this initialized self it it exists
    if (await g.notYetInitialized) {
      createUser();
    } else {
      home();
    }
  }

  Future<void> initUser({
    required ID id,
    required String name,
    required String lastName,
    required FireMedia media,
  }) async {
    void onFailure(String msg) => createUser(errorMessage: msg);

    final goodMedia = await media.withNewOwnership(id, recalculateID: true);
    if (goodMedia == null) {
      print("Error setting the correct ownership over user media");
      return onFailure("System failure");
    }
    goodMedia.writeFromCachedPath();

    _view = const LoadingPage2();
    setState(() {});

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print("error getting firebase messaging token");
      return onFailure("Check if valid internet connection!");
    }

    final seed1 = unsafeSeed(32);
    final seed2 = unsafeSeed(32);
    final secret = hash256(seed1 + seed2);
    g.initWallet(seed1, seed2);
    final neuter = g.wallet.neuter;

    final successfulMediaUpload = await uploadMedia(goodMedia, isNode: true);
    if (!successfulMediaUpload) {
      print("Unsuccessful media upload");
      return onFailure("Check internet connection!");
    }

    final userInfo = {
      'id': id,
      'name': name,
      'lastName': lastName,
      'secret': secret.toBase58(),
      'token': token,
      'neuter': neuter.toYouKnow(),
      'media': goodMedia.id,
    };

    final success = await r.initUser(jsonEncode(userInfo));

    if (!success) {
      print("Error initializing account, try again!");
      return onFailure("Error initializing account, try again!");
    }

    await g.initSelf(id, goodMedia, neuter, name, lastName);

    await Token(token).merge();

    home();
  }

  // ============================================================ RENDER ============================================================ //

  void home() {
    _view = const Home();
    setState(() {});
  }

  void createUser({String? errorMessage}) {
    _view = UserMakerPage(initUser: initUser, errorMessage: errorMessage);
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
    final allPadding = truePadding.top - truePadding.bottom - headerHeight;
    // final fakePadding = mediaQuery.padding;
    final sizes = Sizes(
        h: size.height - allPadding,
        w: size.width - truePadding.left - truePadding.right,
        fullHeight: size.height,
        headerHeight: headerHeight);

    g.loadSizes(sizes);

    return _view ?? const LoadingPage2();
  }
}
