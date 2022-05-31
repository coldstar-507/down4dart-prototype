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

enum NodeViews { messages, childs, parents, admins }

class _Down4State extends State<Down4> {
  // ============================================================ VARIABLES ============================================================ //
  States _state = States.loading;
  String _kernelInput = "";
  Node? _user;
  MoneyInfo? _moneyInfo;
  UserCredential? _credential;
  // Map<String, Map<Identifier, Palette3>> _palettes = {
  //   "Friends": {},
  //   "AddFriend": {}
  // };
  // Map<String, Map<Identifier, ChatMessage>> _messages = {};
  // var _modes = {
  //   "Currencies": {
  //     "l": ["CAD", "Satoshis"],
  //     "i": 0
  //   },
  //   "Payment": {
  //     "l": ["Each", "Split"],
  //     "i": 0
  //   },
  //   "Node": {"l": [], "i": null}
  // };

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    _processMessageQueue();
    _anonymousLogin();
    _loadTokenChangeListener();
    _loadHome();
  }

  void _onMessage() {
    FirebaseMessaging.onMessage.listen((event) async {
      final d = event.data;
      Down4Media? m;
      if (d["id"] != "") {
        m = await r.getMessageMedia(d["id"]);
      }
    });
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
      _putState(States.home);
    } else {
      // returns false if user hasn't been initialized
      _putState(States.userCreation);
    }
  }

  Future<bool> _initUser(Map<String, dynamic> info) async {
    String uid = info['id'];
    Uint8List imageData = info['imagedata'];

    Down4Media image = Down4Media(
      id: sv.sha1(uid.codeUnits + imageData).toString(),
      data: imageData,
    );
    await image.generateThumbnail();

    _user = Node(
      type: NodeTypes.usr,
      id: uid,
      image: image,
      name: info['name'],
      lastName: info['lastname'],
    );

    if (!await r.initUser(jsonEncode(_user))) {
      return false;
    }

    image.localSave();
    _uploadDown4Media(image);

    _moneyInfo = await r.initUserMoney(uid);

    Boxes.instance.user.put('user', jsonEncode(_user));
    Boxes.instance.user.put('money', jsonEncode(_moneyInfo));

    return true;
  }

  void _putState(States s) {
    setState(() => _state = s);
  }

  Future<void> _parseMessageData(final data) async {
    final type = MessageTypes.values.byName(data["t"]);
    switch (type) {
      case MessageTypes.fr:
        {
          Boxes.instance.friendRequests.put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.b:
        {
          Boxes.instance.bills.put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.p:
        {
          Boxes.instance.payments.put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.m:
        {
          Boxes.instance.messages.put(data["data"]["id"], data["data"]);
          var chatSource = Node.fromJson(
            Boxes.instance.friends.get(data["data"]["sd"])!,
          ); // that will crash
          chatSource.messages?.add(data["data"]["id"]);
          Boxes.instance.friends.put(chatSource.id, chatSource.toJson());
          break;
        }
    }
  }

  Future<UploadTask?> _uploadDown4Media(Down4Media media) async {
    if (media.data != null) {
      UploadTask uploadTask;
      Reference ref = FirebaseStorage.instance.ref().child(media.id);
      uploadTask = ref.putData(
        base64Decode(media.data!),
        SettableMetadata(customMetadata: media.metadata.toJson()),
      );
      return Future.value(uploadTask);
    }
    return null;
  }
  // ============================================================ DOWN4 ============================================================ //

  void _sendMessage(MessageRequest message) => print("TODO");

  void _searchFriends(Identifier nameID) {
    setState(() {
      _palettes["AddFriend"]![nameID] = SingleActionPalette(
        at: "AddFriend",
        node: Node(
          type: NodeTypes.usr,
          id: nameID,
          name: nameID,
          image: Down4Media(
            id: "id",
            usePlaceHolder: true,
            metadata: Down4MediaMetadata(owner: nameID, isVideo: false),
          ),
        ),
        imPress: _selectPalette,
        bodyPress: _selectPalette,
        goPress: (s, s_) => _todo(),
      );
    });
  }

  void _addFriends(List<Node> friends) {
    for (final friend in friends) {
      final palette = SingleActionPalette(
          node: friend,
          at: "Friends",
          imPress: _selectPalette,
          bodyPress: _selectPalette);
      _palettes["Friends"]![friend.id] = palette;
      Boxes.instance.friends.put(friend.id, jsonEncode(friend));
    }
    setState(() {});
  }

  // List<Palette3> _palettesAt(String at) {
  //   var paletteList = _palettes[at]?.values.toList();
  //   return paletteList ?? [];
  // }

  // List<Palette3> _reversedPalettesAt(String at) {
  //   var paletteList = _palettes[at]?.values.toList().reversed.toList();
  //   return paletteList ?? [];
  // }

  // void _selectPalette(String at, Identifier id) {
  //   setState(() {
  //     _palettes[at]![id] = _palettes[at]![id]!.invertedSelection();
  //   });
  // }

  // void _selectMessage(String at, Identifier id) {
  //   setState(() {
  //     _messages[at]![id] = _messages[at]![id]!.invertedSelection();
  //   });
  // }

  // Map<Identifier, Node> _selectedNodes(String at) {
  //   var sp = Map<Identifier, Palette3>.from(_palettes[at]!);
  //   sp.removeWhere((key, value) => !value.selected);
  //   return sp.map((key, value) => MapEntry(key, value.node));
  // }

  // List<Palette3> _selectedPalettes(String at) {
  //   return _selectedNodes(at)
  //       .values
  //       .map((node) => Palette3(at: at, node: node))
  //       .toList();
  // }

  // Map<Identifier, Down4Message> _selectedMessages(String at) {
  //   var cm = Map<Identifier, ChatMessage>.from(_messages[at]!);
  //   cm.removeWhere((key, value) => !value.selected);
  //   return cm.map((key, value) => MapEntry(key, value.message));
  // }

  // void _todo() => print("TODO");

  // void _unselectedSelectedPalettes(String at) {
  //   _palettes[at] = _palettes[at]!.map((key, value) => value.selected
  //       ? MapEntry(key, value.invertedSelection())
  //       : MapEntry(key, value));
  //   setState(() => {});
  // }

  // Map<Identifier, Down4Message> _localChat(Node node) {
  //   Map<String, Down4Message> messages = {};
  //   final List<Identifier>? ids = node.messages;
  //   if (ids == null) return messages;
  //   for (final id in ids) {
  //     messages[id] =
  //         Down4Message.fromJson(jsonDecode(Boxes.instance.messages.get(id)));
  //   }
  //   return messages;
  // }

  // ============================================================ RENDER ============================================================ //

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case States.loading:
        return const LoadingPage();

      case States.userCreation:
        return UserMakerPage(
          cameras: widget.cameras,
          initUser: _initUser,
          success: () => _putState(States.welcome),
        );

      case States.welcome:
        return WelcomePage(
          mnemonic: _moneyInfo!.mnemonic,
          userInfo: _user!,
          understood: () => _putState(States.home),
        );

      case States.chat:
        return const Center(
          child: Text(
            "Not yet implanted",
            textDirection: TextDirection.ltr,
          ),
        );

      case States.hyperchat:
        return HyperchatPage(
          self: _user!,
          sendInitialMessage: _sendMessage,
          back: () => _putState(States.home),
          palettes: _selectedPalettes("Friends"),
          cameras: widget.cameras,
          afterFirstMessageCallBack: () => _putState(States.chat),
        );

      case States.home:
        return PalettePage(
            palettes: _palettesAt("Friends"),
            console: Console(
              inputs: [
                InputObjects(
                    inputCallBack: (text) => _kernelInput = text,
                    placeHolder: ":)")
              ],
              topButtons: [
                ConsoleButton(
                    name: "Hyperchat",
                    onPress: () {
                      final nodes = _selectedNodes('Friends');
                      _palettes['Hyperchat'] = nodes.map((id, node) =>
                          MapEntry(id, SingleActionPalette(at: "Hyperchat", node: node)));
                      _putState(States.hyperchat);
                    }),
                ConsoleButton(
                    name: "Money",
                    onPress: () {
                      _palettes['Money'] = _selectedNodes("Friends").map(
                          (key, node) =>
                              MapEntry(key, SingleActionPalette(at: "Money", node: node)));
                      _putState(States.money);
                    }),
              ],
              bottomButtons: [
                ConsoleButton(name: "Browse", onPress: _todo),
                ConsoleButton(
                    name: "Add Friend",
                    onPress: () => setState(() {
                          _state = States.addFriend;
                        })),
                ConsoleButton(isSpecial: true, name: "Ping", onPress: _todo)
              ],
            ));

      case States.money:
        final currencies = _modes["Currencies"]!["l"] as List<String>;
        final iCurrencies = _modes["Currencies"]!["i"] as int;
        final payment = _modes["Payment"]!["l"] as List<String>;
        final iPayment = _modes["Payment"]!["i"] as int;
        return PalettePage(
            palettes: _selectedPalettes("Friends"),
            console: Console(
              inputs: [
                InputObjects(
                    inputCallBack: (text) => _kernelInput = text,
                    placeHolder: "\$",
                    type: TextInputType.number)
              ],
              topButtons: [
                ConsoleButton(name: "Pay", onPress: _todo),
                ConsoleButton(name: "Bill", onPress: _todo)
              ],
              bottomButtons: [
                ConsoleButton(
                    name: "Back",
                    onPress: () {
                      _palettes['Money'] = {};
                      _putState(States.home);
                    }),
                ConsoleButton(
                    name: currencies[iCurrencies],
                    isMode: true,
                    onPress: () {
                      setState(() {
                        _modes["Currencies"]!["i"] =
                            (iCurrencies + 1) % currencies.length;
                      });
                    }),
                ConsoleButton(
                    name: payment[iPayment],
                    isMode: true,
                    onPress: () {
                      setState(() {
                        _modes["Payment"]!["i"] =
                            (iPayment + 1) % payment.length;
                      });
                    })
              ],
            ));

      case States.addFriend:
        return AddFriendPage(
          self: _user!,
          addCallback: _addFriends,
          backCallback: () => _putState(States.home),
        );
      // return AddFriendPage(
      //   myID: _user!.id,
      //   paletteList: PaletteList(palettes: _reversedPalettesAt("AddFriend")),
      //   console: Console(
      //     inputs: [
      //       InputObjects(
      //           inputCallBack: (text) => _kernelInput = text,
      //           placeHolder: "@Search")
      //     ],
      //     topButtons: [
      //       ConsoleButton(
      //           name: "Search", onPress: () => _searchFriends(_kernelInput)),
      //       ConsoleButton(
      //           name: "Add",
      //           onPress: () {
      //             _addFriends(_selectedNodes("AddFriend"));
      //             _unselectedSelectedPalettes("AddFriend");
      //           })
      //     ],
      //     bottomButtons: [
      //       ConsoleButton(
      //           name: "Back",
      //           onPress: () {
      //             _palettes["AddFriend"] = {};
      //             _putState(States.home);
      //           }),
      //       ConsoleButton(name: "Scan", onPress: () => print("SCAN")),
      //       ConsoleButton(name: "Forward", onPress: () => print("FORWARD"))
      //     ],
      //   ),
      // );

      case States.node:
        return Container(
          color: PinkTheme.backGroundColor,
          child: Column(
            children: [],
          ),
        );

      case States.map:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case States.nodeCreation:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case States.snip:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case States.cam:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));
    }
  }
}
