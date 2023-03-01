import 'package:flutter/material.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';

import '../data_objects.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../web_requests.dart' show PingRequest;

import '../globals.dart' show g, ChatableNodeExtensions;

// class HomePage extends StatelessWidget {
//   final ScrollController scrollController;
//   final Iterable<Palette> palettes;
//   final Console console;
//   const HomePage({
//     required this.scrollController,
//     required this.palettes,
//     required this.console,
//     Key? key,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Andrew(pages: [
//       Down4Page(
//         scrollController: scrollController,
//         staticList: true,
//         title: "Home",
//         list: palettes.toList(),
//         console: console,
//       ),
//     ]);
//   }
// }

class HomePage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "HomePage";
  final ScrollController scrollController;
  final List<Palette2> palettes;
  final void Function(String text) ping;
  final void Function() hyperchat, group, money, search, delete, forward, snip;
  const HomePage({
    required this.scrollController,
    required this.palettes,
    required this.hyperchat,
    required this.group,
    required this.money,
    required this.snip,
    required this.ping,
    required this.search,
    required this.delete,
    required this.forward,
    Key? key,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GlobalKey groupButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
  }

  late Console _homeConsole;

  var _tec = TextEditingController();

  void ping() {
    if (_tec.value.text.isEmpty) return;
    widget.ping(_tec.value.text);
    _tec.clear();
  }

  void loadBaseConsole([bool extra = false]) {
    _homeConsole = Console(
      bottomInputs: [
        ConsoleInput(tec: _tec, placeHolder: ":)"),
      ],
      topButtons: [
        ConsoleButton(name: "Hyperchat", onPress: widget.hyperchat),
        ConsoleButton(name: "Money", onPress: widget.money),
      ],
      bottomButtons: [
        ConsoleButton(
            key: groupButtonKey,
            showExtra: extra,
            name: "Group",
            bottomEpsilon: -0.3,
            widthEpsilon: 0.7,
            heightEpsilon: -1.0,
            onPress: () => extra ? loadBaseConsole(!extra) : widget.group(),
            isSpecial: true,
            onLongPress: () => loadBaseConsole(!extra),
            extraButtons: [
              ConsoleButton(name: "Delete", onPress: widget.delete),
              ConsoleButton(name: "Forward", onPress: widget.forward),
              // ConsoleButton(name: "Shit", onPress: () => homePage(!extra)),
              // ConsoleButton(name: "Wacko", onPress: () => homePage(!extra)),
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
    // widget.palettes.forEach((element) => print(element.node.name));
    return Andrew(pages: [
      Down4Page(
          scrollController: widget.scrollController,
          staticList: true,
          title: "Home",
          list: widget.palettes,
          console: _homeConsole)
    ]);
  }
}
