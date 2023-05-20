import 'dart:async';

import 'package:base85/base85.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr/qr.dart';

import '../data_objects.dart';
import '../bsv/types.dart';
import '../bsv/_bsv_utils.dart';
import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/qr.dart';
import '../render_objects/_render_utils.dart'
    show
        Down4PageWidget,
        IterablePalette2Extensions,
        Palette2Extensions,
        backArrow;
import '_page_utils.dart';

final base85 = Base85Codec(Alphabets.z85);

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

class PaymentPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "payment";
  final void Function() back, ok;
  final Down4Payment payment;
  final List<String> paymentAsList;
  final void Function(Down4Payment) sendPayment;

  PaymentPage({
    required this.ok,
    required this.back,
    required this.payment,
    required this.sendPayment,
    Key? key,
  })  : paymentAsList = payment.asQrData,
        super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with Pager2 {
  Timer? timer;
  int listIndex = 0;
  var qrs = <Widget Function(int)>[];
  var qrs2 = <Widget>[];
  // var tec = TextEditingController();
  // late var input = ConsoleInput(placeHolder: "(Text Note)", tec: tec);
  // late Console theConsole = aConsole;

  @override
  void initState() {
    super.initState();
    print("THERE ARE ${widget.paymentAsList.length} QRS");
  }

  Timer get startedTimer =>
      Timer.periodic(const Duration(milliseconds: 400), (timer) {
        listIndex = (listIndex + 1) % widget.paymentAsList.length;
        setState(() {});
      });

  void loadQrsAsPaints() {
    for (int i = 0; i < widget.paymentAsList.length; i++) {
      var paymentData = widget.paymentAsList[i];
      qrs.add((int index) => Opacity(
          opacity: index == i ? 1 : 0,
          child: Align(
              alignment: Alignment.topCenter,
              child: Column(children: [
                SizedBox(height: topPadding),
                SizedBox.square(
                    dimension: qrDimension,
                    child: Down4Qr(
                      data: paymentData,
                      dimension: qrDimension,
                      errorCorrectionLevel: QrErrorCorrectLevel.L,
                    ))
              ]))));
    }
    setState(() {
      // theConsole = aConsole;
      if (qrs.length > 1) timer = startedTimer;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  double get qrDimension => g.sizes.w - (g.sizes.w * 0.08 * golden * 2);

  double get topPadding => g.sizes.w - qrDimension * 2 * 1 / golden;

  // Console get aConsole => Console(
  //       // inputs: [input],
  //       topButtons: [
  //         qrs.isEmpty
  //             ? ConsoleButton(name: "Generate QR", onPress: loadQrsAsPaints)
  //             : ConsoleButton(name: "Ok", onPress: widget.ok),
  //       ],
  //       bottomButtons: [
  //         ConsoleButton(name: "Back", onPress: widget.back),
  //         ConsoleButton(
  //             name: "Send",
  //             onPress: () {
  //               // final textNode = tec.value.text.isEmpty ? null : tec.value.text;
  //               final spender = widget.payment.txs.last.txsIn.first.spender;
  //               if (spender == g.self.id) {
  //                 widget.sendPayment(widget.payment);
  //                 // final pr = r.PaymentRequest(
  //                 //   sender: spender!,
  //                 //   payment: widget.payment,
  //                 //   targets: widget.payment.txs.last.txsOut
  //                 //       .where((txout) => txout.isGets)
  //                 //       .map((txout) => txout.receiver)
  //                 //       .whereType<String>()
  //                 //       .toList(growable: false),
  //                 // );
  //                 // widget.paymentRequest(pr);
  //                 widget.ok();
  //               }
  //             })
  //       ],
  //       // consoleRow: Console3(
  //       //   widgets: [
  //       //     qrs.isEmpty
  //       //         ? ConsoleButton(name: "GENERATE_QR", onPress: loadQrsAsPaints)
  //       //         : ConsoleButton(name: "OK", onPress: widget.ok),
  //       //     ConsoleButton(
  //       //         name: "SEND",
  //       //         onPress: () {
  //       //           // final textNode = tec.value.text.isEmpty ? null : tec.value.text;
  //       //           final spender = widget.payment.txs.last.txsIn.first.spender;
  //       //           if (spender == g.self.id) {
  //       //             widget.sendPayment(widget.payment);
  //       //             // final pr = r.PaymentRequest(
  //       //             //   sender: spender!,
  //       //             //   payment: widget.payment,
  //       //             //   targets: widget.payment.txs.last.txsOut
  //       //             //       .where((txout) => txout.isGets)
  //       //             //       .map((txout) => txout.receiver)
  //       //             //       .whereType<String>()
  //       //             //       .toList(growable: false),
  //       //             // );
  //       //             // widget.paymentRequest(pr);
  //       //             widget.ok();
  //       //           }
  //       //         })
  //       //   ],
  //       // ),
  //     );

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                qrs.isEmpty
                    ? ConsoleButton(
                        name: "GENERATE_QR", onPress: loadQrsAsPaints)
                    : ConsoleButton(name: "OK", onPress: widget.ok),
                ConsoleButton(
                    name: "SEND",
                    onPress: () {
                      // final textNode = tec.value.text.isEmpty ? null : tec.value.text;
                      final spender =
                          widget.payment.txs.last.txsIn.first.spender;
                      if (spender == g.self.id) {
                        widget.sendPayment(widget.payment);
                        // final pr = r.PaymentRequest(
                        //   sender: spender!,
                        //   payment: widget.payment,
                        //   targets: widget.payment.txs.last.txsOut
                        //       .where((txout) => txout.isGets)
                        //       .map((txout) => txout.receiver)
                        //       .whereType<String>()
                        //       .toList(growable: false),
                        // );
                        // widget.paymentRequest(pr);
                        widget.ok();
                      }
                    }),
              ], extension: null, widths: null, inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  Widget build(BuildContext context) {
    return Andrew(backButton: backArrow(back: widget.back), pages: [
      Down4Page(
        title: md5(widget.payment.txs.last.txID.data).toBase58(),
        // stackWidgets: qrs2.isNotEmpty ? [qrs2[listIndex]] : null,
        stackWidgets: qrs.map((e) => e(listIndex)).toList(growable: false),
        console: console,
      )
    ]);
  }

  @override
  List<String> get currentConsolesName => ["base"];

  @override
  int get currentPageIndex => 0;

  @override
  void setTheState() {
    setState(() {});
  }

  @override
  late List<Extra> extras = [];
}

class MoneyPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "money";
  final Transition? transition;
  final Personable? single;
  final ViewState viewState;
  // final List<Palette2> payments;
  final void Function(Down4Payment) onScan;
  final Future<void> Function() loadMorePayments;
  final void Function() back;
  final Future<void> Function(Down4Payment) makePayment;

  const MoneyPage({
    required this.loadMorePayments,
    required this.onScan,
    required this.back,
    required this.makePayment,
    required this.viewState,
    // required this.payments,
    this.transition,
    this.single,
    Key? key,
  }) : super(key: key);

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage>
    with WidgetsBindingObserver, Pager2, Input2, Scanner2 {
  // late final _ctrl =
  //     AnimationController(duration: Console.animationDuration, vsync: this)
  //       ..addListener(() {
  //         print("RELOADING MAINVIEWCONSOLE!");
  //         loadMainViewConsole();
  //       });

  // bool _scanning = false;
  // bool _extra = false;
  // bool _extraPay = false;
  // late FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  // void _onFocusChange() {
  //   if (!_focusNode.hasFocus) {
  //     _ctrl.reverse();
  //     reloadInputsAndConsole();
  //   } else {
  //     if (_console.key == emptyViewConsoleKey) {
  //       print("SQUEEZING");
  //       _ctrl.forward();
  //       loadEmptyViewConsole(doSqueeze: true);
  //     } else if (_console.key == mainViewConsoleKey) {
  //       print("SQUEEZING");
  //       _ctrl.forward();
  //       // loadMainViewConsole(doSqueeze: true);
  //     }
  //   }
  // }

  // final emptyViewConsoleKey = GlobalKey();
  // final mainViewConsoleKey = GlobalKey();
  // final inputKey = GlobalKey();
  // GlobalKey backButttonKey = GlobalKey();

  // var tec = TextEditingController();

  int _satsInput = 0;
  int _importAmount = 0;
  int? _balance;

  // @override
  // void changeConsole(String c) {
  //   currentConsolesName[currentPageIndex] = c;
  //   _extraPay = false;
  //   setTheState();
  // }

  void balanceRoutine() async {
    _balance = await g.wallet.balance;
    mainInput.ctrl.placeHolder = formattedCash;
    setState(() {});
  }

  String get formattedCash {
    if (_balance == null) return "...";
    switch (currency) {
      case "USD":
        return usds;
      case "SAT":
        return formattedSats(_balance!);
    }
    throw 'Unimplemented currency $currency';
  }

  String get formattedInput {
    switch (currency) {
      case "USD":
        return "${satoshisToUSD(_satsInput).toStringAsFixed(4)} USD";
      case "SAT":
        return "${formattedSats(_satsInput)} SAT";
    }
    throw "Unimplemented currency $currency";
  }

  @override
  late final List<MyTextEditor> inputs = [
    // MAIN INPUT
    MyTextEditor(
        alignment: AlignmentDirectional.center,
        onInput: onInput,
        maxWidth: 0.6,
        onFocusChange: onFocusChange,
        maxLines: 1,
        config: Input2.numberPad,
        ctrl: InputController(placeHolder: "...")),
    // IMPORT INPUT
    MyTextEditor(
        maxWidth: 0.6,
        onInput: onInput,
        onFocusChange: onFocusChange,
        config: Input2.singleLine,
        alignment: AlignmentDirectional.center,
        ctrl: InputController(placeHolder: "RAW PK BASE58"),
        maxLines: 3),
    // TEXT NOTE INPUT
    MyTextEditor(
        onInput: onInput,
        config: Input2.multiLine,
        ctrl: InputController(placeHolder: "(NOTE)"),
        alignment: AlignmentDirectional.center,
        onFocusChange: onFocusChange,
        maxWidth: 0.5,
        maxLines: 4),
    // FILTER INPUT,
    MyTextEditor(
        onInput: onInput,
        config: Input2.singleLine,
        alignment: AlignmentDirectional.center,
        ctrl: InputController(placeHolder: "FILTER"),
        onFocusChange: onFocusChange,
        maxLines: 1),
  ];

  MyTextEditor get mainInput => inputs[0];
  MyTextEditor get importInput => inputs[1];
  MyTextEditor get textNoteInput => inputs[2];
  MyTextEditor get filterInput => inputs[3];

  // final InputController mainIC = InputController(placeHolder: "...");
  // final FocusNode mainFN = FocusNode();
  // late final mainTec = MyTextEditor(
  //     input: mainIC,
  //     textAlign: TextAlign.center,
  //     numberPad: true,
  //     onInputChange: (text, height) {},
  //     maxWidth: 0.5,
  //     maxLines: 1,
  //     fn: mainFN);
  // ConsoleInput2 get mainInput => ConsoleInput2(mainTec);
  //
  // final InputController importIC = InputController();
  // final FocusNode importFN = FocusNode();
  // late final importTec = MyTextEditor(
  //     input: importIC,
  //     onInputChange: (text, height) {},
  //     maxWidth: 0.6,
  //     maxLines: 1,
  //     fn: importFN);
  // ConsoleInput2 get importInput => ConsoleInput2(importTec);
  //
  // final InputController textNoteIC = InputController();
  // final FocusNode textNodeFN = FocusNode();
  // late final textNoteTec = MyTextEditor(
  //     input: textNoteIC,
  //     onInputChange: (text, height) {},
  //     maxWidth: 0.6,
  //     maxLines: 4,
  //     fn: textNodeFN);
  // ConsoleInput2 get textNodeInput => ConsoleInput2(textNoteTec);
  //
  // final InputController filterIC = InputController();
  // final FocusNode filterFN = FocusNode();
  // late final filterTec = MyTextEditor(
  //     input: textNoteIC,
  //     onInputChange: (text, height) {},
  //     maxWidth: 0.6,
  //     maxLines: 4,
  //     fn: textNodeFN);
  // ConsoleInput2 get filterInput => ConsoleInput2(textNoteTec);

  // late Console _console;

  // MobileScannerController? scanner;

  Map<int, String> scannedData = {};
  int scannedDataLength = -1;
  // ConsoleInput? _cachedMainViewInput;
  final Map<String, dynamic> _currencies = {
    "l": ["SAT", "USD"],
    "i": 0,
  };
  final Map<String, dynamic> _paymentMethod = {
    "l": ["EACH", "SPLIT"],
    "i": 0,
  };
  late var palettes = widget.transition != null
      ? widget.transition!.preTransition
      : _users.values.toList(growable: false);

  late final _offset = (widget.transition?.nHidden ?? 0) * Palette2.fullHeight;
  late ScrollController scroller0 = ScrollController(
    initialScrollOffset: widget.transition != null
        ? widget.transition!.scroll
        : widget.single != null
            ? 0
            : widget.viewState.pages[0].scroll,
  )..addListener(() {
      widget.viewState.pages[0].scroll = scroller0.offset;
    });
  late ScrollController scroller1 = ScrollController(
    initialScrollOffset: widget.viewState.pages[1].scroll,
  )..addListener(() {
      widget.viewState.pages[1].scroll = scroller1.offset;
    });

  Map<ID, Palette2> get _payments => widget.viewState.pages[1].objects.cast();

  Map<ID, Palette2> get _users => widget.viewState.pages[0].objects.cast();

  List<Personable> get people => _users.values.asNodes<Personable>().toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.transition != null) animatedTransition();
    // if (people.isEmpty) {
    //   loadEmptyViewConsole();
    // } else {
    //   loadMainViewConsole();
    // }
    // reloadInputsAndConsole();
  }

  // Future<void> reloadInputsAndConsole() async {
  //   await loadBalance();
  //   loadMainViewInput();
  //   if (!_focusNode.hasFocus) {
  //     if (_console.key == emptyViewConsoleKey) {
  //       loadEmptyViewConsole();
  //     } else if (_console.key == mainViewConsoleKey) {
  //       loadMainViewConsole();
  //     }
  //   }
  // }

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          palettes = widget.transition!.postTransition;
          scroller0.jumpTo(widget.transition!.scroll + _offset);
          scroller0.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

  @override
  void dispose() {
    for (final fn in focusNodes) {
      fn.dispose();
    }
    scroller0.dispose();
    disposeScanner();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(MoneyPage old) {
    super.didUpdateWidget(old);
    balanceRoutine();
    // reloadInputsAndConsole();
  }

  int usdToSatoshis(double usds) =>
      ((usds / g.exchangeRate.rate) * 100000000).floor();

  double satoshisToUSD(int satoshis) =>
      (satoshis / 100000000) * g.exchangeRate.rate;

  Future<void> loadBalance() async => _balance = await g.wallet.balance;

  String formattedSats(int sats) => String.fromCharCodes(sats
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

  String get usds => satoshisToUSD(_balance!).toStringAsFixed(4);

  String get currency => _currencies["l"][_currencies["i"]] as String;

  String get method => _paymentMethod["l"][_paymentMethod["i"]] as String;

  void rotateCurrency() {
    _currencies["i"] =
        (_currencies["i"] + 1) % (_currencies["l"] as List<String>).length;
    mainInput.ctrl.placeHolder = formattedCash;
    setTheState();
  }

  void rotateMethod() {
    _paymentMethod["i"] = (_paymentMethod["i"] + 1) %
        (_paymentMethod["l"] as List<String>).length;
    setTheState();
  }

  @override
  void onScan(Barcode bc, MobileScannerArguments? args) {
    final raw = bc.rawValue;
    print("Trying to scan some good stuff right here!");
    if (raw == null) return;

    final isFirst = raw[0] == "_";
    if (!isFirst) {
      final prefixEnd = raw.indexOf(";");
      final ix = int.parse(raw.substring(0, prefixEnd));
      scannedData.putIfAbsent(ix, () => raw.substring(prefixEnd + 1));
    } else {
      final countPrefixEnd = raw.indexOf(",");
      scannedDataLength = int.parse(raw.substring(1, countPrefixEnd));
      scannedData.putIfAbsent(0, () => raw.substring(countPrefixEnd + 1));
    }

    if (scannedData.keys.length == scannedDataLength) {
      // we have all the data
      print("WE HAVE ALL THE DATA, SENDING!!!!");

      final sortedKeys = scannedData.keys.toList(growable: false)..sort();
      final sortedData =
          sortedKeys.map((e) => scannedData[e]).toList(growable: false).join();

      print("SORTED KEYS = $sortedKeys");

      final base85DecodedData = base85.decode(sortedData);

      final payment = Down4Payment.fromCompressed(base85DecodedData);

      // if (people.isEmpty) {
      //   loadEmptyViewConsole();
      // } else {
      //   loadMainViewConsole();
      // }
      widget.onScan(payment);

      setState(() => scanning = false);

      print("RESETTING SCAN");
      // scanner?.stop();
      scannedData = {};
      scannedDataLength = -1;
      // _scanning = false;
    }
  }

  // ConsoleInput get temporaryInput => ConsoleInput(
  //       textAlign: TextAlign.center,
  //       // flex: 4,
  //       placeHolder: "...",
  //       tec: tec,
  //       maxLines: 1,
  //       type: TextInputType.number,
  //     );

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": baseRow,
              "import": ConsoleRow(
                  widgets: [backButton, importInput.widget, checkButton],
                  extension: null,
                  widths: [0.25, 0.5, 0.25],
                  inputMaxHeight: null),
              "confirmImport": ConsoleRow(
                  widgets: [
                    ConsoleButton(
                        name: "BACK", onPress: () => changeConsole("import")),
                    ConsoleText(
                        text: "FOUND ${formattedSats(_importAmount)} sat"),
                    ConsoleButton(name: "IMPORT", onPress: import),
                  ],
                  extension: null,
                  widths: [0.25, 0.5, 0.25],
                  inputMaxHeight: null),
              "confirmPayment": ConsoleRow(
                  widgets: [
                    ConsoleButton(
                        name: "CANCEL", onPress: () => changeConsole("base")),
                    ConsoleButton(
                        name: formattedInput,
                        onPress: rotateCurrency,
                        isMode: true),
                    // quantity,
                    // currencyButton,

                    textNoteInput.widget,
                    ConsoleButton(name: "CONFIRM", onPress: confirmPayment)
                  ],
                  extension: null,
                  widths: textNoteInput.hasFocus
                      ? [0.0, 0.25, 0.50, 0.25]
                      : [.22, .34, .22, .22],
                  // importInput.hasFocus
                  //     ? [0.25, 0.5, 0.25]
                  //     : [0.25, 0.25, 0.5],
                  inputMaxHeight: textNoteInput.hasFocus
                      ? textNoteInput.height
                      : Console.buttonHeight),
            },
            {
              "base2": ConsoleRow(
                  widgets: [
                    ConsoleButton(name: "PERIOD", onPress: () {}),
                    filterInput.widget,
                    ConsoleButton(name: "ACCOUNT", onPress: () {}),
                  ],
                  extension: null,
                  widths: [0.25, 0.5, 0.25],
                  inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  ConsoleButton get openImportButton =>
      ConsoleButton(name: "IMPORT", onPress: () => changeConsole("import"));

  ConsoleButton get currencyButton =>
      ConsoleButton(isMode: true, name: currency, onPress: rotateCurrency);

  ConsoleButton get modeButton =>
      ConsoleButton(name: method, isMode: true, onPress: rotateMethod);

  ConsoleButton get billButton => ConsoleButton(
      name: "BILL", onPress: () => print("TODO"), isGreyedOut: true);

  ConsoleButton get payButton => ConsoleButton(
      name: "PAY",
      onPress: () {
        // if (_extraPay) return setState(() => _extraPay = !_extraPay);
        final inputValue = mainInput.value;
        if (inputValue.isEmpty) return;
        final numericValue = num.parse(inputValue);
        final trueValue =
            method == "SPLIT" ? numericValue : numericValue * _users.length;
        _satsInput = currency == "SAT"
            ? trueValue.toInt()
            : usdToSatoshis(trueValue.toDouble());
        changeConsole("confirmPayment");
      });

  ConsoleButton get checkButton => ConsoleButton(
        name: "CHECK",
        onPress: () async {
          final fetchedUtxos = await checkPrivateKey(importInput.value);
          _importAmount =
              fetchedUtxos?.values.fold<int>(0, (p, e) => p + e.sats.asInt) ??
                  0;
          changeConsole("confirmImport");
        },
      );

  ConsoleButton get backButton =>
      ConsoleButton(name: "BACK", onPress: () => changeConsole("base"));

  ConsoleText get quantity => ConsoleText(text: formattedInput);

  void import() async {
    final payment = await g.wallet.importMoney(importInput.value, g.self.id);
    if (payment == null) return;
    widget.onScan(payment);
  }

  void confirmPayment() async {
    final pay = await g.wallet.payPeople(
        people: people,
        selfID: g.self.id,
        amount: Sats(_satsInput),
        textNote: textNoteInput.value);
    if (pay != null) {
      await widget.makePayment(pay);
      mainInput.clear();
      textNoteInput.clear();
    }
  }

  // final GlobalKey _extraKey = GlobalKey();
  // bool extraB = false;

  ConsoleRow get baseRow => people.isEmpty
      ? ConsoleRow(
          widgets: [
            scanButton.withExtra(extraButton, [payButton, billButton]),
            mainInput.widget,
            currencyButton,
          ],
          extension: scanning ? (scanExtension, g.sizes.w) : null,
          widths: mainInput.hasFocus ? [0.2, 0.6, 0.2] : null,
          inputMaxHeight: null,
        )
      : ConsoleRow(
          widgets: people.length == 1
              ? [
                  payButton.withExtra(extraButton, [scanButton, billButton]),
                  mainInput.widget,
                  currencyButton,
                ]
              : [payButton, mainInput.widget, currencyButton, modeButton],
          extension: scanning ? (scanExtension, g.sizes.w) : null,
          widths: people.length == 1
              ? mainInput.hasFocus
                  ? [0.2, 0.6, 0.2]
                  : null
              : mainInput.hasFocus
                  ? [0.14, 0.58, 0.14, 0.14]
                  : null,
          inputMaxHeight: null);

  // void loadMainViewInput() {
  //   final sats = formattedSats(_balance!);
  //   _cachedMainViewInput = ConsoleInput(
  //     focus: _focusNode,
  //     textAlign: TextAlign.center,
  //     maxLines: 1,
  //     type: TextInputType.number,
  //     placeHolder: currency == "USD" ? "$usds \$" : "$sats sat",
  //     tec: tec,
  //   );
  //   setState(() {});
  // }

  // void loadEmptyViewConsole({bool doSqueeze = false}) {
  //   if (_scanning) {
  //     scanner = MobileScannerController();
  //   } else {
  //     scanner?.dispose();
  //     scanner = null;
  //   }
  //   _console = Console(
  //     key: emptyViewConsoleKey,
  //     scanner: !_scanning
  //         ? null
  //         : MobileScanner(onDetect: onScan, controller: scanner),
  //     bottomInputs: [],
  //     topButtons: [],
  //     bottomButtons: [
  //       ConsoleButton(
  //         key: backButttonKey,
  //         name: "BACK",
  //         isSpecial: true,
  //         showExtra: _extra,
  //         onPress: () {
  //           if (_extra) {
  //             _extra = false;
  //             loadEmptyViewConsole();
  //           } else {
  //             widget.back();
  //           }
  //         },
  //         //  extraBack
  //         //     ? loadEmptyViewConsole(scanning: scanning, extraBack: !extraBack)
  //         //     : widget.back(),
  //         onLongPress: () {
  //           _extra = !_extra;
  //           loadEmptyViewConsole();
  //         },
  //         extraButtons: [
  //           ConsoleButton(
  //             name: "IMPORT",
  //             onPress: loadImportConsole,
  //           )
  //         ],
  //       ),
  //       ConsoleButton(
  //         isMode: true,
  //         name: currency,
  //         onPress: () {
  //           rotateCurrency();
  //           loadMainViewInput();
  //           loadEmptyViewConsole(
  //               // scanning: scanning,
  //               // extraBack: extraBack,
  //               // reloadInput: true,
  //               );
  //         },
  //       ),
  //       _cachedMainViewInput ?? temporaryInput,
  //       ConsoleButton(
  //         name: "SCAN",
  //         onPress: () {
  //           _scanning = !_scanning;
  //           loadEmptyViewConsole();
  //         },
  //       ),
  //     ],
  //   );
  //   setState(() {});
  // }

  // void loadMainViewConsole() {
  //   _console = Console(
  //     key: mainViewConsoleKey,
  //     bottomInputs: [],
  //     topButtons: [],
  //     bottomButtons: [
  //       ConsoleButton(
  //           name: currency,
  //           isMode: true,
  //           onPress: () {
  //             rotateCurrency();
  //             if (tec.value.text.isEmpty) loadMainViewInput();
  //             loadMainViewConsole();
  //           }),
  //       ConsoleButton(
  //           name: method,
  //           isMode: true,
  //           onPress: () {
  //             rotateMethod();
  //             loadMainViewConsole();
  //           }),
  //       _cachedMainViewInput ?? temporaryInput,
  //       ConsoleButton(
  //         name: "PAY",
  //         onPress: () {
  //           if (_extraPay) {
  //             _extraPay = !_extraPay;
  //             loadMainViewConsole();
  //           } else if (tec.value.text.isNotEmpty) {
  //             loadConfirmationConsole(currency);
  //           }
  //         },
  //         onLongPress: () {
  //           _extraPay = !_extraPay;
  //           loadMainViewConsole();
  //         },
  //         isSpecial: true,
  //         showExtra: _extraPay,
  //         extraButtons: [
  //           ConsoleButton(
  //               name: "BILL", onPress: () => print("TODO"), isGreyedOut: true),
  //         ],
  //       ),
  //     ],
  //     // consoleRow: Console3(
  //     //   ctrl: _ctrl,
  //     //   beginSizes: const [.20, .20, .40, .20],
  //     //   endSizes: const [0, .20, .60, .20],
  //     //   widgets: [
  //     //
  //     //   ],
  //     // ),
  //     // bottomButtons: [
  //     //   // ConsoleButton(
  //     //   //   key: backButttonKey,
  //     //   //   name: "BACK",
  //     //   //   flex: doSqueeze ? 3 : 9,
  //     //   //   isSpecial: true,
  //     //   //   showExtra: _extra,
  //     //   //   onPress: () {
  //     //   //     if (_extra) {
  //     //   //       _extra = false;
  //     //   //       loadMainViewConsole();
  //     //   //     } else {
  //     //   //       widget.back();
  //     //   //     }
  //     //   //   },
  //     //   //   onLongPress: () {
  //     //   //     _extra = !_extra;
  //     //   //     loadMainViewConsole();
  //     //   //   },
  //     //   //   extraButtons: [
  //     //   //     ConsoleButton(name: "IMPORT", onPress: loadImportConsole),
  //     //   //   ],
  //     //   // ),
  //     //   ConsoleButton(
  //     //       name: currency,
  //     //       // flex: doSqueeze ? 0 : 4,
  //     //       maxWidth: Console.consoleWidth / 4,
  //     //       width: doSqueeze ? 0 : Console.consoleWidth / 4,
  //     //       isMode: true,
  //     //       onPress: () {
  //     //         rotateCurrency();
  //     //         if (tec.value.text.isEmpty) loadMainViewInput();
  //     //         loadMainViewConsole(
  //     //             // reloadInput: tec.value.text.isEmpty ? true : false,
  //     //             );
  //     //       }),
  //     //   ConsoleButton(
  //     //       name: method,
  //     //       maxWidth: Console.consoleWidth / 4,
  //     //       width: Console.consoleWidth / 4,
  //     //       isMode: true,
  //     //       onPress: () {
  //     //         rotateMethod();
  //     //         loadMainViewConsole();
  //     //       }),
  //     //   ConsoleInput(
  //     //     key: inputKey,
  //     //     maxWidth: Console.consoleWidth / 4,
  //     //     width:
  //     //         doSqueeze ? Console.consoleWidth / 2 : Console.consoleWidth / 4,
  //     //     focus: _focusNode,
  //     //     maxLines: 1,
  //     //     type: TextInputType.number,
  //     //     placeHolder: "LOL", // currency == "USD" ? "$usds \$" : "$sats sat",
  //     //     tec: tec,
  //     //   ),
  //     //
  //     //   // _cachedMainViewInput ?? temporaryInput,
  //     //   ConsoleButton(
  //     //     name: "PAY",
  //     //     maxWidth: Console.consoleWidth / 2,
  //     //     width: Console.consoleWidth / 4,
  //     //     onPress: () {
  //     //       if (_extraPay) {
  //     //         _extraPay = !_extraPay;
  //     //         loadMainViewConsole();
  //     //       } else if (tec.value.text.isNotEmpty) {
  //     //         loadConfirmationConsole(currency);
  //     //       }
  //     //     },
  //     //     onLongPress: () {
  //     //       _extraPay = !_extraPay;
  //     //       loadMainViewConsole();
  //     //     },
  //     //     isSpecial: true,
  //     //     showExtra: _extraPay,
  //     //     extraButtons: [
  //     //       ConsoleButton(
  //     //           name: "BILL", onPress: () => print("TODO"), isGreyedOut: true),
  //     //     ],
  //     //   ),
  //     // ],
  //   );
  //   setState(() {});
  // }

  // void loadConfirmationConsole(String inputCurrency) {
  //   double asUSD;
  //   int asSats;
  //   if (inputCurrency == "USD") {
  //     asUSD = num.parse(tec.value.text).toDouble() *
  //         (method == "Split" ? 1.0 : people.length);
  //     asSats = usdToSatoshis(asUSD);
  //   } else {
  //     asSats = num.parse(tec.value.text).toInt() *
  //         (method == "Split" ? 1 : people.length);
  //     asUSD = satoshisToUSD(asSats);
  //   }
  //
  //   void confirmPayment() async {
  //     final pay = await g.wallet.payPeople(
  //         people: people,
  //         selfID: g.self.id,
  //         amount: Sats(asSats),
  //         textNote: textNoteTec.value.text);
  //     // print("The pay: ${pay?.toJson()}");
  //     if (pay != null) {
  //       await widget.makePayment(pay);
  //       tec.clear();
  //       textNoteTec.clear();
  //       // await loadPayment(pay.id);
  //       // await loadInputsAndConsole();
  //       // widget.refreshMoneyPage();
  //     }
  //   }
  //
  //   final satsString = "${formattedSats(asSats)} sat";
  //   final usdString = "${asUSD.toStringAsFixed(4)} \$";
  //
  //   _console = Console(
  //     bottomInputs: [
  //       ConsoleInput(placeHolder: "(Text Note)", tec: textNoteTec)
  //     ],
  //     topButtons: [
  //       ConsoleButton(
  //           name: "-${currency == "USD" ? usdString : satsString}",
  //           onPress: confirmPayment),
  //     ],
  //     bottomButtons: [
  //       ConsoleButton(name: "Back", onPress: loadMainViewConsole),
  //       ConsoleButton(
  //         name: currency,
  //         isMode: true,
  //         onPress: () {
  //           rotateCurrency();
  //           loadConfirmationConsole(inputCurrency);
  //         },
  //       ),
  //     ],
  //   );
  //   setState(() {});
  // }

  // void loadImportConsole([Iterable<Down4TXOUT>? utxos]) {
  //   ConsoleInput input;
  //   if (utxos == null) {
  //     input = ConsoleInput(placeHolder: "WIF / PK", tec: importTec);
  //   } else {
  //     final sats = utxos.fold<int>(0, (prev, utxo) => prev + utxo.sats.asInt);
  //     final ph = "Found ${formattedSats(sats)} sat";
  //     input = ConsoleInput(placeHolder: ph, tec: textNoteTec, activated: false);
  //   }
  //
  //   void import() async {
  //     final payment =
  //         await g.wallet.importMoney(importTec.value.text, g.self.id);
  //
  //     if (payment == null) return;
  //     widget.onScan(payment);
  //     _extra = false;
  //     if (people.isEmpty) {
  //       loadEmptyViewConsole();
  //     } else {
  //       loadMainViewConsole();
  //     }
  //   }
  //
  //   _console = Console(
  //     bottomInputs: [input],
  //     topButtons: [
  //       ConsoleButton(name: "Import", onPress: import),
  //     ],
  //     bottomButtons: [
  //       ConsoleButton(
  //         name: "Back",
  //         onPress: () {
  //           _extra = false;
  //           if (people.isEmpty) {
  //             loadEmptyViewConsole();
  //           } else {
  //             loadMainViewConsole();
  //           }
  //         },
  //       ),
  //       ConsoleButton(
  //         name: "Check",
  //         onPress: () async {
  //           final fetchedUtxos = await checkPrivateKey(importTec.value.text);
  //           loadImportConsole(fetchedUtxos?.values);
  //         },
  //       ),
  //     ],
  //   );
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    print("PALLETSN = ${_payments.length}");
    return Andrew(
      backButton: backArrow(back: widget.back),
      initialPageIndex: widget.viewState.currentIndex,
      onPageChange: (idx) => setState(() {
        widget.viewState.currentIndex = idx;
      }),
      pages: [
        Down4Page(
            scrollController: scroller0,
            staticList: true,
            title: "Money",
            list: palettes,
            trueLen: people.length,
            console: console),
        Down4Page(
            onRefresh: widget.loadMorePayments,
            title: "Status",
            list: _payments.values.toList(),
            console: console),
      ],
    );
  }

  @override
  List<String> currentConsolesName = ["base", "base2"];

  Extra get extraButton => extras[0];

  @override
  late List<Extra> extras = [Extra(setTheState: setTheState)];

  @override
  int get currentPageIndex => widget.viewState.currentIndex;

  @override
  void setTheState() => setState(() {});
}
