import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dartsv/dartsv.dart' as sv;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_testproject/src/wallet.dart';
import 'web_requests.dart' as r;
import 'boxes.dart';
// import 'package:crypto/crypto.dart' as crypto;
// import 'package:pointycastle/digests/sha1.dart';
import 'package:pointycastle/digests/sha256.dart' as pc256;
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:convert/convert.dart';
import 'package:hex/hex.dart';

import 'render_pages.dart';
import 'data_objects.dart';

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
    loadTokenChangeListener();
    loadUser();
  }

  void loadTokenChangeListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final res = await r.refreshTokenRequest(newToken);
    });
  }

  Future<void> loadUser() async {
    final userData = Boxes.instance.user.get('user');
    if (userData != null) {
      _user = Node.fromJson(jsonDecode(userData));
      final moneyData = Boxes.instance.user.get('money');
      _wallet = Wallet.fromJson(jsonDecode(moneyData)); // if this crashes gg
      homePage();
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
    final mnemonic = await r.generateMnemonic();

    if (mnemonic == null) {
      print("error generating mnemonic generateMnemonic");
      return false;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print("error getting firebase messaging token");
      return false;
    }

    final concatMnemonic = mnemonic.replaceAll(" ", "");
    print("concatenated mnemonic: $concatMnemonic");
    final concatMnemonicCodes = concatMnemonic.codeUnits;
    final idCodeUnits = id.codeUnits;
    final secretData = concatMnemonicCodes + idCodeUnits;

    final seed = sv.Mnemonic().toSeedHex(mnemonic);
    final master = sv.HDPrivateKey.fromSeed(seed, sv.NetworkType.MAIN);
    final down4priv = master.deriveChildKey("m/4'/0'/0'");
    final neuter = down4priv.hdPublicKey;
    print("seedHex: $seed");
    print("masterString: ${master.toString()}");
    print("down4priv: ${down4priv.toString()}");
    print("neuter: ${neuter.toString()}");

    final singleHash =
        pc256.SHA256Digest().process(Uint8List.fromList(secretData));
    final doubleHash = pc256.SHA256Digest().process(singleHash);
    final pcDoubleHashHex = HEX.encode(doubleHash);

    final doublesv = sv.sha256Twice(secretData);
    final doublesvHex = HEX.encode(doublesv);

    print("concatMnemonicCodeUnits: $concatMnemonicCodes");
    print("idCodeUnits: $idCodeUnits");
    print("secretData: $secretData");

    print("pcDoubleHash: $doubleHash");
    print("pcDoubleHEX: $pcDoubleHashHex");

    print("doublesv: $doublesv");
    print("doublesvHEX: $doublesvHex");

    final secret = doublesvHex;
    final isValid = doublesvHex == pcDoubleHashHex;

    print("VALID SECRET IS ${doublesvHex == pcDoubleHashHex}\n");
    if (!isValid) {
      return false;
    }

    final imageID = HEX.encode(sv.sha1(id.codeUnits + imData.toList()));
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
      'sh': secret,
      'tkn': token,
      'nt': neuter.toString(),
      'im': image,
    };

    final success = await r.initUser(jsonEncode(userInfo));

    if (!success) {
      print("It was not a success");
      return false;
    }

    await image.generateThumbnail();

    _user = Node(
      type: Nodes.user,
      id: id,
      image: image,
      name: name,
      lastName: lastName,
      parents: [],
      childs: [],
      admins: [],
      friends: [],
      group: [],
      posts: [],
      messages: [],
      snips: [],
    );

    _wallet = Wallet(
      mnemonic: mnemonic,
      master: master,
      down4priv: down4priv,
      lowerIndex: 0,
      upperIndex: 0,
      lowerChange: 1,
      upperChange: 1,
    );

    Boxes.instance.user.put('token', token);
    Boxes.instance.user.put('user', jsonEncode(_user!.toLocal()));
    Boxes.instance.user.put('money', jsonEncode(_wallet));

    return true;
  }

  // ============================================================ RENDER ============================================================ //

  void homePage() {
    _view = HomePage(
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
      mnemonic: _wallet!.mnemonic,
      userInfo: _user!,
      understood: homePage,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    Sizes.h = size.height - padding.top - padding.bottom;
    Sizes.w = size.width - padding.left - padding.right;
    return SafeArea(child: _view ?? const LoadingPage());
  }
}
