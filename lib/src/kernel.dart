import 'dart:convert';
import 'package:dartsv/dartsv.dart';
import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'render_objects.dart';
import 'dart:async';
import 'render_pages.dart';
import 'package:camera/camera.dart';
import 'package:hive/hive.dart';

import 'scratch.dart';

class Down4 extends StatefulWidget {
  List<CameraDescription> cameras;
  Down4({required this.cameras, Key? key}) : super(key: key);

  @override
  State<Down4> createState() => _Down4State();
}

enum states {
  loading,
  userCreation,
  welcome,
  home,
  money,
  addFriend,
  chat,
  node,
  map,
  nodeCreation,
  snip,
  cam,
}

class _Down4State extends State<Down4> {
  // ============================================================ VARIABLES ============================================================ //
  states _state = states.loading;
  Identifier? _id;
  Base64Image? _image;
  Name? _name;
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
    }
  };

  // ============================================================ KERNEL ============================================================ //

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    Future<bool> loadUser() async {
      _id = _boxes["User"]?.get("id");
      _image = _boxes["User"]?.get("image");
      _name = _boxes["User"]?.get("name");
      if (_id == null) return false;
      return true;
    }

    await _loadBox("User");
    if (await loadUser()) {
      await _loadBox("Friends");
      _putState(states.home);
    } else {
      // returns false if user hasn't been initialized
      _putState(states.userCreation);
    }
  }

  Future<void> _loadBox(String boxName) async {
    _boxes[boxName] = await Hive.openBox(boxName);
  }

  void _todo() {
    print("TODO");
  }

  void _todoID(String at, Identifier id) {
    print("TODO: at=$at, id=$id");
  }

  void _initUser(Map<String, String> info) {
    setState(() {
      _name = info['name'];
      _image = info['image'];
      // _id = info['id'];
      _id = sha1(utf8.encode(info['image']! + info['name']!)).toString();
      _state = states.home;
    });
  }

  void _putState(states s) {
    setState(() => _state = s);
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

  // ============================================================ RENDER ============================================================ //

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case states.loading:
        return const LoadingPage();

      case states.userCreation:
        return PaletteMakerPage(
            cameras: widget.cameras,
            kernelInfoCallBack: (infos) => _initUser(infos["user"]!),
            makingUser: true);

      case states.welcome:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.home:
        return PalettePage(
            paletteList: PaletteList(palettes: _paletteList("Friends")),
            console: Console(
              placeHolder: ":)",
              inputCallBack: (text) => _input = text,
              topButtons: [
                ConsoleButton(name: "Hyperchat", onPress: _todo),
                ConsoleButton(
                    name: "Money",
                    onPress: () {
                      _palettes['Money'] = _selectedNodes("Friends").map(
                          (key, node) =>
                              MapEntry(key, Palette3(at: "Money", node: node)));
                      _putState(states.money);
                    }),
              ],
              bottomButtons: [
                ConsoleButton(name: "Browse", onPress: _todo),
                ConsoleButton(
                    name: "Add Friend",
                    onPress: () => setState(() {
                          _state = states.addFriend;
                        })),
                ConsoleButton(isSpecial: true, name: "Ping", onPress: _todo)
              ],
            ));

      case states.money:
        final currencies = _modes["Currencies"]!["l"] as List<String>;
        final iCurrencies = _modes["Currencies"]!["i"] as int;
        final payment = _modes["Payment"]!["l"] as List<String>;
        final iPayment = _modes["Payment"]!["i"] as int;
        return PalettePage(
            paletteList: PaletteList(palettes: _paletteList('Money')),
            console: Console(
              placeHolder: "\$",
              inputCallBack: (text) => _input = text,
              textInputType: TextInputType.number,
              topButtons: [
                ConsoleButton(name: "Pay", onPress: _todo),
                ConsoleButton(name: "Bill", onPress: _todo)
              ],
              bottomButtons: [
                ConsoleButton(
                    name: "Back",
                    onPress: () {
                      _palettes['Money'] = {};
                      _putState(states.home);
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
      case states.addFriend:
        return AddFriendPage(
            myID: _id!,
            paletteList: PaletteList(palettes: _reversedList("AddFriend")),
            console: Console(
              placeHolder: "@Search",
              inputCallBack: (text) => _input = text,
              topButtons: [
                ConsoleButton(
                    name: "Search", onPress: () => _searchFriends(_input)),
                ConsoleButton(
                    name: "Add",
                    onPress: () => _addFriends(_selectedNodes("AddFriend")))
              ],
              bottomButtons: [
                ConsoleButton(
                    name: "Back",
                    onPress: () {
                      _palettes["AddFriend"] = {};
                      _putState(states.home);
                    }),
                ConsoleButton(name: "Scan", onPress: _todo),
                ConsoleButton(name: "Forward", onPress: _todo)
              ],
            ));

      case states.chat:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.node:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.map:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.nodeCreation:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.snip:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.cam:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));
    }
  }
}
