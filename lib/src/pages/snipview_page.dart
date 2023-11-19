import 'dart:math' as math;

import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/data_objects/couch.dart';
import 'package:down4/src/data_objects/medias.dart';
import 'package:down4/src/data_objects/messages.dart';
import 'package:down4/src/data_objects/nodes.dart';
import 'package:down4/src/render_objects/navigator.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../render_objects/console.dart';
import '../render_objects/_render_utils.dart';

import '_page_utils.dart';
import '../globals.dart';

class SnipViewPage2 extends StatefulWidget with Down4PageWidget {
  @override
  String get id => "snipview";
  final ChatN node;
  final Snip snip;
  final void Function() back, next;

  const SnipViewPage2({
    required this.node,
    required this.snip,
    required this.back,
    required this.next,
    super.key,
  });

  @override
  State<SnipViewPage2> createState() => _SnipViewPage2();
}

class _SnipViewPage2 extends State<SnipViewPage2> with Pager2 {
  VideoPlayerController? vpc;
  Widget? snipper;

  @override
  void dispose() {
    print("DISPOSING THAT BAD BOY");
    vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      transparentHeader: true,
      pages: [
        Down4Page(
          title: "", // widget.node.displayName,
          console: console,
          stackWidgets: [
            FutureBuilder(
              future: makeSnip2(widget.snip),
              builder: (context, snapshot) {
                final s = snapshot.connectionState;
                final d = snapshot.data;
                if (s == ConnectionState.done && d != null) {
                  final (snipper_, vpc_) = d;
                  vpc?.dispose();
                  vpc = null;
                  vpc = vpc_
                    ?..setLooping(true)
                    ..play();
                  snipper = snipper_;
                  return snipper!;
                } else {
                  return snipper ??
                      SizedBox.fromSize(
                          size: g.sizes.snipSize,
                          child: Down4RotatingLogo(0.3 * g.sizes.w));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<(Widget, VideoPlayerController?)> makeSnip2(Snip snip) async {
    VideoPlayerController? vpc;

    snip.markRead();

    final bm = await global<Down4Media>(snip.mediaID,
        doCache: false, doFetch: true, tempID: snip.tempMediaID);

    final (tempID, tempTS) = (snip.tempMediaID, snip.tempMediaTS);
    if (tempID != null && tempTS != null) {
      bm?.updateTempReferences(tempID, tempTS);
    }

    await globall<Down4Media>(snip.sticks.map((e) => e.mediaID),
        doFetch: true,
        doMergeIfFetch: true,
        tempIDs: snip.sticks.map((e) => e.tempID));

    final (start, goal) = (snip.snipSize, g.sizes.snipSize);

    final cs = applyBoxFit(BoxFit.contain, start, goal).destination;
    final (k_, _, _) = kds(snip.snipSize, g.sizes.snipSize);
    final (k, d, s) = kds(cs, goal);
    final hasText = snip.txt != null;
    final jeff = snip.txt?.split(" ");
    final txt = jeff?.sublist(1).join(" ");
    final ro = double.parse(jeff?[0] ?? "0.0"); // relative offset for txt

    double boxHeight() {
      final tp = TextPainter(
        text: TextSpan(text: txt, style: g.theme.snipInputTextStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: g.sizes.w);
      return tp.height;
    }

    Widget ct() {
      if (!hasText) return const SizedBox.shrink();
      final ros = Offset(0, ro * s.height);
      final pos = ros - Offset(0, d.dy);
      return Positioned(
          top: pos.dy,
          child: SizedBox(
              width: g.sizes.w,
              height: boxHeight() + 4,
              child: ColoredBox(
                  color: g.theme.snipRibbon,
                  child: Center(
                      child: Text(txt ?? "",
                          textAlign: TextAlign.center,
                          style: g.theme.snipInputTextStyle)))));
    }

    Future<Widget> backGroundMedia() async {
      final rv = bm?.isReversed ?? false;
      if (bm is Down4Image) {
        final im = bm.basicImage();
        if (im != null) {
          await precacheImage(im.image, context);
        }
        return Transform(
            alignment: FractionalOffset.bottomCenter,
            transform: Matrix4.identity()
              ..scale(1 / k)
              ..rotateY(rv ? math.pi : 0),
            child: Align(alignment: Alignment.bottomCenter, child: im));
      } else if (bm is Down4Video) {
        vpc = bm.newReadyController() ?? await bm.futureController();
        if (vpc != null) {
          await vpc!.initialize();
          return Transform(
              alignment: FractionalOffset.bottomCenter,
              transform: Matrix4.identity()
                ..scale(1 / k)
                ..rotateY(rv ? math.pi : 0),
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox.fromSize(
                      size: cs,
                      child: VideoPlayer(vpc!
                        ..setLooping(true)
                        ..play()))));
        }
      }
      return const SizedBox.shrink();
    }

    Future<List<Widget>> stxs() async {
      return await Future.wait(snip.sticks.reversed.map((stx) async {
        final m = local<Down4Media>(stx.mediaID);
        if (m == null) return const SizedBox.shrink();
        m.updateTempReferences(stx.tempID!, stx.tempTS!);
        if (m is Down4Image) {
          final rm = m.readyImage(stx.initSize);
          if (rm == null) return const SizedBox.shrink();
          await precacheImage(rm.image, context);
        }

        final spos = Offset(stx.pos.dx * s.width, stx.pos.dy * s.height);
        final pos = spos - d;

        return Positioned(
            left: pos.dx,
            top: pos.dy,
            child: Transform(
                alignment: FractionalOffset.topLeft,
                transform: Matrix4.identity()
                  // ..translate(pw, ph)
                  ..rotateZ(stx.rotation)
                  ..scale(stx.scale / k_),
                child: m.display(size: stx.initSize)));
      }));
    }

    final Widget widg = SizedBox.fromSize(
        key: GlobalKey(),
        size: goal,
        child: Stack(children: [
          await backGroundMedia(),
          ...await stxs(),
          ct(),
        ]));

    return (widg, vpc);
  }

  @override
  List<Extra> extras = [];

  @override
  List<String> currentConsolesName = ["base"];

  @override
  void setTheState() => setState(() {});

  @override
  Console get console => Console(rows: [
        {
          "base": ConsoleRow(widgets: [
            ConsoleButton(name: "BACK", onPress: widget.back),
            ConsoleButton(name: "NEXT", onPress: widget.next),
          ], extension: null, widths: null, inputMaxHeight: null)
        },
      ], currentConsolesName: currentConsolesName, currentPageIndex: 0);
}

class SnipViewPage extends StatelessWidget //State<SnipViewPage>
    with
        Down4PageWidget {
  //, Pager2 {
  @override
  String get id => "snipview";

  final Widget displayMedia;
  // final String? text;
  final void Function() back;
  final void Function() next;
  SnipViewPage({
    required this.displayMedia,
    required this.back,
    required this.next,
    // this.text,
    Key? key,
  }) : super(key: key);

  // String get text => widget.text ?? "";

  // double get boxHeight {
  //   final tp = TextPainter(
  //     text: TextSpan(text: text, style: g.theme.snipInputTextStyle),
  //     textDirection: TextDirection.ltr,
  //   )..layout(maxWidth: g.sizes.w);
  //   return tp.height;
  // }

  // @override
  Console get console => Console(rows: [
        {
          "base": ConsoleRow(widgets: [
            ConsoleButton(name: "BACK", onPress: back, isInverted: false),
            ConsoleButton(name: "NEXT", onPress: next, isInverted: false),
          ], extension: null, widths: null, inputMaxHeight: null)
        }
      ], currentConsolesName: [
        "base"
      ], currentPageIndex: 0);

  @override
  Widget build(BuildContext context) {
    return Andrew(transparentHeader: true, pages: [
      Down4Page(
        title: "",
        console: console,
        stackWidgets: [displayMedia],
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

  // @override
  // List<String> currentConsolesName = ["base"];

  // @override
  // List<Extra> extras = [];

  // @override
  // void setTheState() {}// => setState(() {});
}
