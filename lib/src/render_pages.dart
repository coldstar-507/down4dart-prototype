import 'package:flutter/material.dart';
import 'render_objects.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class NodePage extends StatelessWidget {
  final List<Palette> palettes;
  final Console console;
  NodePage({required this.palettes, required this.console});

  @override
  Widget build(BuildContext context) {
    return Down4Container(
      padding: 16.0,
      backgroundColor: PinkTheme.backGroundColor,
      child: Column(
        children: [
          ListView.separated(
              itemBuilder: (c, i) => palettes[i],
              separatorBuilder: (c, i) => Container(height: 16.0),
              itemCount: palettes.length),
          Expanded(child: Container()),
          console
        ],
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Down4Container(
      backgroundColor: PinkTheme.backGroundColor,
      child: Center(child: Text("Loading...")),
    );
  }
}

class UserCreationPage extends StatefulWidget {
  void Function(Map<String, String>) callBack;
  UserCreationPage({Key? key, required this.callBack}) : super(key: key);
  @override
  State<UserCreationPage> createState() => _UserCreationPageState();
}

class _UserCreationPageState extends State<UserCreationPage> {
  Map<String, String> info = {};

  Widget build(BuildContext context) {
    return Down4Container(
        padding: 16.0,
        backgroundColor: PinkTheme.backGroundColor,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Spacer(),
          Down4Container(
              border: true,
              borderColor: PinkTheme.headerColor,
              borderWidth: 2.0,
              height: Palette.height + 4 + 1,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.ltr,
                  children: [
                    GestureDetector(
                        onTap: () async {
                          FilePickerResult? r = await FilePicker.platform
                              .pickFiles(
                                  type: FileType.image,
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
                            backgroundColor: PinkTheme.black,
                            width: Palette.height + 1,
                            child: Center(
                                child: info['image'] == null
                                    ? Image.asset(
                                        'lib/src/assets/picture_place_holder.png')
                                    : Image.memory(base64Decode(info['image']!),
                                        gaplessPlayback: true)))),
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
                                        bottom: (Palette.height + 1) / 2)),
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
