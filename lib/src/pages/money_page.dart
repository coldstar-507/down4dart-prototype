import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data_objects.dart';
import '../bsv/wallet.dart';
import '../bsv/types.dart';
import '../bsv/utils.dart';
import '../themes.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

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
  var importTec = TextEditingController();

  @override
  void dispose() {
    tec.dispose();
    importTec.dispose();
    super.dispose();
  }

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

  void importView([List<Down4TXOUT>? utxos]) {
    ConsoleInput input;
    if (utxos == null) {
      input = ConsoleInput(placeHolder: "WIF / PK", tec: importTec);
    } else {
      final sats = utxos.fold<int>(0, (prev, utxo) => prev + utxo.sats.asInt);
      final ph = "Found " + formattedSats(sats) + " sat";
      input = ConsoleInput(placeHolder: ph, tec: importTec, activated: false);
    }

    final importViewConsole = Console(
      inputs: [input],
      topButtons: [
        ConsoleButton(
            name: "Import",
            onPress: () async {
              // final pay = await widget.wallet
              //     .importMoney(widget.self, importTec.value.text);
              // if (pay != null) {
              //   widget.wallet.parsePayment(widget.self, pay);
              // }
            })
      ],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () => widget.palettes.isEmpty ? emptyMainView() : mainView(),
        ),
        ConsoleButton(
          name: "Check",
          onPress: () async => importView(await checkPrivateKey(importTec.value.text)),
        ),
      ],
    );

    _view = Jeff(pages: [
      Down4Page(
        title: "Money",
        console: importViewConsole,
        palettes: widget.palettes,
      )
    ]);

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

    final emptyViewConsole = Console(
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
          widthEpsilon: 0.5,
          heightEpsilon: 0.5,
          bottomEpsilon: -0.5,
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
    );

    _view = Jeff(pages: [Down4Page(title: "Money", console: emptyViewConsole)]);

    setState(() {});
  }

  void mainView([bool reloadInput = false, bool extraBack = false]) {
    final mainViewConsole = Console(
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
    );

    _view = Jeff(pages: [
      Down4Page(
        title: "Money",
        palettes: widget.palettes,
        console: mainViewConsole,
      )
    ]);

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

    final confirmationViewConsole = Console(
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
              // final pay = widget.wallet.payUsers(
              //   widget.palettes.map((p) => p.node).toList(),
              //   widget.self,
              //   Sats(inputAsSatoshis),
              // );
              // if (pay != null) {
              //   widget.wallet.trySettlement();
              //   transactedView(pay);
              // }
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
    );

    _view = Jeff(pages: [
      Down4Page(
        title: "Money",
        console: confirmationViewConsole,
        palettes: widget.palettes,
      )
    ]);

    if (reload) setState(() {});
  }

  void transactedView(Down4Payment pay, [int i = 0, bool reload = true]) {
    Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => transactedView(pay, (i + 1) % pay.txs.length),
    );

    final paymentWidget = Positioned(
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
    );

    final transactedViewConsole = Console(bottomButtons: [
      ConsoleButton(name: "Done", onPress: widget.back),
    ]);

    _view = Jeff(pages: [
      Down4Page(
          title: "Money",
          console: transactedViewConsole,
          stackWidgets: [paymentWidget]),
    ]);

    if (reload) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_view == null) widget.palettes.isEmpty ? emptyMainView() : mainView();
    return _view!;
  }
}
