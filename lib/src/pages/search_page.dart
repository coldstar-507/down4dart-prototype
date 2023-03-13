import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/types.dart';
import 'package:down4/src/data_objects.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../globals.dart';

import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/qr.dart';

class AddFriendPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "search";

  // final Self self;
  // final List<Palette> palettes;
  // final Future<bool> Function(List<String>) search;
  // final void Function(User node) putNodeOffline;
  final void Function(BaseNode) openNode;
  final void Function(List<Palette2>) forwardNodes;
  final void Function(Iterable<Palette2>) add;
  final void Function(BaseNode) onScan;
  final Future<void> Function(String) search;
  final void Function() back;

  const AddFriendPage({
    required this.openNode,
    required this.search,
    required this.onScan,
    required this.add,
    required this.back,
    required this.forwardNodes,
    Key? key,
  }) : super(key: key);

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  Console? _console;
  var tec = TextEditingController();
  CameraController? _cameraController;
  MobileScannerController? scanner;

  Future<List<ButtonsInfo2>> bGen(BaseNode node) async {
    return [
      ButtonsInfo2(
          asset: g.fifty,
          pressFunc: () => widget.openNode(node),
          rightMost: true)
    ];
  }

  Map<ID, Palette2> get searchs => g.vm.cv.cp.objects.cast();

  @override
  void initState() {
    super.initState();
    defaultConsole();
    // loadQr();
  }

  @override
  void dispose() {
    super.dispose();
    _cameraController?.dispose();
  }

  ConsoleInput get consoleInput {
    return ConsoleInput(
      maxLines: 1,
      tec: tec,
      placeHolder: "@search",
    );
  }

  String get qrData => [
        g.self.id,
        g.self.name,
        g.self.lastName,
        g.self.neuter.toYouKnow(),
      ].join("~");

  static double get qrDimension => g.sizes.w - (g.sizes.w * 0.08 * golden * 2);

  static double get qrTopGap => g.sizes.w - qrDimension * 2 * 1 / golden;

  Widget get qr {
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          SizedBox(height: qrTopGap),
          SizedBox.square(
            dimension: qrDimension,
            child: Down4Qr(data: qrData, dimension: qrDimension),
          ),
        ],
      ),
    );
  }

  void scanCallBack(Barcode bc, MobileScannerArguments? args) {
    if (bc.rawValue == null) return;
    final data = bc.rawValue!.split("~");
    if (data.length != 4) return;
    var node = User(
        id: data[0],
        firstName: data[1],
        lastName: data[2],
        neuter: Down4Keys.fromYouKnow(data[3]),
        messages: {},
        snips: {},
        children: {});
    widget.onScan(node);
  }

  void defaultConsole([scanning = false]) {
    if (scanning) {
      scanner = MobileScannerController();
    } else {
      scanner?.dispose();
      scanner = null;
    }
    _console = Console(
      scanner: !scanning
          ? null
          : MobileScanner(onDetect: scanCallBack, controller: scanner),
      bottomInputs: [consoleInput],
      topButtons: [
        ConsoleButton(
          name: "Add",
          onPress: () => widget.add(searchs.values.selected()),
        ),
        ConsoleButton(
            name: "Search",
            onPress: () async {
              await widget.search(tec.value.text);
              tec.clear();
            }),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(name: "Scan", onPress: () => defaultConsole(!scanning)),
        ConsoleButton(
          name: "Forward",
          onPress: () => widget.forwardNodes(
            searchs.values.selected().toList(),
          ),
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print("QR DATA LEN = ${qrData.length}");
    return Andrew(pages: [
      Down4Page(
          title: "Search",
          console: _console!,
          stackWidgets: [qr],
          list: searchs.values.toList())
    ]);
  }
}
