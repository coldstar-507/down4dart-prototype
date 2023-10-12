import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';

import '../data_objects/_data_utils.dart';
import '../data_objects/nodes.dart';
import '../globals.dart';

class BasicActionButton2 extends StatelessWidget {
  final ButtonsInfo2 bi;
  const BasicActionButton2({required this.bi, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: bi.pressFunc,
      onLongPress: bi.longPressFunc,
      child: Container(
          height: Palette.paletteHeight,
          width: Palette.paletteHeight,
          padding: const EdgeInsets.all(6.0),
          decoration: BoxDecoration(
              borderRadius: bi.rightMost
                  ? const BorderRadius.only(
                      topRight: Radius.circular(4.0),
                      bottomRight: Radius.circular(4.0))
                  : null),
          child: bi.asset),
    );
  }
}

extension DeactivateButtons on Iterable<ButtonsInfo2> {
  List<ButtonsInfo2> thatDoesNothing() =>
      map((b) => b.thatDoesNothing()).toList();
}

class ButtonsInfo2 {
  final Widget asset;
  final void Function() pressFunc;
  final void Function()? longPressFunc;
  final bool rightMost;
  ButtonsInfo2({
    required this.asset,
    required this.pressFunc,
    this.rightMost = true,
    this.longPressFunc,
  });

  ButtonsInfo2 thatDoesNothing() => ButtonsInfo2(
        asset: asset,
        pressFunc: () {},
        rightMost: rightMost,
      );
}


class Palette<T extends PaletteN> extends StatelessWidget
    with Down4Object, Down4Widget, Down4SelectionWidget {
  static double get padding => 10;
  static double get paletteRadius => fullHeight / 2;
  static double get paletteHeight => (g.sizes.h * 0.1212);
  static Size get paletteSquare => Size(paletteHeight, paletteHeight);
  static double get gapSize => g.sizes.h * 0.0119;
  static double get paletteMargin => g.sizes.w * 0.042;
  static double get blurRadius => 6.0;
  static Size get imageSize => Size.square(fullHeight - (padding * 2));
  static double get spreadRadius => -7.0;
  static double get fullHeight => paletteHeight + gapSize;
  static Offset get shadowOffset => const Offset(6.0, 6.0);
  static Color get shadowColor => Colors.black.withOpacity(0.66);

  @override
  Down4ID get id => node.id;
  final Widget _image;

  @override
  final bool selected;

  @override
  final void Function()? select;
  final T node;
  final bool show;
  final void Function()? imPress, imLongPress, bodyPress, bodyLongPress;
  final List<ButtonsInfo2> buttonsInfo2;
  final String? messagePreview;
  final Animation<double>? sizeAnim, fadeAnim, bFadeAnim;

  Palette({
    required this.node,
    this.sizeAnim,
    this.fadeAnim,
    this.bFadeAnim,
    this.show = true,
    this.messagePreview,
    this.buttonsInfo2 = const [],
    this.select,
    this.imPress,
    this.bodyPress,
    this.imLongPress,
    this.bodyLongPress,
    this.selected = false,
    required Key? key,
  })  : _image = node.nodeImage(Size.square(fullHeight - (2 * padding))),
        super(key: key);

  @override
  Palette invertedSelection() {
    return Palette(
      key: GlobalKey(),
      node: node,
      show: show,
      fadeAnim: fadeAnim,
      bFadeAnim: bFadeAnim,
      sizeAnim: sizeAnim,
      messagePreview: messagePreview,
      buttonsInfo2: buttonsInfo2,
      select: select,
      imPress: imPress,
      bodyPress: bodyPress,
      imLongPress: imLongPress,
      bodyLongPress: bodyLongPress,
      selected: !selected,
    );
  }

  Palette invertedShow() {
    return Palette(
      key: GlobalKey(),
      node: node,
      show: !show,
      fadeAnim: fadeAnim,
      bFadeAnim: bFadeAnim,
      sizeAnim: sizeAnim,
      messagePreview: messagePreview,
      buttonsInfo2: buttonsInfo2,
      select: select,
      imPress: imPress,
      bodyPress: bodyPress,
      imLongPress: imLongPress,
      bodyLongPress: bodyLongPress,
      selected: !selected,
    );
  }

  Widget get buttons => bFadeAnimWrapper(
          child: Row(
        children: buttonsInfo2.map((bi) => BasicActionButton2(bi: bi)).toList(),
      ));

  Widget sizeAnimWrapper({required Widget child}) {
    if (sizeAnim == null) return Container(child: child);
    return SizeTransition(sizeFactor: sizeAnim!, child: child);
  }

  Widget fadeAnimWrapper({required Widget child}) {
    if (fadeAnim == null) return Container(child: child);
    return FadeTransition(opacity: fadeAnim!, child: child);
  }

  Widget bFadeAnimWrapper({required Widget child}) {
    if (bFadeAnim == null) return Container(child: child);
    return FadeTransition(opacity: bFadeAnim!, child: child);
  }

  Widget mainContainer({required Widget child}) {
    return ColoredBox(
      color: g.theme.backGroundColor,
      child: sizeAnimWrapper(
        child: Container(
          height: Palette.fullHeight,
          padding: EdgeInsets.all(Palette.padding / 2),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(5)),
                color: g.theme.paletteColor),
            child: Container(
              padding: EdgeInsets.all(Palette.padding / 2),
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  color: selected
                      ? g.theme.paletteSelectionOverlayColor
                      : Colors.transparent),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget imageContainer({required Widget image}) {
    return GestureDetector(
        onTap: imPress,
        onLongPress: imLongPress,
        child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            child: image));
  }

  Widget get body => Expanded(
        child: GestureDetector(
          onTap: bodyPress,
          behavior: HitTestBehavior.opaque,
          onLongPress: bodyLongPress,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8, top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(node.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: g.theme.paletteNameStyle(selected: selected)),
                Text(node.displayID,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: g.theme.paletteIDTextStyle(
                        selected: selected, color: node.color)),
                const Spacer(),
                messagePreview != null
                    ? Text(messagePreview!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style:
                            g.theme.palettePreviewTextStyle(selected: selected))
                    : const SizedBox.shrink()
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return fadeAnimWrapper(
      child: mainContainer(
        child: Row(
          children: [
            imageContainer(image: _image),
            body,
            buttons,
          ],
        ),
      ),
    );
  }
}
