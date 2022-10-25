import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

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
  Node? _user;
  Wallet? _wallet;
  Widget? _view;

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    FirebaseDatabase.instance.setPersistenceEnabled(false);
    fs.settings = const Settings(persistenceEnabled: false);
    loadTokenChangeListener();
    loadUser();
  }

  void loadTokenChangeListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final res = await r.refreshTokenRequest(newToken);
    });
  }

  Future<void> loadUser() async {
    final userData = b.user.get('user');
    if (userData != null) {
      _user = Node.fromJson(jsonDecode(userData));
      final moneyData = b.user.get('wallet');
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
    Uint8List imData,
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

    final imageID = d4utils.generateMediaID(imData);
    Down4Media image = Down4Media(
      id: imageID,
      data: imData,
      metadata: MediaMetadata(
        owner: id,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        toReverse: toReverse,
      ),
    );

    final userInfo = {
      'id': id,
      'nm': name,
      'ln': lastName,
      'sh': secret.toHex(),
      'tkn': token,
      'nt': neutered.toYouKnow(),
      'im': image,
    };

    final success = await r.initUser(jsonEncode(userInfo));

    if (!success) {
      print("It was not a success");
      return false;
    }

    final thumbnail = await FlutterImageCompress.compressWithList(
      image.data,
      minWidth: 20,
      minHeight: 20,
      quality: 50,
    );

    image.thumbnail = thumbnail;

    _user = Node(
      type: Nodes.user,
      neuter: neutered,
      id: id,
      image: image,
      name: name,
      lastName: lastName,
      parents: [],
      childs: [],
      messages: [],
      snips: [],
    );

    b.user.putAll({
      'token': token,
      'user': jsonEncode(_user),
      'wallet': jsonEncode(_wallet),
    });

    return true;
  }

  // ============================================================ RENDER ============================================================ //

  void home() {
    _view = Home(
      wallet: _wallet!,
      cameras: widget.cameras,
      self: _user!,
    );
    setState(() {});
  }

  void createUser() {
    _view = UserMakerPage(
      cameras: widget.cameras,
      initUser: initUser,
      success: welcomePage,
    );
    setState(() {});
  }

  void welcomePage() {
    _view = WelcomePage(
      mnemonic: "No giving it bro sorry",
      userInfo: _user!,
      understood: home,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: PinkTheme.qrColor),
    );
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    Sizes.h = size.height - padding.top - padding.bottom - 32;
    Sizes.w = size.width - padding.left - padding.right;
    return SafeArea(child: _view ?? const LoadingPage());
  }
}
