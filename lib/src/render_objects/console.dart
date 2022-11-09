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

import 'utils.dart';

class ConsoleButton extends StatelessWidget {
  static const double height = 26.0;
  final String name;
  final List<ConsoleButton>? extraButtons;
  final bool isSpecial, isMode, shouldBeDownButIsnt, isActivated, showExtra;
  final void Function() onPress;
  final void Function()? onLongPress;
  final void Function()? onLongPressUp;
  final double leftEpsilon, bottomEpsilon, widthEpsilon, heightEpsilon;

  const ConsoleButton({
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

  @override
  Widget build(BuildContext context) {
    final buttonHeight = Sizes.h * 0.038; // 3.8%
    return Expanded(
      child: Container(
        height: buttonHeight,
        decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: PinkTheme.black,
            border: Border.all(color: Colors.black, width: 0.5)),
        child: isActivated
            ? TouchableOpacity(
                shouldBeDownButIsnt: shouldBeDownButIsnt,
                onPress: onPress,
                onLongPress: onLongPress,
                onLongPressUp: onLongPressUp,
                child: Container(
                  color: PinkTheme.buttonColor,
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
class ConsoleInput extends StatefulWidget {
  final TextInputType type;
  final bool activated;
  final String placeHolder;
  final String value;
  final String prefix, suffix;
  final void Function(String)? inputCallBack;
  final Key k = GlobalKey();
  final TextEditingController tec;
  ConsoleInput({
    this.type = TextInputType.text,
    this.inputCallBack,
    required this.placeHolder,
    required this.tec,
    this.prefix = "",
    this.suffix = "",
    this.value = "",
    this.activated = true,
    Key? key,
  }) : super(key: key);

  @override
  _ConsoleInputState createState() => _ConsoleInputState();
}

class _ConsoleInputState extends State<ConsoleInput> {
  @override
  Widget build(BuildContext context) {
    final buttonHeight = Sizes.h * 0.038; // 3.8%
    return Expanded(
      child: Container(
        constraints: BoxConstraints(
          minHeight: buttonHeight,
          maxHeight: widget.activated ? buttonHeight * 4 : buttonHeight,
        ),
        decoration: BoxDecoration(
          color: widget.activated
              ? Colors.white
              : const Color.fromARGB(255, 216, 212, 212),
          border: Border.all(color: Colors.black, width: 0.5),
        ),
        child: widget.activated
            ? TextField(
                controller: widget.tec,
                cursorColor: PinkTheme.black,
                key: widget.k,
                maxLines: null,
                keyboardType: widget.type,
                textAlignVertical: TextAlignVertical.center,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.all(2.0),
                  hintText: widget.placeHolder,
                  border: InputBorder.none,
                  prefixIcon: Text(widget.prefix),
                  prefixIconConstraints: const BoxConstraints(
                    minHeight: 0,
                    minWidth: 0,
                  ),
                  suffixIcon: Text(widget.suffix),
                  suffixIconConstraints: const BoxConstraints(
                    minHeight: 0,
                    minWidth: 0,
                  ),
                ),
                textDirection: TextDirection.ltr,
                onChanged: widget.inputCallBack,
              )
            : Center(child: Text(widget.placeHolder)),
      ),
    );
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
  const Console({
    required this.bottomButtons,
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

  @override
  Widget build(BuildContext context) {
    final double mirror = toMirror == true ? math.pi : 0;
    final camWidthAndHeight = Sizes.w - (Sizes.h * 0.023 * 2);
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
      // child: Container(
      //   decoration: BoxDecoration(
      //     border: Border.all(width: 0.5, color: Colors.black),
      //   ),
      child: Column(
        children: [
          forwardingPalette != null
              ? SizedBox(
                  height: ConsoleButton.height,
                  width: camWidthAndHeight,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    palette.image,
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(2.0),
                                        color: PinkTheme
                                            .nodeColors[palette.node.colorCode],
                                        child: Text(
                                          palette.node.name,
                                          overflow: TextOverflow.clip,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                )
              : const SizedBox.shrink(),
          Row(textDirection: TextDirection.ltr, children: topInputs ?? []),
          Row(textDirection: TextDirection.ltr, children: inputs ?? []),
          images == true
              ? Container(
                  width: camWidthAndHeight - 1,
                  height: camWidthAndHeight - 1,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 0.5),
                    color: PinkTheme.buttonColor,
                  ),
                  child: (ListView.builder(
                      itemCount: (medias?.length ?? 0 / 4.0).ceil(),
                      itemBuilder: ((context, index) {
                        Widget f(int i) {
                          if ((medias?.length ?? 0) > i) {
                            return medias?[i].metadata.isVideo == true
                                ? SizedBox(
                                    height: (camWidthAndHeight - 2) / 5,
                                    width: (camWidthAndHeight - 2) / 5,
                                    child: Down4VideoPlayer(
                                      vid: medias![i].file!,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: () => selectMedia?.call(medias![i]),
                                    child: SizedBox(
                                      height: (camWidthAndHeight - 2) / 5,
                                      width: (camWidthAndHeight - 2) / 5,
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
                      }))),
                )
              : cameraController != null
                  ? Container(
                      width: camWidthAndHeight,
                      height: camWidthAndHeight,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: .5),
                      ),
                      child: Transform.scale(
                        alignment: Alignment.center,
                        scaleY: aspectRatio,
                        child: AspectRatio(
                          aspectRatio: aspectRatio!,
                          child: CameraPreview(cameraController!),
                        ),
                      ),
                    )
                  : imagePreviewPath != null
                      ? Container(
                          width: camWidthAndHeight,
                          height: camWidthAndHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 0.5),
                          ),
                          child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(mirror),
                              child: Image.file(
                                io.File(imagePreviewPath!),
                                fit: BoxFit.cover,
                              )))
                      : videoPlayerController != null
                          ? Container(
                              clipBehavior: Clip.hardEdge,
                              width: camWidthAndHeight,
                              height: camWidthAndHeight,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.black,
                                  width: 0.5,
                                ),
                              ),
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(mirror),
                                child: Transform.scale(
                                  scaleY: aspectRatio,
                                  child: VideoPlayer(videoPlayerController!),
                                ),
                              ),
                            )
                          : scanController != null
                              ? Container(
                                  width: camWidthAndHeight - 1,
                                  height: camWidthAndHeight - 1,
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
                                )
                              : const SizedBox.shrink(),
          Row(
            children: topButtons ?? [],
            textDirection: TextDirection.ltr,
          ),
          Row(
            children: bottomButtons,
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
