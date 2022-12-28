import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:down4/src/down4_utility.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

class PaymentPage extends StatefulWidget {
  final User self;
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
  })  : paymentAsList = payment.toJsonList(),
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

  @override
  void initState() {
    super.initState();
    // loadQrs();
    loadQrsAsPaints();
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      listIndex = (listIndex + 1) % widget.paymentAsList.length;
      setState(() {});
    });
  }

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
                    child: Down4Qr(data: paymentData, dimension: qrDimension))
              ]))));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  double get qrDimension => Sizes.w - (Sizes.w * 0.08 * golden * 2);

  double get topPadding => Sizes.w - qrDimension * 2 * 1 / golden;

  late Console theConsole = Console(
    inputs: [input],
    topButtons: [
      ConsoleButton(name: "Ok", onPress: widget.ok),
    ],
    bottomButtons: [
      ConsoleButton(name: "Back", onPress: widget.back),
      ConsoleButton(
          name: "Send",
          onPress: () {
            final textNode = tec.value.text.isEmpty ? null : tec.value.text;
            final spender = widget.payment.txs.last.txsIn.first.spender;
            if (spender == widget.self.id) {
              final pr = r.PaymentRequest(
                sender: spender!,
                payment: widget.payment..textNote = textNode,
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
        title: sha1(widget.payment.txs.last.txID!.data).toBase58(),
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
  final Iterable<User> trueTargets;
  final User self;
  final List<Palette> transitioned;
  final void Function() back;
  final void Function(Down4Payment) makePayment, importMoney;
  final void Function(r.Request req) paymentRequest;
  final int pageIndex;
  final void Function(int) onPageChange;
  final double initialOffset;

  const MoneyPage({
    required this.importMoney,
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
  var emptyTec = TextEditingController();
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
    emptyTec.dispose();
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

  int get inputAsSatoshis {
    int amount;
    final numInput = num.parse(tec.value.text);
    if (currency == "Satoshis") {
      amount = method == "Split"
          ? numInput.round()
          : (numInput * widget.trueTargets.length).round();
    } else {
      amount = method == "Split"
          ? usdToSatoshis(numInput.toDouble())
          : usdToSatoshis(numInput.toDouble() * widget.trueTargets.length);
    }
    return amount;
  }

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
    if (raw != null) {
      final decodedRaw = jsonDecode(raw);
      scannedDataLength = decodedRaw["tot"];
      scannedData.putIfAbsent(decodedRaw["index"], () => decodedRaw["data"]);
      if (scannedData.length == scannedDataLength) {
        // we have all the data
        await scanner?.stop();
        var sortedData = <String>[];
        final sortedKeys = scannedData.keys.toList()..sort();
        for (final key in sortedKeys) {
          sortedData.add(scannedData[key]!);
        }
        final payment = Down4Payment.fromJsonList(sortedData);
        widget.wallet.parsePayment(widget.self, payment);
        loadEmptyViewConsole(false, false, true);
      }
    }
  }

  void loadMainViewInput([bool reload = false]) {
    _cachedMainViewInput = ConsoleInput(
      maxLines: 1,
      type: TextInputType.number,
      placeHolder: currency == "USD" ? usds + "\$" : satoshis + " sat",
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
      scanCallBack: scanning ? onScan : null,
      scanController: scanning ? scanner : null,
      inputs: [_cachedMainViewInput!],
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
      inputs: [_cachedMainViewInput!],
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
      topButtons: [
        ConsoleButton(name: "Bill", onPress: () => print("TODO")),
        ConsoleButton(
            name: "Pay", onPress: () => loadConfirmationConsole(currency)),
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
      final pay = widget.wallet.payUsers(
        widget.trueTargets.toList(growable: false),
        widget.self,
        Sats(inputAsSatoshis),
      );
      print("The pay: ${pay?.toJson()}");
      if (pay != null) widget.makePayment(pay);
    }

    final satsString = formattedSats(asSats);
    _console = Console(
      inputs: [
        ConsoleInput(
          placeHolder: currency == "USD"
              ? "${asUSD.toStringAsFixed(4)} \$"
              : "$satsString sat",
          tec: emptyTec,
          activated: false,
        ),
      ],
      topButtons: [
        ConsoleButton(name: "Confirm", onPress: confirmPayment),
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
      input = ConsoleInput(placeHolder: ph, tec: emptyTec, activated: false);
    }

    void import() async {
      final payment =
          await widget.wallet.importMoney(importTec.value.text, widget.self);

      if (payment == null) return;
      widget.importMoney(payment);
      if (widget.trueTargets.isEmpty) {
        loadEmptyViewConsole(false, false, true);
      } else {
        loadMainViewConsole(true);
      }
    }

    _console = Console(
      inputs: [input],
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
          palettes: palettes.toList(growable: false),
          console: _console!,
        ),
        Down4Page(
          title: "Status",
          palettes: widget.paymentAsPalettes,
          console: _console!,
        ),
      ],
    );
  }
}
