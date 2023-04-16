import 'package:camera/camera.dart';
import 'package:down4/src/globals.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/lists.dart';
import '../render_objects/_render_utils.dart' show Down4PageWidget;
import '../render_objects/navigator.dart';
import '../render_objects/profile.dart';

class NodePage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "node-${viewState.node!.id}";

  final ViewState viewState;
  // final FireNode node;
  final void Function(Chatable) openChat;
  final void Function(FireNode) openNode;
  final void Function(Personable) payNode;
  final void Function() back;

  const NodePage({
    required this.viewState,
    // required this.node,
    required this.payNode,
    required this.openNode,
    required this.openChat,
    required this.back,
    Key? key,
  }) : super(key: key);

  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  Widget? _view;
  FireNode get node => widget.viewState.node!;

  late final ScrollController scroller =
      ScrollController(initialScrollOffset: widget.viewState.pages[0].scroll)
        ..addListener(() {
          widget.viewState.pages[0].scroll = scroller.offset;
        });

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (node is Personable) {
      _view = Andrew(pages: [
        Down4Page(
          scrollController: scroller,
          reversedList: false,
          title: node.displayName,
          console: userPaletteConsole,
          list: [ProfileWidget(node: node)],
        ),
      ]);
    } // TODO other node types
  }

  Console get basicPaletteConsole => Console(
        topButtons: [
          ConsoleButton(
            name: "Parent Depending Button TODO",
            onPress: () => print("TODO"),
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(name: "Forward", onPress: () => print("TODO")),
        ],
      );

  Console get userPaletteConsole => Console(
        topButtons: [
          ConsoleButton(
            name: "Message",
            onPress: () => widget.openChat(node as Chatable),
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(
            name: "Pay",
            onPress: () => widget.payNode(node as Personable),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return _view ?? const SizedBox.shrink();
  }
}
