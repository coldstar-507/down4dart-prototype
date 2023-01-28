import 'package:flutter/material.dart';
// import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../boxes.dart';
import '../themes.dart';

import 'lists.dart';
import 'palette.dart';
import 'chat_message.dart';
import 'console.dart';

class Down4Page {
  final ScrollController? scrollController;
  final String title;
  final List<Widget>? _list;
  // final RefreshController? refreshController;
  // final void Function()? onRefresh, onLoading;
  final Future<void> Function()? onRefresh;
  final Map<String, Widget>? asMap;
  final List<String>? orderedKeys;
  final Iterable<Widget>? _iterables;
  final int? iterableLen;
  final List<Widget>? stackWidgets;
  final Console? console;
  final bool isChatPage, centerStackItems, reversedList, staticList;
  Down4Page({
    required this.title,
    this.scrollController,
    this.asMap,
    this.orderedKeys,
    // this.refreshController,
    this.onRefresh,
    // this.onLoading,
    this.isChatPage = false,
    this.stackWidgets,
    this.iterableLen,
    List<Widget>? list,
    Iterable<Widget>? iterables,
    this.console,
    this.reversedList = true,
    this.centerStackItems = false,
    this.staticList = false,
  })  : _list = list,
        _iterables = iterables;

  List<Widget> get list => _list ?? const [];

  Iterable<Widget>? get iterables => _iterables;
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

  Widget get pageHeader => Row(
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
                  fontSize: 20,
                ),
                child: Text(" ${e.value} ", softWrap: true)))
            .toList(growable: false),
      );

  Widget get pageBody => Expanded(
        child: Stack(
            alignment: widget.pages[curPos].centerStackItems
                ? AlignmentDirectional.center
                : AlignmentDirectional.topStart,
            children: [
              ...widget.pages[curPos].stackWidgets ?? [],
              Row(
                children: widget.pages
                    .asMap()
                    .entries
                    .map((page) => AnimatedOpacity(
                        opacity: curPos == page.key ? 1 : 0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOut,
                          width: curPos == page.key ? Sizes.w : 0,
                          child: page.value.staticList
                              ? StaticList(
                                  reversed: page.value.reversedList,
                                  scrollController: page.value.scrollController,
                                  topPadding: page.value.isChatPage ? 4 : null,
                                  list: page.value.list
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
                                                  transitionFromRight:
                                                      curPos < page.key
                                                          ? true
                                                          : curPos > page.key
                                                              ? false
                                                              : null)
                                              : p)
                                      .toList(growable: false))
                              : DynamicList(
                                  // refreshController: page.value.refreshController,
                                  // onLoading: page.value.onLoading,
                                  onRefresh: page.value.onRefresh,
                                  reversed: page.value.reversedList,
                                  asMap: page.value.asMap,
                                  orderedKeys: page.value.orderedKeys,
                                  scrollController: page.value.scrollController,
                                  topPadding: page.value.isChatPage ? 4 : null,
                                  iterables: page.value.iterables,
                                  iterableLen: page.value.iterableLen,
                                  list: page.value.list
                                  // .map((p) => p is Palette
                                  //     ? p.animated(
                                  //         squish: page.key == curPos,
                                  //         alignedRight: curPos < page.key
                                  //             ? true
                                  //             : curPos > page.key
                                  //                 ? false
                                  //                 : null)
                                  //     : p is ChatMessage
                                  //         ? p.animated(
                                  //             show: page.key == curPos,
                                  //             transitionFromRight:
                                  //                 curPos < page.key
                                  //                     ? true
                                  //                     : curPos > page.key
                                  //                         ? false
                                  //                         : null)
                                  //         : p)
                                  // .toList()
                                  ),
                        )))
                    .toList(growable: false),
              ),
              // ),
            ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Sizes.headerHeight,
        title: pageHeader,
        backgroundColor: PinkTheme.qrColor,
      ),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            if ((details.primaryDelta ?? 0) > 0) {
              print("go left!");
              goLeft();
            } else if ((details.primaryDelta ?? 0) < 0) {
              print("go right!");
              goRight();
            }
          },
          child: Stack(
            children: [
              ...widget.pages[curPos].stackWidgets ?? [],
              Container(
                color: PinkTheme.backGroundColor,
                child: Column(
                  children: [
                    pageBody,
                    curPage.console ?? const SizedBox.shrink(),
                  ],
                ),
              ),
              // ),
              // pageHeader,
              ...curPage.console?.extraTopButtons ?? [],
              ...curPage.console?.extraBottomButtons ?? [],
            ],
          ),
        ),
      ),
      // ),
    );
  }
}
