import 'package:flutter/material.dart';

import '../data_objects/_data_utils.dart';
import '../globals.dart';

import 'palette.dart';
import '_render_utils.dart';

class FutureList extends StatefulWidget {
  final Stream<Widget> stream;
  const FutureList({required this.stream, Key? key}) : super(key: key);

  @override
  State<FutureList> createState() => _FutureListState();
}

class _FutureListState extends State<FutureList> {
  List<Widget> items = [];
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('Loading');
          } else if (snapshot.connectionState == ConnectionState.done) {
            return DynamicList(list: items);
          } else if (snapshot.hasError) {
            return const Text('Error!');
          } else {
            items.add(snapshot.data!);
            return DynamicList(list: items);
          }
        });
  }
}

// class FutureList extends StatelessWidget {
//   final Stream<Widget> items;
//   final bool? isReversed;

//   const FutureList({required this.items, this.isReversed, Key? key})
//       : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder(
//         stream: items,
//         builder: (context, snapshot) {
//           if (snapshot.hasData &&
//               snapshot.connectionState == ConnectionState.done) {
//             return snapshot.requireData;
//           } else {
//             return const SizedBox.shrink();
//           }
//         });
//   }
// }

class DynamicList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<Widget> list;
  final Future<void> Function()? onRefresh;
  final Map<Down4ID, Widget>? asMap;
  final List<Down4ID>? orderedKeys;
  final Iterable<Widget>? iterables;
  final int? iterableLen;
  final bool reversed;
  final double? topPadding;
  const DynamicList({
    this.asMap,
    this.orderedKeys,
    this.onRefresh,
    this.scrollController,
    this.topPadding,
    this.iterables,
    this.iterableLen,
    required this.list,
    this.reversed = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (onRefresh != null) {
      return ScrollConfiguration(
          behavior: NoGlow(),
          child: RefreshIndicator(
              edgeOffset: g.sizes.viewPaddingHeight,
              onRefresh: onRefresh!,
              color: g.theme.refreshIndicatorColor,
              backgroundColor: g.theme.backGroundColor,
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.only(top: topPadding ?? Palette.gapSize),
                reverse: reversed,
                itemBuilder: (_, i) =>
                    asMap?[orderedKeys?[i]] ??
                    (list.length > i ? list[i] : const SizedBox.shrink()),
                itemCount: asMap?.length ?? list.length,
              )));
    }

    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.only(top: topPadding ?? Palette.gapSize),
        reverse: reversed,
        itemBuilder: (_, i) => asMap?[orderedKeys?[i]] ?? list[i],
        itemCount: asMap?.length ?? list.length,
      ),
    );
  }
}

class StaticList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<Widget> list;
  final int? trueLen;

  final bool reversed;
  final double? topPadding;
  const StaticList({
    this.scrollController,
    this.topPadding,
    this.trueLen,
    required this.list,
    this.reversed = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          reverse: reversed,
          controller: scrollController,
          padding: EdgeInsets.only(top: topPadding ?? 0.0),
          child: Column(children: list),
        ),
      ),
    );
  }
}

// class PaletteMakerList extends StatelessWidget {
//   final List<PaletteMaker> palettes;
//   const PaletteMakerList({required this.palettes, Key? key}) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//         child: ScrollConfiguration(
//             behavior: NoGlow(),
//             child: ListView.separated(
//                 reverse: true,
//                 itemBuilder: (c, i) => i == 0
//                     ? const SizedBox.shrink()
//                     : i == palettes.length + 2 - 1
//                         ? const SizedBox.shrink()
//                         : palettes[i - 1],
//                 separatorBuilder: (c, i) => Container(height: 16.0),
//                 itemCount: palettes.length + 2)));
//   }
// }
