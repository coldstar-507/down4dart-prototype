import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'render_objects.dart';
import 'dart:convert';

class PalettePage extends StatelessWidget {
  final PaletteList paletteList;
  final Console console;
  const PalettePage(
      {required this.paletteList, required this.console, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Container(
                color: PinkTheme.backGroundColor,
                child: Column(children: [paletteList, console]))));
  }
}

class MessagePage extends StatelessWidget {
  final MessageList messageList;
  final Console console;
  const MessagePage(
      {required this.messageList, required this.console, Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(16.0),
        color: PinkTheme.backGroundColor,
        child: Column(
          children: [messageList, console],
        ));
  }
}

class AddFriendPage extends StatelessWidget {
  final Identifier myID;
  final PaletteList paletteList;
  final Console console;
  const AddFriendPage(
      {required this.myID,
      required this.paletteList,
      required this.console,
      Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Container(
      color: PinkTheme.backGroundColor,
      child: Stack(
        children: [
          Container(
              padding: const EdgeInsets.all(16.0),
              child: QrImage(data: myID, foregroundColor: PinkTheme.qrColor)),
          Column(children: [paletteList, console]),
        ],
      ),
    )));
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: const Center(child: Text("Loading...")),
    );
  }
}

enum NodeViews { messages, childs, parents, admins }

class NodePage extends StatefulWidget {
  final Node node;
  const NodePage({required this.node, Key? key}) : super(key: key);
  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  NodeViews view;
  _NodePageState({this.view = NodeViews.messages});
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class PaletteMakerPage extends StatefulWidget {
  void Function(Map<String, Map<String, String>>) kernelInfoCallBack;
  bool makingUser;
  String? userID;
  PaletteMakerPage(
      {required this.kernelInfoCallBack,
      this.makingUser = false,
      this.userID,
      Key? key})
      : super(key: key);

  @override
  State<PaletteMakerPage> createState() => _PaletteMakerPageState();
}

class _PaletteMakerPageState extends State<PaletteMakerPage> {
  Map<String, Map<String, String>> infos = {};
  late String at;
  late String currentConsole;
  late Map<String, Console> consoles;

  @override
  void initState() {
    super.initState();
    if (widget.makingUser) {
      currentConsole = "user";
      at = "user";
      infos["user"] = {"id": ""};
    }
    consoles = {
      "user": Console(
        textInputType: TextInputType.phone,
        inputCallBack: (text) => infos["user"]!["phone"] = text,
        placeHolder: "and your phone number.",
        bottomButtons: [
          ConsoleButton(name: "Camera", onPress: () => print("Todo")),
          ConsoleButton(
              name: "Proceed", onPress: () => widget.kernelInfoCallBack(infos))
        ],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PaletteMakerList(
              palettes: infos[at]!
                  .map((key, value) => MapEntry(key,
                      PaletteMaker(infoCallBack: (info) => infos[at] = info)))
                  .values
                  .toList()),
          consoles[currentConsole]!
        ],
      ),
    );
  }
}
