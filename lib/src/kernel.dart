import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dartsv/dartsv.dart' as sv;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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
import 'render_objects.dart';
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

enum InitializationStates { loading, createUser, welcome, home }

class _Down4State extends State<Down4> {
  // ============================================================ VARIABLES ============================================================ //
  Node? _user;
  MoneyInfo? _moneyInfo;
  InitializationStates _state = InitializationStates.loading;

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    // _anonymousLogin();
    _loadTokenChangeListener();
    _loadUser();
  }

  void _putState(InitializationStates s) {
    setState(() => _state = s);
  }

  void _loadTokenChangeListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final res = await r.refreshTokenRequest(newToken);
    });
  }

  Future<void> _loadUser() async {
    final userData = Boxes.instance.user.get('user');
    if (userData != null) {
      _user = Node.fromJson(jsonDecode(userData));
      final moneyData = Boxes.instance.user.get('money');
      _moneyInfo =
          MoneyInfo.fromJson(jsonDecode(moneyData)); // if this crashes gg
      _putState(InitializationStates.home);
    } else {
      // returns false if user hasn't been initialized
      _putState(InitializationStates.createUser);
    }
  }

  Future<bool> _initUser(
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
    );

    _moneyInfo = MoneyInfo(
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
    Boxes.instance.user.put('money', jsonEncode(_moneyInfo));

    return true;
  }

  // ============================================================ RENDER ============================================================ //

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case InitializationStates.loading:
        return const LoadingPage();
      case InitializationStates.home:
        return HomePage(
          cameras: widget.cameras,
          self: _user!,
        );
      case InitializationStates.createUser:
        return UserMakerPage(
          cameras: widget.cameras,
          initUser: _initUser,
          success: () => _putState(InitializationStates.welcome),
        );
      case InitializationStates.welcome:
        return WelcomePage(
          mnemonic: _moneyInfo!.mnemonic,
          userInfo: _user!,
          understood: () => _putState(InitializationStates.home),
        );
    }
  }
}
