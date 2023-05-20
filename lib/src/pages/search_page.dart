import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/types.dart';
import 'package:down4/src/data_objects.dart';
import 'package:down4/src/couch.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../globals.dart';

import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/qr.dart';
import '_page_utils.dart';

class AddFriendPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "search";

  final ViewState viewState;
  final void Function(Branchable) openNode;
  final void Function(List<Palette2>) forwardNodes;
  final void Function(Iterable<Personable>) add;
  final void Function(FireNode) onScan;
  final Future<void> Function(String) search;
  final void Function() back;

  const AddFriendPage({
    required this.viewState,
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

class _AddFriendPageState extends State<AddFriendPage>
    with WidgetsBindingObserver, Pager2, Input2, Scanner2 {
  // Console? _console;
  // var tec = TextEditingController();
  // CameraController? _cameraController;
  // MobileScannerController? scanner;

  Future<List<ButtonsInfo2>> bGen(Branchable b) async {
    return [
      ButtonsInfo2(
        asset: g.fifty,
        pressFunc: () => widget.openNode(b),
        rightMost: true,
      )
    ];
  }

  Map<ID, Palette2> get searchs => widget.viewState.currentPage.objects.cast();

  // @override
  // void initState() {
  //   super.initState();
  //   // defaultConsole();
  //   // loadQr();
  // }

  // @override
  // void dispose() {
  //   super.dispose();
  //   _cameraController?.dispose();
  // }

  // ConsoleInput get consoleInput {
  //   return ConsoleInput(
  //     maxLines: 1,
  //     tec: tec,
  //     placeHolder: "@search",
  //   );
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeScanner();
    super.dispose();
  }

  String get qrData => [
        g.self.id,
        g.self.firstName,
        g.self.lastName,
        g.self.mediaID,
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

  @override
  void onScan(Barcode bc, MobileScannerArguments? args) async {
    if (bc.rawValue == null) return;
    final data = bc.rawValue!.split("~");
    if (data.length != 5) return;
    final localUser = await global<User>(data[0]);
    final node = localUser ??
        User(data[0],
            name: data[1],
            lastName: data[2],
            mediaID: data[3],
            neuter: Down4Keys.fromYouKnow(data[4]),
            publics: {},
            activity: makeTimestamp(),
            isFriend: false,
            description: "");
    widget.onScan(node);
  }

  ConsoleButton get searchButton => ConsoleButton(
      name: "SEARCH",
      onPress: () async {
        await widget.search(input.value);
        input.clear();
        setTheState();
      });

  ConsoleButton get addButton => ConsoleButton(
        name: "ADD",
        onPress: () => widget.add(
          searchs.values.selected().asNodes<Personable>(),
        ),
      );

  ConsoleButton get forwardButton => ConsoleButton(
      name: "FORWARD",
      onPress: () => widget.forwardNodes(searchs.values.selected().toList()));

  // void defaultConsole([scanning = false]) {
  //   if (scanning) {
  //     scanner = MobileScannerController();
  //   } else {
  //     scanner?.dispose();
  //     scanner = null;
  //   }
  //   _console = Console(
  //     scanner: !scanning
  //         ? null
  //         : MobileScanner(onDetect: scanCallBack, controller: scanner),
  //     bottomInputs: [consoleInput],
  //     topButtons: [
  //       ConsoleButton(
  //         name: "Add",
  //         onPress: () => widget.add(
  //           searchs.values.selected().asNodes<Personable>(),
  //         ),
  //       ),
  //       ConsoleButton(
  //           name: "Search",
  //           onPress: () async {
  //             await widget.search(tec.value.text);
  //             tec.clear();
  //           }),
  //     ],
  //     bottomButtons: [
  //       ConsoleButton(name: "Back", onPress: widget.back),
  //       ConsoleButton(name: "Scan", onPress: () => defaultConsole(!scanning)),
  //       ConsoleButton(
  //         name: "Forward",
  //         onPress: () => widget.forwardNodes(
  //           searchs.values.selected().toList(),
  //         ),
  //       ),
  //     ],
  //   );
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    print("QR DATA LEN = ${qrData.length}");
    return Andrew(backButton: backArrow(back: widget.back), pages: [
      Down4Page(
          title: "Search",
          console: console,
          stackWidgets: [qr],
          list: searchs.values.toList())
    ]);
  }

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(
                  widgets: [
                    scanButton.withExtra(scanExtra, [forwardButton]),
                    addButton,
                    input.widget,
                    searchButton,
                  ],
                  extension: scanning ? (scanExtension, g.sizes.w) : null,
                  widths: input.hasFocus ? [0.0, 0.2, 0.6, 0.2] : null,
                  inputMaxHeight: input.height)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  late List<Extra> extras = [Extra(setTheState: setTheState)];

  Extra get scanExtra => extras[0];

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
        onInput: onInput,
        config: Input2.singleLine,
        ctrl: InputController(placeHolder: "@username ..."),
        onFocusChange: onFocusChange),
  ];

  @override
  void setTheState() => setState(() {});
}
