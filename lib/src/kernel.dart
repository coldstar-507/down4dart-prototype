import 'dart:convert';

import 'package:dartsv/dartsv.dart';
import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'render_objects.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'render_pages.dart';

import 'package:hive/hive.dart';

import 'scratch.dart';

Future<String> getLocalDatabasePath() async {
  var dir = await getApplicationDocumentsDirectory();
  var theDir = await dir.create(recursive: true);
  var dbPath = join(theDir.path, 'down4.db');
  return dbPath;
}

Future<Database> getLocalDatabase() async {
  String dbPath = await getLocalDatabasePath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  return db;
}

class Down4 extends StatefulWidget {
  final userStore = StoreRef<String, String>.main();
  final keyStore = StoreRef<String, List<Identifier>>.main();
  final messageStore = StoreRef<Identifier, Down4Message>.main();
  final nodeStore = StoreRef<Identifier, Node>.main();
  final reactionStore = StoreRef<Identifier, Reaction>.main();
  final Database localDatabase;
  


  Down4({Key? key, required this.localDatabase}) : super(key: key);

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
  states theState = states.loading;

  Identifier? myID;
  Base64Image? myImage;
  Name? myName;

  String textInput = "";

  List<Map<String, Node>> nodes = [];
  Map<Identifier, ChatMessage> liveChat = {};
  Map<Identifier, Palette3> livePalette = {};

  void _todo() {
    print("TODO");
  }

  void _todoID(Identifier id) {
    print("TODO: ID={$id}");
  }

  void _initUser(Map<String, String> map) {
    setState(() {
      myName = map['name'];
      myImage = map['image'];
      myID = sha1(utf8.encode(map['image']! + map['name']!)).toString();

      livePalette = {
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
      };

      theState = states.home;
    });
  }

  void _addFriends(List<Node> friends) async {
    var friendBox = await Hive.openBox('friends');
  }

  void _putState(states s) {
    setState(() => theState = s);
  }

  void _selectPalette(Identifier id) {
    setState(() {
      livePalette[id] = livePalette[id]!.invertedSelection();
    });
  }

  void _selectMessage(Identifier id) {
    setState(() {
      liveChat[id] = liveChat[id]!.invertedSelection();
    });
  }

  Future<void> _loadLocalPalettes(List<Identifier> ids,
      [void Function()? cb]) async {
    List<Node?> nodes =
        await widget.nodeStore.records(ids).get(widget.localDatabase);

    for (var node in nodes) {
      node != null
          ? livePalette[node.id] = Palette3(
              node: node,
              selected: false,
              imPress: _selectPalette,
              bodyPress: _selectPalette,
              goPress: _todoID,
            )
          : print("No palette to load :(");
    }

    cb?.call();
  }

  Future<void> _loadLocalMessages(List<Identifier> ids,
      [void Function()? cb]) async {
    List<Down4Message?> messages =
        await widget.messageStore.records(ids).get(widget.localDatabase);

    for (var message in messages) {
      message != null
          ? liveChat[message.id] = ChatMessage(
              message: message,
              myMessage: myID == message.sd,
              select: _selectMessage,
            )
          : print("There is no message to load");
    }
    cb?.call();
  }

  Future<void> _loadHome() async {
    Future<bool> loadUser() async {
      var userRecords = await widget.userStore
          .records(['myID', 'myImage', 'myName']).get(widget.localDatabase);
      myID = userRecords[0];
      myImage = userRecords[1];
      myName = userRecords[2];

      if (myID == null) return false;
      return true;
    }

    loadIdentifiers() async {
      var records = await widget.keyStore.records([
        'savedMessageIDs',
        'chatMessageIDs',
        'reactionIDs',
        'friendIDs',
        'nodeIDs',
        'assetIDs'
      ]).get(widget.localDatabase);

      savedMessageIDs = records[0] ?? [];
      chatMessageIDs = records[1] ?? [];
      reactionIDs = records[2] ?? [];
      friendIDs = records[3] ?? [];
      nodeIDs = records[4] ?? [];
      assetIDs = records[5] ?? [];
    }

    if (await loadUser()) {
      await loadIdentifiers();
      await _loadLocalPalettes(friendIDs, () => _putState(states.home));
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
  List<Palette3> _selectedPalettes() {
    return livePalette.values.where((palette) => palette.selected).toList();
  }

  List<ChatMessage> _selectedMessages() {
    return liveChat.values.where((msg) => msg.selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    switch (theState) {
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
                          theState = states.addFriend;
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
            myID: myID!,
            paletteList: PaletteList(palettes: livePalette.values.toList()),
            console: Console(
              placeHolder: "@Search",
              inputCallBack: (text) => setState(() => textInput = text),
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
