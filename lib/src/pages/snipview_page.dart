import 'package:flutter/material.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/_render_utils.dart' show Down4PageWidget;

import '_page_utils.dart';

class SnipViewPage extends StatelessWidget
    implements Down4PageWidget {
  @override
  String get id => "snipview";

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

  double get boxHeight {
    final tp = TextPainter(
      text: TextSpan(text: text ?? "", style: g.theme.snipInputTextStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: g.sizes.w);
    return tp.height;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      displayMedia,
      text != "" && text != null
          ? Center(
              child: Container(
                width: g.sizes.w,
                height: boxHeight + 4,
                alignment: AlignmentDirectional.center,
                decoration: BoxDecoration(color: g.theme.snipRibbon),
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: g.theme.snipInputTextStyle,
                ),
              ),
            )
          : const SizedBox.shrink(),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          width: g.sizes.w,
          child: console.rowOfPage(index: 0),
        ),
      ),
    ]);
  }

  // @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                ConsoleButton(name: "BACK", onPress: back, isInverted: true),
                ConsoleButton(name: "NEXT", onPress: next, isInverted: true),
              ], extension: null, widths: null, inputMaxHeight: null)
            }
          ],
          currentConsolesName: ["base"],
          currentPageIndex: 0);

  // @override
  // void setTheState() {}

  // @override
  // set extras(List<Extra> e) {}

  // @override
  // final List<Extra> extras = const [];

  // @override
  // List<String> get currentConsolesName => ["base"];
  // @override
  // set currentConsolesName(List<String> j) {}
}
