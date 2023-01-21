import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/down4_utility.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/types.dart';
import 'package:down4/src/data_objects.dart';
import 'package:down4/src/render_objects/render_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../boxes.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/qr.dart';

class AddFriendPage extends StatefulWidget {
  final Self self;
  final List<Palette> palettes;
  final Future<bool> Function(List<String>) search;
  final void Function(User node) putNodeOffline;
  final void Function(List<Palette>) addCallback, forwardNodes;
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
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  Console? _console;
  var tec = TextEditingController();
  CameraController? _cameraController;
  MobileScannerController? scanner;

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
        widget.self.id,
        widget.self.name,
        widget.self.lastName,
        widget.self.neuter.toYouKnow(),
      ].join("~");

  double get dimension => Sizes.w - (Sizes.w * 0.08 * golden * 2);

  Widget get qr => Align(
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            SizedBox(height: Sizes.w - dimension * 2 * 1 / golden),
            SizedBox.square(
              dimension: dimension,
              child: Down4Qr(data: qrData, dimension: dimension),
            ),
          ],
        ),
      );

  scanCallBack(Barcode bc, MobileScannerArguments? args) {
    if (bc.rawValue != null) {
      final data = bc.rawValue!.split("~");
      if (data.length != 4) return;
      var node = User(
        id: data[0],
        firstName: data[1],
        lastName: data[2],
        neuter: Down4Keys.fromYouKnow(data[3]),
        messages: {},
        snips: {},
        children: {},
      );
      widget.putNodeOffline(node);
    }
  }

  void defaultConsole([scanning = false]) {
    if (scanning) {
      scanner = MobileScannerController();
    } else {
      scanner?.dispose();
      scanner = null;
    }
    _console = Console(
      scanController: scanning ? scanner : null,
      scanCallBack: scanning ? scanCallBack : null,
      inputs: [consoleInput],
      topButtons: [
        ConsoleButton(
          name: "Add",
          onPress: () => widget.addCallback(
            widget.palettes.selected().toList(growable: false),
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
            widget.palettes.selected().toList(growable: false),
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
        palettes: widget.palettes,
      )
    ]);
  }
}
