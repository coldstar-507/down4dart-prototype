import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'render_objects.dart';
import 'dart:convert';
import 'camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dartsv/dartsv.dart' as sv;
import 'web_requests.dart' as r;

class PalettePage extends StatelessWidget {
  final List<SingleActionPalette> palettes;
  final Console console;
  const PalettePage({required this.palettes, required this.console, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4ColumnBackground(
        children: [PaletteList(palettes: palettes), console]);
  }
}

class HyperchatPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Node self;
  final List<SingleActionPalette> palettes;
  void Function(MessageRequest) sendInitialMessage;
  void Function() afterFirstMessageCallBack;
  void Function() back;
  HyperchatPage({
    required this.self,
    required this.sendInitialMessage,
    required this.back,
    required this.palettes,
    required this.cameras,
    required this.afterFirstMessageCallBack,
    Key? key,
  }) : super(key: key);

  @override
  _HyperchatPageState createState() => _HyperchatPageState();
}

class _HyperchatPageState extends State<HyperchatPage> {
  dynamic _console;
  dynamic singleInput;

  String _input = "";
  Uint8List? _media;
  bool? _isVideo;

  void _loadCameraConsole() {
    _console = CameraConsole(
      cameras: widget.cameras,
      cameraBack: () {
        _loadTextInput();
        _loadHyperchatConsole();
      },
      cameraCallBack: (filePath, isVideo) {
        if (filePath != null && isVideo != null) {
          _media = File(filePath).readAsBytesSync();
          _isVideo = isVideo;
        }
        _loadHyperchatConsole();
      },
    );
  }

  void _loadHyperchatConsole() {
    _console = Console(
      inputs: [singleInput],
      topButtons: [
        ConsoleButton(
          name: "Images",
          onPress: () => print("TODO"),
        ),
        ConsoleButton(
            name: "Send",
            onPress: () async {
              final tn = await widget.self.image.generateThumbnail();
              widget.sendInitialMessage(
                MessageRequest(
                  b64Thumbnail: base64Encode(tn),
                  sender: widget.self.id,
                  targets: widget.palettes.map((e) => e.node.id).toList(),
                  name: widget.self.name,
                  isChat: true,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                  media: _media,
                  text: _input,
                ),
              );
              widget.afterFirstMessageCallBack();
            }),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _media == null ? "Camera" : "&Camera",
          onPress: _loadCameraConsole,
        ),
        ConsoleButton(name: "Ping", onPress: () => print("TODO"))
      ],
    );
  }

  void _loadTextInput() {
    singleInput = InputObjects(
      inputCallBack: (text) => _input = text,
      placeHolder: ":)",
      value: _input,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTextInput();
    _loadHyperchatConsole();
  }

  @override
  Widget build(BuildContext context) {
    return Down4ColumnBackground(children: [
      PaletteList(palettes: widget.palettes),
      _console ?? const SizedBox.shrink()
    ]);
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
    return Down4ColumnBackground(
      children: [messageList, console],
    );
  }
}

class AddFriendPage extends StatefulWidget {
  final Node self;
  final void Function(List<Node>) addCallback;
  final void Function() backCallback;
  const AddFriendPage({
    required this.self,
    required this.addCallback,
    required this.backCallback,
    Key? key,
  }) : super(key: key);

  @override
  _AddFriendPageState createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  Map<String, SingleActionPalette> _palettes = {};
  String _input = "";
  dynamic console;

  @override
  void initState() {
    super.initState();
    console = _loadConsole();
  }

  Console _loadConsole() {
    return Console(
      inputs: [
        InputObjects(
            value: _input,
            prefix: "@",
            inputCallBack: (text) => _input = text,
            placeHolder: "@Search")
      ],
      topButtons: [
        ConsoleButton(
            name: "Search",
            onPress: () async {
              var node = await r.getNodes([_input]);
              if (node != null) {
                _palettes = {
                  ..._palettes,
                  _input: SingleActionPalette(
                    at: "",
                    node: node.first,
                    imPress: (s, ss) {
                      _palettes[node.first.id]?.invertedSelection();
                      setState(() {});
                    },
                  )
                };
                setState(() {});
              }
            }),
        ConsoleButton(
          name: "Add",
          onPress: () {
            widget.addCallback(
              _palettes.values
                  .where((element) => element.selected)
                  .map((e) => e.node)
                  .toList(),
            );
            _palettes = _palettes.map(
              (key, value) => MapEntry(
                  key, value.selected ? value.invertedSelection() : value),
            );
          },
        )
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.backCallback),
        ConsoleButton(name: "Scan", onPress: () => print("SCAN")),
        ConsoleButton(name: "Forward", onPress: () => print("FORWARD"))
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Down4StackBackground(
      children: [
        Container(
          child: QrImage(
              data: [widget.self.id, widget.self.name, widget.self.lastName]
                  .join(" "),
              foregroundColor: PinkTheme.qrColor),
          padding: const EdgeInsets.all(16.0),
        ),
        Column(children: [
          PaletteList(palettes: _palettes.values.toList()),
          console,
        ]),
      ],
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
  final Future<bool> Function(Map<String, dynamic>) initUser;
  final void Function() success;
  final List<CameraDescription> cameras;
  const UserMakerPage({
    required this.initUser,
    required this.success,
    required this.cameras,
    Key? key,
  }) : super(key: key);

  @override
  _UserMakerPageState createState() => _UserMakerPageState();
}

class _UserMakerPageState extends State<UserMakerPage> {
  final buttonKey = GlobalKey();
  Map<String, dynamic> infos = {
    'id': '',
    'name': '',
    'imagedata': Uint8List(0),
    'lastname': '',
    'phone': '',
  }; // "user" redondance because of paletteMaker
  dynamic console;
  dynamic inputs;
  bool _isValidUsername = false;
  bool _isReady = false;
  bool _errorTryAgain = false;

  @override
  void initState() {
    super.initState();
    _loadInputs();
    _loadInitConsole();
  }

  void _loadInputs() {
    inputs = [
      // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
      InputObjects(
          inputCallBack: (id) async {
            _isValidUsername = await r.usernameIsValid(id);
            infos['id'] = id.toLowerCase();
            _loadInitConsole();
          },
          prefix: '@',
          placeHolder: "@username",
          value: infos['id'] == '' ? '' : '@' + infos['id']),
      InputObjects(
        inputCallBack: (firstName) {
          setState(() => infos['name'] = firstName);
        },
        placeHolder: 'First Name',
        value: infos['name'],
      ),
      InputObjects(
        inputCallBack: (lastName) {
          setState(() => infos['lastname'] = lastName);
        },
        placeHolder: "(Last Name)",
        value: infos['lastname'],
      )
    ];
  }

  void _loadInitConsole() {
    console = Console(
      topInputs: [inputs[0]],
      inputs: [inputs[1], inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: _loadCameraConsole),
        ConsoleButton(name: "Recover", onPress: () => print("TODO")),
        ConsoleButton(
            key: buttonKey,
            isActivated: _isReady,
            name: "Proceed",
            onPress: () async {
              _errorTryAgain = !await widget.initUser(infos);
              if (_errorTryAgain) {
                setState(() {});
              } else {
                widget.success();
              }
            })
      ],
    );
    setState(() {});
  }

  void _loadCameraConsole() {
    console = CameraConsole(
        cameras: widget.cameras,
        cameraBack: _loadInitConsole,
        cameraCallBack: (path, isVideo) async {
          if (path != null) {
            final unCompressedBytes = File(path).readAsBytesSync();
            final compressedBytes = await FlutterImageCompress.compressWithFile(
              path,
              minHeight: 520, // palette height
              minWidth: 520, // palette height
              quality: 40,
            );
            print("""
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


                  Uncompressed image size = ${unCompressedBytes.length}
                  Compressed image size = ${compressedBytes?.length}


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
            """);
            infos["imagedata"] = compressedBytes!;
          }
          _loadInputs();
          _loadInitConsole();
        });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _isReady = _isValidUsername &&
        infos['imagedata'].isNotEmpty &&
        infos['name'] != '';
    return Down4ColumnBackground(
      children: [
        _errorTryAgain
            ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 22.0),
                child: const Text(
                  "Rare error, someone might have just taken that username, please try again",
                  textAlign: TextAlign.center,
                ))
            : const SizedBox.shrink(),
        UserMakerPalette(
          selectFile: () async {
            FilePickerResult? r = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'png', 'jpeg'],
                withData: true);
            if (r?.files.single.bytes != null) {
              final compressedBytes =
                  await FlutterImageCompress.compressWithList(
                r!.files.single.bytes!,
                minHeight: 520,
                minWidth: 520,
                quality: 40,
              );
              setState(() => infos['imagedata'] = compressedBytes);
            }
          },
          name: infos['name'],
          id: infos['id'],
          lastName: infos['lastname'],
          image: infos['imagedata'],
        ),
        const SizedBox(height: 16.0),
        console,
        // console ?? Container()
      ],
    );
  }
}

class WelcomePage extends StatelessWidget {
  final VoidCallback _understood;
  final String _mnemonic;
  final Node _userInfo;
  const WelcomePage({
    required String mnemonic,
    required Node userInfo,
    required VoidCallback understood,
    Key? key,
  })  : _mnemonic = mnemonic,
        _userInfo = userInfo,
        _understood = understood,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalWidth = MediaQuery.of(context).size.width;
    final totalHeight = MediaQuery.of(context).size.height;

    return Down4StackBackground(children: [
      Positioned(
        width: totalWidth,
        height: totalHeight - (16.0 + ConsoleButton.height),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SingleActionPalette(node: _userInfo, at: ""),
            Container(
              margin: const EdgeInsets.only(left: 22.0, right: 22.0),
              child: Text(
                _mnemonic,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 22.0, right: 22.0),
              child: const Text(
                "Those twelve words are the key to your account, money & personal infrastructure, save it somewhere secure. We recommend a piece of paper.",
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      Positioned(
        width: totalWidth,
        bottom: 0,
        child: Console(
          bottomButtons: [
            ConsoleButton(name: "Understood", onPress: _understood)
          ],
        ),
      ),
    ]);
  }
}

class HomePage extends StatefulWidget {
  Map<Identifier, Node> friends, friendRequests, hyperchats, groups;

  HomePage({
    required this.friends,
    required this.friendRequests,
    required this.hyperchats,
    required this.groups,
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, SingleActionPalette> _sp = {};

  void _selectNode(String id) {
    _sp[id] = _sp[id]!.invertedSelection();
    setState(() {});
  }

  void _initMessageListener() {
    FirebaseMessaging.onMessage.listen((event) {
      final d = event.data;
      
    });
  }

  @override
  void initState() {
    super.initState();

    final friends = widget.friends.map((key, value) => MapEntry(
        key,
        SingleActionPalette(
          node: value,
          imPress: () => _selectNode(value.id),
        )));

    final hyperchats = widget.hyperchats.map((key, value) => MapEntry(
        key,
        SingleActionPalette(
          node: value,
          imPress: () => _selectNode(value.id),
        )));

    final groups = widget.groups.map((key, value) => MapEntry(
        key,
        SingleActionPalette(
          node: value,
          imPress: () => _selectNode(value.id),
        )));

    _sp.addAll(friends);
    _sp.addAll(hyperchats);
    _sp.addAll(groups);
  }

  @override
  Widget build(BuildContext context) {
    return PalettePage(
        palettes: _sp.values.toList()
          ..sort((a, b) => a.activity.compareTo(b.activity)),
        console: Console(
          inputs: [
            InputObjects(
                inputCallBack: (text) => _kernelInput = text, placeHolder: ":)")
          ],
          topButtons: [
            ConsoleButton(
                name: "Hyperchat",
                onPress: () {
                  final nodes = _selectedNodes('Friends');
                  _palettes['Hyperchat'] = nodes.map((id, node) => MapEntry(
                      id, SingleActionPalette(at: "Hyperchat", node: node)));
                  _putState(States.hyperchat);
                }),
            ConsoleButton(
                name: "Money",
                onPress: () {
                  _palettes['Money'] = _selectedNodes("Friends").map(
                      (key, node) => MapEntry(
                          key, SingleActionPalette(at: "Money", node: node)));
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
  }
}
// TODO

// class PaletteMakerPage extends StatefulWidget {
//   final void Function(Map<String, Map<String, String?>>) kernelInfoCallBack;
//   final String? userID;
//   final List<CameraDescription> cameras;
//   const PaletteMakerPage(
//       {required this.kernelInfoCallBack,
//       required this.cameras,
//       this.userID,
//       Key? key})
//       : super(key: key);

//   @override
//   State<PaletteMakerPage> createState() => _PaletteMakerPageState();
// }

// class _PaletteMakerPageState extends State<PaletteMakerPage> {
//   Map<String, Map<String, dynamic>> infos = {};
//   late String at;
//   late String currentConsole;
//   late Map<String, dynamic> consoles;

//   void _infoCallBack(String key, Map<String, dynamic> info) {
//     setState(() {
//       infos[key] = info;
//       print("Info update: $info");
//     });
//   }

//   @override
//   void initState() {
//     super.initState();
//     consoles["camera"] = CameraConsole(
//       cameras: widget.cameras,
//       cameraCallBack: (path) async {
//         if (path != null) {
//           infos[at]!["image"] = path;
//           final unCompressedBase64Image =
//               base64Encode(File(path).readAsBytesSync());
//           final compressedImage =
//               await FlutterImageCompress.compressWithFile(path,
//                   minHeight: 520, // palette height
//                   minWidth: 520, // palette height
//                   quality: 40);
//           if (compressedImage != null) {
//             final base64Image = base64Encode(compressedImage);
//             print("""
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//                   Uncompressed image size = ${unCompressedBase64Image.length}
//                   Compressed image size = ${base64Image.length}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//             """);
//           }
//           setState(() {
//             currentConsole = "user";
//           });
//         }
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     print("""
// +++++++++++++++++++++++++++++++++++++++++++++

//                 REPAINTING

// +++++++++++++++++++++++++++++++++++++++++++++
// """);
//     return Container(
//       color: PinkTheme.backGroundColor,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           PaletteMakerList(
//               palettes: infos
//                   .map((key, value) => MapEntry(
//                       key,
//                       PaletteMaker(
//                           infoCallBack: _infoCallBack,
//                           infoKey: key,
//                           info: infos[key] ?? {})))
//                   .values
//                   .toList()),
//           consoles[currentConsole]!
//         ],
//       ),
//     );
//   }
// }
