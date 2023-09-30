// import 'dart:io';
import 'package:camera/camera.dart';
import 'package:down4/src/data_objects/nodes.dart';
// import 'package:down4/src/render_objects/navigator.dart';
import 'package:down4/src/render_objects/palette.dart';
import 'package:flutter_video_info/flutter_video_info.dart';

import 'package:image/image.dart' as img;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mime/mime.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';

import '../_dart_utils.dart';

import '../data_objects/couch.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../data_objects/messages.dart';

import '../globals.dart';

import '../render_objects/_render_utils.dart';
import '../render_objects/console.dart';

class Caret extends CustomPainter {
  Rect caret;
  Caret(this.caret);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(caret, Paint()..color = g.theme.inputTextStyle.color!);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class InputController implements Listenable {
  String value = "";
  String _placeHolder;
  final TextEditingController _tec;

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

  String get currentConsoleName => currentConsolesName[currentPageIndex];

  List<String> get currentConsolesName;
  set currentConsolesName(List<String> currentConsolesName);

  Icon get closeButtonIcon =>
      Icon(Icons.keyboard_arrow_down, color: g.theme.buttonTextColor);

  BuildContext get context;

  List<Extra> get extras;
  set extras(List<Extra> e);

  static const double _widgetRadius = 2.0;

  void turnOffExtras() {
    for (final e in extras) {
      if (e.show) e.flip();
    }
  }

  void changeConsole(String consoleName) async {
    // shit's just slow, need better alternative
    // if (consoleName == "medias") {
    //   final mediaIDs = g.savedMediasIDs[MediaType.images]!;
    //   final l = mediaIDs.length > 40 ? 40 : mediaIDs.length;
    //   for (int i = 0; i < l; i++) {
    //     final m = local<Down4Image>(mediaIDs[i]);
    //     final imProvider = m?.localImage(Size.square(Medias2.mediaCelSize));
    //     if (imProvider != null) await precacheImage(imProvider, context!);
    //   }
    // }

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
  void send({Down4Media? mediaInput});

  ConsoleButton get sendButton => ConsoleButton(name: "SEND", onPress: send);
}

mixin Boost2 {
  void boost();
  ConsoleButton get boostButton => ConsoleButton(name: "BOOST", onPress: boost);
}

mixin Append2 on Pager2, Forward2, Boost2 {
  void clearForwards() {
    g.vm.forwardingObjects.clear();
    g.vm.mode = Modes.def;
    setTheState();
  }

  void append() {
    turnOffExtras();
    g.vm.forwardingObjects.addAll(g.vm.currentView.allPageSelection());
    g.vm.currentView.unselectEverything();
    g.vm.mode = Modes.append;
    setTheState();
  }

  ConsoleButton get cancelButton =>
      ConsoleButton(name: "CANCEL", onPress: clearForwards);

  ConsoleButton get appendButton =>
      ConsoleButton(name: "APPEND", onPress: append);

  ConsoleRow get basicAppendRow => ConsoleRow(
        widths: null,
        extension: null,
        inputMaxHeight: null,
        widgets: [appendButton, cancelButton, boostButton, forwardButton],
      );
}

mixin Forward2 {
  void forward();

  ConsoleButton get forwardButton =>
      ConsoleButton(name: "FORWARD", onPress: forward);
}

mixin Input2 on Pager2, WidgetsBindingObserver {
  List<MyTextEditor> get inputs;
  set inputs(List<MyTextEditor> ic) => inputs = ic;
  void onInput(String s, double h) => setTheState();

  MyTextEditor get input => inputs.first;

  Iterable<FocusNode> get focusNodes => inputs.map((e) => e.fn);

  bool get hasFocus => focusNodes.any((element) => element.hasFocus);

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
  
  // BuildContext get context;

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

// class Trans {
//   final Set<PersonN> trueTargets;
//   final List<Palette> animatedPalettes;
//   final int nHidden;
//   Trans(this.animatedPalettes, this.nHidden, this.trueTargets);
// }

mixin Transition2 on Pager2 {
  List<Down4Widget>? transitedPalettes;
  set trueTargets(Set<PersonN> tt);

  TickerProvider get ticker;

  Duration get transDuration => const Duration(milliseconds: 600);

  ScrollController get mainScroll;

  final Tween<double> oneToZero = Tween<double>(begin: 1.0, end: 0.0);
  late final CurvedAnimation curved = CurvedAnimation(
    parent: foldAnim,
    curve: Curves.easeInOut,
  );

  late final AnimationController foldAnim = AnimationController(
      vsync: ticker, duration: const Duration(milliseconds: 600));
  late final AnimationController fadeAnim = AnimationController(
      vsync: ticker, duration: const Duration(milliseconds: 100));

  (List<Palette>, int, Set<PersonN>) transitionPalettes(
      List<Palette> originals) {
    Iterable<Palette> selection = originals.selected();
    Iterable<GroupN> sGroup = selection.asNodes<GroupN>();
    Iterable<Down4ID> userSel = selection.whereNodeIs<PersonN>().asIDs();
    Iterable<Down4ID> ofGroup = sGroup.map((g) => g.members).expand((e) => e);
    Set<Down4ID> fullSel = userSel.followedBy(ofGroup).toSet();
    final ogs = originals
        .where((p) => p.show)
        .followedBy(originals.where((p) => !p.show));

    final sizeAnim_ = oneToZero.animate(curved);
    final fadeAnim_ = oneToZero.animate(fadeAnim);

    int nHidden = 0;
    Set<PersonN> trueTargets = {};
    final animatedPalettes = ogs.map((p) {
      final inSel = fullSel.contains(p.id);
      final there = p.node is PersonN && inSel;
      final stayHid = !p.show && !inSel;
      final wasHid = !p.show && inSel;
      if (there) trueTargets.add(p.node as PersonN);
      if (wasHid) nHidden++;
      return Palette(
          key: Key(p.node.id.unik),
          node: p.node,
          sizeAnim: there ? null : sizeAnim_,
          fadeAnim: there ? null : fadeAnim_,
          bFadeAnim: fadeAnim_,
          buttonsInfo2: p.buttonsInfo2.thatDoesNothing(),
          show: !stayHid);
    }).toList();

    return (animatedPalettes, nHidden, trueTargets);
  }

  void animatedTransition(List<Palette>? ogs, double? ogOffset) {
    if (ogs == null && ogOffset == null) return;
    final (transited, nHidden, tt) = transitionPalettes(ogs!);
    trueTargets = tt;
    print("there are $nHidden hidden palettes!");
    Future(() {
      final offset = nHidden * Palette.fullHeight;
      transitedPalettes = transited;
      mainScroll.jumpTo(ogOffset! + offset);
      mainScroll.animateTo(0, duration: transDuration, curve: Curves.easeInOut);
      foldAnim.forward();
      fadeAnim.forward();
      setTheState();
    });
  }
}

mixin Medias2 on Pager2 {
  static int get _mediasPerRow => 5;
  static int get _nRows => 3;
  static double get mediaCelSize => Console.trueWidth / _mediasPerRow;
  static Size get celSize => Size.square(mediaCelSize);
  double get mediaExtensionHeight => mediaCelSize * _nRows;

  MediaType t = MediaType.images;
  void nextType({MediaType? specificType}) {
    if (specificType != null) {
      t = specificType;
    } else {
      final int ix = MediaType.values.indexOf(t);
      final int nx = (ix + 1) % MediaType.values.length;
      t = MediaType.values.elementAt(nx);
    }
    setTheState();
  }

  (String, void Function(Down4Media))? forMediaMode;
  Chat? reactingTo;

  List<(String, void Function(Down4Media))> get mediasMode;

  int currentMode = 0;
  (String, void Function(Down4Media)) get curMode => mediasMode[currentMode];
  void Function(Down4Media) get curFunc => forMediaMode?.$2 ?? curMode.$2;

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
          await importConsoleMedias(type: t, reload: setTheState);
        }
      });

  ConsoleButton get mediasTypeButton => ConsoleButton(
      isMode: true,
      isActivated: forMediaMode == null,
      isGreyedOut: forMediaMode != null,
      name: t.name.toUpperCase(),
      onPress: nextType);

  ConsoleButton get mediasModeButton => ConsoleButton(
      name: forMediaMode?.$1 ?? curMode.$1,
      isMode: true,
      isActivated: forMediaMode == null,
      onPress: () {
        currentMode = (currentMode + 1) % mediasMode.length;
        setTheState();
      });

  Widget get mediasExtension3 {
    return CustomList(forMediaMode?.$2 ?? curMode.$2, t);
  }

  Widget get mediasExtension {
    final ids = g.savedMediasIDs[t]!;
    final nRows = (ids.length / _mediasPerRow).ceil();
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(Console.consoleRad)),
        // color: Colors.white10, //g.theme.buttonTextColor,
      ),
      // border: Border.all(
      //     color: g.theme.consoleBorderColor, width: Console.borderWidth)),
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: _nRows * mediaCelSize, maxWidth: Console.trueWidth),
          child: ListView.builder(
              itemCount: nRows,
              itemBuilder: ((context, index) {
                Widget f(int i) {
                  if (i < ids.length) {
                    final cachedMedia = cache<Down4Media>(ids[i]);
                    if (cachedMedia != null) {
                      return GestureDetector(
                          onTap: () => forMediaMode != null
                              ? forMediaMode!.$2.call(cachedMedia as Down4Image)
                              : curMode.$2(cachedMedia),
                          child: cachedMedia is Down4Image
                              ? cachedMedia.display(
                                  key: Key("console${cachedMedia.id.value}"),
                                  size: Size.square(mediaCelSize))
                              : cachedMedia.display(
                                  key: Key("console${cachedMedia.id.value}"),
                                  size: Size.square(mediaCelSize),
                                  forceSquare: true));
                    }
                    return FutureBuilder(
                      future: global<Down4Media>(ids[i]),
                      builder: (ctx, ans) {
                        if (ans.connectionState == ConnectionState.done &&
                            ans.hasData) {
                          return GestureDetector(
                              onTap: () => ans.data != null
                                  ? curMode.$2(ans.data!)
                                  : null,
                              child: ans.requireData?.display(
                                      key: Key(
                                          "console-${ans.requireData?.id.value}"),
                                      size: Size.square(mediaCelSize),
                                      forceSquare: true) ??
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
                  key: Key(t.name + index.toString()),
                  children: List.generate(
                    _mediasPerRow,
                    (j) => f((index * _mediasPerRow) + j),
                  ),
                );
              }))),
    );
  }

  Widget get mediasExtension2 {
    final ids = g.savedMediasIDs[t]!;
    final idsWithPrefix = ids.map((id) => (id, "console"));
    final s = Size.square(mediaCelSize);
    final imStream = ImageCacheManager(t)
        .throttledImages(idsWithPrefix, size: s)
        .asBroadcastStream();
    final nRows = (ids.length / _mediasPerRow).ceil();

    return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Console.consoleRad)),
        ),
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: _nRows * mediaCelSize, maxWidth: Console.trueWidth),
            child: ListView.builder(
                itemCount: nRows,
                itemBuilder: (ctx, index) {
                  Widget f(int i) {
                    if (i < ids.length) {
                      final id = ids[i];
                      final readyImage =
                          ImageCacheManager(t).readyMedia("console${id.unik}");
                      if (readyImage != null) {
                        return GestureDetector(
                            onTap: () => forMediaMode != null
                                ? forMediaMode!.$2.call(readyImage.media)
                                : curMode.$2(readyImage.media),
                            child: SizedBox.square(
                                dimension: mediaCelSize, child: readyImage));
                      }
                      return FutureBuilder(
                        future: imStream.elementAt(i),
                        builder: (ctx, ans) {
                          final isDone =
                              ans.connectionState == ConnectionState.done;
                          if (isDone && ans.hasData) {
                            return GestureDetector(
                                onTap: () => curMode.$2(ans.data!.media),
                                child: SizedBox.square(
                                    dimension: mediaCelSize, child: ans.data!));
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
                    key: Key(t.name + index.toString()),
                    children: List.generate(
                      _mediasPerRow,
                      (j) => f((index * _mediasPerRow) + j),
                    ),
                  );
                })));
  }

  String get basicMediaRowName => "medias";

  ConsoleRow get basicMediasRow => ConsoleRow(widgets: [
        mediasBackButton,
        mediasImportButton,
        mediasTypeButton,
        mediasModeButton,
      ], extension: (
        mediasExtension3,
        // mediasExtension2,
        // mediasExtension,
        mediaExtensionHeight
      ), widths: null, inputMaxHeight: null);
}

mixin Camera2 on Pager2 {
  Size get _squaredCamSize => Size.square(Console.trueWidth);
  int _currentCam = 0;
  CameraController? cameraController;
  Down4Media? tempInput, cameraInput;
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
          changeConsole(backFromCameraConsoleName);
          tempInput = null;
          await cameraController?.dispose();
          cameraController = null;
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
          final im = img.decodeImage(await f.readAsBytes());
          if (im == null) return changeConsole(backFromCameraConsoleName);
          tempInput = Down4Media.fromLocal(ComposedID(),
              mainCachedPath: f.path,            
              metadata: Down4MediaMetadata(
                  ownerID: g.self.id,
                  isSquared: true,
                  isReversed: isReversed,                  
                  timestamp: makeTimestamp(),
                  width: im.width.toDouble(),
                  height: im.height.toDouble(),
                  mime: lookupMimeType(f.path)!));

          // tempInput = await makeCameraMedia(
          //     writeFromCachedPath: false,
          //     cachedPath: f.path,
          //     size: cameraController!.value.previewSize!.inverted,
          //     isReversed: isReversed,
          //     owner: g.self.id,
          //     isSquared: true);
          changeConsole(cameraConfirmationRowName);
        },
        onLongPress: () async {
          await cameraController!.startVideoRecording();
          setTheState();
        },
        onLongPressUp: () async {
          final XFile f = await cameraController!.stopVideoRecording();
          final videoInfo = await FlutterVideoInfo().getVideoInfo(f.path);
          if (videoInfo == null) return changeConsole(backFromCameraConsoleName);
          tempInput = Down4Media.fromLocal(ComposedID(),
              mainCachedPath: f.path,
              metadata: Down4MediaMetadata(
                  ownerID: g.self.id,
                  isSquared: true,
                  isReversed: isReversed,
                  timestamp: makeTimestamp(),
                  width: videoInfo.width!.toDouble(),
                  height: videoInfo.height!.toDouble(),
                  mime: lookupMimeType(f.path)!));

          // tempInput = await makeCameraMedia(
          //     writeFromCachedPath: false,
          //     cachedPath: f.path,
          //     size: cameraController!.value.previewSize!.inverted,
          //     isReversed: isReversed,
          //     owner: g.self.id,
          //     isSquared: true);
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
        cameraInput = Down4Media.fromJson(tempInput!.toJson(includeLocal: true))
          ..mainCachedPath = tempInput!.mainCachedPath;

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
          child: tempInput!.display(
              size: _squaredCamSize, forceSquare: true, autoPlay: true));
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
  ConsoleRow get basicCameraRow => ConsoleRow(widgets: [
        cameraCloseButton,
        cameraSwitchButton,
        cameraCaptureButton,
      ], extension: (
        cameraExtension,
        g.sizes.w
      ), widths: null, inputMaxHeight: null);

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
  void onScan(Barcode bc);
  Widget? _scanner;

  QRViewController? _ctrl;

  void loadScanner() {
    _scanner = null;
    _scanner = QRView(
      key: GlobalKey(),
      onQRViewCreated: (ctrl) {
        scanning = true;
        _ctrl = ctrl;
        ctrl.scannedDataStream.listen(onScan);
      },
      overlay: QrScannerOverlayShape(
          borderWidth: 6,
          borderColor: g.theme.headerColor,
          cutOutSize: g.sizes.w * 0.92,
          overlayColor: Colors.black45),
    );
    setTheState();
  }

  bool scanning = false;

  ConsoleButton get scanButton => ConsoleButton(
      name: "SCAN",
      isMode: scanning,
      onPress: () {
        scanning = !scanning;
        if (!scanning) {
          _ctrl?.dispose();
          _scanner = null;
          // _scanner?.controller?.dispose();
          // _scanner = null;
        } else {
          // Future.delayed(Andrew.pageSwitchAnimationDuration, loadScanner);
          Future.delayed(const Duration(milliseconds: 300), loadScanner);
        }
        setTheState();
      });

  void disposeScanner() {
    _ctrl?.dispose();
    _scanner = null;
    // _scanner?.controller?.dispose();
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
                  child: _scanner))
        ]),
      );
}

// Future<Down4Media> makeCameraMedia({
//   required String cachedPath,
//   required Size size,
//   required bool isReversed,
//   required ComposedID owner,
//   required bool isSquared,
//   // bool temporary = false,
//   required bool writeFromCachedPath,
// }) async {
//   final id = ComposedID(region: owner.region);
//   final bool needWrite = !temporary || isSquared;
//   if (needWrite) {
//     final pGen = temporary ? Down4Media.cachePath_ : Down4Media.mainPath_;
//     final p = pGen(id);
//     if (isSquared) {
//       await cropAndSaveToSquare(from: File(cachedPath), to: File(p));
//     } else {
//       await File(cachedPath).copy(p);
//     }
//   }

//   // if it's video, we make a thumbnail
//   final mime = lookupMimeType(cachedPath)!;
//   final isVideo = videoMimes.contains(mime);
//   if (!temporary && isVideo) {
//     final p = "${Down4Media.mainPath_(id)}-tn";
//     await VideoThumbnail.thumbnailFile(
//         video: cachedPath, thumbnailPath: p, quality: 80);
//   }

//   return Down4Media.fromLocal(id, metadata: Down4MediaMetadata(
//           ownerID: owner,
//           isSquared: isSquared,
//           isReversed: isReversed,
//           timestamp: makeTimestamp(),
//           width: size.width,
//           height: size.height,
//           mime: mime));

//   // final data = File(cachedPath).readAsBytesSync();
//   // final id = ComposedID(region: owner.region);
//   // final toPath = Down4Media.mainPath_(id);
//   // cropAndSaveToSquare(from: File(cachedPath), to: File(toPath));
//   // final im = img.decodeImage(data);
  

//   // final tinyThumbnail = isVideo ? null : makeTiny(data);
//   // return Down4Media.fromLocal2(
//   //     ComposedID(region: owner.region), // hack for init
//   //     mainCachedPath: cachedPath,
//   //     writeFromCachedPath: writeFromCachedPath,
//   //     metadata: Down4MediaMetadata(
//   //         ownerID: owner,
//   //         isSquared: isSquared,
//   //         isReversed: isReversed,
//   //         timestamp: makeTimestamp(),
//   //         width: size.width,
//   //         height: size.height,
//   //         mime: mime));
//   // tinyThumbnail: tinyThumbnail);
// }
