import 'package:flutter/material.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class HomePage extends StatelessWidget {
  final ScrollController scrollController;
  final Iterable<Palette> palettes;
  final Console console;
  const HomePage({
    required this.scrollController,
    required this.palettes,
    required this.console,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        scrollController: scrollController,
        staticList: true,
        title: "Home",
        list: palettes.toList(),
        console: console,
      ),
    ]);
  }
}

//
// // if we want the playful home, we need Home to consist of pretty much
// // what it is, not separation between moneyPage, groupPage, hyperchatPage,
// class HomePage2 extends StatefulWidget {
//   // hidden users are the users in groups but not in home
//   // these users actually are in home, just hidden
//   final List<Palette> groupUsersAndHiddenUsers;
//   const HomePage2({required this.groupUsersAndHiddenUsers, Key? key})
//       : super(key: key);
//
//   @override
//   State<HomePage2> createState() => _HomePageState2();
// }
//
// class _HomePageState2 extends State<HomePage2> {
//   late List<Palette> palettes = widget.groupUsersAndHiddenUsers;
//   late Console console = mainConsole;
//   var tec = TextEditingController();
//   var counter = Counter();
//   late List<Down4Page> pages = [mainPage];
//
//   List<Palette> palettesForTransition() {
//     var originalOrder = palettes.asIds();
//     var hidden = palettes.hidden();
//     var selected = palettes.selected();
//     var idsInGroups = selected
//         .asNodes()
//         .groups()
//         .map((g) => g.group)
//         .expand((id) => id)
//         .toSet();
//     var selectedUsers = selected.users();
//     var selectedGroups = selected.groups();
//     var unHide = hidden.those(idsInGroups);
//     var notSelected = palettes.notSelected();
//     // groups are folded
//     // unHide should get a left to right show transition
//     // not selected should get a fold transition
//     // selected are unselected
//     // all are deactivated
//     return [
//       ...selectedUsers
//           .map((e) => e.animated(selected: false, fadeButton: true)),
//       ...unHide.map((e) => e.deactivated().animated(expand: true)),
//       ...selectedGroups.map((e) => e.animated(fold: true, fadeButton: true)),
//       ...notSelected.map((e) => e.animated(fold: true, fadeButton: true)),
//     ].inThatOrder(originalOrder);
//   }
//
//   Down4Page get mainPage => Down4Page(
//         title: "Home",
//         console: mainConsole,
//         palettes: palettes,
//       );
//
//   Down4Page get moneyPage => Down4Page(
//         title: "Money",
//         console: moneyConsole,
//         palettes: palettesForTransition(),
//       );
//
//   Console get moneyConsole => Console(
//         inputs: [ConsoleInput(placeHolder: "\$", tec: tec)],
//         bottomButtons: [
//           ConsoleButton(
//             name: "Back",
//             isSpecial: true,
//             showExtra: false,
//             onPress: () => setState(() {
//               pages = [mainPage];
//             }),
//             onLongPress: () => print("TODO"),
//             extraButtons: [
//               ConsoleButton(name: "Import", onPress: () => print("TODO")),
//             ],
//           ),
//           ConsoleButton(
//               name: "Each", isMode: true, onPress: () => print("TODO")),
//           ConsoleButton(
//               name: "USD", isMode: true, onPress: () => print("TODO")),
//         ],
//         topButtons: [
//           ConsoleButton(name: "Bill", onPress: () => print("TODO")),
//           ConsoleButton(name: "Pay", onPress: () => print("TODO")),
//         ],
//       );
//
//   Console get mainConsole => Console(
//         inputs: [ConsoleInput(placeHolder: ":)", tec: tec)],
//         topButtons: [
//           ConsoleButton(name: "Hyperchat", onPress: () => print("TODO")),
//           ConsoleButton(
//               name: "Money",
//               onPress: () => setState(() {
//                     pages = [moneyPage];
//                   })),
//         ],
//         bottomButtons: [
//           ConsoleButton(name: "Group", onPress: () => print("TODO")),
//           ConsoleButton(name: "Search", onPress: () => print("TODO")),
//           ConsoleButton(name: "Ping", onPress: () => print("TODO")),
//         ],
//       );
//
//   @override
//   Widget build(BuildContext context) {
//     return Andrew(pages: pages);
//
//     // print(renderThatShitInitially.pages[0].title);
//     // return renderThatShitInitially;
//     // return Andrew(pages: [
//     //   Down4Page(title: "Home", console: console, palettes: palettes),
//     // ]);
//   }
// }
