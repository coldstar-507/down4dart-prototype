import 'dart:io' as io;
import 'dart:math' as math;

import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';
import 'palette.dart';
import '../down4_utility.dart';

import 'render_utils.dart';

class ConsoleButton extends StatelessWidget {
  static const double height = 26.0;
  final String name;
  final List<ConsoleButton>? extraButtons;
  final bool isSpecial, isMode, shouldBeDownButIsnt, isActivated, showExtra;
  final void Function() onPress;
  final void Function()? onLongPress;
  final void Function()? onLongPressUp;
  final double leftEpsilon, bottomEpsilon, widthEpsilon, heightEpsilon;
  final bool invertColors;

  const ConsoleButton({
    this.invertColors = false,
    required this.name,
    required this.onPress,
    this.leftEpsilon = 0.0,
    this.bottomEpsilon = 0.0,
    this.widthEpsilon = 0.0,
    this.heightEpsilon = 0.0,
    this.extraButtons,
    this.showExtra = false,
    this.shouldBeDownButIsnt = false,
    this.isMode = false,
    this.isSpecial = false,
    this.isActivated = true,
    this.onLongPress,
    this.onLongPressUp,
    Key? key,
  }) : super(key: key);

  ConsoleButton invertedColors() => ConsoleButton(
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        invertColors: true,
        leftEpsilon: leftEpsilon,
        bottomEpsilon: bottomEpsilon,
        widthEpsilon: widthEpsilon,
        heightEpsilon: heightEpsilon,
        extraButtons: extraButtons,
        showExtra: showExtra,
        shouldBeDownButIsnt: shouldBeDownButIsnt,
        isMode: isMode,
        isSpecial: isSpecial,
        isActivated: isActivated,
        key: key,
      );

  // ConsoleButton2 toTransit(String prevName) {
  //   return ConsoleButton2(
  //     prevName: prevName,
  //     onPress: onPress,
  //     name: name,
  //     extraButtons: extraButtons,
  //     showExtra: showExtra,
  //     shouldBeDownButIsnt: shouldBeDownButIsnt,
  //     isMode: isMode,
  //     isSpecial: isSpecial,
  //     isActivated: isActivated,
  //     onLongPress: onLongPress,
  //     onLongPressUp: onLongPressUp,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final buttonHeight = Sizes.h * 0.038; // 3.8%
    return Expanded(
      child: Container(
        height: buttonHeight,
        decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: invertColors ? null : PinkTheme.black,
            border: Border.all(color: Colors.black, width: 0.5)),
        child: isActivated
            ? TouchableOpacity(
                shouldBeDownButIsnt: shouldBeDownButIsnt,
                onPress: onPress,
                onLongPress: onLongPress,
                onLongPressUp: onLongPressUp,
                child: Container(
                  color: invertColors ? Colors.black12 : PinkTheme.buttonColor,
                  child: Center(
                    child: Text(
                      name,
                      style: TextStyle(
                        color:
                            invertColors ? PinkTheme.buttonColor : Colors.black,
                        decoration: isSpecial ? TextDecoration.underline : null,
                        decorationStyle: TextDecorationStyle.solid,
                        fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                color: PinkTheme.inactivatedButtonColor,
                child: Center(
                  child: Text(
                    name,
                    style: TextStyle(
                      decoration: isSpecial ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.solid,
                      fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
                      fontWeight: FontWeight.bold,
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
  final TextInputType type;
  final bool activated;
  final String placeHolder;
  final String value;
  final String prefix, suffix;
  final int? maxLines;
  final void Function(String)? inputCallBack;
  final TextEditingController tec;
  final bool? b;
  const ConsoleInput({
    this.b,
    this.type = TextInputType.text,
    this.inputCallBack,
    this.maxLines,
    required this.placeHolder,
    required this.tec,
    this.prefix = "",
    this.suffix = "",
    this.value = "",
    this.activated = true,
    Key? key,
  }) : super(key: key);

  double get buttonHeight => Sizes.h * 0.038; // 3.8%

  ConsoleInput animated(bool b) => ConsoleInput(
        type: type,
        placeHolder: placeHolder,
        tec: tec,
        activated: activated,
        value: value,
        prefix: prefix,
        suffix: suffix,
        inputCallBack: inputCallBack,
        b: b,
      );

  Widget get activatedField => TextField(
        controller: tec,
        cursorColor: PinkTheme.black,
        key: GlobalKey(),
        maxLines: maxLines,
        keyboardType: type,
        textAlignVertical: TextAlignVertical.center,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: true,
          contentPadding: const EdgeInsets.all(2.0),
          hintText: placeHolder,
          border: InputBorder.none,
          prefixIcon: Text(prefix),
          prefixIconConstraints: const BoxConstraints(
            minHeight: 0,
            minWidth: 0,
          ),
          suffixIcon: Text(suffix),
          suffixIconConstraints: const BoxConstraints(
            minHeight: 0,
            minWidth: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
        onChanged: inputCallBack,
      );

  Widget get unactivatedField => Center(child: Text(placeHolder));

  Widget animatedContainer({required Widget child}) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(
        minHeight: b! ? 0 : buttonHeight,
        maxHeight: b! // ? 0 : buttonHeight,
            ? 0
            : activated
                ? buttonHeight * 4
                : buttonHeight,
      ),
      decoration: BoxDecoration(
        color:
            activated ? Colors.white : const Color.fromARGB(255, 216, 212, 212),
        border: Border.all(color: Colors.black, width: b! ? 0 : 0.5),
      ),
      child: child);

  Widget unanimatedContainer({required Widget child}) => Container(
      constraints: BoxConstraints(
        minHeight: b! ? 0 : buttonHeight,
        maxHeight: activated ? buttonHeight * 4 : buttonHeight,
      ),
      decoration: BoxDecoration(
        color:
            activated ? Colors.white : const Color.fromARGB(255, 216, 212, 212),
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: child);

  @override
  Widget build(BuildContext context) {
    print("Text field is animated: $b");
    return Expanded(
        child: b != null || activated
            ? animatedContainer(child: activatedField)
            : unanimatedContainer(child: unactivatedField));
  }
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? topButtons;
  final List<ConsoleButton> bottomButtons;
  final CameraController? cameraController;
  final double? aspectRatio;
  final bool? toMirror, images;
  final List<Down4Media>? medias;
  final void Function(Down4Media)? selectMedia;
  final String? imagePreviewPath;
  final VideoPlayerController? videoPlayerController;
  final List<ConsoleInput>? inputs, topInputs;
  final MobileScannerController? scanController;
  final dynamic Function(Barcode, MobileScannerArguments?)? scanCallBack;
  final List<Palette>? forwardingPalette;
  final bool invertedColors;

  int get nImageRows => (b.images.keys.length / 5).ceil();
  double get rowHeight => (consoleWidth / 5);
  // double get initialHeight => rowHeight;
  // double get currentHeight => initialHeight;
  // double get maxHeight => rowHeight * 1; //((nImageRows < 7) ? nImageRows : 7);
  double get mediasHeight =>
      nImageRows == 0 ? rowHeight : rowHeight * nImageRows;

  List<Widget> get extraTopButtons {
    final consoleHorizontalGap = Sizes.h * 0.023;
    final consoleVerticalGap = Sizes.h * 0.021;
    final buttonWidth = ((Sizes.w - (consoleHorizontalGap * 2.0)) /
            (bottomButtons.length.toDouble())) +
        1.0; // 1.0 for borders
    List<Widget> extras = [];
    int i = 0;
    for (final b in topButtons ?? <ConsoleButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
          bottom: consoleVerticalGap + (ConsoleButton.height * 2),
          left: consoleHorizontalGap + (buttonWidth * i),
          child: Container(
            height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
            width: buttonWidth,
            decoration: BoxDecoration(border: Border.all(width: 0.5)),
            child: Column(children: b.extraButtons!),
          ),
        ));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  List<Widget> get extraBottomButtons {
    final horizontalGap = Sizes.h * 0.023;
    final verticalGap = Sizes.h * 0.021;
    final nBottomButton = bottomButtons.length;
    final buttonWidth = (Sizes.w - (2 * horizontalGap)) / nBottomButton;
    List<Widget> extras = [];
    int i = 0;
    for (final b in bottomButtons) {
      final nExtra = b.extraButtons?.length ?? 0;
      if (b.showExtra && nExtra > 0) {
        extras.add(Positioned(
            bottom: verticalGap + ConsoleButton.height + b.bottomEpsilon,
            left: horizontalGap + (buttonWidth * i) + b.leftEpsilon,
            child: Container(
              height: (nExtra * ConsoleButton.height) + b.heightEpsilon,
              width: buttonWidth + b.widthEpsilon,
              decoration: BoxDecoration(border: Border.all(width: 0.5)),
              child: Column(children: b.extraButtons!),
            )));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  double get consoleWidth => Sizes.w - (Sizes.h * 0.023 * 2);

  bool get bb =>
      images == true ||
      cameraController != null ||
      imagePreviewPath != null ||
      videoPlayerController != null ||
      scanController != null;

  const Console({
    required this.bottomButtons,
    this.invertedColors = false,
    this.forwardingPalette,
    this.selectMedia,
    this.images,
    this.medias,
    this.imagePreviewPath,
    this.videoPlayerController,
    this.toMirror,
    this.aspectRatio,
    this.cameraController,
    this.inputs,
    this.topInputs,
    this.topButtons,
    this.scanCallBack,
    this.scanController,
    Key? key,
  }) : super(key: key);

  Widget mainContainer({required List<Widget> children}) => Container(
        margin: EdgeInsets.only(
            left: Sizes.h * 0.023,
            right: Sizes.h * 0.023,
            bottom: Sizes.h * 0.021),
        decoration: BoxDecoration(
            border: Border.all(
                width: 0.5,
                color: invertedColors ? PinkTheme.buttonColor : Colors.black)),
        child: Column(children: children),
      );

  Widget forwardingPalettes() => SizedBox(
        height: ConsoleButton.height,
        width: consoleWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          textDirection: TextDirection.ltr,
          children: forwardingPalette!
              .map((palette) => Flexible(
                  child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border.all(width: 0.5),
                      ),
                      child: Row(
                          textDirection: TextDirection.ltr,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                                width: ConsoleButton.height,
                                height: ConsoleButton.height,
                                child: palette.image),
                            Expanded(
                                child: Container(
                                    padding: const EdgeInsets.all(2.0),
                                    color: PinkTheme
                                        .nodeColors[palette.node.colorCode],
                                    child: Text(palette.node.name,
                                        overflow: TextOverflow.clip)))
                          ]))))
              .toList(),
        ),
      );

  Widget topConsoleInputs() => Row(
      textDirection: TextDirection.ltr,
      children: topInputs
              ?.map((input) => input.animated(bb))
              .toList(growable: false) ??
          []);

  Widget bottomConsoleInputs() => Row(
      textDirection: TextDirection.ltr,
      children:
          inputs?.map((input) => input.animated(bb)).toList(growable: false) ??
              []);

  Widget consoleMedias() => ListView.builder(
      itemCount: (medias?.length ?? 0 / 4.0).ceil(),
      itemBuilder: ((context, index) {
        Widget f(int i) {
          if ((medias?.length ?? 0) > i) {
            return medias?[i].metadata.isVideo == true
                ? SizedBox(
                    height: (consoleWidth - 2) / 5,
                    width: (consoleWidth - 2) / 5,
                    child: Down4VideoPlayer(
                      vid: medias![i].file!,
                    ),
                  )
                : GestureDetector(
                    onTap: () => selectMedia?.call(medias![i]),
                    child: SizedBox(
                      height: (consoleWidth - 2) / 5,
                      width: (consoleWidth - 2) / 5,
                      child: Image.memory(
                        medias![i].data,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
          } else {
            return const SizedBox.shrink();
          }
        }

        return Row(
          children: [
            f((index * 5)),
            f((index * 5) + 1),
            f((index * 5) + 2),
            f((index * 5) + 3),
            f((index * 5) + 4)
          ],
        );
      }));

  Widget consoleCamera() => Transform.scale(
        alignment: Alignment.center,
        scaleY: aspectRatio,
        child: AspectRatio(
          aspectRatio: aspectRatio!,
          child: CameraPreview(cameraController!),
        ),
      );

  Widget consoleImagePreview({bool? toMirror = false}) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(toMirror == true ? math.pi : 0),
      child: Image.file(
        io.File(imagePreviewPath!),
        fit: BoxFit.cover,
      ));

  Widget consoleVideoPreview({bool? toMirror = false}) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(toMirror == true ? math.pi : 0),
        child: Transform.scale(
          scaleY: aspectRatio,
          child: VideoPlayer(videoPlayerController!),
        ),
      );

  Widget bbContainer({required Widget child}) => Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: child);

  Widget consoleScanner() => Container(
        width: consoleWidth - 1,
        height: consoleWidth - 1,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black,
            width: 0.5,
          ),
          color: PinkTheme.buttonColor,
        ),
        child: MobileScanner(
          controller: scanController,
          onDetect: scanCallBack!,
          allowDuplicates: false,
        ),
      );

  Widget bottomConsoleButtons() => Row(
        textDirection: TextDirection.ltr,
        children: invertedColors
            ? bottomButtons
                .map((button) => button.invertedColors())
                .toList(growable: false)
            : bottomButtons,
      );

  Widget topConsoleButtons() => Row(
        textDirection: TextDirection.ltr,
        children: invertedColors
            ? (topButtons ?? [])
                .map((button) => button.invertedColors())
                .toList(growable: false)
            : (topButtons ?? []),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: Sizes.h * 0.023,
        right: Sizes.h * 0.023,
        bottom: Sizes.h * 0.021,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          width: 0.5,
          color: Colors.black,
        ), // Color.fromRGBO(0, 0, 0, 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          forwardingPalette != null
              ? forwardingPalettes()
              : const SizedBox.shrink(),
          topConsoleInputs(),
          bottomConsoleInputs(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: consoleWidth,
            height: images ?? false
                ? mediasHeight
                : bb
                    ? consoleWidth
                    : 0,
            child: bbContainer(
              child: images == true
                  ? consoleMedias()
                  : cameraController != null
                      ? consoleCamera()
                      : imagePreviewPath != null
                          ? consoleImagePreview(toMirror: toMirror)
                          : videoPlayerController != null
                              ? consoleVideoPreview(toMirror: toMirror)
                              : scanController != null
                                  ? consoleScanner()
                                  : const SizedBox.shrink(),
            ),
          ),
          topConsoleButtons(),
          bottomConsoleButtons(),
        ],
      ),
    );
  }
}

// class Console extends StatefulWidget {
//   final List<ConsoleButton>? topButtons;
//   final List<ConsoleButton> bottomButtons;
//   final CameraController? cameraController;
//   final double? aspectRatio;
//   final bool? toMirror, images;
//   final List<Down4Media>? medias;
//   final void Function(Down4Media)? selectMedia;
//   final String? imagePreviewPath;
//   final VideoPlayerController? videoPlayerController;
//   final List<ConsoleInput>? inputs, topInputs;
//   final MobileScannerController? scanController;
//   final dynamic Function(Barcode, MobileScannerArguments?)? scanCallBack;
//   final List<Palette>? forwardingPalette;
//
//   List<Widget> get extraTopButtons {
//     final consoleHorizontalGap = Sizes.h * 0.023;
//     final consoleVerticalGap = Sizes.h * 0.021;
//     final buttonWidth = ((Sizes.w - (consoleHorizontalGap * 2.0)) /
//             (bottomButtons.length.toDouble())) +
//         1.0; // 1.0 for borders
//     List<Widget> extras = [];
//     int i = 0;
//     for (final b in topButtons ?? <ConsoleButton>[]) {
//       if (b.showExtra) {
//         extras.add(Positioned(
//           bottom: consoleVerticalGap + (ConsoleButton.height * 2),
//           left: consoleHorizontalGap + (buttonWidth * i),
//           child: Container(
//             height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
//             width: buttonWidth,
//             decoration: BoxDecoration(border: Border.all(width: 0.5)),
//             child: Column(children: b.extraButtons!),
//           ),
//         ));
//       } else {
//         extras.add(const SizedBox.shrink());
//       }
//       i++;
//     }
//     return extras;
//   }
//
//   List<Widget> get extraBottomButtons {
//     final horizontalGap = Sizes.h * 0.023;
//     final verticalGap = Sizes.h * 0.021;
//     final nBottomButton = bottomButtons.length;
//     final buttonWidth = (Sizes.w - (2 * horizontalGap)) / nBottomButton;
//     List<Widget> extras = [];
//     int i = 0;
//     for (final b in bottomButtons) {
//       final nExtra = b.extraButtons?.length ?? 0;
//       if (b.showExtra && nExtra > 0) {
//         extras.add(Positioned(
//             bottom: verticalGap + ConsoleButton.height + b.bottomEpsilon,
//             left: horizontalGap + (buttonWidth * i) + b.leftEpsilon,
//             child: Container(
//               height: (nExtra * ConsoleButton.height) + b.heightEpsilon,
//               width: buttonWidth + b.widthEpsilon,
//               decoration: BoxDecoration(border: Border.all(width: 0.5)),
//               child: Column(children: b.extraButtons!),
//             )));
//       } else {
//         extras.add(const SizedBox.shrink());
//       }
//       i++;
//     }
//     return extras;
//   }
//
//   double get consoleWidth => Sizes.w - (Sizes.h * 0.023 * 2);
//
//   bool get b =>
//       images == true ||
//       cameraController != null ||
//       imagePreviewPath != null ||
//       videoPlayerController != null ||
//       scanController != null;
//
//   const Console({
//     required this.bottomButtons,
//     this.forwardingPalette,
//     this.selectMedia,
//     this.images,
//     this.medias,
//     this.imagePreviewPath,
//     this.videoPlayerController,
//     this.toMirror,
//     this.aspectRatio,
//     this.cameraController,
//     this.inputs,
//     this.topInputs,
//     this.topButtons,
//     this.scanCallBack,
//     this.scanController,
//     Key? key,
//   }) : super(key: key);
//
//   @override
//   State<Console> createState() => _ConsoleState();
// }
//
// class _ConsoleState extends State<Console> {
//   int nImageRows = (b.images.keys.length / 5).ceil();
//   late double rowHeight = (widget.consoleWidth / 5);
//   late double initialHeight = rowHeight;
//   late double currentHeight = initialHeight;
//   late double maxHeight = rowHeight * 1; //((nImageRows < 7) ? nImageRows : 7);
//   late double minimumHeight = nImageRows == 0 ? 0 : rowHeight;
//   bool onResize = false;
//   ScrollController scrollController = ScrollController();
//
//   Widget mainContainer({required List<Widget> children}) => Container(
//         margin: EdgeInsets.only(
//             left: Sizes.h * 0.023,
//             right: Sizes.h * 0.023,
//             bottom: Sizes.h * 0.021),
//         decoration:
//             BoxDecoration(border: Border.all(width: 0.5, color: Colors.black)),
//         child: Column(children: children),
//       );
//
//   Widget forwardingPalettes() => SizedBox(
//         height: ConsoleButton.height,
//         width: widget.consoleWidth,
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           textDirection: TextDirection.ltr,
//           children: widget.forwardingPalette!
//               .map((palette) => Flexible(
//                   child: DecoratedBox(
//                       position: DecorationPosition.foreground,
//                       decoration: BoxDecoration(
//                         border: Border.all(width: 0.5),
//                       ),
//                       child: Row(
//                           textDirection: TextDirection.ltr,
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             SizedBox(
//                                 width: ConsoleButton.height,
//                                 height: ConsoleButton.height,
//                                 child: palette.image),
//                             Expanded(
//                                 child: Container(
//                                     padding: const EdgeInsets.all(2.0),
//                                     color: PinkTheme
//                                         .nodeColors[palette.node.colorCode],
//                                     child: Text(palette.node.name,
//                                         overflow: TextOverflow.clip)))
//                           ]))))
//               .toList(),
//         ),
//       );
//
//   Widget topConsoleInputs() => Row(
//       textDirection: TextDirection.ltr,
//       children: widget.topInputs
//               ?.map((input) => input.animated(widget.b))
//               .toList(growable: false) ??
//           []);
//
//   Widget bottomConsoleInputs() => Row(
//       textDirection: TextDirection.ltr,
//       children: widget.inputs
//               ?.map((input) => input.animated(widget.b))
//               .toList(growable: false) ??
//           []);
//
//   Widget consoleMedias() => ListView.builder(
//       controller: scrollController,
//       itemCount: (widget.medias?.length ?? 0 / 4.0).ceil(),
//       itemBuilder: ((context, index) {
//         Widget f(int i) {
//           if ((widget.medias?.length ?? 0) > i) {
//             return widget.medias?[i].metadata.isVideo == true
//                 ? SizedBox(
//                     height: (widget.consoleWidth - 2) / 5,
//                     width: (widget.consoleWidth - 2) / 5,
//                     child: Down4VideoPlayer(
//                       vid: widget.medias![i].file!,
//                     ),
//                   )
//                 : GestureDetector(
//                     onTap: () => widget.selectMedia?.call(widget.medias![i]),
//                     child: SizedBox(
//                       height: (widget.consoleWidth - 2) / 5,
//                       width: (widget.consoleWidth - 2) / 5,
//                       child: Image.memory(
//                         widget.medias![i].data,
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   );
//           } else {
//             return const SizedBox.shrink();
//           }
//         }
//
//         return Row(
//           children: [
//             f((index * 5)),
//             f((index * 5) + 1),
//             f((index * 5) + 2),
//             f((index * 5) + 3),
//             f((index * 5) + 4)
//           ],
//         );
//       }));
//
//   Widget consoleCamera() => Transform.scale(
//         alignment: Alignment.center,
//         scaleY: widget.aspectRatio,
//         child: AspectRatio(
//           aspectRatio: widget.aspectRatio!,
//           child: CameraPreview(widget.cameraController!),
//         ),
//       );
//
//   Widget consoleImagePreview({bool? toMirror = false}) => Transform(
//       alignment: Alignment.center,
//       transform: Matrix4.rotationY(toMirror == true ? math.pi : 0),
//       child: Image.file(
//         io.File(widget.imagePreviewPath!),
//         fit: BoxFit.cover,
//       ));
//
//   Widget consoleVideoPreview({bool? toMirror = false}) => Transform(
//         alignment: Alignment.center,
//         transform: Matrix4.rotationY(toMirror == true ? math.pi : 0),
//         child: Transform.scale(
//           scaleY: widget.aspectRatio,
//           child: VideoPlayer(widget.videoPlayerController!),
//         ),
//       );
//
//   Widget bContainer({required Widget child}) => Container(
//       width: widget.consoleWidth,
//       height: widget.consoleWidth,
//       clipBehavior: Clip.hardEdge,
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.black, width: 0.5),
//       ),
//       child: child);
//
//   Widget biggerContainer({required Widget child}) => Container(
//       // width: consoleWidth,
//       // height: consoleWidth * golden,
//       // clipBehavior: Clip.hardEdge,
//       // decoration: BoxDecoration(
//       //   border: Border.all(color: Colors.black, width: 0.5),
//       // ),
//       child: child);
//
//   Widget scrollableContainer({required Widget child}) => Container(
//         width: widget.consoleWidth,
//         decoration: BoxDecoration(border: Border.all(width: 0.5)),
//         // duration: Duration(milliseconds: onResize ? 1 : 200),
//         height: currentHeight,
//         child: Stack(
//           children: [
//             child,
//             GestureDetector(
//               onVerticalDragUpdate: (DragUpdateDetails details) {
//                 print("hello");
//                 final primaryDelta = details.primaryDelta ?? 0;
//                 final potentialHeight = currentHeight - primaryDelta;
//                 if (potentialHeight < maxHeight &&
//                     potentialHeight > minimumHeight) {
//                   setState(() {
//                     currentHeight = potentialHeight;
//                     onResize = true;
//                   });
//                 } else {
//                   print("Trying to scroll instead!");
//                   var currentPosition = scrollController.offset;
//                   scrollController.position.animateTo(
//                     currentPosition - (primaryDelta * 10),
//                     duration: const Duration(milliseconds: 50),
//                     curve: Curves.linear,
//                   );
//                 }
//               },
//             )
//           ],
//         ),
//       );
//
//   Widget consoleScanner() => Container(
//         width: widget.consoleWidth - 1,
//         height: widget.consoleWidth - 1,
//         decoration: BoxDecoration(
//           border: Border.all(
//             color: Colors.black,
//             width: 0.5,
//           ),
//           color: PinkTheme.buttonColor,
//         ),
//         child: MobileScanner(
//           controller: widget.scanController,
//           onDetect: widget.scanCallBack!,
//           allowDuplicates: false,
//         ),
//       );
//
//   Widget bottomConsoleButtons() => Row(
//         textDirection: TextDirection.ltr,
//         children: widget.bottomButtons,
//       );
//
//   Widget topConsoleButtons() => Row(
//         textDirection: TextDirection.ltr,
//         children: widget.topButtons ?? [],
//       );
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       // height: 300,
//       // constraints: const BoxConstraints(maxHeight: 300),
//       margin: EdgeInsets.only(
//         left: Sizes.h * 0.023,
//         right: Sizes.h * 0.023,
//         bottom: Sizes.h * 0.021,
//       ),
//       decoration: BoxDecoration(
//         border: Border.all(
//           width: 0.5,
//           color: Colors.black,
//         ), // Color.fromRGBO(0, 0, 0, 0.05)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           widget.forwardingPalette != null
//               ? forwardingPalettes()
//               : const SizedBox.shrink(),
//           topConsoleInputs(),
//           bottomConsoleInputs(),
//
//           widget.images == true
//               ? scrollableContainer(child: consoleMedias())
//               : const SizedBox.shrink(),
//
//           // AnimatedContainer(
//           //   duration: const Duration(milliseconds: 200),
//           //   width: consoleWidth,
//           //   height: b ? consoleWidth : 0,
//           //   child: bContainer(
//           //     child: images == true
//           //         ? consoleMedias()
//           //         : cameraController != null
//           //             ? consoleCamera()
//           //             : imagePreviewPath != null
//           //                 ? consoleImagePreview(toMirror: toMirror)
//           //                 : videoPlayerController != null
//           //                     ? consoleVideoPreview(toMirror: toMirror)
//           //                     : scanController != null
//           //                         ? consoleScanner()
//           //                         : const SizedBox.shrink(),
//           //   ),
//           // ),
//           topConsoleButtons(),
//           bottomConsoleButtons(),
//         ],
//       ),
//     );
//   }
// }
