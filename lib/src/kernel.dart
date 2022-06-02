import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dartsv/dartsv.dart' as sv;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'web_requests.dart' as r;
import 'boxes.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'render_pages.dart';
import 'data_objects.dart';
import 'render_objects.dart';
import 'scratch.dart' as scratch;

class Down4 extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String? token;
  const Down4({
    required this.cameras,
    this.token,
    Key? key,
  }) : super(key: key);

  @override
  State<Down4> createState() => _Down4State();
}

enum States {
  loading,
  userCreation,
  welcome,
  home,
  money,
  hyperchat,
  chat,
  addFriend,
  node,
  map,
  nodeCreation,
  snip,
  cam,
}

class _Down4State extends State<Down4> {
  // ============================================================ VARIABLES ============================================================ //
  Node? _user;
  MoneyInfo? _moneyInfo;
  UserCredential? _credential;
  Widget? _page;

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    _processMessageQueue();
    _anonymousLogin();
    _loadTokenChangeListener();
    _loadHome();
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

  Future<void> _anonymousLogin() async {
    try {
      _credential = await FirebaseAuth.instance.signInAnonymously();
      print("Anonymous uid: ${_credential?.user?.uid}");
    } catch (e) {
      print("Error logging in: $e");
    }
  }

  Future<void> _loadHome() async {
    final userData = Boxes.instance.user.get('user');
    if (userData != null) {
      _user = Node.fromJson(jsonDecode(userData));
      final moneyData = Boxes.instance.user.get('money');
      _moneyInfo =
          MoneyInfo.fromJson(jsonDecode(moneyData)); // if this crashes gg
      setState(() => _page = _homePage());
    } else {
      // returns false if user hasn't been initialized
      setState(() => _page = _userCreationPage());
    }
  }

  Widget _userCreationPage() {
    return UserMakerPage(
      cameras: widget.cameras,
      initUser: _initUser,
      success: () => setState(() => _page = _welcomePage()),
    );
  }

  Widget _welcomePage() {
    return WelcomePage(
      mnemonic: _moneyInfo!.mnemonic,
      userInfo: _user!,
      understood: () => setState(() => _page = _homePage()),
    );
  }

  Widget _homePage() {
    return HomePage(
      cameras: widget.cameras,
      self: _user!,
    );
  }

  Future<bool> _initUser(Map<String, dynamic> info) async {
    final token = await FirebaseMessaging.instance.getToken();
    info["tkn"] = token;

    if (!(await r.initUser(jsonEncode(info)))) {
      print("Failed to init user!");
      return false;
    }

    String uid = info["id"];
    List<int> imData = info["im"];
    Down4Image image = Down4Image(
      id: sv.sha1(uid.codeUnits + imData).toString(),
      data: Uint8List.fromList(imData),
    );
    await image.generateThumbnail();

    _user = Node(
      type: NodeTypes.usr,
      id: info["id"],
      image: image,
      name: info["nm"],
      lastName: info["ln"],
    );

    _moneyInfo = await r.initUserMoney(uid);

    Boxes.instance.user.put('token', token);
    Boxes.instance.user.put('user', jsonEncode(_user!.toLocal()));
    Boxes.instance.user.put('money', jsonEncode(_moneyInfo));

    return true;
  }

  Future<void> _parseMessageData(final data) async {
    final type = MessageTypes.values.byName(data["t"]);
    switch (type) {
      case MessageTypes.friendRequest:
        {
          Boxes.instance.friendRequests.put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.bill:
        {
          Boxes.instance.bills.put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.payment:
        {
          Boxes.instance.payments.put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.chat:
        {
          Boxes.instance.messages.put(data["data"]["id"], data["data"]);
          var chatSource = Node.fromJson(
            Boxes.instance.friends.get(data["data"]["sd"])!,
          ); // that will crash
          chatSource.messages?.add(data["data"]["id"]);
          Boxes.instance.friends.put(chatSource.id, chatSource.toLocal());
          break;
        }
    }
  }

  // ============================================================ RENDER ============================================================ //

  @override
  Widget build(BuildContext context) {
    return _page ?? const LoadingPage();
  }
}
