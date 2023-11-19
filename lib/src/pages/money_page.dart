import 'dart:async';

import 'package:url_launcher/url_launcher.dart';
import 'package:base85/base85.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/_dart_utils.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr/qr.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../bsv/types.dart';
import '../bsv/_bsv_utils.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/nodes.dart';
import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/qr.dart';
import '../render_objects/_render_utils.dart'
    show Down4PageWidget, IterablePalette2Extensions;
import '_page_utils.dart';

final base85 = Base85Codec(Alphabets.z85);

class PaymentPage extends StatefulWidget with Down4PageWidget {
  @override
  String get id => "payment";
  final void Function() back, ok;
  final Down4Payment payment;
  final void Function(Down4Payment) sendPayment;

  const PaymentPage({
    required this.ok,
    required this.back,
    required this.payment,
    required this.sendPayment,
    super.key,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with Pager2 {
  Timer? timer;
  int listIndex = 0;
  var qrs = <Widget Function(int)>[];
  var qrs2 = <Widget>[];

  List<String>? _paymentAsList;
  List<String> get paymentAsList {
    return _paymentAsList ??= payment.asQrData;
  }

  Timer get startedTimer {
    return Timer.periodic(const Duration(milliseconds: 400), (timer) {
      listIndex = (listIndex + 1) % paymentAsList.length;
      setState(() {});
    });
  }

  void loadQrsAsPaints() {
    for (int i = 0; i < paymentAsList.length; i++) {
      var paymentData = paymentAsList[i];
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

  Down4Payment get payment => widget.payment;
  bool get validPayment =>
      payment.spender == g.self.id && payment.validForBroadcast;

  @override
  Console get console => Console(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                qrs.isEmpty
                    ? ConsoleButton(
                        name: "GENERATE_QR",
                        onPress: loadQrsAsPaints,
                        isGreyedOut: validPayment,
                        isActivated: validPayment)
                    : ConsoleButton(name: "OK", onPress: widget.ok),
                ConsoleButton(
                    name: "SEND",
                    isGreyedOut: validPayment,
                    isActivated: validPayment,
                    onPress: () {
                      if (widget.payment.spender == g.self.id) {
                        widget.sendPayment(widget.payment);
                        widget.ok();
                      }
                    }),
              ], extension: null, widths: null, inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  String get note {
    if (payment.spender == null) {
      return payment.textNote;
    } else if (payment.textNote.isEmpty) {
      return "";
    } else {
      return "${payment.spender!.unik}: ${payment.textNote}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final tst = g.theme.paletteNameStyle(selected: false);
    final smaller = tst.copyWith(fontSize: tst.fontSize! - 2);
    final bolded = tst.copyWith(fontWeight: FontWeight.bold);
    final urltst = smaller.copyWith(color: Colors.blue);

    // final sender = payment.spender?.unik ?? "";
    // TextPainter(text: TextSpan(text: sender, style: bolded));

    return Andrew(
      backFunction: widget.back,
      pages: [
        Down4Page(
          title: md5(widget.payment.id.value.codeUnits).toBase58(),
          stackWidgets: qrs.map((e) => e(listIndex)).toList(growable: false),
          list: [
            // Padding(
            //   padding: const EdgeInsets.all(40),
            //   child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Text(note,
            //             style: tst,
            //             maxLines: 10,
            //             overflow: TextOverflow.ellipsis),
            //         const SizedBox(height: 20),
            //         Row(
            //           children: [
            //             Text("TXID: ", style: tst),
            //             Expanded(
            //               child: GestureDetector(
            //                 onTap: () => launchUrl(
            //                   Uri.parse(
            //                     "https://test.whatsonchain.com/tx/${widget.payment.txid.asHex}",
            //                   ),
            //                 ),
            //                 child: Text(
            //                   widget.payment.txid.asHex,
            //                   maxLines: 1,
            //                   style: urltst,
            //                   overflow: TextOverflow.ellipsis,
            //                 ),
            //               ),
            //             ),
            //           ],
            //         ),
            //         Row(children: [
            //           Text("Confirmations: ", style: tst),
            //           Text(widget.payment.confirmationsFmt,
            //               style: tst.copyWith(color: widget.payment.color))
            //         ]),
            //       ]),
            // ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment.spender?.unik ?? "", style: bolded),
                    Text(payment.textNote, style: smaller),
                    const SizedBox(height: 20),
                    Text("Transaction ID", style: bolded),
                    GestureDetector(
                        onTap: () => launchUrl(Uri.parse(
                            "https://test.whatsonchain.com/tx/${widget.payment.txid.asHex}")),
                        child: Text(widget.payment.txid.asHex,
                            maxLines: 1,
                            style: urltst,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(height: 20),
                    Text("Confirmations", style: bolded),
                    Text(widget.payment.confirmationsFmt,
                        style: smaller.copyWith(color: widget.payment.color)),
                  ]),
            ),
          ],
          console: console,
        )
      ],
    );
  }

  @override
  List<String> currentConsolesName = ["base"];

  @override
  int get currentPageIndex => 0;

  @override
  void setTheState() {
    setState(() {});
  }

  @override
  late List<Extra> extras = [];
}

class MoneyPage extends StatefulWidget with Down4PageWidget {
  @override
  String get id => "money";
  final List<Palette>? initPalettes;
  final double? initScroll;
  final PersonN? single;
  final void Function(Down4Payment) onScan;
  final Future<void> Function() loadMorePayments;
  final void Function() back;
  final void Function(Down4Payment) makePayment;

  const MoneyPage({
    required this.loadMorePayments,
    required this.onScan,
    required this.back,
    required this.makePayment,
    this.initPalettes,
    this.initScroll,
    this.single,
    Key? key,
  }) : super(key: key);

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        Pager2,
        Input2,
        Scanner2,
        Transition2 {
  @override
  TickerProvider get ticker => this;

  late Set<PersonN> trueTargets;

  int _satsInput = 0;
  int _importAmount = 0;
  int? _balance;
  int get _discountPercentage => int.tryParse(discountInput.value) ?? 0;
  int get _tipPercentage => int.tryParse(tipInput.value) ?? 0;
  int get _discountAmount => (_discountPercentage / 100 * _satsInput).toInt();
  int get _tipAmount => (_tipPercentage / 100 * _satsInput).toInt();
  int get _totalAmount => _satsInput + _tipAmount - _discountAmount;

  void balanceRoutine() {
    _balance = g.wallet.balance;
    mainInput.ctrl.placeHolder = formattedCash;
    setState(() {});
  }

  String formatted(int sats) {
    switch (currency) {
      case "USD":
        return formattedDollars(satoshisToUSD(sats));
      case "SAT":
        return formattedSats(sats);
    }
    throw "Unimplemented currency: $currency";
  }

  String formattedDollars(double dollars) {
    final String withFourDigits = dollars.toStringAsFixed(4);
    final List<String> splitted = withFourDigits.split(".");
    final String formattedDollarsPart = formattedSats(int.parse(splitted[0]));
    return "$formattedDollarsPart.${splitted[1]}";
  }

  String get formattedCash {
    if (_balance == null) return "...";
    return formatted(_balance!);
  }

  String get formattedInput {
    return formatted(_satsInput);
  }

  String formattedWithIcon(int sats) {
    switch (currency) {
      case "USD":
        return "${formattedDollars(satoshisToUSD(sats))} \$";
      case "SAT":
        return "${formattedSats(sats)} SAT";
    }
    throw "Unimplemented currency $currency";
  }

  @override
  late final List<MyTextEditor> inputs = [
    // MAIN INPUT
    MyTextEditor(
      centered: true,
      onInput: onInput,
      maxWidth: 0.6,
      onFocusChange: onFocusChange,
      maxLines: 1,
      config: Input2.numberPad,
      placeHolder: "...",
    ),
    // IMPORT INPUT
    MyTextEditor(
      maxWidth: 0.6,
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.singleLine,
      centered: true,
      placeHolder: "RAW PK BASE58",
      maxLines: 3,
    ),
    // TEXT NOTE INPUT
    MyTextEditor(
      onInput: onInput,
      config: Input2.multiLine,
      placeHolder: "NOTE",
      centered: true,
      onFocusChange: onFocusChange,
      maxWidth: 0.6,
      maxLines: 4,
    ),
    // DISCOUNT INPUT,
    MyTextEditor(
      onInput: onInput,
      config: Input2.numberPad,
      placeHolder: "DISCOUNT %",
      centered: true,
      onFocusChange: onFocusChange,
      maxWidth: 0.6,
      maxLines: 1,
    ),
    // TIP INPUT,
    MyTextEditor(
      onInput: onInput,
      config: Input2.numberPad,
      placeHolder: "TIP %",
      centered: true,
      onFocusChange: onFocusChange,
      maxWidth: 0.6,
      maxLines: 1,
    ),
    // FILTER INPUT,
    MyTextEditor(
      onInput: onInput,
      config: Input2.singleLine,
      centered: true,
      placeHolder: "FILTER",
      onFocusChange: onFocusChange,
      maxLines: 1,
    ),
  ];

  MyTextEditor get mainInput => inputs[0];
  MyTextEditor get importInput => inputs[1];
  MyTextEditor get textNoteInput => inputs[2];
  MyTextEditor get discountInput => inputs[3];
  MyTextEditor get tipInput => inputs[4];
  MyTextEditor get filterInput => inputs[5];

  Map<int, String> scannedData = {};
  int scannedDataLength = -1;
  final Map<String, dynamic> _currencies = {
    "l": ["SAT", "USD"],
    "i": 0,
  };
  final Map<String, dynamic> _paymentMethod = {
    "l": ["EACH", "SPLIT"],
    "i": 0,
  };

  late var palettes =
      widget.initPalettes ?? _users.values.toList(growable: false);

  ViewState get vs => widget.vs;

  late ScrollController scroller0 = ScrollController(
      initialScrollOffset: widget.initScroll ?? vs.pages[0].scroll)
    ..addListener(() => vs.pages[0].scroll = scroller0.offset);

  late ScrollController scroller1 =
      ScrollController(initialScrollOffset: vs.pages[1].scroll)
        ..addListener(() => vs.pages[1].scroll = scroller1.offset);

  @override
  ScrollController get mainScroll => scroller0;

  Map<Down4ID, Palette> get _payments => vs.pages[1].state.cast();

  Map<ComposedID, Palette> get _users => vs.pages[0].state.cast();

  Set<PersonN> get people => _users.values.asNodes<PersonN>().toSet();

  @override
  void animatedTransition(List<Palette>? ogs, double? ogOffset) {
    if (ogs == null && ogOffset == null) return;
    final (transited, nHidden, tt) = transitionPalettes(ogs!);
    trueTargets = tt;
    Future(() {
      final offset = nHidden * Palette.fullHeight;
      transitedPalettes = transited;
      mainScroll.jumpTo(ogOffset! + offset);
      mainScroll.animateTo(0, duration: transDuration, curve: Curves.easeInOut);
      foldAnim.forward();
      fadeAnim.forward();
      setTheState();
      Future(() {
        // we write true targets to users, and will render
        // them for display and true targets if we comeback from payments
        for (final t in tt) {
          writePalette(t, _users, null, null, home: false);
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    balanceRoutine();
    // this means no transition (back from payments), so we can use people
    if (widget.initPalettes == null) {
      if (widget.single == null) {
        trueTargets = people;
      } else {
        trueTargets = {widget.single!};
        writePalette(widget.single!, _users, null, null, home: false);
      }
    }
    animatedTransition(widget.initPalettes, widget.initScroll);
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
  void onScan(Barcode bc) {
    final raw = bc.code;
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

      widget.onScan(payment);

      print("RESETTING SCAN");
      scannedData = {};
      scannedDataLength = -1;
      scanning = false;
      disposeScanner();
      setTheState();
    }
  }

  @override
  Console get console => Console(
          rows: [
            {
              "base": baseRow,
              "import": ConsoleRow(
                widgets: [backButton, importInput.consoleInput, checkButton],
                extension: null,
                widths:
                    importInput.hasFocus ? [0.2, 0.6, 0.2] : [0.25, 0.5, 0.25],
                inputMaxHeight:
                    importInput.hasFocus ? importInput.height : null,
              ),
              "confirmImport": ConsoleRow(widgets: [
                ConsoleButton(
                    name: "RETURN", onPress: () => changeConsole("import")),
                currencyButton,
                ConsoleButton(name: "IMPORT", onPress: import),
              ], extension: importWidget, widths: null, inputMaxHeight: null),
              "confirmPayment": ConsoleRow(
                widgets: [
                  cancelButton,
                  currencyButton,
                  confirmPaymentButton,
                  withNoteButton.withExtra(confirmExtra, [
                    withDiscountButton,
                    withTipButton,
                  ]),
                ],
                extension: quantityWidget,
                widths: null,
                inputMaxHeight: null,
              ),
              "textNote": ConsoleRow(
                  widgets: [
                    ConsoleButton(
                        name: "RETURN",
                        onPress: () => changeConsole("confirmPayment")),
                    textNoteInput.consoleInput,
                    withTipButton.withExtra(withTipExtra, [
                      withDiscountButton,
                    ])
                  ],
                  extension: quantityWidget,
                  widths:
                      textNoteInput.hasFocus ? [.2, .6, .2] : [.25, .5, .25],
                  inputMaxHeight:
                      textNoteInput.hasFocus ? textNoteInput.height : null),
              "tip": ConsoleRow(
                  widgets: [
                    ConsoleButton(
                        name: "RETURN",
                        onPress: () => changeConsole("confirmPayment")),
                    tipInput.consoleInput,
                    withNoteButton.withExtra(withNoteExtra, [
                      withDiscountButton,
                    ]),
                  ],
                  extension: quantityWidget,
                  widths: hasFocus ? [.2, .6, .2] : [.25, .5, .25],
                  inputMaxHeight: null),
              "discount": ConsoleRow(
                  widgets: [
                    ConsoleButton(
                        name: "RETURN",
                        onPress: () => changeConsole("confirmPayment")),
                    discountInput.consoleInput,
                    withNoteButton.withExtra(withNoteExtra2, [
                      withTipButton,
                    ]),
                  ],
                  extension: quantityWidget,
                  widths: hasFocus ? [.2, .6, .2] : [.25, .5, .25],
                  inputMaxHeight: null),
            },
            {
              "base2": ConsoleRow(
                  widgets: [
                    ConsoleButton(name: "PERIOD", onPress: () {}),
                    filterInput.consoleInput,
                    ConsoleButton(name: "ACCOUNT", onPress: () {}),
                  ],
                  extension: null,
                  widths: filterInput.hasFocus
                      ? [0.2, 0.6, 0.2]
                      : [0.25, 0.5, 0.25],
                  inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  ConsoleButton get cancelButton => ConsoleButton(
      name: "CANCEL",
      onPress: () {
        tipInput.clear();
        discountInput.clear();
        textNoteInput.clear();
        mainInput.clear();
        changeConsole("base");
      });

  ConsoleButton get confirmPaymentButton => ConsoleButton(
      name: "CONFIRM",
      isSpecial: true,
      onPress: () {},
      onLongPress: confirmPayment);

  ConsoleButton get withTipButton =>
      ConsoleButton(name: "W/TIP", onPress: () => changeConsole("tip"));

  ConsoleButton get withDiscountButton => ConsoleButton(
      name: "W/DISCOUNT", onPress: () => changeConsole("discount"));

  ConsoleButton get withNoteButton =>
      ConsoleButton(name: "W/NOTE", onPress: () => changeConsole("textNote"));

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

  (Widget, double?) doublerWidget(List<(String name, String format)> ins) {
    double singleRowHeight() {
      final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(text: "0", style: g.theme.consoleTextStyle))
        ..layout(maxWidth: g.sizes.w);
      return tp.height;
    }

    final tStyle = g.theme.consoleTextStyle;
    Widget doubler2(String name, String format) {
      return Row(
        children: [
          Text(name, style: tStyle),
          const Spacer(),
          Text(format, style: tStyle),
        ],
      );
    }

    final doublers = ins.map((e) => doubler2(e.$1, e.$2));

    final tNoteTp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: textNoteInput.value, style: tStyle))
      ..layout(maxWidth: g.sizes.w * 0.9);

    final hGapper = g.sizes.w * 0.05;
    final vGapper = hGapper / golden;
    final _gapper = vGapper / golden;

    final bool hasText = textNoteInput.value.isNotEmpty;
    final h = hasText ? (_gapper * 2) + 1 + tNoteTp.height : 0;

    return (
      Padding(
          padding: EdgeInsets.symmetric(horizontal: hGapper, vertical: vGapper),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...doublers,
              hasText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          SizedBox(height: _gapper),
                          Container(color: tStyle.color, height: 1),
                          SizedBox(height: _gapper),
                          Text(textNoteInput.value, style: tStyle),
                        ])
                  : const SizedBox.shrink(),
            ],
          )),
      (singleRowHeight() * ins.length) + (2 * vGapper) + h
    );
  }

  (Widget, double?) get importWidget {
    return doublerWidget([("FOUND", formattedWithIcon(_importAmount))]);
  }

  (Widget, double?) get quantityWidget {
    List<(String, String)> children() => [
          ("INPUT", formattedWithIcon(_satsInput)),
          ..._tipAmount > 0
              ? [("TIP $_tipPercentage%", "+${formattedWithIcon(_tipAmount)}")]
              : [],
          ..._discountAmount > 0
              ? [
                  (
                    "DISCOUNT $_discountPercentage%",
                    "-${formattedWithIcon(_discountAmount)}"
                  )
                ]
              : [],
          ..._discountAmount > 0 || _tipAmount > 0
              ? [("TOTAL", "=${formattedWithIcon(_totalAmount)}")]
              : []
        ];

    return doublerWidget(children());
  }

  void import() async {
    changeConsole("base");
    final payment = await g.wallet.importMoney(importInput.value, g.self.id);
    if (payment == null) return;
    widget.onScan(payment);
  }

  void confirmPayment() {
    // TODO: add tips utxos and discount notes
    final pay = g.wallet.payPeople(
        people: trueTargets.toList(),
        selfID: g.self.id,
        amount: Sats(_totalAmount),
        textNote: textNoteInput.value);
    if (pay != null) {
      widget.makePayment(pay);
      mainInput.clear();
      textNoteInput.clear();
    }
  }

  ConsoleRow get baseRow {
    if (trueTargets.isEmpty) {
      return ConsoleRow(
        widgets: [
          scanButton.withExtra(extraButton, [
            openImportButton,
            payButton,
            billButton,
          ]),
          mainInput.consoleInput,
          currencyButton,
        ],
        extension: scanning ? (scanExtension, g.sizes.w) : null,
        widths: mainInput.hasFocus ? [0.2, 0.6, 0.2] : null,
        inputMaxHeight: null,
      );
    } else if (trueTargets.length == 1) {
      return ConsoleRow(
          widgets: [
            payButton.withExtra(extraButton, [
              openImportButton,
              scanButton,
              billButton,
            ]),
            mainInput.consoleInput,
            currencyButton,
          ],
          extension: scanning ? (scanExtension, g.sizes.w) : null,
          widths: people.length == 1
              ? mainInput.hasFocus
                  ? [0.2, 0.6, 0.2]
                  : null
              : mainInput.hasFocus
                  ? [0.2, 0.4, 0.2, 0.2]
                  : null,
          inputMaxHeight: null);
    } else {
      return ConsoleRow(
          widgets: [
            payButton.withExtra(extraButton, [
              openImportButton,
              scanButton,
              billButton,
            ]),
            mainInput.consoleInput,
            currencyButton,
            modeButton,
          ],
          extension: scanning ? (scanExtension, g.sizes.w) : null,
          widths: people.length == 1
              ? mainInput.hasFocus
                  ? [0.2, 0.6, 0.2]
                  : null
              : mainInput.hasFocus
                  ? [0.2, 0.4, 0.2, 0.2]
                  : null,
          inputMaxHeight: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      backFunction: widget.back,
      initialPageIndex: vs.currentIndex,
      onPageChange: (idx) => setState(() => vs.currentIndex = idx),
      pages: [
        Down4Page(
            scrollController: scroller0,
            staticList: true,
            title: "Money",
            list: transitedPalettes ??
                widget.initPalettes ??
                _users.values.toList(),
            console: console),
        Down4Page(
            scrollController: scroller1,
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
  Extra get confirmExtra => extras[1];
  Extra get withNoteExtra => extras[2];
  Extra get withTipExtra => extras[3];
  Extra get withNoteExtra2 => extras[4];

  @override
  late List<Extra> extras = [
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
  ];

  @override
  int get currentPageIndex => vs.currentIndex;

  @override
  void setTheState() => setState(() {});
}
