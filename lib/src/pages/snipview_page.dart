import 'package:flutter/material.dart';
import '../boxes.dart';
import '../render_objects/console.dart';

class SnipViewPage extends StatelessWidget {
  final Widget displayMedia;
  final String? text;
  final void Function() back;
  final void Function() next;
  const SnipViewPage({
    required this.displayMedia,
    required this.back,
    required this.next,
    this.text,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      displayMedia,
      text != "" && text != null
          ? Center(
              child: Container(
                width: Sizes.w,
                decoration: const BoxDecoration(
                  color: Colors.black38,
                ),
                constraints: BoxConstraints(
                  minHeight: 16,
                  maxHeight: Sizes.fullHeight,
                ),
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : const SizedBox.shrink(),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          width: Sizes.w,
          child: Console(
            invertedColors: true,
            bottomButtons: [
              ConsoleButton(name: "Back", onPress: back),
              ConsoleButton(name: "Next", onPress: next),
            ],
          ),
        ),
      ),
    ]);
  }
}
