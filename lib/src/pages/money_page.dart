import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_testproject/main.dart';
import 'package:flutter_testproject/src/down4_utility.dart';
import 'package:flutter_testproject/src/render_objects/utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data_objects.dart';
import '../web_requests.dart' as r;
import '../bsv/wallet.dart';
import '../bsv/types.dart';
import '../bsv/utils.dart';
import '../themes.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

class PaymentPage extends StatefulWidget {
  final void Function() back;
  final Down4Payment payment;
  final List<String> paymentList;

  PaymentPage({
    required this.back,
    required this.payment,
    Key? key,
  })  : paymentList = payment.toJsonList(),
        super(key: key);

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Timer? timer;
  int listIndex = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      listIndex = (listIndex + 1) % (widget.paymentList.length);
      setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget qr() => Container(
        padding: const EdgeInsets.only(top: 27, right: 44, left: 44),
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: QrImage(
            foregroundColor: PinkTheme.qrColor,
            data: widget.paymentList[listIndex],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Jeff(pages: [
      Down4Page(
        title: sha1(widget.payment.txs.last.txID!.data).toBase58(),
        stackWidgets: [qr()],
        console: Console(
          bottomButtons: [
            ConsoleButton(
              name: "Back",
              onPress: widget.back,
            ),
          ],
        ),
      ),
    ]);
  }
}

class MoneyPage extends StatefulWidget {
  final double exchangeRate;
  final Wallet wallet;
  final List<Palette> palettes, paymentAsPalettes;
  final User self;
  final void Function() back;
  final void Function(Down4Payment) parsePayment;
  final void Function(r.Request req) paymentRequest;
  final int pageIndex;
  final void Function(int) onPageChange;

  const MoneyPage({
    required this.wallet,
    required this.exchangeRate,
    required this.palettes,
    required this.paymentAsPalettes,
    required this.back,
    required this.self,
    required this.pageIndex,
    required this.onPageChange,
    required this.parsePayment,
    required this.paymentRequest,
    Key? key,
  }) : super(key: key);

  @override
  _MoneyPageState createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  var tec = TextEditingController();
  var importTec = TextEditingController();
  MobileScannerController? scanner;
  Console? _console;
  Map<int, String> scannedData = {};
  int scannedDataLength = -1;

  @override
  void initState() {
    super.initState();
    mainViewInput(true);
    if (widget.palettes.isEmpty) {
      emptyViewConsole();
    } else {
      mainViewConsole();
    }
  }

  @override
  void dispose() {
    tec.dispose();
    importTec.dispose();
    scanner?.dispose();
    super.dispose();
  }

  void startScan() {}

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

  String get usds => satoshisToUSD(widget.wallet.balance).toStringAsFixed(4);

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

  void mainViewInput([bool reload = false]) {
    _cachedMainViewInput = ConsoleInput(
      type: TextInputType.number,
      placeHolder: currency == "USD" ? usds + "\$" : satoshis + " sat",
      tec: tec,
    );
    if (reload) setState(() {});
  }

  void emptyViewConsole([
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

    mainViewInput(reloadInput);
    _console = Console(
      scanCallBack: scanning ? onScan : null,
      scanController: scanning ? scanner : null,
      inputs: scanning ? null : [_cachedMainViewInput!],
      topButtons: [
        ConsoleButton(
          name: "Scan",
          onPress: () => emptyViewConsole(!scanning),
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
              ? emptyViewConsole(scanning, !extraBack, reloadInput)
              : widget.back(),
          onLongPress: () =>
              emptyViewConsole(scanning, !extraBack, reloadInput),
          extraButtons: [
            ConsoleButton(
              name: "Import",
              onPress: importConsole,
            )
          ],
        ),
        ConsoleButton(
          isMode: true,
          name: currency,
          onPress: () {
            rotateCurrency();
            emptyViewConsole(scanning, extraBack, true);
          },
        ),
      ],
    );
    setState(() {});
  }

  void mainViewConsole([bool reloadInput = false, bool extra = false]) {
    mainViewInput(reloadInput);
    _console = Console(
      inputs: [_cachedMainViewInput!],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          isSpecial: true,
          showExtra: extra,
          onPress: () =>
              extra ? mainViewConsole(reloadInput, !extra) : widget.back(),
          onLongPress: () => mainViewConsole(reloadInput, !extra),
          extraButtons: [
            ConsoleButton(name: "Import", onPress: importConsole),
          ],
        ),
        ConsoleButton(
            name: method,
            isMode: true,
            onPress: () {
              rotateMethod();
              mainViewConsole();
            }),
        ConsoleButton(
            name: currency,
            isMode: true,
            onPress: () {
              rotateCurrency();
              mainViewConsole(tec.value.text.isEmpty ? true : false);
            }),
      ],
      topButtons: [
        ConsoleButton(name: "Bill", onPress: () => print("TODO")),
        ConsoleButton(
            name: "Pay", onPress: () => confirmationConsole(currency)),
      ],
    );

    setState(() {});
  }

  void confirmationConsole(String inputCurrency) {
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

    final satsString = formattedSats(asSats);

    _console = Console(
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
                widget.palettes.asNodes().toList(growable: false) as List<User>,
                widget.self,
                Sats(inputAsSatoshis),
              );
              if (pay != null) {
                for (final tx in pay.txs) {
                  printWrapped("=================");
                  printWrapped(tx.fullRawHex);
                  printWrapped("=================");
                  printWrapped(tx.txID!.asHex);
                  printWrapped("=================");
                }
                widget.parsePayment(pay);
                printWrapped("pay: ${pay.toYouKnow()}###\n###");
                print("ID: ${sha256(utf8.encode(pay.toYouKnow())).toHex()}");
                print("txid: ${pay.txs.last.txID!.asHex}");
                if (widget.palettes.isEmpty) {
                  emptyViewConsole(false, false, true);
                } else {
                  mainViewConsole(true);
                }
              }
            }),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: mainViewConsole),
        ConsoleButton(
          name: currency,
          isMode: true,
          onPress: () {
            rotateCurrency();
            confirmationConsole(inputCurrency);
          },
        ),
      ],
    );

    setState(() {});
  }

  void importConsole([List<Down4TXOUT>? utxos]) {
    ConsoleInput input;
    if (utxos == null) {
      input = ConsoleInput(placeHolder: "WIF / PK", tec: importTec);
    } else {
      final sats = utxos.fold<int>(0, (prev, utxo) => prev + utxo.sats.asInt);
      final ph = "Found " + formattedSats(sats) + " sat";
      input = ConsoleInput(placeHolder: ph, tec: importTec, activated: false);
    }

    void import() async {
      final payment =
          await widget.wallet.importMoney(importTec.value.text, widget.self);

      if (payment == null) return;

      widget.parsePayment(payment);
      if (widget.palettes.isEmpty) {
        emptyViewConsole(false, false, true);
      } else {
        mainViewConsole(true);
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
          onPress: () =>
              widget.palettes.isEmpty ? emptyViewConsole() : mainViewConsole(),
        ),
        ConsoleButton(
          name: "Check",
          onPress: () async =>
              importConsole(await checkPrivateKey(importTec.value.text)),
        ),
      ],
    );

    setState(() {});
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
        emptyViewConsole(false, false, true);
      }
    }
  }

  void rotateCurrency() {
    _currencies["i"] =
        (_currencies["i"] + 1) % (_currencies["l"] as List<String>).length;
  }

  @override
  Widget build(BuildContext context) {
    print("Initial page:${widget.pageIndex}");
    return Andrew(
      initialPageIndex: widget.pageIndex,
      onPageChange: widget.onPageChange,
      pages: [
        Down4Page(
          title: "Money",
          palettes: widget.palettes,
          console: _console!,
        ),
        Down4Page(
          title: "Status",
          palettes: widget.paymentAsPalettes,
          console: _console!,
        ),
      ],
    );

    // if (_view == null) widget.palettes.isEmpty ? emptyMainView() : mainView();
    // return _view!;
  }
}
