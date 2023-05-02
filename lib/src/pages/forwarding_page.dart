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
    with Pager, Backable, Camera, Medias, Sender, Forwarder {
  final _tec = TextEditingController();
  @override
  List<Down4Object> get fo => widget.fObjects;

  late ScrollController scroller =
      ScrollController(initialScrollOffset: widget.viewState.pages[0].scroll)
        ..addListener(() {
          widget.viewState.pages[0].scroll = scroller.offset;
        });

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  Map<ID, Palette2> get _forwardState =>
      widget.viewState.pages[0].objects.cast();

  Iterable<Palette2> get _fList => _forwardState.values;

  Iterable<Palette2> get selection => _fList.where((p) => p.selected);

  ConsoleInput get input => ConsoleInput(tec: _tec, placeHolder: ":)");

  Transition hyperTransition() {
    return selectionTransition(
        originalList: _fList.toList(),
        state: _forwardState,
        scrollOffset: widget.viewState.currentPage.scroll);
  }

  // @override
  // VideoPlayerController? videoPreview;

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
  }

  @override
  void Function()? get hyper => () => widget.hyper(fo, hyperTransition());

  @override
  Widget build(BuildContext context) {
    final ps = _fList.toList(growable: false);
    return Andrew(pages: [
      Down4Page(
          staticList: true,
          trueLen: ps.length,
          title: "Forward",
          console: console,
          list: ps,
          scrollController: scroller),
    ]);
  }

  @override
  FireMedia? cameraInput;

  @override
  late Console console;

  @override
  void back() => widget.back();

  @override
  void loadBaseConsole() {
    loadForwardingConsole();
  }

  @override
  ConsoleInput get mainInput => input;

  @override
  List<Pair<String, void Function(FireMedia)>> get mediasMode => [
        Pair("Send", (m) async {
          await m.use();
          send(mediaInput: m);
        }),
        Pair("Remove", (m) {
          m.updateSaveStatus(false);
          loadMediasConsole(!m.isVideo, true);
        }),
      ];

  @override
  ID get selfID => g.self.id;

  @override
  Future<void> send({FireMedia? mediaInput}) async {
    final p = Payload(
        media: mediaInput ?? cameraInput,
        replies: [],
        forwards: fo,
        text: _tec.value.text,
        isSnip: false);
    widget.forward(p, selection.asNodes<Chatable>());
  }

  @override
  void setTheState() {
    setState(() {});
  }
}
