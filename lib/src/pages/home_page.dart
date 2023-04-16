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
  final void Function() hyperchat;
  final void Function() group, money, search, delete, snip;
  const HomePage({
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
    with Pager, Sender, Medias, Camera {
  late String placeHolder = widget.promptMessage ?? ":)";

  late ScrollController scroller =
      ScrollController(initialScrollOffset: widget.homeState.currentPage.scroll)
        ..addListener(() {
          widget.homeState.currentPage.scroll = scroller.offset;
        });

  void ref() => setState(() {});

  ConsoleInput get input => ConsoleInput(tec: _tec, placeHolder: placeHolder);

  Map<ID, Palette2> get palettes => widget.homeState.currentPage.objects.cast();

  @override
  void initState() {
    super.initState();
    if (widget.promptMessage != null) {
      Future.delayed(const Duration(seconds: 2), () {
        placeHolder = ":)";
        loadBaseConsole();
      });
    }
    loadBaseConsole();
  }

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  final _tec = TextEditingController();

  void ping() {
    if (_tec.value.text.isEmpty) return;
    widget.ping(_tec.value.text);
    _tec.clear();
  }

  @override
  void loadBaseConsole({bool extra = false}) {
    console = Console(
      bottomInputs: [input],
      topButtons: [
        ConsoleButton(name: "Hyperchat", onPress: () => widget.hyperchat()),
        ConsoleButton(name: "Money", onPress: widget.money),
      ],
      bottomButtons: [
        ConsoleButton(
            showExtra: extra,
            name: "Group",
            onPress: () =>
                extra ? loadBaseConsole(extra: !extra) : widget.group(),
            isSpecial: true,
            onLongPress: () => loadBaseConsole(extra: !extra),
            extraButtons: [
              ConsoleButton(name: "Delete", onPress: widget.delete),
              ConsoleButton(name: "Medias", onPress: loadMediasConsole),
              ConsoleButton(
                  name: cameraInput == null ? "Camera" : "@Camera",
                  onPress: loadSquaredCameraConsole),
              ConsoleButton(
                  name: "Forward",
                  onPress: () => widget.forward(
                        palettes.values.selected().toList(),
                      )),
              ConsoleButton(name: "Send", onPress: send)
            ]),
        ConsoleButton(name: "Search", onPress: widget.search),
        ConsoleButton(
            name: "Ping",
            onPress: ping,
            onLongPress: widget.snip,
            isSpecial: true),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
          scrollController: scroller,
          staticList: true,
          title: "Home",
          trueLen: palettes.length,
          list: palettes.values.toList().formatted(),
          console: console)
    ]);
  }

  // @override
  // VideoPlayerController? videoPreview;

  @override
  FireMedia? cameraInput;

  @override
  late Console console;

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
        replies: [],
        forwards: [],
        text: _tec.value.text,
        media: mediaInput ?? cameraInput,
        isSnip: false);

    widget.send(p, palettes.values.selected().asNodes<Chatable>());
    _tec.clear();
  }

  @override
  void setTheState() {
    setState(() {});
  }
}
