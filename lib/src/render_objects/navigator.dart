import 'dart:math' show max;

import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';
// import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../globals.dart';
import '../themes.dart';

import 'lists.dart';
import 'palette.dart';
import 'chat_message.dart';
import 'console.dart';

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
  final void Function()? addFriends;
  final Function(int)? onPageChange;
  final Widget? backButton;

  static Duration get pageSwitchAnimationDuration =>
      const Duration(milliseconds: 200);
  static Duration get pageSwitchOpacityDuration =>
      const Duration(milliseconds: 160);

  const Andrew({
    this.addFriends,
    this.backButton,
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
    super.dispose();
  }

  bool get isHome => widget.backButton == null;

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

  Widget get pageHeader => Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          widget.backButton ??
              GestureDetector(
                onTap: widget.addFriends,
                child: Center(child: down4Logo(g.sizes.headerHeight / 2)),
              ),
          Row(
              children: titles
                  .asMap()
                  .entries
                  .map((e) => AnimatedDefaultTextStyle(
                      duration: Andrew.pageSwitchAnimationDuration,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: g.theme.font,
                        color: g.theme.headerTextColor
                            .withOpacity(curPos == e.key ? 1 : 0.3),
                        fontSize: 20,
                      ),
                      child: Text("  ${e.value}  ")))
                  .toList(growable: false)),
          SizedBox(width: g.sizes.headerHeight / 2)
        ],
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
                                      scrollController:
                                          page.value.scrollController,
                                      topPadding:
                                          page.value.isChatPage ? 4 : null,
                                      iterables: page.value.iterables,
                                      iterableLen: page.value.iterableLen,
                                      list: page.value.list),
                        )))
                    .toList(growable: false),
              ),
              // ),
            ]),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: g.theme.backGroundColor,
          image: DecorationImage(
              image: MemoryImage(
                  g.background), // AssetImage("assets/images/triangles.png"),
              fit: BoxFit.cover)),
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
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            toolbarHeight: g.sizes.headerHeight,
            title: pageHeader,
            backgroundColor: g.theme.headerColor,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                ...widget.pages[curPos].stackWidgets ?? [],
                Column(
                  children: [
                    pageBody,
                    curPage.console ?? const SizedBox.shrink(),
                  ],
                ),
                ...curPage.console.extraButtons,
              ],
            ),
          ),
        ),
      ),
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
