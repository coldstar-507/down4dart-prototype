import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'render_objects.dart';
import 'dart:convert';
import 'camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PalettePage extends StatelessWidget {
  final PaletteList paletteList;
  final Console console;
  const PalettePage(
      {required this.paletteList, required this.console, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        color: PinkTheme.backGroundColor,
        child: Column(children: [paletteList, console]));
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
    return Container(
      color: PinkTheme.backGroundColor,
      child: Stack(
        children: [
          Container(
              padding: const EdgeInsets.all(16.0),
              child: QrImage(data: myID, foregroundColor: PinkTheme.qrColor)),
          Column(children: [paletteList, console]),
        ],
      ),
    );
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

class UserMakerPage extends StatefulWidget {
  final void Function(Map<String, dynamic>) kernelCallBack;
  final List<CameraDescription> cameras;
  const UserMakerPage(
      {required this.kernelCallBack, required this.cameras, Key? key})
      : super(key: key);

  @override
  _UserMakerPageState createState() => _UserMakerPageState();
}

enum UserMakerStates { phone, camera, personal }

class _UserMakerPageState extends State<UserMakerPage> {
  Map<String, dynamic> infos = {
    'id': '',
    'name': '',
    'image': '',
    'lastName': '',
    'phone': '',
  }; // "user" redondance because of paletteMaker
  dynamic console;
  dynamic palette;

  @override
  void initState() {
    super.initState();
    _loadPhoneConsole();
    _loadPaletteMaker();
  }

  void _loadPalette() {
    setState(() {
      palette = Palette3(
          at: "",
          node: Node(
              t: NodeTypes.usr,
              id: infos['id'],
              nm: infos['name'],
              ln: infos['lastName'],
              im: infos['image']));
    });
  }

  void _loadPaletteMaker() {
    print(infos);
    setState(() {
      palette = UserPaletteMaker(
          infoCallBack: (info) {
            infos = info;
            _loadPaletteMaker();
          },
          info: infos);
    });
  }

  void _loadPhoneConsole() {
    setState(() {
      console = Console(
        inputs: [
          InputObjects(
              type: TextInputType.phone,
              inputCallBack: (text) => infos["phone"] = text,
              placeHolder: "Valid phone number for identification.")
        ],
        bottomButtons: [
          ConsoleButton(name: "Camera", onPress: _loadCameraConsole),
          ConsoleButton(
              name: "Proceed",
              onPress: () {
                print(infos);
                print("""
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                        TODO VERIFY

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
              """);
                _loadPersonalConsole();
                _loadPalette();
              })
        ],
      );
    });
  }

  void _loadCameraConsole() {
    setState(() {
      console = CameraConsole(
          cameras: widget.cameras,
          cameraCallBack: (path) async {
            if (path != null) {
              final unCompressedBytes = File(path).readAsBytesSync();
              final compressedBytes =
                  await FlutterImageCompress.compressWithFile(path,
                      minHeight: 520, // palette height
                      minWidth: 520, // palette height
                      quality: 40);
              print("""
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


                  Uncompressed image size = ${unCompressedBytes.length}
                  Compressed image size = ${compressedBytes?.length}


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            """);
              infos["image"] = base64Encode(compressedBytes!);
            }
            _loadPaletteMaker();
            _loadPhoneConsole();
          });
    });
  }

  void _loadPersonalConsole() {
    setState(() {
      console = Console(
        inputs: [
          InputObjects(
            inputCallBack: (value) {
              infos["name"] = value;
              _loadPalette();
            },
            placeHolder: "First Name",
          ),
          InputObjects(
              inputCallBack: (value) {
                infos["lastName"] = value;
                _loadPalette();
              },
              placeHolder: "(Last Name)")
        ],
        bottomButtons: [
          ConsoleButton(
              name: "Bring me in!",
              onPress: () {
                if (infos["name"] != null && infos["name"] != "") {
                  widget.kernelCallBack(infos);
                }
              })
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          palette ?? Container(),
          const SizedBox(height: 16.0),
          console ?? Container()
        ],
      ),
    );
  }
}

// TODO

class PaletteMakerPage extends StatefulWidget {
  final void Function(Map<String, Map<String, String?>>) kernelInfoCallBack;
  final String? userID;
  final List<CameraDescription> cameras;
  const PaletteMakerPage(
      {required this.kernelInfoCallBack,
      required this.cameras,
      this.userID,
      Key? key})
      : super(key: key);

  @override
  State<PaletteMakerPage> createState() => _PaletteMakerPageState();
}

class _PaletteMakerPageState extends State<PaletteMakerPage> {
  Map<String, Map<String, dynamic>> infos = {};
  late String at;
  late String currentConsole;
  late Map<String, dynamic> consoles;

  void _infoCallBack(String key, Map<String, dynamic> info) {
    setState(() {
      infos[key] = info;
      print("Info update: $info");
    });
  }

  @override
  void initState() {
    super.initState();
    consoles["camera"] = CameraConsole(
      cameras: widget.cameras,
      cameraCallBack: (path) async {
        if (path != null) {
          infos[at]!["image"] = path;
          final unCompressedBase64Image =
              base64Encode(File(path).readAsBytesSync());
          final compressedImage =
              await FlutterImageCompress.compressWithFile(path,
                  minHeight: 520, // palette height
                  minWidth: 520, // palette height
                  quality: 40);
          if (compressedImage != null) {
            final base64Image = base64Encode(compressedImage);
            print("""
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


                  Uncompressed image size = ${unCompressedBase64Image.length}
                  Compressed image size = ${base64Image.length}


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            """);
          }
          setState(() {
            currentConsole = "user";
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print("""
+++++++++++++++++++++++++++++++++++++++++++++

                REPAINTING

+++++++++++++++++++++++++++++++++++++++++++++
""");
    return Container(
      color: PinkTheme.backGroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PaletteMakerList(
              palettes: infos
                  .map((key, value) => MapEntry(
                      key,
                      PaletteMaker(
                          infoCallBack: _infoCallBack,
                          infoKey: key,
                          info: infos[key] ?? {})))
                  .values
                  .toList()),
          consoles[currentConsole]!
        ],
      ),
    );
  }
}
