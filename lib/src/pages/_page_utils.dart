import 'dart:io';
import 'dart:math';
import 'dart:ui';

// import 'package:better_player/better_player.dart';
import 'package:camera/camera.dart';
import 'package:down4/main.dart';
import 'package:down4/src/couch.dart';
import 'package:down4/src/render_objects/navigator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:video_player/video_player.dart';

import '../_dart_utils.dart';
import '../data_objects.dart';
import '../globals.dart';
import '../render_objects/_render_utils.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import 'chat_page.dart';

class Caret extends CustomPainter {
  Rect caret;
  Caret(this.caret);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(caret, Paint()..color = g.theme.inputTextStyle.color!);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}

class InputController implements Listenable {
  String value = "";
  String _placeHolder;
  final TextEditingController _tec;
  // final TextInputConfiguration config;

  void clear() {
    value = "";
    height = _initHeight;
    caretOffset = Offset.zero;
    caretPosition = 0;
    _tec.clear();
    _notify();
  }

  String get placeHolder => _placeHolder;
  set placeHolder(String ph) {
    _placeHolder = ph;
    _notify();
  }

  void _notify() {
    for (final l in _listeners) {
      l.call();
    }
  }

  final double _initHeight;

  double height;

  Offset caretOffset = Offset.zero;
  int caretPosition = 0;

  InputController({String? placeHolder, required this.height})
      : _placeHolder = (placeHolder ?? "").isEmpty ? " " : placeHolder!,
        _tec = TextEditingController(),
        _initHeight = height;

  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void dispose() {
    _tec.dispose();
  }
}

extension on TextStyle {
  double get singleLineHeight {
    final lay = TextPainter(
        text: TextSpan(text: "W", style: this),
        textDirection: TextDirection.ltr)
      ..layout();
    return lay.height;
  }
}

class MyTextEditor extends StatefulWidget {
  InitInput2 get initInput => InitInput2(this);
  ConsoleInput2 get consoleInput => ConsoleInput2(this);
  Widget get basicInput => BasicInput(this);
  Widget get snipInput => SnipInput(this);
  bool get hasFocus => fn.hasFocus;
  String get value => ctrl.value;
  double get height => ctrl.height;
  void clear() => ctrl.clear();

  final TextInputConfiguration config;

  // final TextAlign textAlignment;
  // final AlignmentDirectional alignment;
  final bool centered;
  final void Function() onFocusChange;
  final void Function(String input, double fullHeight) onInput;
  // final bool isAnimated;
  final double maxWidth;
  final int maxLines;
  final FocusNode fn;
  final InputController ctrl;
  final TextStyle? specificStyle, placeholderStyle;
  final bool isConsoleInput;

  TextStyle get style => specificStyle ?? g.theme.inputTextStyle;

  final double horizontalTextPadding, verticalTextPadding;

  MyTextEditor({
    this.specificStyle,
    TextStyle? placeholderStyle,
    this.centered = false,
    this.isConsoleInput = true,
    required this.config,
    String? placeHolder,
    required this.onInput,
    required this.onFocusChange,
    this.verticalTextPadding = 0,
    double? horizontalTextPadding,
    this.maxWidth = 0.6,
    this.maxLines = 20,
    FocusNode? fn,
    Key? key,
  })  : fn = FocusNode()..addListener(onFocusChange),
        placeholderStyle = placeholderStyle ??
            specificStyle ??
            g.theme.inputPlaceholderTextStyle,
        horizontalTextPadding =
            isConsoleInput ? 24.0 : horizontalTextPadding ?? 0,
        ctrl = InputController(
            height: isConsoleInput
                ? Console.buttonHeight
                : (specificStyle ?? g.theme.inputTextStyle).singleLineHeight +
                    verticalTextPadding,
            placeHolder: placeHolder),
        super(key: key);

  @override
  State<MyTextEditor> createState() => _MyTextEditorState();
}

class _MyTextEditorState extends State<MyTextEditor> {
  String get value => widget.ctrl.value;
  set value(String v) => widget.ctrl.value = v;

  late double caretSize = widget.style.singleLineHeight;

  String get placeHolder => widget.ctrl.placeHolder;

  int get caretOffset => widget.ctrl.caretPosition;
  set caretOffset(int p) => widget.ctrl.caretPosition = p;

  Offset get caretPosition => widget.ctrl.caretOffset;
  set caretPosition(Offset p) => widget.ctrl.caretOffset = p;

  Offset get paintingCaretOffset => caretPosition.translate(0, 1);
  Offset get caretSecondaryOffset =>
      paintingCaretOffset.translate(1, caretSize.toInt() - 2);
  Rect get caret => Rect.fromPoints(paintingCaretOffset, caretSecondaryOffset);

  // Rect get caret_ =>
  //     Rect.fromPoints(animCursorPos, animCursorPos.translate(2, 18));

  Widget get cursor =>
      // Positioned(
      // left: animCursorPos.dx,
      // top: animCursorPos.dy,
      // child:
      const SizedBox(
        width: 1,
        height: 18,
        child: ColoredBox(color: Colors.amber),
      );
  // );

  void calculateCaretFromOffset() {
    final textPo = TextPosition(offset: caretOffset);
    caretPosition = textPainter.getOffsetForCaret(textPo, caret);
    widget.ctrl._tec.selection = TextSelection.collapsed(offset: caretOffset);
    setState(() {});
  }

  void calculateCaretPositionFromPosition(Offset pos) {
    caretOffset = textPainter.getPositionForOffset(pos).offset;
    calculateCaretFromOffset();
  }

  late GestureRecognizer detector = TapGestureRecognizer()
    ..onTapDown = (details) {
      if (widget.fn.hasFocus) {
        calculateCaretPositionFromPosition(details.localPosition);
      } else {
        // if (widget.isNumberPad) {
        //   // SystemChannels.textInput.invokeMethod(
        //   //     'TextInput.show', {"inputType": widget.numberInputConfig()});
        //   // SystemChannels.textInput.invokeMethod('TextInput.show');
        // } else {
        //   // SystemChannels.textInput.invokeMethod('TextInput.show');
        // }
        // FocusScope.of(context).requestFocus(widget.fn);
      }
    };

  String get beforeCaret => value.substring(0, caretOffset);
  String get afterCaret => value.substring(caretOffset);
  //
  // late bool Function(KeyEvent) onKeyEvent = (ke) {
  //   print("KEY EVENT");
  //   if (ke is RawKeyUpEvent) return false;
  //
  //   if (ke.character != null) {
  //     value = "$beforeCaret${ke.character!}$afterCaret";
  //     caretOffset += 1;
  //     calculateCaretFromOffset();
  //
  //     final fullHeight = inputHeight(text: value);
  //     widget.ctrl.height = fullHeight;
  //     widget.onInput(value, fullHeight);
  //     return true;
  //   }
  //
  //   if (ke.logicalKey.keyId == LogicalKeyboardKey.backspace.keyId &&
  //       ke is KeyDownEvent) {
  //     if (caretOffset > 0) {
  //       final bc = beforeCaret;
  //       value = "${bc.substring(0, bc.length - 1)}$afterCaret";
  //       if (caretOffset > 0) caretOffset -= 1;
  //       calculateCaretFromOffset();
  //
  //       final fullHeight = inputHeight(text: value);
  //       widget.ctrl.height = fullHeight;
  //       widget.onInput(value, fullHeight);
  //       return true;
  //     }
  //   }
  //   return false;
  // };

  late void Function(String) onValue = (newValue) {
    final diff = newValue.length - value.length;
    // if (isAnimated) {
    //   String strDiff;
    //   isAddition = diff > 0;
    //   if (isAddition) {
    //     // chars have been added, to find added chars
    //     // go to [offset,  offset + diff)
    //     strDiff = newValue.substring(caretOffset, caretOffset + diff);
    //   } else {
    //     // chars have been removed, to find removed chars
    //     // go to [offset + diff, offset)
    //     strDiff = value.substring(caretOffset + diff, caretOffset);
    //     removeDiff = strDiff;
    //   }
    //
    //   final diffSpan = TextSpan(
    //       text: strDiff, style: widget.style ?? g.theme.inputTextStyle);
    //   final tp = TextPainter(text: diffSpan, textDirection: TextDirection.ltr)
    //     ..layout();
    //   final double strDiffWidth = tp.width;
    //   final double strDiffHeight = tp.height;
    //
    //   if (isAddition) {
    //     widthTweener = Tween(begin: strDiffWidth, end: 0);
    //     reverseTweener = Tween(begin: 0, end: strDiffWidth);
    //   } else {
    //     widthTweener = Tween(begin: 0, end: strDiffWidth);
    //     reverseTweener = Tween(begin: strDiffWidth, end: 0);
    //   }
    //   differHeight = strDiffHeight;
    //   anim.forward(from: 0);
    // }

    value = newValue;
    caretOffset += diff;
    calculateCaretFromOffset();

    final fullHeight = inputHeight();
    widget.ctrl.height = fullHeight;
    print("full height: $fullHeight\n");

    return widget.onInput(newValue, fullHeight);
  };

  // differ knowledge
  // double differHeight = 0;
  // Tween<double> widthTweener = Tween(begin: 0, end: 0);
  // Tween<double> reverseTweener = Tween(begin: 0, end: 0);
  // bool isAddition = true;
  // String removeDiff = "";
  // Offset get animCursorPos => isAddition
  //     ? caretPosition.translate(-widthTweener.evaluate(anim), 0)
  //     : caretPosition.translate(reverseTweener.evaluate(anim), 0);

  // Curve get curve => Curves.linear;

  ///////////////////////
  // Widget get differ {
  //   final diffSize =
  //       widthTweener.evaluate(CurvedAnimation(parent: anim, curve: curve));
  //   final reverseDiffSize =
  //       reverseTweener.evaluate(CurvedAnimation(parent: anim, curve: curve));
  //   return Positioned(
  //       top: caretPosition.dy,
  //       left: isAddition
  //           ? caretPosition.dx - diffSize // widthTweener.evaluate(anim)
  //           : caretPosition.dx +
  //               reverseDiffSize, //  reverseTweener.evaluate(anim),
  //       child: SizedBox(
  //         width: isAddition
  //             ? diffSize // widthTweener.evaluate(anim)
  //             : diffSize, //widthTweener.evaluate(anim),
  //         height: differHeight,
  //         child: ColoredBox(color: g.theme.inputColor),
  //       ));
  // }

  // Duration get animationDuration => const Duration(milliseconds: 100);

  // late AnimationController anim = AnimationController(
  //     vsync: this, duration: animationDuration) //Console.animationDuration)
  //   ..addListener(() {
  //     if (anim.isCompleted && !isAddition && removeDiff != "") {
  //       print("COMPLETED BRO\n");
  //       removeDiff = "";
  //       final recalculatedHeight = inputHeight();
  //       widget.ctrl.height = recalculatedHeight;
  //       widget.onInput(value, recalculatedHeight);
  //     }
  //     setState(() {});
  //   });

  TextSpan get span => TextSpan(
      text: value.isEmpty ? placeHolder : value,
      style: value.isEmpty
          ? widget.placeholderStyle ?? g.theme.inputPlaceholderTextStyle
          : widget.specificStyle ?? g.theme.inputTextStyle,
      recognizer: widget.fn.hasFocus ? detector : null);

  // TextSpan get modifiedSpan => TextSpan(
  //     text: value.isEmpty
  //         ? placeHolder
  //         : isAddition
  //             ? value + " "
  //             : value + removeDiff,
  //     style: value.isEmpty && placeHolder.isNotEmpty
  //         ? widget.placeholderStyle ?? g.theme.inputPlaceholderTextStyle
  //         : widget.style ?? g.theme.inputTextStyle,
  //     recognizer: widget.fn.hasFocus ? detector : null);

  TextPainter get textPainter => TextPainter(
      textAlign: widget.centered ? TextAlign.center : TextAlign.start,
      textDirection: TextDirection.ltr,
      text: span,
      maxLines: widget.maxLines)
    ..layout(
        maxWidth: (g.sizes.w * widget.maxWidth) - widget.horizontalTextPadding);

  // TextPainter get modifiedTextPainter => TextPainter(
  //     textAlign: widget.centered ? TextAlign.center : TextAlign.start,
  //     textDirection: TextDirection.ltr,
  //     text: modifiedSpan,
  //     maxLines: widget.maxLines)
  //   ..layout(maxWidth: (g.sizes.w * widget.maxWidth) - widget.textPadding);

  // bool get isAnimated => widget.isAnimated;

  double inputHeight() {
    final tp = textPainter;
    final textHeight = tp.height;
    if (!widget.isConsoleInput) return tp.height + widget.verticalTextPadding;
    final nLines = tp.computeLineMetrics().length;
    final oneLineHeight = tp.height / nLines;
    final paddingHeight = Console.buttonHeight / 2;
    final inputHeight = Console.buttonHeight - paddingHeight;
    final greyNoText = inputHeight - oneLineHeight;
    final consoleInputHeight = greyNoText + paddingHeight + textHeight;
    return consoleInputHeight;
  }

  void updateTextEditor() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(updateTextEditor);
    widget.fn.addListener(updateTextEditor);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(updateTextEditor);
    widget.fn.removeListener(widget.onFocusChange);
    widget.fn.removeListener(updateTextEditor);
    // anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.shrink(
          child: EditableText(
            showCursor: false,
            autocorrect: false,
            keyboardAppearance: g.theme.keyBoardTheme,
            keyboardType: widget.config.inputType,
            maxLines: widget.maxLines,
            onChanged: onValue,
            controller: widget.ctrl._tec,
            focusNode: widget.fn,
            style: const TextStyle(),
            cursorColor: Colors.transparent,
            backgroundCursorColor: Colors.transparent,
          ),
        ),
        RichText(
            text: span,
            // text: isAnimated ? modifiedSpan : span,
            softWrap: true,
            maxLines: widget.maxLines,
            textAlign: widget.centered ? TextAlign.center : TextAlign.start),
        widget.fn.hasFocus
            ? CustomPaint(painter: Caret(caret))
            : const SizedBox.shrink(),
        // value.isNotEmpty && isAnimated ? differ : const SizedBox.shrink(),
        // widget.fn.hasFocus
        //     ? isAnimated
        //         ? AnimatedPositioned(
        //             duration: animationDuration,
        //             left: caretPosition.dx,
        //             top: caretPosition.dy + 1,
        //             child: cursor
        // )
        // : CustomPaint(painter: Caret(caret))
        // : const SizedBox.shrink(),
      ],
    );
  }
}

// mixin Pager {
//   ID get selfID;
//   ConsoleInput get mainInput;
//   Console get console;
//   set console(Console c);
//   void setTheState();
//   void loadBaseConsole();
//   AnimationController? get aCtrl => null;
//   FocusNode? get focusNode => null;
//   void onFocusChange() {
//     if (!focusNode!.hasFocus) {
//       aCtrl!.reverse();
//     } else {
//       aCtrl!.forward();
//     }
//     loadBaseConsole();
//   }
//
//   Future<void> focusRoutine() async {
//     print("NOT DOING ANYTHING");
//   }
//
//   double inputHeight({maxWidth = 0.5}) {
//     final text = mainInput.tec.value.text;
//     final val = text.isEmpty ? " " : text;
//
//     final tp = TextPainter(
//       text: TextSpan(text: val, style: g.theme.inputTextStyle),
//       textDirection: TextDirection.ltr,
//       maxLines: 8,
//     );
//     tp.layout(maxWidth: (g.sizes.w * maxWidth) - (24 + 2));
//     final textHeight = tp.height;
//     final nLines = tp.computeLineMetrics().length;
//     final oneLineHeight = tp.height / nLines;
//     final paddingHeight = Console.buttonHeight / 2;
//     final inputHeight = Console.buttonHeight - paddingHeight;
//     final greyNoText = inputHeight - oneLineHeight;
//     final trueHeight = greyNoText + paddingHeight + textHeight;
//
//     return trueHeight;
//   }
// }
//
// mixin Backable {
//   void back();
// }

class Extra {
  final GlobalKey key = GlobalKey();
  bool show = false;
  final VoidCallback setTheState;
  Extra({required this.setTheState});

  void flip() {
    show = !show;
    setTheState.call();
  }
}

mixin Pager2 {
  int get currentPageIndex => 0;

  List<String> get currentConsolesName;
  set currentConsolesName(List<String> currentConsolesName);

  Icon get closeButtonIcon =>
      Icon(Icons.keyboard_arrow_down, color: g.theme.buttonTextColor);

  List<Extra> get extras;
  set extras(List<Extra> e);

  static const double _widgetRadius = 2.0;

  void turnOffExtras() {
    for (final e in extras) {
      if (e.show) e.flip();
    }
  }

  void changeConsole(String consoleName) {
    currentConsolesName[currentPageIndex] = consoleName;
    turnOffExtras();
    setTheState();
  }

  void onPageSwitch() {
    turnOffExtras();
    setTheState();
  }

  void setTheState();

  Console3 get console;
}

mixin Sender2 {
  void send({FireMedia? mediaInput});

  final GlobalKey _sendButtonKey = GlobalKey();
  ConsoleButton get sendButton =>
      ConsoleButton(name: "SEND", onPress: send, key: _sendButtonKey);
}

mixin ForwardSender2 on Sender2 {
  List<Down4Object>? get fo;

  Widget individualObject(Down4Object obj) {
    if (obj is Palette2) {
      return Row(
          textDirection: TextDirection.ltr,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(5))),
              child: obj.node
                  .nodeImage(Size.square(Console.buttonHeight - (2 * 4))),
            ),
            Flexible(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Center(
                        child: Text(obj.node.displayName,
                            style: g.theme
                                .palettePreviewTextStyle(selected: false),
                            overflow: TextOverflow.clip,
                            maxLines: 1))))
          ]);
    } else if (obj is ChatMessage) {
      return Container(
          color: obj.messageColor,
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          constraints: BoxConstraints(maxWidth: Console.consoleWidth / 4),
          child: Center(
              child: Text(
                  (obj.message.text ?? "").isEmpty
                      ? "&attachment"
                      : obj.message.text!,
                  style: g.theme.chatBubbleTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)));
    }

    return const SizedBox.shrink();
  }

  List<Widget> get _foWidgets =>
      (fo ?? []).map((e) => individualObject(e)).toList();

  Widget get forwardingObjectsWidget => Container(
        padding: const EdgeInsets.all(4),
        height: Console.buttonHeight,
        child: ListView(
          // shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(0),
          children: _foWidgets,
        ),
      );
}

mixin Forwarder2 {
  // void Function()? get hyper => null;

  // List<String> get forwardingConsoles => [
  //       "ForwardingConsole",
  //       "ForwardingMediasConsole",
  //       "ForwardingCameraConsole",
  //       "ForwardingPreviewConsole",
  //     ];

  void forward();

  ConsoleButton get forwardButton =>
      ConsoleButton(name: "FORWARD", onPress: forward);

// void loadForwardingConsole([bool extra = false]) {
//   console = Console(
//     name: "ForwardingConsole",
//     // bottomInputs: [mainInput],
//     // forwardingObjects: fo,
//     bottomButtons: [],
//     consoleRow: Console3(
//       ctrl: aCtrl,
//       maxHeight: Console.buttonHeight,
//       beginSizes: const [0.25, 0.25, 0.25, 0.25],
//       endSizes: const [0.0, 0.25, 0.50, 0.25],
//       widgets: [
//         Container(
//           padding: const EdgeInsets.all(4),
//           height: Console.buttonHeight,
//           child: ListView(
//             // shrinkWrap: true,
//             scrollDirection: Axis.horizontal,
//             padding: const EdgeInsets.all(0),
//             children: _foWidgets,
//           ),
//         ),
//         ConsoleButton(name: "MEDIAS", onPress: loadMediasConsole),
//         mainInput,
//         ConsoleButton(
//           name: "FORWARD",
//           onPress: () => extra ? loadForwardingConsole(!extra) : send(),
//           onLongPress: () => loadForwardingConsole(!extra),
//           isSpecial: true,
//           showExtra: extra,
//           extraButtons: [
//             ConsoleButton(
//               name: cameraInput == null ? "CAMERA" : "@CAMERA",
//               onPress: loadSquaredCameraConsole,
//             ),
//             ...(hyper != null
//                 ? [ConsoleButton(name: "HYPER", onPress: hyper!)]
//                 : [])
//           ],
//         )
//       ],
//     ),
//     // bottomButtons: [
//     //   ConsoleButton(name: "BACK", onPress: back),
//     //   ConsoleButton(name: "MEDIAS", onPress: loadForwardingMediasConsole),
//     //   ConsoleButton(
//     //     name: "FORWARD",
//     //     onPress: () => extra ? loadForwardingConsole(!extra) : send(),
//     //     onLongPress: () => loadForwardingConsole(!extra),
//     //     isSpecial: true,
//     //     showExtra: extra,
//     //     extraButtons: [
//     //       ConsoleButton(
//     //         name: cameraInput == null ? "Camera" : "@Camera",
//     //         onPress: loadForwardingCameraConsole,
//     //       ),
//     //       ...(hyper != null
//     //           ? [ConsoleButton(name: "Hyper", onPress: hyper!)]
//     //           : [])
//     //     ],
//     //   )
//     // ],
//   );
//
//   setTheState();
// }

// void loadForwardingMediasConsole([bool images = true]) {
//   console = Console(
//     name: "ForwardingMediasConsole",
//     // bottomInputs: [mainInput],
//     medias: ConsoleMedias2(
//       images: images,
//       onSelect: (m) => send(mediaInput: m),
//     ),
//     // forwardingObjects: fo,
//     bottomButtons: [
//       ConsoleButton(name: "BACK", onPress: loadForwardingConsole),
//       ConsoleButton(
//           name: images ? "IMAGES" : "VIDEOS",
//           onPress: () => loadForwardingMediasConsole(!images))
//     ],
//   );
//   setTheState();
// }

// Future<void> loadForwardingCameraConsole([
//   CameraController? ctrl,
//   int cam = 0,
// ]) async {
//   if (ctrl == null) {
//     try {
//       ctrl = CameraController(g.cameras[cam], ResolutionPreset.high);
//       await ctrl.initialize();
//     } catch (e) {
//       loadBaseConsole();
//     }
//   }
//   final bool isReversed = cam == 1;
//
//   console = Console(
//     name: "ForwardingCameraConsole",
//     // bottomInputs: [mainInput],
//     cameraController: ctrl,
//     // forwardingObjects: fo,
//     bottomButtons: [],
//     consoleRow: ConsoleRow(
//       widgets: [
//         ConsoleButton(name: "BACK", onPress: loadForwardingCameraConsole),
//         ConsoleButton(
//             name: cam == 0 ? "REAR" : "FRONT",
//             onPress: () => loadForwardingCameraConsole(null, (cam + 1) % 2),
//             isMode: true),
//         ConsoleButton(
//           name: "CAPTURE",
//           isSpecial: true,
//           shouldBeDownButIsnt: ctrl!.value.isRecordingVideo,
//           onPress: () async {
//             final XFile f = await ctrl!.takePicture();
//             final media = makeCameraMedia(
//                 cachedPath: f.path,
//                 size: ctrl.value.previewSize!,
//                 isReversed: isReversed,
//                 owner: selfID,
//                 isSquared: true);
//             loadForwardingPreviewConsole(media);
//           },
//           onLongPress: () async {
//             await ctrl!.startVideoRecording();
//             loadForwardingCameraConsole(ctrl, cam);
//           },
//           onLongPressUp: () async {
//             final XFile f = await ctrl!.stopVideoRecording();
//             final media = makeCameraMedia(
//                 cachedPath: f.path,
//                 size: ctrl.value.previewSize!,
//                 isReversed: isReversed,
//                 owner: selfID,
//                 isSquared: true);
//             loadForwardingPreviewConsole(media);
//           },
//         ),
//       ],
//     ),
//   );
//
//   setTheState();
// }
//
// void loadForwardingPreviewConsole(FireMedia m) async {
//   final vpc = await _loopingController(m);
//   console = Console(
//     name: "ForwardingPreviewConsole",
//     bottomInputs: [mainInput],
//     previewMedia: m.display(size: _squaredCamSize, controller: vpc),
//     forwardingObjects: fo,
//     bottomButtons: [
//       ConsoleButton(
//         name: "Back",
//         onPress: () {
//           vpc?.dispose();
//           loadForwardingCameraConsole(null, m.isReversed ? 1 : 0);
//         },
//       ),
//       ConsoleButton(
//           name: "Cancel",
//           onPress: () {
//             vpc?.dispose();
//             loadForwardingConsole();
//           }),
//       ConsoleButton(
//           name: "Accept",
//           onPress: () {
//             vpc?.dispose();
//             cameraInput = m;
//             loadForwardingConsole();
//           }),
//     ],
//   );
//
//   setTheState();
// }
}
//
// class FullInput {
//   final FocusNode focusNode;
//   final int maxInputLines;
//   final double maxInputWidth;
//   // final InputController tec;
//   final bool numberPad;
//   TextAlign textAlign;
//   double inputHeight;
//   late final MyTextEditor editor;
//
//   String get value => tec.value;
//
//   FullInput({
//     this.numberPad = false,
//     String? placeHoder,
//     required void Function(String, double) onInput,
//     this.textAlign = TextAlign.start,
//     double? maxInputWidth,
//     int? maxInputLines,
//     double? inputHeight,
//   })  : maxInputWidth = maxInputWidth ?? 0.6,
//         maxInputLines = maxInputLines ?? 20,
//         inputHeight = inputHeight ?? Console.buttonHeight,
//         focusNode = FocusNode() {
//     editor = MyTextEditor(
//         input: InputController(placeHolder: placeHoder),
//         textAlign: textAlign,
//         numberPad: numberPad,
//         onInputChange: (s, h) {
//           inputHeight = h;
//           onInput.call(s, h);
//         },
//         maxWidth: this.maxInputWidth,
//         maxLines: this.maxInputLines,
//         fn: focusNode);
//   }
//
//   ConsoleInput2 get widget => ConsoleInput2(editor);
// }

mixin Input2 on Pager2, WidgetsBindingObserver {
  List<MyTextEditor> get inputs;
  set inputs(List<MyTextEditor> ic) => inputs = ic;
  void onInput(String s, double h) => setTheState();

  MyTextEditor get input => inputs.first;

  Iterable<FocusNode> get focusNodes => inputs.map((e) => e.fn);

  bool get hasFocus => focusNodes.any((element) => element.hasFocus);

  // static void connectInput(InputController ctrl) {
  //   connection = TextInput.attach(ctrl, ctrl.config);
  // }

  @override
  void onPageSwitch() {
    turnOffExtras();
    removeFocus();
    setTheState();
  }

  void removeFocus() {
    print("REMOVING FOCUS");
    for (final input in inputs) {
      input.fn.unfocus();
    }
  }

  void onFocusChange() {
    print("FOCUS CHANGE");
    setTheState();
  }

  BuildContext get context;

  Future<bool> keyboardIsHidden() {
    return Future.delayed(const Duration(milliseconds: 200),
        () => MediaQuery.of(context).viewInsets.bottom <= 0);
  }

  Future<void> focusRoutine() async {
    turnOffExtras();
    print("FOCUS ROUTINE");
    if (hasFocus && await keyboardIsHidden()) {
      removeFocus();
      setTheState();
    }
  }

  void disposeInputs() {
    for (final i in inputs) {
      i.ctrl.dispose();
    }
  }

  @override
  void didChangeMetrics() async {
    focusRoutine();
  }

  static TextInputConfiguration get numberPad => TextInputConfiguration(
      inputType: TextInputType.number,
      inputAction: TextInputAction.done,
      keyboardAppearance: g.theme.keyBoardTheme);

  static TextInputConfiguration get multiLine => TextInputConfiguration(
      inputType: TextInputType.multiline,
      inputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.none,
      keyboardAppearance: g.theme.keyBoardTheme);

  static TextInputConfiguration get singleLine => TextInputConfiguration(
      inputType: TextInputType.text,
      inputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.none,
      keyboardAppearance: g.theme.keyBoardTheme);

  // final FocusNode _focusNode = FocusNode();
  // FocusNode get focusNode => _focusNode;
  // int get maxInputLines => 20;
  // double get maxInputWidth => 0.6;
  // final InputController tec = InputController();
  // double inputHeight = Console.buttonHeight;
  // late final MyTextEditor _myTextEditor = MyTextEditor(
  //     input: tec,
  //     onInputChange: (s, h) {
  //       inputHeight = h;
  //       setTheState();
  //     },
  //     maxWidth: maxInputWidth,
  //     maxLines: maxInputLines,
  //     fn: _focusNode);
  // ConsoleInput2 get input => ConsoleInput2(_myTextEditor);
}

// mixin InputListener2 on Pager2, Input2, WidgetsBindingObserver {
//   BuildContext get context;
//
//   Future<bool> keyboardIsHidden() {
//     return Future.delayed(const Duration(milliseconds: 200),
//         () => MediaQuery.of(context).viewInsets.bottom <= 0);
//   }
//
//   Future<void> focusRoutine() async {
//     print("DOING FOCUS ROUTINE!");
//     if (focusNode.hasFocus && await keyboardIsHidden()) {
//       print("REMOVEING FOCUS");
//       focusNode.unfocus();
//       setTheState();
//     }
//   }
//
//   @override
//   void didChangeMetrics() async {
//     focusRoutine();
//   }
// }

mixin Medias2 on Pager2 {
  int get _mediasPerRow => 5;
  int get _nRows => 3;
  double get _mediaCelSize => Console.trueWidth / _mediasPerRow;
  double get mediaExtensionHeight => _mediaCelSize * _nRows;

  bool _images =
      true; // or videos, but will change from bool to allow more types

  (String, void Function(FireMedia))? forMediaMode;
  FireMessage? reactingTo;

  List<(String, void Function(FireMedia))> get mediasMode;

  int currentMode = 0;
  (String, void Function(FireMedia)) get curMode => mediasMode[currentMode];

  String get backFromMediasConsoleName => "base";

  ConsoleButton get mediasButton => ConsoleButton(
      name: "MEDIAS",
      onPress: () {
        forMediaMode = null;
        changeConsole("medias");
      });

  ConsoleButton get mediasBackButton => ConsoleButton(
      name: "BACK",
      onPress: () {
        forMediaMode = null;
        changeConsole(backFromMediasConsoleName);
      });

  ConsoleButton get mediasImportButton => ConsoleButton(
      name: "IMPORT",
      onPress: () async {
        if (forMediaMode != null) {
          final nodeMedia = await importNodeMedia();
          if (nodeMedia != null) {
            forMediaMode!.$2.call(nodeMedia);
          }
        } else {
          await importConsoleMedias(
              images: _images,
              reload: () {
                setTheState();
              });
        }
      });

  ConsoleButton get mediasTypeButton => ConsoleButton(
      isMode: true,
      isActivated: forMediaMode == null,
      isGreyedOut: forMediaMode != null,
      name: _images ? "IMAGES" : "VIDEOS",
      onPress: () {
        _images = !_images;
        setTheState();
      });

  ConsoleButton get mediasModeButton => ConsoleButton(
      name: forMediaMode?.$1 ?? curMode.$1,
      isMode: true,
      isActivated: forMediaMode == null,
      onPress: () {
        currentMode = (currentMode + 1) % mediasMode.length;
        setTheState();
      });

  Widget get mediasExtension {
    final ids = _images ? g.savedImageIDs : g.savedVideoIDs;
    final nRows = (ids.length / _mediasPerRow).ceil();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Console.consoleRad)),
          color: g.theme.consoleBorderColor,
          border: Border.all(
              color: g.theme.consoleBorderColor, width: Console.borderWidth)),
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: _nRows * _mediaCelSize, maxWidth: Console.trueWidth),
          child: ListView.builder(
              itemCount: nRows,
              itemBuilder: ((context, index) {
                Widget f(int i) {
                  if (i < ids.length) {
                    final cachedMedia = cache<FireMedia>(ids[i]);
                    if (cachedMedia != null) {
                      return GestureDetector(
                          onTap: () => forMediaMode != null
                              ? forMediaMode!.$2.call(cachedMedia)
                              : curMode.$2(cachedMedia),
                          child: (cachedMedia.displayImage(
                              size: Size.square(_mediaCelSize),
                              forceSquare: true)));
                    }
                    return FutureBuilder(
                      future: global<FireMedia>(ids[i]),
                      builder: (ctx, ans) {
                        if (ans.connectionState == ConnectionState.done &&
                            ans.hasData) {
                          return GestureDetector(
                              onTap: () => ans.data != null
                                  ? curMode.$2(ans.data!)
                                  : null,
                              child: (ans.requireData?.displayImage(
                                      size: Size.square(_mediaCelSize),
                                      forceSquare: true)) ??
                                  SizedBox.square(dimension: _mediaCelSize));
                        } else {
                          return SizedBox.square(dimension: _mediaCelSize);
                        }
                      },
                    );
                  } else {
                    return SizedBox.square(dimension: _mediaCelSize);
                  }
                }

                return Row(
                  key: Key(_images.toString() + index.toString()),
                  children: List.generate(
                    _mediasPerRow,
                    (j) => f((index * _mediasPerRow) + j),
                  ),
                  // [
                  //   f((index * 5)),
                  //   f((index * 5) + 1),
                  //   f((index * 5) + 2),
                  //   f((index * 5) + 3),
                  //   f((index * 5) + 4)
                  // ],
                );
              }))),
    );
  }

  String get basicMediaRowName => "medias";

  ConsoleRow get basicMediasRow => ConsoleRow(widgets: [
        mediasBackButton,
        mediasImportButton,
        mediasTypeButton,
        mediasModeButton,
      ], extension: (
        mediasExtension,
        mediaExtensionHeight
      ), widths: null, inputMaxHeight: null);
}

mixin Camera2 on Pager2 {
  Size get _squaredCamSize => Size.square(Console.trueWidth);
  int _currentCam = 0;
  CameraController? cameraController;
  FireMedia? tempInput, cameraInput;
  bool get isReversed => _currentCam == 1;

  CameraDescription get cam => g.cameras[_currentCam];

  ConsoleButton get cameraButton => ConsoleButton(
        name: cameraInput == null ? "CAMERA" : "@CAMERA",
        onPress: () async {
          if (cameraController == null) {
            cameraController = CameraController(cam, ResolutionPreset.high);
            await cameraController?.initialize();
            changeConsole("camera");
          }
        },
      );

  String get backFromCameraConsoleName => "base";
  ConsoleButton get cameraCloseButton => ConsoleButton(
        name: "CLOSE",
        onPress: () async {
          tempInput = null;
          await cameraController?.dispose();
          cameraController = null;
          changeConsole(backFromCameraConsoleName);
        },
      );

  ConsoleButton get cameraSwitchButton => ConsoleButton(
        name: _currentCam == 0 ? "REAR" : "FRONT",
        onPress: () async {
          await cameraController?.dispose();
          cameraController = null;
          _currentCam = (_currentCam + 1) % 2;
          cameraButton.onPress.call();
        },
        isMode: true,
      );

  ConsoleButton get cameraCaptureButton => ConsoleButton(
        name: "CAPTURE",
        isSpecial: true,
        shouldBeDownButIsnt: cameraController?.value.isRecordingVideo ?? false,
        onPress: () async {
          final XFile f = await cameraController!.takePicture();
          tempInput = makeCameraMedia(
              cachedPath: f.path,
              size: cameraController!.value.previewSize!.inverted,
              isReversed: isReversed,
              owner: g.self.id,
              isSquared: true);
          changeConsole(cameraConfirmationRowName);
        },
        onLongPress: () async {
          await cameraController!.startVideoRecording();
          setTheState();
        },
        onLongPressUp: () async {
          final XFile f = await cameraController!.stopVideoRecording();
          tempInput = makeCameraMedia(
              cachedPath: f.path,
              size: cameraController!.value.previewSize!.inverted,
              isReversed: isReversed,
              owner: g.self.id,
              isSquared: true);
          changeConsole(cameraConfirmationRowName);
        },
      );

  ConsoleButton get cameraCancelButton => ConsoleButton(
      name: "CANCEL",
      onPress: () {
        cameraController?.dispose();
        cameraController = null;
        tempInput = null;
        changeConsole(backFromCameraConsoleName);
      });

  ConsoleButton get cameraAcceptButton => ConsoleButton(
      name: "ACCEPT",
      onPress: () {
        // ugly way to make a copy, but we don't really make copies
        // elsewhere so...
        cameraInput = FireMedia.fromJson(tempInput!.toJson(toLocal: true))
          ..cachePath = tempInput!.cachePath;

        cameraController?.dispose();
        cameraController = null;
        tempInput = null;
        changeConsole(backFromCameraConsoleName);
      });

  Widget get cameraExtension {
    if (tempInput != null) {
      return Container(
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(Pager2._widgetRadius)),
            // border: Border.all(
            //     color: g.theme.consoleBorderColor, width: Console.borderWidth),
          ),
          child: tempInput!.display(size: _squaredCamSize));
    } else if (cameraController != null) {
      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Pager2._widgetRadius)),
          // color: g.theme.consoleBorderColor,
          // border: Border.all(
          //     color: g.theme.consoleBorderColor, width: Console.borderWidth),
        ),
        child: SizedBox.square(
            dimension: Console.trueWidth,
            child: Transform.scale(
                scaleY: cameraController!.value.aspectRatio,
                child: CameraPreview(cameraController!))),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  ConsoleButton get cameraBackButton => ConsoleButton(
      name: "BACK",
      onPress: () {
        tempInput = null;
        changeConsole(basicCameraRowName);
      });

  String get basicCameraRowName => "camera";
  ConsoleRow get basicCameraRow => ConsoleRow(
          widgets: [
            // cameraBackButton,
            cameraCloseButton,
            // cameraCancelButton,
            cameraSwitchButton,
            // cameraAcceptButton,
            cameraCaptureButton,
          ],
          extension: (
            cameraExtension,
            g.sizes.w
          ),
          widths: null,
          // tempInput == null
          //     ? [0.0, 0.34, 0.0, 0.33, 0.0, 0.33]
          //     : [0.34, 0.0, 0.33, 0.0, 0.33, 0.0],
          inputMaxHeight: null);

  String get cameraConfirmationRowName => "cameraConfirmation";
  ConsoleRow get cameraConfirmationRow => ConsoleRow(widgets: [
        cameraBackButton,
        cameraCancelButton,
        cameraAcceptButton,
      ], extension: (
        cameraExtension,
        g.sizes.w
      ), widths: null, inputMaxHeight: null);
}

mixin Saver2 on Pager2 {
  void save() => changeConsole("saving");

  ConsoleButton get saveButton => ConsoleButton(name: "SAVE", onPress: save);
  ConsoleButton get toMessagesButton =>
      ConsoleButton(name: "TO_MESSAGES", onPress: saveToMessages);
  ConsoleButton get toMediasButton =>
      ConsoleButton(name: "TO_MEDIAS", onPress: saveToMedias);

  String get basicSavingRowName => "saving";

  ConsoleButton get backFromSavingButton =>
      ConsoleButton(name: "BACK", onPress: backFromSaving);

  void backFromSaving() => changeConsole("base");
  void saveToMessages();
  void saveToMedias();

  ConsoleRow get basicSavingRow =>
      ConsoleRow(extension: null, inputMaxHeight: null, widths: null, widgets: [
        backFromSavingButton,
        toMessagesButton,
        toMediasButton,
      ]);
}

mixin Compose2 on Pager2, Input2, Sender2, Medias2, Camera2 {
  String get basicComposeRowName => "compose";
  ConsoleRow get basicComposeRow => ConsoleRow(
      inputMaxHeight:
          input.hasFocus ? inputs.first.ctrl.height : Console.buttonHeight,
      extension: null,
      widgets: [
        mediasButton,
        cameraButton,
        inputs.first.consoleInput,
        sendButton
      ],
      widths: input.hasFocus ? [0.2, 0.0, 0.6, 0.2] : null);
}

mixin Money2 {
  void money();
  final GlobalKey _moneyButtonKey = GlobalKey();
  ConsoleButton get moneyButton =>
      ConsoleButton(key: _moneyButtonKey, name: "MONEY", onPress: money);
}

mixin Hyper2 {
  void hyper();
  ConsoleButton get hyperButton => ConsoleButton(name: "HYPER", onPress: hyper);
}

mixin Add2 {
  void add();
  ConsoleButton get addButton => ConsoleButton(name: "ADD", onPress: add);
}

mixin Scanner2 on Pager2 {
  void onScan(Barcode bc, MobileScannerArguments? args);
  MobileScanner? _scanner;

  Widget get scanner => _scanner ??= MobileScanner(
        onDetect: onScan,
        controller: MobileScannerController(),
      );

  bool scanning = false;

  ConsoleButton get scanButton => ConsoleButton(
      name: "SCAN",
      isMode: scanning,
      onPress: () {
        scanning = !scanning;
        if (!scanning) {
          _scanner?.controller?.dispose();
          _scanner = null;
        }
        setTheState();
      });

  void disposeScanner() {
    _scanner?.controller?.dispose();
  }

  Widget get scanExtension => Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(Pager2._widgetRadius))),
        // border: Border.all(
        //     width: borderWidth, color: g.theme.consoleBorderColor)),
        child: Stack(children: [
          Center(
              child: SizedBox(
                  height: Console.trueWidth,
                  width: Console.trueWidth,
                  child: scanner))
        ]),
      );
}

// abstract class BasicRows
//     with Pager2, Medias2, Sender2, Forwarder2, Input2, Camera2 {
//   ({String name, ConsoleRow row}) get basicCameraRow => (
//         name: "camera",
//         row: ConsoleRow(
//             widgets: [
//               cameraBackButton,
//               cameraCancelButton,
//               cameraSwitchButton,
//               cameraCaptureButton,
//               cameraAcceptButton,
//             ],
//             extension: (
//               cameraExtension,
//               g.sizes.w
//             ),
//             widths: cameraInput == null
//                 ? [0.34, 0.0, 0.33, 0.33, 0.0]
//                 : [0.34, 0.33, 0.0, 0.0, 0.33],
//             inputMaxHeight: null)
//       );
//
//   ({String name, ConsoleRow row}) get basicMediasRow => (
//         name: "medias",
//         row: ConsoleRow(widgets: [
//           mediasBackButton,
//           mediasImportButton,
//           mediasTypeButton,
//           mediasModeButton,
//         ], extension: (
//           mediasExtension,
//           mediaExtensionHeight
//         ), widths: null, inputMaxHeight: null)
//       );
//
//   ({String name, ConsoleRow row}) get basicComposingRow => (
//         name: "compose",
//         row: ConsoleRow(
//             inputMaxHeight: inputHeight,
//             extension: (mediasExtension, 0.0),
//             widgets: [mediasButton, cameraButton, input, sendButton],
//             widths: focusNode.hasFocus ? [0.2, 0.0, 0.6, 0.2] : null)
//       );
// }

// mixin Transition {
//   Transition get transition;
// }
//
// mixin Hyper on Transition {
//   void hyper(Transition t);
//   final GlobalKey _hyperKey = GlobalKey();
//   ConsoleButton get hyperButton => ConsoleButton(
//       key: _hyperKey, name: "HYPER", onPress: () => hyper(transition));
// }
//
// mixin Money on Transition {}

// mixin Chatter on Pager2, Medias2, Camera2 {
//   void send();
//   late Console3 newConsole;
//
//   void loadConsole({
//     void Function(FireMedia)? forNode,
//     bool images = true,
//   }) {
//     newConsole = Console3(
//       consoles: [
//         {
//           "base": (
//             extension: null,
//             inputMaxHeight: _inputHeight,
//             widths: _focusNode.hasFocus
//                 ? [0.20, 0.0, 0.6, 0.2]
//                 : [0.25, 0.25, 0.25, 0.25],
//             widgets: [
//               ConsoleButton(
//                   name: "MEDIAS",
//                   onPress: () {
//                     _currentConsole = "medias";
//                     setTheState();
//                   }),
//               ConsoleButton(
//                   name: _cameraInput == null ? "CAMERA" : "@CAMERA",
//                   onPress: () {
//                     _currentConsole = "camera";
//                     setTheState();
//                   }),
//               ConsoleInput2(_myTextEditor),
//               ConsoleButton(name: "SEND", onPress: send),
//             ]
//           ),
//           "medias": (
//             extension: SizedBox.shrink(),
//             inputMaxHeight: null,
//             widths: null,
//             widgets: [
//               ConsoleButton(
//                 name: "BACK",
//                 onPress: () {
//                   _currentConsole = "base";
//                   setTheState();
//                 },
//               ),
//               ConsoleButton(
//                   name: "IMPORT",
//                   onPress: () async {
//                     if (forNode != null) {
//                       final nodeMedia = await importNodeMedia();
//                       if (nodeMedia != null) {
//                         forNode.call(nodeMedia);
//                       }
//                     } else {
//                       await importConsoleMedias(
//                           images: images,
//                           reload: () {
//                             setTheState();
//                           });
//                     }
//                   }),
//               ConsoleButton(
//                 isMode: true,
//                 isActivated: forNode == null,
//                 isGreyedOut: forNode != null,
//                 name: images ? "IMAGES" : "VIDEOS",
//                 onPress: () => loadMediasConsole(!images, extra, forNode),
//               ),
//               ConsoleButton(
//                 name: curMode.first,
//                 isMode: true,
//                 onPress: () {
//                   currentMode = (currentMode + 1) % mediasMode.length;
//                   loadMediasConsole(images, extra, forNode);
//                 },
//               ),
//             ]
//           )
//         }
//       ],
//       currentConsoleName: _currentConsole,
//       currentPageIndex: _currentPage,
//     );
//   }
//
//   void loadConsole() {
//     console = Console(
//       bottomButtons: [],
//       consoleRow: Console3(
//         widgets: [
//           ConsoleButton(
//             name: _cameraInput == null ? "CAMERA" : "@CAMERA",
//             onPress: () => loadSquaredCameraConsole(0),
//           ),
//           ConsoleButton(
//             name: "MEDIAS",
//             onPress: () => loadMediasConsole(images),
//           ),
//           ConsoleInput2(te),
//           ConsoleButton(
//             name: "SEND",
//             onPress: () {
//               send();
//               loadBaseConsole();
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
// }

// mixin Camera on Pager {
//   FireMedia? get cameraInput;
//   set cameraInput(FireMedia? m);
//   Size get _squaredCamSize => Size.square(Console.trueWidth);
//   VideoPlayerController? videoPreview;
//   CameraController? cameraController;
//
//   Future<void> loadSquaredCameraConsole([int cam = 0]) async {
//     // focusNode?.unfocus();
//     if (cameraController == null) {
//       try {
//         cameraController =
//             CameraController(g.cameras[cam], ResolutionPreset.high);
//         await cameraController?.initialize();
//       } catch (e) {
//         loadBaseConsole();
//       }
//     }
//
//     final bool isReversed = cam == 1;
//     console = Console(
//       // bottomInputs: [mainInput],
//       cameraController: cameraController,
//       topButtons: [],
//       bottomButtons: [
//         ConsoleButton(
//             name: "BACK",
//             onPress: () {
//               cameraController?.dispose();
//               cameraController = null;
//               loadBaseConsole();
//             }),
//         ConsoleButton(
//             name: cam == 0 ? "REAR" : "FRONT",
//             onPress: () async {
//               await cameraController?.dispose();
//               cameraController = null;
//               loadSquaredCameraConsole((cam + 1) % 2);
//             },
//             isMode: true),
//         ConsoleButton(
//           name: "CAPTURE",
//           isSpecial: true,
//           shouldBeDownButIsnt: cameraController!.value.isRecordingVideo,
//           onPress: () async {
//             final XFile f = await cameraController!.takePicture();
//             print(
//                 "CAMERA PREVIEW SIZE = ${cameraController?.value.previewSize}");
//             final media = makeCameraMedia(
//                 cachedPath: f.path,
//                 size: cameraController!.value.previewSize!.inverted,
//                 isReversed: isReversed,
//                 owner: selfID,
//                 isSquared: true);
//             loadPreviewConsole(media);
//           },
//           onLongPress: () async {
//             await cameraController!.startVideoRecording();
//             loadSquaredCameraConsole(cam);
//           },
//           onLongPressUp: () async {
//             final XFile f = await cameraController!.stopVideoRecording();
//             final media = makeCameraMedia(
//                 cachedPath: f.path,
//                 size: cameraController!.value.previewSize!.inverted,
//                 isReversed: isReversed,
//                 owner: selfID,
//                 isSquared: true);
//             loadPreviewConsole(media);
//           },
//         ),
//       ],
//       // consoleRow: Console3(
//       //   widgets: [
//       //     ConsoleButton(
//       //         name: "BACK",
//       //         onPress: () {
//       //           cameraController?.dispose();
//       //           cameraController = null;
//       //           loadBaseConsole();
//       //         }),
//       //     ConsoleButton(
//       //         name: cam == 0 ? "REAR" : "FRONT",
//       //         onPress: () async {
//       //           await cameraController?.dispose();
//       //           cameraController = null;
//       //           loadSquaredCameraConsole((cam + 1) % 2);
//       //         },
//       //         isMode: true),
//       //     ConsoleButton(
//       //       name: "CAPTURE",
//       //       isSpecial: true,
//       //       shouldBeDownButIsnt: cameraController!.value.isRecordingVideo,
//       //       onPress: () async {
//       //         final XFile f = await cameraController!.takePicture();
//       //         print(
//       //             "CAMERA PREVIEW SIZE = ${cameraController?.value.previewSize}");
//       //         final media = makeCameraMedia(
//       //             cachedPath: f.path,
//       //             size: cameraController!.value.previewSize!.inverted,
//       //             isReversed: isReversed,
//       //             owner: selfID,
//       //             isSquared: true);
//       //         loadPreviewConsole(media);
//       //       },
//       //       onLongPress: () async {
//       //         await cameraController!.startVideoRecording();
//       //         loadSquaredCameraConsole(cam);
//       //       },
//       //       onLongPressUp: () async {
//       //         final XFile f = await cameraController!.stopVideoRecording();
//       //         final media = makeCameraMedia(
//       //             cachedPath: f.path,
//       //             size: cameraController!.value.previewSize!.inverted,
//       //             isReversed: isReversed,
//       //             owner: selfID,
//       //             isSquared: true);
//       //         loadPreviewConsole(media);
//       //       },
//       //     ),
//       //   ],
//       // ),
//     );
//
//     setTheState();
//   }
//
//   Future<VideoPlayerController?> _loopingController(FireMedia m) async {
//     if (!m.isVideo) return null;
//     final vpc = await m.videoController;
//     await vpc?.initialize();
//     return vpc
//       ?..setLooping(true)
//       ..play();
//   }
//
//   void loadPreviewConsole(FireMedia m) async {
//     // videoPreview = await _loopingController(m);
//     if (m.isVideo) {
//       final file = await m.cachedFile;
//       videoPreview = VideoPlayerController.file(file!);
//       await videoPreview?.initialize();
//       videoPreview?.setLooping(true);
//       videoPreview?.play();
//     }
//
//     Widget videoPlayer() {
//       return Down4VideoTransform(
//           displaySize: _squaredCamSize,
//           videoAspectRatio: m.aspectRatio,
//           video: VideoPlayer(videoPreview!),
//           isReversed: m.isReversed,
//           isScaled: true);
//     }
//
//     console = Console(
//       // bottomInputs: [mainInput],
//       previewMedia: m.isVideo
//           ? videoPlayer()
//           : m.displayImage(
//               size: _squaredCamSize,
//               forceSquare: true,
//             ), //, controller: vpc),
//       topButtons: [],
//       bottomButtons: [
//         ConsoleButton(
//           name: "BACK",
//           onPress: () {
//             // vpc?.dispose();
//             videoPreview?.dispose();
//             loadSquaredCameraConsole(m.isReversed ? 1 : 0);
//           },
//         ),
//         ConsoleButton(
//             name: "CANCEL",
//             onPress: () {
//               cameraController?.dispose();
//               cameraController = null;
//               videoPreview?.dispose();
//               loadBaseConsole();
//             }),
//         ConsoleButton(
//             name: "ACCEPT",
//             onPress: () {
//               // vpc?.dispose();
//               cameraController?.dispose();
//               cameraController = null;
//               videoPreview?.dispose();
//               cameraInput = m;
//               loadBaseConsole();
//             }),
//       ],
//       // consoleRow: Console3(
//       //   widgets: [
//       //     ConsoleButton(
//       //       name: "BACK",
//       //       onPress: () {
//       //         // vpc?.dispose();
//       //         videoPreview?.dispose();
//       //         loadSquaredCameraConsole(m.isReversed ? 1 : 0);
//       //       },
//       //     ),
//       //     ConsoleButton(
//       //         name: "CANCEL",
//       //         onPress: () {
//       //           cameraController?.dispose();
//       //           cameraController = null;
//       //           videoPreview?.dispose();
//       //           loadBaseConsole();
//       //         }),
//       //     ConsoleButton(
//       //         name: "ACCEPT",
//       //         onPress: () {
//       //           // vpc?.dispose();
//       //           cameraController?.dispose();
//       //           cameraController = null;
//       //           videoPreview?.dispose();
//       //           cameraInput = m;
//       //           loadBaseConsole();
//       //         }),
//       //   ],
//       // ),
//     );
//     setTheState();
//   }
// }

// mixin Medias on Pager {
//   List<Pair<String, void Function(FireMedia)>> get mediasMode;
//
//   int currentMode = 0;
//
//   Pair<String, void Function(FireMedia)> get curMode => mediasMode[currentMode];
//
//   void loadMediasConsole([
//     bool images = true,
//     bool extra = false,
//     void Function(FireMedia)? forNode,
//   ]) {
//     // focusNode?.unfocus();
//     console = Console(
//       // bottomInputs: [mainInput],
//
//       // topButtons: [
//       //   ConsoleButton(
//       //       name: "Import",
//       //       onPress: () async {
//       //         if (forNode != null) {
//       //           final nodeMedia = await importNodeMedia();
//       //           if (nodeMedia != null) {
//       //             forNode.call(nodeMedia);
//       //           }
//       //         } else {
//       //           await importConsoleMedias(
//       //               images: images,
//       //               reload: () => loadMediasConsole(images, extra, forNode));
//       //         }
//       //       }),
//       // ],
//       // bottomButtons: [
//       //   ConsoleButton(
//       //     showExtra: extra,
//       //     isSpecial: forNode == null ? true : false,
//       //     name: "Back",
//       //     onPress: () => extra && forNode == null
//       //         ? loadMediasConsole(images, !extra, forNode)
//       //         : loadBaseConsole(),
//       //     onLongPress: () => forNode == null
//       //         ? loadMediasConsole(images, !extra, forNode)
//       //         : null,
//       //     extraButtons: [
//       //       ConsoleButton(
//       //         name: curMode.first,
//       //         onPress: () {
//       //           currentMode = (currentMode + 1) % mediasMode.length;
//       //           loadMediasConsole(images, extra, forNode);
//       //         },
//       //         isMode: true,
//       //       ),
//       //     ],
//       //   ),
//       //   ConsoleButton(
//       //     isMode: true,
//       //     isActivated: forNode == null,
//       //     isGreyedOut: forNode != null,
//       //     name: images ? "Images" : "Videos",
//       //     onPress: () => loadMediasConsole(!images, extra, forNode),
//       //   ),
//       // ],
//       bottomButtons: [
//         ConsoleButton(
//           showExtra: extra,
//           name: "BACK",
//           onPress: () {
//             loadBaseConsole();
//             focusRoutine();
//           },
//         ),
//         ConsoleButton(
//             name: "IMPORT",
//             onPress: () async {
//               if (forNode != null) {
//                 final nodeMedia = await importNodeMedia();
//                 if (nodeMedia != null) {
//                   forNode.call(nodeMedia);
//                 }
//               } else {
//                 await importConsoleMedias(
//                     images: images,
//                     reload: () => loadMediasConsole(images, extra, forNode));
//               }
//             }),
//         ConsoleButton(
//           isMode: true,
//           isActivated: forNode == null,
//           isGreyedOut: forNode != null,
//           name: images ? "IMAGES" : "VIDEOS",
//           onPress: () => loadMediasConsole(!images, extra, forNode),
//         ),
//         ConsoleButton(
//           name: curMode.first,
//           isMode: true,
//           onPress: () {
//             currentMode = (currentMode + 1) % mediasMode.length;
//             loadMediasConsole(images, extra, forNode);
//           },
//         ),
//       ],
//       medias: ConsoleMedias2(
//         images: images,
//         onSelect: forNode ?? curMode.second,
//       ),
//       // consoleRow: Console3(
//       //   widgets: [
//       //     ConsoleButton(
//       //       showExtra: extra,
//       //       name: "BACK",
//       //       onPress: () {
//       //         loadBaseConsole();
//       //         focusRoutine();
//       //       },
//       //     ),
//       //     ConsoleButton(
//       //         name: "IMPORT",
//       //         onPress: () async {
//       //           if (forNode != null) {
//       //             final nodeMedia = await importNodeMedia();
//       //             if (nodeMedia != null) {
//       //               forNode.call(nodeMedia);
//       //             }
//       //           } else {
//       //             await importConsoleMedias(
//       //                 images: images,
//       //                 reload: () => loadMediasConsole(images, extra, forNode));
//       //           }
//       //         }),
//       //     ConsoleButton(
//       //       isMode: true,
//       //       isActivated: forNode == null,
//       //       isGreyedOut: forNode != null,
//       //       name: images ? "IMAGES" : "VIDEOS",
//       //       onPress: () => loadMediasConsole(!images, extra, forNode),
//       //     ),
//       //     ConsoleButton(
//       //       name: curMode.first,
//       //       isMode: true,
//       //       onPress: () {
//       //         currentMode = (currentMode + 1) % mediasMode.length;
//       //         loadMediasConsole(images, extra, forNode);
//       //       },
//       //     ),
//       //   ],
//       // ),
//     );
//
//     setTheState();
//   }
// }

// mixin Sender {
//   Future<void> send({FireMedia? mediaInput});
// }

FireMedia makeCameraMedia({
  required String cachedPath,
  required Size size,
  required bool isReversed,
  required String owner,
  required bool isSquared,
}) {
  final mime = lookupMimeType(cachedPath)!;
  final data = File(cachedPath).readAsBytesSync();
  final id = deterministicMediaID(data, owner);
  return FireMedia(id,
      ownerID: owner,
      timestamp: makeTimestamp(),
      width: size.width,
      height: size.height,
      cachePath: cachedPath,
      tinyThumbnail: makeTiny(data),
      isSquared: isSquared,
      isReversed: isReversed,
      mime: mime);
}