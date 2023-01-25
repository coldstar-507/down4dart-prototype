import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/lists.dart';
import '../render_objects/navigator.dart';
import '../render_objects/profile.dart';

class NodePage extends StatefulWidget {
  final int pageIndex;
  final void Function(int) onPageChange;
  final List<CameraDescription> cameras;
  final List<Palette>? palettes;
  // final MessageList4? messageList;
  final Palette palette;
  final Self self;
  final Palette? Function(BaseNode, {String at}) nodeToPalette;
  final void Function(String, String) openNode, openChat;
  final void Function() back;

  const NodePage({
    required this.pageIndex,
    required this.onPageChange,
    required this.cameras,
    required this.openNode,
    required this.openChat,
    required this.palette,
    required this.nodeToPalette,
    required this.back,
    required this.self,
    this.palettes,
    // this.messageList,
    Key? key,
  }) : super(key: key);

  @override
  _NodePageState createState() => _NodePageState();
}

class _NodePageState extends State<NodePage> {
  Widget? _view;
  @override
  void initState() {
    super.initState();
    final node = widget.palette.node;
    if (node is User) {
      _view = Andrew(pages: [
        Down4Page(
          reversedList: false,
          title: node.name,
          console: userPaletteConsole,
          list: [
            ProfileWidget(palette: widget.palette),
            ...?widget.palettes
          ],
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
            onPress: () => widget.openChat(
              widget.palette.node.id,
              widget.palette.at,
            ),
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.back),
          ConsoleButton(
            name: "Forward",
            onPress: () => print("TODO"), // "TODO: forward"
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return _view ?? const SizedBox.shrink();
  }
}
