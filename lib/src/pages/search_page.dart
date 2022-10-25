import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/bsv/types.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../themes.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class AddFriendPage extends StatefulWidget {
  final Node self;
  final List<Palette> palettes;
  final Future<bool> Function(List<String>) search;
  final void Function(Node node) putNodeOffline;
  final void Function(List<Node>) addCallback, forwardNodes;
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
      var node = Node(
        type: Nodes.user,
        id: data[0],
        name: data[1],
        lastName: data[2],
        neuter: Down4Keys.fromYouKnow(data[3]),
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
      inputs: !scanning ? [_consoleInputRef ?? consoleInput] : null,
      topButtons: [
        ConsoleButton(
          name: "Add",
          onPress: () => widget.addCallback(
            widget.palettes
                .where((element) => element.selected)
                .map((e) => e.node)
                .toList(),
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
            widget.palettes
                .where((p) => p.selected)
                .map((p) => p.node)
                .toList(),
          ),
        ),
      ],
    );
    setState(() {});
  }

  Widget get qr => Container(
        padding: const EdgeInsets.only(top: 27, right: 44, left: 44),
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: QrImage(
            foregroundColor: PinkTheme.qrColor,
            data: [
              widget.self.id,
              widget.self.name,
              widget.self.lastName,
              widget.self.neuter!.toYouKnow(),
            ].join("~"),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Jeff(pages: [
      Down4Page(
        title: "Search",
        console: _console!,
        stackWidgets: [qr],
        palettes: widget.palettes,
      )
    ]);
  }
}
