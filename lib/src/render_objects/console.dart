import 'package:flutter/material.dart';

import '../globals.dart';
import '../pages/_page_utils.dart';

import 'navigator.dart';
import '_render_utils.dart';

class ConsoleButton extends StatelessWidget {
  final Extra? extra;
  final String? name;
  final Icon? icon;
  final List<ConsoleButton>? extraButtons;
  final bool isSpecial, isMode, shouldBeDownButIsnt, isActivated, isGreyedOut;
  final void Function() onPress;
  final void Function()? onLongPress;
  final void Function()? onLongPressUp;
  final bool isInverted;
  final BorderRadius? border;

  const ConsoleButton({
    this.extra,
    this.icon,
    this.isInverted = false,
    required this.name,
    required this.onPress,
    this.extraButtons,
    this.isGreyedOut = false,
    this.shouldBeDownButIsnt = false,
    this.isMode = false,
    this.isSpecial = false,
    this.isActivated = true,
    this.onLongPress,
    this.onLongPressUp,
    this.border,
    Key? key,
  }) : super(key: key);

  ConsoleButton invertedColors() => ConsoleButton(
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        isInverted: true,
        isGreyedOut: isGreyedOut,
        extraButtons: extraButtons,
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        isMode: isMode,
        isSpecial: isSpecial,
        isActivated: isActivated,
        key: key,
        border: border,
      );

  ConsoleButton withKey(GlobalKey k) {
    return ConsoleButton(
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        isInverted: true,
        isGreyedOut: isGreyedOut,
        extraButtons: extraButtons,
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        isMode: isMode,
        isSpecial: isSpecial,
        isActivated: isActivated,
        key: k,
        border: border);
  }

  ConsoleButton withExtra(Extra extra, List<ConsoleButton> buttons) {
    return ConsoleButton(
        extra: extra,
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        isInverted: isInverted,
        isGreyedOut: isGreyedOut,
        extraButtons: buttons,
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        isMode: isMode,
        isSpecial: true,
        isActivated: isActivated,
        key: extra.key,
        border: border);
  }

  ConsoleButton withBorder(BorderRadius border, {required GlobalKey k}) =>
      ConsoleButton(
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        isInverted: isInverted,
        border: border,
        isGreyedOut: isGreyedOut,
        extraButtons: extraButtons,
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        isMode: isMode,
        isSpecial: isSpecial,
        isActivated: isActivated,
        key: k,
      );

  void pressButton() {
    if (!isActivated) return;
    if (extra?.show ?? false) {
      extra!.flip();
    } else {
      onPress.call();
    }
  }

  void longPressButton() {
    if (!isActivated) return;
    if (extra != null) {
      extra!.flip();
    } else {
      onLongPress?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (icon == null && name == null) {
      throw 'ConsoleButton error: Either icon or name must not be null';
    }

    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: TouchableOpacity(
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        onPress: pressButton,
        onLongPress: longPressButton,
        onLongPressUp: isActivated ? onLongPressUp : () {},
        child: ColoredBox(
          color: g.theme
              .buttonColor(isActivated: isActivated, isInverted: isInverted),
          child: SizedBox(
            height: Console.buttonHeight,
            child: Center(
              child: icon ??
                  Text(
                    name!,
                    maxLines: 1,
                    style: g.theme.consoleButtonTextStyle(
                      isMode: isMode,
                      isSpecial: isSpecial,
                      isInverted: isInverted,
                      isActivated: isActivated,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
    //});
  }
}

// Could refactor to use Down4Input
class ConsoleInput extends StatelessWidget {
  final List<IconButton>? prefixIcons, suffixIcons;
  final FocusNode? focus;
  final TextInputType type;
  final TextAlign textAlign;
  final bool activated;
  final String placeHolder;
  final String value;
  final String prefix, suffix;
  final int maxLines;
  final void Function(String)? inputCallBack;
  final void Function()? onEditingComplete;
  final TextEditingController tec;
  final bool show;
  final BorderRadius? borderRadius;
  const ConsoleInput({
    this.prefixIcons,
    this.suffixIcons,
    this.textAlign = TextAlign.start,
    this.focus,
    this.borderRadius,
    this.onEditingComplete,
    this.show = true,
    this.type = TextInputType.multiline,
    this.inputCallBack,
    this.maxLines = 1,
    required this.placeHolder,
    required this.tec,
    this.prefix = "",
    this.suffix = "",
    this.value = "",
    this.activated = true,
    Key? key,
  }) : super(key: key);

  bool get isMultiLine => maxLines > 1;

  ConsoleInput withRadius(BorderRadius radius) {
    return ConsoleInput(
      borderRadius: radius,
      focus: focus,
      type: type,
      placeHolder: placeHolder,
      tec: tec,
      activated: activated,
      value: value,
      maxLines: maxLines,
      prefix: prefix,
      suffix: suffix,
      onEditingComplete: onEditingComplete,
      inputCallBack: inputCallBack,
      show: show,
    );
  }

  ConsoleInput animated({required bool show}) {
    return ConsoleInput(
      focus: focus,
      borderRadius: borderRadius,
      type: type,
      onEditingComplete: onEditingComplete,
      placeHolder: placeHolder,
      tec: tec,
      activated: activated,
      value: value,
      maxLines: maxLines,
      prefix: prefix,
      suffix: suffix,
      inputCallBack: inputCallBack,
      show: show,
    );
  }

  Widget get activatedField {
    return Center(
      child: TextField(
        controller: tec,
        focusNode: focus,
        cursorColor: g.theme.cursorColor,
        key: GlobalKey(),
        maxLines: maxLines,
        minLines: 1,
        style: g.theme.inputTextStyle,
        onEditingComplete: onEditingComplete,
        keyboardType: type,
        textAlign: textAlign,
        decoration: InputDecoration.collapsed(
          hintText: placeHolder,
          border: InputBorder.none,
          hintStyle: g.theme.inputTextStyle,
        ),
        textDirection: TextDirection.ltr,
        onChanged: inputCallBack,
      ),
    );
  }

  Widget get unactivatedField {
    return Center(child: Text(placeHolder));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(vertical: Console.buttonHeight / 4),
        constraints: BoxConstraints(minHeight: Console.buttonHeight),
        child: DecoratedBox(
            decoration: BoxDecoration(
                color: g.theme.inputColor,
                borderRadius: const BorderRadius.all(Radius.circular(15))),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: activated ? activatedField : unactivatedField)));
  }
}

class InitInput2 extends StatelessWidget {
  final MyTextEditor ed;
  const InitInput2(this.ed, {Key? key}) : super(key: key);

  static double get initInputHeight => g.sizes.h * 0.054;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: !ed.fn.hasFocus
            ? () {
                FocusScope.of(context).requestFocus(ed.fn);
              }
            : null,
        child: SizedBox(
            height: initInputHeight,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: g.theme.inputColor,
                    borderRadius:
                        BorderRadius.all(Radius.circular(initInputHeight / 2))),
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                        alignment: AlignmentDirectional.center, child: ed)))));
  }
}

class ConsoleInput2 extends StatelessWidget {
  final MyTextEditor ed;
  const ConsoleInput2(this.ed, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: !ed.fn.hasFocus
            ? () {
                FocusScope.of(context).requestFocus(ed.fn);
              }
            : null,
        child: Container(
            color: g.theme.buttonColor(isActivated: true, isInverted: false),
            padding: EdgeInsets.symmetric(vertical: Console.buttonHeight / 4),
            constraints: BoxConstraints(minHeight: Console.buttonHeight),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: g.theme.inputColor,
                    borderRadius: const BorderRadius.all(Radius.circular(15))),
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                        alignment: ed.centered
                            ? AlignmentDirectional.center
                            : AlignmentDirectional.topStart,
                        child: ed)))));
  }
}

class BasicInput extends StatelessWidget {
  final MyTextEditor ed;
  const BasicInput(this.ed, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: !ed.fn.hasFocus
            ? () => FocusScope.of(context).requestFocus(ed.fn)
            : null,
        child: Align(alignment: AlignmentDirectional.topStart, child: ed));
  }
}

class SnipInput extends StatelessWidget {
  final MyTextEditor ed;
  const SnipInput(this.ed, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: !ed.fn.hasFocus
            ? () => FocusScope.of(context).requestFocus(ed.fn)
            : null,
        child: Center(
            child: Container(
                width: g.sizes.w,
                height: ed.height,
                color: g.theme.snipRibbon,
                child: Align(
                  alignment: AlignmentDirectional.center,
                  child: ed,
                ))));
  }
}

class ConsoleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final AlignmentDirectional align;
  final TextAlign textAlign;
  const ConsoleText({
    required this.align,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: align,
      child: Text(
        text,
        style: style ?? g.theme.consoleTextStyle,
        textAlign: textAlign,
      ),
    );
  }
}

class ConsoleRow {
  final double? inputMaxHeight;
  final List<Widget> widgets;
  final (Widget, double?)? extension;
  final List<double>? widths;
  const ConsoleRow({
    required this.widgets,
    required this.extension,
    required this.widths,
    required this.inputMaxHeight,
  });
}

class Console {
  static double get consoleGap => 0;
  static double get consoleWidth => g.sizes.w - (2.0 * consoleGap);
  static double get trueWidth => consoleWidth - (4 * borderWidth);
  static double get buttonHeight => g.sizes.h * 0.064;
  static Duration get animationDuration => const Duration(milliseconds: 200);
  static double get consoleRad => 0;
  static double get borderWidth => 0;

  final int currentPageIndex;
  final List<String> currentConsolesName;
  final List<Map<String, ConsoleRow>> rows;

  String get currentConsoleName => currentConsolesName[currentPageIndex];

  List<Widget> get currentWidgets =>
      rows[currentPageIndex][currentConsoleName]!.widgets;

  Iterable<ConsoleButton> get currentButtons =>
      currentWidgets.whereType<ConsoleButton>();

  Widget? get currentExtension =>
      rows[currentPageIndex][currentConsoleName]?.extension?.$1;

  double? get currentExtensionHeight =>
      rows[currentPageIndex][currentConsoleName]?.extension?.$2;

  double get extraButtonsRad => 2.0;

  List<Widget> get extraButtons {
    return currentButtons.map((b) {
      if (b.extra?.show ?? false) {
        final key = b.key as GlobalKey;
        final context = key.currentContext;
        final renderBox = context!.findRenderObject() as RenderBox;
        final Offset position = renderBox.localToGlobal(Offset.zero);
        final semantics = renderBox.semanticBounds;
        final buttonWidth = semantics.width;
        final buttonHeight = semantics.height;

        b.extraButtons!.first = b.extraButtons!.first.withBorder(
            k: GlobalKey(),
            BorderRadius.only(
                topLeft: Radius.circular(Console.consoleRad),
                topRight: Radius.circular(Console.consoleRad)));

        final nButton = b.extraButtons!.length;

        return Positioned(
          left: position.dx - Console.borderWidth,
          top: position.dy -
              // g.sizes.viewPaddingHeight -
              Console.borderWidth -
              (nButton * (buttonHeight)),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              border: Border.all(
                  width: Console.borderWidth,
                  color: g.theme.consoleBorderColor),
              color: g.theme.consoleBorderColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(extraButtonsRad),
                topRight: Radius.circular(extraButtonsRad),
              ),
            ),
            child: AnimatedSize(
              duration: Console.animationDuration,
              child: SizedBox(
                height: b.extra?.show ?? false ? buttonHeight * nButton : 0,
                width: buttonWidth,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: b.extraButtons!),
              ),
            ),
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    }).toList();
  }

  ConsoleRow rowAt(int pageIndex) =>
      rows[pageIndex][currentConsolesName[pageIndex]]!;

  const Console({
    required this.rows,
    required this.currentConsolesName,
    required this.currentPageIndex,
    String? lastConsole,
    int? lastIndex,
    double? fullWidth,
    // Key? key,
  });
  // : super(key: key);

  static Widget staticRow(ConsoleRow r) {
    final defaultWidth = 1 / r.widgets.length;
    final currentHeight = Console.buttonHeight;
    final inputHeight = r.inputMaxHeight;
    return Column(children: [
      AnimatedOpacity(
        opacity: r.extension == null ? 0 : 1,
        duration: Console.animationDuration,
        child: AnimatedContainer(
          duration: Console.animationDuration,
          height: r.extension?.$2 ?? 0,
          child: r.extension?.$1 ?? const SizedBox.shrink(),
        ),
      ),
      Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: r.widgets.indexed.map((e) {
            final i = e.$1;
            final w = e.$2;
            final width = (r.widths?[i] ?? defaultWidth) * g.sizes.w;

            double height;
            if (w is ConsoleButton) {
              height = currentHeight;
            } else {
              height = currentHeight == 0
                  ? currentHeight
                  : inputHeight ?? Console.buttonHeight;
            }

            final Widget w_ = AnimatedContainer(
                duration: Andrew.pageSwitchAnimationDuration,
                width: width,
                height: height,
                child: w);

            return w_;
          }).toList()),
    ]);
  }

  Widget rowOfPage({required int index, bool staticRow = false}) {
    final extension = extensionOfPage(index: index);
    final ex = extension?.$1;
    final h = extension?.$2;
    return AnimatedOpacity(
        duration: Andrew.pageSwitchOpacityDuration,
        opacity: staticRow ? 0 : 1,
        child: ColoredBox(
            color: g.theme.buttonColor(),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedOpacity(
                    opacity: extension == null ? 0 : 1,
                    duration: Console.animationDuration,
                    child: AnimatedContainer(
                        // color: g.theme.buttonColor(),
                        color: g.theme.extensionBackdropColor,
                        duration: Console.animationDuration,
                        height: h ?? 0,
                        child: ex // Stack(
                        //   children: [
                        //     AnimatedContainer(
                        //         alignment: AlignmentDirectional.topCenter,
                        //         duration: Console.animationDuration,
                        //         width: g.sizes.w,
                        //         height: h ?? 0,
                        //         color: g.theme.extensionBackdropColor,
                        //         child: ex ?? const SizedBox.shrink()),
                        //     IgnorePointer(
                        //       child: Row(
                        //         children: [
                        //           AnimatedContainer(
                        //             duration: Console.animationDuration,
                        //             width: extension == null ? g.sizes.w / 2 : 0,
                        //             color: g.theme.buttonColor(),
                        //           ),
                        //           AnimatedContainer(
                        //             duration: Console.animationDuration,
                        //             width: extension == null ? 0 : g.sizes.w,
                        //             color: Colors.transparent,
                        //           ),
                        //           AnimatedContainer(
                        //             duration: Console.animationDuration,
                        //             width: extension == null ? g.sizes.w / 2 : 0,
                        //             color: g.theme.buttonColor(),
                        //           ),
                        //         ],
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        ),
                  ),
                  ...rows[index]
                      .map((name, c) {
                        double currentHeight;
                        if (currentConsolesName.contains(name)) {
                          currentHeight = buttonHeight;
                        } else {
                          currentHeight = 0;
                        }

                        final defaultWidth = 1 / c.widgets.length;
                        final inputHeight = c.inputMaxHeight;

                        final row = Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: c.widgets.indexed.map((e) {
                            final i = e.$1;
                            final w = e.$2;

                            final width =
                                (c.widths?[i] ?? defaultWidth) * g.sizes.w;

                            double height;
                            if (w is ConsoleButton) {
                              height = currentHeight;
                            } else {
                              height = currentHeight == 0
                                  ? currentHeight
                                  : inputHeight ?? Console.buttonHeight;
                            }

                            final Widget w_ = AnimatedContainer(
                                duration: Andrew.pageSwitchAnimationDuration,
                                width: width,
                                height: height,
                                child: w);

                            return w_;
                          }).toList(),
                        );

                        return MapEntry(name, row);
                      })
                      .values
                      .toList(),
                ])));
  }

  (Widget, double?)? extensionOfPage({required int index}) {
    return rows[index][currentConsolesName[index]]?.extension;
  }
}
