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

enum InitializationStates { loading, createUser, welcome, home }

class _Down4State extends State<Down4> {
  // ============================================================ VARIABLES ============================================================ //
  Node? _user;
  MoneyInfo? _moneyInfo;
  // UserCredential? _credential;
  InitializationStates _state = InitializationStates.loading;
  Widget? _page;

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    _processMessageQueue();
    // _anonymousLogin();
    _loadTokenChangeListener();
    _loadHome();
  }

  void _putState(InitializationStates s) {
    setState(() => _state = s);
  }

  void _loadTokenChangeListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final res = await r.refreshTokenRequest(newToken);
    });
  }

  Future<void> _processMessageQueue() async {
    for (final messageData in Boxes.instance.messageQueue.values) {
      await _parseMessageData(messageData);
    }
    await Boxes.instance.messageQueue.clear();
    Boxes.instance.messageQueue.close();
  }

  // Future<void> _anonymousLogin() async {
  //   try {
  //     _credential = await FirebaseAuth.instance.signInAnonymously();
  //     print("Anonymous uid: ${_credential?.user?.uid}");
  //   } catch (e) {
  //     print("Error logging in: $e");
  //   }
  // }

  Future<void> _loadHome() async {
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
      String id, String name, String lastName, Uint8List imData) async {
    final token = await FirebaseMessaging.instance.getToken();
    final nodeInfo = {
      'id': id,
      'nm': name,
      'ln': lastName,
      'im': imData,
      'tkn': token,
    };

    final success = await r.initUser(jsonEncode(nodeInfo));

    if (!success) {
      print("Failed to init user!");
      return false;
    }

    final imageID = sv.sha1(id.codeUnits + imData.toList()).toString();

    Down4Image image = Down4Image(
      id: imageID,
      data: imData,
    );

    await image.generateThumbnail();

    _user = Node(
      type: NodeTypes.usr,
      id: id,
      image: image,
      name: name,
      lastName: lastName,
    );

    _moneyInfo = await r.initUserMoney(id);

    if (_moneyInfo == null) {
      print("Failed to initalize money!");
      return false;
    }

    final xpriv = sv.HDPrivateKey.fromXpriv(_moneyInfo!.down4Priv);
    final nextPriv =
        xpriv.deriveChildNumber(_moneyInfo!.upperIndex + 2).privateKey;

    final hexpriv = nextPriv.toHex();

    var sig = sv.SVSignature.fromPrivateKey(nextPriv);

    const message = "Jeff is a nigger";
    final hexEncodedMessage = HEX.encode(message.codeUnits);

    final signedMessage = sig.sign(hexEncodedMessage);

    final verifSig = sv.SVSignature.fromPublicKey(nextPriv.publicKey);
    // final isValid = verifSig.verify(signedMessage);

    print(
        "next privateKey in hex: $hexpriv\nMessage: Jeff is a nigger\nSigned message: $signedMessage");

    Boxes.instance.user.put('token', token);
    Boxes.instance.user.put('user', jsonEncode(_user!.toLocal()));
    Boxes.instance.user.put('money', jsonEncode(_moneyInfo));

    return true;
  }

  Future<void> _parseMessageData(final notification) async {
    final type = MessageTypes.values.byName(notification["t"]);
    final messageData = notification["data"];
    switch (type) {
      case MessageTypes.friendRequest:
        {
          Boxes.instance.friendRequests.put(messageData["id"], messageData);
          break;
        }
      case MessageTypes.bill:
        {
          Boxes.instance.bills.put(messageData["id"], messageData);
          break;
        }
      case MessageTypes.payment:
        {
          Boxes.instance.payments.put(messageData["id"], messageData);
          break;
        }
      case MessageTypes.chat:
        {
          Boxes.instance.messages.put(messageData["id"], messageData);
          var chatSource = Node.fromJson(
            Boxes.instance.friends.get(messageData["sd"])!,
          ); // that will crash
          chatSource.messages?.add(messageData["id"]);
          Boxes.instance.friends.put(chatSource.id, chatSource.toLocal());
          break;
        }
    }
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

    return _page ?? const LoadingPage();
  }
}
