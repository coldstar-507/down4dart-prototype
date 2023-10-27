import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/data_objects/messages.dart';
import 'package:down4/src/data_objects/nodes.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';

import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../render_objects/chat_message.dart';
import '_page_utils.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../globals.dart';

class ForwardingPage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "forward";
  ViewState get viewState => g.vm.currentView;

  final void Function() back, openPreview;
  final void Function() hyper;
  final void Function(Iterable<Chat>) forward;
  Set<Down4Object> get fObjects => g.vm.forwardingObjects;

  const ForwardingPage({
    required this.openPreview,
    required this.hyper,
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
        Compose2,
        Hyper2 {
  Set<Down4Object> get fo => widget.fObjects;

  late ScrollController scroller =
      ScrollController(initialScrollOffset: widget.viewState.pages[0].scroll)
        ..addListener(() {
          widget.viewState.pages[0].scroll = scroller.offset;
        });

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

  Map<Down4ID, Palette> get _forwardState =>
      widget.viewState.pages[0].state.cast();

  Iterable<Palette> get _fList => _forwardState.values;

  Iterable<Palette> get selection => _fList.where((p) => p.selected);

  ConsoleRow get baseRow => ConsoleRow(
          inputMaxHeight: input.hasFocus ? input.height : null,
          extension: null,
          widths: input.hasFocus ? [.20, .0, .60, .20] : null,
          widgets: [
            mediasButton.withExtra(mediaExtra, [cameraButton]),
            hyperButton,
            input.consoleInput,
            sendButton
          ]);

  @override
  Console get console => Console(
          rows: [
            {
              "base": baseRow,
              basicCameraRowName: basicCameraRow,
              cameraConfirmationRowName: cameraConfirmationRow,
              basicMediaRowName: basicMediasRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: widget.viewState.currentIndex);

  @override
  List<(String, void Function(Down4Media))> get mediasMode => [
        (
          "SEND",
          (m) {
            m.use();
            send(mediaInput: m);
          }
        ),
        (
          "REMOVE",
          (m) {
            m.updateSaveStatus(false);
            setState(() {});
          }
        ),
      ];

  @override
  Future<void> send({Down4Media? mediaInput}) async {
    final media = mediaInput ??
        (cameraInput
          ?..cache()
          ..merge()
          ..writeFromCachedPath());

    var chts = <Chat>[];

    final sel = selection.asNodes<ChatN>();

    final fms = fo.whereType<ChatMessage>().map((cm) => cm.message);

    final fm = sel
        .map((s) => fms
            .map((m) => m.forwarded(g.self.id, s.root_)
              ..cache()
              ..merge())
            .toList()
            .reversed)
        .expand((e) => e);

    chts.addAll(fm);

    final fnds = fo.whereType<Palette>().asComposedIDs().toSet();
    if (input.value.isNotEmpty || fnds.isNotEmpty || media != null) {
      final chats = sel.map((n) => Chat(ComposedID(),
          root: n.root_,
          senderID: g.self.id,
          txt: input.value,
          nodes: fo.whereType<Palette>().asComposedIDs().toSet(),
          timestamp: makeTimestamp(),
          mediaID: media?.id)
        ..cache()
        ..merge());
      chts.addAll(chats);
    }
    if (chts.isNotEmpty) {
      g.vm.mode = Modes.def;
      g.vm.forwardingObjects.clear();
      widget.forward(chts);
    }
  }

  @override
  void setTheState() {
    setState(() {});
  }

  @override
  void hyper() => widget.hyper();

  @override
  Widget build(BuildContext context) {
    final ps = _fList.toList(growable: false);
    return Andrew(
      previewFunction: widget.openPreview,
      backFunction: () {
        g.vm.mode = Modes.def;
        widget.back();
      },
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

  Extra get mediaExtra => extras[0];
}
