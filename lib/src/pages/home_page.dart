import 'package:flutter/material.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class HomePage extends StatelessWidget {
  final List<Palette> palettes;
  final Console console;
  const HomePage({required this.palettes, required this.console, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(title: "Home", palettes: palettes, console: console),
    ]);
  }
}
