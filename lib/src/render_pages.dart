import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bip32/bip32.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:english_words/english_words.dart' as rw;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scroll_navigation/scroll_navigation.dart';
import 'customized_packages/custom_scroll_navigation/scroll_navigation.dart'
    as custom_scroll;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'render_objects.dart';
import 'boxes.dart';
import 'camera.dart';
import 'web_requests.dart' as r;
import 'down4_utility.dart' as u;
import 'render_utility.dart';
import 'themes.dart';

import 'simple_bsv.dart';

class Down4Navigator extends StatelessWidget {
  final List<Down4Page> pages;
  final navigationKey = GlobalKey<ScrollNavigationState>();

  Down4Navigator(this.pages, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TitleScrollNavigation(
      showIdentifier: false,
      bodyStyle: const NavigationBodyStyle(background: PinkTheme.qrColor),
      barStyle: const TitleNavigationBarStyle(
        style: TextStyle(fontSize: 18),
        padding: EdgeInsets.all(5.0),
        background: PinkTheme.qrColor,
        activeColor: Colors.white,
        deactiveColor: Colors.white24,
      ),
      // identiferStyle: NavigationIdentiferStyle(
      //   color: pages.length > 1 ? Colors.redAccent : PinkTheme.qrColor,
      // ),
      titles: pages.map((p) => p.title).toList(growable: false),
      pages: pages,
    );

    // return ScrollNavigation(
    //   // bodyStyle: const NavigationBodyStyle(background: PinkTheme.qrColor),
    //   barStyle: const NavigationBarStyle(
    //     verticalPadding: 5.0,
    //     position: NavigationPosition.top,
    //     background: PinkTheme.qrColor,
    //   ),
    //   identiferStyle: NavigationIdentiferStyle(
    //     color: pages.length > 1 ? Colors.redAccent : PinkTheme.qrColor,
    //   ),
    //   pages: pages,
    //   items: titles,
    // );
  }
}

class Down4Navigator2 extends StatefulWidget {
  final int firstPage;
  final List<Page> pages;
  final navigationKey = GlobalKey<ScrollNavigationState>();
  Down4Navigator2({
    required this.pages,
    required this.firstPage,
    Key? key,
  }) : super(key: key);

  @override
  _Down4Navigator2State createState() => _Down4Navigator2State();
}

class _Down4Navigator2State extends State<Down4Navigator2> {
  int _currentPage = 0;
  Widget? _view;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.firstPage;
  }

  void onPageChange(int newPage) {
    _currentPage = newPage;
    print("New page: $newPage");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Jeff(
      titles: widget.pages.map((e) => e.pageBody.title).toList(growable: false),
      bodies: widget.pages.map((e) => e.pageBody).toList(growable: false),
      consoles: widget.pages.map((e) => e.pageConsole).toList(growable: false),
      index: widget.firstPage,
    );

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: Sizes.h - 60,
            child: custom_scroll.TitleScrollNavigation(
              initialPage: _currentPage,
              pageChangeCurrentIndex: onPageChange,
              showIdentifier: false,
              // bodyStyle: const NavigationBodyStyle(
              //   background: PinkTheme.backGroundColor,
              // ),
              barStyle: const TitleNavigationBarStyle(
                style: TextStyle(fontSize: 18),
                padding: EdgeInsets.all(5.0),
                background: PinkTheme.qrColor,
                activeColor: Colors.white,
                deactiveColor: Colors.white24,
              ),
              titles: widget.pages
                  .map((p) => p.pageBody.title)
                  .toList(growable: false),
              pages:
                  widget.pages.map((p) => p.pageBody).toList(growable: false),
            ),
          ),
          widget.pages[_currentPage].pageConsole,
        ],
      ),
    );
  }
}

class PageBody extends StatelessWidget {
  final String title;
  final List<Widget>? stackWidgets;
  final List<Palette>? palettes;
  final List<ChatMessage>? messages;
  final MessageList4? messageList;
  final List<Widget>? columnWidgets;

  const PageBody({
    required this.title,
    this.columnWidgets,
    this.palettes,
    this.stackWidgets,
    this.messageList,
    this.messages,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...(stackWidgets ?? []),
        messageList ??
            ((palettes != null || messages != null || columnWidgets != null)
                ? DynamicList(list: palettes ?? messages ?? columnWidgets!)
                : const SizedBox.shrink()),
      ],
    );
  }
}

class PageConsole extends StatelessWidget {
  final Console console;
  const PageConsole({required this.console, Key? key}) : super(key: key);

  List<Widget> getExtraTopButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 31) / (console.topButtons?.length ?? 1);
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.topButtons ?? <ConsoleButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
            bottom: 16.0 + (ConsoleButton.height * 2),
            left: 16.0 + (buttonWidth * i),
            child: Container(
              height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
              width: (screenWidth - 32) / console.topButtons!.length,
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
    final buttonWidth = (screenWidth - 30) / console.bottomButtons.length;
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.bottomButtons) {
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
    return Stack(
      children: [
        console,
        ...extraTopButtons,
        ...extraBottomButtons,
      ],
    );
  }
}

class Page {
  final PageBody pageBody;
  final PageConsole pageConsole;
  const Page({required this.pageBody, required this.pageConsole});
}

class Down4Page extends StatelessWidget {
  final String title;
  final List<Widget>? stackWidgets;
  final List<Palette>? palettes;
  final List<ChatMessage>? messages;
  final MessageList4? messageList;
  final List<Widget>? columnWidgets;
  final Console console;

  const Down4Page({
    required this.title,
    required this.console,
    this.columnWidgets,
    this.palettes,
    this.stackWidgets,
    this.messageList,
    this.messages,
    Key? key,
  }) : super(key: key);

  List<Widget> getExtraTopButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 31) / (console.topButtons?.length ?? 1);
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.topButtons ?? <ConsoleButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
            bottom: 16.0 + (ConsoleButton.height * 2),
            left: 16.0 + (buttonWidth * i),
            child: Container(
              height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
              width: (screenWidth - 32) / console.topButtons!.length,
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
    final buttonWidth = (screenWidth - 30) / console.bottomButtons.length;
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.bottomButtons) {
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: PinkTheme.qrColor),
    );
    return Container(
      color: PinkTheme.backGroundColor,
      child: Scaffold(
        body: Stack(
          children: [
            ...(stackWidgets ?? []),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                messageList ??
                    ((palettes != null ||
                            messages != null ||
                            columnWidgets != null)
                        ? DynamicList(
                            list: palettes ?? messages ?? columnWidgets!)
                        : const SizedBox.shrink()),
                console,
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

class Down4Page2 extends StatelessWidget {
  final String title;
  final List<Widget>? stackWidgets;
  final List<Palette>? palettes;
  final List<ChatMessage>? messages;
  final MessageList4? messageList;
  final List<Widget>? columnWidgets;
  final Console console;

  const Down4Page2({
    required this.title,
    required this.console,
    this.columnWidgets,
    this.palettes,
    this.stackWidgets,
    this.messageList,
    this.messages,
    Key? key,
  }) : super(key: key);

  List<Widget> getExtraTopButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 31) / (console.topButtons?.length ?? 1);
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.topButtons ?? <ConsoleButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
            bottom: 16.0 + (ConsoleButton.height * 2),
            left: 16.0 + (buttonWidth * i),
            child: Container(
              height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
              width: (screenWidth - 32) / console.topButtons!.length,
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
    final buttonWidth = (screenWidth - 30) / console.bottomButtons.length;
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.bottomButtons) {
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: PinkTheme.qrColor),
    );
    return Container(
      color: PinkTheme.backGroundColor,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: AppBar(
            backgroundColor: PinkTheme.qrColor,
            title: Text(title, style: const TextStyle(fontSize: 16)),
            centerTitle: true,
          ),
        ),
        body: Stack(
          children: [
            ...(stackWidgets ?? []),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                messageList ??
                    ((palettes != null ||
                            messages != null ||
                            columnWidgets != null)
                        ? DynamicList(
                            list: palettes ?? messages ?? columnWidgets!)
                        : const SizedBox.shrink()),
                console,
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

class ForwardingPage extends StatelessWidget {
  final List<Palette> homeUsers;
  final Console console;

  const ForwardingPage({
    required this.homeUsers,
    required this.console,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4Page2(
      title: "Forward",
      console: console,
      palettes: homeUsers,
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
  List<Widget> items = [];
  var tec = TextEditingController();
  var tec2 = TextEditingController();

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
      tec: tec2,
      id: "",
      // will calculate the ID on hyperchat creation for hyperchats
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
    items.clear();
    items.add(hyperchatMaker());
    items.addAll(widget.palettes);
    setState(() {});
  }

  Future<void> send() async {
    if (_input != "" || _mediaInput != null || _cameraInput != null) {
      final ts = u.timeStamp();
      var targets = widget.palettes.map((e) => e.node.id).toList()
        ..remove(widget.self.id);
      final wp = rw.WordPair.random(safeOnly: false);
      final root = u.deterministicHyperchatRoot(targets + [widget.self.id]);
      final msg = Down4Message(
        mediaID: _cameraInput?.id ?? _mediaInput?.id,
        senderID: widget.self.id,
        timestamp: ts,
        text: _input,
        nodes: _forwardingNodes,
      )..save();

      var hyperchatNode = Node(
        type: Nodes.hyperchat,
        id: root,
        name: wp.first,
        lastName: wp.second,
        messages: [msg.id!],
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
      final success = await f(
        MessageRequest(
          msg: msg,
          targets: targets,
          rootNode: hyperchatNode,
          media: _cameraInput ?? _mediaInput,
        ),
      );

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
          onPress: () => print("TODO"),
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
    return Down4Page2(
      title: widget.isHyperchat ? "Hyperchat" : "Group",
      console: _console!,
      columnWidgets: items,
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
    int amount;
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

  void importView() {
    var importTec = TextEditingController();

    _view = Down4Navigator(
      [
        Down4Page(
          title: "Money",
          console: Console(
            inputs: [ConsoleInput(placeHolder: "WIF / PK", tec: importTec)],
            topButtons: [
              ConsoleButton(
                  name: "Import",
                  onPress: () async {
                    final pay = await widget.wallet
                        .importMoney(widget.self, importTec.value.text);
                    if (pay != null) {
                      widget.wallet.parsePayment(widget.self, pay);
                    }
                  })
            ],
            bottomButtons: [
              ConsoleButton(
                name: "Back",
                onPress: () =>
                    widget.palettes.length > 0 ? mainView() : emptyMainView(),
              ),
              ConsoleButton(name: "Check", onPress: () => print("TODO")),
            ],
          ),
        ),
      ],
    );

    setState(() {});
  }

  void emptyMainView([
    bool scanning = false,
    bool reloadInput = false,
    bool extraBack = false,
  ]) {
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

    _view = Down4Page2(
      title: "Money",
      console: Console(
        scanCallBack: onScan,
        scanController: ctrl,
        inputs: scanning
            ? null
            : [
                reloadInput
                    ? mainViewInput
                    : _cachedMainViewInput ?? mainViewInput,
              ],
        topButtons: [
          ConsoleButton(name: "Scan", onPress: () => emptyMainView(!scanning))
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            isSpecial: true,
            showExtra: extraBack,
            onPress: () => extraBack
                ? emptyMainView(scanning, reloadInput, !extraBack)
                : widget.back(),
            onLongPress: () => emptyMainView(scanning, reloadInput, !extraBack),
            extraButtons: [
              ConsoleButton(
                name: "Import",
                onPress: () => importView(),
              )
            ],
          ),
          ConsoleButton(
            isMode: true,
            name: currency,
            onPress: () {
              rotateCurrency();
              emptyMainView(scanning, true);
            },
          ),
        ],
      ),
    );
    setState(() {});
  }

  void mainView([bool reloadInput = false, bool extraBack = false]) {
    _view = Down4Page2(
      title: "Money",
      palettes: widget.palettes,
      console: Console(
        inputs: [
          reloadInput ? mainViewInput : _cachedMainViewInput ?? mainViewInput,
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            isSpecial: true,
            showExtra: extraBack,
            onPress: () =>
                extraBack ? mainView(reloadInput, !extraBack) : widget.back(),
            onLongPress: () => mainView(reloadInput, !extraBack),
            extraButtons: [
              ConsoleButton(name: "Import", onPress: importView),
            ],
          ),
          ConsoleButton(
              name: method,
              isMode: true,
              onPress: () {
                rotateMethod();
                mainView();
              }),
          ConsoleButton(
              name: currency,
              isMode: true,
              onPress: () {
                rotateCurrency();
                mainView(tec.value.text.isEmpty ? true : false);
              }),
        ],
        topButtons: [
          ConsoleButton(name: "Bill", onPress: () => print("TODO")),
          ConsoleButton(name: "Pay", onPress: () => confirmationView(currency)),
        ],
      ),
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

    _view = Down4Page2(
      title: "Money",
      palettes: widget.palettes,
      console: Console(
        inputs: [
          ConsoleInput(
            placeHolder: currency == "USD"
                ? asUSD.toStringAsFixed(4) + " \$"
                : satsString + " sat",
            tec: tec,
            activated: false,
          ),
        ],
        topButtons: [
          ConsoleButton(
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
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: mainView),
          ConsoleButton(
            name: currency,
            isMode: true,
            onPress: () {
              rotateCurrency();
              confirmationView(inputCurrency);
            },
          ),
        ],
      ),
    );
    if (reload) setState(() {});
  }

  void transactedView(Down4Payment pay, [int i = 0, bool reload = true]) {
    Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => transactedView(pay, (i + 1) % pay.txs.length),
    );

    _view = Down4Page2(
      title: "Money",
      stackWidgets: [
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
      console: Console(
        bottomButtons: [
          ConsoleButton(name: "Done", onPress: widget.back),
        ],
      ),
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
  final Future<bool> Function(List<String>) search;
  final void Function(Node node) putNodeOffline;
  final void Function(List<Node>) addCallback, forwardNodes;
  final void Function() backCallback;

  const AddFriendPage({
    required this.palettes,
    required this.search,
    required this.self,
    required this.putNodeOffline,
    required this.addCallback,
    required this.backCallback,
    required this.forwardNodes,
    Key? key,
  }) : super(key: key);

  @override
  _AddFriendPageState createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  Console? _console;
  ConsoleInput? _consoleInputRef;
  var tec = TextEditingController();
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    defaultConsole();
    _consoleInputRef = consoleInput;
  }

  @override
  void dispose() {
    super.dispose();
    _cameraController?.dispose();
  }

  ConsoleInput get consoleInput {
    return ConsoleInput(
      tec: tec,
      placeHolder: "@search",
    );
  }

  scanCallBack(Barcode bc, MobileScannerArguments? args) {
    if (bc.rawValue != null) {
      final data = bc.rawValue!.split("~");
      if (data.length != 4) return;
      var node = Node(
        type: Nodes.user,
        id: data[0],
        name: data[1],
        lastName: data[2],
        neuter: data[3] != "" ? BIP32.fromBase58(data[3]) : null,
      );
      widget.putNodeOffline(node);
    }
  }

  void defaultConsole([scanning = false]) {
    MobileScannerController? scannerController;
    if (scanning) scannerController = MobileScannerController();
    _console = Console(
      scanController: scannerController,
      scanCallBack: scanCallBack,
      inputs: !scanning ? [_consoleInputRef ?? consoleInput] : null,
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
            onPress: () async {
              if (await widget.search(tec.value.text.split(" "))) tec.clear();
            }),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.backCallback),
        ConsoleButton(name: "Scan", onPress: () => defaultConsole(!scanning)),
        ConsoleButton(
          name: "Forward",
          onPress: () => widget.forwardNodes(
            widget.palettes
                .where((p) => p.selected)
                .map((p) => p.node)
                .toList(),
          ),
        ),
      ],
    );
    setState(() {});
  }

  Widget get qr => Container(
        padding: const EdgeInsets.only(top: 27, right: 44, left: 44),
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: QrImage(
            foregroundColor: PinkTheme.qrColor,
            data: [
              widget.self.id,
              widget.self.name,
              widget.self.lastName,
              widget.self.neuter?.toBase58() ?? "",
            ].join("~"),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Down4Page2(
      title: "Search",
      stackWidgets: [qr],
      columnWidgets: widget.palettes,
      console: _console!,
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
  Console? _console;
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
    inputs();
    baseConsole();
  }

  bool get isReady => _isValidUsername && _image.isNotEmpty && _name.isNotEmpty;

  void inputs() {
    _inputs = [
      // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
      ConsoleInput(
        tec: tec1,
        inputCallBack: (id) async {
          _isValidUsername = await r.usernameIsValid(id);
          _id = id.toLowerCase();
          baseConsole();
        },
        placeHolder: "@username",
        value: _id == '' ? '' : '@' + _id,
      ),
      ConsoleInput(
        tec: tec2,
        inputCallBack: (firstName) {
          _name = firstName;
          baseConsole();
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

  void baseConsole() {
    _console = Console(
      topInputs: [_inputs[0]],
      inputs: [_inputs[1], _inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: () => print("TODO")),
        ConsoleButton(name: "Recover", onPress: () => print("TODO")),
        ConsoleButton(
            key: buttonKey,
            isActivated: isReady,
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

  Future<void> camConsole([
    CameraController? ctrl,
    int cameraIdx = 0,
    ResolutionPreset resolution = ResolutionPreset.medium,
    FlashMode flashMode = FlashMode.off,
    bool reloadCtrl = false,
    String? path,
  ]) async {
    if (ctrl == null || reloadCtrl) {
      try {
        ctrl = CameraController(
          widget.cameras[cameraIdx],
          resolution,
          enableAudio: true,
        );
        await ctrl.initialize();
      } catch (err) {
        baseConsole();
      }
    }

    ctrl?.setFlashMode(flashMode);

    void nextCam() => cameraIdx == 0
        ? camConsole(ctrl, 1, resolution, FlashMode.off, true)
        : camConsole(ctrl, 0, resolution, FlashMode.off, true);

    void nextRes() {
      switch (resolution) {
        case ResolutionPreset.low:
          camConsole(ctrl, cameraIdx, ResolutionPreset.medium, flashMode, true);
          break;
        case ResolutionPreset.medium:
          camConsole(ctrl, cameraIdx, ResolutionPreset.high, flashMode, true);
          break;
        case ResolutionPreset.high:
          camConsole(ctrl, cameraIdx, ResolutionPreset.low, flashMode, true);
          break;
        case ResolutionPreset.veryHigh:
          // TODO: Handle this case.
          break;
        case ResolutionPreset.ultraHigh:
          // TODO: Handle this case.
          break;
        case ResolutionPreset.max:
          // TODO: Handle this case.
          break;
      }
    }

    void nextFlash() => flashMode == FlashMode.off
        ? camConsole(ctrl, cameraIdx, resolution, FlashMode.torch)
        : camConsole(ctrl, cameraIdx, resolution, FlashMode.off);

    if (path == null) {
      _console = Console(
        cameraController: ctrl,
        aspectRatio: ctrl?.value.aspectRatio,
        topButtons: [
          ConsoleButton(
            name: cameraIdx == 0 ? "Front" : "Rear",
            onPress: nextCam,
            isMode: true,
          ),
          ConsoleButton(
            name: "Capture",
            onPress: () async {
              XFile? f = await ctrl?.takePicture();
              if (f != null) {
                path = f.path;
                Uint8List? compressed;
                compressed = await FlutterImageCompress.compressWithFile(
                  path!,
                  minHeight: 520, // palette height
                  minWidth: 520, // palette height
                  quality: 40,
                );
                if (compressed != null) {
                  _image = compressed;
                } else {
                  path = null;
                }
              }
              camConsole(
                ctrl,
                cameraIdx,
                resolution,
                FlashMode.off,
                false,
                path,
              );
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: baseConsole),
          ConsoleButton(
            name: resolution.name.capitalize(),
            onPress: nextRes,
            isMode: true,
          ),
          ConsoleButton(
            name: flashMode.name.capitalize(),
            onPress: nextFlash,
            isMode: true,
          ),
        ],
      );
    } else {
      _console = Console(
        imagePreviewPath: path,
        toMirror: cameraIdx == 1,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () {
              _toReverse = cameraIdx == 1;
              baseConsole();
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
              name: "Back",
              onPress: () {
                _image = Uint8List(0);
                camConsole(ctrl, cameraIdx, resolution, flashMode, false, null);
              }),
          ConsoleButton(name: "Cancel", onPress: baseConsole),
        ],
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Down4Page2(
      title: "Initialization",
      console: _console!,
      columnWidgets: [
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
              baseConsole();
            }
          },
          name: _name,
          id: _id,
          lastName: _lastName,
          image: _image,
        ),
      ],
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
    return Down4Page2(
      title: "Welcome",
      stackWidgets: [
        Positioned(
          width: Sizes.w,
          height: Sizes.h - (16.0 + ConsoleButton.height),
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
      ],
      console: Console(
        bottomButtons: [
          ConsoleButton(name: "Understood", onPress: _understood)
        ],
      ),
    );
  }
}

class NodePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final List<Palette> palettes;
  final Palette palette;
  final Node self;
  final Palette? Function(Node, String) nodeToPalette;
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

  Map<String, List<String>> _stupidMap = {};
  List<String> _modes = ["Childs"];
  int _i = 0;

  @override
  void initState() {
    super.initState();
    // setUpProfileImage();
    final node = widget.palette.node;
    // if (node.posts.isNotEmpty) { // TODO: posts
    //   _modes.add("Posts");
    //   _stupidMap["Posts"] = node.posts;
    // }
    if ((node.parents ?? []).isNotEmpty) {
      _modes.add("Parents");
      _stupidMap["Parents"] = node.parents!;
    }
    if ((node.admins ?? []).isNotEmpty) {
      _modes.add("Admins");
      _stupidMap["Admins"] = node.admins!;
    }
    if ((node.friends ?? []).isNotEmpty) {
      _modes.add("Friends");
      _stupidMap["Friends"] = node.friends!;
    }
  }

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
        final p = widget.nodeToPalette(node, widget.palette.node.id);
        if (p != null) {
          _fetchablePalettes[currentMode] = {p.node.id: p};
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.palette.node.name +
        (widget.palette.node.lastName != null
            ? widget.palette.node.lastName!
            : "");
    switch (currentMode) {
      case "Childs":
        return [Nodes.user, Nodes.friend, Nodes.nonFriend]
                .contains(widget.palette.node.type)
            ? Down4Page2(
                title: title,
                columnWidgets: [
                  Container(
                    margin: const EdgeInsets.only(top: 27),
                    child: ProfileWidget(
                      node: widget.palette.node
                        ..description =
                            "Hello, this is a temporary description, used first of all for one purpose only, and that purpose is testing",
                    ),
                  ),
                  PaletteList(palettes: currentPalettes),
                ],
                console: userPaletteConsole,
              )
            : Down4Page2(
                title: title,
                palettes: currentPalettes,
                console: basicPaletteConsole,
              );

      case "Parents":
        return Down4Page2(
          title: title,
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );

      case "Admins":
        return Down4Page2(
          title: title,
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );

      case "Followers":
        return Down4Page2(
          title: title,
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );

      case "Following":
        return Down4Page2(
          title: title,
          palettes: currentPalettes,
          console: basicPaletteConsole,
        );
    }
    return const SizedBox.shrink();
  }
}

class ChatPage extends StatefulWidget {
  final Map<Identifier, Node> senders;
  final Node self, node;
  final List<CameraDescription> cameras;
  final Future<bool> Function(MessageRequest req) send;
  final void Function() back;

  const ChatPage({
    required this.senders,
    required this.node,
    required this.send,
    required this.self,
    required this.back,
    required this.cameras,
    Key? key,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Console? _console;
  ConsoleInput? _consoleInput;
  var tec = TextEditingController();
  Map<Identifier, Down4Media> _cachedImages = {};
  Map<Identifier, ChatMessage> _chachedMessages = {};

  List<Down4Media> get images {
    if (_cachedImages.isEmpty && Boxes.instance.images.keys.isEmpty) {
      return <Down4Media>[];
    } else if (_cachedImages.values.isEmpty &&
        Boxes.instance.images.keys.isNotEmpty) {
      for (final mediaID in Boxes.instance.images.keys) {
        _cachedImages[mediaID] = Boxes.instance.loadSavedImage(mediaID);
      }
      return _cachedImages.values.toList();
    } else {
      return _cachedImages.values.toList();
    }
  }

  ConsoleInput get consoleInput => _consoleInput = ConsoleInput(
        tec: tec,
        inputCallBack: (t) => null,
        placeHolder: ":)",
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
        _cachedImages[mediaID] = Down4Media(
          id: mediaID,
          data: compressedData,
          metadata: MediaMetadata(owner: widget.self.id, timestamp: ts),
        );
        Boxes.instance.saveImage(_cachedImages[mediaID]!);
      }
    }
    setState(() {});
  }

  void saveSelectedMessages() {
    for (final msg in _chachedMessages.values) {
      if (msg.selected) {
        if (msg.message.media != null) {
          if (msg.message.media!.metadata.isVideo) {
            Boxes.instance.saveVideo(msg.message.media!);
          } else {
            Boxes.instance.saveImage(msg.message.media!);
          }
        }
        _chachedMessages[msg.message.id!] = msg.invertedSelection();
      }
    }
    setState(() {});
  }

  void send2(String textInput, Down4Media? mediaInput) {
    if (textInput != "" || mediaInput != null) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final targets = (widget.node.group ?? [widget.node.id])
        ..removeWhere((element) => element == widget.self.id);

      var msg = Down4Message(
        id: u.generateMessageID(widget.self.id, ts),
        timestamp: ts,
        senderID: widget.self.id,
        media: mediaInput,
        text: textInput,
      );

      Boxes.instance.saveMessage(msg);
      widget.send(MessageRequest(targets: targets, msg: msg));
      tec.clear();
    }
  }

  MessageList4 get messageList => MessageList4(
        senders: widget.senders,
        messages: widget.node.messages ?? <String>[],
        self: widget.self,
        messageMap: _chachedMessages,
        cache: (msg) => _chachedMessages[msg.message.id!] = msg,
        select: (id, _) {
          _chachedMessages[id] = _chachedMessages[id]!.invertedSelection();
          setState(() {});
        },
      );

  Future<void> camConsole([
    CameraController? ctrl,
    int cameraIdx = 0,
    ResolutionPreset resolution = ResolutionPreset.medium,
    FlashMode flashMode = FlashMode.off,
    bool reloadCtrl = false,
    Down4Media? cameraInput,
  ]) async {
    if (ctrl == null || reloadCtrl) {
      try {
        ctrl = CameraController(
          widget.cameras[cameraIdx],
          resolution,
          enableAudio: true,
        );
        await ctrl.initialize();
      } catch (err) {
        baseConsole();
      }
    }

    ctrl?.setFlashMode(flashMode);

    void nextCam() => cameraIdx == 0
        ? camConsole(ctrl, 1, resolution, FlashMode.off, true)
        : camConsole(ctrl, 0, resolution, FlashMode.off, true);

    void nextRes() async {
      switch (resolution) {
        case ResolutionPreset.low:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.medium, flashMode, true);
        case ResolutionPreset.medium:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.high, flashMode, true);
        case ResolutionPreset.high:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.low, flashMode, true);
        case ResolutionPreset.veryHigh:
          // TODO: Handle this case.
          break;
        case ResolutionPreset.ultraHigh:
          // TODO: Handle this case.
          break;
        case ResolutionPreset.max:
          // TODO: Handle this case.
          break;
      }
    }

    void nextFlash() => flashMode == FlashMode.off
        ? camConsole(ctrl, cameraIdx, resolution, FlashMode.torch)
        : camConsole(ctrl, cameraIdx, resolution, FlashMode.off);

    if (cameraInput == null) {
      _console = Console(
        cameraController: ctrl,
        aspectRatio: ctrl?.value.aspectRatio,
        topButtons: [
          ConsoleButton(
            name: cameraIdx == 0 ? "Front" : "Rear",
            onPress: nextCam,
            isMode: true,
          ),
          ConsoleButton(
            name: "Capture",
            onPress: () async {
              XFile? f = await ctrl?.takePicture();
              if (f != null) {
                var camInput = Down4Media.fromCamera(
                  f.path,
                  MediaMetadata(
                    owner: widget.self.id,
                    timestamp: u.timeStamp(),
                    isVideo: false,
                    toReverse: cameraIdx == 1,
                  ),
                );
                camConsole(
                  ctrl,
                  cameraIdx,
                  resolution,
                  FlashMode.off,
                  false,
                  camInput,
                );
              }
            },
            onLongPress: () async => await ctrl?.startVideoRecording(),
            onLongPressUp: () async {
              XFile? f = await ctrl?.stopVideoRecording();
              if (f != null) {
                var camInput = Down4Media.fromCamera(
                  f.path,
                  MediaMetadata(
                    owner: widget.self.id,
                    timestamp: u.timeStamp(),
                    isVideo: true,
                    toReverse: cameraIdx == 1,
                  ),
                );
                camConsole(
                  ctrl,
                  cameraIdx,
                  resolution,
                  FlashMode.off,
                  false,
                  camInput,
                );
              }
            },
            shouldBeDownButIsnt: ctrl?.value.isRecordingVideo ?? false,
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: baseConsole),
          ConsoleButton(
            name: resolution.name.capitalize(),
            onPress: nextRes,
            isMode: true,
          ),
          ConsoleButton(
            name: flashMode.name.capitalize(),
            onPress: nextFlash,
            isMode: true,
          ),
        ],
      );
    } else {
      String? imPrev;
      VideoPlayerController? videoCtrl;
      if (cameraInput.metadata.isVideo) {
        videoCtrl = VideoPlayerController.file(cameraInput.file!);
        await videoCtrl.initialize();
        await videoCtrl.setLooping(true);
        await videoCtrl.play();
      } else {
        imPrev = cameraInput.path;
      }
      _console = Console(
        imagePreviewPath: imPrev,
        videoPlayerController: videoCtrl,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () {
              videoCtrl?.dispose();
              ctrl?.dispose();
              baseConsole(cameraInput);
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            onPress: () {
              videoCtrl?.dispose();
              camConsole(ctrl, cameraIdx, resolution, flashMode, false, null);
            },
          ),
          ConsoleButton(
              name: "Cancel",
              onPress: () {
                videoCtrl?.dispose();
                ctrl?.dispose();
                baseConsole();
              }),
        ],
      );
    }
    setState(() {});
  }

  void baseConsole([Down4Media? cameraInput]) {
    _console = Console(
      inputs: [_consoleInput ?? consoleInput],
      topButtons: [
        ConsoleButton(name: "Save", onPress: saveSelectedMessages),
        ConsoleButton(
          name: "Send",
          onPress: () {
            send2(tec.value.text, cameraInput);
            baseConsole();
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: "Images",
          onPress: () => mediasConsole(cameraInput),
        ),
        ConsoleButton(
          name: cameraInput == null ? "Camera" : "@Camera",
          onPress: camConsole,
        ),
      ],
    );
    setState(() {});
  }

  void mediasConsole([Down4Media? cameraInput]) {
    _console = Console(
      images: true,
      medias: images,
      selectMedia: (media) => send2(tec.value.text, media),
      topButtons: [ConsoleButton(name: "Import", onPress: handleImport)],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: () => baseConsole(cameraInput)),
        ConsoleButton(name: "Todo", onPress: () => print("TODO")),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.node.name +
        (widget.node.lastName != null ? " " + widget.node.lastName! : "");
    if (_console == null) baseConsole();
    return Down4Page2(
      title: title,
      messageList: messageList,
      console: _console!,
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Palette> palettes;
  final Console console;
  const HomePage({required this.palettes, required this.console, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4Navigator2(
      firstPage: 0,
      pages: [
        Page(
          pageBody: PageBody(title: "Home", palettes: palettes),
          pageConsole: PageConsole(console: console),
        ),
        Page(
          pageBody: PageBody(title: "Friends", palettes: palettes),
          pageConsole: PageConsole(
            console: Console(
              inputs: [
                ConsoleInput(
                  placeHolder: "Nice",
                  tec: TextEditingController(),
                )
              ],
              bottomButtons: [
                ConsoleButton(name: "Nigga", onPress: () => print("LOL")),
                ConsoleButton(name: "What", onPress: () => print("LOL")),
                ConsoleButton(name: "Lol", onPress: () => print("LOL")),
              ],
              topButtons: [
                ConsoleButton(name: "Apple", onPress: () => print("LOL")),
                ConsoleButton(name: "Orange", onPress: () => print("LOL")),
              ],
            ),
          ),
        ),
      ],
    );

    // [
    //   Down4Page(
    //     title: "Home",
    //     palettes: palettes,
    //     console: console,
    //   ),
    // ]);
  }
}

class Home extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Node self;
  final Wallet wallet;

  const Home({
    required this.cameras,
    required this.self,
    required this.wallet,
    Key? key,
  }) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var box = Boxes.instance;
  Widget? view;
  Map<String, dynamic> exchangeRate = {};

  // The base location is Home with the home palettes
  // You can traverse palettes which will be cached
  // Home -> home palettes
  // paletteID -> child palettes

  Map<Identifier, Map<Identifier, Palette>> paletteMap = {
    "Home": {},
    "Search": {},
    "Forward": {},
  };

  // similar to the palettes, used for local data and caching messages
  Map<String, Map<String, ChatMessage>> messageMap = {
    "Saved": {},
    "MyPosts": {},
  };

  StreamSubscription? messageListener;

  // Node? _node; // the node we are currently traversing, always null at start
  // List<String> _locations = ["Home"]; // to keep an history of traversed nodes
  List<Map<String, String>> locations = [
    {"at": "Home"},
  ];

  // we pop it when backing in node views
  // when it's empty we should be on home view
  // if _currentLocation is not "Home", it should be _node.id
  List<Node> forwardingNodes = [];

  var tec = TextEditingController();

  // ======================================================= INITIALIZATION ============================================================ //

  @override
  void initState() {
    super.initState();
    updateExchangeRate();
    loadLocalHomePalettes();
    connectToMessages();
    homePage();
  }

  @override
  void dispose() {
    messageListener?.cancel();
    super.dispose();
  }

  Future<void> updateExchangeRate() async {
    final lastUpdate = exchangeRate["update"] ?? 0;
    final rightNow = u.timeStamp();
    if (rightNow - lastUpdate > const Duration(minutes: 10).inMilliseconds) {
      final rate = await r.getExchangeRate();
      if (rate != null) {
        exchangeRate["rate"] = rate;
        exchangeRate["update"] = rightNow;
        box.saveExchangeRate(exchangeRate);
        if (view is MoneyPage) moneyPage();
      }
    }
  }

  void loadLocalHomePalettes() {
    final jsonEncodedHomeNodes = box.home.values;
    for (final jsonEncodedHomeNode in jsonEncodedHomeNodes) {
      final node = Node.fromJson(jsonDecode(jsonEncodedHomeNode));
      writePalette(node);
    }
  }

  void connectToMessages() {
    var msgQueue = db.child("Users").child(widget.self.id).child("M");
    var messagesRef = db.child("Messages");

    messageListener = msgQueue.onChildAdded.listen((event) async {
      var msgID = event.snapshot.key;
      if (msgID == null) return;
      msgQueue.child(msgID).remove(); // consume it

      final snapshot = await messagesRef.child(msgID).get();
      if (!snapshot.exists) return;
      final msgJson = Map<String, dynamic>.from(snapshot.value as Map);
      final msg = Down4Message.fromJson(msgJson);

      switch (msg.type) {
        case Messages.chat:
          msg.save();
          if (msg.root != null) {
            var rootNode = nodeAt(msg.root!);
            if (rootNode != null) {
              (rootNode.messages ??= []).add(msg.id!);
              // if root is group of hyperchat, we download the media right away
              if (rootNode.isFriendOrGroup && msg.mediaID != null) {
                (await r.getMessageMedia(msg.mediaID!))?.save();
              }
              writePalette(rootNode
                ..updateActivity()
                ..save());
            } else {
              // root node is not in home
              final newNode = await getNode(msg.root!);
              if (newNode == null) return;
              (newNode.messages ??= []).add(msg.id!);
              writePalette(newNode
                ..updateActivity()
                ..save());
            }
          } else {
            // msg.root == null
            var userNode = nodeAt(msg.senderID);
            if (userNode != null) {
              // user is in home
              (userNode.messages ??= []).add(msg.id!);
              // if is friend, we download the media right away
              if (userNode.isFriendOrGroup && msg.mediaID != null) {
                (await r.getMessageMedia(msg.mediaID!))?.save();
              }
              writePalette(userNode
                ..updateActivity()
                ..save());
            } else {
              // userNode is not in home
              final newUserNode = await getNode(msg.senderID);
              if (newUserNode == null) return;
              (newUserNode.messages ??= []).add(msg.id!);
              writePalette(newUserNode
                ..updateActivity()
                ..save());
            }
          }
          if (view is HomePage) {
            homePage();
          } else if (view is NodePage &&
              locations.last["id"] == (msg.root ?? msg.senderID)) {
            var n = nodeAt(msg.root ?? msg.senderID);
            if (n != null) nodePage(n);
          }
          break;
        case Messages.payment:
          final paymentID = msg.paymentID;
          if (paymentID == null) return;
          final paymentData = await st.ref(paymentID).getData();
          if (paymentData == null) return;
          final paymentString = utf8.decode(paymentData);
          final paymentJson = jsonDecode(paymentString);
          final payment = Down4Payment.fromJson(paymentJson)..save();
          widget.wallet.parsePayment(widget.self, payment);
          if (view is MoneyPage) moneyPage();
          break;
        case Messages.bill:
          // TODO: Handle this case.
          break;
        case Messages.snip:
          if (msg.root != null) {
            var nodeRoot = nodeAt(msg.root!);
            if (nodeRoot == null) {
              // nodeRoot is not in home, need to download it
              final newRootNode = await getNode(msg.root!);
              if (newRootNode == null) return;
              (newRootNode.snips ??= []).add(msg.mediaID!);
              writePalette(newRootNode
                ..updateActivity()
                ..save());
            } else {
              // nodeRoot is in home
              (nodeRoot.snips ??= []).add(msg.mediaID!);
              writePalette(nodeRoot
                ..updateActivity()
                ..save());
            }
          } else {
            // user snip
            final homeUserRoot = nodeAt(msg.senderID);
            if (homeUserRoot != null) {
              // user is in home
              (homeUserRoot.snips ??= []).add(msg.mediaID!);
              writePalette(homeUserRoot
                ..updateActivity()
                ..save());
            } else {
              // user is not in home
              var userNode = await getNode(msg.senderID);
              if (userNode == null) return;
              (userNode.snips ??= []).add(msg.mediaID!);
              writePalette(userNode
                ..updateActivity()
                ..save());
            }
          }
          if (view is HomePage) homePage();
          break;
      }
    });
  }

  // ======================================================= UTILS ============================================================ //

  void unselectSelectedPalettes([
    String at = "Home",
    bool updateActivity = false,
  ]) {
    if (updateActivity) {
      for (final p in palettes(at)) {
        if (p.selected) {
          paletteMap[at]
              ?[p.node.id] = paletteMap[at]![p.node.id]!.invertedSelection()
            ..node.updateActivity();
        }
      }
    } else {
      for (final p in palettes(at)) {
        if (p.selected) {
          paletteMap[at]?[p.node.id] =
              paletteMap[at]![p.node.id]!.invertedSelection();
        }
      }
    }
  }

  Palette? nodeToPalette(Node node, [String at = "Home"]) {
    switch (node.type) {
      case Nodes.user:
        final friendIDs = palettes()
            .where((p) => p.node.type == Nodes.friend)
            .map((e) => e.node.id)
            .toList();
        return friendIDs.contains(node.id)
            ? nodeToPalette(node..mutateType(Nodes.friend), at)
            : nodeToPalette(node..mutateType(Nodes.nonFriend), at);

      case Nodes.root:
        return Palette(
          node: node,
          at: at,
          // todo
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
              assetPath: at == "Home" && node.snips!.isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
              pressFunc: at == "Home"
                  ? node.snips!.isNotEmpty
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
        if (node.messages!.isEmpty) {
          return null;
        } else {
          final lastMessageID = node.messages!.last;
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
              pressFunc: node.snips!.isNotEmpty ? checkSnips : openChat,
              assetPath: node.snips!.isNotEmpty
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
              assetPath: at == "Home" && node.snips!.isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
              pressFunc: at == "Home"
                  ? node.snips!.isNotEmpty
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
              pressFunc: node.snips!.isNotEmpty ? checkSnips : openChat,
              assetPath: node.snips!.isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
            )
          ],
        );
    }
    return null;
  }

  Future<void> sendSnip(
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
      var userTargets = <Identifier>[];
      for (final p in palettes().selected()) {
        if (p.node.isGroup) {
          final mr = MessageRequest(
            msg: Down4Message(
              root: p.node.id,
              timestamp: timestamp,
              mediaID: media.id,
              senderID: widget.self.id,
            ),
            targets: (p.node.group ??= [])
              ..removeWhere((userID) => widget.self.id == userID),
            media: media,
          );
          r.snipRequest(mr);
        } else {
          userTargets.add(p.node.id);
        }
      }
      r.snipRequest(MessageRequest(
        msg: Down4Message(
          timestamp: timestamp,
          mediaID: media.id,
          senderID: widget.self.id,
        ),
        targets: selectedHomeUserPaletteDeactivated.asIds(),
        media: media,
      ));
      unselectSelectedPalettes("Home", true);
    }
    homePage();
  }

  // ======================================================= CONSOLE ACTIONS ============================================================ //

  void addUsers(List<Node> friends) {
    for (final friend in friends) {
      paletteMap["Search"]![friend.id] = paletteMap["Search"]![friend.id]!
          .invertedSelection()
        ..node.mutateType(Nodes.friend);

      writePalette(friend
        ..mutateType(Nodes.friend)
        ..updateActivity());

      paletteMap["Home"]!.putIfAbsent(
        friend.id,
        () => nodeToPalette(
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

  void delete([String at = "Home"]) {
    for (final p in palettes(at).selected()) {
      box.deleteNode(p.node.id);
      paletteMap[at]?.remove(p.node.id);
    }
    // TODO for other places than home
    if (view is HomePage) homePage();
  }

  Future<bool> search(List<String> ids) async {
    final nodes = await r.getNodes(ids);
    if (nodes != null) {
      for (var node in nodes) {
        writePalette(node..updateActivity(), "Search");
        searchPage();
      }
      return true;
    }
    return false;
  }

  void putNodeOffLine(Node node) {
    final p = nodeToPalette(node, "Search");
    if (p != null) {
      paletteMap["Search"]?.putIfAbsent(node.id, () => p);
      searchPage();
    }
  }

  Future<void> chatRequest(Node node, Down4Message msg) async {}

  void back([bool remove = true]) {
    if (remove) locations.removeLast();
    if (locations.last["at"] == "Home" && locations.last["type"] == null) {
      homePage();
    } else if (locations.last["at"] == "Search" &&
        locations.last["type"] == null) {
      searchPage();
    } else if (locations.last["type"] == "Node") {
      nodePage(nodeAt(locations.last["id"]!, locations.last["at"]!)!);
    } else if (locations.last["type"] == "Chat") {
      // TODO
      chatPage(nodeAt(locations.last["id"]!, locations.last["at"]!)!);
    }
  }

  Future<bool> send(Object message) async {
    // TODO
    return Future(() => true);
  }

  void forward(List<Node> nodes) {
    forwardingNodes = nodes;
    forwardPage();
  }

  // ======================================================== NODE ACTIONS ============================================================== //

  Future<void> openNode(String id, String at) async {
    if (paletteMap[id] == null) {
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
      final childNodes = await r.getNodes(node.childs ?? []);
      if (childNodes != null) {
        for (final node in childNodes) {
          var p = nodeToPalette(node, id);
          if (p != null) paletteMap[id]!.putIfAbsent(node.id, () => p);
        }
      }
    }
    locations.add({"type": "Node", "id": id, "at": at});
    nodePage(nodeAt(id, at)!);
  }

  void select(String id, String at) {
    paletteMap[at]![id] = paletteMap[at]![id]!.invertedSelection();
    if (view is ForwardingPage) {
      forwardPage();
    } else {
      locations.last["at"] == "Home"
          ? homePage()
          : locations.last["at"] == "Search"
              ? searchPage()
              : nodePage(nodeAt(at, previousLocation["id"]!)!);
    }
  }

  void openChat(String id, String at) {
    locations.add({"at": at, "id": id, "type": "Chat"});
    // TODO
    chatPage(nodeAt(id, at)!);
  }

  void checkSnips(String id, String at) {
    snipView(nodeAt(id, at)!);
  }

  // ======================================================== COMPLEXITY REDUCING GETTERS ? =============================================== //

  Palette? palette(String id, [String at = "Home"]) {
    return paletteMap[at]?[id];
  }

  Node? nodeAt(String id, [String at = "Home"]) {
    return paletteMap[at]?[id]?.node;
  }

  void writePalette(Node node, [String at = "Home"]) {
    if (paletteMap[at] == null) paletteMap[at] = {};
    final p = nodeToPalette(node, at);
    if (p != null) paletteMap[at]?[node.id] = p;
  }

  List<Palette> get selectedFriendPalettesDeactivated {
    var selectedGroups = palettes().where(
      (p) =>
          (p.node.type == Nodes.hyperchat || p.node.type == Nodes.group) &&
          p.selected,
    );
    var idsInSelGroups = [];
    for (final shc in selectedGroups) {
      for (final uid in shc.node.group!) {
        if (!idsInSelGroups.contains(uid)) {
          idsInSelGroups.add(uid);
        }
      }
    }

    var palettes_ = <Palette>[];
    final selectedNonGroups = formattedHomePalettes.where(
      (p) => (p.node.type == Nodes.friend) && p.selected,
    );
    for (final pal in selectedNonGroups) {
      if (!idsInSelGroups.contains(pal.node.id)) {
        palettes_.add(pal.deactivated());
      }
    }

    return palettes_;
  }

  List<Palette> get selectedHomeUserPaletteDeactivated {
    var selectedGroups = formattedHomePalettes.where(
      (p) =>
          (p.node.type == Nodes.hyperchat || p.node.type == Nodes.group) &&
          p.selected,
    );
    var idsInSelGroups = <Identifier>[];
    for (final shc in selectedGroups) {
      for (final uid in shc.node.group!) {
        if (!idsInSelGroups.contains(uid)) {
          idsInSelGroups.add(uid);
        }
      }
    }

    var palettes = <Palette>[];
    for (final id in idsInSelGroups) {
      if (palette(id) != null) {
        palettes.add(palette(id)!.deactivated());
      }
    }

    final selectedNonGroups = formattedHomePalettes.where(
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

  List<Palette> palettes([String at = "Home"]) {
    return paletteMap[at]?.values.toList(growable: false) ?? <Palette>[];
  }

  List<Palette> get formattedHomePalettes {
    return palettes()
      ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  }

  Map<String, String> get previousLocation {
    if (locations.length > 2) {
      return locations[locations.length - 2];
    }
    throw "Invalid previous location";
  }

  List<Identifier> get groupRoots {
    return palettes()
        .where((e) => e.node.isGroup)
        .map((e) => e.node.id)
        .toList();
  }

  // ============================================================== BUILD ================================================================ //

  void homePage([bool extra = false]) {
    view = HomePage(
      palettes: formattedHomePalettes,
      console: Console(
        inputs: [
          ConsoleInput(
            tec: tec,
            placeHolder: ":)",
          ),
        ],
        bottomButtons: [
          ConsoleButton(
              showExtra: extra,
              name: "Delete",
              onPress: () => extra ? homePage(!extra) : delete,
              isSpecial: true,
              onLongPress: () => homePage(!extra),
              extraButtons: [
                ConsoleButton(name: "Nigger", onPress: () => homePage(!extra)),
                ConsoleButton(name: "Shit", onPress: () => homePage(!extra)),
                ConsoleButton(name: "Wacko", onPress: () => homePage(!extra)),
              ]),
          ConsoleButton(
            name: "Search",
            onPress: () {
              locations.add({"at": "Search"});
              searchPage();
            },
          ),
          ConsoleButton(
            name: "Ping",
            onPress: ping,
            onLongPress: snipPage,
            isSpecial: true,
          ),
        ],
        topButtons: [
          ConsoleButton(name: "Chat", onPress: hyperchatPage),
          ConsoleButton(name: "Money", onPress: moneyPage),
        ],
      ),
    );
    setState(() {});
  }

  void forwardPage() {
    var userAndGroups =
        palettes().where((p) => p.node.isGroup || p.node.isUser);

    if (userAndGroups.length != paletteMap["Forward"]!.length) {
      for (final p in formattedHomePalettes) {
        if (!paletteMap["Forward"]!.containsKey(p.node.id) &&
            (p.node.isUser || p.node.isGroup)) {
          writePalette(p.node, "Forward");
        }
      }
    }

    view = ForwardingPage(
      homeUsers: paletteMap["Forward"]!.values.toList(),
      console: Console(
        forwardingNodes: forwardingNodes,
        topButtons: [
          ConsoleButton(name: "Forward", onPress: () => print("TODO")),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: () => back(false)),
          ConsoleButton(name: "Hyper", onPress: () => print("TODO")),
        ],
      ),
    );
    setState(() {});
  }

  void moneyPage() {
    updateExchangeRate();
    print(exchangeRate);
    view = MoneyPage(
      self: widget.self,
      wallet: widget.wallet,
      exchangeRate: exchangeRate["rate"],
      palettes: selectedHomeUserPaletteDeactivated,
      back: homePage,
    );
    setState(() {});
  }

  void hyperchatPage() {
    view = GroupPage(
      isHyperchat: true,
      self: widget.self,
      afterMessageCallback: (node) {
        // TODO
        writePalette(node);
        locations.add({"at": "Home", "id": node.id, "type": "Chat"});
        chatPage(node);
      },
      back: homePage,
      palettes: selectedHomeUserPaletteDeactivated,
      cameras: widget.cameras,
    );
    setState(() {});
  }

  void searchPage() {
    view = AddFriendPage(
      forwardNodes: forward,
      putNodeOffline: putNodeOffLine,
      self: widget.self,
      search: search,
      palettes: paletteMap["Search"]?.values.toList().reversed.toList() ?? [],
      addCallback: addUsers,
      backCallback: () {
        paletteMap["Search"]?.clear();
        back();
      },
    );
    setState(() {});
  }

  void nodePage(Node node) {
    view = NodePage(
      cameras: widget.cameras,
      self: widget.self,
      openChat: openChat,
      palette: paletteMap[locations.last["at"]!]![node.id]!,
      palettes: paletteMap[node.id]?.values.toList() ?? <Palette>[],
      openNode: openNode,
      nodeToPalette: nodeToPalette,
      back: back,
    );
    setState(() {});
  }

  Future<void> snipPage({
    CameraController? ctrl,
    int camera = 0,
    ResolutionPreset res = ResolutionPreset.medium,
    bool reload = false,
  }) async {
    ResolutionPreset nextRes() => res == ResolutionPreset.low
        ? ResolutionPreset.medium
        : res == ResolutionPreset.medium
            ? ResolutionPreset.high
            : ResolutionPreset.low;

    int nextCam() => camera == 0 ? 1 : 0;

    void snip() async {
      view = SnipCamera(
        maxZoom: await ctrl!.getMaxZoomLevel(),
        minZoom: await ctrl.getMinZoomLevel(),
        camNum: camera,
        cameraBack: homePage,
        cameraCallBack: sendSnip,
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

  void chatPage(Node node) async {
    var senders = <String, Node>{};
    if (node.isGroup) {
      var toFetch = <String>[];
      Node? homeNode;
      for (final nodeID in node.group ?? <String>[]) {
        homeNode = nodeAt(nodeID);
        if (homeNode != null) {
          senders[nodeID] = homeNode;
        } else {
          toFetch.add(nodeID);
        }
      }
      if (toFetch.isNotEmpty) {
        var fetchedNodes = await r.getNodes(toFetch);
        if (fetchedNodes != null) {
          for (var fetchedNode in fetchedNodes) {
            senders[fetchedNode.id] = fetchedNode;
          }
        }
      }
    } else {
      senders[widget.self.id] = widget.self;
      senders[node.id] = node;
    }

    view = ChatPage(
      senders: senders,
      send: send,
      self: widget.self,
      node: node,
      cameras: widget.cameras,
      back: back,
    );

    setState(() {});
  }

  Future<void> snipView(Node node) async {
    final mediaSize = MediaQuery.of(context).size; // full screen
    if (node.snips!.isEmpty) {
      writePalette(node);
      homePage();
    } else {
      final snip = node.snips!.first;
      node.snips!.remove(snip); // consume it
      box.saveNode(node);
      Down4Media? media;
      dynamic jsonEncodedMedia;
      if ((jsonEncodedMedia = box.snips.get(snip)) == null) {
        media = await r.getMessageMedia(snip);
      } else {
        media = Down4Media.fromJson(jsonDecode(jsonEncodedMedia));
        box.snips.delete(snip); // consume it
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
        view = Down4Page2(
          title: "TODO",
          stackWidgets: [
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
          console: Console(
            bottomButtons: [
              ConsoleButton(
                name: "Back",
                onPress: () async {
                  await ctrl.dispose();
                  f.delete();
                  writePalette(node);
                  homePage();
                },
              ),
              ConsoleButton(
                name: "Next",
                onPress: () async {
                  await ctrl.dispose();
                  f.delete();
                  snipView(node);
                },
              ),
            ],
          ),
        );
      } else {
        await precacheImage(MemoryImage(media.data), context);
        view = Down4Page2(
          title: "TODO",
          stackWidgets: [
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
          console: Console(
            bottomButtons: [
              ConsoleButton(
                  name: "Back",
                  onPress: () {
                    writePalette(node);
                    homePage();
                  }),
              ConsoleButton(name: "Next", onPress: () => snipView(node)),
            ],
          ),
        );
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return view ?? const LoadingPage();
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
