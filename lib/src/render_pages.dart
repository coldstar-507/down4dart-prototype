import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'render_objects.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class PalettePage extends StatelessWidget {
  final PaletteList paletteList;
  final Console console;
  const PalettePage(
      {required this.paletteList, required this.console, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Container(
            color: PinkTheme.backGroundColor,
            child: Column(
              children: [paletteList, console],
            )));
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
    return Down4Container(
        padding: 16.0,
        backgroundColor: PinkTheme.backGroundColor,
        child: Column(
          children: [messageList, const Spacer(), console],
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
            child: Down4Container(
      backgroundColor: PinkTheme.backGroundColor,
      child: Stack(
        children: [
          QrImage(data: myID, foregroundColor: PinkTheme.qrColor),
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
    return const Down4Container(
      backgroundColor: PinkTheme.backGroundColor,
      child: Center(child: Text("Loading...")),
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

class UserCreationPage extends StatefulWidget {
  final void Function(Map<String, String>) callBack;
  const UserCreationPage({Key? key, required this.callBack}) : super(key: key);
  @override
  State<UserCreationPage> createState() => _UserCreationPageState();
}

class _UserCreationPageState extends State<UserCreationPage> {
  Map<String, String> info = {};

  @override
  Widget build(BuildContext context) {
    return Down4Container(
        padding: 16.0,
        backgroundColor: PinkTheme.backGroundColor,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Spacer(),
          Down4Container(
              height: Palette.height,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.ltr,
                  children: [
                    GestureDetector(
                        onTap: () async {
                          FilePickerResult? r = await FilePicker.platform
                              .pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpg', 'png'],
                                  withData: true);
                          if (r != null) {
                            setState(() {
                              info['image'] =
                                  base64Encode(r.files.single.bytes!);
                            });
                          }
                        },
                        child: Down4Container(
                            backgroundColor: PinkTheme.headerColor,
                            width: Palette.height,
                            padding: 1.5,
                            child: Center(
                                child: info['image'] == null
                                    ? Image.asset(
                                        'lib/src/assets/picture_place_holder.png',
                                        fit: BoxFit.cover,
                                      )
                                    : Image.memory(
                                        base64Decode(info['image']!),
                                        gaplessPlayback: true,
                                        fit: BoxFit.cover,
                                      )))),
                    Expanded(
                        child: Down4Container(
                            paddingLeft: 10.0,
                            paddingTop: 10.0,
                            backgroundColor: PinkTheme.headerColor,
                            child: TextField(
                                textAlignVertical: TextAlignVertical.top,
                                decoration: const InputDecoration(
                                    hintText: "Pick a name and an image!",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.only(
                                        bottom: (Palette.height) / 2)),
                                textDirection: TextDirection.ltr,
                                onChanged: ((value) =>
                                    setState(() => info['name'] = value))))),
                  ])),
          const Spacer(),
          Console(bottomButtons: [
            ConsoleButton(
                name: "Ok !",
                onPress: () {
                  if (info['image'] != null && info['name'] != null) {
                    print("Lets go");
                    widget.callBack(info);
                  } else {
                    print("Need name and image!");
                  }
                })
          ])
        ]));
  }
}
