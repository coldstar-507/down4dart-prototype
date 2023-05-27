import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:video_player/video_player.dart';
// import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../_dart_utils.dart';
import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '_page_utils.dart';

class ChatPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "chat-${viewState.node!.id}";

  final ViewState viewState;
  final List<Down4Object>? fo;
  final void Function(int) onPageChange;
  final void Function() back, add, money, hyper;
  final Future<void> Function([int limit]) loadMore;
  final void Function(Branchable) openNode;
  final void Function(Payload) send;
  final void Function(List<Down4Object> fo) forward;

  const ChatPage({
    required this.add,
    required this.money,
    required this.hyper,
    required this.viewState,
    required this.loadMore,
    required this.onPageChange,
    required this.back,
    required this.send,
    required this.openNode,
    required this.forward,
    this.fo,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with
        WidgetsBindingObserver,
        Pager2,
        Input2,
        Camera2,
        Medias2,
        Sender2,
        Add2,
        Hyper2,
        Money2,
        ForwardSender2,
        Saver2,
        Forwarder2
// Sender,
// Forwarder,
// SingleTickerProviderStateMixin,

{
  // Future<bool> keyboardIsHidden() {
  //   return Future.delayed(const Duration(milliseconds: 200),
  //       () => MediaQuery.of(context).viewInsets.bottom <= 0);
  // }

  // @override
  // Future<void> focusRoutine() async {
  //   print("DOING FOCUS ROUTINE!");
  //   if (hasFocus && await keyboardIsHidden()) {
  //     print("REMOVEING FOCUS");
  //     removeFocus();
  //     // focusNode.unfocus();
  //     showForwardButtonExtra = false;
  //     showMediaButtonExtra = false;
  //     setState(() {});
  //   }
  // }

  // @override
  // void didChangeMetrics() async {
  //   focusRoutine();
  // }

  // GlobalKey mediaModeKey = GlobalKey();
  // GlobalKey mediaForwardModeKey = GlobalKey();

  Chatable get node => widget.viewState.node as Chatable;
  List<ID> get orderedChats => widget.viewState.chat?.first ?? [];

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
            setState(() {});
            // loadBaseConsole();
            // loadMediasConsole(!m.isVideo, true);
          }
        ),
      ];
  // @override
  // ID get selfID => g.self.id;
  @override
  List<Down4Object>? get fo => widget.fo;
  @override
  void setTheState() => setState(() {});

  // @override
  // late Console console;
  // final _tec = TextEditingController();

  late ScrollController scroller0 =
      ScrollController(initialScrollOffset: widget.viewState.pages[0].scroll)
        ..addListener(() {
          widget.viewState.pages[0].scroll = scroller0.offset;
        });

  late ScrollController? scroller1 = node is Groupable
      ? (ScrollController(initialScrollOffset: widget.viewState.pages[1].scroll)
        ..addListener(() {
          widget.viewState.pages[1].scroll = scroller1!.offset;
        }))
      : null;

  // @override
  // late final aCtrl =
  //     AnimationController(duration: Console.animationDuration, vsync: this)
  //       ..addListener(() {
  //         loadBaseConsole();
  //       });

  Map<ID, ChatMessage> get _messages =>
      widget.viewState.pages[0].objects.cast();
  Map<ID, Palette2> get _group => widget.viewState.pages[1].objects.cast();

  var lastOffsetUpdate = 0.0;

  String? _idOfLastMessageRead;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // console = theConsole;
    // if (fo != null) {
    //   loadForwardingConsole();
    // } else {
    //   loadBaseConsole();
    // }
  }

  @override
  void dispose() {
    scroller0.dispose();
    scroller1?.dispose();
    // aCtrl?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
    print("UPDATED WIDGET");
    // if (forwardingConsoles.contains(console.name) && fo == null) {
    //   loadBaseConsole();
    // }
  }

  // @override
  // late ConsoleInput mainInput = ConsoleInput(
  //     maxLines: 8,
  //     tec: _tec,
  //     focus: focusNode,
  //     placeHolder: "",
  //     inputCallBack: (_) {
  //       loadBaseConsole();
  //     });

  // void loadSavingConsole() {
  //   console = Console(
  //     // bottomInputs: [mainInput],
  //     topButtons: [],
  //     bottomButtons: [],
  //     consoleRow: Console3(
  //       widgets: [
  //         ConsoleButton(name: "Back", onPress: loadBaseConsole),
  //         ConsoleButton(
  //             name: "To Messages",
  //             onPress: () async {
  //               for (var chat in _messages.values.selected()) {
  //                 chat.message.updateSavedStatus(true);
  //               }
  //               // g.self.save();
  //               unselectSelectedMessage();
  //               loadBaseConsole();
  //             }),
  //         ConsoleButton(
  //             name: "To Medias",
  //             onPress: () {
  //               final selectedMedias = _messages.values
  //                   .selected()
  //                   .where((chat) => chat.hasMedia)
  //                   .map((chat) => chat.mediaInfo!.media);
  //               for (final media in selectedMedias) {
  //                 media.updateSaveStatus(true);
  //               }
  //               // g.self.save();
  //               unselectSelectedMessage();
  //               loadBaseConsole();
  //             }),
  //       ],
  //     ),
  //   );
  //   setState(() {});
  // }

  void unselectSelectedMessage() {
    for (final key in _messages.keys) {
      if (_messages[key]?.selected ?? false) {
        _messages[key] = _messages[key]!.invertedSelection();
      }
    }
    setState(() {});
  }

  Future<void> loadFullCamera() async {
    // TODO
  }

  @override
  Future<void> send({FireMedia? mediaInput}) async {
    final media = cameraInput ?? mediaInput;
    if (input.value == "" && media != null && fo != null) return;

    final r = _messages.values.selected().asIDs().toList();

    final p = Payload(
        media: media,
        text: input.value,
        forwards: fo,
        replies: r,
        isSnip: false);

    widget.send(p);

    unselectSelectedMessage();
    input.clear();
    cameraInput = null;
    turnOffExtras();
    setTheState();
  }

  @override
  late List<Extra> extras = [
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
  ];

  Extra get mediaButtonExtra => extras[0];
  // Extra get mediaButtonExtra => extras[0];

  List<double> get baseConsoleWidth {
    if (forwarding) {
      if (hasFocus) {
        return [0.0, 0.2, 0.0, 0.6, 0.2];
      } else {
        return [0.25, 0.25, 0.0, 0.25, 0.25];
      }
    } else {
      if (hasFocus) {
        return [0.0, 0.2, 0.0, 0.6, 0.2];
      } else {
        return [0.0, 0.25, 0.25, 0.25, 0.25];
      }
    }
  }

  bool get forwarding => (fo ?? []).isNotEmpty;

  // @override
  // void changeConsole(String consoleName) {
  //   currentConsolesName[currentPageIndex] = consoleName;
  //   showMediaButtonExtra = false;
  //   showMediaButtonExtra = false;
  //   setState(() {});
  // }

  // final GlobalKey _doubleCameraKey = GlobalKey();
  // final GlobalKey _mediasButtonKey = GlobalKey();

  @override
  Console3 get console {
    return Console3(
      rows: [
        {
          "base": ConsoleRow(
            widgets: [
              forwardingObjectsWidget,
              mediasButton.withExtra(mediaButtonExtra, [
                forwarding ? cameraButton : forwardButton,
                saveButton,
              ]),
              cameraButton,
              inputs.single.consoleInput,
              sendButton,
            ],
            extension: null,
            widths: baseConsoleWidth, // goes to default even size
            inputMaxHeight: hasFocus ? input.ctrl.height : Console.buttonHeight,
          ),
          // "forward": ConsoleRow(
          //   inputMaxHeight: inputHeight,
          //   extension: null,
          //   widgets: [
          //     forwardingObjectsWidget,
          //     mediasButton,
          //     input,
          //     forwardButton.withExtra(
          //       buttons: [cameraButton],
          //       showExtra: showForwardButtonExtra,
          //       onLongPress: () {
          //         setState(() {
          //           showForwardButtonExtra = !showForwardButtonExtra;
          //         });
          //       },
          //     ),
          //   ],
          //   widths: focusNode.hasFocus ? [0.0, 0.2, 0.6, 0.2] : null,
          // ),
          basicMediaRowName: basicMediasRow,
          basicCameraRowName: basicCameraRow,
          basicSavingRowName: basicSavingRow,
        },
        {
          "base2": ConsoleRow(
            widths: null,
            inputMaxHeight: null,
            extension: null,
            widgets: [forwardButton, hyperButton, moneyButton, addButton],
          )
        }
      ],
      currentConsolesName: currentConsolesName,
      currentPageIndex: widget.viewState.currentIndex,
    );
  }

  // @override
  // void loadConsole() {}

  // InputController input = InputController();
  // double fullHeight = Console.buttonHeight;
  // late MyTextEditor te = MyTextEditor(
  //     onInputChange: (input, height) {
  //       input = input;
  //       fullHeight = height;
  //       loadBaseConsole();
  //     },
  //     input: input,
  //     maxWidth: 0.7,
  //     maxLines: 8,
  //     fn: focusNode!);

  // @override
  // void loadBaseConsole({bool images = true, bool extra = false}) {
  //   if (fo != null) {
  //     loadForwardingConsole();
  //   } else {
  //     console = Console(
  //       // bottomInputs: [mainInput],
  //       // topButtons: [
  //       //   ConsoleButton(name: "Save", onPress: loadSavingConsole),
  //       // ],
  //       bottomButtons: [
  //         // ConsoleButton(
  //         //   name: "BACK",
  //         //   onPress: !extra ? widget.back : loadBaseConsole,
  //         //   showExtra: extra,
  //         //   onLongPress: () => loadBaseConsole(extra: !extra),
  //         //   isSpecial: true,
  //         //   extraButtons: [
  //         //     ConsoleButton(name: "SAVE", onPress: loadSavingConsole),
  //         //     ConsoleButton(
  //         //       name: "FORWARD",
  //         //       onPress: () => widget.forward(
  //         //         _messages.values.selected().toList(growable: false),
  //         //       ),
  //         //     ),
  //         //   ],
  //         // ),
  //       ],
  //       consoleRow: Console3(
  //         beginSizes: const [0.25, 0.25, 0.25, 0.25],
  //         endSizes: const [0.0, 0.15, 0.70, 0.15],
  //         ctrl: aCtrl,
  //         maxHeight: focusNode!.hasFocus ? fullHeight : null,
  //         widgets: [
  //           ConsoleButton(
  //             name: cameraInput == null ? "CAMERA" : "@CAMERA",
  //             onPress: () => loadSquaredCameraConsole(0),
  //           ),
  //           ConsoleButton(
  //             name: "MEDIAS",
  //             onPress: () => loadMediasConsole(images),
  //           ),
  //           ConsoleInput2(te),
  //           ConsoleButton(
  //             name: "SEND",
  //             onPress: () {
  //               send();
  //               loadBaseConsole();
  //             },
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    final pages = node is Groupable
        ? [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: node.displayName,
                console: console,
                asMap: _messages,
                orderedKeys: orderedChats,
                onRefresh: widget.loadMore),
            Down4Page(
              scrollController: scroller1,
              title: "Members",
              console: console,
              list: _group.values.toList(),
            ),
          ]
        : [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: node.displayName,
                console: console,
                asMap: _messages,
                orderedKeys: orderedChats,
                onRefresh: widget.loadMore)
          ];

    return Andrew(
      backFunction: widget.back,
      pages: pages,
      initialPageIndex: widget.viewState.currentIndex,
      onPageChange: (ix) {
        widget.onPageChange(ix);
        onPageSwitch();
      },
    );
  }

  @override
  List<String> currentConsolesName = ["base", "base2"];

  @override
  int get currentPageIndex => widget.viewState.currentIndex;

  @override
  String get backFromCameraConsoleName => "base";

  @override
  String get backFromMediasConsoleName => "base";

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: onInput,
      // isAnimated: node is Groupable,
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
      ctrl: InputController(),
    ),
  ];

  @override
  void forward() {
    if (currentPageIndex == 0) {
      widget.forward(_messages.values.selected().toList(growable: false));
    } else {
      widget.forward(_group.values.selected().toList(growable: false));
    }
  }

  @override
  void saveToMedias() {
    final selectedMedias = _messages.values
        .selected()
        .where((chat) => chat.hasMedia)
        .map((chat) => chat.mediaInfo!.media);
    for (final media in selectedMedias) {
      media.updateSaveStatus(true);
    }
    unselectSelectedMessage();
    changeConsole("base");
  }

  @override
  void saveToMessages() {
    for (var chat in _messages.values.selected()) {
      chat.message.updateSavedStatus(true);
    }
    unselectSelectedMessage();
    changeConsole("base");
  }

  @override
  void add() => widget.add();

  @override
  void hyper() => widget.hyper();

  @override
  void money() => widget.money();
}

// Future<void> squaredCamera(
//   Console c,
//   void Function() b,
//   ConsoleInput i,
//   void Function(String f) cb, {
//   CameraController? ctrl,
//   int cam = 0,
//   String? path,
// }) async {
//   if (ctrl == null) {
//     try {
//       ctrl = CameraController(g.cameras[cam], ResolutionPreset.medium);
//       await ctrl.initialize();
//     } catch (err) {
//       b();
//     }
//   }
//
//   Future<void> nextCam() async {
//     await ctrl?.dispose();
//     return squaredCamera(c, b, i, cb, cam: (cam + 1) % 2);
//   }
//
//   if (path == null) {
//     c = Console(
//       bottomInputs: [i],
//       cameraController: ctrl,
//       topButtons: [
//         ConsoleButton(
//           name: "Capture",
//           isSpecial: true,
//           shouldBeDownButIsnt: ctrl!.value.isRecordingVideo,
//           onPress: () async {
//             final XFile f = await ctrl!.takePicture();
//             squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam, path: f.path);
//           },
//           onLongPress: () async {
//             await ctrl!.startVideoRecording();
//             squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam);
//           },
//           onLongPressUp: () async {
//             final XFile f = await ctrl!.stopVideoRecording();
//             squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam, path: f.path);
//           },
//         ),
//       ],
//       bottomButtons: [
//         ConsoleButton(
//             name: "Back",
//             onPress: () {
//               ctrl?.dispose();
//               b();
//             }),
//         ConsoleButton(
//           name: cam == 0 ? "Rear" : "Front",
//           onPress: nextCam,
//           isMode: true,
//         ),
//       ],
//     );
//   } else {
//     BetterPlayerController? vpc;
//     final topBottons = [
//       ConsoleButton(
//         name: "Accept",
//         onPress: () => cb(path),
//       ),
//     ];
//     final bottomButtons = [
//       ConsoleButton(
//         name: "Back",
//         onPress: () => squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam),
//       ),
//       ConsoleButton(
//           name: "Cancel",
//           onPress: () {
//             ctrl?.dispose();
//             b();
//           }),
//     ];
//
//     if (path.extension().isVideoExtension()) {
//       vpc = BetterPlayerController(const BetterPlayerConfiguration());
//       await vpc.setupDataSource(BetterPlayerDataSource.file(path));
//       await vpc.setLooping(true);
//       await vpc.play();
//       _console = Console(
//           bottomInputs: [consoleInput],
//           videoForPreview: VideoPreview(
//               videoPlayer: BetterPlayer(controller: vpc),
//               videoAspectRatio: ctrl!.value.aspectRatio,
//               isReversed: cam == 1),
//           topButtons: topBottons,
//           bottomButtons: bottomButtons);
//     } else {
//       _console = Console(
//           bottomInputs: [consoleInput],
//           imageForPreview: ImagePreview(
//               path: path,
//               isReversed: cam == 1,
//               imageAspectRatio: ctrl!.value.aspectRatio),
//           topButtons: topBottons,
//           bottomButtons: bottomButtons);
//     }
//   }
//   setState(() {});
// }
