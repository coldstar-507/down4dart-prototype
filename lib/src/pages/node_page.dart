import 'package:down4/src/globals.dart';
import 'package:down4/src/pages/_page_utils.dart';
import 'package:flutter/material.dart';

import '../data_objects/nodes.dart';
import '../render_objects/console.dart';
import '../render_objects/_render_utils.dart' show Down4PageWidget;
import '../render_objects/navigator.dart';
import '../render_objects/profile.dart';

class NodePage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "node-${viewState.node!.id.value}";

  final void Function(ChatN) openChat;
  final void Function(Down4Node) openNode;
  final void Function(PersonN) payNode;
  final void Function() back, openPreview, forward;

  final ViewState viewState;

  const NodePage({
    required this.viewState,
    required this.openPreview,
    required this.payNode,
    required this.openNode,
    required this.openChat,
    required this.back,
    required this.forward,
    Key? key,
  }) : super(key: key);

  @override
  State<NodePage> createState() => _NodePageState();
}

class _NodePageState extends State<NodePage>
    with Pager2, Boost2, Forward2, Append2 {
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

  @override
  Widget build(BuildContext context) {
    return Andrew(
      previewFunction: widget.openPreview,
      staticRow: g.vm.mode == Modes.append ? basicAppendRow : null,
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
  }

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                ConsoleButton(
                  name: "MSG",
                  onPress: () => widget.openChat(node as ChatN),
                ),
                ConsoleButton(
                  name: "PAY",
                  onPress: () => widget.payNode(node as PersonN),
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


  @override
  void boost() {
    // TODO: implement boost
  }

  @override
  void forward() {
    final sel = g.vm.currentView.allPageSelection();
    g.vm.forwardingObjects.addAll(sel);
    g.vm.mode = Modes.forward;
    widget.forward();
  }
}
