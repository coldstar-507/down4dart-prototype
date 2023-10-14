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
  final void Function(String, Offset global) onMove;
  final void Function(String, bool) pressing;
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
    required this.pressing,
    required this.onMove,
    required this.tid,
    // required this.tid,
  }) : super(key: ValueKey(tid));

  @override
  State<TW2> createState() => _TW2State();
}

class _TW2State extends State<TW2> {
  double _curScale = 1.0;
  double _prevScale = 1.0;
  double _curRotation = 0.0;
  double _prevRotation = 0.0;
  late final Size s = widget.initSize;
  late final Offset ofs =
      Offset(widget.initSize.width / 2, widget.initSize.height / 2);
  late Offset _offset = g.sizes.middlePoint - ofs;
  int nPrevPointers = 0;

  Offset twoFingerPress = const Offset(0, 0);

  Offset _position = Offset(0, 0);
  Offset _previousPosition = Offset(0, 0);
  double _scale = 1.0;
  double _previousScale = 1.0;
  double _rotation = 0.0;
  double _previousRotation = 0.0;
  Offset _focalPoint = Offset(0, 0);

  late Offset sz = Offset(widget.initSize.width, widget.initSize.height);

  Offset rotate(Offset ofs, double angle) {
    return Offset(
      (ofs.dx * math.cos(angle)) - (ofs.dy * math.sin(angle)),
      (ofs.dx * math.sin(angle)) + (ofs.dy * math.cos(angle)),
    );
  }

  FractionalOffset fo = FractionalOffset.center;

  void calculateRbPos() {
    final k = widget.child.key as GlobalKey;
    final ctx = k.currentContext;
    final rb = ctx?.findRenderObject() as RenderBox?;
    if (ctx == null || rb == null) return print("rb is null");

    if (_focalPoint.dx == 0.0 && _focalPoint.dy == 0.0) {
      return print("FOCAL POINT NOT YET VALID");
    }

    final A = rb.localToGlobal(Offset.zero);
    final B = A + (rotate(Offset(sz.dx, 0), _rotation) * _scale);
    final C = A + (rotate(sz, _rotation) * _scale);
    final D = A + (rotate(Offset(0, sz.dy), _rotation) * _scale);

    final BCm = (B.dx == C.dx) ? double.infinity : (B.dy - C.dy) / (B.dx - C.dx);
    final BCb = B.dy - (BCm * B.dx);

    final DCm = (D.dx == C.dx) ? double.infinity : (D.dy - C.dy) / (D.dx - C.dx);
    final DCb = D.dy - (DCm * D.dx);

    final F = _focalPoint;
    final FHm = DCm;
    final FHb = F.dy - (FHm * F.dx);
    final FWm = BCm;
    final FWb = F.dy - (FWm * F.dx);
    print("""
      F = $F
      FHm = $FHm
      FHb = $FHb
      FWm = $FWm
      FWb = $FWb
      
      FH=y=x$FHm + $FHb
      FW=y=x$FWm + $FWb
      
      """);

    final Hdx = (FHb - BCb) / (BCm - FHm);
    final Hdy = (Hdx * FHm) + FHb;
    final H = Offset(Hdx, Hdy);

    final Wdx = (FHb - DCb) / (DCm - FHm);
    final Wdy = (Wdx * FHm) + FHb;
    final W = Offset(Wdx, Wdy);

    fo = FractionalOffset(
      calcDistance2(W, D) / calcDistance2(C, D),
      calcDistance2(H, B) / calcDistance2(C, B),
    );

    print("""
      A = $A
      B = $B
      C = $C
      D = $D

      F = $F
      H = $H
      W = $W

      FO = $fo
      """);
  }

  @override
  Widget build(BuildContext context) {
    Future(calculateRbPos);
    print("Fractional Offset: $fo");

    return GestureDetector(
      onScaleUpdate: (ScaleUpdateDetails details) {
        setState(() {
          _scale = _previousScale * details.scale;

          print(details.rotation);

          // _rotation += details.rotation;
          _rotation = _previousRotation + details.rotation;

          // Calculate the position based on the touch position within the widget
          print("details.focalPoint = ${details.focalPoint}");
          print("local focal point = ${details.localFocalPoint}");
          _position += details.focalPointDelta;

          _focalPoint = details.focalPoint;

          print("position: $_position");
        });
      },
      onScaleEnd: (ScaleEndDetails details) {
        setState(() {
          _previousScale = _scale;
          _previousPosition = _position;
          _previousRotation = _rotation;
        });
      },
      child: Center(
        child: Transform(
          transform: Matrix4.identity()
            ..translate(_position.dx, _position.dy)
            ..rotateZ(_rotation),
          //..scale(_scale),
          alignment: FractionalOffset.center,
          child: Transform(
            alignment: fo,
            transform: Matrix4.identity()..scale(_scale),
            child: widget.child,
          ), // Replace with your image asset
        ),
      ),
    );

    return Positioned(
      bottom: _offset.dy,
      right: _offset.dx,
      child: Transform(
        // origin: twoFingerPress,
        transform: Matrix4.identity()..scale(_curScale),
        alignment: FractionalOffset.center,
        child: GestureDetector(
          onScaleStart: (details) {
            print("scale start");
            widget.pressing(widget.tid, true);
          },
          onScaleEnd: (details) {
            print("scale end");
            _prevScale = _curScale;
            _prevRotation = _curRotation;
            widget.pressing(widget.tid, false);
          },
          onScaleUpdate: (details) {
            print("scaling!");
            widget.onMove(widget.tid, details.focalPoint);
            if (details.pointerCount == 1 && nPrevPointers == 1) {
              print("1 pointer scaling");
              _offset -= details.focalPointDelta * _curScale;
            } else if (details.pointerCount == 2 && nPrevPointers == 2) {
              // twoFingerPress = details.focalPoint;
              _curScale = _prevScale * details.scale;
              _curRotation = _prevRotation + details.rotation;
            }
            nPrevPointers = details.pointerCount;
            setState(() {});
          },
          child: Transform.rotate(angle: _curRotation, child: widget.child),
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
  Map<String, bool> pressing = {};
  Map<String, Offset> positions = {};

  @override
  List<(String, void Function(Down4Media))> get mediasMode {
    return [
      (
        "PUT",
        (m) {
          print("putting that fucking shit in nigga");
          Size scaleFor(Size from, Size to) {
            // we want the largest side of (from) to be (smallest size of (to) / 2)
            double width, height;
            // aspectRatio :  width / height
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

          final tw = TW2(
              tid: randomMediaID(),
              initSize: s,
              child: m.display(size: s, key: GlobalKey()),
              pressing: (tid, p) {
                pressing[tid] = p;
                if (!p) {
                  print("delete button position: $xWidgetPos");
                  print("drop off position     : ${positions[tid]}");
                  final dropPos = positions[tid]!;
                  final pixelDist = calcDistance2(xWidgetPos, dropPos);
                  if (pixelDist < 60) {
                    sticks.removeWhere((e) => e.tid == tid);
                    pressing.remove(tid);
                    positions.remove(tid);
                  }
                }
                setState(() {});
              },
              onMove: (tid, ofs) {
                final ix = sticks.indexWhere((e) => e.tid == tid);
                if (ix != 0) sticks.swap(0, ix);
                positions[tid] = ofs;
                setState(() {});
              });
          sticks.insert(0, tw);
          pressing[tw.tid] = false;
          setState(() {});
        }
      )
    ];
  }

  // Widget? _preview;
  double _scale = 1.0;
  double _baseScale = 1.0;
  late double maxZoom, minZoom;

  bool get isVideo => vpc != null;
  bool get hasPreview => filePath != null || _blank;
  bool _blank = false;

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

  // CameraController newCameraController() =>
  //     CameraController(g.cameras[camNum], ResolutionPreset.high);

  late double _ar;

  void initCamera() async {
    if (ctrl.value.isInitialized) {
      _ar = ctrl.value.aspectRatio;
      return;
    }
    await ctrl.initialize();
    _ar = ctrl.value.aspectRatio;
    maxZoom = await ctrl.getMaxZoomLevel();
    minZoom = await ctrl.getMinZoomLevel();
    await ctrl.setFlashMode(FlashMode.off);
    setState(() {});
  }

  CameraController? _ctrl;

  CameraController get ctrl {
    return _ctrl ??= CameraController(g.cameras[camNum], ResolutionPreset.high);
  }

  bool get readyCamera => ctrl.value.isInitialized;

  double get scale => g.sizes.fullAspectRatio * _ar; // ctrl.value.aspectRatio;

  bool get toReverse => camNum != 0;

  Widget get inputBody => hasInput ? input.snipInput : const SizedBox.shrink();

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

  Future<void> killCamera() async {
    await ctrl.dispose();
    _ctrl = null;
  }

  void flip() async {
    camNum = (camNum + 1) % 2;
    await killCamera();
    // await ctrl.dispose();
    initCamera();
  }

  Future<void> _takePicture() async {
    try {
      final xfile = await ctrl.takePicture();
      filePath = xfile.path;
      await precacheImage(FileImage(File(filePath!)), context);
      mimetype = lookupMimeType(filePath!);
      await killCamera();
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
      await killCamera();
      // ctrl.dispose();
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
                    height: g.sizes.w * _ar, // ctrl.value.aspectRatio,
                    width: g.sizes.w,
                    child: child,
                  ),
                ),
              ),
            ),
            ...sticks.reversed,
            inputBody,
            // Positioned(
            //     right: g.sizes.headerHeight / 2,
            //     top: g.sizes.statusBarHeight, // + (g.sizes.headerHeight / 2),
            //     child: xWidget),
          ],
        ),
      );

  Offset get xWidgetPos {
    final rb = xKey.currentContext!.findRenderObject() as RenderBox;
    return rb.localToGlobal(Offset.zero);
  }

  GlobalKey xKey = GlobalKey();
  Widget get xWidget {
    return AnimatedOpacity(
      key: xKey,
      opacity: pressing.values.any((e) => e) ? 1 : 0,
      duration: Console.animationDuration,
      child: // Center(
          // child:
          Icon(
        Icons.block,
        color: Colors.white,
        size: g.sizes.headerHeight / 2,
      ),
//      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    killCamera();
    // ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      backFunction: widget.cameraBack,
      transparentHeader: true,
      extraHeaderWidgets: [xWidget],
      pages: [
        Down4Page(
          title: "",
          console: console,
          staticList: true,
          stackWidgets: [
            hasPreview
                ? previewsContainer(
                    reverse: toReverse,
                    child: filePath != null
                        ? isVideo
                            ? VideoPlayer(vpc!)
                            : Image.file(File(filePath!))
                        : const SizedBox.shrink())
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
                    name: "BLANK",
                    onPress: () {
                      _blank = true;
                      changeConsole("preview");
                    }),
                // ConsoleButton(
                //     name: ctrl.value.flashMode.name.toUpperCase(),
                //     onPress: _nextFlashMode,
                //     isMode: true),
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
                  name: "RETRY",
                  onPress: () async {
                    sticks.clear();
                    _blank = false;
                    if (filePath != null) {
                      File(filePath!).delete();
                    }
                    filePath = null;
                    hasInput = false;
                    input.clear();
                    vpc?.dispose();
                    vpc = null;
                    await killCamera();
                    // ctrl.dispose();
                    initCamera();
                    changeConsole("base");
                    setState(() {});
                  },
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
