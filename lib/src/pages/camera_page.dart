import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/data_objects/_data_utils.dart';
import 'package:down4/src/data_objects/medias.dart';
import 'package:down4/src/data_objects/messages.dart';
import 'package:down4/src/render_objects/navigator.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../render_objects/_render_utils.dart';
import '../render_objects/console.dart';
import '../pages/_page_utils.dart';
import '../globals.dart';

class TW1 extends StatefulWidget {
  final Widget child;
  final void Function(Offset) onMove;

  const TW1({super.key, required this.onMove, required this.child});

  @override
  State<TW1> createState() => _TW1State();
}

class _TW1State extends State<TW1> {
  final origin = const Offset(0.0, 0.0);
  late Offset _position = origin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) {
        print("vertical drag my nigga\ndelta=${d.delta}");
        _position += d.delta;
        widget.onMove(_position);
      },
      child: Center(
        child: Transform(
          transform: Matrix4.identity()..translate(_position.dx, _position.dy),
          alignment: FractionalOffset.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class TW2 extends StatefulWidget {
  final Widget child;
  final ComposedID mediaID;
  final Size initSize;
  final String tid;
  final void Function(String, Offset, double, double) onMove;
  final void Function(String, bool, Offset) pressing;
  final bool allowRotation,
      allowScale,
      allowHorizontalTranslation,
      allowVerticalTranslation;

  TW2({
    required this.mediaID,
    required this.child,
    required this.initSize,
    required this.pressing,
    required this.onMove,
    required this.tid,
    this.allowScale = true,
    this.allowRotation = true,
    this.allowHorizontalTranslation = true,
    this.allowVerticalTranslation = true,
  }) : super(key: ValueKey(tid));

  @override
  State<TW2> createState() => _TW2State();
}

class _TW2State extends State<TW2> {
  final origin = const Offset(0.0, 0.0);
  double _prevScale = 1.0;
  late final Size s = widget.initSize;
  int nPrevPointers = 0;

  late Offset _position = origin;
  late Offset _focalPoint = origin;

  double _scale = 1.0;
  double _prevPrevScale = 1.0;
  double _rotation = 0.0;
  double _previousRotation = 0.0;

  late Offset sz = Offset(widget.initSize.width, widget.initSize.height);

  Offset rotate(Offset ofs, double angle) {
    return Offset(
      (ofs.dx * math.cos(angle)) - (ofs.dy * math.sin(angle)),
      (ofs.dx * math.sin(angle)) + (ofs.dy * math.cos(angle)),
    );
  }

  Offset get a_ {
    final key = widget.child.key as GlobalKey;
    final ctx = key.currentContext;
    final rb = ctx?.findRenderObject() as RenderBox?;

    if (ctx == null || rb == null || _focalPoint == origin) {
      final ss = g.sizes.snipSize;
      final s = widget.initSize;
      return Offset(ss.width - (s.width / 2), ss.height - (s.height / 2));
    }

    return rb.localToGlobal(Offset.zero);
  }

  (Offset, Offset) calculateKandJ(double nextAngle) {
    final key = widget.child.key as GlobalKey;
    final ctx = key.currentContext;
    final rb = ctx?.findRenderObject() as RenderBox?;

    if (ctx == null || rb == null || _focalPoint == origin) {
      return (origin, origin);
    }

    final a = a_;
    final c = a + (rotate(sz, _rotation) * _scale);
    final p = (a / 2) + (c / 2);
    final f = _focalPoint;

    final k = p - f;

    final f_ = rotate(f - p, nextAngle - _rotation) + p;
    final j = f_ - f;

    return (k, j);
  }

  // void calculateRbPos() {
  //   final k = widget.child.key as GlobalKey;
  //   final ctx = k.currentContext;
  //   final rb = ctx?.findRenderObject() as RenderBox?;
  //   if (ctx == null || rb == null) return print("rb is null");

  //   if (_focalPoint.dx == 0.0 && _focalPoint.dy == 0.0) {
  //     return print("FOCAL POINT NOT YET VALID");
  //   }

  //   final A = rb.localToGlobal(Offset.zero);
  //   final B = A + (rotate(Offset(sz.dx, 0), _rotation) * _scale);
  //   final C = A + (rotate(sz, _rotation) * _scale);
  //   final D = A + (rotate(Offset(0, sz.dy), _rotation) * _scale);
  //   final F = _focalPoint;

  //   if ((_rotation / (math.pi / 2)) % 1 == 0) {
  //     fo = FractionalOffset(
  //       (F.dx - D.dx) / (C.dx - D.dx),
  //       (F.dy - B.dy) / (C.dy - B.dy),
  //     );
  //     return print("angle is a divisable by pi/2");
  //   }

  //   final BCm =
  //       (B.dx == C.dx) ? double.infinity : (B.dy - C.dy) / (B.dx - C.dx);
  //   final BCb = B.dy - (BCm * B.dx);

  //   final DCm =
  //       (D.dx == C.dx) ? double.infinity : (D.dy - C.dy) / (D.dx - C.dx);
  //   final DCb = D.dy - (DCm * D.dx);

  //   final FHm = DCm;
  //   final FHb = F.dy - (FHm * F.dx);
  //   final FWm = BCm;
  //   final FWb = F.dy - (FWm * F.dx);

  //   final Hdx = (FHb - BCb) / (BCm - FHm);
  //   final Hdy = (Hdx * FHm) + FHb;
  //   final H = Offset(Hdx, Hdy);

  //   final Wdx = (DCb - FWb) / (FWm - DCm);
  //   final Wdy = (FWm * Wdx) + FWb;
  //   final W = Offset(Wdx, Wdy);

  //   fo = FractionalOffset(
  //     calcDistance2(W, D) / calcDistance2(C, D),
  //     calcDistance2(H, B) / calcDistance2(C, B),
  //   );

  //   isCalculation = true;
  // }

  // bool isCalculation = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleUpdate: (ScaleUpdateDetails details) {
        final newScale = details.scale * _prevScale;
        final newAngle = _previousRotation + details.rotation;
        if (details.pointerCount == nPrevPointers) {
          if (nPrevPointers == 2) {
            final lastWidth = _prevPrevScale * widget.initSize.width;
            final newWidth = newScale * widget.initSize.width;
            // same result using height
            final pixelScale = ((newWidth / lastWidth) - 1) / 2;

            final (k, j) = calculateKandJ(newAngle);
            _position += (details.focalPointDelta) + (k * pixelScale) - j;
          } else {
            _position += details.focalPointDelta;
          }
        }

        _prevPrevScale = _scale;
        _scale = newScale;
        _rotation = _previousRotation + details.rotation;
        _focalPoint = details.focalPoint;
        nPrevPointers = details.pointerCount;

        widget.onMove(widget.tid, _position, _scale, _rotation);

        setState(() {});
      },
      onScaleStart: (details) {
        widget.pressing(widget.tid, true, _focalPoint);
      },
      onScaleEnd: (ScaleEndDetails details) {
        _prevScale = _scale;
        _previousRotation = _rotation;
        widget.pressing(widget.tid, false, _focalPoint);
      },
      child: Center(
        child: Transform(
          transform: Matrix4.identity()
            ..translate(_position.dx, _position.dy)
            ..scale(_scale)
            ..rotateZ(_rotation),
          alignment: FractionalOffset.center,
          child: widget.child,
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
    required Down4Media? backgroundMedia,
    required List<SnipStick> sticks,
    required String? text,
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
  Map<String, (Offset, double, double)> positions = {};
  List<(ComposedID, Offset, Size, double, double)> get sticksInfo {
    return sticks.map((e) {
      final (ofs, scl, rot) = positions[e.tid]!;
      return (e.mediaID, ofs, e.initSize, scl, rot);
    }).toList();
  }

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
              mediaID: m.id,
              initSize: s,
              child: m.display(size: s, key: GlobalKey()),
              pressing: (tid, p, dp) {
                pressing[tid] = p;
                if (!p) {
                  final pixelDist = calcDistance2(xWidgetPos, dp);
                  if (pixelDist < 60) {
                    sticks.removeWhere((e) => e.tid == tid);
                    pressing.remove(tid);
                    positions.remove(tid);
                  }
                }
                setState(() {});
              },
              onMove: (tid, ofs, scl, rot) {
                positions[tid] = (ofs, scl, rot);
                final ix = sticks.indexWhere((e) => e.tid == tid);
                if (ix != 0) {
                  final e = sticks.removeAt(ix);
                  sticks.insert(0, e);
                  // sticks.swap(0, ix);
                  setState(() {});
                }
              });
          sticks.insert(0, tw);
          positions[tw.tid] = (const Offset(0, 0), 1.0, 0.0);
          pressing[tw.tid] = false;
          setState(() {});
        }
      )
    ];
  }

  Size get ss => g.sizes.snipSize;

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

  late double _ar;
  late Size _camSize;

  void initCamera() async {
    if (ctrl.value.isInitialized) {
      _ar = ctrl.value.aspectRatio;
      return;
    }
    await ctrl.initialize();
    _ar = ctrl.value.aspectRatio;
    _camSize = ctrl.value.previewSize!.inverted;
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

  Widget get inputBody => hasInput ? snipInput : const SizedBox.shrink();

  (String, String, bool, Size)? get m {
    if (filePath == null) return null;
    ctrl.value.previewSize;
    return (filePath!, mimetype!, toReverse, _camSize);
  }

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
      child: Icon(
        Icons.block,
        color: Colors.white,
        size: g.sizes.headerHeight / 2,
      ),
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
                    ? const SizedBox.shrink()
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

  Offset so = const Offset(0, 0);
  late TW1 snipInput = TW1(onMove: (so_) => so = so_, child: input.snipInput);

  @override
  List<Extra> extras = [];

  @override
  Console get console => Console(
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
                    Down4Media? m;
                    if (filePath != null) {
                      m = Down4Media.fromLocal(ComposedID(),
                          mainCachedPath: filePath,
                          metadata: Down4MediaMetadata(
                              ownerID: g.self.id,
                              timestamp: makeTimestamp(),
                              width: _camSize.width,
                              height: _camSize.height,
                              mime: mimetype!));
                    }

                    final stx = sticks.map((e) {
                      final (ofs, scl, rot) = positions[e.tid]!;
                      return SnipStick(
                          mediaID: e.mediaID,
                          pos: ofs,
                          tempID_: null, // will be defined on upload
                          tempTS_: null, // will be defined on upload
                          initSize: e.initSize,
                          rotation: rot,
                          scale: scl);
                    }).toList();

                    vpc?.dispose();
                    widget.cameraCallBack(
                        backgroundMedia: m?..cache(),
                        text: input.value,
                        sticks: stx);
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
