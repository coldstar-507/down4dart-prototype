import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/bsv/types.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:flutter_testproject/src/render_objects/render_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../themes.dart';
import '../boxes.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

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

  Widget get qr => Align(
        alignment: AlignmentDirectional.topCenter,
        child: Container(
          padding: EdgeInsets.only(
            top: ((Sizes.w - (Sizes.w * (1 / golden))) / 2) * (1 / golden),
          ),
          child: QrImage(
            size: Sizes.w * (1 / golden),
            foregroundColor: PinkTheme.qrColor,
            data: [
              widget.self.id,
              widget.self.name,
              widget.self.lastName,
              widget.self.neuter.toYouKnow(),
            ].join("~"),
          ),
        ),
      );

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
