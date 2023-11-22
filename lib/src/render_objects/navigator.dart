import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/render_objects/chat_message.dart';
import 'package:down4/src/render_objects/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data_objects/_data_utils.dart';
import '../globals.dart';

import 'lists.dart';
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
  final Widget? simplePageWidget;
  final Stream<Widget>? stream;
  final Future<void> Function()? onRefresh;
  final Map<Down4ID, Widget>? asMap;
  final List<Down4ID>? orderedKeys;
  final Iterable<Widget>? _iterables;
  final int? iterableLen, trueLen;
  final List<Widget>? stackWidgets; //, backgroundStackWidgets;
  final Console console;
  final bool isChatPage, centerStackItems, reversedList, staticList;
  // avoidKeyboardResize;
  Down4Page({
    required this.title,
    this.simplePageWidget,
    this.scrollController,
    this.asMap,
    this.stream,
    this.orderedKeys,
    // this.backgroundStackWidgets,
    // this.avoidKeyboardResize = false,
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
  final bool transparentHeader;
  final Function(int)? onPageChange;
  final void Function()? backFunction, previewFunction;
  final List<Widget>? extraHeaderWidgets;
  // final ConsoleRow? staticRow;
  static Duration get pageSwitchAnimationDuration =>
      const Duration(milliseconds: 200);
  static Duration get pageSwitchOpacityDuration =>
      const Duration(milliseconds: 160);

  const Andrew({
    this.extraHeaderWidgets,
    this.themes,
    // this.staticRow,
    this.addFriends,
    this.backFunction,
    this.previewFunction,
    this.transparentHeader = false,
    required this.pages,
    this.onPageChange,
    this.initialPageIndex = 0,
    Key? key,
  }) : super(key: key);

  @override
  State<Andrew> createState() => _AndrewState();
}

class _AndrewState extends State<Andrew> with WidgetsBindingObserver {
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

  int get nForwardingMessages =>
      g.vm.forwardingObjects.whereType<ChatMessage>().length;

  int get nForwardingPalettes =>
      g.vm.forwardingObjects.whereType<Palette>().length;

  Widget? get forwardingIndicator {
    final nForw = nForwardingMessages + nForwardingPalettes;
    if (nForw == 0 || widget.previewFunction == null) return null;
    return GestureDetector(
        onTap: widget.previewFunction,
        child: Container(
            alignment: AlignmentDirectional.centerEnd,
            child: Text("$nForwardingMessages:$nForwardingPalettes",
                style: g.theme.headerTextStyle(activated: true))));
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
                // so this is the padding after the titles until the top-right icons / right pad
                SizedBox(width: gapW, height: headerHeight),
              ],
            );
          }).toList(),
        ),
      ),
      leftBox + 1,
      rightBox + 1,
    );
  }

  static double get lateralHeaderPad => g.sizes.w * 0.02;
  static double get mainHeaderIconWidth => g.sizes.headerHeight;
  static double get headerHeight => g.sizes.headerHeight;

  Widget pageHeader([List<Widget?>? topRightWidgets]) {
    // final lateralPads = g.sizes.w * 0.02;
    // final leftPad = lateralPads + g.sizes.headerHeight;

    final topRightWgts = topRightWidgets?.whereType<Widget>() ?? [];

    // this is the pad + the backArrow or down4Icon width
    final leftPad = lateralHeaderPad + mainHeaderIconWidth;
    final nTopRightIcons = topRightWgts.length;
    final rightIconsWidth = nTopRightIcons * mainHeaderIconWidth;
    double rightPad = lateralHeaderPad + rightIconsWidth;

    final (titleWidget, leftBoxWidth, rightBoxWidth) =
        titleList3(leftPad, rightPad);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            height: MediaQuery.of(context).padding.top,
            width: g.sizes.w,
            color: widget.transparentHeader
                ? Colors.transparent
                : g.theme.headerColor),
        Container(
          height: g.sizes.headerHeight,
          width: g.sizes.w,
          color: widget.transparentHeader
              ? Colors.transparent
              : g.theme.headerColor,
          child: Row(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(
                  onHorizontalDragUpdate: (_) {},
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.backFunction ?? widget.addFriends,
                  onLongPress: widget.themes,
                  child: Row(children: [
                    // left pad
                    SizedBox(width: lateralHeaderPad, height: headerHeight),

                    // (main icon / back arrow)
                    SizedBox.square(
                      dimension: g.sizes.headerHeight,
                      child: widget.backFunction != null
                          ? backArrow()
                          : Center(
                              child: SizedBox.square(
                                dimension: g.sizes.headerHeight, // / golden,
                                child:
                                    g.theme.down4Icon(g.theme.backArrowColor),
                              ),
                            ),
                    ),
                  ])),

              // padding before reaching first title
              SizedBox(width: leftBoxWidth),
              // all the titles
              titleWidget,
              // padding until the righ pad
              SizedBox(width: rightBoxWidth),
              // top right widgets if there are
              ...topRightWgts,
              // the right pad
              SizedBox(width: lateralHeaderPad, height: headerHeight),
            ],
          ),
        ),
      ],
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
        final percent =
            pageCtrl.position.pixels / pageCtrl.position.maxScrollExtent;
        titleScroller.jumpTo(titleScroller.position.maxScrollExtent * percent);
      }
      setState(() {});
    });

  Widget get staticConsole {
    return Positioned(
      bottom: 0,
      left: 0,
      child: AnimatedOpacity(
        duration: Console.animationDuration,
        opacity: g.vm.appending ? 1 : 0,// widget.staticRow == null ? 0 : 1,
        child: g.vm.appending // widget.staticRow != null
            ? Console.staticRow(widget.staticRow!)
            : SizedBox(width: g.sizes.w),
      ),
    );
  }

  Widget get pageBody2 => ScrollConfiguration(
        behavior: NoGlow(),
        child: PageView(
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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        widget.transparentHeader
                            ? const SizedBox.shrink()
                            : SizedBox(height: g.sizes.viewPaddingHeight),
                        Stack(children: [
                          ...?widget.pages[curPos].stackWidgets,
                        ]),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        page.simplePageWidget ??
                            Flexible(
                              child: page.staticList
                                  ? StaticList(
                                      trueLen: page.trueLen,
                                      reversed: page.reversedList,
                                      scrollController: page.scrollController,
                                      topPadding: g.sizes.viewPaddingHeight +
                                          (page.isChatPage ? 4 : 0),
                                      list: page.list)
                                  : DynamicList(
                                      onRefresh: page.onRefresh,
                                      reversed: page.reversedList,
                                      asMap: page.asMap,
                                      orderedKeys: page.orderedKeys,
                                      scrollController: page.scrollController,
                                      topPadding: g.sizes.viewPaddingHeight +
                                          (page.isChatPage ? 4 : 0),
                                      iterables: page.iterables,
                                      iterableLen: page.iterableLen,
                                      list: page.list),
                            ),
                        page.console.rowOfPage(
                            index: index, staticRow: g.vm.mode == Modes.append),
                        SizedBox(
                            height: MediaQuery.of(context).viewInsets.bottom),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        ),
      );

  Future<bool> onWillPop() async {
    if (widget.backFunction == null) {
      SystemNavigator.pop();
    } else {
      widget.backFunction!.call();
    }
    return false;
  }

  Widget buildAgain() {
    return Container(
      color: g.theme.backGroundColor,
      width: g.sizes.w,
      height: g.sizes.fullHeight,
      child: WillPopScope(
        onWillPop: onWillPop,
        child: Stack(
          children: [
            pageBody2,
            ...curPage.console.extraButtons,
            staticConsole,
            Positioned(
              top: 0,
              left: 0,
              child: pageHeader(
                  [...?widget.extraHeaderWidgets, forwardingIndicator]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildAgain();
  }

  //   return Container(
  //     decoration: BoxDecoration(
  //       color: g.theme.backGroundColor,
  //       // image: DecorationImage(
  //       //     image: MemoryImage(g.background), fit: BoxFit.cover),
  //     ),
  //     child: WillPopScope(
  //       onWillPop: onWillPop,
  //       child: Stack(
  //         children: [
  //           // ...?curPage.backgroundStackWidgets,
  //           Scaffold(
  //             // resizeToAvoidBottomInset: !curPage.avoidKeyboardResize,
  //             backgroundColor: Colors.transparent,
  //             appBar: AppBar(
  //               toolbarHeight: g.sizes.headerHeight,
  //               elevation: 0.0,
  //               backgroundColor: widget.transparentHeader
  //                   ? Colors.transparent
  //                   : g.theme.headerColor,
  //               leading: pageHeader([forwardingIndicator]),
  //               leadingWidth: g.sizes.w,
  //             ),
  //             body: SafeArea(
  //               child: Stack(
  //                 children: [
  //                   pageBody2,
  //                   ...curPage.console.extraButtons,
  //                   staticConsole
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}

// class MyScreenWithoutScaffold extends StatefulWidget {
//   @override
//   _MyScreenWithoutScaffoldState createState() =>
//       _MyScreenWithoutScaffoldState();
// }

// class _MyScreenWithoutScaffoldState extends State<MyScreenWithoutScaffold>
//     with WidgetsBindingObserver {
//   double _keyboardHeight = 0.0;

//   @override
//   void initState() {
//     super.initState();

//     // Add a listener to the MediaQuery for keyboard changes

//     MediaQuery.of(context).removeObserver(_handleMediaQueryChange);
//     MediaQuery.of(context).addObserver(_handleMediaQueryChange);
//   }

//   @override
//   void dispose() {
//     // Remove the MediaQuery listener to prevent memory leaks
//     MediaQuery.of(context).removeObserver(_handleMediaQueryChange);
//     super.dispose();
//   }

//   void _handleMediaQueryChange() {
//     // Calculate the keyboard height by subtracting the screen height from the viewInsets
//     setState(() {
//       _keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [Colors.blue, Colors.green],
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Container(
//             padding: EdgeInsets.only(top: 40.0, left: 16.0, right: 16.0),
//             child: Text(
//               'Title',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 24.0,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           Expanded(
//             child: SingleChildScrollView(
//               // Adjust the padding to account for the keyboard height
//               padding: EdgeInsets.only(bottom: _keyboardHeight),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   TextField(
//                     decoration: InputDecoration(
//                       labelText: 'Input',
//                     ),
//                   ),
//                   SizedBox(height: 20.0),
//                   Container(
//                     width: double.infinity,
//                     height: 200.0,
//                     color: Colors.blue,
//                     child: Center(
//                       child: Text(
//                         'Resizable Content',
//                         style: TextStyle(color: Colors.white),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

