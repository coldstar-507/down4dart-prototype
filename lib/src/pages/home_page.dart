import 'package:flutter/material.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:video_player/video_player.dart';

import '../_dart_utils.dart';
import '../data_objects.dart';

import '../render_objects/_render_utils.dart';
import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '../globals.dart';

import '_page_utils.dart';

class HomePage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "home";
  final String? promptMessage;
  final ViewState homeState;
  // final List<Palette2> palettes;
  final void Function(String text) ping;
  final void Function(Chatable, List<FireObject>)
      openChat; // TODO what is this?
  final void Function(Payload, Iterable<Chatable>) send;
  final void Function(List<Palette2>) forward;
  final void Function() hyperchat, themes;
  final void Function() group, money, search, delete, snip;
  const HomePage({
    required this.themes,
    required this.homeState,
    required this.hyperchat,
    required this.group,
    required this.money,
    required this.snip,
    required this.ping,
    required this.search,
    required this.delete,
    required this.send,
    required this.openChat,
    required this.forward,
    this.promptMessage,
    Key? key,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with
        WidgetsBindingObserver,
        Pager2,
        Sender2,
        Input2,
        Medias2,
        Camera2,
        Forwarder2,
        Compose2,
        Hyper2,
        Money2 {
  late String placeHolder = widget.promptMessage ?? ":)";

  late ScrollController scroller =
      ScrollController(initialScrollOffset: widget.homeState.currentPage.scroll)
        ..addListener(() {
          widget.homeState.currentPage.scroll = scroller.offset;
        });

  @override
  void setTheState() => setState(() {});

  // ConsoleInput get input => ConsoleInput(
  //       // prefixIcons: const [
  //       //   IconButton(
  //       //     padding: EdgeInsets.symmetric(vertical: 4),
  //       //     onPressed: null,
  //       //     icon: const Icon(Icons.keyboard_arrow_right_rounded),
  //       //   )
  //       // ],
  //       suffixIcons: const [
  //         IconButton(
  //           padding: EdgeInsets.symmetric(vertical: 4),
  //           onPressed: null,
  //           icon: Icon(Icons.filter_alt),
  //         )
  //       ],
  //       tec: _tec,
  //       placeHolder: "",
  //     );

  Map<ID, Palette2> get palettes => widget.homeState.currentPage.objects.cast();

  // @override
  // void initState() {
  //   super.initState();
  //   if (widget.promptMessage != null) {
  //     Future.delayed(const Duration(seconds: 2), () {
  //       placeHolder = ":)";
  //       loadBaseConsole();
  //     });
  //   }
  //   loadBaseConsole();
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scroller.dispose();
    super.dispose();
  }

  // final _tec = TextEditingController();

  // void ping() {
  //   if (_tec.value.text.isEmpty) return;
  //   widget.ping(_tec.value.text);
  //   _tec.clear();
  // }

  // @override
  // void loadBaseConsole({bool extra = false}) {
  //   console = Console(
  //     // bottomInputs: [
  //     //   const SizedBox(width: 20),
  //     //   IconButton(
  //     //       padding: const EdgeInsets.all(4),
  //     //       onPressed: loadMediasConsole,
  //     //       color: g.theme.buttonTextColor,
  //     //       icon: const Icon(Icons.qr_code_outlined),
  //     //       constraints: BoxConstraints(maxHeight: Console.buttonHeight)),
  //     //   // IconButton(
  //     //   //     padding: const EdgeInsets.all(4),
  //     //   //     onPressed: loadMediasConsole,
  //     //   //     color: g.theme.buttonTextColor,
  //     //   //     icon: const Icon(Icons.image_outlined),
  //     //   //     constraints: BoxConstraints(maxHeight: Console.buttonHeight)),
  //     //   input,
  //     //   IconButton(
  //     //       padding: const EdgeInsets.all(4),
  //     //       onPressed: loadMediasConsole,
  //     //       color: g.theme.buttonTextColor,
  //     //       icon: const Icon(Icons.image_outlined),
  //     //       constraints: BoxConstraints(maxHeight: Console.buttonHeight)),
  //     //   IconButton(
  //     //       padding: const EdgeInsets.all(4),
  //     //       onPressed: loadSquaredCameraConsole,
  //     //       color: g.theme.buttonTextColor,
  //     //       icon: const Icon(Icons.camera_outlined),
  //     //       constraints: BoxConstraints(maxHeight: Console.buttonHeight)),
  //     //   const SizedBox(width: 20),
  //     // ],
  //     // topButtons: [
  //     //
  //     // ],
  //     bottomButtons: [
  //       ConsoleButton(
  //           showExtra: extra,
  //           name: "GROUP",
  //           onPress: () =>
  //               extra ? loadBaseConsole(extra: !extra) : widget.group(),
  //           isSpecial: true,
  //           onLongPress: () => loadBaseConsole(extra: !extra),
  //           extraButtons: [
  //             ConsoleButton(name: "DELETE", onPress: widget.delete),
  //             ConsoleButton(name: "MEDIAS", onPress: loadMediasConsole),
  //             ConsoleButton(
  //                 name: cameraInput == null ? "CAMERA" : "@CAMERA",
  //                 onPress: loadSquaredCameraConsole),
  //             ConsoleButton(
  //                 name: "FORWARD",
  //                 onPress: () => widget.forward(
  //                       palettes.values.selected().toList(),
  //                     )),
  //             ConsoleButton(name: "SEND", onPress: send)
  //           ]),
  //       ConsoleButton(name: "HYPER", onPress: () => widget.hyperchat()),
  //       ConsoleButton(name: "MONEY", onPress: widget.money),
  //       // ConsoleButton(name: "Search", onPress: widget.search),
  //       ConsoleButton(
  //           name: "PING",
  //           onPress: ping,
  //           onLongPress: widget.snip,
  //           isSpecial: true),
  //     ],
  //     // consoleRow: Console3(widgets: [
  //     //
  //     // ]),
  //   );
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      addFriends: widget.search,
      themes: widget.themes,
      pages: [
        Down4Page(
            scrollController: scroller,
            staticList: true,
            title: "Down4",
            trueLen: palettes.length,
            list: palettes.values.toList().formatted(),
            console: console)
      ],
    );
  }

  // @override
  // VideoPlayerController? videoPreview;

  // @override
  // void changeConsole(String c) {
  //   groupExtraButton = false;
  //   extraCloseButton = false;
  //   currentConsolesName[currentPageIndex] = c;
  //   print(currentConsolesName);
  //   setState(() {});
  // }

  ConsoleButton get groupButton =>
      ConsoleButton(name: "GROUP", onPress: widget.group)
          .withExtra(extraGroup, [
        ConsoleButton(name: "DELETE", onPress: widget.delete),
        ConsoleButton(
            name: "FORWARD",
            onPress: () => widget.forward(
                  palettes.values.selected().toList(),
                )),
        ConsoleButton(name: "COMPOSE", onPress: () => changeConsole("compose")),
      ]);

  ConsoleButton get closeButton =>
      ConsoleButton(name: "CLOSE", onPress: () => changeConsole("home"))
          .withExtra(extraClose, [cameraButton]);

  ConsoleButton get snipButton =>
      ConsoleButton(name: "SNIP", onPress: widget.snip);

  @override
  Console3 get console => Console3(
          rows: [
            {
              "home": ConsoleRow(
                widgets: [groupButton, hyperButton, moneyButton, snipButton],
                extension: null,
                widths: null,
                inputMaxHeight: null,
              ),
              "compose": ConsoleRow(
                widgets: [
                  closeButton,
                  mediasButton,
                  input.consoleInput,
                  sendButton
                ],
                extension: null,
                widths: hasFocus ? [0.0, 0.2, 0.6, 0.2] : null,
                inputMaxHeight: hasFocus ? input.height : Console.buttonHeight,
              ),
              basicMediaRowName: basicMediasRow,
              basicCameraRowName: basicCameraRow,
              cameraConfirmationRowName: cameraConfirmationRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  List<(String, void Function(FireMedia))> get mediasMode => [
        (
          "SEND",
          (m) async {
            await m.use();
            send(mediaInput: m);
          }
        ),
        (
          "REMOVE",
          (m) {
            m.updateSaveStatus(false);
            setTheState();
          }
        ),
      ];

  @override
  Future<void> send({FireMedia? mediaInput}) async {
    final p = Payload(
        replies: [],
        forwards: [],
        text: input.value,
        media: mediaInput ?? cameraInput,
        isSnip: false);

    widget.send(p, palettes.values.selected().asNodes<Chatable>());
    input.clear();
  }

  @override
  String get backFromCameraConsoleName => "compose";

  @override
  String get backFromMediasConsoleName => "compose";

  @override
  List<String> currentConsolesName = ["home"];

  @override
  int get currentPageIndex => 0;

  @override
  void hyper() => widget.hyperchat();

  @override
  void money() => widget.money();

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
    ),
  ];

  Extra get extraGroup => extras[0];
  Extra get extraClose => extras[1];

  @override
  late List<Extra> extras = [
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
  ];

  @override
  void forward() {
    widget.forward(palettes.values.toList());
  }
}
