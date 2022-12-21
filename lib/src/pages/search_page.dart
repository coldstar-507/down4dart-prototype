import 'dart:async';

import 'package:camera/camera.dart';
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
  final User self;
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
      var node = User(
        id: data[0],
        firstName: data[1],
        lastName: data[2],
        neuter: Down4Keys.fromYouKnow(data[3]),
        messages: [],
        snips: [],
        children: [],
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
      inputs: [_consoleInputRef ?? consoleInput],
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

  String get qrData => [
        widget.self.id,
        widget.self.name,
        widget.self.lastName,
        widget.self.neuter.toYouKnow(),
      ].join("~");

  Widget get qr {
    final topPadding = Sizes.w * 0.08;
    final qrSize = Sizes.w - (topPadding * golden * 2);

    return Container(
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: topPadding),
      child: Down4Qr(data: qrData, dimension: qrSize),
    );
  }

  @override
  Widget build(BuildContext context) {
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
