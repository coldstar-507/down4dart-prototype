import 'dart:io';
import 'dart:ui' as ui;
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
import 'package:hex/hex.dart';
import 'down4_utility.dart' as d4utils;
import 'package:random_words/random_words.dart' as rw;

class PalettePage extends StatelessWidget {
  final List<Palette> palettes;
  final Console console;
  const PalettePage({required this.palettes, required this.console, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4ColumnBackground(
        children: [PaletteList(palettes: palettes), console]);
  }
}

class MessagePage extends StatelessWidget {
  final MessageList2 messageList;
  final dynamic console;
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

class HyperchatPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Node self;
  final List<Palette> palettes;
  final void Function(Node) afterMessageCallback;
  final void Function() back;
  const HyperchatPage({
    required this.self,
    required this.afterMessageCallback,
    required this.back,
    required this.palettes,
    required this.cameras,
    Key? key,
  }) : super(key: key);

  @override
  _HyperchatPageState createState() => _HyperchatPageState();
}

class _HyperchatPageState extends State<HyperchatPage> {
  dynamic _console;
  dynamic singleInput;
  List<dynamic> _items = [];
  var tec = TextEditingController();

  String _input = "";
  Down4Media? _mediaInput;

  String _hyperchatName = "";
  Down4Media? _hyperchatImage;

  List<Identifier>? _forwardingNodes;

  @override
  void initState() {
    super.initState();
    _loadTextInput();
    _loadHyperchatConsole();
    _loadPalettes();
  }

  PaletteMaker _hyperchatMaker() {
    return PaletteMaker(
      id: "", // will calculate the ID on hyperchat creation for hyperchats
      name: _hyperchatName,
      hintText: "(Name)",
      nameCallBack: (name) => setState(() => _hyperchatName = name),
      type: Nodes.hyperchat,
      imageCallBack: (data) {
        final dataForID = widget.self.id.codeUnits + data.toList();
        final imageID = HEX.encode(sv.sha1(dataForID));
        _hyperchatImage = Down4Media(
          data: data,
          id: imageID,
          metadata: MediaMetadata(
            owner: widget.self.id,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        _loadPalettes();
      },
      image: _hyperchatImage?.data ?? Uint8List(0),
    );
  }

  void _loadPalettes() {
    _items.clear();
    _items.add(_hyperchatMaker());
    _items.addAll(widget.palettes);
    setState(() {});
  }

  void _loadCameraConsole() {
    _console = CameraConsole(
      cameras: widget.cameras,
      cameraBack: () {
        _loadTextInput();
        _loadHyperchatConsole();
      },
      cameraCallBack: (filePath, isVideo, toReverse) {
        if (filePath != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _mediaInput = Down4Media.fromCamera(
            filePath,
            MediaMetadata(
              owner: widget.self.id,
              timestamp: timestamp,
              isVideo: isVideo ?? false,
              toReverse: toReverse ?? false,
            ),
          );
        }
        _loadHyperchatConsole();
      },
    );
  }

  Future<void> _send() async {
    if (_input != "" && _mediaInput != null) {
      final targets = widget.palettes.map((e) => e.node.id).toList();
      final wp = rw.WordPair.random(safeOnly: false);
      final root =
          d4utils.deterministicHyperchatRoot(targets..add(widget.self.id));
      final msg = Down4Message(
        messageID: d4utils.generateMessageID(
          widget.self.id,
          DateTime.now().millisecondsSinceEpoch,
        ),
        media: _mediaInput,
        root: root,
        senderName: widget.self.id,
        senderID: widget.self.id,
        senderThumbnail: base64Encode(widget.self.image.thumbnail!),
        forwarderName: widget.self.name,
        isChat: true,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        text: _input,
        nodes: _forwardingNodes,
      )..saveLocally();
      final hyperchatNode = Node(
        type: Nodes.hyperchat,
        id: root,
        name: wp.first,
        lastName: wp.second,
        image: _hyperchatImage ?? widget.self.image,
        messages: [msg.messageID],
        posts: [],
        friends: [],
        group: targets..add(widget.self.id),
        parents: [],
        childs: [],
        admins: [],
      )..saveLocally();
      final success = await r.messageRequest(MessageRequest(
        msg: msg,
        targets: targets,
        isHyperchat: true,
        rootNode: hyperchatNode,
        withUpload: msg.media != null,
      ));
      if (success) {
        widget.afterMessageCallback(hyperchatNode);
      }
    }
  }

  void _loadHyperchatConsole() {
    _console = Console(
      inputs: [singleInput],
      topButtons: [
        ConsoleButton(
          name: "Images",
          onPress: () => print("TODO"),
        ),
        ConsoleButton(name: "Send", onPress: _send),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _mediaInput == null ? "Camera" : "&Camera",
          onPress: _loadCameraConsole,
        ),
        ConsoleButton(name: "Ping", onPress: () => print("TODO"))
      ],
    );
  }

  void _loadTextInput() {
    singleInput = ConsoleInput(
      tec: tec,
      inputCallBack: (text) => _input = text,
      placeHolder: ":)",
      value: _input,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Down4ColumnBackground(children: [
      DynamicList(palettes: _items),
      _console ?? const SizedBox.shrink()
    ]);
  }
}

class MoneyPage extends StatefulWidget {
  final List<Palette> palettes;
  final VoidCallback back;
  const MoneyPage({
    required this.palettes,
    required this.back,
    Key? key,
  }) : super(key: key);

  @override
  _MoneyPageState createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  String _moneyInput = "";
  var tec = TextEditingController();
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
          ConsoleInput(
            tec: tec,
            inputCallBack: (text) => _moneyInput = text,
            placeHolder: "\$",
            type: TextInputType.number,
          )
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

class AddFriendPage extends StatefulWidget {
  final Node self;
  final List<Palette> palettes;
  final Future<bool> Function(String) search;
  final void Function(List<Node>) addCallback;
  final void Function() backCallback;
  const AddFriendPage({
    required this.palettes,
    required this.search,
    required this.self,
    required this.addCallback,
    required this.backCallback,
    Key? key,
  }) : super(key: key);

  @override
  _AddFriendPageState createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  String _input = "";
  ConsoleInput? _consoleInputRef;
  TextEditingController tec = TextEditingController();

  @override
  void initState() {
    super.initState();
    _consoleInputRef = consoleInput;
  }

  ConsoleInput get consoleInput {
    return ConsoleInput(
      tec: tec,
      value: _input,
      prefix: "@",
      inputCallBack: (text) => _input = text,
      placeHolder: "@search",
    );
  }

  Console get defaultConsole {
    return Console(
      inputs: [_consoleInputRef ?? consoleInput],
      topButtons: [
        ConsoleButton(
          name: "Search",
          onPress: () async => await widget.search(_input) ? tec.clear() : {},
        ),
        ConsoleButton(
          name: "Add",
          onPress: () => widget.addCallback(
            widget.palettes
                .where((element) => element.selected)
                .map((e) => e.node)
                .toList(),
          ),
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
          padding: const EdgeInsets.only(top: 44, right: 44, left: 44),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: QrImage(
              foregroundColor: PinkTheme.qrColor,
              data: [widget.self.id, widget.self.name, widget.self.lastName]
                  .join(" "),
            ),
          ),
        ),
        Column(children: [
          PaletteList(palettes: widget.palettes),
          defaultConsole,
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
  final Future<bool> Function(String, String, String, Uint8List, bool) initUser;
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
  String _id = "";
  String _name = "";
  String _lastName = "";
  Uint8List _image = Uint8List(0);
  dynamic _console;
  dynamic _inputs;
  bool _toReverse = false;
  bool _isValidUsername = false;
  bool _errorTryAgain = false;
  var tec1 = TextEditingController();
  var tec2 = TextEditingController();
  var tec3 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInputs();
    _loadInitConsole();
  }

  bool _isReady() {
    return _isValidUsername && _image.isNotEmpty && _name.isNotEmpty;
  }

  void _loadInputs() {
    _inputs = [
      // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
      ConsoleInput(
          tec: tec1,
          inputCallBack: (id) async {
            _isValidUsername = await r.usernameIsValid(id);
            _id = id.toLowerCase();
            _loadInitConsole();
          },
          prefix: '@',
          placeHolder: "@username",
          value: _id == '' ? '' : '@' + _id),
      ConsoleInput(
        tec: tec2,
        inputCallBack: (firstName) {
          _name = firstName;
          _loadInitConsole();
        },
        placeHolder: 'First Name',
        value: _name,
      ),
      ConsoleInput(
        tec: tec3,
        inputCallBack: (lastName) {
          setState(() => _lastName = lastName);
        },
        placeHolder: "(Last Name)",
        value: _lastName,
      )
    ];
  }

  void _loadInitConsole() {
    _console = Console(
      topInputs: [_inputs[0]],
      inputs: [_inputs[1], _inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: _loadCameraConsole),
        ConsoleButton(name: "Recover", onPress: () => print("TODO")),
        ConsoleButton(
            key: buttonKey,
            isActivated: _isReady(),
            name: "Proceed",
            onPress: () async {
              _errorTryAgain = !await widget.initUser(
                _id,
                _name,
                _lastName,
                _image,
                _toReverse,
              );
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
    _console = CameraConsole(
        enableVideo: false,
        cameras: widget.cameras,
        cameraBack: _loadInitConsole,
        cameraCallBack: (path, _, toReverse) async {
          if (path != null) {
            _toReverse = toReverse ?? false;
            final compressedBytes = await FlutterImageCompress.compressWithFile(
              path,
              minHeight: 520, // palette height
              minWidth: 520, // palette height
              quality: 40,
            );
            _image = compressedBytes ?? Uint8List(0);
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
              setState(() => _image = compressedBytes);
            }
          },
          name: _name,
          id: _id,
          lastName: _lastName,
          image: _image,
        ),
        const SizedBox(height: 16.0),
        _console,
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
            Palette(node: _userInfo, at: ""),
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

class NodePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final List<Palette> palettes;
  final Palette palette;
  final Node self;
  final Palette? Function(String, Node) nodeToPalette;
  final void Function(String, String) openNode, openChat;
  final void Function() back, saveMessages;
  const NodePage({
    required this.cameras,
    required this.saveMessages,
    required this.openNode,
    required this.openChat,
    required this.palette,
    required this.nodeToPalette,
    required this.back,
    required this.self,
    required this.palettes,
    Key? key,
  }) : super(key: key);

  @override
  _NodePageState createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  Map<String, Map<Identifier, Palette>> _fetchablePalettes = {
    "Admins": {},
    "Followers": {},
    "Following": {},
    "Parents": {},
  };

  // Map<String, ChatMessage> _posts = {};

  Map<String, List<String>> _stupidMap = {};
  List<String> _modes = ["Childs"];
  int _i = 0;

  // double _profileImageWidth = 200;

  @override
  void initState() {
    super.initState();
    // setUpProfileImage();
    final node = widget.palette.node;
    // if (node.posts.isNotEmpty) { // TODO: posts
    //   _modes.add("Posts");
    //   _stupidMap["Posts"] = node.posts;
    // }
    if (node.parents.isNotEmpty) {
      _modes.add("Parents");
      _stupidMap["Parents"] = node.parents;
    }
    if (node.admins.isNotEmpty) {
      _modes.add("Admins");
      _stupidMap["Admins"] = node.admins;
    }
    if (node.friends.isNotEmpty) {
      _modes.add("Friends");
      _stupidMap["Friends"] = node.friends;
    }
  }

  // Future<void> setUpProfileImage() async {
  //   final buffer =
  //       await ui.ImmutableBuffer.fromUint8List(widget.palette.node.image.data);
  //   final descriptor = await ui.ImageDescriptor.encoded(buffer);
  //   _profileImageWidth = descriptor.width.toDouble();
  //   setState(() {});
  // }

  String get currentMode => _modes[_i];

  List<Palette> get currentPalettes {
    if (currentMode == "Childs") {
      return widget.palettes;
    }
    return _fetchablePalettes[currentMode]!.values.toList();
  }

  Console get basicPaletteConsole => Console(
        topButtons: [
          ConsoleButton(name: "Forward", onPress: () => print("TODO")),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(
            isActivated: _modes.length != 1,
            isMode: true,
            name: currentMode,
            onPress: rotate,
          ),
        ],
      );

  Console get userPaletteConsole => Console(
        topButtons: [
          ConsoleButton(
            name: "Message",
            onPress: () => widget.openChat(
              widget.palette.node.id,
              widget.palette.at,
            ),
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(
            name: "Forward",
            onPress: () => print("TODO"), // "TODO: forward"
          ),
        ],
      );

  Future<void> rotate() async {
    _i = (_i + 1) % _modes.length;
    if (currentMode == "Childs") {
      setState(() {});
      return;
    }
    if (_fetchablePalettes[currentMode]!.isEmpty) {
      final nodes = await r.getNodes(_stupidMap[currentMode]!);
      for (final node in nodes ?? []) {
        final p = widget.nodeToPalette(widget.palette.node.id, node);
        if (p != null) {
          _fetchablePalettes[currentMode] = {p.node.id: p};
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (currentMode) {
      case "Childs":
        return [Nodes.user, Nodes.friend, Nodes.nonFriend]
                .contains(widget.palette.node.type)
            ? Down4ColumnBackground(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 44, right: 44, top: 27),
                    child: ProfileWidget(
                      node: widget.palette.node
                        ..description =
                            "Hello, this is a temporary description, used first of all for one purpose only, and that purpose is testing",
                    ),
                  ),
                  PaletteList(palettes: currentPalettes),
                  userPaletteConsole,
                ],
              )
            : PalettePage(
                palettes: currentPalettes,
                console: basicPaletteConsole,
              );

      case "Parents":
        return PalettePage(
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );

      case "Admins":
        return PalettePage(
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );

      case "Followers":
        return PalettePage(
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );

      case "Following":
        return PalettePage(
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );
    }
    return const SizedBox.shrink();
  }
}

class ChatPage extends StatefulWidget {
  final Node self, node;
  final List<CameraDescription> cameras;
  final List<Down4Message> d4messages;
  final void Function() back, saveMessages;
  final void Function(MessageRequest) messageRequest;
  final List<ChatMessage> messages;
  const ChatPage({
    required this.messageRequest,
    required this.saveMessages,
    required this.d4messages,
    required this.self,
    required this.node,
    required this.back,
    required this.messages,
    required this.cameras,
    Key? key,
  }) : super(key: key);
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String _textInput = "";
  Down4Media? _cameraInput, _mediaInput;
  bool _showCameraConsole = false;
  bool _showMediaConsole = false;
  ConsoleInput? _consoleInput;
  var tec = TextEditingController();
  Map<Identifier, Down4Media> _medias = {};

  List<Down4Media> get medias {
    if (_medias.isEmpty && Boxes.instance.images.keys.isEmpty) {
      return <Down4Media>[];
    } else if (_medias.values.isEmpty &&
        Boxes.instance.images.keys.isNotEmpty) {
      for (final mediaID in Boxes.instance.images.keys) {
        _medias[mediaID] = Down4Media.fromSave(mediaID);
      }
      return _medias.values.toList();
    } else {
      return _medias.values.toList();
    }
  }

  ConsoleInput get consoleInput => _consoleInput = ConsoleInput(
        tec: tec,
        inputCallBack: (t) => _textInput = t,
        placeHolder: ":)",
        value: _textInput,
      );

  Console get mediasConsole => Console(
        images: true,
        medias: medias,
        selectMedia: (media) {
          _mediaInput = media;
          send();
        },
        topButtons: [ConsoleButton(name: "Import", onPress: handleImport)],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: toggleMedias),
          ConsoleButton(name: "Delete", onPress: () => print("TODO"))
        ],
      );

  Console get baseConsole => Console(
        topInputs: [_consoleInput ?? consoleInput],
        topButtons: [
          ConsoleButton(name: "Save", onPress: widget.saveMessages),
          ConsoleButton(name: "Send", onPress: send),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(name: "Images", onPress: toggleMedias),
          ConsoleButton(
            name: _cameraInput == null ? "Camera" : "@Camera",
            onPress: toggleCamera,
          )
        ],
      );

  Future<void> handleImport() async {
    FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg'],
      withData: true,
      allowMultiple: true,
    );
    final ts = d4utils.timeStamp();
    for (final pf in r?.files ?? <PlatformFile>[]) {
      if (pf.bytes != null) {
        final compressedData = await FlutterImageCompress.compressWithList(
          pf.bytes!,
          minHeight: 520,
          minWidth: 0,
        );
        final mediaID = d4utils.generateMediaID(compressedData);
        _medias[mediaID] = Down4Media(
          id: mediaID,
          data: compressedData,
          metadata: MediaMetadata(owner: widget.self.id, timestamp: ts),
        )..save();
      }
    }
    setState(() {});
  }

  void handleCameraCallback(String? path, bool? isVideo, bool? toReverse) {
    if (path != null && isVideo != null && toReverse != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _cameraInput = Down4Media.fromCamera(
        path,
        MediaMetadata(
          owner: widget.self.id,
          timestamp: timestamp,
          isVideo: isVideo,
          toReverse: toReverse,
        ),
      );
    }
    _showCameraConsole = false;
    setState(() {});
  }

  void toggleCamera() {
    setState(() => _showCameraConsole = !_showCameraConsole);
  }

  void toggleMedias() {
    setState(() => _showMediaConsole = !_showMediaConsole);
  }

  void saveSelectedMessages() {}

  void clearInputs() {
    tec.clear();
    _textInput = "";
    _cameraInput = null;
    _mediaInput = null;
  }

  void send() {
    if (_textInput != "" || _cameraInput != null || _mediaInput != null) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final targets =
          widget.node.group.isEmpty ? [widget.node.id] : widget.node.group;
      var msg = Down4Message(
        messageID: d4utils.generateMessageID(widget.self.id, ts),
        root: widget.node.id,
        timestamp: ts,
        senderID: widget.self.id,
        senderName: widget.self.name,
        senderThumbnail: base64Encode(widget.self.image.thumbnail!),
        media: _cameraInput ?? _mediaInput,
        text: _textInput,
      );
      widget.messageRequest(MessageRequest(targets: targets, msg: msg));
      clearInputs();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MessagePage(
      messageList: MessageList2(
        messages: widget.node.messages.reversed.toList(),
        self: widget.self,
      ),
      console: _showCameraConsole
          ? CameraConsole(
              cameras: widget.cameras,
              cameraBack: toggleCamera,
              cameraCallBack: handleCameraCallback,
            )
          : _showMediaConsole
              ? mediasConsole
              : baseConsole,
    );
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Node self;
  const HomePage({required this.cameras, required this.self, Key? key})
      : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

enum HomePageRenderState {
  loading,
  home,
  addFriend,
  money,
  hyperchat,
  chat,
  map,
  feed,
  node,
}

class _HomePageState extends State<HomePage> {
  HomePageRenderState _state = HomePageRenderState.loading;
  // The base location is Home with the home palettes
  // You can traverse palettes which will be cached
  // Home -> home palettes
  // paletteID -> child palettes
  Map<Identifier, Map<Identifier, Palette>> _palettes = {
    "Home": {},
    "Search": {},
  };
  // similar to the palettes, used for local data and caching messages
  Map<String, Map<String, ChatMessage>> _messages = {
    "Saved": {},
    "MyPosts": {},
  };
  Map<String, ChatMessage> _chatMessages = {};

  Node? _node; // the node we are currently traversing, always null at start
  List<String> _locations = ["Home"]; // to keep an history of traversed nodes
  // we pop it when backing in node views
  // when it's empty we should be on home view
  // if _currentLocation is not "Home", it should be _node.id

  String _pingInput = "";
  Down4Media? _snipInput;
  bool _camera = false;
  var tec = TextEditingController();
  bool _extra = false;

  // ======================================================= INITIALIZATION ============================================================ //

  @override
  void initState() {
    super.initState();
    loadLocalHomePalettes();
    processMessageQueue();
    initializeMessageListener();
    putState(HomePageRenderState.home);
  }

  void loadLocalHomePalettes() {
    final jsonEncodedHomeNodes = Boxes.instance.home.values;
    for (final jsonEncodedHomeNode in jsonEncodedHomeNodes) {
      final node = Node.fromJson(jsonDecode(jsonEncodedHomeNode));
      final p = nodeToPalette("Home", node);
      if (p != null) {
        setPaletteIfAbsent(p);
      }
    }
  }

  void initializeMessageListener() {
    FirebaseMessaging.onMessage.listen((event) async {
      print("Received message: ${event.data}");
      final notif = MessageNotification.fromNotification(
        Map<String, String>.from(event.data),
      );
      parseMessageNotification(notif);
    });
  }

  Future<void> processMessageQueue() async {
    for (final messageData in Boxes.instance.messageQueue.values) {
      final notif = MessageNotification.fromNotification(
          Map<String, String>.from(messageData));
      await parseMessageNotification(notif);
    }
    await Boxes.instance.messageQueue.clear();
    Boxes.instance.messageQueue.close();
  }

  // ======================================================= UTILS ============================================================ //

  void putState(HomePageRenderState s) {
    setState(() => _state = s);
  }

  Palette? nodeToPalette(String location, Node node) {
    switch (node.type) {
      case Nodes.user:
        return friendIDs.contains(node.id)
            ? nodeToPalette(location, node.mutatedType(Nodes.friend))
            : nodeToPalette(location, node.mutatedType(Nodes.nonFriend));

      case Nodes.root:
        return Palette(
          node: node,
          at: location, // todo
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: openNode,
              rightMost: true,
            )
          ],
        );

      case Nodes.friend:
        return Palette(
          node: node,
          at: location,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: location == "Home" ? openChat : openNode,
              longPressFunc: openNode,
              rightMost: true,
            )
          ],
        );
      case Nodes.market:
        break;
      case Nodes.hyperchat:
        if (node.messages.isEmpty) {
          return null;
        } else {
          final lastMessageID = node.messages.last;
          final msg = Down4Message.fromLocal(lastMessageID);
          if (msg.timestamp.isExpired) {
            node.deleteLocally();
            return null;
          }
        }
        return Palette(
          node: node,
          at: location,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: openChat,
              rightMost: true,
            )
          ],
        );
      case Nodes.event:
        break;
      case Nodes.checkpoint:
        return Palette(
          node: node,
          at: location,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: openNode,
              rightMost: true,
            )
          ],
        );

      case Nodes.item:
        break;

      case Nodes.journal:
        break;

      case Nodes.ticket:
        break;

      case Nodes.nonFriend:
        if (node.activity.isExpired) {
          return null;
        }
        return Palette(
          node: node,
          at: location,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: location == "Home" ? openChat : openNode,
              longPressFunc: openNode,
              rightMost: true,
            )
          ],
        );

      case Nodes.group:
        return Palette(
          node: node,
          at: location,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: openChat,
              rightMost: true,
            )
          ],
        );
    }
    return null;
  }

  void handleSnipCameraCallback(String? path, bool? isVideo, bool? toReverse) {
    if (path != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _snipInput = Down4Media.fromCamera(
        path,
        MediaMetadata(
          owner: widget.self.id,
          timestamp: timestamp,
          toReverse: toReverse ?? false,
          isVideo: isVideo ?? false,
        ),
      );
    }
    toggleCamera();
  }

  void toggleCamera() {
    setState(() => _camera = !_camera);
  }

  void clearInputs() {
    _pingInput = "";
    _snipInput = null;
  }

  Down4Message? makeMsg() {
    if (_snipInput != null || _pingInput != "") {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final msgID = d4utils.generateMessageID(widget.self.id, ts);
      return Down4Message(
        messageID: msgID,
        root: _node!.id,
        timestamp: ts,
        senderID: widget.self.id,
        senderName: widget.self.name,
        senderThumbnail: base64Encode(widget.self.image.thumbnail!),
        text: _pingInput,
        media: _snipInput,
      );
    }
    return null;
  }

  Future<void> parseMessageNotification(MessageNotification notif) async {
    switch (notif.type) {
      case Messages.chat:
        {
          var msg = await notif.toDown4Message();
          if (msg.root == widget.self.id) {
            msg.root = msg.senderID;
          }
          msg.saveLocally();
          if (getPalette(msg.root, "Home") != null) {
            setPalette(
              getPalette(msg.root, "Home")!
                ..node.messages.add(msg.messageID)
                ..node.updateActivity(DateTime.now().millisecondsSinceEpoch)
                ..node.saveLocally(),
            );
            if (_node?.id == msg.root) {
              _node?.messages.add(msg.messageID);
            }
          } else {
            // else fetch the node
            final nonFriend = await r.getNodes([msg.root]);
            // save it locally with proper type and activity
            final node = nonFriend?.first
              ?..mutateType(Nodes.nonFriend)
              ..messages.add(msg.messageID)
              ..updateActivity(DateTime.now().millisecondsSinceEpoch)
              ..saveLocally();
            if (node != null) {
              // add it to cached palettes
              setPaletteIfAbsent(nodeToPalette("Home", node)!);
            }
          }
          setState(() {});
          break;
        }

      case Messages.hyperchat:
        {
          final msg = (await notif.toDown4Message());
          final node = (await notif.nodeOfHyperchat())
            ?..messages.add(msg.messageID)
            ..updateActivity(DateTime.now().millisecondsSinceEpoch)
            ..saveLocally();
          if (node != null) {
            msg.saveLocally();
            setPaletteIfAbsent(nodeToPalette("Home", node)!);
          }
          setState(() {});
          break;
        }

      case Messages.group:
        {
          final msg = await notif.toDown4Message();
          var node = (await notif.nodeOfGroup())
            ?..messages.add(msg.messageID)
            ..updateActivity(DateTime.now().millisecondsSinceEpoch)
            ..saveLocally();
          if (node != null) {
            msg.saveLocally();
            setPaletteIfAbsent(nodeToPalette("Home", node)!);
          }
          setState(() {});
          break;
        }

      case Messages.payment:
        {
          break;
        }
      case Messages.bill:
        {
          break;
        }
    }
  }

  // ======================================================= CONSOLE ACTIONS ============================================================ //

  void addUsers(List<Node> friends) {
    for (final friend in friends) {
      setPalette(getPalette(friend.id, "Search")!.invertedSelection()
        ..node.mutateType(Nodes.friend));

      setPaletteIfAbsent(nodeToPalette(
          "Home",
          friend.mutatedType(Nodes.friend)
            ..updateActivity(DateTime.now().millisecondsSinceEpoch)
            ..saveLocally())!);
    }
    setState(() {});
  }

  Future<bool> ping() async {
    final List<String> targets = selectedHomeUserIDs;
    final msg = makeMsg();
    if (msg != null && targets.isNotEmpty) {
      return await r.messageRequest(MessageRequest(msg: msg, targets: targets));
    }
    return false;
  }

  void saveMessages() {
    for (final msg in currentMessages) {
      if (msg.selected) {
        msg.message.save();
        selectMessage(msg.message.messageID, msg.at);
      }
    }
  }

  void delete() {
    for (final p in selectedHomePalettes) {
      p.node.deleteLocally();
      removeHomePalette(p.node.id);
    }
    setState(() {});
  }

  Future<bool> search(String id) async {
    final nodes = await r.getNodes([id]);
    var node = nodes == null ? null : nodes.first;
    if (node != null) {
      node.updateActivity(d4utils.timeStamp());
      final p = nodeToPalette("Search", node);
      if (p != null) {
        setPaletteIfAbsent(p);
        setState(() {});
        return true;
      }
    }
    return false;
  }

  Future<void> send(MessageRequest mr) async {
    if (await r.messageRequest(mr)) {
      mr.msg.saveLocally();
      final cm = ChatMessage(
        hasHeader: lastMessageSender(mr.msg.root) != mr.msg.senderID,
        message: mr.msg,
        myMessage: true,
        at: mr.msg.root,
        select: selectMessage,
      );
      updateActivity(mr.msg.root, mr.msg.timestamp);
      setState(() {});
    }
  }

  void toggleExtra() {
    _extra = !_extra;
    setState(() {});
  }

  // ======================================================== NODE ACTIONS ============================================================== //

  Future<void> openNode(String id, String at) async {
    if (getPalettes(id) == null) {
      if (at == "Home") {
        // fetch the local node first to be sure it's up to date TODO: sadly
        final theNode = (await r.getNodes([id]))?.first;
        if (theNode != null) {
          final childNodes = await r.getNodes(theNode.childs);
          if (childNodes != null) {
            for (final node in childNodes) {
              setPaletteIfAbsent(nodeToPalette(id, node)!);
            }
            setTheNode(nodeAt(id, at));
            pushLocation(id);
            putState(HomePageRenderState.node);
          }
        }
      } else {
        final childNodes = await r.getNodes(nodeAt(id, at).childs);
        if (childNodes != null) {
          for (final node in childNodes) {
            setPaletteIfAbsent(nodeToPalette(id, node)!);
          }
          setTheNode(nodeAt(id, at));
          pushLocation(id);
          putState(HomePageRenderState.node);
        }
      }
    } else {
      setTheNode(nodeAt(id, at));
      pushLocation(id);
      putState(HomePageRenderState.node);
    }
  }

  void select(String id, String at) {
    _palettes[at]![id] = _palettes[at]![id]!.invertedSelection();
    setState(() {});
  }

  void selectMessage(String id, String at) {
    _messages[at]?[id] = _messages[at]![id]!.invertedSelection();
    setState(() {});
  }

  void openChat(String id, String at) {
    if (at == "Home") {
      setTheNode(nodeAt(id, at));
      putState(HomePageRenderState.chat);
    } else {
      if (friendAndNonFriendIDs.contains(id)) {
        setTheNode(nodeAt(id, at));
        putState(HomePageRenderState.chat);
      } else {
        setPaletteIfAbsent(nodeToPalette("Home", nodeAt(id, at))!);
        setTheNode(nodeAt(id, at));
        putState(HomePageRenderState.chat);
      }
    }
  }

  // ======================================================== GETTERS AND SETTERS======================================================== //

  void updateTheNode() {
    _node = _palettes["Home"]?[_node?.id]?.node;
  }

  void updateActivity(String id, int timestamp) {
    setPalette(
      getPalette(id, "Home")!
        ..node.updateActivity(timestamp)
        ..node.saveLocally(),
    );
  }

  void pushLocation(Identifier id) {
    _locations.add(id);
  }

  void popLocation() {
    _locations.removeLast();
  }

  Node nodeAt(String id, String at) {
    return _palettes[at]![id]!.node;
  }

  void setTheNode(Node node) {
    _node = node;
  }

  void removeHomePalette(String id) {
    _palettes["Home"]?.remove(id);
  }

  Palette? getPalette(String id, String at) {
    return _palettes[at]?[id];
  }

  Map<String, Palette>? getPalettes(String at) {
    return _palettes[at];
  }

  void setPalette(Palette p) {
    _palettes[p.at]![p.node.id] = p;
  }

  void setPaletteIfAbsent(Palette p) {
    if (_palettes[p.at] == null) {
      _palettes[p.at] = {p.node.id: p};
    } else {
      _palettes[p.at]!.putIfAbsent(p.node.id, () => p);
    }
  }

  ChatMessage? getMessage(String id, String at) {
    return _messages[at]?[id];
  }

  void setMessage(ChatMessage m) {
    _messages[m.message.root] != null
        ? _messages[m.message.root]!.addAll({m.message.messageID: m})
        : _messages[m.message.root] = {m.message.messageID: m};
  }

  String lastMessageSender(String at) {
    try {
      return getMessages(at)?.values.last.message.senderID ?? "";
    } catch (e) {
      return "";
    }
  }

  Map<String, ChatMessage>? getMessages(String at) {
    return _messages[at];
  }

  List<Palette> get formatedHomePalettes {
    return _palettes["Home"]?.values.toList() ?? <Palette>[]
      ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  }

  List<Palette> get selectedFriendPalettesDeactivated {
    var selectedGroups = homePalettes.where(
      (p) =>
          (p.node.type == Nodes.hyperchat || p.node.type == Nodes.group) &&
          p.selected,
    );
    var idsInSelGroups = [];
    for (final shc in selectedGroups) {
      for (final uid in shc.node.group) {
        if (!idsInSelGroups.contains(uid)) {
          idsInSelGroups.add(uid);
        }
      }
    }

    var palettes = <Palette>[];
    final selectedNonGroups = homePalettes.where(
      (p) => (p.node.type == Nodes.friend) && p.selected,
    );
    for (final pal in selectedNonGroups) {
      if (!idsInSelGroups.contains(pal.node.id)) {
        palettes.add(pal.deactivated());
      }
    }

    return palettes;
  }

  List<ChatMessage> get currentMessages {
    final chatRoot = node?.id;
    if (chatRoot == null) {
      return [];
    }
    // first, try the cache
    if (_messages[chatRoot] != null) {
      return _messages[chatRoot]!.values.toList().reversed.toList();
    }
    _messages[chatRoot] = {};
    final messageIDs = _node?.messages;
    String lastMessageSender = "";
    for (final msgID in messageIDs ?? []) {
      final d4msg = Down4Message.fromLocal(msgID);
      if (d4msg.timestamp.isExpired) {
        Boxes.instance.messages.delete(msgID);
        _node?.messages.removeWhere((element) => element == msgID);
      } else {
        _messages[chatRoot]?.addAll({
          msgID: ChatMessage(
            hasHeader: lastMessageSender != d4msg.senderID,
            at: chatRoot,
            message: d4msg,
            myMessage: d4msg.senderID == widget.self.id ||
                d4msg.forwarderID == widget.self.id,
            select: selectMessage,
          )
        });
        lastMessageSender = d4msg.senderID;
      }
    }
    _node?.saveLocally();
    return _messages[chatRoot]!.values.toList().reversed.toList();
  }

  List<ChatMessage> get chatMessages {
    if (node?.messages.length == _chatMessages.keys.length) {
      return _chatMessages.values.toList().reversed.toList();
    }
    final messagesToGet =
        node?.messages.takeWhile((msgID) => !_chatMessages.containsKey(msgID));

    var lastSenderID =
        _chatMessages.isEmpty ? "" : _chatMessages.values.last.message.senderID;

    for (final msgID in messagesToGet ?? <String>[]) {
      var d4msg = Down4Message.fromLocal(msgID);
      _chatMessages.addAll({
        d4msg.messageID: ChatMessage(
          message: d4msg,
          myMessage: widget.self.id == d4msg.senderID,
          at: "at",
          hasHeader: lastSenderID != d4msg.senderID,
        )
      });
      lastSenderID = d4msg.senderID;
    }
    return _chatMessages.values.toList().reversed.toList();
  }

  Node? get node {
    return _node;
  }

  List<Palette> get selectedHomePalettes {
    return homePalettes.where((element) => element.selected).toList();
  }

  List<Palette> get homePalettes {
    return _palettes["Home"]?.values.toList() ?? <Palette>[];
  }

  List<Node> get selectedHomeUserNodes {
    return selectedFriendPalettesDeactivated.map((e) => e.node).toList();
  }

  List<Identifier> get selectedHomeUserIDs {
    return selectedHomeUserNodes.map((e) => e.id).toList();
  }

  List<Down4Message> get messages {
    var l = <Down4Message>[];
    for (final msgID in node?.messages.reversed ?? <String>[]) {
      l.add(Down4Message.fromLocal(msgID));
    }
    return l;
  }

  String get currentLocation {
    return _locations.last;
  }

  List<Identifier> get friendIDs {
    return homePalettes
        .where((p) => p.node.type == Nodes.friend)
        .map((e) => e.node.id)
        .toList();
  }

  List<Identifier> get friendAndNonFriendIDs {
    return homePalettes
        .where((p) =>
            p.node.type == Nodes.friend || p.node.type == Nodes.nonFriend)
        .map((e) => e.node.id)
        .toList();
  }

  String get previousLocation {
    if (_locations.length > 2) {
      return _locations[_locations.length - 2];
    }
    throw "Invalid previous location";
  }
  // ============================================================== BUILD ================================================================ //

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case HomePageRenderState.loading:
        return const LoadingPage();

      case HomePageRenderState.home:
        var formattedPalettesInfo = formatedHomePalettes
            .map((e) => <String, dynamic>{
                  "name": e.node.name,
                  "activity": e.node.activity
                })
            .toList();
        print(formattedPalettesInfo);
        return Down4PalettePage(
          palettes: formatedHomePalettes,
          bottomInputs: [
            ConsoleInput(
              tec: tec,
              inputCallBack: (text) => _pingInput = text,
              placeHolder: ":)",
            ),
          ],
          bottomButtons: [
            RealButton(
                showExtra: _extra,
                mainButton: ConsoleButton(
                  name: "Delete",
                  onPress: _extra ? toggleExtra : delete,
                  isSpecial: true,
                  onLongPress: toggleExtra,
                ),
                extraButtons: [
                  ConsoleButton(name: "Nigger", onPress: toggleExtra),
                  ConsoleButton(name: "Shit", onPress: toggleExtra),
                  ConsoleButton(name: "Wacko", onPress: toggleExtra),
                ]),
            RealButton(
              mainButton: ConsoleButton(
                name: "Search",
                onPress: () {
                  pushLocation("Search");
                  putState(HomePageRenderState.addFriend);
                },
              ),
            ),
            RealButton(
              mainButton: ConsoleButton(
                name: "Ping",
                onPress: ping,
              ),
            ),
          ],
          topButtons: [
            RealButton(
              mainButton: ConsoleButton(
                name: "Hyperchat",
                onPress: () => putState(HomePageRenderState.hyperchat),
              ),
            ),
            RealButton(
              mainButton: ConsoleButton(
                name: "Money",
                onPress: () => putState(HomePageRenderState.money),
              ),
            ),
          ],
        );

      case HomePageRenderState.chat:
        return ChatPage(
            d4messages: messages,
            saveMessages: saveMessages, // messages are cached in home for now,
            self: widget.self,
            node: _node!,
            messageRequest: send,
            messages: currentMessages,
            cameras: widget.cameras,
            back: () {
              currentLocation == "Home"
                  ? putState(HomePageRenderState.home)
                  : putState(HomePageRenderState.node);
              _chatMessages.clear();
            });

      case HomePageRenderState.hyperchat:
        return HyperchatPage(
          self: widget.self,
          afterMessageCallback: (node) {
            setPaletteIfAbsent(nodeToPalette("Home", node)!);
            setTheNode(node);
            putState(HomePageRenderState.chat);
          },
          back: () {
            clearInputs();
            putState(HomePageRenderState.home);
          },
          palettes: selectedFriendPalettesDeactivated,
          cameras: widget.cameras,
        );

      case HomePageRenderState.node:
        return NodePage(
          cameras: widget.cameras,
          self: widget.self,
          openChat: openChat,
          palette: getPalette(node!.id, previousLocation)!,
          palettes: getPalettes(node!.id)?.values.toList() ?? <Palette>[],
          saveMessages: saveMessages,
          openNode: openNode,
          nodeToPalette: nodeToPalette,
          back: () {
            popLocation();
            if (currentLocation == "Home") {
              putState(HomePageRenderState.home);
            } else if (currentLocation == "Search") {
              putState(HomePageRenderState.addFriend);
            } else {
              putState(HomePageRenderState.node);
            }
          },
        );

      case HomePageRenderState.addFriend:
        return AddFriendPage(
          self: widget.self,
          addCallback: addUsers,
          search: search,
          palettes: getPalettes("Search")!.values.toList(),
          backCallback: () {
            popLocation();
            getPalettes("Search")?.clear();
            putState(HomePageRenderState.home);
          },
        );

      case HomePageRenderState.money:
        return MoneyPage(
          palettes: selectedFriendPalettesDeactivated,
          back: () {
            clearInputs();
            putState(HomePageRenderState.home);
          },
        );

      case HomePageRenderState.feed:
        return Container();

      case HomePageRenderState.map:
        return Container();
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
