import 'package:down4/src/_down4_dart_utils.dart';
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
  final Iterable<ChatableNode> possibleTargets;
  final List<Down4Object> forwardingObjects;
  final void Function() back;
  final void Function(Iterable<Down4Object> objects, ChatableNode single)
      singleForward;
  final void Function(
          Iterable<Down4Object> objects, Iterable<ChatableNode> targets)
      forward, hyperForward;

  const ForwardingPage({
    required this.possibleTargets,
    required this.singleForward,
    required this.forwardingObjects,
    required this.forward,
    required this.hyperForward,
    required this.back,
    Key? key,
  }) : super(key: key);

  @override
  State<ForwardingPage> createState() => _ForwadingPageState();
}

class _ForwadingPageState extends State<ForwardingPage> {
  late Console _console;
  final tec = TextEditingController();

  Future<List<ButtonsInfo2>> bGen(ChatableNode node) async {
    return [
      ButtonsInfo2(
          assetPath: 'assets/images/50.png',
          pressFunc: () => widget.singleForward(widget.forwardingObjects, node),
          rightMost: true)
    ];
  }

  bool hypering = false;
  Map<ID, Palette2> potentialTargets = {};

  ConsoleMedias2 cm(bool showImages) => ConsoleMedias2(
      showImages: showImages,
      onSelectMedia: (media) => forward(withMedia: media));

  void forward({MessageMedia? withMedia}) {
    if (hypering) {
      // TODO
    } else {
      final targets = potentialTargets.values.selected().asIds().toList();
      final forwardingPalettesIDs = // Ids is all we need
          widget.forwardingObjects.whereType<Palette2>().asIds().toList();

      final forwardingMessages = widget.forwardingObjects
          .whereType<Message>()
          .map((msg) => msg.forwarded(g.self))
          .toList();

      final myMessage = Message(
          // root: ,
          senderID: g.self.id,
          timestamp: timeStamp(),
          id: messagePushId(),
          nodes: forwardingPalettesIDs,
          text: tec.value.text,
          mediaID: withMedia?.id);

      for (final target in targets) {
        final node = potentialTargets[target]!.node;
        final specificTargets = node is GroupNode ? node.group : {node.id};
        final root = node is GroupNode ? node.id : null;
        // final mr = MessageRequest(
        //   targets: specificTargets.toList(),

        // );
      }
    }
  }

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

  void loadBaseConsole({
    bool extra = false,
    bool medias = false,
    bool images = false,
  }) {
    _console = Console(
      consoleMedias2: medias ? cm(images) : null,
      bottomInputs: [ConsoleInput(placeHolder: ":)", tec: tec)],
      forwardingObjects: widget.forwardingObjects,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: "Forward",
          onPress: () => extra
              ? loadBaseConsole(extra: !extra, medias: medias, images: images)
              : print("TODO"),
          isSpecial: true,
          showExtra: extra,
          extraButtons: [
            ConsoleButton(name: "Hyper", onPress: () => print("TODO")),
            ConsoleButton(name: "Medias", onPress: () => print("TODO")),
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
      ),
    ]);
  }
}
