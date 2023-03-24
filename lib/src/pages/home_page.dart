import 'dart:math';

import 'package:flutter/material.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';

import '../data_objects.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '../globals.dart';

class HomePage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "home";
  final String? promptMessage;
  final List<Palette2> palettes;
  final void Function(String text) ping;
  final void Function(Chatable, List<Down4Object>) openNode;
  final void Function(Payload, List<Chatable>) send;
  final void Function(List<Palette2>) forward;
  final void Function() hyperchat;
  final void Function() group, money, search, delete, snip;
  const HomePage({
    required this.palettes,
    required this.hyperchat,
    required this.group,
    required this.money,
    required this.snip,
    required this.ping,
    required this.search,
    required this.delete,
    required this.send,
    required this.openNode,
    required this.forward,
    this.promptMessage,
    Key? key,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String placeHolder = widget.promptMessage ?? ":)";

  late ScrollController scroller =
      ScrollController(initialScrollOffset: g.vm.home.cp.scroll)
        ..addListener(() {
          g.vm.home.cp.scroll = scroller.offset;
        });

  void ref() => setState(() {});

  ConsoleInput get input => ConsoleInput(tec: _tec, placeHolder: placeHolder);

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

  late Console _homeConsole;

  final _tec = TextEditingController();

  void ping() {
    if (_tec.value.text.isEmpty) return;
    widget.ping(_tec.value.text);
    _tec.clear();
  }

  void loadBaseConsole({bool extra = false}) {
    _homeConsole = Console(
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
              ConsoleButton(
                name: "Forward",
                onPress: () => widget.forward(
                  widget.palettes.selected().toList(),
                ),
              ),
            ]),
        ConsoleButton(name: "Search", onPress: widget.search),
        ConsoleButton(
          name: "Ping",
          onPress: ping,
          onLongPress: widget.snip,
          isSpecial: true,
        ),
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
          trueLen: widget.palettes.length,
          list: widget.palettes,
          console: _homeConsole)
    ]);
  }
}
