import 'package:flutter/material.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class ForwardingPage extends StatelessWidget {
  final List<Palette> homeUsers;
  final Console console;

  const ForwardingPage({
    required this.homeUsers,
    required this.console,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Jeff(pages: [
      Down4Page(title: "Forward", console: console, palettes: homeUsers),
    ]);
  }
}
