import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:base85/base85.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr/qr.dart';

import '../data_objects.dart';
import '../web_requests.dart' as r;
import '../bsv/wallet.dart';
import '../bsv/types.dart';
import '../bsv/utils.dart';
import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/qr.dart';
import '../render_objects/_down4_flutter_utils.dart'
    show Down4PageWidget, Palette2Extensions;

final base85 = Base85Codec(Alphabets.z85);

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

class PaymentPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "PaymentPage";
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

class _PaymentPageState extends State<PaymentPage> {
  Timer? timer;
  int listIndex = 0;
  var qrs = <Widget Function(int)>[];
  var qrs2 = <Widget>[];
  var tec = TextEditingController();
  late var input = ConsoleInput(placeHolder: "(Text Note)", tec: tec);
  late Console theConsole = aConsole;

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
      theConsole = aConsole;
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

  Console get aConsole => Console(
        // inputs: [input],
        topButtons: [
          qrs.isEmpty
              ? ConsoleButton(name: "Generate QR", onPress: loadQrsAsPaints)
              : ConsoleButton(name: "Ok", onPress: widget.ok),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(
              name: "Send",
              onPress: () {
                // final textNode = tec.value.text.isEmpty ? null : tec.value.text;
                final spender = widget.payment.txs.last.txsIn.first.spender;
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
              })
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        title: md5(widget.payment.txs.last.txID.data).toBase58(),
        // stackWidgets: qrs2.isNotEmpty ? [qrs2[listIndex]] : null,
        stackWidgets: qrs.map((e) => e(listIndex)).toList(growable: false),
        console: theConsole,
      )
    ]);
  }
}

class MoneyPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "MoneyPage";
  final List<Palette2> palettesBeforeTransition, palettesAfterTransition;
  final Iterable<Person> people;
  final int nHidden;
  final void Function(Down4Payment) openPayment;
  final Down4Payment? paymentUpdate;
  final void Function() back;
  final Future<void> Function(Down4Payment) makePayment;
  final double initialOffset;

  const MoneyPage({
    required this.palettesAfterTransition,
    required this.openPayment,
    required this.people,
    required this.nHidden,
    required this.palettesBeforeTransition,
    required this.back,
    // required this.refreshMoneyPage,
    required this.makePayment,
    required this.initialOffset,
    this.paymentUpdate,
    Key? key,
  }) : super(key: key);

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  bool _scanning = false;
  bool _extra = false;

  final emptyViewConsoleKey = GlobalKey();
  final mainViewConsoleKey = GlobalKey();
  GlobalKey backButttonKey = GlobalKey();

  var tec = TextEditingController();
  var importTec = TextEditingController();
  var textNoteTec = TextEditingController();
  MobileScannerController? scanner;
  Console? _console;
  Map<int, String> scannedData = {};
  int scannedDataLength = -1;
  ConsoleInput? _cachedMainViewInput;
  final Map<String, dynamic> _currencies = {
    "l": ["USD", "Satoshis"],
    "i": 0,
  };
  final Map<String, dynamic> _paymentMethod = {
    "l": ["Each", "Split"],
    "i": 0,
  };
  late var palettes = widget.palettesBeforeTransition;
  late final _offset = widget.nHidden * Palette.fullHeight;
  late ScrollController scrollController0 = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );

  int? _balance;

  Map<ID, Palette2> _payments = {};

  Future<void> loadMorePayments(int n) async {
    await payments3(n).toList();
    setState(() {});
  }

  Palette2 paymentToPalette(Down4Payment payment) {
    return Palette2(
      node: Payment(payment: payment, selfID: g.self.id),
      messagePreview: payment.textNote,
      buttonsInfo2: [
        ButtonsInfo2(
            asset: g.fifty,
            pressFunc: () => widget.openPayment(payment),
            rightMost: true)
      ],
    );
  }

  Future<void> loadPayment(ID id) async {
    final payment = await g.wallet.getPayment(id);
    if (payment == null) return;
    _payments.putIfAbsent(id, () => paymentToPalette(payment));
    return setState(() {});
  }

  Stream<void> payments3(int n) async* {
    await for (final p in g.wallet.payments.skip(_payments.length).take(n)) {
      final asNode = Payment(payment: p, selfID: g.self.id);
      _payments.putIfAbsent(p.id, () => paymentToPalette(p));
    }
  }

  @override
  void initState() {
    super.initState();
    animatedTransition();
    loadMorePayments(4);
    loadInputsAndConsole();
    if (widget.people.isEmpty) {
      loadEmptyViewConsole();
    } else {
      loadMainViewConsole();
    }
  }

  Future<void> loadInputsAndConsole() async {
    await loadBalance();
    loadMainViewInput();
    if (widget.people.isEmpty) {
      loadEmptyViewConsole();
    } else {
      loadMainViewConsole();
    }
  }

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          palettes = widget.palettesAfterTransition;
          scrollController0.jumpTo(widget.initialOffset + _offset);
          scrollController0.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

  @override
  void dispose() {
    tec.dispose();
    importTec.dispose();
    textNoteTec.dispose();
    scanner?.dispose();
    scrollController0.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MoneyPage old) {
    super.didUpdateWidget(old);
    if (widget.paymentUpdate != null) {
      _payments.putIfAbsent(widget.paymentUpdate!.id,
          () => paymentToPalette(widget.paymentUpdate!));
    }
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
  }

  void rotateMethod() {
    _paymentMethod["i"] = (_paymentMethod["i"] + 1) %
        (_paymentMethod["l"] as List<String>).length;
  }

  dynamic onScan(Barcode bc, MobileScannerArguments? args) async {
    final raw = bc.rawValue;
    print("Trying to scan some good stuff right here!");
    if (raw != null) {
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
        await scanner?.stop();
        final sortedKeys = scannedData.keys.toList(growable: false)..sort();
        final sortedData = sortedKeys
            .map((e) => scannedData[e])
            .toList(growable: false)
            .join();

        print("SORTED KEYS = $sortedKeys");

        final base85DecodedData = base85.decode(sortedData);

        final payment = Down4Payment.fromCompressed(base85DecodedData);
        print(payment.txs.fold<String>("", (p, e) => "$p${e.txID.asHex}\n"));

        print("the payment = $payment");

        print("Parsing the payment!");
        scannedData = {};
        scannedDataLength = -1;

        _scanning = false;
        await g.wallet.parsePayment(g.self.id, payment);
        await loadPayment(payment.id);
        loadInputsAndConsole();
        print("Should literally work");
      }
    }
  }

  ConsoleInput get temporaryInput => ConsoleInput(
        placeHolder: "...",
        tec: tec,
        maxLines: 1,
        type: TextInputType.number,
      );

  void loadMainViewInput() {
    final sats = formattedSats(_balance!);
    _cachedMainViewInput = ConsoleInput(
      maxLines: 1,
      type: TextInputType.number,
      placeHolder: currency == "USD" ? "$usds \$" : "$sats sat",
      tec: tec,
    );
    setState(() {});
  }

  void loadEmptyViewConsole(
      // {bool scanning = false,
      // bool extraBack = false,
      // bool reloadInput = false,}
      ) {
    if (_scanning) {
      scanner = MobileScannerController();
    } else {
      scanner?.dispose();
      scanner = null;
    }
    // if (reloadInput) loadMainViewInput();
    _console = Console(
      key: emptyViewConsoleKey,
      scanner: !_scanning
          ? null
          : MobileScanner(onDetect: onScan, controller: scanner),
      bottomInputs: [_cachedMainViewInput ?? temporaryInput],
      topButtons: [
        ConsoleButton(
          name: "Scan",
          onPress: () {
            _scanning = !_scanning;
            loadEmptyViewConsole();
          },
        )
      ],
      bottomButtons: [
        ConsoleButton(
          key: backButttonKey,
          name: "Back",
          isSpecial: true,
          showExtra: _extra,
          onPress: () {
            if (_extra) {
              _extra = false;
              loadEmptyViewConsole();
            } else {
              widget.back();
            }
          },
          //  extraBack
          //     ? loadEmptyViewConsole(scanning: scanning, extraBack: !extraBack)
          //     : widget.back(),
          onLongPress: () {
            _extra = !_extra;
            loadEmptyViewConsole();
          },
          extraButtons: [
            ConsoleButton(
              name: "Import",
              onPress: loadImportConsole,
            )
          ],
        ),
        ConsoleButton(
          isMode: true,
          name: currency,
          onPress: () {
            rotateCurrency();
            loadMainViewInput();
            loadEmptyViewConsole(
                // scanning: scanning,
                // extraBack: extraBack,
                // reloadInput: true,
                );
          },
        ),
      ],
    );
    setState(() {});
  }

  void loadMainViewConsole() {
    _console = Console(
      key: mainViewConsoleKey,
      bottomInputs: [_cachedMainViewInput ?? temporaryInput],
      topButtons: [
        ConsoleButton(
            name: "Bill", onPress: () => print("TODO"), isGreyedOut: true),
        ConsoleButton(
            name: "Pay",
            onPress: () {
              if (tec.value.text.isNotEmpty) loadConfirmationConsole(currency);
            }),
      ],
      bottomButtons: [
        ConsoleButton(
          key: backButttonKey,
          name: "Back",
          isSpecial: true,
          showExtra: _extra,
          onPress: () {
            if (_extra) {
              _extra = false;
              loadMainViewConsole();
            } else {
              widget.back();
            }
          },
          onLongPress: () {
            _extra = !_extra;
            loadMainViewConsole();
          },
          // _extra ? loadMainViewConsole(extra: !extra) : widget.back(),

          extraButtons: [
            ConsoleButton(name: "Import", onPress: loadImportConsole),
          ],
        ),
        ConsoleButton(
            name: method,
            isMode: true,
            onPress: () {
              rotateMethod();
              loadMainViewConsole();
            }),
        ConsoleButton(
            name: currency,
            isMode: true,
            onPress: () {
              rotateCurrency();
              if (tec.value.text.isEmpty) loadMainViewInput();
              loadMainViewConsole(
                  // reloadInput: tec.value.text.isEmpty ? true : false,
                  );
            }),
      ],
    );
    setState(() {});
  }

  void loadConfirmationConsole(String inputCurrency) {
    double asUSD;
    int asSats;
    if (inputCurrency == "USD") {
      asUSD = num.parse(tec.value.text).toDouble() *
          (method == "Split" ? 1.0 : widget.people.length);
      asSats = usdToSatoshis(asUSD);
    } else {
      asSats = num.parse(tec.value.text).toInt() *
          (method == "Split" ? 1 : widget.people.length);
      asUSD = satoshisToUSD(asSats);
    }

    void confirmPayment() async {
      final pay = await g.wallet.payPeople(
          people: widget.people.toList(growable: false),
          selfID: g.self.id,
          amount: Sats(asSats),
          textNote: textNoteTec.value.text);
      // print("The pay: ${pay?.toJson()}");
      if (pay != null) {
        await widget.makePayment(pay);
        tec.clear();
        textNoteTec.clear();
        // await loadPayment(pay.id);
        // await loadInputsAndConsole();
        // widget.refreshMoneyPage();
      }
    }

    final satsString = "${formattedSats(asSats)} sat";
    final usdString = "${asUSD.toStringAsFixed(4)} \$";

    _console = Console(
      bottomInputs: [
        ConsoleInput(placeHolder: "(Text Note)", tec: textNoteTec)
      ],
      topButtons: [
        ConsoleButton(
            name: "-${currency == "USD" ? usdString : satsString}",
            onPress: confirmPayment),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadMainViewConsole),
        ConsoleButton(
          name: currency,
          isMode: true,
          onPress: () {
            rotateCurrency();
            loadConfirmationConsole(inputCurrency);
          },
        ),
      ],
    );
    setState(() {});
  }

  void loadImportConsole([List<Down4TXOUT>? utxos]) {
    ConsoleInput input;
    if (utxos == null) {
      input = ConsoleInput(placeHolder: "WIF / PK", tec: importTec);
    } else {
      final sats = utxos.fold<int>(0, (prev, utxo) => prev + utxo.sats.asInt);
      final ph = "Found ${formattedSats(sats)} sat";
      input = ConsoleInput(placeHolder: ph, tec: textNoteTec, activated: false);
    }

    void import() async {
      final payment =
          await g.wallet.importMoney(importTec.value.text, g.self.id);

      if (payment == null) return;
      g.wallet.parsePayment(g.self.id, payment);
      _extra = false;
      loadBalance();
      loadMainViewInput();
      if (widget.people.isEmpty) {
        loadEmptyViewConsole();
      } else {
        loadMainViewConsole();
      }
    }

    _console = Console(
      bottomInputs: [input],
      topButtons: [
        ConsoleButton(name: "Import", onPress: import),
      ],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () {
            _extra = false;
            if (widget.people.isEmpty) {
              loadEmptyViewConsole();
            } else {
              loadMainViewConsole();
            }
          },
        ),
        ConsoleButton(
          name: "Check",
          onPress: () async =>
              loadImportConsole(await checkPrivateKey(importTec.value.text)),
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      // initialPageIndex: g.curState.i,
      // onPageChange: (idx) => g.curState.i = idx,
      pages: [
        Down4Page(
            scrollController: scrollController0,
            staticList: true,
            title: "Money",
            list: palettes.toList(growable: false),
            console: _console!),
        Down4Page(
            onRefresh: () => loadMorePayments(20),
            title: "Status",
            list: _payments.values.toList().formatted(),
            console: _console!),
      ],
    );
  }
}
