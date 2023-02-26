import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'web_requests.dart' as r;
import 'globals.dart';
import '_down4_dart_utils.dart' as d4utils;
import 'home.dart';
import 'data_objects.dart';
import 'themes.dart';
import 'bsv/wallet.dart';
import 'bsv/utils.dart';

import 'pages/welcome_page.dart';
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
    // FirebaseDatabase.instance.setPersistenceEnabled(false);
    // fs.settings = const Settings(persistenceEnabled: false);
    loadTokenChangeListener();
    loadUser();
  }

  void loadTokenChangeListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final res = await r.refreshTokenRequest(newToken);
    });
  }

  Future<void> loadUser() async {
    if (g.notYetInitialized) {
      createUser();
    } else {
      home();
    }
  }

  Future<bool> initUser({
    required ID id,
    required String name,
    required String lastName,
    required String imPath,
    required String imExtension,
    required double imAspectRatio,
    required bool isReversed,
  }) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print("error getting firebase messaging token");
      return false;
    }

    final seed1 = unsafeSeed(32);
    final seed2 = unsafeSeed(32);
    final secret = hash256(seed1 + seed2);
    g.initWallet(seed1, seed2);
    final neuter = g.wallet.neuter;

    NodeMedia image = NodeMedia(
      id: d4utils.randomMediaID(),
      data: File(imPath).readAsBytesSync(),
      metadata: MediaMetadata(
        owner: id,
        timestamp: d4utils.timeStamp(),
        elementAspectRatio: 1 / imAspectRatio,
        extension: imExtension,
        isReversed: isReversed,
        isSquared: true, // all node images are squared
      ),
    );

    final userInfo = {
      'id': id,
      'nm': name,
      'ln': lastName,
      'sh': secret.toBase58(),
      'tkn': token,
      'nt': neuter.toYouKnow(),
      'im': image,
    };

    final success = await r.initUser(jsonEncode(userInfo));

    if (!success) {
      print("It was not a success");
      return false;
    }

    g.initSelf(id, image, neuter, name, lastName);

    g.boxes.personal.put("token", token);

    return true;
  }

  // ============================================================ RENDER ============================================================ //

  void home() {
    _view = const Home();
    setState(() {});
  }

  void createUser() {
    _view = UserMakerPage(initUser: initUser, success: home);
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
    // final fakePadding = mediaQuery.padding;
    g.sizes.fullHeight = size.height;
    g.sizes.headerHeight = size.height * 0.056;
    g.sizes.h = size.height -
        truePadding.top -
        truePadding.bottom -
        g.sizes.headerHeight;
    g.sizes.w = size.width - truePadding.left - truePadding.right;
    return _view ?? const LoadingPage2();
  }
}
