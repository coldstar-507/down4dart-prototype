import 'dart:convert';
import 'dart:async';
import 'dart:ffi';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dartsv/dartsv.dart' as sv;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'render_pages.dart';
import 'data_objects.dart';
import 'render_objects.dart';
import 'scratch.dart';

class Down4 extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Box messageQueue;
  const Down4({required this.cameras, required this.messageQueue, Key? key})
      : super(key: key);

  @override
  State<Down4> createState() => _Down4State();
}

enum States {
  loading,
  userCreation,
  welcome,
  home,
  money,
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
  Identifier? _id, _uid;
  Down4Media? _image;
  String? _name, _lastName, _phone;
  String _input = "";
  Node? _node;
  Map<String, Box> _boxes = {};
  Map<String, Map<Identifier, Palette3>> _palettes = {
    "Friends": {},
    "AddFriend": {}
  };
  Map<String, Map<Identifier, ChatMessage>> _messages = {};
  var _modes = {
    "Currencies": {
      "l": ["CAD", "Satoshis"],
      "i": 0
    },
    "Payment": {
      "l": ["Each", "Split"],
      "i": 0
    },
    "Node": {"l": [], "i": null}
  };

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    for (final messageData in widget.messageQueue.values) {
      _parseMessageData(messageData);
    }
    widget.messageQueue.clear();
    _loadHome();
  }

  Future<void> _loadHome() async {
    Future<bool> loadUser() async {
      _id = (await _box("User")).get("id");
      _image = (await _box("User")).get("image");
      _name = (await _box("User")).get("name");
      if (_id == null) return false;
      return true;
    }

    if (await loadUser()) {
      _putState(States.home);
    } else {
      // returns false if user hasn't been initialized
      _putState(States.userCreation);
    }
  }

  Future<Box> _box(String boxName) async {
    return _boxes[boxName] ?? (_boxes[boxName] = await Hive.openBox(boxName));
  }

  void _todo() {
    print("TODO");
  }

  void _todoID(String at, Identifier id) {
    print("TODO: at=$at, id=$id");
  }

  Future<void> _initUser(Map<String, dynamic> info) async {
    String uid = info['id'] as String;
    String base64Image = info['image'] as String;
    String mediaID =
        sv.sha1(uid.codeUnits + base64Decode(base64Image)).toString();

    Down4Media media = Down4Media(
        id: mediaID,
        metadata: Down4MediaMetadata(isVideo: false, owner: uid),
        data: base64Decode(base64Image));

    _uploadDown4Media(media);

    _name = info['name'];
    _lastName = info['lastName'];
    _image = info['image'];
    _uid = info['uid'];
    _phone = info['phone'];
    _state = States.home;

    setState(() {});
  }

  void _putState(States s) {
    setState(() => _state = s);
  }

  Future<void> _parseMessageData(final data) async {
    final t = MessageTypes.values.byName(data["t"]);
    switch (t) {
      case MessageTypes.fr:
        {
          (await _box("FriendRequest")).put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.b:
        {
          (await _box("Bills")).put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.p:
        {
          (await _box("Payments")).put(data["data"]["id"], data["data"]);
          break;
        }
      case MessageTypes.m:
        {
          (await _box("Messages")).put(data["data"]["id"], data["data"]);
          var chatSource =
              Node.fromJson((await _box("Friends")).get(data["data"]["sd"]));
          if (chatSource.msg != null) {
            chatSource.msg!.add(data["data"]["id"]);
          } else {
            chatSource.msg = [data["data"]["id"]];
          }
          (await _box("Friends")).put(chatSource.id, chatSource);
          break;
        }
    }
  }

  Future<UploadTask?> _uploadDown4Media(Down4Media media) async {
    if (media.data != null) {
      UploadTask uploadTask;
      Reference ref = FirebaseStorage.instance.ref().child(media.id);
      uploadTask = ref.putData(
          media.data!, SettableMetadata(customMetadata: media.jsonMetadata));
      return Future.value(uploadTask);
    }
    return null;
  }
  // ============================================================ DOWN4 ============================================================ //

  void _searchFriends(Identifier nameID) {
    setState(() {
      _palettes["AddFriend"]![nameID] = Palette3(
        at: "AddFriend",
        node: Node(t: NodeTypes.usr, id: nameID, nm: nameID, im: p),
        imPress: _selectPalette,
        bodyPress: _selectPalette,
        goPress: _go,
      );
    });
  }

  void _addFriends(Map<Identifier, Node> friends) {
    var asPalettes = friends.map((id, node) => MapEntry(
        id,
        Palette3(
            at: "Friends",
            node: node,
            imPress: _selectPalette,
            bodyPress: _selectPalette,
            goPress: _go)));
    _palettes["Friends"]?.addAll(asPalettes);
    _boxes["Friends"]?.putAll(friends);
  }

  List<Palette3> _paletteList(String at) {
    var paletteList = _palettes[at]!.values.toList();
    return paletteList;
  }

  List<Palette3> _reversedList(String at) {
    var paletteList = _palettes[at]!.values.toList().reversed.toList();
    return paletteList;
  }

  void _selectPalette(String at, Identifier id) {
    setState(() {
      _palettes[at]![id] = _palettes[at]![id]!.invertedSelection();
    });
  }

  void _selectMessage(String at, Identifier id) {
    setState(() {
      _messages[at]![id] = _messages[at]![id]!.invertedSelection();
    });
  }

  Map<Identifier, Node> _selectedNodes(String at) {
    var sp = Map<Identifier, Palette3>.from(_palettes[at]!);
    sp.removeWhere((key, value) => !value.selected);
    return sp.map((key, value) => MapEntry(key, value.node));
  }

  Map<Identifier, Down4Message> _selectedMessages(String at) {
    var cm = Map<Identifier, ChatMessage>.from(_messages[at]!);
    cm.removeWhere((key, value) => !value.selected);
    return cm.map((key, value) => MapEntry(key, value.message));
  }

  void _go(String at, Identifier p) {}

  void _snip(Map<Identifier, Palette3> friends) {}

  void _forwardPalettes(Map<Identifier, Palette3> palettes) {}

  void _forwardMessages(Map<Identifier, ChatMessage> messages) {}

  void _unselectedSelectedPalettes(String at) {
    _palettes[at] = _palettes[at]!.map((key, value) => value.selected
        ? MapEntry(key, value.invertedSelection())
        : MapEntry(key, value));
    setState(() => {});
  }

  Map<Identifier, Down4Message> _localChat(Node node) {
    Map<String, Down4Message> messages = {};
    final List<Identifier>? ids = node.msg;
    if (ids == null) return messages;
    for (final id in ids) {
      messages[id] = Down4Message.fromJson(_boxes["Messages"]?.get(id));
    }
    return messages;
  }

  // ============================================================ RENDER ============================================================ //

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case States.loading:
        return const LoadingPage();

      case States.userCreation:
        return UserMakerPage(
            cameras: widget.cameras, kernelCallBack: _initUser);

      case States.welcome:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case States.home:
        return PalettePage(
            paletteList: PaletteList(palettes: _paletteList("Friends")),
            console: Console(
              inputs: [
                InputObjects(
                    inputCallBack: (text) => _input = text, placeHolder: ":)")
              ],
              topButtons: [
                ConsoleButton(name: "Hyperchat", onPress: _todo),
                ConsoleButton(
                    name: "Money",
                    onPress: () {
                      _palettes['Money'] = _selectedNodes("Friends").map(
                          (key, node) =>
                              MapEntry(key, Palette3(at: "Money", node: node)));
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
            paletteList: PaletteList(palettes: _paletteList('Money')),
            console: Console(
              inputs: [
                InputObjects(
                    inputCallBack: (text) => _input = text,
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
            myID: _id!,
            paletteList: PaletteList(palettes: _reversedList("AddFriend")),
            console: Console(
              inputs: [
                InputObjects(
                    inputCallBack: (text) => _input = text,
                    placeHolder: "@Search")
              ],
              topButtons: [
                ConsoleButton(
                    name: "Search", onPress: () => _searchFriends(_input)),
                ConsoleButton(
                    name: "Add",
                    onPress: () {
                      _addFriends(_selectedNodes("AddFriend"));
                      _unselectedSelectedPalettes("AddFriend");
                    })
              ],
              bottomButtons: [
                ConsoleButton(
                    name: "Back",
                    onPress: () {
                      _palettes["AddFriend"] = {};
                      _putState(States.home);
                    }),
                ConsoleButton(name: "Scan", onPress: _todo),
                ConsoleButton(name: "Forward", onPress: _todo)
              ],
            ));

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
