import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../themes.dart';
import '../boxes.dart';
import '../render_objects/_down4_flutter_utils.dart' show down4Logo;

class LoadingPage2 extends StatefulWidget {
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
          child: down4Logo(0.82 * Sizes.w),
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
