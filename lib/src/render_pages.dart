import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'render_objects.dart';
import 'dart:convert';
import 'boxes.dart';
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
                  isVideo: _isVideo ?? false,
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

class MoneyPage extends StatefulWidget {
  List<SingleActionPalette> palettes;
  VoidCallback back;
  MoneyPage({
    required this.palettes,
    required this.back,
    Key? key,
  }) : super(key: key);

  @override
  _MoneyPageState createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  String _moneyInput = "";
  final Map<String, dynamic> _currencies = {
    "l": ["CAD", "Satoshis"],
    "i": 0
  };
  final Map<String, dynamic> _paymentMethod = {
    "l": ["Each", "Split"],
    "i": 0
  };

  @override
  Widget build(BuildContext context) {
    final currency = _currencies["l"][_currencies["i"]] as String;
    final paymentMethod = _paymentMethod["l"][_paymentMethod["i"]] as String;
    return PalettePage(
      palettes: widget.palettes,
      console: Console(
        inputs: [
          InputObjects(
              inputCallBack: (text) => _moneyInput = text,
              placeHolder: "\$",
              type: TextInputType.number)
        ],
        topButtons: [
          ConsoleButton(name: "Pay", onPress: () => print("TODO")),
          ConsoleButton(name: "Bill", onPress: () => print("TODO"))
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(
              name: currency,
              isMode: true,
              onPress: () {
                setState(() {
                  _currencies["i"] = (_currencies["i"] + 1) %
                      (_currencies["l"] as List<String>).length;
                });
              }),
          ConsoleButton(
              name: paymentMethod,
              isMode: true,
              onPress: () {
                setState(() {
                  _paymentMethod["i"] = (_paymentMethod["i"] + 1) %
                      (_paymentMethod["l"] as List<String>).length;
                });
              })
        ],
      ),
    );
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

  void _selectePalette(String _, String id) {
    _palettes[id] = _palettes[id]!.invertedSelection();
    setState(() {});
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
              var node = (await r.getNodes([_input]))?.first;
              if (node != null) {
                _palettes.addAll({
                  node.id: SingleActionPalette(
                    node: node,
                    imPress: _selectePalette,
                    bodyPress: _selectePalette,
                  )
                });
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
            setState(() {});
          },
        )
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.backCallback),
        ConsoleButton(name: "Scan", onPress: () => print("SCAN")),
        ConsoleButton(name: "Forward", onPress: () => print("FORWARD")),
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
    'nm': '',
    'im': <int>[],
    'ln': '',
  }; // "user" redondance because of paletteMaker
  dynamic console;
  dynamic inputs;
  bool _isValidUsername = false;
  bool _errorTryAgain = false;

  @override
  void initState() {
    super.initState();
    _loadInputs();
    _loadInitConsole();
  }

  bool _isReady() {
    return _isValidUsername && infos['im'].isNotEmpty && infos['nm'] != '';
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
          setState(() => infos['nm'] = firstName);
        },
        placeHolder: 'First Name',
        value: infos['nm'],
      ),
      InputObjects(
        inputCallBack: (lastName) {
          setState(() => infos['ln'] = lastName);
        },
        placeHolder: "(Last Name)",
        value: infos['ln'],
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
            isActivated: _isReady(),
            name: "Proceed",
            onPress: () async {
              _errorTryAgain = !await widget.initUser(infos);
              if (_errorTryAgain) {
                setState(() {});
              } else {
                widget.success();
              }
            }),
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
            infos["im"] = compressedBytes!.toList();
          }
          _loadInputs();
          _loadInitConsole();
        });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
              setState(() => infos['im'] = compressedBytes.toList());
            }
          },
          name: infos['nm'],
          id: infos['id'],
          lastName: infos['ln'],
          image: infos['im'],
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
  List<CameraDescription> cameras;
  Node self;
  HomePage({required this.cameras, required this.self, Key? key})
      : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

enum HomePageRenderState { loading, home, addFriend, money, hyperchat, chat }

class _HomePageState extends State<HomePage> {
  HomePageRenderState _state = HomePageRenderState.loading;
  Map<String, Map<String, SingleActionPalette>> _palettes = {
    "Friends": {},
    "FriendRequests": {},
    "Hyperchats": {},
    "Temporal": {},
  };
  Map<String, Map<String, ChatMessage>> _messages = {};
  String _pingInput = "";

  @override
  void initState() {
    super.initState();
    _loadLocalFriends();
    _loadLocalFriendRequests();
    _loadLocalHyperchats();
    _putState(HomePageRenderState.home);
  }

  void _putState(HomePageRenderState s) {
    setState(() => _state = s);
  }

  void _initializeMessageListener() {
    FirebaseMessaging.onMessage.listen((event) async {
      final notif = MessageNotification.fromNotification(event.data);
      switch (notif.type) {
        case MessageTypes.chat:
          final msg = (await notif.toDown4Message())..saveLocally();
          if (_messages[msg.root] != null) {
            _messages[msg.root] = {
              msg.id: ChatMessage(
                message: msg,
                myMessage: msg.sender == widget.self.id,
                at: msg.root,
              ),
            };
            setState(() {});
          }
          break;

        case MessageTypes.friendRequest:
          {
            break;
          }
        case MessageTypes.payment:
          {
            break;
          }
        case MessageTypes.bill:
          {
            break;
          }
      }
    });
  }

  void _select(String at, String id) {
    _palettes[at]![id] = _palettes[at]![id]!.invertedSelection();
    setState(() {});
  }

  void _selectMessage(String id, String at) {
    _messages[at]?[id] = _messages[at]![id]!.invertedSelection();
    setState(() {});
  }

  void _openChat(String at, String id) {
    print("TODO");
    setState(() {});
  }

  void _sendMessage(MessageRequest mr) async {
    r.messageRequest(mr);
  }

  void _loadLocalMessages(String nodeID, String nodeLocation) {
    // The sessions starts at null for every node mapping to their messages
    // We local load them once, then they get added to memory and to disk with the _onMessage function
    if (_messages[nodeID] == null) {
      _messages[nodeID] = {};
      final node = _palettes[nodeLocation]?[nodeID]?.node;
      for (final msgID in node?.messages ?? <String>[]) {
        final d4msg = Down4Message.fromLocal(msgID);
        _messages[nodeID] = {
          msgID: ChatMessage(
            at: nodeID,
            message: d4msg,
            myMessage: widget.self.id == d4msg.sender,
            select: _selectMessage,
          )
        };
      }
    }
  }

  void _initMessageListener() {
    FirebaseMessaging.onMessage.listen((event) async {
      final notif = MessageNotification.fromNotification(event.data);
      switch (notif.type) {
        case MessageTypes.chat:
          final msg = await notif.toDown4Message();
          _messages[msg.root] = {
            msg.id: ChatMessage(
              message: msg,
              myMessage: msg.sender == widget.self.id,
              select: _selectMessage,
              at: msg.root,
            ),
          };
          setState(() {});
          break;
        case MessageTypes.friendRequest:
          break;
        case MessageTypes.payment:
          break;
        case MessageTypes.bill:
          break;
      }
    });
  }

  void _loadLocalFriends() {
    final jsonEncodedFriends = Boxes.instance.friends.values;
    for (final jsonEncodedFriend in jsonEncodedFriends) {
      final node = Node.fromJson(jsonDecode(jsonEncodedFriend));
      _palettes["Friends"]?.putIfAbsent(
          node.id,
          () => SingleActionPalette(
                node: node,
                at: "Friends",
                bodyPress: _select,
                goPress: _openChat,
              ));
    }
    ;
  }

  void _loadLocalFriendRequests() {
    final jsonFriendRequests = Boxes.instance.friendRequests.values;
    for (final jsonFriendRequest in jsonFriendRequests) {
      final node = Node.fromJson(jsonFriendRequest);
      _palettes["FriendRequests"]?.addAll(
          {node.id: SingleActionPalette(node: node, at: "FriendRequests")});
    }
  }

  void _loadLocalHyperchats() {
    final jsonHyperchats = Boxes.instance.hyperchats.values;
    for (final jsonHyperchat in jsonHyperchats) {
      final node = Node.fromJson(jsonHyperchat);
      _palettes["Hyperchats"]?.addAll({
        node.id: SingleActionPalette(
          node: node,
          at: "Hyperchats",
          bodyPress: _select,
          goPress: _openChat,
        ),
      });
    }
  }

  void _addFriends(List<Node> friends) {
    for (final friend in friends) {
      _palettes["Friends"]!.putIfAbsent(friend.id, () {
        friend.saveLocally();
        return SingleActionPalette(
          node: friend,
          bodyPress: _select,
          goPress: _openChat,
        );
      });
    }
  }

  // ======================================================== VIEWS RELATED ============================================================ //

  List<SingleActionPalette> _formatedHomePalettes() {
    return _palettes["Friends"]!
        .values
        .followedBy(_palettes["Hyperchats"]!.values)
        .toList()
      ..sort((a, b) => a.activity.compareTo(b.activity))
      ..addAll(_palettes["FriendRequests"]!.values);
  }

  List<SingleActionPalette> _selectedHomePalettes() {
    var selectedHyperchats =
        _palettes["Hyperchats"]!.values.where((hc) => hc.selected);
    var idsOfSelHyperchats = [];
    for (final shc in selectedHyperchats) {
      for (final uid in shc.node.friends ?? <String>[]) {
        if (!idsOfSelHyperchats.contains(uid)) {
          idsOfSelHyperchats.add(uid);
        }
      }
    }
    var palettes = <SingleActionPalette>[];
    for (final pal in _palettes["Friends"]!.values) {
      if (idsOfSelHyperchats.contains(pal.node.id)) {
        palettes.add(pal.deactivated());
      }
    }
    for (final pal in _palettes["Temporal"]!.values) {
      if (idsOfSelHyperchats.contains(pal.node.id)) {
        palettes.add(pal.deactivated());
      }
    }

    var selectedFriends = _palettes["Friends"]!.values.where((e) => e.selected);
    for (final f in selectedFriends) {
      if (!idsOfSelHyperchats.contains(f.node.id)) {
        palettes.add(f.deactivated());
      }
    }

    return palettes;
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case HomePageRenderState.loading:
        return const LoadingPage();

      case HomePageRenderState.home:
        return PalettePage(
            palettes: _formatedHomePalettes(),
            console: Console(
              inputs: [
                InputObjects(
                  inputCallBack: (text) => _pingInput = text,
                  placeHolder: ":)",
                )
              ],
              topButtons: [
                ConsoleButton(
                    name: "Hyperchat",
                    onPress: () => _putState(HomePageRenderState.hyperchat)),
                ConsoleButton(
                    name: "Money",
                    onPress: () => _putState(HomePageRenderState.money)),
              ],
              bottomButtons: [
                ConsoleButton(name: "Browse", onPress: () => print("TODO")),
                ConsoleButton(
                    name: "Add Friend",
                    onPress: () => _putState(HomePageRenderState.addFriend)),
                ConsoleButton(
                    isSpecial: true, name: "Ping", onPress: () => print("TODO"))
              ],
            ));

      case HomePageRenderState.hyperchat:
        return HyperchatPage(
          self: widget.self,
          sendInitialMessage: _sendMessage,
          back: () => _putState(HomePageRenderState.home),
          palettes: _selectedHomePalettes(),
          cameras: widget.cameras,
          afterFirstMessageCallBack: () => print("TODO"),
        );

      case HomePageRenderState.chat:
        return Container();

      case HomePageRenderState.addFriend:
        return AddFriendPage(
          self: widget.self,
          addCallback: _addFriends,
          backCallback: () => _putState(HomePageRenderState.home),
        );

      case HomePageRenderState.money:
        return MoneyPage(
          palettes: _selectedHomePalettes(),
          back: () => _putState(HomePageRenderState.home),
        );
    }
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
