import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/data_objects/medias.dart';
import 'package:down4/src/render_objects/navigator.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'package:collection/collection.dart' show ListExtensions;

import '../render_objects/_render_utils.dart';
import '../render_objects/console.dart';
import '../pages/_page_utils.dart';
import '../globals.dart';

class TransformableWidget extends StatelessWidget {
  final Widget child;
  final String tid;
  final Offset currentOffset;
  final double currentScale, currentRotation;
  final void Function(Offset, double rot, double scl, String tid)
      onPositionChange;
  TransformableWidget({
    required this.onPositionChange,
    required this.currentOffset,
    required this.currentScale,
    required this.currentRotation,
    required this.tid,
    // required this.previousScale,
    required this.child,
  }) : super(key: ValueKey(tid));

  TransformableWidget withNewPosition(Offset ofs, rot, scl) {
    return TransformableWidget(
      onPositionChange: onPositionChange,
      currentOffset: ofs,
      // previousScale: previousScale,
      currentScale: scl,
      currentRotation: rot,
      tid: tid,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        if (details.pointerCount == 1) {
          final pos = currentOffset + details.focalPointDelta;
          onPositionChange(pos, currentRotation, currentScale, tid);
        } else if (details.pointerCount == 2) {
          print("details.scale: ${details.scale}");
          double scl;
          if (details.scale > 1.0) {
            scl = currentScale * 1.05;
          } else {
            scl = currentScale * 0.95;
          }
          onPositionChange(currentOffset, currentRotation, scl, tid);
        }
      },
      child: Center(
        child: Transform(
          transform: Matrix4.identity()
            ..scale(currentScale)
            ..rotateZ(currentRotation),
          alignment: FractionalOffset.center,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class TW2 extends StatefulWidget {
  final Widget child;
  final Size initSize;
  final String tid;
  final void Function(String) onMove;
  // final double scale;
  // final Offset offset;
  // final double rotation;
  // final String tid;

  TW2({
    required this.child,
    required this.initSize,
    // required this.scale,
    // required this.offset,
    // required this.rotation,
    required this.onMove,
    required this.tid,
    // required this.tid,
  }) : super(key: ValueKey(tid));

  @override
  State<TW2> createState() => _TW2State();
}

class _TW2State extends State<TW2> {
  double _scale = 0.5;
  double _previousScale = 1.0;
  double _rotation = 0.0;
  late final Size s = widget.initSize;
  late final Offset ofs = Offset(widget.initSize.width, widget.initSize.height);
  late Offset _offset = g.sizes.middlePoint - ofs;
  // late Offset _prevOffset = widget.offset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: _offset.dy,// * _scale,
      right: _offset.dx,// * _scale,
      child: Transform(
        transform: Matrix4.identity()
          // ..translate(_offset.dx, _offset.dy)
          ..scale(_scale)
          ..rotateZ(_rotation),
        alignment: FractionalOffset.center,
        child: GestureDetector(
          onScaleUpdate: (details) {
            print("scaling!");
            widget.onMove(widget.tid);
            if (details.pointerCount == 1) {
              print("1 pointer scaling");
              _offset -= details.focalPointDelta * _scale;
            } else if (details.pointerCount == 2) {
              print("2 pointer scaling");
              if (details.scale > 1.0) {
                _scale = _scale * 1.01;
              } else {
                _scale = _scale * 0.99;
              }
            }
            setState(() {});
          },
          child: widget.child,
//          ),
        ),
      ),
    );
  }
}

class SnipCamera extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "snip";

  final void Function() cameraBack;
  final void Function({
    required String mimetype,
    required String path,
    required bool isReversed,
    required Size size,
    String? text,
  }) cameraCallBack;
  final bool enableVideo;

  const SnipCamera({
    required this.cameraBack,
    required this.cameraCallBack,
    this.enableVideo = true,
    Key? key,
  }) : super(key: key);

  @override
  State<SnipCamera> createState() => _SnipCameraState();
}

class _SnipCameraState extends State<SnipCamera>
    with WidgetsBindingObserver, Pager2, Input2, Medias2 {
  VideoPlayerController? vpc;
  String? filePath;
  String? mimetype;
  String? text;
  bool hasInput = false;

  List<TW2> sticks = [];

  @override
  List<(String, void Function(Down4Media))> get mediasMode {
    return [
      (
        "PUT",
        (m) {
          print("putting that fucking shit in nigga");
          Size scaleFor(Size from, Size to) {
            // width / height
            // we want the largest side of (from) to be (smallest size of (to) / 2)
            double width, height;
            if (from.aspectRatio > 1) {
              // large media
              width = to.width / 2;
              height = width / from.aspectRatio;
            } else {
              // long media
              height = to.height / 2;
              width = height * from.aspectRatio;
            }
            return Size(width, height);
          }

          final s = scaleFor(m.size, g.sizes.snipSize);
          print("from  : ${m.size}\nto    : ${g.sizes.snipSize}\nresult: $s\n");

          final tw = TW2(
              tid: randomMediaID(),
              initSize: s,
              child: m.display(size: s),
              onMove: (tid) {
                final ix = sticks.indexWhere((e) => e.tid == tid);
                if (ix != 0) sticks.swap(0, ix);
                setState(() {});
              });

          sticks.insert(0, tw);
          setState(() {});
          // final tid = randomMediaID();
          // final tw = TransformableWidget(
          //     onPositionChange: (ofs, rot, scl, tid) {
          //       final ix = sticks.indexWhere((e) => e.tid == tid);
          //       sticks[ix] = sticks[ix].withNewPosition(ofs, rot, scl);
          //       if (ix != 0) sticks.swap(ix, 0);
          //       setState(() {});
          //     },
          //     currentOffset: g.sizes.middlePoint - m.middlePoint,
          //     currentRotation: 0,
          //     currentScale: 1.0,
          //     tid: tid,
          //     child: m.display(size: m.size));
          // sticks.insert(0, tw);
          // setState(() {});
        }
      )
    ];
  }

  // Widget? _preview;
  double _scale = 1.0;
  double _baseScale = 1.0;
  late double maxZoom, minZoom;

  bool get isVideo => vpc != null;
  bool get hasPreview => filePath != null;

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      config: Input2.multiLine,
      centered: true,
      isConsoleInput: false,
      specificStyle: g.theme.snipInputTextStyle,
      placeholderStyle: g.theme.snipInputTextStyle,
      maxWidth: 1.0,
      verticalTextPadding: 4,
      onInput: onInput,
      onFocusChange: onFocusChange,
    )
  ];

  int camNum = 0;

  CameraController newCameraController() =>
      CameraController(g.cameras[camNum], ResolutionPreset.high);

  void initCamera() async {
    ctrl = newCameraController();
    await ctrl.initialize();
    maxZoom = await ctrl.getMaxZoomLevel();
    minZoom = await ctrl.getMinZoomLevel();
    await ctrl.setFlashMode(FlashMode.off);
    setState(() {});
  }

  late CameraController ctrl = newCameraController();

  bool get readyCamera => ctrl.value.isInitialized;

  double get scale => ctrl.value.aspectRatio * g.sizes.fullAspectRatio;

  bool get toReverse => camNum != 0;

  Widget get inputBody => hasInput
      ? Center(
          child: Container(
              width: g.sizes.w,
              color: Colors.black38,
              height: input.height,
              child: input.basicInput),
        )
      : const SizedBox.shrink();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  void _nextFlashMode() {
    if (ctrl.value.flashMode == FlashMode.off) {
      ctrl.setFlashMode(FlashMode.torch);
    } else {
      ctrl.setFlashMode(FlashMode.off);
    }
    setState(() {});
  }

  void flip() async {
    camNum = (camNum + 1) % 2;
    await ctrl.dispose();
    initCamera();
  }

  Future<void> _takePicture() async {
    try {
      final xfile = await ctrl.takePicture();
      filePath = xfile.path;
      await precacheImage(FileImage(File(filePath!)), context);
      mimetype = lookupMimeType(filePath!);
      ctrl.dispose();
      changeConsole("preview");
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
      widget.cameraBack();
      throw "ERROR TRYING TO RECORD VIDEO $e";
    }
  }

  Future<void> _stopRecording() async {
    try {
      XFile? f = await ctrl.stopVideoRecording();
      filePath = f.path;
      vpc = await initVPC(f.path);
      mimetype = lookupMimeType(f.path);
      ctrl.dispose();
      changeConsole("preview");
    } catch (e) {
      // throw "ERROR WHEN STOPPING TO RECORD $e";
      print("ERROR WHEN STOPPING TO RECORD $e");
      widget.cameraBack();
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
      SizedBox.fromSize(
        size: g.sizes.snipSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
            ),
            ...sticks.reversed,
          ],
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      backFunction: widget.cameraBack,
      transparentHeader: true,
      pages: [
        Down4Page(
          title: "",
          console: console,
          staticList: true,
          stackWidgets: [
            hasPreview
                ? previewsContainer(
                    reverse: toReverse,
                    child: isVideo
                        ? VideoPlayer(vpc!)
                        : Image.file(File(filePath!)))
                : !readyCamera
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
                        child: previewsContainer(child: CameraPreview(ctrl)),
                      ),
          ],
        )
      ],
    );
  }

  TransformableWidget? _snipInput;

  TransformableWidget get movableInput {
    return _snipInput ??= TransformableWidget(
        onPositionChange: (ofs, rot, scl, tid) {
          print("moving snip input!");
          _snipInput = _snipInput!.withNewPosition(ofs, rot, scl);
          setState(() {});
        },
        currentOffset: g.sizes.middlePoint,
        currentScale: 1.0,
        currentRotation: 0.0,
        tid: randomMediaID(),
        child: input.snipInput);
  }

  @override
  List<Extra> extras = [];

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                ConsoleButton(
                    name: "BACK",
                    onPress: widget.cameraBack,
                    isInverted: false),
                ConsoleButton(
                    name: ctrl.value.flashMode.name.toUpperCase(),
                    onPress: _nextFlashMode,
                    isMode: true),
                ConsoleButton(
                    isMode: true,
                    name: camNum == 0 ? "REAR" : "FRONT",
                    onPress: flip),
                ConsoleButton(
                    shouldBeDownButIsnt: ctrl.value.isRecordingVideo,
                    name: "CAPTURE",
                    isSpecial: widget.enableVideo,
                    onPress: _takePicture,
                    onLongPress: widget.enableVideo ? _startRecording : null,
                    onLongPressUp: widget.enableVideo ? _stopRecording : null),
              ], extension: null, widths: null, inputMaxHeight: null),
              "preview": ConsoleRow(widgets: [
                ConsoleButton(
                  name: "BACK",
                  onPress: () => setState(() {
                    sticks.clear();
                    File(filePath!).delete();
                    filePath = null;
                    hasInput = false;
                    input.clear();
                    vpc?.dispose();
                    vpc = null;
                    ctrl.dispose();
                    initCamera();
                    changeConsole("base");
                  }),
                ),
                mediasButton,
                ConsoleButton(
                  name: "TEXT",
                  isMode: hasInput,
                  onPress: () => setState(() => hasInput = !hasInput),
                ),
                ConsoleButton(
                  name: "SEND",
                  onPress: () {
                    vpc?.dispose();
                    widget.cameraCallBack(
                      path: filePath!,
                      mimetype: mimetype!,
                      isReversed: toReverse,
                      text: input.value,
                      size: ctrl.value.previewSize!.inverted,
                    );
                  },
                ),
              ], extension: null, widths: null, inputMaxHeight: null),
              "medias": basicMediasRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  String get backFromMediasConsoleName => "preview";

  @override
  List<String> currentConsolesName = ["base"];

  @override
  void setTheState() {
    setState(() {});
  }
}
