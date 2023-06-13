import 'dart:math' show max;

import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../_dart_utils.dart';
import '../globals.dart';
import '../themes.dart';

import 'lists.dart';
import 'palette.dart';
import 'chat_message.dart';
import 'console.dart';

class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({
    required this.child,
    Key? key,
  }) : super(key: key);

  final Widget child;

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class Down4Page {
  final ScrollController? scrollController;
  final String title;
  final List<Widget>? _list;
  final Stream<Widget>? stream;
  final Future<void> Function()? onRefresh;
  final Map<String, Widget>? asMap;
  final List<String>? orderedKeys;
  final Iterable<Widget>? _iterables;
  final int? iterableLen, trueLen;
  final List<Widget>? stackWidgets;
  final Console3 console;
  final bool isChatPage, centerStackItems, reversedList, staticList;
  Down4Page({
    required this.title,
    this.scrollController,
    this.asMap,
    this.stream,
    this.orderedKeys,
    this.trueLen,
    this.onRefresh,
    this.isChatPage = false,
    this.stackWidgets,
    this.iterableLen,
    List<Widget>? list,
    Iterable<Widget>? iterables,
    required this.console,
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
  final void Function()? addFriends, themes;
  final Function(int)? onPageChange;
  final void Function()? backFunction;

  static Duration get pageSwitchAnimationDuration =>
      const Duration(milliseconds: 200);
  static Duration get pageSwitchOpacityDuration =>
      const Duration(milliseconds: 160);

  const Andrew({
    this.themes,
    this.addFriends,
    this.backFunction,
    required this.pages,
    this.onPageChange,
    this.initialPageIndex = 0,
    Key? key,
  }) : super(key: key);

  @override
  State<Andrew> createState() => _AndrewState();
}

class _AndrewState extends State<Andrew> {
  int curPos = 0;

  @override
  void initState() {
    super.initState();
    curPos = widget.initialPageIndex;
  }

  void goRight() {
    if (curPos < widget.pages.length - 1) {
      curPos++;
      setState(() {});
      widget.onPageChange?.call(curPos);
    }
  }

  void goLeft() {
    if (curPos > 0) {
      curPos--;
      widget.onPageChange?.call(curPos);
      setState(() {});
    }
  }

  @override
  void dispose() {
    pageCtrl.dispose();
    super.dispose();
  }

  bool get isHome => widget.backFunction == null;

  Down4Page get curPage => widget.pages[curPos];

  List<String> get titles {
    return widget.pages.map((page) => page.title).toList(growable: false);
    // final unTransformed =
    // final maxLen = unTransformed.fold<int>(0, (prev, q) => max(prev, q.length));
    // return unTransformed.map((e) {
    //   final toPad = maxLen - e.length;
    //   // final padLeft = (toPad / 2).ceil();
    //   // final padRight = (toPad / 2).floor();
    //   return e.padLeft(toPad); // .padRight(padRight);
    // }).toList(growable: false);
  }

  late double pageOffset = widget.initialPageIndex.toDouble();

  ScrollController titleScroller = ScrollController();

  (Widget, double, double) titleList3(double leftPadding, double rightPadding) {
    final fullPadding = leftPadding + rightPadding;
    final full = g.sizes.w;
    const double gapWidth = 10;
    final gapSpace = gapWidth * (titles.length - 1);
    final availableSpace = full - fullPadding;
    final availableTitleSpace = availableSpace - gapSpace;
    final spacePerTitle = availableTitleSpace / titles.length;

    final titlesPaints = titles
        .map((e) => TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: " $e ",
              style: g.theme.headerTextStyle2(Colors.white),
            ))
          ..layout())
        .toList();

    List<double> tSpaces = [];
    for (final t in titlesPaints) {
      if (t.width > spacePerTitle) {
        tSpaces.add(spacePerTitle);
      } else {
        tSpaces.add(t.width);
      }
    }

    final tSpace = tSpaces.fold(0.0, (p, t) => p + t);
    final fullSpace = gapSpace + tSpace;

    double leftBox, rightBox, centerBox;
    rightBox = (full / 2) - (fullSpace / 2) - rightPadding;
    leftBox = (full / 2) - (fullSpace / 2) - leftPadding;
    centerBox = fullSpace;
    if (leftBox < 0) {
      rightBox += leftBox;
      leftBox = 0;
    } else if (rightBox < 0) {
      leftBox += rightBox;
      rightBox = 0;
    }

    // print("""
    // RIGHT PADDING = $rightPadding
    // LEFT PADDING = $leftPadding
    // ALPHA = $alpha
    // TITLE SPACE = $titleSpace
    // GAP SPACE = $gapSpace
    // FULL SIZE = $full
    // AVAIL SIZE = $availableSpace
    // FULL SPACE = $fullSpace
    // LEFT BOX = $leftBox
    // RIGHT BOX = $rightBox
    // CENTER BOX = $centerBox
    // centerBox + leftBox + rightBox + headerSize = full? = ${centerBox + leftBox + rightBox + fullPadding}
    // """);

    return (
      SizedBox(
        height: g.sizes.headerHeight,
        width: centerBox - 2,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          controller: titleScroller,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          children: titles.indexed.map((e) {
            final String text = e.$2;
            final int i = e.$1;

            // final double tWidth = alpha * titlesPaints[i].width;
            final double gapW = i == titles.length - 1 ? 0.0 : gapWidth;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: tSpaces[i],
                  height: g.sizes.headerHeight,
                  child: Center(
                      child: Text(" $text ",
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: g.theme.headerTextStyle2(g
                              .theme.headerTextColor
                              .withOpacity(pageTweenValue(i))))),
                ),
                SizedBox(width: gapW),
              ],
            );

            // return Center(
            //     child: Text("  $text  ",
            //         style: g.theme.headerTextStyle2(g.theme.headerTextColor
            //             .withOpacity(pageTweenValue(pageIndex)))));
          }).toList(),
        ),
      ),
      leftBox + 1,
      rightBox + 1,
    );
  }

  (Widget, double, double) titleList2(double leftPadding, double rightPadding) {
    final fullPadding = leftPadding + rightPadding;
    final full = g.sizes.w;
    const double gapWidth = 10;
    final gapSpace = gapWidth * (titles.length - 1);
    final availableSpace = full - fullPadding;

    final titlesPaints = titles
        .map((e) => TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
                text: " $e ", style: g.theme.headerTextStyle2(Colors.white)))
          ..layout())
        .toList();

    final titleSpace = titlesPaints.fold(0.0, (p, i) => i.width + p);
    final fullSpace = gapSpace + titleSpace;

    double alpha = 1;
    double leftBox, rightBox, centerBox;
    if (fullSpace > availableSpace) {
      leftBox = 0;
      rightBox = 0;
      centerBox = availableSpace;
      alpha = (availableSpace - gapSpace) / titleSpace;
    } else {
      rightBox = (full / 2) - (fullSpace / 2) - rightPadding;
      leftBox = (full / 2) - (fullSpace / 2) - leftPadding;
      centerBox = fullSpace;
      if (leftBox < 0) {
        rightBox += leftBox;
        leftBox = 0;
      } else if (rightBox < 0) {
        leftBox += rightBox;
        rightBox = 0;
      }
    }

    // print("""
    // RIGHT PADDING = $rightPadding
    // LEFT PADDING = $leftPadding
    // ALPHA = $alpha
    // TITLE SPACE = $titleSpace
    // GAP SPACE = $gapSpace
    // FULL SIZE = $full
    // AVAIL SIZE = $availableSpace
    // FULL SPACE = $fullSpace
    // LEFT BOX = $leftBox
    // RIGHT BOX = $rightBox
    // CENTER BOX = $centerBox
    // centerBox + leftBox + rightBox + headerSize = full? = ${centerBox + leftBox + rightBox + fullPadding}
    // """);

    return (
      SizedBox(
        height: g.sizes.headerHeight,
        width: centerBox - 2,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          controller: titleScroller,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          children: titles.indexed.map((e) {
            final String text = e.$2;
            final int i = e.$1;

            final double tWidth = alpha * titlesPaints[i].width;
            final double gapW = i == titles.length - 1 ? 0.0 : gapWidth;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: tWidth,
                  height: g.sizes.headerHeight,
                  child: Center(
                      child: Text(" $text ",
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: g.theme.headerTextStyle2(g
                              .theme.headerTextColor
                              .withOpacity(pageTweenValue(i))))),
                ),
                SizedBox(width: gapW),
              ],
            );

            // return Center(
            //     child: Text("  $text  ",
            //         style: g.theme.headerTextStyle2(g.theme.headerTextColor
            //             .withOpacity(pageTweenValue(pageIndex)))));
          }).toList(),
        ),
      ),
      leftBox + 1,
      rightBox + 1,
    );
  }

  (Widget, double, double) titleList(double leftPadding) {
    final lay = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
            text: titles.map((e) => "  $e  ").join(),
            style: g.theme.headerTextStyle2(g.theme.headerTextColor)))
      ..layout();
    final iconSize = g.sizes.headerHeight;
    final full = g.sizes.w;
    final availableSpace = full - leftPadding;
    final layWidth = lay.width;

    double leftBox, rightBox, centerBox;
    if (layWidth > availableSpace) {
      leftBox = 0;
      rightBox = 0;
      centerBox = availableSpace;
    } else {
      rightBox = (full - layWidth) / 2;
      leftBox = rightBox - leftPadding;
      if (leftBox > 0) {
        centerBox = layWidth + 2;
        leftBox -= 1;
        rightBox -= 1;
      } else {
        leftBox = 0;
        rightBox = 0;
        centerBox = availableSpace;
      }
    }

    print("""
    HEADER SIZE = $iconSize
    FULL SIZE = $full
    AVAIL SIZE = ${full - iconSize}
    LAY WIDTH = $layWidth
    LEFT BOX = $leftBox
    RIGHT BOX = $rightBox
    CENTER BOX = $centerBox
    centerBox + leftBox + rightBox + headerSize = full = $full
    """);

    return (
      SizedBox(
        height: iconSize,
        width: centerBox,
        child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            controller: titleScroller,
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            children: [
              ...titles.indexed.map((e) {
                final String text = e.$2;
                final int pageIndex = e.$1;

                return Center(
                    child: Text("  $text  ",
                        style: g.theme.headerTextStyle2(g.theme.headerTextColor
                            .withOpacity(pageTweenValue(pageIndex)))));
              }).toList(),
            ]),
      ),
      leftBox,
      rightBox,
    );
  }

  Widget pageHeader([List<Widget>? topRightWidgets]) {
    final lateralPads = g.sizes.w * 0.02;
    final leftPad = lateralPads + g.sizes.headerHeight;
    final rightIconsWidth =
        (topRightWidgets?.length ?? 0) * g.sizes.headerHeight;
    double rightPad = lateralPads + rightIconsWidth;

    final (titleWidget, leftBoxWidth, rightBoxWidth) =
        titleList3(leftPad, rightPad);
    return Container(
      height: g.sizes.headerHeight,
      width: g.sizes.w,
      color: g.theme.headerColor,
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // SizedBox(width: lateralPads),
          GestureDetector(
              onHorizontalDragUpdate: (_) {},
              behavior: HitTestBehavior.opaque,
              onTap: widget.backFunction ?? widget.addFriends,
              onLongPress: widget.themes,
              child: Row(children: [
                SizedBox(width: lateralPads, height: g.sizes.headerHeight),
                SizedBox.square(
                  dimension: g.sizes.headerHeight,
                  child: widget.backFunction != null
                      ? backArrow()
                      : Center(
                          child: SizedBox.square(
                            dimension: g.sizes.headerHeight, // / golden,
                            child: g.theme.down4Icon(g.theme.backArrowColor),
                          ),
                        ),
                  // down4Logo(g.sizes.headerHeight / 2),
                ),
              ])),
          SizedBox(width: leftBoxWidth),
          titleWidget,
          SizedBox(width: rightBoxWidth),
          ...(topRightWidgets ?? []),
          SizedBox(width: lateralPads, height: g.sizes.headerHeight),

          // const SizedBox.shrink(),
          // Row(
          //   children: titles.indexed.map((e) {
          //     final String text = e.$2;
          //     final int pageIndex = e.$1;
          //
          //     return Text("  $text  ",
          //         style: g.theme.headerTextStyle2(g.theme.headerTextColor
          //             .withOpacity(pageTweenValue(pageIndex))));
          //   }).toList(),
          // ),
          // Row(
          //     children: titles
          //         .asMap()
          //         .entries
          //         .map((e) => AnimatedDefaultTextStyle(
          //             duration: Andrew.pageSwitchAnimationDuration,
          //             style:
          //                 g.theme.headerTextStyle(activated: curPos == e.key),
          //             child: Text("  ${e.value}  ")))
          //         .toList(growable: false)),
          // SizedBox.square(dimension: g.sizes.headerHeight),
        ],
      ),
    );
  }

  Tween<double> tweener = Tween(begin: 1.0, end: 0.3);
  double pageTweenValue(int page) {
    final distance = (page - pageOffset).abs();
    return tweener.transform(distance.toDouble());
  }

  late PageController pageCtrl = PageController(
    initialPage: widget.initialPageIndex,
  )..addListener(() {
      if (pageCtrl.page != null) {
        pageOffset = pageCtrl.page!;
        print("PAGE OFFSET =$pageOffset");
        final percent =
            pageCtrl.position.pixels / pageCtrl.position.maxScrollExtent;
        print("PERCENT = $percent");
        titleScroller.jumpTo(titleScroller.position.maxScrollExtent * percent);
      }
      // print("PAGE CONTROLER PAGE = ${pageCtrl.page}");
      // print("PAGE CONTROLLER OFFSET = ${pageCtrl.offset}");
      setState(() {});
    });

  Widget get pageBody2 =>
      // Expanded(child:
      PageView(
        controller: pageCtrl,
        onPageChanged: widget.onPageChange,
        children: widget.pages.indexed.map((e) {
          final page = e.$2;
          final index = e.$1;
          return KeepAlivePage(
            child: Opacity(
              opacity: pageTweenValue(index),
              child: Stack(
                children: [
                  ...widget.pages[curPos].stackWidgets ?? [],
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: page.staticList
                            ? StaticList(
                                trueLen: page.trueLen,
                                reversed: page.reversedList,
                                scrollController: page.scrollController,
                                topPadding: page.isChatPage ? 4 : null,
                                list: page.list)
                            : page.stream != null
                                ? FutureList(stream: page.stream!)
                                : DynamicList(
                                    onRefresh: page.onRefresh,
                                    reversed: page.reversedList,
                                    asMap: page.asMap,
                                    orderedKeys: page.orderedKeys,
                                    scrollController: page.scrollController,
                                    topPadding: page.isChatPage ? 4 : null,
                                    iterables: page.iterables,
                                    iterableLen: page.iterableLen,
                                    list: page.list),
                      ),
                      page.console.rowOfPage(index: index),
                      // page.console,
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(growable: false),
        // ),
      );

  Widget get pageBody => Expanded(
        child:
            // Stack(
            //     alignment: widget.pages[curPos].centerStackItems
            //         ? AlignmentDirectional.center
            //         : AlignmentDirectional.topStart,
            //     children: [
            //       ...widget.pages[curPos].stackWidgets ?? [],
            Row(
          children: widget.pages
              .asMap()
              .entries
              .map((page) => AnimatedOpacity(
                  opacity: curPos == page.key ? 1 : 0,
                  duration: Andrew.pageSwitchOpacityDuration,
                  curve: Curves.easeInOut,
                  child: AnimatedContainer(
                    duration: Andrew.pageSwitchAnimationDuration,
                    curve: Curves.easeInOut,
                    width: curPos == page.key ? g.sizes.w : 0,
                    child: page.value.staticList
                        ? StaticList(
                            trueLen: page.value.trueLen,
                            reversed: page.value.reversedList,
                            scrollController: page.value.scrollController,
                            topPadding: page.value.isChatPage ? 4 : null,
                            list: page.value.list)
                        : page.value.stream != null
                            ? FutureList(stream: page.value.stream!)
                            : DynamicList(
                                onRefresh: page.value.onRefresh,
                                reversed: page.value.reversedList,
                                asMap: page.value.asMap,
                                orderedKeys: page.value.orderedKeys,
                                scrollController: page.value.scrollController,
                                topPadding: page.value.isChatPage ? 4 : null,
                                iterables: page.value.iterables,
                                iterableLen: page.value.iterableLen,
                                list: page.value.list),
                  )))
              .toList(growable: false),
        ),
        // ),
        // ]
        // ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: g.theme.backGroundColor,
        // image: DecorationImage(
        //     image: MemoryImage(g.background), fit: BoxFit.cover),
      ),
      child:
          // GestureDetector(
          //   onHorizontalDragUpdate: (DragUpdateDetails details) {
          //     if ((details.primaryDelta ?? 0) > 0) {
          //       print("go left!");
          //       goLeft();
          //     } else if ((details.primaryDelta ?? 0) < 0) {
          //       print("go right!");
          //       goRight();
          //     }
          //   },
          //   child:
          Scaffold(
        // primary: false,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: g.sizes.headerHeight,
          backgroundColor: g.theme.headerColor,
          leading: pageHeader(),
          leadingWidth: g.sizes.w,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // ...widget.pages[curPos].stackWidgets ?? [],
              pageBody2,
              // Column(
              //   children: [
              // pageBody,
              // pageBody2,
              // curPage.console ?? const SizedBox.shrink(),
              // ],
              // ),
              ...curPage.console.extraButtons,
              // pageHeader,
            ],
          ),
        ),
      ),
      // ),
    );
  }
}

// class TestAnimation extends StatefulWidget {
//
//   @override
//   _TestAnimationState createState() => _TestAnimationState();
// }

// class _TestAnimationState extends State<TestAnimation> with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late List<Animation> _animation;
//
//   @override
//   void initState() {
//     super.initState();
//     _animationController =
//         AnimationController(duration: Duration(seconds: 2), vsync: this);
//     _animation = widget. IntTween(begin: 100, end: 0).animate(_animationController);
//     _animation.addListener(() => setState(() {}));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         body: Center(
//           child: Row(
//             children: <Widget>[
//               Expanded(
//                 flex: 100,
//                 child: TouchableOpacity(
//                   onPress: () {
//                     if (_animationController.value == 0.0) {
//                       _animationController.forward();
//                     } else {
//                       _animationController.reverse();
//                     }
//                   },
//                   child: const Text("Left"),
//                 ),
//               ),
//               Expanded(
//                 flex: _animation.value,
//                 // Uses to hide widget when flex is going to 0
//                 child: SizedBox(
//                   width: 0.0,
//                   child: TouchableOpacity(
//                     child: const FittedBox( //Add this
//                       child: Text(
//                         "Right",
//                       ),
//                     ),
//                     onPress: () {},
//                   ),
//                 ),
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
