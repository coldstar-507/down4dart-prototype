import 'package:down4/src/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data_objects/_data_utils.dart';
import '../data_objects/nodes.dart';
import '../globals.dart';

import '../render_objects/_render_utils.dart';
import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '_page_utils.dart';

class ThemePage extends StatefulWidget implements Down4PageWidget {
  final void Function() back, onSwap;
  const ThemePage({required this.back, required this.onSwap, Key? key})
      : super(key: key);

  @override
  State<ThemePage> createState() => _ThemePageState();

  @override
  String get id => "themes";
}

class _ThemePageState extends State<ThemePage> with Pager2 {
  @override
  List<Extra> extras = [];

  void swapTheme(Down4Theme theme) {
    g.myTheme.changeTheme(theme.name);
    for (final t in themes) {
      writePalette3(NodeTheme(t), _palettes, bGen, setTheState);
    }
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: g.theme.topStatusIconBrightness,
      systemNavigationBarColor: g.theme.bottomNavigationBarColor,
      systemNavigationBarIconBrightness: g.theme.bottonNavigationIconBrightness,
    ));

    widget.onSwap.call();
    setState(() {});
  }

  List<ButtonsInfo2> bGen(NodeTheme t) {
    return [
      ButtonsInfo2(
          asset: g.noMessageArrow,
          pressFunc: () => swapTheme(t.theme),
          rightMost: true)
    ];
  }

  @override
  void initState() {
    super.initState();
    for (final t in themes) {
      writePalette3(NodeTheme(t), _palettes, bGen, setTheState);
    }
  }

  Map<Down4ID, Palette2> _palettes = {};

  List<Down4Theme> themes = [BlackTheme(), PinkTheme()];

  ConsoleButton get purchaseButton =>
      ConsoleButton(name: "PURCHASE", onPress: () {});

  ConsoleButton get giftButton => ConsoleButton(name: "GIFT", onPress: () {});

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(
                  widgets: [purchaseButton, giftButton],
                  extension: null,
                  widths: null,
                  inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  void setTheState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(backFunction: widget.back, pages: [
      Down4Page(
        list: _palettes.values.toList(),
        title: "Themes",
        console: console,
      )
    ]);
  }

  @override
  List<String> currentConsolesName = ["base"];
}

// class WelcomePage extends StatelessWidget {
//   final void Function() _understood;
//   final String _mnemonic;
//   final User _userInfo;

//   const WelcomePage({
//     required String mnemonic,
//     required User userInfo,
//     required void Function() understood,
//     Key? key,
//   })  : _mnemonic = mnemonic,
//         _userInfo = userInfo,
//         _understood = understood,
//         super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final stackWidgets = [
//       Positioned(
//         width: g.sizes.w,
//         height: g.sizes.h - (16.0 + Console.buttonHeight),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             Palette(node: _userInfo, at: ""),
//             Container(
//               margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//               child: Text(
//                 _mnemonic,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 26.0,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             Container(
//               margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//               child: const Text(
//                 "Those twelve words are the key to your account, money & personal infrastructure, save it somewhere secure. We recommend a piece of paper.",
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ];

//     final console = Console(
//       bottomButtons: [ConsoleButton(name: "Understood", onPress: _understood)],
//     );

//     return Andrew(pages: [
//       Down4Page(title: "Welcome", console: console, stackWidgets: stackWidgets),
//     ]);
//   }
// }
