import 'package:down4/src/_down4_dart_utils.dart';
import 'package:down4/src/home.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';
import 'package:down4/src/web_requests.dart';
import 'package:flutter/material.dart';

import '../data_objects.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../globals.dart';

class ForwardingPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "forward";
  final List<Palette2> homePalettes;
  final List<Down4Object> fObjects;
  final Map<ID, Palette2> hiddenState;
  final void Function() back;
  final void Function(List<Down4Object>, ChatableNode) openNode;
  final void Function(List<Down4Object>, Transition) hyper;
  final Future<void> Function(Payload, List<ChatableNode>) forward;

  const ForwardingPage({
    required this.homePalettes,
    required this.openNode,
    required this.hyper,
    required this.fObjects,
    required this.forward,
    required this.back,
    required this.hiddenState,
    Key? key,
  }) : super(key: key);

  @override
  State<ForwardingPage> createState() => _ForwadingPageState();
}

class _ForwadingPageState extends State<ForwardingPage> {
  final GlobalKey _forwardKey = GlobalKey();
  late Console _console;
  final _tec = TextEditingController();
  late final fo = widget.fObjects;

  late ScrollController scroller =
      ScrollController(initialScrollOffset: g.vm.home.cp.scroll)
        ..addListener(() {
          g.vm.cv.cp.scroll = scroller.offset;
        });

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  Map<ID, Palette2>? _f;

  void ref() => setState(() {});

  Future<List<ButtonsInfo2>> bGen(ChatableNode n, List<Down4Object> f) async {
    return [
      ButtonsInfo2(
          asset: g.fifty,
          pressFunc: () => widget.openNode(f, n),
          rightMost: true)
    ];
  }

  ConsoleInput get input => ConsoleInput(tec: _tec, placeHolder: ":)");

  Transition hyperTransition() {
    return selectionTransition(
      originalList: _f!.values.toList(),
      state: _f!,
      hiddenState: widget.hiddenState,
      scrollOffset: scroller.offset,
    );
  }

  ConsoleMedias2 cm(bool showImages) {
    return ConsoleMedias2(
      showImages: showImages,
      onSelect: (media) => widget.forward(
          Payload(f: widget.fObjects, t: _tec.value.text, m: media, r: null),
          _f!.values.selected().asNodes<ChatableNode>().toList()),
    );
  }

  void reload() => setState(() {});

  Future<void> loadPalettes() async {
    final nodes = widget.homePalettes.map((e) => e.node);
    _f = await Future.value({});
    for (final node in nodes.whereType<ChatableNode>()) {
      await writePalette2(node, _f!, (node) => bGen(node, fo), reload, h: true);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadForwardingConsole();
    loadPalettes();
  }

  void loadForwardingMediasConsole({bool images = true}) {
    _console = Console(
      bottomInputs: [input],
      consoleMedias2: ConsoleMedias2(
        showImages: images,
        onSelect: (media) => widget.forward(
          Payload(f: fo, t: _tec.value.text, m: media, r: null),
          _f!.values.selected().asNodes<ChatableNode>().toList(),
        ),
      ),
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: () => loadForwardingConsole()),
        ConsoleButton(
          name: images ? "Images" : "Videos",
          onPress: () => loadForwardingMediasConsole(images: !images),
        )
      ],
    );
    setState(() {});
  }

  void loadForwardingConsole({bool extra = false}) {
    _console = Console(
      bottomInputs: [input],
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          key: _forwardKey,
          name: "Forward",
          onLongPress: () => loadForwardingConsole(extra: !extra),
          onPress: () => extra
              ? loadForwardingConsole(extra: !extra)
              : widget.forward(
                  Payload(r: null, f: fo, t: _tec.value.text, m: null),
                  _f!.values.selected().asNodes<ChatableNode>().toList()),
          isSpecial: true,
          showExtra: extra,
          extraButtons: [
            ConsoleButton(
                name: "Hyper",
                onPress: () => widget.hyper(fo, hyperTransition())),
            ConsoleButton(
                name: "Medias", onPress: () => loadForwardingMediasConsole()),
            ConsoleButton(name: "Camera", onPress: () => print("TODO")),
          ],
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print(_f);
    return Andrew(pages: [
      Down4Page(
        title: "Forward",
        console: _console,
        list: _f?.values.toList() ?? widget.homePalettes,
        scrollController: scroller,
      ),
    ]);
  }
}
