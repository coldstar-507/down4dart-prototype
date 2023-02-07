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
