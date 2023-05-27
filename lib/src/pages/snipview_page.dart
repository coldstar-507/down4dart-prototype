import 'package:flutter/material.dart';
import '../globals.dart';
import '../data_objects.dart' show ID;
import '../render_objects/console.dart';
import '_page_utils.dart';
import '../render_objects/_render_utils.dart' show Down4PageWidget;

class SnipViewPage extends StatelessWidget
    with Pager2
    implements Down4PageWidget {
  @override
  ID get id => "snipview";

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
                width: g.sizes.w,
                decoration: const BoxDecoration(
                  color: Colors.black38,
                ),
                constraints: BoxConstraints(
                  minHeight: 16,
                  maxHeight: g.sizes.fullHeight,
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
          width: g.sizes.w,
          child: console,
          // Console3(
          //   // consoleRow: Console3(
          //   //   widgets: [
          //   //
          //   //   ],
          //   // ),
          //   bottomButtons: [],
          // ),
        ),
      ),
    ]);
  }

  @override
  final List<Extra> extras = const [];

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                ConsoleButton(name: "BACK", onPress: back, isInverted: true),
                ConsoleButton(name: "NEXT", onPress: next, isInverted: true),
              ], extension: null, widths: null, inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  void setTheState() {
    return;
  }

  @override
  set extras(List<Extra> e) {
    return;
  }
}
