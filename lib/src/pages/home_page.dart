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
  final void Function(PingRequest) ping;
  final void Function() hyperchat, group, money, search, delete, forward, snip;
  // final void Function(ChatableNode) openChat, snipView;
  const HomePage({
    required this.scrollController,
    // required this.openChat,
    // required this.snipView,
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

  // ButtonsInfo2 buttonsOfNode(ChatableNode node, [bool lastMsgWasRead = true]) {
  //   if (node.snips.isNotEmpty) {
  //     return ButtonsInfo2(
  //         assetPath: 'assets/images/snip.png',
  //         pressFunc: () => widget.snipView(node),
  //         rightMost: true);
  //   } else {
  //     return ButtonsInfo2(
  //         assetPath: lastMsgWasRead
  //             ? 'assets/images/50.png'
  //             : 'assets/images/filled.png',
  //         pressFunc: () => widget.openChat(node),
  //         rightMost: true);
  //   }
  // }

  // // Home palettes are all chatables. Friends, non-friends, hyperchats, groups
  // void writePalette2(ChatableNode node, {required bool selected}) {
  //   final lastMessagePreviewInfo = node.previewInfo();
  //   _palettes[node.id] = Palette2(
  //     node: node,
  //     selected: selected,
  //     messagePreview: lastMessagePreviewInfo.first,
  //     imPress: () => writePalette2(node, selected: !selected),
  //     bodyPress: () => writePalette2(node, selected: !selected),
  //     buttonsInfo2: [buttonsOfNode(node, lastMessagePreviewInfo.second)],
  //   );
  // }

  late Console _homeConsole;

  var _tec = TextEditingController();

  void ping() {
    if (_tec.value.text.isEmpty) return;
    final pr = PingRequest(
        text: _tec.value.text,
        targets: widget.palettes.selected().allPeopleIds().toList(),
        senderID: g.self.id);
    widget.ping(pr);
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
