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

class TW2 extends StatefulWidget {
  final Widget child;
  final ComposedID mediaID;
  final Size initSize;
  final Offset inita;
  final String tid;
  final void Function(String, Offset, double, double) onMove;
  final void Function(String, bool, Offset) pressing;
  final void Function(Offset, String) ona;
  final bool allowRotation,
      allowScale,
      allowHorizontalTranslation,
      allowVerticalTranslation;

  Offset get sizeOfs => Offset(initSize.width, initSize.height);

  TW2({
    required this.inita,
    required this.mediaID,
    required this.child,
    required this.initSize,
    required this.pressing,
    required this.onMove,
    required this.tid,
    required this.ona,
    this.allowScale = true,
    this.allowRotation = true,
    this.allowHorizontalTranslation = true,
    this.allowVerticalTranslation = true,
  }) : super(key: ValueKey(tid));

  @override
  State<TW2> createState() => _TW2State();
}

class _TW2State extends State<TW2> {
  Size get snipSize => g.sizes.snipSize;
  Size get initSize => widget.initSize;
  Offset get oo => Offset(
        0,
        (snipSize.height - s.height) / 2,
      );
  Offset get ob => oo + _position;

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
      return widget.inita;
    }

    return rb.localToGlobal(Offset.zero);
  }

  (Offset, Offset) calculateKandJ(double nextAngle) {
    final a = a_;
    final c = a + (rotate(sz, _rotation) * _scale);
    final p = (a / 2) + (c / 2);
    final f = _focalPoint;

    final k = p - f;

    final f_ = rotate(f - p, nextAngle - _rotation) + p;
    final j = f_ - f;

    return (k, j);
  }

  @override
  Widget build(BuildContext context) {
    Future(() => widget.ona(a_, widget.tid));
    return GestureDetector(
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

        print("_position = $_position, a_ = $a_");
        widget.onMove(widget.tid, ob, _scale, _rotation);

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
          alignment: AlignmentDirectional.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class SnipCamera extends StatefulWidget with Down4PageWidget {
  @override
  String get id => "snip";

  final void Function() cameraBack;
  final void Function({
    required Down4Media? backgroundMedia,
    required List<SnipStick> sticks,
    required Size ps,
    required String? text,
    required double? pdy,
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
  Map<String, Offset> trueOffset = {};

  @override
  List<(String, void Function(Down4Media))> get mediasMode {
    return [
      (
        "PUT",
        (m) {
          final s = applyBoxFit(BoxFit.fitWidth, m.size, g.sizes.snipSize)
              .destination;
          final scl = s * 0.8;
          final gx = (s.width - scl.width) / 2;
          final gy = (s.height - scl.height) / 2;

          final inita = Offset(gx, ((snipSize.height - s.height) / 2) + gy);

          print("""
            initSize: $s
            inita: $inita
            scaledInitSize: $scl
            """);

          final tw = TW2(
              inita: inita,
              tid: randomMediaID(),
              mediaID: m.id,
              initSize: scl,
              child: m.display(size: scl, key: GlobalKey()),
              ona: (a, tid) => trueOffset[tid] = a,
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
    ctrl.setZoomLevel(_scale);    
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

  double get scale => g.sizes.fullAspectRatio * _ar;

  bool get toReverse => camNum != 0;

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
      changeConsole("preview");
    } catch (e) {
      print("ERROR WHEN STOPPING TO RECORD $e");
      widget.cameraBack();
    }
  }

  Future<VideoPlayerController> initVPC(String filePath_) async {
    final vpc = VideoPlayerController.file(File(filePath_));
    await vpc.initialize();
    return vpc
      ..setLooping(true)
      ..play();
  }

  Size get snipSize => g.sizes.snipSize;
  Offset get snipo => Offset(snipSize.width, snipSize.height);
  Offset get centerSnip => snipo / 2.0;
  Widget cameraChild() {
    Widget readyCam() {
      final cs = applyBoxFit(BoxFit.contain, _camSize, snipSize).destination;
      final (k, _, _) = kds_(cs, snipSize);
      return Transform.scale(
        alignment: FractionalOffset.center,
        scale: 1 / k,
        child: Align(
          alignment: Alignment.center,
          child: SizedBox.fromSize(
            size: cs,
            child: CameraPreview(ctrl),
          ),
        ),
      );
    }

    if (!readyCamera) {
      return const SizedBox.shrink();
    } else {
      return GestureDetector(
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
        child: previewsContainer(child: readyCam()),
      );
    }
  }

  Widget previewChild() {
    Widget widg() {
      if (filePath != null) {
        final cs_ = applyBoxFit(BoxFit.contain, _camSize, snipSize);
        final cs = cs_.destination;
        final (k, _, _) = kds_(cs, snipSize);
        if (isVideo) {
          return Transform(
              alignment: FractionalOffset.center,
              transform: Matrix4.identity()
                ..scale(1 / k)
                ..rotateY(toReverse ? math.pi : 0),
              child: Align(
                  alignment: Alignment.center,
                  child:
                      SizedBox.fromSize(size: cs, child: VideoPlayer(vpc!))));
        } else {
          final im = Image.file(File(filePath!));
          return Transform(
              alignment: FractionalOffset.center,
              transform: Matrix4.identity()
                ..scale(1 / k)
                ..rotateY(toReverse ? math.pi : 0),
              child: Align(alignment: Alignment.center, child: im));
        }
      }
      return const SizedBox.shrink();
    }

    return previewsContainer(reverse: toReverse, child: widg());
  }

  Widget previewsContainer({bool reverse = false, required Widget child}) {
    return SizedBox.fromSize(
      size: snipSize,
      child: Stack(
        children: [
          child,
          ...sticks.reversed,
          hasInput
              ? input.snipInput2((p0) => setState(() => so += p0))
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Size get start => _blank ? snipSize : _camSize;
  (Size, Offset, List<SnipStick>) relativeGs() {
    final s_ = applyBoxFit(BoxFit.contain, start, snipSize).destination;
    final (_, d, s) = kds_(s_, snipSize);
    return (
      s,
      d,
      sticks.map((e) {
        final (_, scl, rot) = positions[e.tid]!;
        final o = trueOffset[e.tid] ?? e.inita;
        final relo = o + d;
        final pos = Offset(relo.dx / s.width, relo.dy / s.height);
        return SnipStick(
            mediaID: e.mediaID,
            pos: pos,
            tempID_: null,
            tempTS_: null,
            initSize: e.initSize,
            rotation: rot,
            scale: scl);
      }).toList()
    );
  }

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
            hasPreview ? previewChild() : cameraChild(),
          ],
        )
      ],
    );
  }

  Offset so = const Offset(0, 0);
  Offset get sio => Offset(0, (snipSize.height - input.ctrl.height) / 2) + so;

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
                      if (filePath != null) File(filePath!).delete();
                      filePath = null;
                      hasInput = false;
                      input.clear();
                      vpc?.dispose();
                      vpc = null;
                      await killCamera();
                      initCamera();
                      changeConsole("base");
                      setState(() {});
                    }),
                mediasButton,
                ConsoleButton(
                    name: "TEXT",
                    isMode: hasInput,
                    onPress: () => setState(() => hasInput = !hasInput)),
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
                                isReversed: toReverse,
                                width: _camSize.width,
                                height: _camSize.height,
                                mime: mimetype!));
                      }

                      final (s, d, stx) = relativeGs();
                      String? txt;
                      if (hasInput && input.value.isNotEmpty) {
                        final relo = sio + d;
                        final pos = Offset(0, relo.dy / s.height);
                        txt = "${pos.dy} ${input.value}";
                      }

                      vpc?.dispose();
                      widget.cameraCallBack(
                          ps: s,
                          backgroundMedia: m?..cache(),
                          pdy: so.dy,
                          text: txt,
                          sticks: stx);
                    }),
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
