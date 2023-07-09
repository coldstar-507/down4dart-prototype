import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:down4/src/render_objects/chat_message.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data_objects/couch.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';

import '../globals.dart';
import '../pages/_page_utils.dart';

import 'navigator.dart';
import 'palette.dart';
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
    // this.flex = 1,
    // this.width,
    // this.maxWidth,
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
        // flex: flex,
        // width: width,
        // maxWidth: maxWidth,
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        isInverted: true,
        isGreyedOut: isGreyedOut,
        extraButtons: extraButtons,
        // showExtra: showExtra,
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
        // showExtra: showExtra,
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
        // flex: flex,
        // maxWidth: maxWidth,
        // width: width,
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        isInverted: isInverted,
        border: border,
        isGreyedOut: isGreyedOut,
        extraButtons: extraButtons,
        // showExtra: showExtra,
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
  }
}

// Could refactor to use Down4Input
class ConsoleInput extends StatelessWidget {
  // final int flex;
  // final double? width, maxWidth;
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
    // this.width,
    // this.maxWidth,
    // this.flex = 1,
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
      // width: width,
      // maxWidth: maxWidth,
      // flex: flex,
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
      // width: width,
      // maxWidth: maxWidth,
      // flex: flex,
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
      child:
          // EditableText(
          //     controller: tec,
          //     focusNode: focus!,
          //     backgroundCursorColor: Colors.white,
          //     minLines: 1,
          //     maxLines: 8,
          //     // expands: true,
          //     onChanged: inputCallBack,
          //     style: g.theme.inputTextStyle,
          //     cursorColor: Colors.white54)
          TextField(
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: !ed.fn.hasFocus
            ? () {
                FocusScope.of(context).requestFocus(ed.fn);
              }
            : null,
        child: SizedBox(
            // padding: const EdgeInsets.symmetric(horizontal: 30),
            height: Console.buttonHeight,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: g.theme.inputColor,
                    borderRadius: BorderRadius.all(
                        Radius.circular(Console.buttonHeight / 2))),
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
    // if (ed.fn.hasFocus) {
    //   return Container(
    //       padding: EdgeInsets.symmetric(vertical: Console.buttonHeight / 4),
    //       constraints: BoxConstraints(minHeight: Console.buttonHeight),
    //       child: DecoratedBox(
    //           decoration: BoxDecoration(
    //               color: g.theme.inputColor,
    //               borderRadius: const BorderRadius.all(Radius.circular(15))),
    //           child: Padding(
    //               padding: const EdgeInsets.symmetric(horizontal: 12),
    //               child: ed)));
    // }

    return GestureDetector(
        onTap: !ed.fn.hasFocus
            ? () {
                // final t = ed.ctrl.config.inputType;
                //
                // if (t == TextInputType.number) {
                //   print("IS NUMBER");
                //   Input2.connection = TextInput.attach(
                //       InputController(config: Input2.numberPad),
                //       Input2.numberPad)
                //     ..show();
                // } else if (t == TextInputType.multiline) {
                //   print("IS MULTI LINE");
                //   Input2.connection = TextInput.attach(
                //       InputController(config: Input2.multiLine),
                //       Input2.multiLine)
                //     ..show();
                // } else {
                //   print("IS SINGLE LINE");
                //   Input2.connection = TextInput.attach(
                //       InputController(config: Input2.singleLine),
                //       Input2.singleLine)
                //     ..show();
                // }
                FocusScope.of(context).requestFocus(ed.fn);

                // Future(() async {
                //   await SystemChannels.textInput
                //       .invokeMethod('TextInput.updateConfig', config.toJson());
                //   await SystemChannels.textInput.invokeMethod('TextInput.show');
                // }).then((value) => FocusScope.of(context).requestFocus(ed.fn));
                // if (ed.numberPad) {
                //
                // } else {
                //   SystemChannels.textInput.invokeMethod('TextInput.show');
                //   FocusScope.of(context).requestFocus(ed.fn);
                // }
              }
            : null,
        child: Container(
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
      color: g.theme.buttonColor(isActivated: true, isInverted: false),
      alignment: align,
      child: Text(
        text,
        style: style ?? g.theme.consoleTextStyle,
        textAlign: textAlign,
      ),
    );
  }
}

class ConsoleMedias2 {
  final void Function(Down4Media) onSelect;
  final bool images;
  ConsoleMedias2({required this.images, required this.onSelect});
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? _topButtons;
  final List<Widget> _bottomButtons;
  final List<Widget>? _bottomInputs, _topInputs;
  final bool animatedInputs;

  final Widget? previewMedia;
  final List<dynamic>? forwardingObjects;
  final List<Palette2>? forwardingPalette;
  final bool invertedColors, initializationConsole;
  final ConsoleMedias2? medias;
  final CameraController? cameraController;
  final MobileScanner? scanner;

  static GlobalKey get widgetCaptureKey => GlobalKey();
  List<Widget> get extraButtons => [];

  int get nMediaPerRow => 5;
  int get maximumMediaRows => 3;
  double get rowHeight => consoleWidth / nMediaPerRow; // squared element

  // List<Widget> get extraTopButtons {
  //   List<Widget> extras = [];
  //   for (final b in topConsoleButtons) {
  //     if (b.showExtra) {
  //       final key = b.key as GlobalKey;
  //       final renderBox = key.currentContext!.findRenderObject() as RenderBox;
  //       // final RenderBox renderBox = b.renderBox as RenderBox;
  //       final semantics = renderBox.semanticBounds;
  //       final buttonWidth = semantics.width;
  //       final leftBottom = semantics.bottomLeft;
  //
  //       extras.add(Positioned(
  //         bottom: leftBottom.dy - borderWidth,
  //         left: leftBottom.dx - borderWidth,
  //         child: Container(
  //           width: buttonWidth + borderWidth,
  //           decoration: BoxDecoration(
  //               border: Border.all(
  //                   width: borderWidth, color: g.theme.consoleBorderColor)),
  //           child: Column(children: b.extraButtons!),
  //         ),
  //       ));
  //     } else {
  //       extras.add(const SizedBox.shrink());
  //     }
  //   }
  //   return extras;
  // }

  int get nConsoleLayers {
    int n = 1;
    if (_topButtons != null) n++;
    if (_bottomInputs != null) n++;
    if (_topInputs != null) n++;
    return n;
  }

  // List<Widget> get extraBottomButtons {
  //   return bottomConsoleButtons.map((b) {
  //     if (b is ConsoleButton && b.showExtra) {
  //       final key = b.key as GlobalKey;
  //       final context = key.currentContext;
  //       final renderBox = context!.findRenderObject() as RenderBox;
  //       final Offset position = renderBox.localToGlobal(Offset.zero);
  //       final semantics = renderBox.semanticBounds;
  //       final buttonWidth = semantics.width;
  //       final buttonHeight = semantics.height;
  //
  //       b.extraButtons!.first = b.extraButtons!.first.withBorder(
  //           k: GlobalKey(),
  //           BorderRadius.only(
  //               topLeft: Radius.circular(Console.consoleRad),
  //               topRight: Radius.circular(Console.consoleRad)));
  //
  //       final nButton = b.extraButtons!.length;
  //
  //       return Positioned(
  //         left: position.dx - borderWidth,
  //         top: position.dy -
  //             g.sizes.viewPaddingHeight -
  //             borderWidth -
  //             (nButton * (buttonHeight)),
  //         child: Container(
  //           clipBehavior: Clip.hardEdge,
  //           decoration: BoxDecoration(
  //             border: Border.all(
  //                 width: borderWidth, color: g.theme.consoleBorderColor),
  //             color: g.theme.consoleBorderColor,
  //             borderRadius: BorderRadius.only(
  //               topLeft: Radius.circular(Console.consoleRad),
  //               topRight: Radius.circular(Console.consoleRad),
  //               // topLeft: Radius.circular(nExtraButtons == nConsoleLayers - 1
  //               //     ? Console.consoleRad
  //               //     : 0),
  //               // topRight: Radius.circular(nExtraButtons > nConsoleLayers - 1
  //               //     ? Console.consoleRad
  //               //     : 0),
  //             ),
  //           ),
  //           child: AnimatedSize(
  //             duration: Console.animationDuration,
  //             child: SizedBox(
  //               height: b.showExtra ? buttonHeight * nButton : 0,
  //               width: buttonWidth,
  //               child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.stretch,
  //                   children: b.extraButtons!),
  //             ),
  //           ),
  //         ),
  //       );
  //     } else {
  //       return const SizedBox.shrink();
  //     }
  //   }).toList();
  // }

  static double get consoleRad => 0; //10;

  static double get buttonHeight => g.sizes.h * 0.064;

  bool get bottomButtonsHasTop =>
      _topButtons != null ||
      _bottomInputs != null ||
      _topButtons != null ||
      hasGadgets;

  bool get topButtonsHasTop =>
      _bottomInputs != null || _topInputs != null || hasGadgets;

  static double get consoleGap => 0; //g.sizes.w * 0.015;
  static double get borderWidth => 0; //.6;
  // static Color get borderColor => Colors.black45;
  static double get consoleWidth => g.sizes.w - (2.0 * consoleGap);
  static double get trueWidth => consoleWidth - (4 * borderWidth);
  static double get bbWidth => consoleWidth - (2 * borderWidth);

  bool get bottomInputsHasTop => _topInputs != null;

  static Duration get animationDuration => const Duration(milliseconds: 200);

  bool get hasGadgets =>
      previewMedia != null ||
      // imageForPreview != null ||
      // videoForPreview != null ||
      cameraController != null ||
      // forwardingObjects != null ||
      scanner != null ||
      medias != null;

  final String? name;

  // final Console3? consoleRow;

  const Console({
    // this.consoleRow,
    this.name,
    required List<Widget> bottomButtons,
    this.invertedColors = false,
    this.forwardingPalette,
    this.previewMedia,
    this.forwardingObjects,
    this.cameraController,
    this.initializationConsole = false,
    this.scanner,
    this.animatedInputs = true,
    this.medias,
    List<Widget>? bottomInputs,
    List<Widget>? topInputs,
    List<ConsoleButton>? topButtons,
    Key? key,
  })  : _topInputs = topInputs,
        _bottomInputs = bottomInputs, // _cameraController = cameraController,
        _bottomButtons = bottomButtons,
        _topButtons = topButtons,
        super(key: key);

  Future<Uint8List?> captureWidget() async {
    final RenderRepaintBoundary? boundary = widgetCaptureKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ui.Image image = await boundary.toImage();
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  Widget widgetCapture({required Widget child}) {
    return RepaintBoundary(key: widgetCaptureKey, child: child);
  }

  // List<ConsoleInput> get topConsoleInputs =>
  //     _topInputs
  //         ?.map((input) => input.animated(show: !hasGadgets))
  //         .toList()
  //         .asMap()
  //         .map((i, e) => MapEntry(
  //             i,
  //             e.withRadius(BorderRadius.only(
  //               topLeft: Radius.circular(i == 0 ? consoleRad : 0),
  //               topRight: Radius.circular(
  //                   i == _topInputs!.length - 1 ? consoleRad : 0),
  //               bottomLeft: const Radius.circular(0),
  //               bottomRight: const Radius.circular(0),
  //             ))))
  //         .values
  //         .toList(growable: false) ??
  //     [];
  //
  // List<ConsoleInput> get bottomConsoleInputs =>
  //     _bottomInputs
  //         ?.map((input) => input.animated(show: !hasGadgets))
  //         .toList()
  //         .asMap()
  //         .map((i, e) => MapEntry(
  //             i,
  //             e.withRadius(BorderRadius.only(
  //               topLeft: Radius.circular(
  //                   !bottomInputsHasTop && i == 0 ? consoleRad : 0),
  //               topRight: Radius.circular(
  //                   !bottomInputsHasTop && i == _bottomInputs!.length - 1
  //                       ? consoleRad
  //                       : 0),
  //               bottomLeft: const Radius.circular(0),
  //               bottomRight: const Radius.circular(0),
  //             ))))
  //         .values
  //         .toList(growable: false) ??
  //     [];

  int get mediaPerRow => 5;

  double get mediaCelSize => trueWidth / mediaPerRow;

  Widget consoleMedias() {
    if (medias == null) return const SizedBox.shrink();
    final ids = medias!.images ? g.savedImageIDs : g.savedVideoIDs;
    final nRows = (ids.length / mediaPerRow).ceil();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(consoleRad)),
          color: g.theme.consoleBorderColor,
          border: Border.all(
              color: g.theme.consoleBorderColor, width: borderWidth)),
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: maximumMediaRows * mediaCelSize, maxWidth: trueWidth),
          child: ListView.builder(
              itemCount: nRows,
              itemBuilder: ((context, index) {
                Widget f(int i) {
                  if (i < ids.length) {
                    final cachedMedia = cache<Down4Media>(ids[i]);
                    if (cachedMedia != null) {
                      return GestureDetector(
                          onTap: () => medias!.onSelect(cachedMedia),
                          child: (cachedMedia.display(
                              size: Size.square(mediaCelSize),
                              forceSquare: true)));
                    }
                    return FutureBuilder(
                      future: global<Down4Media>(ids[i]),
                      builder: (ctx, ans) {
                        if (ans.connectionState == ConnectionState.done &&
                            ans.hasData) {
                          return GestureDetector(
                              onTap: () => ans.data != null
                                  ? medias!.onSelect(ans.data!)
                                  : null,
                              child: (ans.requireData?.display(
                                      size: Size.square(mediaCelSize),
                                      forceSquare: true)) ??
                                  SizedBox.square(dimension: mediaCelSize));
                        } else {
                          return SizedBox.square(dimension: mediaCelSize);
                        }
                      },
                    );
                  } else {
                    return SizedBox.square(dimension: mediaCelSize);
                  }
                }

                return Row(
                  key: Key(medias!.images.toString() + index.toString()),
                  children: [
                    f((index * 5)),
                    f((index * 5) + 1),
                    f((index * 5) + 2),
                    f((index * 5) + 3),
                    f((index * 5) + 4)
                  ],
                );
              }))),
    );
  }

  Widget forwardingPalettes() {
    if (forwardingObjects == null) return const SizedBox.shrink();

    Widget individualObject(Down4Object obj) {
      if (obj is Palette2) {
        return Flexible(
            child: Container(
                height: buttonHeight,
                decoration: BoxDecoration(
                    color: obj.node.color,
                    border: Border.all(
                        width: borderWidth, color: g.theme.consoleBorderColor)),
                child: Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          width: Console.buttonHeight,
                          height: Console.buttonHeight,
                          child: obj.node
                              .nodeImage(Size.square(Console.buttonHeight))),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                obj.node.displayName,
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                              )))
                    ])));
      } else if (obj is ChatMessage) {
        return Expanded(
            child: Container(
                padding: const EdgeInsets.all(4.0),
                height: buttonHeight,
                decoration: BoxDecoration(
                    color: obj.messageColor,
                    border: Border.all(
                        width: borderWidth, color: g.theme.consoleBorderColor)),
                child: Text(
                    (obj.message.text ?? "").isEmpty
                        ? "&attachment"
                        : obj.message.text!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)));
      }

      return const SizedBox.shrink();
    }

    return SizedBox(
        height: buttonHeight + (2 * borderWidth),
        width: trueWidth + (2 * borderWidth),
        child: Row(
            textDirection: TextDirection.ltr,
            children:
                forwardingObjects!.map((e) => individualObject(e)).toList()));
  }

  Widget consoleCamera() {
    final camCtrl = cameraController;
    if (camCtrl == null) return const SizedBox.shrink();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(consoleRad)),
          color: g.theme.consoleBorderColor,
          border: Border.all(
              color: g.theme.consoleBorderColor, width: borderWidth)),
      child: SizedBox.square(
          dimension: trueWidth,
          child: Transform.scale(
              scaleY: camCtrl.value.aspectRatio,
              child: CameraPreview(camCtrl))),
    );
  }

  Widget mediaPreview() {
    if (previewMedia == null) return const SizedBox.shrink();
    return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(consoleRad)),
            border: Border.all(
                color: g.theme.consoleBorderColor, width: borderWidth)),
        child: previewMedia!);
  }

  // Widget get rotatingLogo {
  //   return AnimatedRotation(
  //       turns: math.pi * 2,
  //       duration: const Duration(seconds: 2),
  //       child: down4Logo(trueWidth));
  // }

  Widget consoleScanner() {
    if (scanner == null) return const SizedBox.shrink();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(consoleRad)),
          border: Border.all(
              width: borderWidth, color: g.theme.consoleBorderColor)),
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              height: trueWidth,
              width: trueWidth,
              child: scanner!,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get bottomConsoleButtons {
    return _bottomButtons
        .asMap()
        .map((i, value) {
          if (value is ConsoleButton) {
            return MapEntry(
                i,
                value.withBorder(
                    k: bottomButtonsKey[i],
                    BorderRadius.only(
                      topLeft: Radius.circular(
                          !bottomButtonsHasTop && i == 0 ? consoleRad : 0),
                      topRight: Radius.circular(
                          !bottomButtonsHasTop && i == _bottomButtons.length - 1
                              ? 6
                              : 0),
                      bottomLeft: Radius.circular(i == 0 ? consoleRad : 0),
                      bottomRight: Radius.circular(
                          i == _bottomButtons.length - 1 ? consoleRad : 0),
                    )));
          } else {
            return MapEntry(i, value);
          }
        })
        .values
        .toList(growable: false);
  }

  //   return invertedColors
  //       ? _bottomButtons
  //           .map((e) => e.invertedColors())
  //           .toList()
  //           .asMap()
  //           .map((i, value) => MapEntry(
  //               i,
  //               value.withBorder(
  //                   k: bottomButtonsKey[i],
  //                   BorderRadius.only(
  //                     topLeft: Radius.circular(
  //                         !bottomButtonsHasTop && i == 0 ? consoleRad : 0),
  //                     topRight: Radius.circular(
  //                         !bottomButtonsHasTop && i == _bottomButtons.length - 1
  //                             ? 6
  //                             : 0),
  //                     bottomLeft: Radius.circular(i == 0 ? consoleRad : 0),
  //                     bottomRight: Radius.circular(
  //                         i == _bottomButtons.length - 1 ? consoleRad : 0),
  //                   ))))
  //           .values
  //           .toList(growable: false)
  //       : _bottomButtons
  //           .asMap()
  //           .map((i, value) => MapEntry(
  //               i,
  //               value.withBorder(
  //                   k: bottomButtonsKey[i],
  //                   BorderRadius.only(
  //                     topLeft: Radius.circular(
  //                         !bottomButtonsHasTop && i == 0 ? consoleRad : 0),
  //                     topRight: Radius.circular(
  //                         !bottomButtonsHasTop && i == _bottomButtons.length - 1
  //                             ? 6
  //                             : 0),
  //                     bottomLeft: Radius.circular(i == 0 ? consoleRad : 0),
  //                     bottomRight: Radius.circular(
  //                         i == _bottomButtons.length - 1 ? consoleRad : 0),
  //                   ))))
  //           .values
  //           .toList(growable: false);
  // }

  List<ConsoleButton> get topConsoleButtons => invertedColors
      ? (_topButtons ?? [])
          .map((e) => e.invertedColors())
          .toList()
          .asMap()
          .map((i, value) => MapEntry(
              i,
              value.withBorder(
                  k: topButtonsKey[i],
                  BorderRadius.only(
                    topLeft: Radius.circular(
                        !topButtonsHasTop && i == 0 ? consoleRad : 0),
                    topRight: Radius.circular(
                        !topButtonsHasTop && i == _topButtons!.length - 1
                            ? consoleRad
                            : 0),
                    bottomLeft: const Radius.circular(0),
                    bottomRight: const Radius.circular(0),
                  ))))
          .values
          .toList(growable: false)
      : (_topButtons ?? [])
          .asMap()
          .map((i, value) => MapEntry(
              i,
              value.withBorder(
                  k: topButtonsKey[i],
                  BorderRadius.only(
                    topLeft: Radius.circular(
                        !topButtonsHasTop && i == 0 ? consoleRad : 0),
                    topRight: Radius.circular(
                        !topButtonsHasTop && i == _topButtons!.length - 1
                            ? consoleRad
                            : 0),
                    bottomLeft: const Radius.circular(0),
                    bottomRight: const Radius.circular(0),
                  ))))
          .values
          .toList(growable: false);

  Widget get anyGadgets {
    return AnimatedSize(
        duration: animationDuration,
        curve: Curves.easeInOut,
        child: Column(
          children: [
            consoleScanner(),
            consoleCamera(),
            mediaPreview(),
            // imagePreview(),
            // videoPreview(),
            // forwardingPalettes(),
            consoleMedias(),
          ],
        ));
  }

  Widget get staticInputs {
    return Column(
      children: [
        Row(children: _topInputs ?? []),
        Row(children: _bottomInputs ?? [])
      ],
    );
  }

  Widget get inputs {
    return Row(children: _bottomInputs ?? []);
    //   Column(
    //   mainAxisSize: MainAxisSize.min,
    //   mainAxisAlignment: MainAxisAlignment.end,
    //   children: [
    //     Row(children: topConsoleInputs),
    //     Row(children: bottomConsoleInputs),
    //   ],
    // );
  }

  Widget get buttons {
    return Column(
      children: [
        Row(textDirection: TextDirection.ltr, children: topConsoleButtons),
        Row(
          textDirection: TextDirection.ltr,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: bottomConsoleButtons,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      margin: EdgeInsets.only(
        left: consoleGap,
        right: consoleGap,
        bottom: consoleGap,
      ),
      decoration: BoxDecoration(
          color: g.theme.consoleBorderColor,
          borderRadius: BorderRadius.all(Radius.circular(consoleRad)),
          border: Border.all(
              width: borderWidth, color: g.theme.consoleBorderColor)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // inputs and gadgets are programmed so only inputs or a gadget can
          // be viewed at once. They are animated in a way that opening a gadget
          // (like camera for example) will squeeze the input and vice-versa
          // current gadets are camera, media preview after taking picture or
          // video from said camera, and the saved medias
          animatedInputs ? inputs : staticInputs,
          anyGadgets,
          forwardingPalettes(),
          buttons,
          // consoleRow ?? const SizedBox.shrink(),
        ],
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

class Console3 extends StatelessWidget {
  final int currentPageIndex;
  // final int? previousPageIndex;
  final List<String> currentConsolesName;
  // final String currentConsoleName;
  // final String? previousConsoleName;
  final List<Map<String, ConsoleRow>> rows;

  // final double fullWidth;
  // final List<Widget>? forwardingObjects;
  // final List<double>? beginSizes, endSizes;

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
              g.sizes.viewPaddingHeight -
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
                // topLeft: Radius.circular(nExtraButtons == nConsoleLayers - 1
                //     ? Console.consoleRad
                //     : 0),
                // topRight: Radius.circular(nExtraButtons > nConsoleLayers - 1
                //     ? Console.consoleRad
                //     : 0),
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

  // late List<Map<String, (List<double>, List<double>)>> _sizes;

  // final List<Widget> widgets;
  // final AnimationController? ctrl;

  const Console3({
    required this.rows,
    // required String currentConsole,
    required this.currentConsolesName,
    required this.currentPageIndex,
    String? lastConsole,
    int? lastIndex,
    // required List<Widget> widgets,
    // this.forwardingObjects,
    // double? maxHeight,
    // this.beginSizes,
    // this.endSizes,
    // this.ctrl,
    double? fullWidth,
    Key? key,
  })
  // previousConsoleName = lastConsole ?? currentConsole,
  // previousPageIndex = lastIndex ?? currentPageIndex,
  // widgets = widgets
  //     .asMap()
  //     .map((i, w) {
  //       Widget w_;
  //       if (w is ConsoleButton) {
  //         w_ = w.withKey(bottomButtonsKey[i]);
  //       } else if (w is ConsoleInput2) {
  //         w_ = AnimatedContainer(
  //             duration: const Duration(milliseconds: 100),
  //             height: maxHeight ?? Console.buttonHeight,
  //             child: w);
  //       } else {
  //         w_ = w;
  //       }
  //       return MapEntry(i, w_);
  //     })
  //     .values
  //     .toList(),
  : super(key: key);
  // {
  //   int i = 0;
  //   for (var (k, e) in consoles.indexed) {
  //     for (var j in e.entries) {
  //       for (var w in j.value.widgets) {
  //         if (w is ConsoleButton) {
  //           w = w.withKey(bottomButtonsKey[i]);
  //         } else if (w is ConsoleInput2) {
  //           w = AnimatedContainer(
  //               duration: const Duration(milliseconds: 100),
  //               height: maxHeight ?? Console.buttonHeight,
  //               child: w);
  //           i++;
  //         }
  //         i++;
  //       }
  //       i++;
  //     }
  //   }
  // consoles.forEach((element) {
  //   element.forEach((key, value) {
  //     value.widgets.forEach((element) {
  //       Widget w_;
  //       if (w is ConsoleButton) {
  //         w_ = w.withKey(bottomButtonsKey[i]);
  //       } else if (w is ConsoleInput2) {
  //         w_ = AnimatedContainer(
  //             duration: const Duration(milliseconds: 100),
  //             height: maxHeight ?? Console.buttonHeight,
  //             child: w);
  //       } else {
  //         w_ = w;
  //       }
  //     })
  //
  //     return MapEntry(i, w_);
  //   })
  // })
  // }

  // double get currentConsoleHeight =>
  //     Tween<double>(begin: 0.0, end: Console.buttonHeight).animate(ctrl!).value;
  // double get unactivatedConsoleHeight =>
  //     Tween<double>(begin: Console.buttonHeight, end: 0.0).animate(ctrl!).value;

  // double currentConsoleButtonWidth(double maxWidth) =>
  //     Tween<double>(begin: 0.0, end: g.sizes.w * maxWidth).animate(ctrl!).value;
  // double notCurrentConsoleButtonWidth(double maxWidth) =>
  //     Tween<double>(begin: g.sizes.w * maxWidth, end: 0.0).animate(ctrl!).value;

  // late final List<double> sizes = widgets
  //     .asMap()
  //     .map((i, w) {
  //       if (ctrl != null) {
  //         return MapEntry(
  //             i,
  //             Tween<double>(
  //                     begin: fullWidth * beginSizes![i],
  //                     end: fullWidth * endSizes![i])
  //                 .animate(ctrl!)
  //                 .value);
  //       } else {
  //         return MapEntry(
  //             i, fullWidth * (beginSizes?[i] ?? (1 / widgets.length)));
  //       }
  //     })
  //     .values
  //     .toList();

  Widget rowOfPage({required int index}) {
    final extension = extensionOfPage(index: index);
    final ex = extension?.$1;
    final h = extension?.$2;
    return Column(children: [
      AnimatedOpacity(
        opacity: extension == null ? 0 : 1,
        duration: Console.animationDuration,
        child: AnimatedContainer(
          duration: Console.animationDuration,
          height: h ?? 0,
          // constraints: BoxConstraints(
          //     maxHeight: currentExtension == null ? 0 : g.sizes.w),
          child: ex ?? const SizedBox.shrink(),
        ),
      ),
      ...rows[index]
          .map((name, c) {
            double currentHeight;
            if (currentConsolesName.contains(name)) {
              currentHeight = Console.buttonHeight;
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

                final width = (c.widths?[i] ?? defaultWidth) * g.sizes.w;

                double height;
                if (w is ConsoleButton) {
                  height = currentHeight;
                } else {
                  height = currentHeight == 0
                      ? currentHeight
                      : inputHeight ?? Console.buttonHeight;
                }

                final Widget w_ = AnimatedOpacity(
                    duration: Andrew.pageSwitchOpacityDuration,
                    opacity: 1, // ci == currentPageIndex ? 1 : 0,
                    child: AnimatedContainer(
                        duration: Andrew.pageSwitchAnimationDuration,
                        width: width,
                        height: height,
                        child: w));

                return w_;
              }).toList(),
            );

            return MapEntry(name, row);
          })
          .values
          .toList(),
    ]);
  }

  (Widget, double?)? extensionOfPage({required int index}) {
    return rows[index][currentConsolesName[index]]?.extension;
  }

  @override
  Widget build(BuildContext context) {
    // first row means the different pages consoles
    // pages consoles animate from left to right (width)

    // for each pages, we have a column of consoles
    // column consoles animate from top to bottom (height)

    // we have a row of columns of rows
    // the rows in the colum are the actual consoles
    // which can have different animated states aswell (holy shit)

    // the row that embeds the columns
    // ci is the index
    return ColoredBox(
      color: g.theme.buttonColor(isActivated: true, isInverted: false),
      child: GestureDetector(
        onHorizontalDragUpdate: (_) {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: currentExtension == null ? 0 : 1,
              duration: Console.animationDuration,
              child: AnimatedContainer(
                duration: Console.animationDuration,
                height: currentExtensionHeight ?? 0,
                // constraints: BoxConstraints(
                //     maxHeight: currentExtension == null ? 0 : g.sizes.w),
                child: currentExtension ?? const SizedBox.shrink(),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: rows.indexed.map((c) {
                final ci = c.$1;
                final cInfo = c.$2;
                return Column(
                    children: cInfo
                        .map((name, c) {
                          double currentHeight;
                          if (currentConsolesName.contains(name)) {
                            currentHeight = Console.buttonHeight;
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

                              double width;
                              if (ci != currentPageIndex) {
                                width = 0;
                              } else {
                                width =
                                    (c.widths?[i] ?? defaultWidth) * g.sizes.w;
                              }

                              double height;
                              if (w is ConsoleButton) {
                                height = currentHeight;
                              } else {
                                height = currentHeight == 0
                                    ? currentHeight
                                    : inputHeight ?? Console.buttonHeight;
                              }

                              final Widget w_ = AnimatedOpacity(
                                  duration: Andrew.pageSwitchOpacityDuration,
                                  opacity: ci == currentPageIndex ? 1 : 0,
                                  child: AnimatedContainer(
                                      duration:
                                          Andrew.pageSwitchAnimationDuration,
                                      width: width,
                                      height: height,
                                      child: w));

                              return w_;
                            }).toList(),
                          );

                          return MapEntry(name, row);
                        })
                        .values
                        .toList());
                // return MapEntry(i, SizedBox(width: sizes[i], child: value));
              }).toList(),
            )
          ],
        ),
      ),
    );
  }
}

// class ConsoleRow extends StatefulWidget {
//   final List<({int begin, int end, Widget w})> rowWidgets;
//   const ConsoleRow(this.rowWidgets, Key? key) : super(key: key);
//
//   @override
//   State<ConsoleRow> createState() => _ConsoleRowState();
// }
//
// class _ConsoleRowState extends State<ConsoleRow>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late List<Animation> _animations;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl =
//         AnimationController(duration: Console.animationDuration, vsync: this);
//     _animations = widget.rowWidgets
//         .map((e) => IntTween(begin: e.begin, end: e.end).animate(_ctrl))
//         .toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: widget.rowWidgets
//           .asMap()
//           .map((key, value) => MapEntry(
//               key, Expanded(flex: _animations[key].value, child: value.w)))
//           .values
//           .toList(),
//     );
//   }
// }
