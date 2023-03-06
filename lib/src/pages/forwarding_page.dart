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
  ID get id => "ForwardingPage";
  final List<ChatableNode> possibleTargets;
  final List<Down4Object> fObjects;
  final Map<ID, Palette2> hiddenState;
  final void Function() back;
  final void Function(List<Down4Object>, ChatableNode) openNode;
  final void Function(List<Down4Object>, Transition) hyper;
  final Future<void> Function(Payload, List<ChatableNode>) forward;

  const ForwardingPage({
    required this.possibleTargets,
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
  late Console _console;
  final tec = TextEditingController();
  final scroller = ScrollController();

  Future<List<ButtonsInfo2>> bGen(ChatableNode node) async {
    return [
      ButtonsInfo2(
          assetPath: 'assets/images/50.png',
          pressFunc: () => widget.openNode(widget.fObjects, node),
          rightMost: true)
    ];
  }

  bool hypering = false;
  Map<ID, Palette2> potentialTargets = {};

  Transition hyperTransition() {
    return selectionTransition(
      state: potentialTargets,
      hiddenState: widget.hiddenState,
      scrollOffset: scroller.offset,
    );
  }

  ConsoleMedias2 cm(bool showImages) => ConsoleMedias2(
      showImages: showImages,
      onSelect: (media) => widget.forward(
          Payload(f: widget.fObjects, t: tec.value.text, m: media, r: null),
          potentialTargets.values.selected().asNodes<ChatableNode>().toList()));

  void reload() => setState(() {});

  Future<void> loadPalettes() async {
    for (final node in widget.possibleTargets) {
      await writePalette2(node, potentialTargets, bGen, reload);
      reload();
    }
  }

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
    loadPalettes();
  }

  void loadForwardingMediasConsole({
    bool images = true,
  }) {
    _console = Console(
      consoleMedias2: ConsoleMedias2(
          showImages: images,
          onSelect: (media) => widget.forward(
              Payload(f: widget.fObjects, t: tec.value.text, m: media, r: null),
              potentialTargets.values
                  .selected()
                  .asNodes<ChatableNode>()
                  .toList())),
      forwardingObjects: widget.fObjects,
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () => loadBaseConsole(),
        ),
        ConsoleButton(
          name: images ? "Images" : "Videos",
          onPress: () => loadForwardingMediasConsole(images: !images),
        )
      ],
    );
    setState(() {});
  }

  void loadBaseConsole({bool extra = false}) {
    _console = Console(
      // consoleMedias2: medias ? cm(images) : null,
      bottomInputs: [ConsoleInput(placeHolder: ":)", tec: tec)],
      forwardingObjects: widget.fObjects,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: "Forward",
          onPress: () => extra
              ? loadBaseConsole(extra: !extra)
              : widget.forward(
                  Payload(
                    f: widget.fObjects,
                    t: tec.value.text,
                    r: null,
                    m: null,
                  ),
                  potentialTargets.values
                      .selected()
                      .asNodes<ChatableNode>()
                      .toList()),
          isSpecial: true,
          showExtra: extra,
          extraButtons: [
            ConsoleButton(
              name: "Hyper",
              onPress: () => widget.hyper(
                widget.fObjects,
                hyperTransition(),
              ),
            ),
            ConsoleButton(name: "Medias", onPress: loadForwardingMediasConsole),
            ConsoleButton(name: "Camera", onPress: () => print("TODO")),
          ],
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        title: "Forward",
        console: _console,
        list: potentialTargets.values.toList(),
        scrollController: scroller,
      ),
    ]);
  }
}
