import 'dart:io' as io;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:down4/src/render_objects/chat_message.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data_objects.dart';
import '../globals.dart';
import '../themes.dart';
import '../_down4_dart_utils.dart' show golden;

import 'palette.dart';
import '_down4_flutter_utils.dart';

class ConsoleButton extends StatelessWidget {
  // RenderBox get renderBox => context.findRenderObject() as RenderBox;
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

  ConsoleButton({
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

  ConsoleButton invertedColors() => ConsoleButton(
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
        // key: key,
      );

  // ConsoleButton withKey({required Key key}) => ConsoleButton(
  //       name: name,
  //       onPress: onPress,
  //       onLongPress: onLongPress,
  //       onLongPressUp: onLongPressUp,
  //       invertColors: false,
  //       greyedOut: greyedOut,
  //       leftEpsilon: leftEpsilon,
  //       bottomEpsilon: bottomEpsilon,
  //       widthEpsilon: widthEpsilon,
  //       heightEpsilon: heightEpsilon,
  //       extraButtons: extraButtons,
  //       showExtra: showExtra,
  //       shouldBeDownButIsnt: shouldBeDownButIsnt,
  //       isMode: isMode,
  //       isSpecial: isSpecial,
  //       isActivated: isActivated,
  //       key: key,
  //     );

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
              color: invertColors
                  ? Colors.black12
                  : greyedOut
                      ? PinkTheme.inactivatedButtonColor
                      : PinkTheme.buttonColor,
              border: Border.all(
                color: Console.contourColor,
                width: Console.contourWidth,
              )),
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
        contentPadding: EdgeInsets.symmetric(vertical: g.sizes.w * 0.012),
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
      child: AnimatedSize(
        duration: Console.animationDuration,
        child: Container(
          decoration: BoxDecoration(
              color: activated ? Colors.white : Colors.grey,
              border: Border.all(
                  width: show ? Console.contourWidth : 0,
                  color: Console.contourColor)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                // this is higher than maxfields in the textInput allows
                maxHeight: show ? 8 * Console.buttonHeight : 0,
                minHeight: show ? Console.buttonHeight : 0),
            child: activated ? activatedField : unactivatedField,
          ),
        ),
      ),
    );

    // return Expanded(
    //   child: AnimatedContainer(
    //     duration: Console.animationDuration,
    //     decoration: BoxDecoration(
    //         color: activated ? Colors.white : Colors.grey,
    //         border: Border.all(
    //             width: Console.contourWidth, color: Console.contourColor)),
    //     constraints: BoxConstraints(
    //         // this is higher than maxfields in the textInput allows
    //         maxHeight: show ? 8 * Console.buttonHeight : 0,
    //         minHeight: show ? Console.buttonHeight : 0),
    //     child: activated ? activatedField : unactivatedField,
    //   ),
    // );
  }
}

class ConsoleMedias {
  final Iterable<MessageMedia> medias;
  final void Function(MessageMedia) onSelectMedia;
  final int nMedias;
  final bool show;
  const ConsoleMedias({
    required this.show,
    required this.medias,
    required this.onSelectMedia,
    required this.nMedias,
  });
}

class ConsoleMedias2 {
  final void Function(MessageMedia) onSelectMedia;
  final bool showImages;
  ConsoleMedias2({required this.showImages, required this.onSelectMedia});
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

  final List<dynamic>? forwardingObjects;
  final List<Palette>? forwardingPalette;
  // final List<Message>? forwardingMessage;
  final bool invertedColors, initializationConsole;
  // final bool? showImage;
  // final ConsoleMedias? mediasInfo;
  final ConsoleMedias2? consoleMedias2;
  final ImagePreview? imageForPreview;
  final VideoPreview? videoForPreview;
  final CameraController? cameraController;
  final MobileScanner? scanner;

  static GlobalKey get widgetCaptureKey => GlobalKey();

  // int get nMediaRow =>
  //     mediasInfo == null ? 0 : (mediasInfo!.nMedias / nMediaPerRow).ceil();
  int get nMediaPerRow => 5;
  int get maximumMediaRows => 3;
  double get rowHeight => (consoleWidth / nMediaPerRow); // squared element
  // double get mediasHeight => nMediaRow == 0
  //     ? rowHeight
  //     : nMediaRow <= maximumMediaRows
  //         ? rowHeight * nMediaRow
  //         : rowHeight * maximumMediaRows;

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
          bottom: leftBottom.dy - contourWidth,
          left: leftBottom.dx - contourWidth,
          child: Container(
            width: buttonWidth + contourWidth,
            decoration: BoxDecoration(
                border: Border.all(width: contourWidth, color: contourColor)),
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
        final key = b.key as GlobalKey;
        // final renderBox = key.currentContext?;
        final context = key.currentContext;
        final renderBox = context!.findRenderObject() as RenderBox;
        // final RenderBox renderBox = b.renderBox as RenderBox;
        final Offset position = renderBox.localToGlobal(Offset.zero);
        final semantics = renderBox.semanticBounds;
        final buttonWidth = semantics.width;
        final buttonHeight = semantics.height;

        print("""
        button height: $buttonHeight
        position:      $position
        Sizes.w:       ${g.sizes.w}
        Sizes.h:       ${g.sizes.h}
        """);

        return Positioned(
          left: position.dx - contourWidth,
          top: position.dy -
              g.sizes.viewPaddingHeight -
              contourWidth -
              (buttonHeight * (b.extraButtons!.length)),
          child: Container(
            width: buttonWidth + (2 * contourWidth),
            height: buttonHeight * b.extraButtons!.length + (2 * contourWidth),
            decoration: BoxDecoration(
                border: Border.all(width: contourWidth, color: contourColor),
                color: contourColor),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: b.extraButtons!),
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    }).toList();
  }

  static double get buttonHeight => g.sizes.h * 0.044;

  double get consoleGap => g.sizes.w * 0.022;
  static double get contourWidth => 0.9; //0.9;
  static Color get contourColor => Colors.black54;
  double get consoleWidth => g.sizes.w - (2.0 * consoleGap);
  double get trueWidth => consoleWidth - (4 * contourWidth);
  double get bbWidth => consoleWidth - (2 * contourWidth);

  // contour width is actually applied 2 times horizontally, (4 times)
  // (it is also applied 2 times vertically)

  static int nMedias(bool images) =>
      images ? g.self.images.length : g.self.videos.length;

  static Stream<MessageMedia> medias(bool images) async* {
    final ids = List<ID>.from(images ? g.self.images : g.self.videos);
    for (final mediaID in ids) {
      final media = await mediaID.getLocalMessageMedia();
      if (media != null) yield media;
    }
  }

  // static ConsoleMedias consoleMedias2({
  //   required bool? showImages,
  //   required void Function(MessageMedia) onSelectedMedia,
  // }) =>
  //     ConsoleMedias(
  //       show: showImages != null,
  //       medias: medias(showImages ?? true),
  //       onSelectMedia: onSelectedMedia,
  //       nMedias: nMedias(showImages ?? true),
  //     );

  static Duration get animationDuration =>
      Duration(milliseconds: (100 * golden).toInt());

  bool get hasGadgets =>
      imageForPreview != null ||
      videoForPreview != null ||
      cameraController != null ||
      scanner != null ||
      consoleMedias2 != null;

  const Console({
    required List<ConsoleButton> bottomButtons,
    this.invertedColors = false,
    this.forwardingPalette,
    // this.forwardingPalette2,
    this.forwardingObjects,
    // this.forwardingMessage,
    this.cameraController,
    this.imageForPreview,
    this.videoForPreview,
    this.initializationConsole = false,
    // this.mediasInfo,
    this.scanner,
    this.animatedInputs = true,
    this.consoleMedias2,
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
          .toList(growable: false) ??
      [];

  List<ConsoleInput> get bottomConsoleInputs =>
      _bottomInputs
          ?.map((input) => input.animated(show: !hasGadgets))
          .toList(growable: false) ??
      [];

  int get mediaPerRow => 5;

  double get mediaCelSize => trueWidth / mediaPerRow;

  Widget consoleMedias() {
    if (initializationConsole) return const SizedBox.shrink();
    // final mi = mediasInfo;
    // if (mi == null) return const SizedBox.shrink();
    final nMedia = nMedias(consoleMedias2?.showImages ?? true);
    final theoreticalRows = (nMedia / mediaPerRow).ceil();
    final trueRows = theoreticalRows > 0
        ? theoreticalRows < 4
            ? theoreticalRows
            : 3
        : 1;

    final showingImages = consoleMedias2?.showImages ?? true;
    return Container(
      decoration: BoxDecoration(
          color: Console.contourColor,
          border: Border.all(
            color: contourColor,
            width: consoleMedias2 != null ? contourWidth : 0,
          )),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: consoleMedias2 != null ? trueRows * mediaCelSize : 0,
          maxWidth: trueWidth,
        ),
        child: ListView.builder(
            itemCount: theoreticalRows,
            itemBuilder: ((context, index) {
              Widget f(int i) {
                return FutureBuilder(
                  future: medias(showingImages).elementAt(i),
                  builder: ((context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      return GestureDetector(
                        onTap: () => consoleMedias2?.onSelectMedia
                            .call(snapshot.requireData),
                        child: Down4ImageViewer(
                            media: snapshot.requireData,
                            displaySize: Size.square(mediaCelSize),
                            forceSquareAnyways: true),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                );
                // if (i < nMedia) {
                //   final theMedia = await medias(showingImages).elementAt(i);
                //   return GestureDetector(
                //     onTap: () => consoleMedias2?.onSelectMedia.call(theMedia),
                //     child: Down4ImageViewer(
                //       media: theMedia,
                //       displaySize: Size.square(mediaCelSize),
                //       forceSquareAnyways: true,
                //     ),
                //   );
                // } else {
                //   return const SizedBox.shrink();
                // }
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
            })),
      ),
    );
  }

  Widget forwardingPalettes() {
    if (forwardingObjects == null) return const SizedBox.shrink();

    Widget individualObject(Down4Object obj) {
      if (obj is Palette2) {
        return Flexible(
            child: Container(
                decoration: BoxDecoration(
                    border:
                        Border.all(color: contourColor, width: contourWidth)),
                child: Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          width: Console.buttonHeight,
                          height: Console.buttonHeight,
                          child: obj.image),
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.all(4.0),
                              color: PinkTheme.nodeColors[obj.node.colorCode],
                              child: Text(
                                obj.node.name,
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                              )))
                    ])));
      } else if (obj is ChatMessage) {
        return Flexible(
            child: Container(
                decoration: BoxDecoration(
                    color: obj.myMessage
                        ? PinkTheme.myBubblesColor
                        : PinkTheme.buttonColor,
                    border:
                        Border.all(color: contourColor, width: contourWidth)),
                child: Expanded(
                    child: Text(
                        (obj.message.text ?? "").isEmpty
                            ? "&attachment"
                            : obj.message.text!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis))));
      }

      return const SizedBox.shrink();
    }

    return
        // Container(
        //     decoration: BoxDecoration(
        //         color: null,
        //         border: Border.all(color: contourColor, width: contourWidth)),
        //     child:
        SizedBox(
            height: buttonHeight + (2 * contourWidth),
            width: trueWidth + (2 * contourWidth),
            child: Row(
                // crossAxisAlignment: CrossAxisAlignment.stretch,
                // crossAxisAlignment: CrossAxisAlignment.end,
                textDirection: TextDirection.ltr,
                children: forwardingObjects!
                    .map((e) => individualObject(e))
                    .toList()));

    // return Container(
    //   decoration: BoxDecoration(
    //       color: PinkTheme.black,
    //       border: Border.all(color: contourColor, width: contourWidth)),
    //   child: SizedBox(
    //     height: Console.buttonHeight,
    //     width: consoleWidth,
    //     child: Row(
    //       crossAxisAlignment: CrossAxisAlignment.stretch,
    //       textDirection: TextDirection.ltr,
    //       children: forwardingPalette!
    //           .map((palette) => Flexible(
    //               child: DecoratedBox(
    //                   position: DecorationPosition.foreground,
    //                   decoration: BoxDecoration(
    //                     border: Border.all(width: 0.5),
    //                   ),
    //                   child: Row(
    //                       textDirection: TextDirection.ltr,
    //                       crossAxisAlignment: CrossAxisAlignment.stretch,
    //                       children: [
    //                         SizedBox(
    //                             width: Console.buttonHeight,
    //                             height: Console.buttonHeight,
    //                             child: palette.image),
    //                         Expanded(
    //                             child: Container(
    //                                 padding: const EdgeInsets.all(2.0),
    //                                 color: PinkTheme
    //                                     .nodeColors[palette.node.colorCode],
    //                                 child: Text(palette.node.name,
    //                                     overflow: TextOverflow.clip)))
    //                       ]))))
    //           .toList(),
    //     ),
    //   ),
    // );

    // return ConstrainedBox(
    //     constraints: BoxConstraints(
    //         maxHeight: buttonHeight + (2 * contourWidth),
    //         maxWidth: trueWidth + (2 * contourWidth)),
    //     child: Row(
    //         mainAxisSize: MainAxisSize.max,
    //         crossAxisAlignment: CrossAxisAlignment.stretch,
    //         textDirection: TextDirection.ltr,
    //         // mainAxisSize: MainAxisSize.min,
    //         children:
    //             forwardingObjects!.map((e) => individualObject(e)).toList()));

    //       .map((object) => object is Palette2
    //           ? Flexible(
    //               child: DecoratedBox(
    //                   position: DecorationPosition.foreground,
    //                   decoration: BoxDecoration(
    //                     border: Border.all(width: 0.5),
    //                   ),
    //                   child: Row(
    //                       textDirection: TextDirection.ltr,
    //                       crossAxisAlignment: CrossAxisAlignment.stretch,
    //                       children: [
    //                         SizedBox(
    //                             width: Console.buttonHeight,
    //                             height: Console.buttonHeight,
    //                             child: object.image),
    //                         Expanded(
    //                             child: Container(
    //                                 padding: const EdgeInsets.all(2.0),
    //                                 color: PinkTheme
    //                                     .nodeColors[object.node.colorCode],
    //                                 child: Text(object.node.name,
    //                                     overflow: TextOverflow.clip)))
    //                       ])))
    //           : object is Message
    //               ? Flexible(
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
    //                                 width: Console.buttonHeight,
    //                                 height: Console.buttonHeight,
    //                                 child: object.image),
    //                             Expanded(
    //                                 child: Container(
    //                                     padding: const EdgeInsets.all(2.0),
    //                                     color: PinkTheme
    //                                         .nodeColors[object.node.colorCode],
    //                                     child: Text(object.node.name,
    //                                         overflow: TextOverflow.clip)))
    //                           ])))
    //               : const SizedBox.shrink())
    //       .toList(),
    // );
  }

  Widget consoleCamera() {
    final camCtrl = cameraController;
    if (camCtrl == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
          color: contourColor,
          border: Border.all(color: contourColor, width: contourWidth)),
      child: SizedBox(
          height: trueWidth,
          width: trueWidth,
          child: ClipRect(
              child: Transform.scale(
                  scaleY: camCtrl.value.aspectRatio,
                  child: CameraPreview(camCtrl)))),
    );

    // return Transform.scale(
    //   scale: 1.0,
    //   // scaleY: camCtrl.value.aspectRatio,
    //   child: Center(child: CameraPreview(camCtrl)),
    // );
  }

  Widget videoPreview() {
    final vfp = videoForPreview;
    if (vfp == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
          color: contourColor,
          border: Border.all(color: contourColor, width: contourWidth)),
      child: SizedBox(
          height: trueWidth,
          width: trueWidth,
          child: Down4VideoTransform(
              displaySize: Size.square(trueWidth),
              videoAspectRatio: vfp.videoAspectRatio,
              video: vfp.videoPlayer,
              isReversed: vfp.isReversed,
              isSquared: true)),
    );
    // return Down4VideoTransform(
    //   displaySize: Size.square(trueWidth),
    //   videoAspectRatio: vfp.videoAspectRatio,
    //   video: vfp.videoPlayer,
    //   isReversed: vfp.isReversed,
    //   isSquared: true,
    // );
  }

  Widget imagePreview() {
    final ifp = imageForPreview;
    if (ifp == null) return const SizedBox.shrink();
    return Container(
        // clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: PinkTheme.black,
          border: Border.all(color: contourColor, width: contourWidth),
        ),
        child: SizedBox(
          height: trueWidth,
          width: trueWidth,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(ifp.isReversed ? math.pi : 0),
            child: Image.file(io.File(ifp.path), fit: BoxFit.cover),
          ),
        ));

    // return Down4ImageTransform(
    //   image: theImage,
    //   imageAspectRatio: ifp.imageAspectRatio,
    //   displaySize: Size.square(trueWidth),
    //   isSquared: true,
    //   isReversed: ifp.isReversed,
    // );
  }

  // bool get showingGadgets =>
  //     imageForPreview != null ||
  //     videoForPreview != null ||
  //     cameraController != null ||
  //     scanner != null ||
  //     (mediasInfo != null && (mediasInfo?.show ?? false));

  // double get bbHeight {
  //   if (imageForPreview != null ||
  //       videoForPreview != null ||
  //       cameraController != null ||
  //       scanner != null) {
  //     return bbWidth;
  //   } else if (mediasInfo != null && (mediasInfo?.show ?? false)) {
  //     return mediasHeight;
  //   } else {
  //     return 0;
  //   }
  // }

  Widget get rotatingLogo {
    return AnimatedRotation(
        turns: math.pi * 2,
        duration: const Duration(seconds: 2),
        child: down4Logo(trueWidth));
  }

  // Widget bbContainer({required Widget child}) {
  //   return AnimatedContainer(
  //     duration: animationDuration,
  //     height: bbHeight,
  //     width: bbWidth,
  //     clipBehavior: Clip.hardEdge,
  //     decoration: BoxDecoration(
  //       color: PinkTheme.qrColor,
  //       border: Border.all(color: contourColor, width: contourWidth),
  //     ),
  //     child: child,
  //   );
  // }

  Widget consoleScanner() {
    if (scanner == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
          color: contourColor,
          border: Border.all(width: contourWidth, color: contourColor)),
      child: Stack(
        children: [
          SizedBox.square(
              dimension: trueWidth + (contourWidth * 2),
              child: Center(
                  child: SizedBox(
                      height: trueWidth, width: trueWidth, child: scanner!))),
        ],
      ),
    );
  }

  List<ConsoleButton> get bottomConsoleButtons => invertedColors
      ? _bottomButtons.map((e) => e.invertedColors()).toList()
      // .toList()
      // .asMap()
      // .map((key, value) => MapEntry(
      //     key,
      //     value.invertedColors(
      //         key: ButtonKeys.instance.bottomButtonKeys[key])))
      // .values
      // .toList(growable: false)
      : _bottomButtons;
  // .asMap()
  // .map((key, value) => MapEntry(key,
  //     value.withKey(key: ButtonKeys.instance.bottomButtonKeys[key])))
  // .values
  // .toList(growable: false);

  List<ConsoleButton> get topConsoleButtons => invertedColors
      ? (_topButtons ?? []).map((e) => e.invertedColors()).toList()
      // .asMap()
      // .map((key, value) => MapEntry(
      //     key,
      //     value.invertedColors(
      //         key: ButtonKeys.instance.topButtonKeys[key])))
      // .values
      // .toList(growable: false)
      : (_topButtons ?? []);
  // .asMap()
  // .map((key, value) => MapEntry(
  //     key, value.withKey(key: ButtonKeys.instance.topButtonKeys[key])))
  // .values
  // .toList(growable: false);

  Widget get anyGadgets {
    return AnimatedSize(
        duration: animationDuration,
        curve: Curves.easeInOut,
        child: Column(
          // mainAxisSize: MainAxisSize.min,
          // mainAxisAlignment: MainAxisAlignment.end,
          children: [
            consoleScanner(),
            consoleCamera(),
            imagePreview(),
            videoPreview(),
            forwardingPalettes(),
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
      margin: EdgeInsets.only(
        left: consoleGap,
        right: consoleGap,
        bottom: consoleGap,
      ),
      decoration: BoxDecoration(
          color: contourColor,
          border: Border.all(width: contourWidth, color: contourColor)),
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
          buttons,
        ],
      ),
    );
  }
}
