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

class Down4Page {
  final ScrollController? scrollController;
  final String title;
  final List<Widget>? stackWidgets;
  final List<Palette>? palettes;
  final FutureNodesList? futureNodes;
  final List<ChatMessage>? messages;
  final MessageList4? messageList;
  final List<Widget>? columnWidgets;
  final List<Widget>? topDownColumnWidgets;
  final Console console;
  final bool isChatPage;
  Down4Page({
    required this.title,
    this.scrollController,
    this.isChatPage = false,
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
      <Widget>[];
}

// class Down4Page2 {
//   final String title;
//   final List<Widget>? stackWidgets;
//   final List<Palette>? palettes;
//   final FutureNodesList? futureNodes;
//   final List<ChatMessage>? messages;
//   final MessageList4? messageList;
//   final List<Widget>? columnWidgets;
//   final List<Widget>? topDownColumnWidgets;
//   final Console2 console;
//   Down4Page2({
//     required this.title,
//     this.futureNodes,
//     this.stackWidgets,
//     this.palettes,
//     this.messages,
//     this.messageList,
//     this.columnWidgets,
//     this.topDownColumnWidgets,
//     required this.console,
//   });
//
//   List<Widget> get listItems =>
//       palettes ??
//           messages ??
//           columnWidgets ??
//           topDownColumnWidgets!;
// // }
//
// class Jeff extends StatefulWidget {
//   final List<Down4Page> pages;
//   final int initialPageIndex;
//   final Function(int)? onPageChange;
//
//   const Jeff({
//     required this.pages,
//     this.onPageChange,
//     this.initialPageIndex = 0,
//     Key? key,
//   }) : super(key: key);
//
//   @override
//   _JeffState createState() => _JeffState();
// }
//
// class _JeffState extends State<Jeff> {
//   PageController? controller;
//
//   @override
//   void initState() {
//     super.initState();
//     controller = PageController(initialPage: widget.initialPageIndex);
//   }
//
//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bodies = widget.pages
//         .map((e) => PageBody(
//               topDownColumnWidget: e.topDownColumnWidgets,
//               futureNodes: e.futureNodes,
//               palettes: e.palettes,
//               messageList: e.messageList,
//               messages: e.messages,
//               stackWidgets: e.stackWidgets,
//               columnWidgets: e.columnWidgets,
//             ))
//         .toList(growable: false);
//     final titles = widget.pages.map((e) => e.title).toList(growable: false);
//
//     return Stack(
//       children: [
//         Scaffold(
//           body: Container(
//             color: PinkTheme.backGroundColor,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Container(
//                   decoration: const BoxDecoration(
//                     color: PinkTheme.qrColor,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black38,
//                         blurRadius: 3.0,
//                         spreadRadius: 3.0,
//                       ),
//                     ],
//                   ),
//                   height: 32,
//                   child: Row(
//                     textDirection: TextDirection.ltr,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: titles
//                         .map((e) => Text(" $e ",
//                             style: TextStyle(
//                               color: e == titles[widget.initialPageIndex]
//                                   ? Colors.white
//                                   : Colors.white38,
//                               fontSize: e == titles[widget.initialPageIndex]
//                                   ? 18
//                                   : 14,
//                             )))
//                         .toList(growable: false),
//                   ),
//                 ),
//                 Expanded(
//                   child: PageView(
//                     controller: controller,
//                     children: bodies,
//                     onPageChanged: widget.onPageChange,
//                   ),
//                 ),
//                 widget.pages[widget.initialPageIndex].console,
//               ],
//             ),
//           ),
//         ),
//         ...widget.pages[widget.initialPageIndex].console.extraTopButtons,
//         ...widget.pages[widget.initialPageIndex].console.extraBottomButtons,
//       ],
//     );
//   }
// }

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
  State<Andrew> createState() => _AndrewState();
}

class _AndrewState extends State<Andrew> with TickerProviderStateMixin {
  int curPos = 0;

  @override
  void initState() {
    super.initState();
    curPos = widget.initialPageIndex;
  }

  void goRight() {
    if (curPos < widget.pages.length - 1) {
      print("going right");
      curPos++;
      setState(() {});
      widget.onPageChange?.call(curPos);
    }
  }

  void goLeft() {
    if (curPos > 0) {
      print("going left!");
      curPos--;
      widget.onPageChange?.call(curPos);
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Down4Page get curPage => widget.pages[curPos];

  List<String> get titles =>
      widget.pages.map((page) => page.title).toList(growable: false);

  Widget get pageHeader =>
      // Container(
      //   decoration: const BoxDecoration(
      //     color: PinkTheme.qrColor,
      //     boxShadow: [
      //       BoxShadow(
      //         color: Colors.black38,
      //         blurRadius: 3.0,
      //         spreadRadius: 3.0,
      //       ),
      //     ],
      //   ),
      //   height: 32,
      //   child:
      Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        children: titles
            .asMap()
            .entries
            .map((e) => AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 600),
                style: TextStyle(
                  fontFamily: "Alice",
                  color: Colors.white.withOpacity(curPos == e.key ? 1 : 0.3),
                  fontSize: 18,
                ),
                child: Text(" ${e.value} ", softWrap: true)))
            .toList(growable: false),
        // ),
      );

  Widget get pageBody => Expanded(
        child: Stack(children: [
          ...widget.pages[curPos].stackWidgets ?? [],
          GestureDetector(
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              if ((details.primaryDelta ?? 0) > 0) {
                print("go left!");
                goLeft();
              } else if ((details.primaryDelta ?? 0) < 0) {
                print("go right!");
                goRight();
              }
            },
            child: Row(
              children: widget.pages
                  .asMap()
                  .entries
                  .map((page) => AnimatedContainer(
                      // margin: EdgeInsets.symmetric(
                      //     horizontal: page.key == curPos ? 22 : 0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      width: curPos == page.key ? Sizes.w : 0,
                      child: DynamicList(
                          scrollController: page.value.scrollController,
                          topPadding: page.value.isChatPage ? 4 : null,
                          list: page.value.listItems
                              .map((p) => p is Palette
                                  ? p.animated(
                                      squish: page.key == curPos,
                                      alignedRight: curPos < page.key
                                          ? true
                                          : curPos > page.key
                                              ? false
                                              : null)
                                  : p is ChatMessage
                                      ? p.animated(
                                          show: page.key == curPos,
                                          transitionFromRight: curPos < page.key
                                              ? true
                                              : curPos > page.key
                                                  ? false
                                                  : null)
                                      : p)
                              .toList())))
                  .toList(),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 32,
        title: pageHeader,
        backgroundColor: PinkTheme.qrColor,
      ),
      body:
          // AnnotatedRegion<SystemUiOverlayStyle>(
          //   value: SystemUiOverlayStyle.light.copyWith(
          //     statusBarColor: PinkTheme.qrColor,
          //   ),
          //   child:
          SafeArea(
        child: Stack(children: [
          ...widget.pages[curPos].stackWidgets ?? [],
          Container(
            color: PinkTheme.backGroundColor,
            child: Column(
              // crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // fake header since true header is on stack so it can over shadow the rest
                // const SizedBox(height: 32),
                pageBody,
                curPage.console,
              ],
            ),
          ),
          // pageHeader,
          ...curPage.console.extraTopButtons,
          ...curPage.console.extraBottomButtons,
        ]),
      ),
      // ),
    );
  }
}
