import 'dart:io' as io;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';
import '../_down4_dart_utils.dart' show golden;

import 'palette.dart';
import '_down4_flutter_utils.dart';

class ConsoleButton extends StatelessWidget {
  final String name;
  final List<ConsoleButton>? extraButtons;
  final bool isSpecial,
      isMode,
      shouldBeDownButIsnt,
      isActivated,
      showExtra,
      greyedOut;
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
    this.greyedOut = false,
    this.showExtra = false,
    this.shouldBeDownButIsnt = false,
    this.isMode = false,
    this.isSpecial = false,
    this.isActivated = true,
    this.onLongPress,
    this.onLongPressUp,
    Key? key,
  }) : super(key: key);

  ConsoleButton invertedColors({required Key key}) => ConsoleButton(
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        invertColors: true,
        leftEpsilon: leftEpsilon,
        bottomEpsilon: bottomEpsilon,
        greyedOut: greyedOut,
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

  ConsoleButton withKey({required Key key}) => ConsoleButton(
        name: name,
        onPress: onPress,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressUp,
        invertColors: false,
        greyedOut: greyedOut,
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

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: Console.buttonHeight,
        decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color:
                invertColors ? null : Console.contourColor, // PinkTheme.black,
            border: Border.all(
              color: Console.contourColor,
              width: Console.contourWidth,
            )),
        child: TouchableOpacity(
          shouldBeDownButIsnt: shouldBeDownButIsnt,
          onPress: isActivated ? onPress : () {},
          onLongPress: isActivated ? onLongPress : () {},
          onLongPressUp: isActivated ? onLongPressUp : () {},
          child: Container(
            color: invertColors
                ? Colors.black12
                : greyedOut
                    ? PinkTheme.inactivatedButtonColor
                    : PinkTheme.buttonColor,
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
  final TextInputType type;
  final bool activated;
  final String placeHolder;
  final String value;
  final String prefix, suffix;
  final int maxLines;
  final void Function(String)? inputCallBack;
  final TextEditingController tec;
  final bool show;
  const ConsoleInput({
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

  ConsoleInput animated({required bool show}) {
    return ConsoleInput(
      type: type,
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
      cursorColor: PinkTheme.black,
      key: GlobalKey(),
      maxLines: maxLines,
      minLines: 1,
      keyboardType: type,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: Sizes.w * 0.008),
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
  }

  Widget get unactivatedField {
    return Center(child: Text(placeHolder));
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: Console.animationDuration,
        decoration: BoxDecoration(
            color: activated ? Colors.white : Colors.grey,
            border: Border.all(
                width: Console.contourWidth, color: Console.contourColor)),
        constraints: BoxConstraints(
            // this is higher than maxfields in the textInput allows
            maxHeight: show ? 8 * Console.buttonHeight : 0,
            minHeight: show ? Console.buttonHeight : 0),
        child: activated ? activatedField : unactivatedField,
      ),
    );
  }
}

class ConsoleMedias {
  final Iterable<MessageMedia> medias;
  final void Function(MessageMedia) onSelectMedia;
  final int nMedias;
  const ConsoleMedias({
    required this.medias,
    required this.onSelectMedia,
    required this.nMedias,
  });
}

class ImagePreview {
  final String path;
  final double imageAspectRatio;
  final bool isReversed;
  const ImagePreview({
    required this.path,
    required this.isReversed,
    required this.imageAspectRatio,
  });
}

class VideoPreview {
  final VideoPlayer videoPlayer;
  final double videoAspectRatio;
  final bool isReversed;
  VideoPreview({
    required this.videoPlayer,
    required this.videoAspectRatio,
    required this.isReversed,
  });
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? _topButtons;
  final List<ConsoleButton> _bottomButtons;
  final List<ConsoleInput>? _bottomInputs, _topInputs;
  final bool animatedInputs;
  final List<Palette>? forwardingPalette;
  final bool invertedColors;
  final ConsoleMedias? mediasInfo;
  final ImagePreview? imageForPreview;
  final VideoPreview? videoForPreview;
  final CameraController? cameraController;
  final MobileScanner? scanner;

  static GlobalKey get widgetCaptureKey => GlobalKey();

  int get nMediaRow =>
      mediasInfo == null ? 0 : (mediasInfo!.nMedias / nMediaPerRow).ceil();
  int get nMediaPerRow => 5;
  int get maximumMediaRows => 3;
  double get rowHeight => (consoleWidth / nMediaPerRow); // squared element
  double get mediasHeight => nMediaRow == 0
      ? rowHeight
      : nMediaRow <= maximumMediaRows
          ? rowHeight * nMediaRow
          : rowHeight * maximumMediaRows;

  List<Widget> get extraTopButtons {
    // final consoleHorizontalGap = Sizes.h * 0.023;
    // final consoleVerticalGap = Sizes.h * 0.021;
    // final buttonWidth = ((Sizes.w - (consoleHorizontalGap * 2.0)) /
    // (bottomButtons.length.toDouble())) +
    // 0 for borders
    List<Widget> extras = [];
    for (final b in topConsoleButtons) {
      if (b.showExtra) {
        final key = b.key as GlobalKey;
        final renderBox = key.currentContext!.findRenderObject() as RenderBox;
        final semantics = renderBox.semanticBounds;
        final buttonWidth = semantics.width;
        final leftBottom = semantics.bottomLeft;

        extras.add(Positioned(
          bottom: leftBottom.dy - 0.5,
          left: leftBottom.dx - 0.5,
          child: Container(
            width: buttonWidth + 0.5,
            decoration: BoxDecoration(border: Border.all(width: 0.5)),
            child: Column(children: b.extraButtons!),
          ),
        ));
      } else {
        extras.add(const SizedBox.shrink());
      }
    }
    return extras;
  }

  List<Widget> get extraBottomButtons {
    return bottomConsoleButtons.map((b) {
      if (b.showExtra) {
        final key = b.key as GlobalKey?;
        final context = key!.currentContext;
        final renderBox = context!.findRenderObject() as RenderBox;
        final Offset position = renderBox.localToGlobal(Offset.zero);
        final semantics = renderBox.semanticBounds;
        final buttonWidth = semantics.width;
        final buttonHeight = semantics.height;

        print("""
        button height: $buttonHeight
        position:      $position
        Sizes.w:       ${Sizes.w}
        Sizes.h:       ${Sizes.h}
        """);

        return Positioned(
          left: position.dx - 0.5,
          top: position.dy -
              Sizes.viewPaddingHeight -
              0.5 -
              (buttonHeight * (b.extraButtons!.length)),
          child: Container(
            width: buttonWidth + 1.0,
            height: buttonHeight * b.extraButtons!.length + 1.0,
            decoration: BoxDecoration(border: Border.all(width: 0.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: b.extraButtons!,
            ),
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    }).toList();
  }

  static double get buttonHeight => Sizes.h * 0.045;

  double get consoleGap => Sizes.w * 0.022;
  static double get contourWidth => 0.6;
  static Color get contourColor => Colors.black;
  double get consoleWidth => Sizes.w - (2.0 * consoleGap);
  double get trueWidth => consoleWidth - (4 * contourWidth);
  double get bbWidth => consoleWidth - (2 * contourWidth);

  // contour width is actually applied 2 times horizontally, (4 times)
  // (it is also applied 2 times vertically)
  // Size get bbSize => Size.square(consoleWidth - (4 * contourWidth));

  static Duration get animationDuration =>
      Duration(milliseconds: (100 * golden).toInt());

  bool get hasGadgets =>
      mediasInfo != null ||
      cameraController != null ||
      imageForPreview != null ||
      scanner != null ||
      videoForPreview != null;

  const Console({
    required List<ConsoleButton> bottomButtons,
    this.invertedColors = false,
    this.forwardingPalette,
    this.cameraController,
    this.imageForPreview,
    this.videoForPreview,
    this.mediasInfo,
    this.scanner,
    // this.selectMedia,
    // this.images,
    this.animatedInputs = true,
    // this.medias,
    // this.imagePreviewPath,
    // this.videoPlayerController,
    // this.toMirror,
    // this.aspectRatio,
    // CameraController? cameraController,
    List<ConsoleInput>? bottomInputs,
    List<ConsoleInput>? topInputs,
    List<ConsoleButton>? topButtons,
    // this.scanCallBack,
    // this.scanController,
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
          .toList(growable: false) ??
      [];

  List<ConsoleInput> get bottomConsoleInputs =>
      _bottomInputs
          ?.map((input) => input.animated(show: !hasGadgets))
          .toList(growable: false) ??
      [];

  int get mediaPerRow => 5;

  double get mediaCelSize => trueWidth / mediaPerRow;

  Widget? consoleMedias() {
    final mi = mediasInfo;
    if (mi == null) return null;
    return ListView.builder(
        itemCount: nMediaRow,
        itemBuilder: ((context, index) {
          Widget f(int i) {
            if (i < mi.nMedias) {
              return GestureDetector(
                onTap: () => mi.onSelectMedia(mi.medias.elementAt(i)),
                child: Down4ImageViewer(
                  // backgroundColor: PinkTheme.qrColor,
                  media: mi.medias.elementAt(i),
                  displaySize: Size.square(mediaCelSize),
                  forceSquareAnyways: true,
                ),
              );

              // final theMedia = mi.medias.elementAt(i);
              // return theMedia.metadata.isVideo == true
              // // return medias?[i].metadata.isVideo == true
              //     ? SizedBox(
              //     height: (consoleWidth - 2) / 5,
              //     width: (consoleWidth - 2) / 5,
              //     child: Down4VideoPlayer(media: theMedia)
              //   // child: Down4VideoPlayer(media: medias![i]),
              // )
              //     : GestureDetector(
              //   onTap: () => mi.onSelect.call(theMedia),
              //   // onTap: () => selectMedia?.call(medias![i]),
              //   child: SizedBox.fromSize(
              //     size: Size.square(mediaCelSize),
              //     child: theMedia.file != null
              //         ? Down4ImageViewer(
              //         media: theMedia,
              //         forceSquareAnyways: true,
              //         displaySize: Size.square(mediaCelSize))
              //         : const SizedBox.shrink(),
              //     // child: medias![i].file != null
              //     //     ? Image.file(medias![i].file!, fit: BoxFit.cover)
              //     //     : const SizedBox.shrink(),
              //   ),
              // );
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
  }

  Widget mainContainer({required List<Widget> children}) => Container(
        margin: EdgeInsets.only(
            left: consoleGap, right: consoleGap, bottom: consoleGap),
        decoration: BoxDecoration(
            border: Border.all(
                width: contourWidth,
                color: invertedColors ? PinkTheme.buttonColor : contourColor)),
        child: Column(children: children),
      );

  Widget? forwardingPalettes() {
    if (forwardingPalette == null) return null;
    return SizedBox(
      height: Console.buttonHeight,
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
                              width: Console.buttonHeight,
                              height: Console.buttonHeight,
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
  }

  Widget? consoleCamera() {
    final camCtrl = cameraController;
    if (camCtrl == null) return null;
    // return CameraPreview(camCtrl);
    return Transform.scale(
      scaleY: camCtrl.value.aspectRatio,
      child: CameraPreview(camCtrl),
    );

    // var scale = camCtrl.value.aspectRatio * 1.0;
    // scale = scale > 1 ? scale : 1 / scale;
    // return Down4Display(
    //   displayType: DisplayType.camera,
    //   isReversed: false,
    //   renderRect: bbSize,
    //   captureAspectRatio: camCtrl.value.aspectRatio,
    //   child: CameraPreview(camCtrl),
    // );
  }

  Widget? videoPreview() {
    final vfp = videoForPreview;
    if (vfp == null) return null;
    return Down4VideoTransform(
      displaySize: Size.square(trueWidth),
      videoAspectRatio: vfp.videoAspectRatio,
      video: vfp.videoPlayer,
      isReversed: vfp.isReversed,
      isSquared: true,
    );
  }

  Widget? imagePreview() {
    final ifp = imageForPreview;
    if (ifp == null) return null;
    final theImage = Image.file(
      io.File(ifp.path),
      cacheHeight: trueWidth.toInt(),
      cacheWidth: trueWidth.toInt(),
    );
    return Down4ImageTransform(
      image: theImage,
      imageAspectRatio: ifp.imageAspectRatio,
      displaySize: Size.square(trueWidth),
      isSquared: true,
      isReversed: ifp.isReversed,
    );
  }

  double get bbHeight {
    if (imageForPreview != null ||
        videoForPreview != null ||
        cameraController != null ||
        scanner != null) {
      return bbWidth;
    } else if (mediasInfo != null) {
      return mediasHeight;
    } else {
      return 0;
    }
  }

  Widget bbContainer({required Widget child}) => AnimatedContainer(
        // clipBehavior: Clip.hardEdge,
        duration: animationDuration,
        height: bbHeight,
        width: bbWidth,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: contourColor, width: contourWidth),
        ),
        child: child,
      );

  Widget? consoleScanner() => scanner;

  List<ConsoleButton> get bottomConsoleButtons => invertedColors
      ? _bottomButtons
          .asMap()
          .map((key, value) => MapEntry(
              key,
              value.invertedColors(
                  key: ButtonKeys.instance.bottomButtonKeys[key])))
          .values
          .toList(growable: false)
      : _bottomButtons
          .asMap()
          .map((key, value) => MapEntry(key,
              value.withKey(key: ButtonKeys.instance.bottomButtonKeys[key])))
          .values
          .toList(growable: false);

  List<ConsoleButton> get topConsoleButtons => invertedColors
      ? (_topButtons ?? [])
          .asMap()
          .map((key, value) => MapEntry(
              key,
              value.invertedColors(
                  key: ButtonKeys.instance.topButtonKeys[key])))
          .values
          .toList(growable: false)
      : (_topButtons ?? [])
          .asMap()
          .map((key, value) => MapEntry(
              key, value.withKey(key: ButtonKeys.instance.topButtonKeys[key])))
          .values
          .toList(growable: false);

  Widget get anyGadgets {
    return bbContainer(
        child: consoleMedias() ??
            consoleScanner() ??
            consoleCamera() ??
            imagePreview() ??
            videoPreview() ??
            forwardingPalettes() ??
            const SizedBox.shrink());
  }

  Widget get staticInputs => Column(
        children: [
          Row(children: _topInputs ?? []),
          Row(children: _bottomInputs ?? [])
        ],
      );

  Widget get inputs => Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        // mainAxisAlignment: MainAxisAlignment.end,
        // crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: topConsoleInputs),
          Row(children: bottomConsoleInputs),
        ],
      );

  Widget get buttons => Column(
        // crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(textDirection: TextDirection.ltr, children: topConsoleButtons),
          Row(textDirection: TextDirection.ltr, children: bottomConsoleButtons),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: consoleGap,
        right: consoleGap,
        bottom: consoleGap,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          width: contourWidth,
          color: contourColor,
        ), // Color.fromRGBO(0, 0, 0, 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        // crossAxisAlignment: CrossAxisAlignment.end,
        // crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // inputs and gadgets are programmed so only inputs or a gadget can
          // be viewed at once. They are animated in a way that opening a gadget
          // (like camera for example) will squeeze the input and vice-versa
          // current gadets are camera, media preview after taking picture or
          // video from said camera, and the saved medias

          // Row(children: topConsoleInputs),
          // Row(children: bottomConsoleInputs),
          animatedInputs ? inputs : staticInputs,
          // inputs,
          anyGadgets,
          // forwardingPalette != null
          //     ? forwardingPalettes()
          //     : const SizedBox.shrink(),
          // !animatedInputs ? Row(children: topInputs ?? []) : topConsoleInputs(),
          // !animatedInputs ? Row(children: bottomInputs ?? []) : bottomConsoleInputs(),
          // AnimatedContainer(
          //   duration: const Duration(milliseconds: 200),
          //   // width: consoleWidth,
          //   // height: images ?? false
          //   //     ? mediasHeight
          //   //     : bb
          //   //         ? consoleWidth
          //   //         : 0,
          //   child: bbContainer(
          //     child: mediaPreview() ?? consoleScanner() ??
          //
          //     images == true
          //         ? consoleMedias()
          //         : imagePreviewPath != null
          //             ? consoleImagePreview()
          //             : videoPlayerController != null
          //                 ? consoleVideoPreview()
          //                 : _cameraController != null
          //                     ? consoleCamera()
          //                     : scanController != null
          //                         ? consoleScanner()
          //                         : const SizedBox.shrink(),
          //   ),
          // ),
          buttons,
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
