import 'package:flutter/material.dart';

import '../boxes.dart';
import '../themes.dart';

import 'lists.dart';
import 'palette.dart';
import 'chat_message.dart';
import 'console.dart';

class PageBody extends StatelessWidget {
  final List<Widget>? stackWidgets;
  final List<Palette>? palettes;
  final List<ChatMessage>? messages;
  final MessageList4? messageList;
  final List<Widget>? columnWidgets;
  final List<Widget>? topDownColumnWidget;
  final FutureNodesList? futureNodes;

  const PageBody({
    this.columnWidgets,
    this.palettes,
    this.stackWidgets,
    this.messageList,
    this.messages,
    this.topDownColumnWidget,
    this.futureNodes,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...(stackWidgets ?? []),
        messageList ??
            futureNodes ??
            ((palettes != null || messages != null || columnWidgets != null)
                ? DynamicList(list: palettes ?? messages ?? columnWidgets!)
                : topDownColumnWidget != null
                    ? DynamicList(list: topDownColumnWidget!, reversed: false)
                    : const SizedBox.shrink()),
      ],
    );
  }
}

class PageConsole extends StatelessWidget {
  final Console console;

  const PageConsole({required this.console, Key? key}) : super(key: key);

  List<Widget> getExtraTopButtons() {
    final consoleHorizontalGap = Sizes.h * 0.023;
    final consoleVerticalGap = Sizes.h * 0.021;
    final buttonWidth = ((Sizes.w - (consoleHorizontalGap * 2.0)) /
            (console.bottomButtons.length.toDouble())) +
        1.0; // 1.0 for borders
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.topButtons ?? <ConsoleButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
          bottom: consoleVerticalGap + (ConsoleButton.height * 2),
          left: consoleHorizontalGap + (buttonWidth * i),
          child: Container(
            height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
            width: buttonWidth,
            decoration: BoxDecoration(border: Border.all(width: 0.5)),
            child: Column(children: b.extraButtons!),
          ),
        ));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  List<Widget> getExtraBottomButtons() {
    final horizontalGap = Sizes.h * 0.023;
    final verticalGap = Sizes.h * 0.021;
    final nBottomButton = console.bottomButtons.length;
    final buttonWidth = (Sizes.w - (2 * horizontalGap)) / nBottomButton;
    List<Widget> extras = [];
    int i = 0;
    for (final b in console.bottomButtons) {
      final nExtra = b.extraButtons?.length ?? 0;
      if (b.showExtra && nExtra > 0) {
        extras.add(Positioned(
            bottom: verticalGap + ConsoleButton.height + b.bottomEpsilon,
            left: horizontalGap + (buttonWidth * i) + b.leftEpsilon,
            child: Container(
              height: (nExtra * ConsoleButton.height) + b.heightEpsilon,
              width: buttonWidth + b.widthEpsilon,
              decoration: BoxDecoration(border: Border.all(width: 0.5)),
              child: Column(children: b.extraButtons!),
            )));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  @override
  Widget build(BuildContext context) {
    return console;
  }
}

class Down4Page {
  final String title;
  final List<Widget>? stackWidgets;
  final List<Palette>? palettes;
  final FutureNodesList? futureNodes;
  final List<ChatMessage>? messages;
  final MessageList4? messageList;
  final List<Widget>? columnWidgets;
  final List<Widget>? topDownColumnWidgets;
  final Console console;
  Down4Page({
    required this.title,
    this.futureNodes,
    this.stackWidgets,
    this.palettes,
    this.messages,
    this.messageList,
    this.columnWidgets,
    this.topDownColumnWidgets,
    required this.console,
  });

  List<Widget> get listItems =>
      palettes ??
      messages ??
      columnWidgets ??
      topDownColumnWidgets ??
      stackWidgets!;
}

class Jeff extends StatefulWidget {
  final List<Down4Page> pages;
  final int initialPageIndex;
  final Function(int)? onPageChange;

  const Jeff({
    required this.pages,
    this.onPageChange,
    this.initialPageIndex = 0,
    Key? key,
  }) : super(key: key);

  @override
  _JeffState createState() => _JeffState();
}

class _JeffState extends State<Jeff> {
  PageController? controller;

  @override
  void initState() {
    super.initState();
    controller = PageController(initialPage: widget.initialPageIndex);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodies = widget.pages
        .map((e) => PageBody(
              topDownColumnWidget: e.topDownColumnWidgets,
              futureNodes: e.futureNodes,
              palettes: e.palettes,
              messageList: e.messageList,
              messages: e.messages,
              stackWidgets: e.stackWidgets,
              columnWidgets: e.columnWidgets,
            ))
        .toList(growable: false);
    final titles = widget.pages.map((e) => e.title).toList(growable: false);
    final consoles = widget.pages
        .map((e) => PageConsole(console: e.console))
        .toList(growable: false);

    return Stack(
      children: [
        Scaffold(
          body: Container(
            color: PinkTheme.backGroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: PinkTheme.qrColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 3.0,
                        spreadRadius: 3.0,
                      ),
                    ],
                  ),
                  height: 32,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: titles
                        .map((e) => Text(" " + e + " ",
                            style: TextStyle(
                              color: e == titles[widget.initialPageIndex]
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: e == titles[widget.initialPageIndex]
                                  ? 18
                                  : 14,
                            )))
                        .toList(growable: false),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: controller,
                    children: bodies,
                    onPageChanged: widget.onPageChange,
                  ),
                ),
                consoles[widget.initialPageIndex],
              ],
            ),
          ),
        ),
        ...consoles[widget.initialPageIndex].getExtraTopButtons(),
        ...consoles[widget.initialPageIndex].getExtraBottomButtons(),
      ],
    );
  }
}

class Andrew extends StatefulWidget {
  final List<Down4Page> pages;
  final int initialPageIndex;
  final Function(int)? onPageChange;

  const Andrew({
    required this.pages,
    this.onPageChange,
    this.initialPageIndex = 0,
    Key? key,
  }) : super(key: key);

  @override
  _AndrewState createState() => _AndrewState();
}

class _AndrewState extends State<Andrew> with TickerProviderStateMixin {
  int curPos = 0;

  // late final AnimationController scaleCtrl = AnimationController(
  //   vsync: this,
  //   duration: const Duration(milliseconds: 600),
  // );
  // late final Animation<double> _animation = CurvedAnimation(
  //   parent: scaleCtrl,
  //   curve: Curves.easeOut,
  // );

  void goRight() {
    if (curPos < widget.pages.length - 1) {
      curPos++;
      setState(() {});
    }
  }

  void goLeft() {
    if (curPos > 0) {
      curPos--;
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = widget.pages.map((e) => e.title).toList(growable: false);
    final consoles = widget.pages
        .map((e) => PageConsole(console: e.console))
        .toList(growable: false);

    return Stack(
      children: [
        Scaffold(
          body: Container(
            color: PinkTheme.backGroundColor,
            child: Column(
              // crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: PinkTheme.qrColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 3.0,
                        spreadRadius: 3.0,
                      ),
                    ],
                  ),
                  height: 32,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: titles
                        .asMap()
                        .entries
                        .map((e) => AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 600),
                            style: TextStyle(
                              fontFamily: "Alice",
                              color: Colors.white
                                  .withOpacity(curPos == e.key ? 1 : 0.3),
                              fontSize: 18,
                            ),
                            child: Text(
                              " ${e.value} ",
                              softWrap: true,
                            )))
                        .toList(growable: false),
                  ),
                ),
                Expanded(
                  child: Stack(children: [
                    ...widget.pages[curPos].stackWidgets ?? [],
                    GestureDetector(
                      onHorizontalDragUpdate: (DragUpdateDetails details) {
                        if ((details.primaryDelta ?? 0) > 0) {
                          goLeft();
                        } else if ((details.primaryDelta ?? 0) < 0) {
                          goRight();
                        }
                      },
                      child: Row(
                        children: widget.pages
                            .asMap()
                            .entries
                            .map((page) => AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOut,
                                width: curPos == page.key ? Sizes.w : 0,
                                child: PaletteList(
                                    palettes: page.value.palettes!.map((p) {
                                  if (curPos == page.key) {
                                    print(
                                      "######## showing ${p.node.name} ########",
                                    );
                                  }
                                  return p.animated(
                                      page.key == curPos,
                                      curPos < page.key
                                          ? true
                                          : curPos > page.key
                                              ? false
                                              : null);
                                }).toList())))
                            .toList(),
                      ),
                    ),
                  ]),
                ),
                consoles[curPos],
              ],
            ),
          ),
        ),
        ...consoles[widget.initialPageIndex].getExtraTopButtons(),
        ...consoles[widget.initialPageIndex].getExtraBottomButtons(),
      ],
    );
  }
}
