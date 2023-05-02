import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:down4/src/render_objects/chat_message.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../couch.dart';
import '../data_objects.dart';
import '../globals.dart';
import '../themes.dart';
import '../_dart_utils.dart' show golden;

import 'palette.dart';
import '_render_utils.dart';

class ConsoleButton extends StatelessWidget {
  // RenderBox get renderBox => context.findRenderObject() as RenderBox;
  final String name;
  final List<ConsoleButton>? extraButtons;
  final bool isSpecial,
      isMode,
      shouldBeDownButIsnt,
      isActivated,
      showExtra,
      isGreyedOut;
  final void Function() onPress;
  final void Function()? onLongPress;
  final void Function()? onLongPressUp;
  final bool invertColors;
  final BorderRadius? border;

  const ConsoleButton({
    this.invertColors = false,
    required this.name,
    required this.onPress,
    this.extraButtons,
    this.isGreyedOut = false,
    this.showExtra = false,
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
        invertColors: true,
        isGreyedOut: isGreyedOut,
        extraButtons: extraButtons,
        showExtra: showExtra,
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        isMode: isMode,
        isSpecial: isSpecial,
        isActivated: isActivated,
        key: key,
        border: border,
      );

  ConsoleButton withBorder(BorderRadius border, {required GlobalKey k}) =>
      ConsoleButton(
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        invertColors: invertColors,
        border: border,
        isGreyedOut: isGreyedOut,
        extraButtons: extraButtons,
        showExtra: showExtra,
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        isMode: isMode,
        isSpecial: isSpecial,
        isActivated: isActivated,
        key: k,
      );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TouchableOpacity(
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        onPress: isActivated ? onPress : () {},
        onLongPress: isActivated ? onLongPress : () {},
        onLongPressUp: isActivated ? onLongPressUp : () {},
        child: Container(
          decoration: BoxDecoration(
              borderRadius: border,
              color: invertColors
                  ? Colors.black12
                  : isGreyedOut
                      ? PinkTheme.inactivatedButtonColor
                      : PinkTheme.buttonColor,
              border: Border.all(
                  color: Console.borderColor, width: Console.borderWidth)),
          child: SizedBox(
            height: Console.buttonHeight,
            child: Center(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  color: invertColors ? PinkTheme.buttonColor : Colors.black,
                  decoration: isSpecial ? TextDecoration.underline : null,
                  decorationStyle: TextDecorationStyle.solid,
                  fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
                  fontWeight: FontWeight.bold,
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
    this.textAlign = TextAlign.start,
    this.focus,
    this.borderRadius,
    this.onEditingComplete,
    this.show = true,
    this.type = TextInputType.text,
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
    return TextField(
      controller: tec,
      focusNode: focus,
      cursorColor: PinkTheme.black,
      key: GlobalKey(),
      maxLines: maxLines,
      minLines: 1,
      onEditingComplete: onEditingComplete,
      keyboardType: type,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        // floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: g.sizes.w * 0.012),
        hintText: placeHolder,
        border: InputBorder.none,
        // prefixIcon: Icon(Icons.keyboard_arrow_right_rounded,
        //     size: Console.buttonHeight, color: Console.borderColor),
        // prefixIconConstraints: const BoxConstraints(
        //   minHeight: 0,
        //   minWidth: 0,
        // ),
        // suffixIcon: // const Icon(Icons.keyboard_arrow_right_rounded),
        //     Row(
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     // Icon(Icons.search, size: Console.buttonHeight),
        //     Icon(Icons.qr_code_2,
        //         size: Console.buttonHeight, color: Console.borderColor),
        //     // Icon(Icons.image_rounded, size: Console.buttonHeight),
        //     // Icon(Icons.camera_rounded, size: Console.buttonHeight),
        //   ],
        // ),
        // suffixIconConstraints: const BoxConstraints(
        //   minHeight: 0,
        //   minWidth: 0,
        // ),
      ),
      textDirection: TextDirection.ltr,
      onChanged: inputCallBack,
    );
  }

  Widget get unactivatedField {
    return Center(child: Text(placeHolder));
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedSize(
        duration: Console.animationDuration,
        child: Container(
          decoration: BoxDecoration(
              color: activated ? Colors.white : Colors.grey,
              borderRadius: borderRadius,
              border: Border.all(
                  width: show ? Console.borderWidth : 0,
                  color: Console.borderColor)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                // this is higher than maxfields in the textInput allows
                maxHeight: show && activated
                    ? 8 * Console.buttonHeight
                    : show && !activated
                        ? Console.buttonHeight
                        : 0,
                minHeight: show ? Console.buttonHeight : 0),
            child: activated ? activatedField : unactivatedField,
          ),
        ),
      ),
    );
  }
}

class ConsoleMedias2 {
  final void Function(FireMedia) onSelect;
  final bool images;
  ConsoleMedias2({required this.images, required this.onSelect});
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? _topButtons;
  final List<ConsoleButton> _bottomButtons;
  final List<ConsoleInput>? _bottomInputs, _topInputs;
  final bool animatedInputs;

  final Widget? previewMedia;
  final List<dynamic>? forwardingObjects;
  final List<Palette>? forwardingPalette;
  final bool invertedColors, initializationConsole;
  final ConsoleMedias2? medias;
  final CameraController? cameraController;
  final MobileScanner? scanner;

  static GlobalKey get widgetCaptureKey => GlobalKey();

  int get nMediaPerRow => 5;
  int get maximumMediaRows => 3;
  double get rowHeight => (consoleWidth / nMediaPerRow); // squared element

  List<Widget> get extraTopButtons {
    List<Widget> extras = [];
    for (final b in topConsoleButtons) {
      if (b.showExtra) {
        final key = b.key as GlobalKey;
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        // final RenderBox renderBox = b.renderBox as RenderBox;
        final semantics = renderBox.semanticBounds;
        final buttonWidth = semantics.width;
        final leftBottom = semantics.bottomLeft;

        extras.add(Positioned(
          bottom: leftBottom.dy - borderWidth,
          left: leftBottom.dx - borderWidth,
          child: Container(
            width: buttonWidth + borderWidth,
            decoration: BoxDecoration(
                border: Border.all(width: borderWidth, color: borderColor)),
            child: Column(children: b.extraButtons!),
          ),
        ));
      } else {
        extras.add(const SizedBox.shrink());
      }
    }
    return extras;
  }

  int get nConsoleLayers {
    int n = 1;
    if (_topButtons != null) n++;
    if (_bottomInputs != null) n++;
    if (_topInputs != null) n++;
    return n;
  }

  List<Widget> get extraBottomButtons {
    return bottomConsoleButtons.map((b) {
      if (b.showExtra) {
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
          left: position.dx - borderWidth,
          top: position.dy -
              g.sizes.viewPaddingHeight -
              borderWidth -
              (nButton * (buttonHeight)),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              border: Border.all(width: borderWidth, color: borderColor),
              color: borderColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(Console.consoleRad),
                topRight: Radius.circular(Console.consoleRad),
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
                height: b.showExtra ? buttonHeight * nButton : 0,
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

  static double get consoleRad => 10;

  static double get buttonHeight => g.sizes.h * 0.044;

  bool get bottomButtonsHasTop =>
      _topButtons != null ||
      _bottomInputs != null ||
      _topButtons != null ||
      hasGadgets;

  bool get topButtonsHasTop =>
      _bottomInputs != null || _topInputs != null || hasGadgets;

  static double get consoleGap => g.sizes.w * 0.015;
  static double get borderWidth => .6;
  static Color get borderColor => Colors.black45;
  static double get consoleWidth => g.sizes.w - (2.0 * consoleGap);
  static double get trueWidth => consoleWidth - (4 * borderWidth);
  static double get bbWidth => consoleWidth - (2 * borderWidth);

  bool get bottomInputsHasTop => _topInputs != null;

  static Duration get animationDuration =>
      Duration(milliseconds: (100 * golden).toInt());

  bool get hasGadgets =>
      previewMedia != null ||
      // imageForPreview != null ||
      // videoForPreview != null ||
      cameraController != null ||
      // forwardingObjects != null ||
      scanner != null ||
      medias != null;

  final String? name;
  const Console({
    this.name,
    required List<ConsoleButton> bottomButtons,
    this.invertedColors = false,
    this.forwardingPalette,
    this.previewMedia,
    this.forwardingObjects,
    this.cameraController,
    this.initializationConsole = false,
    this.scanner,
    this.animatedInputs = true,
    this.medias,
    List<ConsoleInput>? bottomInputs,
    List<ConsoleInput>? topInputs,
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

  List<ConsoleInput> get topConsoleInputs =>
      _topInputs
          ?.map((input) => input.animated(show: !hasGadgets))
          .toList()
          .asMap()
          .map((i, e) => MapEntry(
              i,
              e.withRadius(BorderRadius.only(
                topLeft: Radius.circular(i == 0 ? consoleRad : 0),
                topRight: Radius.circular(
                    i == _topInputs!.length - 1 ? consoleRad : 0),
                bottomLeft: const Radius.circular(0),
                bottomRight: const Radius.circular(0),
              ))))
          .values
          .toList(growable: false) ??
      [];

  List<ConsoleInput> get bottomConsoleInputs =>
      _bottomInputs
          ?.map((input) => input.animated(show: !hasGadgets))
          .toList()
          .asMap()
          .map((i, e) => MapEntry(
              i,
              e.withRadius(BorderRadius.only(
                topLeft: Radius.circular(
                    !bottomInputsHasTop && i == 0 ? consoleRad : 0),
                topRight: Radius.circular(
                    !bottomInputsHasTop && i == _bottomInputs!.length - 1
                        ? consoleRad
                        : 0),
                bottomLeft: const Radius.circular(0),
                bottomRight: const Radius.circular(0),
              ))))
          .values
          .toList(growable: false) ??
      [];

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
          color: Console.borderColor,
          border: Border.all(color: borderColor, width: borderWidth)),
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: maximumMediaRows * mediaCelSize, maxWidth: trueWidth),
          child: ListView.builder(
              itemCount: nRows,
              itemBuilder: ((context, index) {
                Widget f(int i) {
                  if (i < ids.length) {
                    final cachedMedia = cache<FireMedia>(ids[i]);
                    if (cachedMedia != null) {
                      return GestureDetector(
                          onTap: () => medias!.onSelect(cachedMedia),
                          child: (cachedMedia.displayImage(
                              size: Size.square(mediaCelSize),
                              forceSquare: true)));
                    }
                    return FutureBuilder(
                      future: global<FireMedia>(ids[i]),
                      builder: (ctx, ans) {
                        if (ans.connectionState == ConnectionState.done &&
                            ans.hasData) {
                          return GestureDetector(
                              onTap: () => ans.data != null
                                  ? medias!.onSelect(ans.data!)
                                  : null,
                              child: (ans.requireData?.displayImage(
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
                    color: PinkTheme.nodeColors[obj.node.colorCode],
                    border: Border.all(width: borderWidth, color: borderColor)),
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
                    border: Border.all(width: borderWidth, color: borderColor)),
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
        child:
            // Container(
            // clipBehavior: Clip.hardEdge,
            // decoration: BoxDecoration(
            //     border: Border.all(color: contourColor, width: borderWidth)),
            // child:
            Row(
                textDirection: TextDirection.ltr,
                children: forwardingObjects!
                    .map((e) => individualObject(e))
                    .toList()));
    // );
  }

  Widget consoleCamera() {
    final camCtrl = cameraController;
    if (camCtrl == null) return const SizedBox.shrink();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(consoleRad)),
          color: borderColor,
          border: Border.all(color: borderColor, width: borderWidth)),
      child: SizedBox.square(
          dimension: trueWidth,
          child: Transform.scale(
              scaleY: camCtrl.value.aspectRatio,
              child: CameraPreview(camCtrl))),
    );
  }

  Widget mediaPreview() {
    if (previewMedia == null) return const SizedBox.shrink();
    print("PREVIEWING THIS FUCKING SHIT ");
    return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(consoleRad)),
            border: Border.all(color: borderColor, width: borderWidth)),
        child: previewMedia!);
  }

  Widget get rotatingLogo {
    return AnimatedRotation(
        turns: math.pi * 2,
        duration: const Duration(seconds: 2),
        child: down4Logo(trueWidth));
  }

  Widget consoleScanner() {
    if (scanner == null) return const SizedBox.shrink();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(consoleRad)),
          border: Border.all(width: borderWidth, color: borderColor)),
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

  List<ConsoleButton> get bottomConsoleButtons {
    return invertedColors
        ? _bottomButtons
            .map((e) => e.invertedColors())
            .toList()
            .asMap()
            .map((i, value) => MapEntry(
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
                    ))))
            .values
            .toList(growable: false)
        : _bottomButtons
            .asMap()
            .map((i, value) => MapEntry(
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
                    ))))
            .values
            .toList(growable: false);
  }

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(children: topConsoleInputs),
        Row(children: bottomConsoleInputs),
      ],
    );
  }

  Widget get buttons {
    return Column(
      children: [
        Row(textDirection: TextDirection.ltr, children: topConsoleButtons),
        Row(textDirection: TextDirection.ltr, children: bottomConsoleButtons),
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
          color: borderColor,
          borderRadius: BorderRadius.all(Radius.circular(consoleRad)),
          border: Border.all(width: borderWidth, color: borderColor)),
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
        ],
      ),
    );
  }
}
