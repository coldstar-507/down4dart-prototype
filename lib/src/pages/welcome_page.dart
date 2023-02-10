import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class WelcomePage extends StatelessWidget {
  final void Function() _understood;
  final String _mnemonic;
  final User _userInfo;

  const WelcomePage({
    required String mnemonic,
    required User userInfo,
    required void Function() understood,
    Key? key,
  })  : _mnemonic = mnemonic,
        _userInfo = userInfo,
        _understood = understood,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final stackWidgets = [
      Positioned(
        width: g.sizes.w,
        height: g.sizes.h - (16.0 + Console.buttonHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Palette(node: _userInfo, at: ""),
            Container(
              margin: const EdgeInsets.only(left: 22.0, right: 22.0),
              child: Text(
                _mnemonic,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 22.0, right: 22.0),
              child: const Text(
                "Those twelve words are the key to your account, money & personal infrastructure, save it somewhere secure. We recommend a piece of paper.",
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ];

    final console = Console(
      bottomButtons: [ConsoleButton(name: "Understood", onPress: _understood)],
    );

    return Andrew(pages: [
      Down4Page(title: "Welcome", console: console, stackWidgets: stackWidgets),
    ]);
  }
}
