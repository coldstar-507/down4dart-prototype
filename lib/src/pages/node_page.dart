import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';


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
  final MessageList4? messageList;
  final Palette palette;
  final Node self;
  final Palette? Function(Node, String) nodeToPalette;
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
    this.messageList,
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
    final title =
        node.name + (node.lastName != null ? " " + node.lastName! : "");
    switch (node.type) {
      case Nodes.user:
        _view = Jeff(pages: [
          Down4Page(
            title: title,
            console: userPaletteConsole,
            topDownColumnWidgets: [
              ProfileWidget(node: node),
              ...?widget.palettes
            ],
          ),
        ]);
        break;
      case Nodes.friend:
        _view = Jeff(pages: [
          Down4Page(
            title: title,
            console: userPaletteConsole,
            topDownColumnWidgets: [
              ProfileWidget(node: node),
              ...?widget.palettes
            ],
          ),
        ]);
        break;
      case Nodes.nonFriend:
        _view = Jeff(pages: [
          Down4Page(
            title: title,
            console: userPaletteConsole,
            topDownColumnWidgets: [
              ProfileWidget(node: node),
              ...?widget.palettes
            ],
          ),
        ]);
        break;
      case Nodes.hyperchat:
        print("You broke my app");
        break;
      case Nodes.group:
        print("You broke my app");
        break;
      case Nodes.root:
        _view = Jeff(pages: [
          Down4Page(
            title: title,
            console: basicPaletteConsole,
            palettes: widget.palettes,
          ),
        ]);
        break;
      case Nodes.market:
        _view = Jeff(
            onPageChange: widget.onPageChange,
            initialPageIndex: widget.pageIndex,
            pages: [
              Down4Page(
                title: "Admins",
                console: basicPaletteConsole,
                futureNodes: FutureNodesList(
                  nodeIDs: node.admins!,
                  at: node.id,
                  nodeToPalette: widget.nodeToPalette,
                ),
              ),
              Down4Page(
                title: title,
                console: basicPaletteConsole,
                palettes: widget.palettes,
              ),
            ]);
        break;
      case Nodes.checkpoint:
        _view = Jeff(pages: [
          Down4Page(
            title: title,
            console: basicPaletteConsole,
            palettes: widget.palettes,
          ),
        ]);
        break;
      case Nodes.journal:
        _view = Jeff(
            onPageChange: widget.onPageChange,
            initialPageIndex: widget.pageIndex,
            pages: [
              Down4Page(
                title: "From",
                console: basicPaletteConsole,
                futureNodes: FutureNodesList(
                  nodeIDs: node.parents!,
                  at: node.id,
                  nodeToPalette: widget.nodeToPalette,
                ),
              ),
              Down4Page(
                title: title,
                console: basicPaletteConsole,
                messageList: widget.messageList,
              ),
            ]);
        break;
      case Nodes.item:
        _view = Jeff(
            onPageChange: widget.onPageChange,
            initialPageIndex: widget.pageIndex,
            pages: [
              Down4Page(
                title: "From",
                console: basicPaletteConsole,
                futureNodes: FutureNodesList(
                  nodeIDs: node.parents!,
                  at: node.id,
                  nodeToPalette: widget.nodeToPalette,
                ),
              ),
              Down4Page(
                title: title,
                console: basicPaletteConsole,
                messageList: widget.messageList,
              ),
            ]);
        break;
      case Nodes.event:
        _view = Jeff(
            onPageChange: widget.onPageChange,
            initialPageIndex: widget.pageIndex,
            pages: [
              Down4Page(
                title: "Admins",
                console: basicPaletteConsole,
                futureNodes: FutureNodesList(
                  nodeIDs: node.admins!,
                  at: node.id,
                  nodeToPalette: widget.nodeToPalette,
                ),
              ),
              Down4Page(
                title: title,
                console: basicPaletteConsole,
                palettes: widget.palettes,
              ),
            ]);
        break;
      case Nodes.ticket:
        _view = Jeff(
            onPageChange: widget.onPageChange,
            initialPageIndex: widget.pageIndex,
            pages: [
              Down4Page(
                title: "From",
                console: basicPaletteConsole,
                futureNodes: FutureNodesList(
                  nodeIDs: node.parents!,
                  at: node.id,
                  nodeToPalette: widget.nodeToPalette,
                ),
              ),
              Down4Page(
                title: title,
                console: basicPaletteConsole,
                messageList: widget.messageList,
              ),
            ]);
        break;
    }
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
