import 'package:camera/camera.dart';
import 'package:down4/src/globals.dart';
import 'package:down4/src/pages/_page_utils.dart';
import 'package:flutter/material.dart';

import '../data_objects/_data_utils.dart';
import '../data_objects/nodes.dart';
import '../render_objects/console.dart';
import '../render_objects/_render_utils.dart' show Down4PageWidget, backArrow;
import '../render_objects/navigator.dart';
import '../render_objects/profile.dart';

class NodePage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "node-${viewState.node!.id}";

  final ViewState viewState;
  // final FireNode node;
  final void Function(ChatNode) openChat;
  final void Function(Down4Node) openNode;
  final void Function(PersonNode) payNode;
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

class _NodePageState extends State<NodePage> with Pager2 {
  Widget? _view;
  Down4Node get node => widget.viewState.node!;

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

  // @override
  // void initState() {
  //   super.initState();
  //   // if (node is Personable) {
  //   //   _view = Andrew(backButton: backArrow(back: widget.back), pages: [
  //   //     Down4Page(
  //   //       scrollController: scroller,
  //   //       reversedList: false,
  //   //       title: node.displayName,
  //   //       console: userPaletteConsole,
  //   //       list: [ProfileWidget(node: node)],
  //   //     ),
  //   //   ]);
  //   // } // TODO other node types
  // }
  //
  // Console get basicPaletteConsole => Console(
  //       topButtons: [
  //         ConsoleButton(
  //           name: "Parent Depending Button TODO",
  //           onPress: () => print("TODO"),
  //         ),
  //       ],
  //       bottomButtons: [
  //         ConsoleButton(name: "Back", onPress: widget.back),
  //         ConsoleButton(name: "Forward", onPress: () => print("TODO")),
  //       ],
  //     );
  //
  // Console get userPaletteConsole => Console(
  //       topButtons: [
  //         ConsoleButton(
  //           name: "Message",
  //           onPress: () => widget.openChat(node as Chatable),
  //         ),
  //       ],
  //       bottomButtons: [
  //         ConsoleButton(name: "Back", onPress: widget.back),
  //       ],
  //       // consoleRow: Console3(
  //       //   widgets: [
  //       //     ConsoleButton(
  //       //       name: "MESSAGE",
  //       //       onPress: () => widget.openChat(node as Chatable),
  //       //     ),
  //       //     ConsoleButton(
  //       //       name: "PAY",
  //       //       onPress: () => widget.payNode(node as Personable),
  //       //     ),
  //       //   ],
  //       // ),
  //     );

  @override
  Widget build(BuildContext context) {
    return Andrew(
      backFunction: widget.back,
      pages: [
        Down4Page(
          scrollController: scroller,
          reversedList: false,
          title: node.displayName,
          console: console,
          list: [ProfileWidget(node: node)],
        ),
      ],
    );

    return _view ?? const SizedBox.shrink();
  }

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                ConsoleButton(
                  name: "MSG",
                  onPress: () => widget.openChat(node as ChatNode),
                ),
                ConsoleButton(
                  name: "PAY",
                  onPress: () => widget.payNode(node as PersonNode),
                ),
              ], extension: null, widths: null, inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  List<String> currentConsolesName = ["base"];

  @override
  int get currentPageIndex => 0;

  @override
  void setTheState() => setState(() {});

  @override
  late List<Extra> extras = [];
}
