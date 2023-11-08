import 'package:down4/src/render_objects/navigator.dart';
import 'package:flutter/material.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/_render_utils.dart' show Down4PageWidget;

import '_page_utils.dart';

class SnipViewPage extends StatefulWidget with Down4PageWidget {
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

  @override
  State<SnipViewPage> createState() => _SnipViewPage();
}

class _SnipViewPage extends State<SnipViewPage> with Pager2 {
  // String get text => widget.text ?? "";

  // double get boxHeight {
  //   final tp = TextPainter(
  //     text: TextSpan(text: text, style: g.theme.snipInputTextStyle),
  //     textDirection: TextDirection.ltr,
  //   )..layout(maxWidth: g.sizes.w);
  //   return tp.height;
  // }

  @override
  Widget build(BuildContext context) {
    return Andrew(transparentHeader: true, pages: [
      Down4Page(
        title: "",
        console: console,
        list: [widget.displayMedia],
        // stackWidgets: [widget.displayMedia],
      )
    ]);    

    // Widget ct() => Container(
    //       width: g.sizes.w,
    //       height: boxHeight + 4,
    //       alignment: AlignmentDirectional.center,
    //       decoration: BoxDecoration(color: g.theme.snipRibbon),
    //       child: Text(
    //         text,
    //         textAlign: TextAlign.center,
    //         style: g.theme.snipInputTextStyle,
    //       ),
    //     );

    // return Stack(children: [
    //   widget.displayMedia,
    //   text.isNotEmpty
    //       ? Center(
    //           child: Container(
    //             width: g.sizes.w,
    //             height: boxHeight + 4,
    //             alignment: AlignmentDirectional.center,
    //             decoration: BoxDecoration(color: g.theme.snipRibbon),
    //             child: Text(
    //               text,
    //               textAlign: TextAlign.center,
    //               style: g.theme.snipInputTextStyle,
    //             ),
    //           ),
    //         )
    //       : const SizedBox.shrink(),
    //   Positioned(
    //     bottom: 0,
    //     left: 0,
    //     child: SizedBox(
    //       width: g.sizes.w,
    //       child: console.rowOfPage(index: 0),
    //     ),
    //   ),
    // ]);
  }

  @override
  Console get console => Console(rows: [
        {
          "base": ConsoleRow(widgets: [
            ConsoleButton(
                name: "BACK", onPress: widget.back, isInverted: false),
            ConsoleButton(
                name: "NEXT", onPress: widget.next, isInverted: false),
          ], extension: null, widths: null, inputMaxHeight: null)
        }
      ], currentConsolesName: [
        "base"
      ], currentPageIndex: 0);

  @override
  List<String> currentConsolesName = ["base"];

  @override
  List<Extra> extras = [];

  @override
  void setTheState() => setState(() {});
}
