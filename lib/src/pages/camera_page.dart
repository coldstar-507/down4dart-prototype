import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../data_objects.dart' show ID;
import '../render_objects/_render_utils.dart'
    show Down4PageWidget, InvertedSize;
import '../render_objects/console.dart';
import '../globals.dart';

class SnipCamera extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "snip";

  // final CameraController ctrl;
  // final double minZoom, maxZoom;
  // final int camNum;
  final void Function() cameraBack; //, nextRes, flip;
  final void Function({
    required String mimetype,
    required String path,
    required bool isReversed,
    required Size size,
    String? text,
  }) cameraCallBack;
  final bool enableVideo;

  const SnipCamera({
    // required this.maxZoom,
    // required this.minZoom,
    // required this.camNum,
    // required this.ctrl,
    required this.cameraBack,
    required this.cameraCallBack,
    // required this.nextRes,
    // required this.flip,
    this.enableVideo = true,
    Key? key,
  }) : super(key: key);

  @override
  State<SnipCamera> createState() => _SnipCameraState();
}

class _SnipCameraState extends State<SnipCamera> {
  Widget? _preview;
  double _scale = 1.0;
  double _baseScale = 1.0;
  late double maxZoom, minZoom;
  var tec = TextEditingController();
  bool _extra = false;

  int camNum = 0;

  void initCamera() async {
    await ctrl.initialize();
    maxZoom = await ctrl.getMaxZoomLevel();
    minZoom = await ctrl.getMinZoomLevel();
    setState(() {});
  }

  late var ctrl = CameraController(g.cameras[camNum], ResolutionPreset.high);

  bool get readyCamera => ctrl.value.isInitialized;

  double get scale => ctrl.value.aspectRatio * g.sizes.fullAspectRatio;

  bool get toReverse => camNum != 0;

  Widget inputBody(bool input) => input
      ? Center(
          child: Container(
            width: g.sizes.w,
            decoration: const BoxDecoration(color: Colors.black38),
            constraints: BoxConstraints(
              minHeight: 16,
              maxHeight: g.sizes.fullHeight,
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
    initCamera();
    // capturingPage();
    // widget.ctrl.setFlashMode(FlashMode.off);
  }

  void _nextFlashMode() {
    if (ctrl.value.flashMode == FlashMode.off) {
      ctrl.setFlashMode(FlashMode.torch);
    } else {
      ctrl.setFlashMode(FlashMode.off);
    }
  }

  void flip() async {
    camNum = (camNum + 1) % 2;
    await ctrl.dispose();
    ctrl = CameraController(g.cameras[camNum], ResolutionPreset.high);
    initCamera();
  }

  Future<void> _takePicture() async {
    try {
      final xfile = await ctrl.takePicture();
      final path = xfile.path;
      await precacheImage(FileImage(File(path)), context);
      imagePreview(path, lookupMimeType(path)!, camNum == 1);
    } catch (e) {
      print("ERROR AFTER TAKING PICTURE: $e");
      widget.cameraBack();
    }
  }

  Future<void> _startRecording() async {
    try {
      await ctrl.startVideoRecording();
      setState(() {});
    } catch (e) {
      throw "ERROR TRYING TO RECORD VIDEO $e";
      widget.cameraBack();
    }
  }

  Future<void> _stopRecording() async {
    try {
      XFile? f = await ctrl.stopVideoRecording();
      final path = f.path;
      final vpc = await initVPC(path);
      final mime = lookupMimeType(path);
      videoPreview(vpc, path, mime!, camNum == 1);
    } catch (e) {
      throw "ERROR WHEN STOPPING TO RECORD $e";
      // print("ERROR WHEN STOPPING TO RECORD $e");
      // widget.cameraBack();
    }
  }

  Future<VideoPlayerController> initVPC(String filePath) async {
    final vpc = VideoPlayerController.file(File(filePath));
    await vpc.initialize();
    return vpc
      ..setLooping(true)
      ..play();
  }

  Widget previewsContainer({bool reverse = false, required Widget child}) =>
      Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(reverse ? math.pi : 0),
          child: Transform.scale(
            scale: scale > 1 ? scale : 1 / scale,
            child: SizedBox(
              height: ctrl.value.aspectRatio * g.sizes.w,
              width: g.sizes.w,
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
        width: g.sizes.w,
        child: child,
      ));

  Widget capturingPage([bool extra = false]) {
    // final cscal = 1.143;
    // final cal = 1 / (ctrl.value.aspectRatio * g.sizes.fullAspectRatio);
    // print("full = ${g.sizes.fullAspectRatio}");
    // print("cam = ${ctrl.value.aspectRatio}");
    // print("cscal = $cscal");
    // print("calll = $cal");
    // print("CAMERA IS READY? $readyCamera");
    return Stack(children: [
      !readyCamera
          ? Container(color: Colors.black)
          : GestureDetector(
              onTap: () => print("LALALALALAL"),
              onScaleStart: (details) => _baseScale = _scale,
              onScaleUpdate: (details) {
                if (_baseScale * details.scale < minZoom) {
                  _scale = minZoom;
                } else if (_baseScale * details.scale > maxZoom) {
                  _scale = maxZoom;
                } else {
                  _scale = _baseScale * details.scale;
                }
                if (_scale >= minZoom && _scale <= maxZoom) {
                  ctrl.setZoomLevel(_scale);
                }
              },
              child: previewsContainer(
                child: CameraPreview(ctrl),
              ),
            ),
      consoleBody(
        Console(
          invertedColors: true,
          topButtons: [
            ConsoleButton(
                shouldBeDownButIsnt: ctrl.value.isRecordingVideo,
                name: "Capture",
                isSpecial: widget.enableVideo,
                onPress: _takePicture,
                onLongPress: widget.enableVideo ? _startRecording : null,
                onLongPressUp: widget.enableVideo ? _stopRecording : null),
          ],
          bottomButtons: [
            ConsoleButton(name: "Back", onPress: widget.cameraBack),
            ConsoleButton(
                isMode: true,
                name: camNum == 0 ? "Rear" : "Front",
                onPress: flip),
          ],
        ),
      ),
    ]);
  }

  void videoPreview(
    VideoPlayerController vpc,
    String filePath,
    String mimetype,
    bool toReverse, [
    String? text,
    bool hasInput = false,
  ]) {
    _preview = Stack(children: [
      previewsContainer(
        child: VideoPlayer(vpc),
        reverse: toReverse,
      ),
      inputBody(hasInput),
      consoleBody(
        Console(
          invertedColors: true,
          topButtons: [
            ConsoleButton(
              name: "Accept",
              onPress: () {
                vpc.dispose();
                widget.cameraCallBack(
                  path: filePath,
                  mimetype: mimetype,
                  isReversed: toReverse,
                  text: tec.value.text,
                  size: ctrl.value.previewSize!.inverted,
                );
              },
            ),
          ],
          bottomButtons: [
            ConsoleButton(
              name: "Back",
              onPress: () => setState(() {
                File(filePath).delete();
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
                mimetype,
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
    String mimetype,
    bool toReverse, [
    String? text,
    bool hasInput = false,
  ]) {
    _preview = Stack(children: [
      previewsContainer(reverse: toReverse, child: Image.file(File(filePath))),
      inputBody(hasInput),
      consoleBody(Console(
        invertedColors: true,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () => widget.cameraCallBack(
                path: filePath,
                mimetype: mimetype,
                isReversed: toReverse,
                text: tec.value.text,
                size: ctrl.value.previewSize!.inverted),
          ),
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            onPress: () => setState(() {
              tec.clear();
              File(filePath).delete();
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
              mimetype,
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
    await ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _preview ?? capturingPage();
  }
}
