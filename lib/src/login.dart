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
import 'boxes.dart';
import 'down4_utility.dart' as d4utils;
import 'home.dart';
import 'data_objects.dart';
import 'themes.dart';
import 'bsv/wallet.dart';
import 'bsv/utils.dart';

import 'pages/welcome_page.dart';
import 'pages/init_page.dart';
import 'pages/loading_page.dart';

class Down4 extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Down4({
    required this.cameras,
    Key? key,
  }) : super(key: key);

  @override
  State<Down4> createState() => _Down4State();
}

class _Down4State extends State<Down4> {
  // ============================================================ VARIABLES ============================================================ //
  Self? _self;
  Wallet? _wallet;
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
    final userData = b.personal.get('user');
    if (userData != null) {
      _self = BaseNode.fromJson(jsonDecode(userData)) as Self;
      final moneyData = b.personal.get('wallet');
      _wallet = Wallet.fromJson(jsonDecode(moneyData)); // if this crashes gg
      home();
    } else {
      // returns false if user hasn't been initialized
      createUser();
    }
  }

  Future<bool> initUser(
    String id,
    String name,
    String lastName,
    String imPath,
    double imAspectRatio,
    bool toReverse,
  ) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print("error getting firebase messaging token");
      return false;
    }

    final seed1 = unsafeSeed(32);
    final seed2 = unsafeSeed(32);
    final secret = hash256(seed1 + seed2);
    _wallet = Wallet.fromSeed(seed1, seed2);
    final neutered = _wallet!.keys.neutered();

    NodeMedia image = NodeMedia(
      id: d4utils.randomMediaID(),
      metadata: MediaMetadata(
        owner: id,
        timestamp: d4utils.timeStamp(),
        elementAspectRatio: imAspectRatio,
        isReversed: toReverse,
      ),
      path: imPath,
    );

    final userInfo = {
      'id': id,
      'nm': name,
      'ln': lastName,
      'sh': secret.toBase64(),
      'tkn': token,
      'nt': neutered.toYouKnow(),
      'im': image,
    };

    final success = await r.initUser(jsonEncode(userInfo));

    if (!success) {
      print("It was not a success");
      return false;
    }

    // final thumbnail = await FlutterImageCompress.compressWithFile(
    //   appPath,
    //   minWidth: 20,
    //   minHeight: 20,
    //   quality: 50,
    // );
    //
    // image.thumbnail = thumbnail;

    _self = Self(
      id: id,
      media: image,
      firstName: name,
      lastName: lastName,
      children: {},
      messages: {},
      snips: {},
      savedMessages: {},
      images: {},
      videos: {},
      nfts: {},
    );

    b.personal.putAll({
      'token': token,
      'self': jsonEncode(_self),
      'wallet': jsonEncode(_wallet),
    });

    return true;
  }

  // ============================================================ RENDER ============================================================ //

  void home() {
    _view = Home(
      wallet: _wallet!,
      cameras: widget.cameras,
      self: _self!,
    );
    setState(() {});
  }

  void createUser() {
    _view = UserMakerPage(
      cameras: widget.cameras,
      initUser: initUser,
      success: home,
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
    // final fakePadding = mediaQuery.padding;
    Sizes.fullHeight = size.height;
    Sizes.headerHeight = size.height * 0.056;
    Sizes.h =
        size.height - truePadding.top - truePadding.bottom - Sizes.headerHeight;
    Sizes.w = size.width - truePadding.left - truePadding.right;
    return _view ?? const LoadingPage();
  }
}
