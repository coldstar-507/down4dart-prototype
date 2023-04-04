import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../themes.dart';
import '../globals.dart';
import '../data_objects.dart' show ID;
import '../render_objects/_render_utils.dart'
    show down4Logo, Down4PageWidget;

class LoadingPage2 extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "loading";

  final String? seed;
  const LoadingPage2({this.seed, Key? key}) : super(key: key);

  @override
  State<LoadingPage2> createState() => _LoadingPage2State();
}

class _LoadingPage2State extends State<LoadingPage2>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget get rotatingLogo => Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: child,
            );
          },
          child: down4Logo(0.82 * g.sizes.w),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Align(
        alignment: AlignmentDirectional.center,
        child: rotatingLogo,
      ),
    );
  }
}
