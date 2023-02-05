import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:base85/base85.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/down4_utility.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr/qr.dart';

import '../data_objects.dart';
import '../web_requests.dart' as r;
import '../bsv/wallet.dart';
import '../bsv/types.dart';
import '../bsv/utils.dart';
import '../boxes.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/qr.dart';

final base85 = Base85Codec(Alphabets.z85);

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

class PaymentPage extends StatefulWidget {
  final Self self;
  final void Function() back, ok;
  final Down4Payment payment;
  final List<String> paymentAsList;
  final void Function(r.PaymentRequest) paymentRequest;

  PaymentPage({
    required this.self,
    required this.ok,
    required this.back,
    required this.payment,
    required this.paymentRequest,
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

  // Future<void> loadQrs() async {
  //   if (widget.payment.qrPngs != null) {
  //     qrs2 = widget.payment.qrPngs!
  //         .map((e) => Align(
  //             alignment: Alignment.topCenter,
  //             child: Column(children: [
  //               SizedBox(height: topPadding),
  //               SizedBox.square(
  //                   dimension: qrDimension,
  //                   child: Image.memory(e,
  //                       height: qrDimension, width: qrDimension))
  //             ])))
  //         .toList(growable: false);
  //   } else {
  //     widget.payment.qrPngs = widget.paymentAsList
  //         .map((e) async =>
  //             await Down4Qr2(data: e, dimension: qrDimension).asImage())
  //         .whereType<Uint8List>()
  //         .toList(growable: false);
  //
  //     widget.payment.save();
  //
  //     qrs2 = widget.payment.qrPngs!
  //         .map((e) => Align(
  //             alignment: Alignment.topCenter,
  //             child: Column(children: [
  //               SizedBox(height: topPadding),
  //               SizedBox.square(
  //                   dimension: qrDimension,
  //                   child: Image.memory(e,
  //                       height: qrDimension, width: qrDimension))
  //             ])))
  //         .toList(growable: false);
  //   }
  //   setState(() {
  //     startTimer();
  //   });
  // }

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

  double get qrDimension => Sizes.w - (Sizes.w * 0.08 * golden * 2);

  double get topPadding => Sizes.w - qrDimension * 2 * 1 / golden;

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
                if (spender == widget.self.id) {
                  final pr = r.PaymentRequest(
                    sender: spender!,
                    payment: widget.payment,
                    targets: widget.payment.txs.last.txsOut
                        .where((txout) => txout.isGets)
                        .map((txout) => txout.receiver)
                        .whereType<String>()
                        .toList(growable: false),
                  );
                  widget.paymentRequest(pr);
                  widget.ok();
                }
              })
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        title: sha1(widget.payment.txs.last.txID.data).toBase58(),
        // stackWidgets: qrs2.isNotEmpty ? [qrs2[listIndex]] : null,
        stackWidgets: qrs.map((e) => e(listIndex)).toList(growable: false),
        console: theConsole,
      )
    ]);
  }
}

class MoneyPage extends StatefulWidget {
  final double exchangeRate;
  final Wallet wallet;
  final List<Palette> paymentAsPalettes;
  final Iterable<Palette> homePalettes;
  final Iterable<Person> trueTargets;
  final Self self;
  final List<Palette> transitioned;
  final void Function() back;
  final void Function(Down4Payment) makePayment, scanOrImport;
  final void Function(r.Request req) paymentRequest;
  final int pageIndex;
  final void Function(int) onPageChange;
  final double initialOffset;

  const MoneyPage({
    required this.scanOrImport,
    required this.trueTargets,
    required this.transitioned,
    required this.wallet,
    required this.exchangeRate,
    required this.homePalettes,
    required this.paymentAsPalettes,
    required this.back,
    required this.self,
    required this.pageIndex,
    required this.onPageChange,
    required this.makePayment,
    required this.paymentRequest,
    required this.initialOffset,
    Key? key,
  }) : super(key: key);

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
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
  late var palettes = widget.homePalettes;
  late var scrollController =
      ScrollController(initialScrollOffset: widget.initialOffset);

  @override
  void initState() {
    super.initState();
    loadMainViewInput(true);
    if (widget.trueTargets.isEmpty) {
      loadEmptyViewConsole();
    } else {
      loadMainViewConsole();
    }

    delayed();
  }

  Future<void> delayed() async {
    Future(() {
      palettes = widget.transitioned;
      scrollController.animateTo(0,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      setState(() {});
    });
  }

  @override
  void dispose() {
    tec.dispose();
    importTec.dispose();
    textNoteTec.dispose();
    scanner?.dispose();
    scrollController.dispose();
    super.dispose();
  }

  int usdToSatoshis(double usds) =>
      ((usds / widget.exchangeRate) * 100000000).floor();

  double satoshisToUSD(int satoshis) =>
      (satoshis / 100000000) * widget.exchangeRate;

  String get satoshis => widget.wallet.balance.toString();

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

  String get usds => satoshisToUSD(widget.wallet.balance).toStringAsFixed(4);

  String get currency => _currencies["l"][_currencies["i"]] as String;

  String get method => _paymentMethod["l"][_paymentMethod["i"]] as String;

  // int get inputAsSatoshis {
  //   int amount;
  //   final numInput = num.parse(tec.value.text);
  //   if (currency == "Satoshis") {
  //     amount = method == "Split"
  //         ? numInput.round()
  //         : (numInput * widget.trueTargets.length).round();
  //   } else {
  //     amount = method == "Split"
  //         ? usdToSatoshis(numInput.toDouble())
  //         : usdToSatoshis(numInput.toDouble() * widget.trueTargets.length);
  //   }
  //   return amount;
  // }

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
        widget.scanOrImport(payment);
        print("Parsing the payment!");
        scannedData = {};
        scannedDataLength = -1;
        loadEmptyViewConsole(false, false, true);
      }
    }
  }

  void loadMainViewInput([bool reload = false]) {
    _cachedMainViewInput = ConsoleInput(
      maxLines: 1,
      type: TextInputType.number,
      placeHolder: currency == "USD"
          ? "$usds \$"
          : "${formattedSats(widget.wallet.balance)} sat",
      tec: tec,
    );
    if (reload) setState(() {});
  }

  void loadEmptyViewConsole([
    bool scanning = false,
    bool extraBack = false,
    bool reloadInput = false,
  ]) {
    if (scanning) {
      scanner = MobileScannerController();
    } else {
      scanner?.dispose();
      scanner = null;
    }
    loadMainViewInput(reloadInput);
    _console = Console(
      scanner: !scanning
          ? null
          : MobileScanner(onDetect: onScan, controller: scanner),
      // scanCallBack: scanning ? onScan : null,
      // scanController: scanning ? scanner : null,
      bottomInputs: [_cachedMainViewInput!],
      topButtons: [
        ConsoleButton(
          name: "Scan",
          onPress: () => loadEmptyViewConsole(!scanning),
        )
      ],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          isSpecial: true,
          widthEpsilon: 0.5,
          heightEpsilon: 0.5,
          bottomEpsilon: -0.5,
          showExtra: extraBack,
          onPress: () => extraBack
              ? loadEmptyViewConsole(scanning, !extraBack, reloadInput)
              : widget.back(),
          onLongPress: () =>
              loadEmptyViewConsole(scanning, !extraBack, reloadInput),
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
            loadEmptyViewConsole(scanning, extraBack, true);
          },
        ),
      ],
    );
    setState(() {});
  }

  void loadMainViewConsole([bool reloadInput = false, bool extra = false]) {
    loadMainViewInput(reloadInput);
    _console = Console(
      bottomInputs: [_cachedMainViewInput!],
      topButtons: [
        ConsoleButton(name: "Bill", onPress: () => print("TODO")),
        ConsoleButton(
            name: "Pay",
            onPress: () {
              if (tec.value.text.isNotEmpty) loadConfirmationConsole(currency);
            }),
      ],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          isSpecial: true,
          showExtra: extra,
          onPress: () =>
              extra ? loadMainViewConsole(reloadInput, !extra) : widget.back(),
          onLongPress: () => loadMainViewConsole(reloadInput, !extra),
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
              loadMainViewConsole(tec.value.text.isEmpty ? true : false);
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
          (method == "Split" ? 1.0 : widget.trueTargets.length);
      asSats = usdToSatoshis(asUSD);
    } else {
      asSats = num.parse(tec.value.text).toInt() *
          (method == "Split" ? 1 : widget.trueTargets.length);
      asUSD = satoshisToUSD(asSats);
    }

    void confirmPayment() {
      final pay = widget.wallet.payPeople(
        people: widget.trueTargets.toList(growable: false),
        selfID: widget.self.id,
        amount: Sats(asSats),
        textNote: textNoteTec.value.text,
      );
      // print("The pay: ${pay?.toJson()}");
      if (pay != null) widget.makePayment(pay);
    }

    final satsString = "${formattedSats(asSats)} sat";
    final usdString = "${asUSD.toStringAsFixed(4)} \$";

    _console = Console(
      bottomInputs: [
        ConsoleInput(placeHolder: "(Text Note)", tec: textNoteTec)
        // ConsoleInput(
        //   placeHolder: currency == "USD"
        //       ? "${asUSD.toStringAsFixed(4)} \$"
        //       : "$satsString sat",
        //   tec: emptyTec,
        //   activated: false,
        // ),
      ],
      topButtons: [
        ConsoleButton(
          name: "-${currency == "USD" ? usdString : satsString}",
          onPress: confirmPayment,
        ),
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
          await widget.wallet.importMoney(importTec.value.text, widget.self.id);

      if (payment == null) return;
      widget.scanOrImport(payment);
      if (widget.trueTargets.isEmpty) {
        loadEmptyViewConsole(false, false, true);
      } else {
        loadMainViewConsole(true);
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
          onPress: () => widget.trueTargets.isEmpty
              ? loadEmptyViewConsole()
              : loadMainViewConsole(),
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
      initialPageIndex: widget.pageIndex,
      onPageChange: widget.onPageChange,
      pages: [
        Down4Page(
          scrollController: scrollController,
          staticList: true,
          title: "Money",
          list: palettes.toList(growable: false),
          console: _console!,
        ),
        Down4Page(
          title: "Status",
          list: widget.paymentAsPalettes,
          console: _console!,
        ),
      ],
    );
  }
}
