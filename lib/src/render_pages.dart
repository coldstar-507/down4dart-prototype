import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:flutter_testproject/src/wallet.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_player/video_player.dart';
import 'render_objects.dart';
import 'dart:convert';
import 'boxes.dart';
import 'camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'web_requests.dart' as r;
import 'down4_utility.dart' as u;
import 'package:random_words/random_words.dart' as rw;
import 'render_utility.dart';
import 'dart:math' as math;
import 'simple_bsv.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Down4Page extends StatelessWidget {
  final List<Widget>? widgets;
  final List<Palette>? palettes;
  final List<ChatMessage>? messages;
  final List<Widget>? columnWidgets;
  final List<RealButton> bottomButtons;
  final List<RealButton>? topButtons;
  final List<ConsoleInput>? bottomInputs, topInputs;
  final MobileScannerController? scanController;
  final dynamic Function(Barcode, MobileScannerArguments?)? scanCallBack;

  const Down4Page({
    required this.bottomButtons,
    this.columnWidgets,
    this.palettes,
    this.widgets,
    this.messages,
    this.topButtons,
    this.bottomInputs,
    this.topInputs,
    this.scanController,
    this.scanCallBack,
    Key? key,
  }) : super(key: key);

  List<Widget> getExtraTopButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 31) / (topButtons?.length ?? 1);
    List<Widget> extras = [];
    int i = 0;
    for (final b in topButtons ?? <RealButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
            bottom: 16.0 + (ConsoleButton.height * 2),
            left: 16.0 + (buttonWidth * i),
            child: Container(
              height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
              width: (screenWidth - 32) / topButtons!.length,
              decoration: BoxDecoration(border: Border.all(width: 0.5)),
              child: Column(children: b.extraButtons!),
            )));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  List<Widget> getExtraBottomButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 30) / bottomButtons.length;
    List<Widget> extras = [];
    int i = 0;
    for (final b in bottomButtons) {
      if (b.showExtra) {
        extras.add(Positioned(
          bottom: 16.0 + ConsoleButton.height,
          left: 16.0 + (buttonWidth * i),
          child: Container(
            height: (b.extraButtons!.length * ConsoleButton.height) + 1,
            width: buttonWidth,
            decoration: BoxDecoration(border: Border.all(width: 0.5)),
            child: Column(children: b.extraButtons!),
          ),
        ));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final extraBottomButtons = getExtraBottomButtons(screenWidth);
    final extraTopButtons = getExtraTopButtons(screenWidth);
    return Scaffold(
      body: Container(
        color: PinkTheme.backGroundColor,
        child: Stack(
          children: [
            ...widgets ?? [],
            Column(
              children: [
                DynamicList(list: palettes ?? messages ?? columnWidgets ?? []),
                // ...palettes ?? messages ?? columnWidgets ?? [const Spacer()],
                Console(
                  scanCallBack: scanCallBack,
                  scanController: scanController,
                  bottomButtons:
                      bottomButtons.map((e) => e.mainButton).toList(),
                  topButtons: topButtons?.map((e) => e.mainButton).toList(),
                  topInputs: topInputs,
                  inputs: bottomInputs,
                ),
              ],
            ),
            ...extraTopButtons,
            ...extraBottomButtons,
          ],
        ),
      ),
    );
  }
}

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
  final MessageList4 messageList;
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

class GroupPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool isHyperchat;
  final Node self;
  final List<Palette> palettes;
  final void Function(Node) afterMessageCallback;
  final void Function() back;
  const GroupPage({
    required this.isHyperchat,
    required this.self,
    required this.afterMessageCallback,
    required this.back,
    required this.palettes,
    required this.cameras,
    Key? key,
  }) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  dynamic _console;
  dynamic singleInput;
  List<dynamic> _items = [];
  var tec = TextEditingController();

  String _input = "";
  Down4Media? _mediaInput;
  Down4Media? _cameraInput;

  String _hyperchatName = "";
  Down4Media? _hyperchatImage;

  List<Identifier>? _forwardingNodes;

  @override
  void initState() {
    super.initState();
    loadTextInput();
    loadChatConsole();
    loadPalettes();
  }

  PaletteMaker hyperchatMaker() {
    return PaletteMaker(
      id: "", // will calculate the ID on hyperchat creation for hyperchats
      name: _hyperchatName,
      hintText: "(Name)",
      nameCallBack: (name) => setState(() => _hyperchatName = name),
      type: widget.isHyperchat ? Nodes.hyperchat : Nodes.group,
      imageCallBack: (data) {
        final dataForID = widget.self.id.codeUnits + data.toList();
        final imageID = u.generateMediaID(dataForID.asUint8List());
        _hyperchatImage = Down4Media(
          data: data,
          id: imageID,
          metadata: MediaMetadata(
            owner: widget.self.id,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        loadPalettes();
      },
      image: _hyperchatImage?.data ?? Uint8List(0),
    );
  }

  void loadPalettes() {
    _items.clear();
    _items.add(hyperchatMaker());
    _items.addAll(widget.palettes);
    setState(() {});
  }

  void loadCameraConsole() {
    _console = CameraConsole(
      cameras: widget.cameras,
      cameraBack: () {
        loadTextInput();
        loadChatConsole();
      },
      cameraCallBack: (filePath, isVideo, toReverse) {
        if (filePath != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _cameraInput = Down4Media.fromCamera(
            filePath,
            MediaMetadata(
              owner: widget.self.id,
              timestamp: timestamp,
              isVideo: isVideo ?? false,
              toReverse: toReverse ?? false,
            ),
          );
        }
        loadChatConsole();
      },
    );
  }

  Future<void> send() async {
    if (_input != "" || _mediaInput != null || _cameraInput != null) {
      final ts = u.timeStamp();
      var targets = widget.palettes.map((e) => e.node.id).toList()
        ..remove(widget.self.id);
      final wp = rw.WordPair.random(safeOnly: false);
      final root = u.deterministicHyperchatRoot(targets + [widget.self.id]);
      final msg = Down4Message(
        messageID: u.generateMessageID(widget.self.id, ts),
        media: _cameraInput ?? _mediaInput,
        root: root,
        senderName: widget.self.id,
        senderID: widget.self.id,
        senderThumbnail: base64Encode(widget.self.image.thumbnail!),
        forwarderName: widget.self.name,
        isChat: true,
        timestamp: ts,
        text: _input,
        nodes: _forwardingNodes,
      );
      Boxes.instance.saveMessage(msg);
      var hyperchatNode = Node(
        type: Nodes.hyperchat,
        id: root,
        name: wp.first,
        lastName: wp.second,
        image: _hyperchatImage ?? widget.self.image,
        messages: [msg.messageID],
        posts: [],
        friends: [],
        group: targets + [widget.self.id],
        parents: [],
        childs: [],
        admins: [],
        snips: [],
      )..updateActivity();
      Boxes.instance.saveNode(hyperchatNode);
      final f = widget.isHyperchat ? r.hyperchatRequest : r.groupRequest;
      final success = await f(MessageRequest(
        msg: msg,
        targets: targets,
        rootNode: hyperchatNode,
        withUpload: _cameraInput != null,
      ));
      if (success) {
        widget.afterMessageCallback(hyperchatNode);
      }
    }
  }

  void loadChatConsole() {
    _console = Console(
      inputs: [singleInput],
      topButtons: [
        ConsoleButton(
          name: "Images",
          onPress: () => print("TODO"),
        ),
        ConsoleButton(name: "Send", onPress: send),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _mediaInput == null ? "Camera" : "&Camera",
          onPress: loadCameraConsole,
        ),
        ConsoleButton(name: "Ping", onPress: () => print("TODO"))
      ],
    );
  }

  void loadTextInput() {
    singleInput = ConsoleInput(
      tec: tec,
      inputCallBack: (text) => _input = text,
      placeHolder: ":)",
      value: _input,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Down4ColumnBackground(children: [
        DynamicList(list: _items),
        _console ?? const SizedBox.shrink()
      ]),
    );
  }
}

class MoneyPage extends StatefulWidget {
  final double exchangeRate;
  final Wallet wallet;
  final List<Palette> palettes;
  final Node self;
  final void Function() back;
  const MoneyPage({
    required this.wallet,
    required this.exchangeRate,
    required this.palettes,
    required this.back,
    required this.self,
    Key? key,
  }) : super(key: key);

  @override
  _MoneyPageState createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  var tec = TextEditingController();
  Widget? _view;
  ConsoleInput? _cachedMainViewInput;
  final Map<String, dynamic> _currencies = {
    "l": ["USD", "Satoshis"],
    "i": 0,
  };
  final Map<String, dynamic> _paymentMethod = {
    "l": ["Each", "Split"],
    "i": 0,
  };

  int usdToSatoshis(double usds) =>
      ((usds / widget.exchangeRate) * 100000000).floor();

  double satoshisToUSD(int satoshis) =>
      (satoshis / 100000000) * widget.exchangeRate;

  String get satoshis => widget.wallet.balance.toString();

  String get usds => satoshisToUSD(widget.wallet.balance).toString();

  String get currency => _currencies["l"][_currencies["i"]] as String;

  String get method => _paymentMethod["l"][_paymentMethod["i"]] as String;

  int get inputAsSatoshis {
    var amount;
    final numInput = num.parse(tec.value.text);
    if (currency == "Satoshis") {
      amount = method == "Split"
          ? numInput.round()
          : (numInput * widget.palettes.length).round();
    } else {
      amount = method == "Split"
          ? usdToSatoshis(numInput.toDouble())
          : usdToSatoshis(numInput.toDouble() * widget.palettes.length);
    }
    return amount;
  }

  ConsoleInput get mainViewInput => _cachedMainViewInput = ConsoleInput(
        type: TextInputType.number,
        inputCallBack: (txt) => null,
        placeHolder: currency == "USD" ? usds + "\$" : satoshis + " sat",
        tec: tec,
      );

  void rotateMethod() {
    _paymentMethod["i"] = (_paymentMethod["i"] + 1) %
        (_paymentMethod["l"] as List<String>).length;
  }

  void rotateCurrency() {
    _currencies["i"] =
        (_currencies["i"] + 1) % (_currencies["l"] as List<String>).length;
  }

  void emptyMainView([bool scanning = false, bool reloadInput = false]) {
    var len = 0;
    var safe = false;
    var txBuf = <Down4TX>[];
    MobileScannerController? ctrl;
    if (scanning) ctrl = MobileScannerController();
    dynamic onScan(Barcode bc, MobileScannerArguments? args) {
      final raw = bc.rawValue;
      if (raw != null) {
        final decodedJsoni = jsonDecode(raw);
        if (decodedJsoni["len"] != null && decodedJsoni["safe"] != null) {
          len = decodedJsoni["len"];
          safe = decodedJsoni["safe"];
          var tx = Down4TX.fromJson(decodedJsoni["tx"]);
          if (!txBuf.contains(tx)) txBuf.add(tx);
          if (txBuf.length == len) {
            widget.wallet.parsePayment(widget.self, Down4Payment(txBuf, safe));
            emptyMainView(false, true);
          }
        }
      }
    }

    _view = Down4Page(
      scanCallBack: onScan,
      scanController: ctrl,
      bottomInputs: scanning
          ? null
          : [
              reloadInput
                  ? mainViewInput
                  : _cachedMainViewInput ?? mainViewInput,
            ],
      topButtons: [
        RealButton(
            mainButton: ConsoleButton(
                name: "Scan", onPress: () => emptyMainView(!scanning)))
      ],
      bottomButtons: [
        RealButton(
            mainButton: ConsoleButton(name: "Back", onPress: widget.back)),
        RealButton(
          mainButton: ConsoleButton(
            isMode: true,
            name: currency,
            onPress: () {
              rotateCurrency();
              emptyMainView(scanning, true);
            },
          ),
        ),
      ],
    );
    setState(() {});
  }

  void mainView([bool reloadInput = false]) {
    _view = Down4Page(
      palettes: widget.palettes,
      bottomInputs: [
        reloadInput ? mainViewInput : _cachedMainViewInput ?? mainViewInput,
      ],
      bottomButtons: [
        RealButton(
          mainButton: ConsoleButton(name: "Back", onPress: widget.back),
        ),
        RealButton(
          mainButton: ConsoleButton(
              name: method,
              isMode: true,
              onPress: () {
                rotateMethod();
                mainView();
              }),
        ),
        RealButton(
          mainButton: ConsoleButton(
              name: currency,
              isMode: true,
              onPress: () {
                rotateCurrency();
                mainView(tec.value.text.isEmpty ? true : false);
              }),
        ),
      ],
      topButtons: [
        RealButton(
          mainButton: ConsoleButton(
            name: "Bill",
            onPress: () => print("TODO"),
          ),
        ),
        RealButton(
          mainButton: ConsoleButton(
            name: "Pay",
            onPress: () => confirmationView(currency),
          ),
        ),
      ],
    );
    setState(() {});
  }

  void confirmationView(String inputCurrency, [bool reload = true]) {
    double asUSD;
    int asSats;
    if (inputCurrency == "USD") {
      asUSD = num.parse(tec.value.text).toDouble() *
          (method == "Split" ? 1.0 : widget.palettes.length);
      asSats = usdToSatoshis(asUSD);
    } else {
      asSats = num.parse(tec.value.text).toInt() *
          (method == "Split" ? 1 : widget.palettes.length);
      asUSD = satoshisToUSD(asSats);
    }
    // puts commas for every power of 1000 for the sats amount
    var satsString = String.fromCharCodes(asSats
        .toString()
        .codeUnits
        .reversed
        .toList()
        .asMap()
        .map((key, value) => key % 3 == 0 && key != 0
            ? MapEntry(key, [value, 0x002C])
            : MapEntry(key, [value]))
        .values
        .reduce((value, element) => [...element, ...value]));

    _view = Down4Page(
      palettes: widget.palettes,
      bottomInputs: [
        ConsoleInput(
          inputCallBack: (txt) => null,
          placeHolder: currency == "USD"
              ? asUSD.toStringAsFixed(4) + " \$"
              : satsString + " sat",
          tec: tec,
          activated: false,
        ),
      ],
      topButtons: [
        RealButton(
          mainButton: ConsoleButton(
              name: "Confirm",
              onPress: () {
                final pay = widget.wallet.payUsers(
                  widget.palettes.map((p) => p.node).toList(),
                  widget.self,
                  Sats(inputAsSatoshis),
                );
                if (pay != null) {
                  widget.wallet.trySettlement();
                  transactedView(pay);
                }
              }),
        ),
      ],
      bottomButtons: [
        RealButton(mainButton: ConsoleButton(name: "Back", onPress: mainView)),
        RealButton(
          mainButton: ConsoleButton(
            name: currency,
            isMode: true,
            onPress: () {
              rotateCurrency();
              confirmationView(inputCurrency);
            },
          ),
        ),
      ],
    );
    if (reload) setState(() {});
  }

  void transactedView(Down4Payment pay, [int i = 0, bool reload = true]) {
    Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => transactedView(pay, (i + 1) % pay.txs.length),
    );

    _view = Down4Page(
      widgets: [
        Positioned(
          top: 0,
          left: 0,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: QrImage(
              data: jsonEncode(pay.toJsoni(i)),
              foregroundColor: PinkTheme.qrColor,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ],
      bottomButtons: [
        RealButton(
          mainButton: ConsoleButton(name: "Done", onPress: widget.back),
        ),
      ],
    );

    if (reload) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_view == null) widget.palettes.isEmpty ? emptyMainView() : mainView();
    return _view!;
  }
}

class AddFriendPage extends StatefulWidget {
  final Node self;
  final List<Palette> palettes;
  final List<CameraDescription> cameras;
  final Future<bool> Function(String) search;
  final void Function(List<Node>) addCallback;
  final void Function() backCallback;
  const AddFriendPage({
    required this.palettes,
    required this.search,
    required this.cameras,
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
  bool _scanning = false;
  CameraController? _cameraController;

  Future<void> initController() async {
    try {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.low,
      );
      await _cameraController?.initialize();
      await _cameraController?.setFlashMode(FlashMode.off);
    } catch (err) {
      rethrow;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _consoleInputRef = consoleInput;
  }

  @override
  void dispose() {
    super.dispose();
    _cameraController?.dispose();
  }

  Future<void> toggleScan() async {
    await initController();

    _scanning = !_scanning;
    setState(() {});
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
      cameraPreview: _scanning ? CameraPreview(_cameraController!) : null,
      aspectRatio: _cameraController?.value.aspectRatio,
      inputs: !_scanning ? [_consoleInputRef ?? consoleInput] : null,
      topButtons: [
        ConsoleButton(
          name: "Add",
          onPress: () => widget.addCallback(
            widget.palettes
                .where((element) => element.selected)
                .map((e) => e.node)
                .toList(),
          ),
        ),
        ConsoleButton(
          name: "Search",
          onPress: () async => await widget.search(_input) ? tec.clear() : null,
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.backCallback),
        ConsoleButton(name: "Scan", onPress: toggleScan),
        ConsoleButton(name: "Forward", onPress: () => print("FORWARD")),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Down4StackBackground(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 27, right: 44, left: 44),
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
    return Scaffold(
      body: Down4ColumnBackground(
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
                _loadInitConsole();
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
      ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  final void Function() _understood;
  final String _mnemonic;
  final Node _userInfo;
  const WelcomePage({
    required String mnemonic,
    required Node userInfo,
    required void Function() understood,
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
  final void Function() back;
  const NodePage({
    required this.cameras,
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
                    margin: const EdgeInsets.only(top: 27),
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
  final Future<bool> Function(MessageRequest req) send;
  final void Function() back;
  const ChatPage({
    required this.send,
    required this.self,
    required this.node,
    required this.back,
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
  Map<Identifier, Down4Media> _images = {};
  Map<Identifier, ChatMessage> _messages = {};

  List<Down4Media> get images {
    if (_images.isEmpty && Boxes.instance.images.keys.isEmpty) {
      return <Down4Media>[];
    } else if (_images.values.isEmpty &&
        Boxes.instance.images.keys.isNotEmpty) {
      for (final mediaID in Boxes.instance.images.keys) {
        _images[mediaID] = Boxes.instance.loadImage(mediaID);
      }
      return _images.values.toList();
    } else {
      return _images.values.toList();
    }
  }

  ConsoleInput get consoleInput => _consoleInput = ConsoleInput(
        tec: tec,
        inputCallBack: (t) => _textInput = t,
        value: _textInput,
        placeHolder: ":)",
        // placeHolder: widget.node.name,
        // placeHolder: widget.node.name +
        //     ((widget.node.lastName != null && widget.node.lastName != "")
        //         ? " " + widget.node.lastName!
        //         : ""),
      );

  Console get mediasConsole => Console(
        images: true,
        medias: images,
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
          ConsoleButton(name: "Save", onPress: saveSelectedMessages),
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
    final ts = u.timeStamp();
    for (final pf in r?.files ?? <PlatformFile>[]) {
      if (pf.bytes != null) {
        final compressedData = await FlutterImageCompress.compressWithList(
          pf.bytes!,
          minHeight: 520,
          minWidth: 0,
        );
        final mediaID = u.generateMediaID(compressedData);
        _images[mediaID] = Down4Media(
          id: mediaID,
          data: compressedData,
          metadata: MediaMetadata(owner: widget.self.id, timestamp: ts),
        );
        Boxes.instance.saveImage(_images[mediaID]!);
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

  void saveSelectedMessages() {
    for (final msg in _messages.values) {
      if (msg.selected) {
        if (msg.message.media != null) {
          if (msg.message.media!.metadata.isVideo) {
            Boxes.instance.saveVideo(msg.message.media!);
          } else {
            Boxes.instance.saveImage(msg.message.media!);
          }
        }
        _messages[msg.message.messageID] = msg.invertedSelection();
      }
    }
    setState(() {});
  }

  void clearInputs() {
    tec.clear();
    _textInput = "";
    _cameraInput = null;
    _mediaInput = null;
  }

  void send() {
    if (_textInput != "" || _cameraInput != null || _mediaInput != null) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final targets = widget.node.group.isEmpty
          ? [widget.node.id]
          : List<String>.from(widget.node.group)
        ..remove(widget.self.id);
      var msg = Down4Message(
        messageID: u.generateMessageID(widget.self.id, ts),
        root: widget.node.id,
        timestamp: ts,
        senderID: widget.self.id,
        senderName: widget.self.name,
        senderThumbnail: base64Encode(widget.self.image.thumbnail!),
        media: _cameraInput ?? _mediaInput,
        text: _textInput,
      );
      Boxes.instance.saveMessage(msg);
      widget.send(MessageRequest(targets: targets, msg: msg));
      clearInputs();
      setState(() {});
    }
  }

  // When dynamically loaded from MessageList2
  // the Messages are cached in _messages
  // There is not limit to this cache, which could be dangerous
  void cacheMessage(ChatMessage msg) {
    _messages[msg.message.messageID] = msg;
    // setState(() {}); // should we reload MessageList2 like this?
  }

  void selectMessage(Identifier id, _) {
    _messages[id] = _messages[id]!.invertedSelection();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessagePage(
        messageList: MessageList4(
          messageMap: _messages,
          cache: cacheMessage,
          select: selectMessage,
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
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Node self;
  final Wallet wallet;
  const HomePage({
    required this.cameras,
    required this.self,
    required this.wallet,
    Key? key,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var box = Boxes.instance;
  Widget? _view;
  Wallet? _wallet;
  Map<String, dynamic> exchangeRate = {};
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

  // Node? _node; // the node we are currently traversing, always null at start
  // List<String> _locations = ["Home"]; // to keep an history of traversed nodes
  List<Map<String, String>> _loc = [
    {"at": "Home"}
  ];
  // we pop it when backing in node views
  // when it's empty we should be on home view
  // if _currentLocation is not "Home", it should be _node.id

  var _tec = TextEditingController();
  String _pingInput = "";
  bool _extra = false;

  // ======================================================= INITIALIZATION ============================================================ //

  @override
  void initState() {
    super.initState();
    exchangeRate = box.loadExchangeRate() ?? {"rate": 0.0, "update": 0};
    updateExchangeRate();
    loadLocalHomePalettes();
    processMessageQueue();
    initializeMessageListener();
    homePage();
  }

  Future<void> updateExchangeRate() async {
    final lastUpdate = exchangeRate["update"] as int;
    final rightNow = u.timeStamp();
    if (rightNow - lastUpdate > const Duration(minutes: 10).inMilliseconds) {
      final rate = await r.getExchangeRate();
      if (rate != null) {
        exchangeRate["rate"] = rate;
        exchangeRate["update"] = rightNow;
        box.saveExchangeRate(exchangeRate);
        if (_view is MoneyPage) moneyPage();
      }
    }
  }

  void loadLocalHomePalettes() {
    final jsonEncodedHomeNodes = box.home.values;
    for (final jsonEncodedHomeNode in jsonEncodedHomeNodes) {
      final node = Node.fromJson(jsonDecode(jsonEncodedHomeNode));
      final p = nodeToPalette("Home", node);
      if (p != null) {
        _palettes["Home"]!.putIfAbsent(node.id, () => p);
      }
    }
  }

  void initializeMessageListener() {
    FirebaseMessaging.onMessage.listen((event) async {
      final notif = MessageNotification.fromNotification(
        Map<String, String>.from(event.data),
      );
      event.data["sdrtn"] = "";
      event.data["fdrtn"] = "";
      print("Received message: ${event.data}");
      parseMessageNotification(notif);
    });
  }

  Future<void> processMessageQueue() async {
    for (final messageData in box.messageQueue.values) {
      final notif = MessageNotification.fromNotification(
          Map<String, String>.from(messageData));
      await parseMessageNotification(notif);
    }
    await box.messageQueue.clear();
    box.messageQueue.close();
  }

  // ======================================================= UTILS ============================================================ //

  void unselectSelectedHomePalettes([bool updateActivity = false]) {
    if (updateActivity) {
      for (final p in homePalettes) {
        if (p.selected) {
          _palettes[p.at]
              ?[p.node.id] = _palettes[p.at]![p.node.id]!.invertedSelection()
            ..node.updateActivity();
        }
      }
    } else {
      for (final p in homePalettes) {
        if (p.selected) {
          _palettes[p.at]?[p.node.id] =
              _palettes[p.at]![p.node.id]!.invertedSelection();
        }
      }
    }
  }

  Palette? nodeToPalette(String at, Node node) {
    switch (node.type) {
      case Nodes.user:
        final friendIDs = homePalettes
            .where((p) => p.node.type == Nodes.friend)
            .map((e) => e.node.id)
            .toList();
        return friendIDs.contains(node.id)
            ? nodeToPalette(at, node.mutatedType(Nodes.friend))
            : nodeToPalette(at, node.mutatedType(Nodes.nonFriend));

      case Nodes.root:
        return Palette(
          node: node,
          at: at, // todo
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
          at: at,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: at == "Home" && node.snips.isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
              pressFunc: at == "Home"
                  ? node.snips.isNotEmpty
                      ? checkSnips
                      : openChat
                  : openNode,
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
          final msg = box.loadMessage(lastMessageID);
          if (msg.timestamp.isExpired) {
            box.deleteNode(node.id);
            return null;
          }
        }
        return Palette(
          node: node,
          at: at,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              rightMost: true,
              pressFunc: node.snips.isNotEmpty ? checkSnips : openChat,
              assetPath: node.snips.isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
            )
          ],
        );
      case Nodes.event:
        break;
      case Nodes.checkpoint:
        return Palette(
          node: node,
          at: at,
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
          at: at,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: at == "Home" && node.snips.isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
              pressFunc: at == "Home"
                  ? node.snips.isNotEmpty
                      ? checkSnips
                      : openChat
                  : openNode,
              longPressFunc: openNode,
              rightMost: true,
            )
          ],
        );

      case Nodes.group:
        return Palette(
          node: node,
          at: at,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              rightMost: true,
              pressFunc: node.snips.isNotEmpty ? checkSnips : openChat,
              assetPath: node.snips.isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
            )
          ],
        );
    }
    return null;
  }

  Future<void> handleSnipCameraCallback(
    String? path,
    bool? isVideo,
    bool? toReverse,
    String? text,
    double aspectRatio,
  ) async {
    if (path != null) {
      final timestamp = u.timeStamp();
      var media = Down4Media.fromCamera(
        path,
        MediaMetadata(
          owner: widget.self.id,
          timestamp: timestamp,
          toReverse: toReverse ?? false,
          isVideo: isVideo ?? false,
          text: text,
          aspectRatio: aspectRatio,
        ),
      );
      var success = r.snipRequest(MessageRequest(
        withUpload: true,
        msg: Down4Message(
            messageID: "", // can be ommited
            root: homePalettes
                .where((p) => p.selected)
                .map((e) => e.node.id)
                .toList()
                .join(" "), // can be omited
            timestamp: timestamp,
            media: media,
            senderID: widget.self.id,
            senderName: widget.self.name,
            senderLastName: widget.self.lastName,
            senderThumbnail: base64Encode(widget.self.image.thumbnail!)),
        targets: selectedHomeUserIDs,
      ));
      homePage();
      if (await success) {
        unselectSelectedHomePalettes(true);
        homePage();
      }
    } else {
      homePage();
    }
  }

  Future<void> parseMessageNotification(MessageNotification notif) async {
    switch (notif.type) {
      case Messages.chat:
        {
          var msg = await notif.toDown4Message();
          if (msg.root == widget.self.id) {
            msg.root = msg.senderID;
          }
          if (nodeAt(msg.root) != null) {
            nodeAt(msg.root)!
              ..messages.add(msg.messageID)
              ..updateActivity();
            box.saveNode(nodeAt(msg.root)!);
            box.saveMessage(msg);
          } else {
            // not in home -> fetch the node
            final nonFriend = await r.getNodes([msg.root]);
            // save it locally with proper type and activity
            if (nonFriend?.isNotEmpty ?? false) {
              writePalette(
                nonFriend!.first
                  ..mutateType(Nodes.nonFriend)
                  ..messages.add(msg.messageID)
                  ..updateActivity(),
              );
              box.saveNode(nonFriend.first);
              box.saveMessage(msg);
            }
          }
          _view is Down4PalettePage
              ? homePage()
              : _loc.last["type"] == "Chat" && _loc.last["id"] == msg.root
                  ? chatPage(nodeAt(msg.root)!)
                  : null;
          break;
        }

      case Messages.hyperchat:
        {
          final msg = await notif.toDown4Message();
          final node = (await notif.nodeOfHyperchat())
            ?..messages.add(msg.messageID)
            ..updateActivity();
          if (node != null) {
            box.saveNode(node);
            box.saveMessage(msg);
            writePalette(node);
          }
          _view is Down4PalettePage
              ? homePage()
              : _loc.last["type"] == "Chat" && _loc.last["id"] == msg.root
                  ? chatPage(nodeAt(msg.root)!)
                  : null;
          break;
        }

      case Messages.group:
        {
          final msg = await notif.toDown4Message();
          var node = (await notif.nodeOfGroup())
            ?..messages.add(msg.messageID)
            ..updateActivity();
          if (node != null) {
            box.saveNode(node);
            box.saveMessage(msg);
            writePalette(node);
          }
          _view is Down4PalettePage
              ? homePage()
              : _loc.last["type"] == "Chat" && _loc.last["id"] == msg.root
                  ? chatPage(nodeAt(msg.root)!)
                  : null;
          break;
        }

      case Messages.snip:
        {
          Future<void> fetchAndSaveSnip() async {
            final media = await r.getMessageMedia(notif.mediaID!);
            if (media != null) {
              box.snip.put(media.id, jsonEncode(media));
            }
          }

          void updateNode(Node node) {
            writePalette(
              node
                ..updateActivity()
                ..snips.add(notif.mediaID!),
            );
            box.saveNode(node);
          }

          final roots = notif.root.split(" ");
          for (final root in roots) {
            if (root == widget.self.id) {
              Node? node;
              if ((node = nodeAt(notif.senderID)) != null) {
                if (node!.type == Nodes.friend) {
                  fetchAndSaveSnip();
                }
                updateNode(node);
              } else {
                var nodes = await r.getNodes([notif.senderID]);
                node = nodes == null ? null : nodes.first;
                if (node != null) {
                  updateNode(node);
                }
              }
            } else if (groupRoots.contains(root)) {
              fetchAndSaveSnip();
              updateNode(nodeAt(root)!);
            }
          }

          _view is Down4PalettePage ? homePage() : null;
          break;
        }

      case Messages.ping:
        {
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
      _palettes["Search"]![friend.id] = _palettes["Search"]![friend.id]!
          .invertedSelection()
        ..node.mutateType(Nodes.friend);

      _palettes["Home"]!.putIfAbsent(
        friend.id,
        () => nodeToPalette(
          "Home",
          friend
            ..mutateType(Nodes.friend)
            ..updateActivity(),
        )!,
      );
      box.saveNode(friend);
    }
    searchPage();
  }

  Future<bool> ping() async {
    // TODO
    return true;
  }

  void delete() {
    for (final p in homePalettes.toList().where((e) => e.selected)) {
      box.deleteNode(p.node.id);
      _palettes["Home"]?.remove(p.node.id);
    }
    homePage();
  }

  Future<bool> search(String id) async {
    final nodes = await r.getNodes([id]);
    var node = nodes == null ? null : nodes.first;
    if (node != null) {
      node.updateActivity();
      final p = nodeToPalette("Search", node);
      if (p != null) {
        _palettes["Search"]?.putIfAbsent(node.id, () => p);
        searchPage();
        return true;
      }
    }
    return false;
  }

  void toggleExtra() {
    _extra = !_extra;
    homePage();
  }

  Future<bool> chatRequest(MessageRequest req) async {
    final success = r.chatRequest(req);
    final node = nodeAt(req.msg.root)!;
    chatPage(node
      ..messages.add(req.msg.messageID)
      ..updateActivity());
    box.saveNode(node);
    return await success;
  }

  // ======================================================== NODE ACTIONS ============================================================== //

  Future<void> openNode(String id, String at) async {
    if (_palettes[id] == null) {
      Node node;
      if (at == "Home") {
        final nodes = await r.getNodes([id]);
        if (nodes == null) {
          return;
        }
        node = nodes.first;
      } else {
        node = nodeAt(id, at)!;
      }
      final childNodes = await r.getNodes(node.childs);
      if (childNodes != null) {
        for (final node in childNodes) {
          _palettes[id]!.putIfAbsent(node.id, () => nodeToPalette(id, node)!);
        }
      }
    }
    _loc.add({"type": "Node", "id": id, "at": at});
    nodePage(nodeAt(id, at)!);
  }

  void select(String id, String at) {
    _palettes[at]![id] = _palettes[at]![id]!.invertedSelection();
    _loc.last["at"] == "Home"
        ? homePage()
        : _loc.last["at"] == "Search"
            ? searchPage()
            : nodePage(nodeAt(at, previousLocation["id"]!)!);
  }

  void openChat(String id, String at) {
    _loc.add({"at": at, "id": id, "type": "Chat"});
    chatPage(nodeAt(id, at)!);
  }

  void checkSnips(String id, String at) {
    snipView(nodeAt(id, at)!);
  }

  // ======================================================== COMPLEXITY REDUCING GETTERS ? =============================================== //

  Palette? paletteAt(String id, [String at = "Home"]) {
    return _palettes[at]?[id];
  }

  Node? nodeAt(String id, [String at = "Home"]) {
    return _palettes[at]?[id]?.node;
  }

  void writePalette(Node node, [String at = "Home"]) {
    _palettes[at]?[node.id] = nodeToPalette(at, node)!;
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
    final selectedNonGroups = formatedHomePalettes.where(
      (p) => (p.node.type == Nodes.friend) && p.selected,
    );
    for (final pal in selectedNonGroups) {
      if (!idsInSelGroups.contains(pal.node.id)) {
        palettes.add(pal.deactivated());
      }
    }

    return palettes;
  }

  List<Palette> get selectedHomeUserPaletteDeactivated {
    var selectedGroups = formatedHomePalettes.where(
      (p) =>
          (p.node.type == Nodes.hyperchat || p.node.type == Nodes.group) &&
          p.selected,
    );
    var idsInSelGroups = <Identifier>[];
    for (final shc in selectedGroups) {
      for (final uid in shc.node.group) {
        if (!idsInSelGroups.contains(uid)) {
          idsInSelGroups.add(uid);
        }
      }
    }

    var palettes = <Palette>[];
    for (final id in idsInSelGroups) {
      if (paletteAt(id) != null) {
        palettes.add(paletteAt(id)!.deactivated());
      }
    }

    final selectedNonGroups = formatedHomePalettes.where(
      (p) =>
          (p.node.type == Nodes.friend || p.node.type == Nodes.nonFriend) &&
          p.selected,
    );
    for (final pal in selectedNonGroups) {
      if (!idsInSelGroups.contains(pal.node.id)) {
        palettes.add(pal.deactivated());
      }
    }

    return palettes;
  }

  List<Identifier> get selectedHomeUserIDs {
    return selectedHomeUserPaletteDeactivated.map((e) => e.node.id).toList();
  }

  List<Palette> get homePalettes {
    return _palettes["Home"]!.values.toList();
  }

  List<Palette> get formatedHomePalettes {
    return homePalettes
      ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  }

  Map<String, String> get previousLocation {
    if (_loc.length > 2) {
      return _loc[_loc.length - 2];
    }
    throw "Invalid previous location";
  }

  List<Identifier> get groupRoots {
    return homePalettes
        .where(
            (e) => const [Nodes.group, Nodes.hyperchat].contains(e.node.type))
        .map((e) => e.node.id)
        .toList();
  }

  // ============================================================== BUILD ================================================================ //

  void homePage() {
    _view = Down4PalettePage(
      palettes: formatedHomePalettes,
      bottomInputs: [
        ConsoleInput(
          tec: _tec,
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
              _loc.add({"at": "Search"});
              searchPage();
            },
          ),
        ),
        RealButton(
          mainButton: ConsoleButton(
            name: "Ping",
            onPress: ping,
            onLongPress: snipPage,
            isSpecial: true,
          ),
        ),
      ],
      topButtons: [
        RealButton(
          mainButton: ConsoleButton(
            name: "Chat",
            onPress: hyperchatPage,
          ),
        ),
        RealButton(
          mainButton: ConsoleButton(
            name: "Money",
            onPress: moneyPage,
          ),
        ),
      ],
    );
    setState(() {});
  }

  void moneyPage() {
    updateExchangeRate();
    print(exchangeRate);
    _view = MoneyPage(
      self: widget.self,
      wallet: widget.wallet,
      exchangeRate: exchangeRate["rate"],
      palettes: selectedHomeUserPaletteDeactivated,
      back: homePage,
    );
    setState(() {});
  }

  void hyperchatPage() {
    _view = GroupPage(
      isHyperchat: true,
      self: widget.self,
      afterMessageCallback: (node) {
        _palettes["Home"]!
            .putIfAbsent(node.id, () => nodeToPalette("Home", node)!);
        _loc.add({"at": "Home", "id": node.id, "type": "Chat"});
        chatPage(node);
      },
      back: homePage,
      palettes: selectedHomeUserPaletteDeactivated,
      cameras: widget.cameras,
    );
    setState(() {});
  }

  void searchPage() {
    _view = AddFriendPage(
      cameras: widget.cameras,
      self: widget.self,
      search: search,
      palettes: _palettes["Search"]?.values.toList().reversed.toList() ?? [],
      addCallback: addUsers,
      backCallback: () {
        _loc.removeLast();
        _palettes["Search"]?.clear();
        homePage();
      },
    );
    setState(() {});
  }

  void nodePage(Node node) {
    _view = NodePage(
      cameras: widget.cameras,
      self: widget.self,
      openChat: openChat,
      palette: _palettes[_loc.last["at"]!]![node.id]!,
      palettes: _palettes[node.id]?.values.toList() ?? <Palette>[],
      openNode: openNode,
      nodeToPalette: nodeToPalette,
      back: () {
        _loc.removeLast();
        if (_loc.last["at"] == "Home" && _loc.last["type"] == null) {
          homePage();
        } else if (_loc.last["at"] == "Search" && _loc.last["type"] == null) {
          searchPage();
        } else if (_loc.last["type"] == "Node") {
          nodePage(nodeAt(_loc.last["id"]!, _loc.last["at"]!)!);
        } else if (_loc.last["type"] == "Chat") {
          chatPage(nodeAt(_loc.last["id"]!, _loc.last["at"]!)!);
        }
      },
    );
    setState(() {});
  }

  Future<void> snipPage({
    CameraController? ctrl,
    camera = 0,
    res = ResolutionPreset.medium,
    bool reload = false,
  }) async {
    ResolutionPreset nextRes() => res == ResolutionPreset.low
        ? ResolutionPreset.medium
        : res == ResolutionPreset.medium
            ? ResolutionPreset.high
            : ResolutionPreset.low;

    int nextCam() => camera == 0 ? 1 : 0;

    void snip() async {
      _view = SnipCamera(
        maxZoom: await ctrl!.getMaxZoomLevel(),
        minZoom: await ctrl.getMinZoomLevel(),
        camNum: camera,
        cameraBack: homePage,
        cameraCallBack: handleSnipCameraCallback,
        ctrl: ctrl,
        nextRes: () => snipPage(
          ctrl: ctrl,
          res: nextRes(),
          camera: camera,
          reload: true,
        ),
        flip: () => snipPage(
          ctrl: ctrl,
          res: res,
          camera: nextCam(),
          reload: true,
        ),
      );
      setState(() {});
    }

    if (ctrl == null || reload) {
      ctrl = CameraController(widget.cameras[camera], res);
      await ctrl.initialize();
      snip();
    }
  }

  void chatPage(Node node) {
    _view = ChatPage(
        send: chatRequest,
        self: widget.self,
        node: node,
        cameras: widget.cameras,
        back: () {
          _loc.removeLast();
          if (_loc.last["at"] == "Home" && _loc.last["type"] == null) {
            homePage();
          } else if (_loc.last["at"] == "Search" && _loc.last["type"] == null) {
            searchPage();
          } else if (_loc.last["type"] == "Node") {
            nodePage(nodeAt(_loc.last["id"]!, _loc.last["at"]!)!);
          } else if (_loc.last["type"] == "Chat") {
            chatPage(nodeAt(_loc.last["id"]!, _loc.last["at"]!)!);
          }
        });
    setState(() {});
  }

  Future<void> snipView(Node node) async {
    final mediaSize = MediaQuery.of(context).size; // full screen
    if (node.snips.isEmpty) {
      writePalette(node);
      homePage();
    } else {
      final snip = node.snips.first;
      node.snips.remove(snip); // consume it
      box.saveNode(node);
      Down4Media? media;
      dynamic jsonEncodedMedia;
      if ((jsonEncodedMedia = box.snip.get(snip)) == null) {
        media = await r.getMessageMedia(snip);
      } else {
        media = Down4Media.fromJson(jsonDecode(jsonEncodedMedia));
        box.snip.delete(snip); // consume it
      }
      if (media == null) {
        writePalette(node);
        homePage();
      }
      final scale =
          1 / (media!.metadata.aspectRatio ?? 1.0 * mediaSize.aspectRatio);
      if (media.metadata.isVideo) {
        var f = box.writeMediaToFile(media);
        var ctrl = VideoPlayerController.file(f);
        await ctrl.initialize();
        await ctrl.setLooping(true);
        await ctrl.play();
        _view = Down4StackBackground2(
          children: [
            SizedBox(
              height: mediaSize.height,
              width: mediaSize.width,
              child: Transform.scale(
                scaleX: 1 / scale,
                child: Transform(
                  alignment: Alignment.center,
                  transform:
                      Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
                  child: VideoPlayer(ctrl),
                ),
              ),
            ),
            media.metadata.text != "" && media.metadata.text != null
                ? Center(
                    child: Container(
                      width: mediaSize.width,
                      decoration: const BoxDecoration(
                        // border: Border.symmetric(
                        //   horizontal: BorderSide(color: Colors.black38),
                        // ),
                        color: Colors.black38,
                        // color: PinkTheme.snipRibbon,
                      ),
                      constraints: BoxConstraints(
                        minHeight: 16,
                        maxHeight: mediaSize.height,
                      ),
                      child: Text(
                        media.metadata.text!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                : const SizedBox.shrink()
          ],
          bottomButtons: [
            RealButton(
              mainButton: ConsoleButton(
                name: "Back",
                onPress: () async {
                  await ctrl.dispose();
                  f.delete();
                  writePalette(node);
                  homePage();
                },
              ),
            ),
            RealButton(
              mainButton: ConsoleButton(
                name: "Next",
                onPress: () async {
                  await ctrl.dispose();
                  f.delete();
                  snipView(node);
                },
              ),
            ),
          ],
        );
      } else {
        await precacheImage(MemoryImage(media.data), context);
        _view = Down4StackBackground2(
          children: [
            SizedBox(
              height: mediaSize.height,
              width: mediaSize.width,
              child: Transform(
                alignment: Alignment.center,
                transform:
                    Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
                child: Image.memory(
                  media.data,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
            media.metadata.text != "" && media.metadata.text != null
                ? Center(
                    child: Container(
                      width: mediaSize.width,
                      decoration: const BoxDecoration(
                        // border: Border.symmetric(
                        //   horizontal: BorderSide(color: Colors.black38),
                        // ),
                        color: Colors.black38,
                        // color: PinkTheme.snipRibbon,
                      ),
                      constraints: BoxConstraints(
                        minHeight: 16,
                        maxHeight: mediaSize.height,
                      ),
                      child: Text(
                        media.metadata.text!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                : const SizedBox.shrink()
          ],
          bottomButtons: [
            RealButton(
              mainButton: ConsoleButton(
                name: "Back",
                onPress: () {
                  writePalette(node);
                  homePage();
                },
              ),
            ),
            RealButton(
              mainButton: ConsoleButton(
                name: "Next",
                onPress: () => snipView(node),
              ),
            ),
          ],
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _view ?? const LoadingPage();
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
