import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:down4/src/render_objects/navigator.dart';

import '../themes.dart';
import '../boxes.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: const Center(child: Text("Loading...")),
    );
  }
}

class LoadingPage2 extends StatefulWidget {
  final String? seed;
  const LoadingPage2({this.seed, Key? key}) : super(key: key);

  @override
  State<LoadingPage2> createState() => _LoadingPage2State();
}

class _LoadingPage2State extends State<LoadingPage2>
    with SingleTickerProviderStateMixin {
  // late String text = sha256(utf8.encode(widget.seed ?? "")).toHex();

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Image get down4Logo => Image.asset(
        "lib/src/assets/down4_inverted.png",
        height: 0.82 * Sizes.w,
        width: 0.82 * Sizes.w,
      );

  Widget get rotatingLogo => Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: child,
            );
          },
          child: down4Logo,
        ),
      );

  // @override
  // void initState() {
  //   super.initState();
  //   // Timer.periodic(const Duration(milliseconds: 100), (timer) { });
  //   // Future.delayed(const Duration(milliseconds: 90), () {
  //   //   setState(() {
  //   //     text = sha256(utf8.encode(text)).toHex();
  //   //   });
  //   // });
  // }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Align(
        alignment: AlignmentDirectional.center,
        child: rotatingLogo,
      ),
    );

    // Andrew(pages: [
    //   Down4Page(
    //     title: "Loading",
    //     centerStackItems: true,
    //     stackWidgets: [rotatingLogo],
    //   )
    // ]);

    // var texts = [
    //   text.substring(0, 8),
    //   text.substring(8, 16),
    //   text.substring(16, 24),
    //   text.substring(24, 32),
    //   text.substring(32, 40),
    //   text.substring(40, 48),
    //   text.substring(48, 56),
    //   text.substring(56, 64)
    // ];
    // return Andrew(pages: [
    //   Down4Page(title: "Loading", stackWidgets: [
    //     Center(
    //       child: Column(
    //         children: texts
    //             .map((t) => Text(
    //                   t,
    //                   textAlign: TextAlign.justify,
    //                   style: const TextStyle(
    //                     color: PinkTheme.black,
    //                     fontSize: 24,
    //                     fontWeight: FontWeight.bold,
    //                   ),
    //                 ))
    //             .toList(growable: false),
    //       ),
    //     )
    //   ])
    // ]);
  }
}
