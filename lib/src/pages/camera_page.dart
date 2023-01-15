import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:down4/src/render_objects/render_utils.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';

import '../down4_utility.dart';
import '../render_objects/console.dart';
import '../boxes.dart';

class SnipCamera extends StatefulWidget {
  final CameraController ctrl;
  final double minZoom, maxZoom;
  final int camNum;
  final void Function() cameraBack, nextRes, flip;
  final void Function(
    String? filePath,
    bool? isVideo,
    bool? toReverse,
    String? text,
    double aspectRatio,
  ) cameraCallBack;
  final bool enableVideo;

  const SnipCamera({
    required this.maxZoom,
    required this.minZoom,
    required this.camNum,
    required this.ctrl,
    required this.cameraBack,
    required this.cameraCallBack,
    required this.nextRes,
    required this.flip,
    this.enableVideo = true,
    Key? key,
  }) : super(key: key);

  @override
  _SnipCameraState createState() => _SnipCameraState();
}

class _SnipCameraState extends State<SnipCamera> {
  Widget? _preview;
  double _scale = 1.0;
  double _baseScale = 1.0;
  var tec = TextEditingController();
  bool _extra = false;
  // late Size mediaSize = MediaQuery.of(context).size;

  double get scale => widget.ctrl.value.aspectRatio * Sizes.fullAspectRatio;

  bool get toReverse => widget.camNum != 0;

  Widget inputBody(bool input) => input
      ? Center(
          child: Container(
            width: Sizes.w,
            decoration: const BoxDecoration(
              // border: Border.symmetric(
              //   horizontal: BorderSide(color: Colors.black38),
              // ),
              color: Colors.black38,
              // color: PinkTheme.snipRibbon,
            ),
            constraints: BoxConstraints(
              minHeight: 16,
              maxHeight: Sizes.fullHeight,
            ),
            child: TextField(
              autofocus: input,
              textInputAction: TextInputAction.done,
              cursorColor: Colors.white,
              controller: tec,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                isCollapsed: true,
              ),
              maxLines: 15,
              minLines: 1,
              style: const TextStyle(color: Colors.white),
              // style: const TextStyle(color: PinkTheme.black),
            ),
          ),
        )
      : const SizedBox.shrink();

  @override
  void initState() {
    super.initState();
    capturingPage();
    widget.ctrl.setFlashMode(FlashMode.off);
  }

  void _nextFlashMode() {
    if (widget.ctrl.value.flashMode == FlashMode.off) {
      widget.ctrl.setFlashMode(FlashMode.torch);
    } else {
      widget.ctrl.setFlashMode(FlashMode.off);
    }
  }

  Future<void> _takePicture() async {
    try {
      final xfile = await widget.ctrl.takePicture();
      final path = xfile.path;
      await precacheImage(FileImage(File(path)), context);
      imagePreview(path, false, widget.camNum == 1);
    } catch (e) {
      widget.cameraCallBack(null, null, null, null, -1);
    }
  }

  Future<void> _startRecording() async {
    try {
      await widget.ctrl.startVideoRecording();
    } catch (e) {
      widget.cameraCallBack(null, null, null, null, -1);
    }
  }

  Future<void> _stopRecording() async {
    try {
      XFile? f = await widget.ctrl.stopVideoRecording();
      final path = f.path;
      final vpc = await initVPC(path);
      videoPreview(vpc, path, true, widget.camNum == 1);
    } catch (e) {
      widget.cameraCallBack(null, null, null, null, -1);
    }
  }

  Future<VideoPlayerController> initVPC(String filePath) async {
    var vpc = VideoPlayerController.file(File(filePath));
    try {
      await vpc.initialize();
      await vpc.setLooping(true);
      await vpc.play();
    } catch (err) {
      widget.cameraCallBack(null, null, null, null, -1);
    }
    return vpc;
  }

  Widget previewsContainer(Widget child) => Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(toReverse ? math.pi : 0),
          child: Transform.scale(
            scale: scale > 1 ? scale : 1 / scale,
            child: SizedBox(
              height: widget.ctrl.value.aspectRatio * Sizes.w,
              width: Sizes.w,
              child: child,
            ),
          ),
        ),
      );

  Widget consoleBody(Widget child) => Positioned(
      bottom: 0,
      left: 0,
      child: SizedBox(
        // height: mediaSize.height,
        width: Sizes.w,
        child: child,
      ));

  Widget capturingPage([bool extra = false]) {
    final cscal = 1.143;
    final cal = 1 / (widget.ctrl.value.aspectRatio * Sizes.fullAspectRatio);
    print("full = ${Sizes.fullAspectRatio}");
    print("cam = ${widget.ctrl.value.aspectRatio}");
    print("cscal = $cscal");
    print("calll = $cal");
    return Stack(children: [
      GestureDetector(
        onTap: () => print("LALALALALAL"),
        onScaleStart: (details) => _baseScale = _scale,
        onScaleUpdate: (details) {
          if (_baseScale * details.scale < widget.minZoom) {
            _scale = widget.minZoom;
          } else if (_baseScale * details.scale > widget.maxZoom) {
            _scale = widget.maxZoom;
          } else {
            _scale = _baseScale * details.scale;
          }
          if (_scale >= widget.minZoom && _scale <= widget.maxZoom) {
            widget.ctrl.setZoomLevel(_scale);
          }
        },
        child: previewsContainer(CameraPreview(widget.ctrl)),
      ),
      consoleBody(
        Console(
          invertedColors: true,
          topButtons: [
            ConsoleButton(
              shouldBeDownButIsnt: widget.ctrl.value.isRecordingVideo,
              name: "Capture",
              isSpecial: widget.enableVideo,
              onPress: _takePicture,
              onLongPress: widget.enableVideo ? _startRecording : null,
              onLongPressUp: widget.enableVideo ? _stopRecording : null,
            ),
          ],
          bottomButtons: [
            ConsoleButton(name: "Back", onPress: widget.cameraBack),
            ConsoleButton(
              isMode: true,
              name: widget.camNum == 0 ? "Rear" : "Front",
              onPress: widget.flip,
            ),
          ],
        ),
      ),
    ]);
  }

  void videoPreview(
    VideoPlayerController vpc,
    String filePath,
    bool isVideo,
    bool toReverse, [
    String? text,
    bool hasInput = false,
  ]) {
    _preview = Stack(children: [
      previewsContainer(VideoPlayer(vpc)),
      inputBody(hasInput),
      consoleBody(
        Console(
          invertedColors: true,
          topButtons: [
            ConsoleButton(
              name: "Accept",
              onPress: () async {
                await vpc.dispose();
                widget.cameraCallBack(
                  filePath,
                  isVideo,
                  toReverse,
                  tec.value.text,
                  widget.ctrl.value.aspectRatio,
                );
              },
            ),
          ],
          bottomButtons: [
            ConsoleButton(
              name: "Back",
              onPress: () => setState(() {
                tec.clear();
                vpc.dispose();
                setState(() {
                  _preview = null;
                });
              }),
            ),
            ConsoleButton(
              name: "Text",
              onPress: () => videoPreview(
                vpc,
                filePath,
                isVideo,
                toReverse,
                text,
                !hasInput,
              ),
            ),
          ],
        ),
      ),
    ]);
    setState(() {});
  }

  void imagePreview(
    String filePath,
    bool isVideo,
    bool toReverse, [
    String? text,
    bool hasInput = false,
  ]) {
    _preview = Stack(children: [
      previewsContainer(Image.file(File(filePath))),
      inputBody(hasInput),
      consoleBody(Console(
        invertedColors: true,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () => widget.cameraCallBack(
              filePath,
              isVideo,
              toReverse,
              tec.value.text,
              widget.ctrl.value.aspectRatio,
            ),
          ),
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            onPress: () => setState(() {
              tec.clear();
              setState(() {
                _preview = null;
              });
            }),
          ),
          ConsoleButton(
            name: "Text",
            isMode: false,
            onPress: () => imagePreview(
              filePath,
              isVideo,
              toReverse,
              text,
              !hasInput,
            ),
          ),
        ],
      )),
    ]);
    setState(() {});
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await widget.ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // print("Extra = $_extra}");
    return _preview ?? capturingPage();
  }
}
