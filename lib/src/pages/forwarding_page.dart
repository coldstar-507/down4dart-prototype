import 'package:down4/src/_down4_dart_utils.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';
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
  Future<List<ButtonsInfo2>> buttonsOfNode(ChatableNode node) async {
    return [
      ButtonsInfo2(
          assetPath: 'assets/images/50.png',
          pressFunc: () => widget.singleForward(widget.forwardingObjects, node),
          rightMost: true)
    ];
  }

  Map<ID, Palette2> potentialTargets = {};

  void reload() => setState(() {});

  Future<void> loadPalettes() async {
    for (final node in widget.possibleTargets) {
      await writePalette2(node, potentialTargets, buttonsOfNode, reload);
      reload();
    }
  }

  @override
  void initState() {
    super.initState();
    loadPalettes();
  }

  late final Console _console = Console(
    forwardingObjects: widget.forwardingObjects,
    topButtons: [
      ConsoleButton(
          name: "Forward",
          onPress: () => widget.forward(
                widget.forwardingObjects,
                potentialTargets.values
                    .selected()
                    .asNodes()
                    .whereType<ChatableNode>(),
              ))
    ],
    bottomButtons: [
      ConsoleButton(name: "Back", onPress: widget.back),
      ConsoleButton(
          name: "Hyper",
          onPress: () => widget.hyperForward(
              widget.forwardingObjects,
              potentialTargets.values
                  .selected()
                  .asNodes()
                  .whereType<ChatableNode>())),
    ],
  );

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
