import 'package:down4/src/themes.dart';
import 'package:flutter/material.dart';
// import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../data_objects.dart';
import '../boxes.dart';

import 'palette.dart';
import 'chat_message.dart';
import 'palette_maker.dart';
import 'render_utils.dart';

class PaletteList extends StatelessWidget {
  final List<Palette> palettes;
  const PaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final gapSize = Sizes.h * 0.02; // 2%
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.builder(
        reverse: true,
        itemBuilder: (c, i) => palettes[i],
        itemCount: palettes.length,
        padding: EdgeInsets.only(top: gapSize),
      ),
      // child: ListView.separated(
      //   padding: const EdgeInsets.only(top: 0),
      //   reverse: true,
      //   itemBuilder: (c, i) => i == 0
      //       ? const SizedBox.shrink()
      //       : i == palettes.length + 2 - 1
      //           ? const SizedBox.shrink()
      //           : palettes[i - 1],
      //   separatorBuilder: (c, i) => Container(height: gapSize),
      //   itemCount: palettes.length + 2,
      // ),
    );
  }
}

class DynamicList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<Widget> list;
  final Future<void> Function()? onRefresh;
  final Map<Identifier, Widget>? asMap;
  final List<Identifier>? orderedKeys;
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
  double get gapSize => Sizes.h * 0.02;

  @override
  Widget build(BuildContext context) {
    if (onRefresh != null) {
      return ScrollConfiguration(
        behavior: NoGlow(),
        child: RefreshIndicator(
          onRefresh: onRefresh!,
          color: PinkTheme.qrColor,
          backgroundColor: PinkTheme.backGroundColor,
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(top: topPadding ?? gapSize),
            reverse: reversed,
            itemBuilder: (_, i) => asMap![orderedKeys![i]]!,
            itemCount: iterableLen ?? iterables?.length ?? list.length,
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.only(top: topPadding ?? gapSize),
        reverse: reversed,
        itemBuilder: (_, i) => iterables?.elementAt(i) ?? list[i],
        itemCount: iterableLen ?? iterables?.length ?? list.length,
      ),
    );
  }
}

class StaticList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<Widget> list;

  final bool reversed;
  final double? topPadding;
  const StaticList({
    this.scrollController,
    this.topPadding,
    required this.list,
    this.reversed = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gapSize = Sizes.h * 0.02;
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          reverse: reversed,
          controller: scrollController,
          padding: EdgeInsets.only(top: topPadding ?? gapSize),
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.end,
            children: list,
          ),
        ),
      ),
    );
  }
}

class PaletteMakerList extends StatelessWidget {
  final List<PaletteMaker> palettes;
  const PaletteMakerList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                reverse: true,
                itemBuilder: (c, i) => i == 0
                    ? const SizedBox.shrink()
                    : i == palettes.length + 2 - 1
                        ? const SizedBox.shrink()
                        : palettes[i - 1],
                separatorBuilder: (c, i) => Container(height: 16.0),
                itemCount: palettes.length + 2)));
  }
}
