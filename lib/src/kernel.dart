import 'dart:convert';

import 'package:dartsv/dartsv.dart';
import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'render_objects.dart';
import 'dart:async';
import 'render_pages.dart';

import 'package:hive/hive.dart';

import 'scratch.dart';


class Down4 extends StatefulWidget {
  const Down4({Key? key}) : super(key: key);

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
  states _state = states.loading;
  Identifier? _id;
  Base64Image? _image;
  Name? _name;
  String _input = "";
  Node? _node;
  Map<String, Box?> _boxes = {};
  Map<Identifier, Map<Identifier, Palette3>> _palettes = {};
  Map<Identifier, Map<Identifier, ChatMessage>> _messages = {};

  //=======================================//

  void _todo() {
    print("TODO");
  }

  void _todoID(Identifier id) {
    print("TODO: ID={$id}");
  }

  void _initUser(Map<String, String> info) {
    setState(() {
      _name = info['name'];
      _image = info['image'];
      _id = info['id'];
      //_id = sha1(utf8.encode(info['image']! + info['name']!)).toString();

      _palettes.addAll({
        "jeff": Palette3(
          node: Node(t: NodeTypes.usr, nm: "Jeff", id: "jeff", im: p),
          imPress: _selectPalette,
          bodyPress: _selectPalette,
          goPress: _todoID,
        ),
        "andrew": Palette3(
          node: Node(t: NodeTypes.usr, nm: "Andrew", id: "andrew", im: p),
          imPress: _selectPalette,
          bodyPress: _selectPalette,
          goPress: _todoID,
        )
      });
      _state = states.home;
    });
  }

  Future<void> _loadBox(String boxName) async {
    _boxes[boxName] = await Hive.openBox(boxName);
  }

  void _addFriends(Map<Identifier, Node> friends) {
    _boxes["Friends"]?.putAll(friends);
  }

  void _putState(states s) {
    setState(() => _state = s);
  }

  void _selectPalette(String at, Identifier id) {
    setState(() {
      _palettes[at]?[id] = _palettes[at]?[id]?.invertedSelection();
    });
  }

  void _selectMessage(String at, Identifier id) {
    setState(() {
      _messages[at]![id] = _messages[at]![id]!.invertedSelection();
    });
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

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  // Down4 utility functions
  Map<Identifier, Palette3>? _selectedPalettes(String at) {
    Map<Identifier, Palette3>? niga =  _palettes[at];
    niga?.removeWhere((key, value) => !value!.selected);
    return niga;
  }

  List<ChatMessage> _selectedMessages() {
    return liveChat.values.where((msg) => msg.selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case states.loading:
        return const LoadingPage();

      case states.userCreation:
        return UserCreationPage(callBack: _initUser);

      case states.welcome:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.home:
        return PalettePage(
            paletteList: PaletteList(palettes: livePalette.values.toList()),
            console: Console(
              topButtons: [
                ConsoleButton(name: "Hyperchat", onPress: _todo),
                ConsoleButton(name: "Money", onPress: _todo),
              ],
              bottomButtons: [
                ConsoleButton(name: "Browse", onPress: _todo),
                ConsoleButton(
                    name: "Add Friend",
                    onPress: () => setState(() {
                          livePalette = {};
                          _state = states.addFriend;
                        })),
                ConsoleButton(name: "Favorite", onPress: _todo)
              ],
            ));

      case states.money:
        return const Center(
            child: Text(
          "Not yet implanted",
          textDirection: TextDirection.ltr,
        ));

      case states.addFriend:
        return AddFriendPage(
            myID: _id!,
            paletteList: PaletteList(palettes: livePalette.values.toList()),
            console: Console(
              placeHolder: "@Search",
              inputCallBack: (text) => setState(() => _input = text),
              topButtons: [
                ConsoleButton(name: "Search", onPress: _todo),
                ConsoleButton(name: "Add", onPress: _todo)
              ],
              bottomButtons: [
                ConsoleButton(
                    name: "Back",
                    onPress: () async => _loadLocalPalettes(
                        friendIDs, () => _putState(states.home))),
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
