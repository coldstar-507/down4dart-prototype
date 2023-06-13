import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../_dart_utils.dart';
import '../data_objects.dart';
import '_page_utils.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../globals.dart';

class ForwardingPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "forward";
  final ViewState viewState;
  final List<Down4Object> fObjects;
  final void Function() back;
  final void Function(List<Down4Object>, Chatable) openChat;
  final void Function(List<Down4Object>, Transition) hyper;
  final Future<void> Function(Payload, Iterable<Chatable>) forward;

  const ForwardingPage({
    required this.viewState,
    required this.openChat,
    required this.hyper,
    required this.fObjects,
    required this.forward,
    required this.back,
    Key? key,
  }) : super(key: key);

  @override
  State<ForwardingPage> createState() => _ForwadingPageState();
}

class _ForwadingPageState extends State<ForwardingPage>
    with
        WidgetsBindingObserver,
        Pager2,
        Input2,
        Camera2,
        Medias2,
        Sender2,
        ForwardSender2,
        Hyper2 {
  // final _tec = TextEditingController();
  @override
  List<Down4Object> get fo => widget.fObjects;

  late ScrollController scroller =
      ScrollController(initialScrollOffset: widget.viewState.pages[0].scroll)
        ..addListener(() {
          widget.viewState.pages[0].scroll = scroller.offset;
        });

  // @override
  // late final aCtrl =
  //     AnimationController(duration: Console.animationDuration, vsync: this)
  //       ..addListener(() {
  //         loadBaseConsole();
  //       });

  // @override
  // late FocusNode focusNode = FocusNode()..addListener(onFocusChange);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scroller.dispose();
    // focusNode.dispose();
    // aCtrl?.dispose();
    super.dispose();
  }

  Map<ID, Palette2> get _forwardState =>
      widget.viewState.pages[0].objects.cast();

  Iterable<Palette2> get _fList => _forwardState.values;

  Iterable<Palette2> get selection => _fList.where((p) => p.selected);

  // @override
  // late ConsoleInput mainInput = ConsoleInput(
  //     tec: _tec,
  //     placeHolder: "",
  //     focus: focusNode,
  //     maxLines: 8,
  //     inputCallBack: (_) => loadBaseConsole());

  Transition hyperTransition() {
    return selectionTransition(
        originalList: _fList.toList(),
        state: _forwardState,
        scrollOffset: widget.viewState.currentPage.scroll);
  }

  // @override
  // FireMedia? cameraInput;
  //
  // bool sendButtonExtra = false;
  // GlobalKey sendButtonKey = GlobalKey();

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(
                widths: hasFocus ? [0.0, 0.2, 0.6, 0.2] : null,
                inputMaxHeight: hasFocus ? input.height : Console.buttonHeight,
                extension: null,
                widgets: [
                  forwardingObjectsWidget,
                  mediasButton,
                  input.consoleInput,
                  sendButton.withExtra(sendExtra, [cameraButton, hyperButton]),
                ],
              ),
              basicCameraRowName: basicCameraRow,
              cameraConfirmationRowName: cameraConfirmationRow,
              basicMediaRowName: basicMediasRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: widget.viewState.currentIndex);
  //
  // @override
  // late Console console;

  // @override
  // void back() => widget.back();

  // @override
  // void loadBaseConsole() {
  //   // loadForwardingConsole();
  // }

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
            // loadMediasConsole(!m.isVideo, true);
          }
        ),
      ];

  // @override
  // ID get selfID => g.self.id;

  @override
  Future<void> send({FireMedia? mediaInput}) async {
    final p = Payload(
        media: mediaInput ?? cameraInput,
        replies: [],
        forwards: fo,
        text: input.value,
        isSnip: false);
    widget.forward(p, selection.asNodes<Chatable>());
  }

  @override
  void setTheState() {
    setState(() {});
  }

  // @override
  // VideoPlayerController? videoPreview;

  // @override
  // void initState() {
  //   super.initState();
  //   loadBaseConsole();
  // }

  @override
  void hyper() => widget.hyper(fo, hyperTransition());

  @override
  Widget build(BuildContext context) {
    final ps = _fList.toList(growable: false);
    return Andrew(
      backFunction: widget.back,
      pages: [
        Down4Page(
            staticList: true,
            trueLen: ps.length,
            title: "Forward",
            console: console,
            list: ps,
            scrollController: scroller),
      ],
    );
  }

  @override
  List<String> currentConsolesName = ["base"];

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
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
    ),
  ];

  @override
  late List<Extra> extras = [Extra(setTheState: setTheState)];

  Extra get sendExtra => extras[0];
}
