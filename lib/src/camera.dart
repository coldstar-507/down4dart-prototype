import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_testproject/src/render_pages.dart';
import 'render_objects.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';
import 'down4_utility.dart';

class CameraConsole extends StatefulWidget {
  final List<CameraDescription> cameras;
  final void Function(
    String? filePath,
    bool? isVideo,
    bool? toReverse,
  ) cameraCallBack;
  final void Function() cameraBack;
  final bool enableVideo;
  const CameraConsole(
      {required this.cameras,
      required this.cameraBack,
      required this.cameraCallBack,
      this.enableVideo = true,
      Key? key})
      : super(key: key);

  @override
  _CameraConsoleState createState() => _CameraConsoleState();
}

class _CameraConsoleState extends State<CameraConsole> {
  CameraController? _cameraController;
  String? _filePath;
  Console? _console;
  int _cameraIndex = 0; // 0 = rear, 1 = front
  bool _audio = true;
  FlashMode _flashMode = FlashMode.off;
  ResolutionPreset _resolution = ResolutionPreset.low;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _setCapturingConsole();
  }

  void _nextResolution() {
    switch (_resolution) {
      case ResolutionPreset.low:
        _resolution = ResolutionPreset.medium;
        break;
      case ResolutionPreset.medium:
        _resolution = ResolutionPreset.high;
        break;
      case ResolutionPreset.high:
        _resolution = ResolutionPreset.low;
        break;
      case ResolutionPreset.veryHigh:
        break;
      case ResolutionPreset.ultraHigh:
        break;
      case ResolutionPreset.max:
        break;
    }
    _setCapturingConsole();
  }

  void _nextFlashMode() {
    if (_flashMode == FlashMode.off) {
      _flashMode = FlashMode.torch;
    } else {
      _flashMode = FlashMode.off;
    }
    _cameraController?.setFlashMode(_flashMode);
    _drawCapturingConsole();
  }

  Future<void> _initController() async {
    try {
      _cameraController = CameraController(
          widget.cameras[_cameraIndex], _resolution,
          enableAudio: _audio);
      await _cameraController?.initialize();
      await _cameraController?.setFlashMode(_flashMode);
    } catch (err) {
      widget.cameraCallBack(null, null, null);
    }
    setState(() {});
  }

  Future<void> _setCapturingConsole() async {
    await _initController();
    _drawCapturingConsole();
  }

  void _drawCapturingConsole() {
    setState(() {
      _console = Console(
        cameraPreview: CameraPreview(_cameraController!),
        aspectRatio: _cameraController?.value.aspectRatio,
        topButtons: [
          ConsoleButton(
            shouldBeDownButIsnt: _cameraController!.value.isRecordingVideo,
            name: "Capture",
            isSpecial: widget.enableVideo,
            onPress: _takePicture,
            onLongPress: widget.enableVideo ? _startRecording : null,
            onLongPressUp: widget.enableVideo ? _stopRecording : null,
          ),
          ConsoleButton(
            isMode: true,
            name: _resolution.name.capitalize(),
            onPress: _nextResolution,
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.cameraBack),
          ConsoleButton(
            isMode: true,
            name: _flashMode.name.capitalize(),
            onPress: _nextFlashMode,
          ),
          ConsoleButton(
            isMode: true,
            name: _cameraIndex == 0 ? "Rear" : "Front",
            onPress: _nextCam,
          )
        ],
      );
    });
  }

  Future<void> _setVideoPreviewConsole() async {
    _videoPlayerController = VideoPlayerController.file(File(_filePath!));
    try {
      await _videoPlayerController?.initialize();
      await _videoPlayerController?.setLooping(true);
      await _videoPlayerController?.play();
    } catch (err) {
      widget.cameraCallBack(null, null, null);
    }
    setState(() {
      _console = Console(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _cameraController?.value.aspectRatio,
        toMirror: _cameraIndex == 1,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () =>
                widget.cameraCallBack(_filePath, true, _cameraIndex == 1),
          ),
        ],
        bottomButtons: [
          ConsoleButton(
              name: "Back",
              onPress: () {
                _setCapturingConsole();
              }),
          ConsoleButton(
            name: "Cancel",
            onPress: () => widget.cameraCallBack(null, null, null),
          )
        ],
      );
    });
  }

  void _setImagePreviewConsole() {
    setState(() {
      _console = Console(
        imagePreviewPath: _filePath,
        toMirror: _cameraIndex == 1,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () =>
                widget.cameraCallBack(_filePath, false, _cameraIndex == 1),
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: _setCapturingConsole),
          ConsoleButton(
            name: "Cancel",
            onPress: () => widget.cameraCallBack(null, null, null),
          )
        ],
      );
    });
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _cameraController?.dispose();
    await _videoPlayerController?.dispose();
  }

  void _nextCam() {
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    _setCapturingConsole();
  }

  Future<void> _takePicture() async {
    try {
      final xfile = await _cameraController?.takePicture();
      final path = xfile?.path;
      _filePath = path;
    } catch (e) {
      widget.cameraCallBack(null, null, null);
    }
    _setImagePreviewConsole();
  }

  Future<void> _startRecording() async {
    try {
      await _cameraController?.startVideoRecording();
      _drawCapturingConsole();
    } catch (e) {
      widget.cameraCallBack(null, null, null);
    }
  }

  Future<void> _stopRecording() async {
    try {
      XFile? f = await _cameraController?.stopVideoRecording();
      final path = f?.path;
      _filePath = path;
    } catch (e) {
      widget.cameraCallBack(null, null, null);
    }
    _setVideoPreviewConsole();
  }

  @override
  Widget build(BuildContext context) {
    return _console ?? Container();
  }
}

class SnipCamera extends StatefulWidget {
  final CameraController ctrl;
  final double minZoom, maxZoom;
  final int camNum;
  final void Function(
    String? filePath,
    bool? isVideo,
    bool? toReverse,
  ) cameraCallBack;
  final void Function() cameraBack, nextRes, flip;
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
  String? _filePath;
  bool? _toReverse, _isVideo;
  bool extra = false;
  Widget? _preview;
  FlashMode _flashMode = FlashMode.off;
  VideoPlayerController? _videoPlayerController;
  double _scale = 1.0;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    widget.ctrl.setFlashMode(_flashMode);
  }

  void _nextFlashMode() {
    if (_flashMode == FlashMode.off) {
      _flashMode = FlashMode.torch;
    } else {
      _flashMode = FlashMode.off;
    }
    widget.ctrl.setFlashMode(_flashMode);
    setState(() {});
  }

  Future<void> _takePicture() async {
    try {
      final xfile = await widget.ctrl.takePicture();
      final path = xfile.path;
      _filePath = path;
      _toReverse = widget.ctrl.cameraId == 1;
      _isVideo = false;
    } catch (e) {
      widget.cameraCallBack(null, null, null);
    }
    imagePreview();
  }

  Future<void> _startRecording() async {
    try {
      await widget.ctrl.startVideoRecording();
    } catch (e) {
      widget.cameraCallBack(null, null, null);
    }
  }

  Future<void> _stopRecording() async {
    try {
      XFile? f = await widget.ctrl.stopVideoRecording();
      final path = f.path;
      _filePath = path;
    } catch (e) {
      widget.cameraCallBack(null, null, null);
    }
    await initVideoPlayerController();
    videoPreview();
  }

  Future<void> initVideoPlayerController() async {
    _videoPlayerController = VideoPlayerController.file(File(_filePath!));
    try {
      await _videoPlayerController?.initialize();
      await _videoPlayerController?.setLooping(true);
      await _videoPlayerController?.play();
    } catch (err) {
      widget.cameraCallBack(null, null, null);
    }
    return;
  }

  void toggleExtra() {
    setState(() {
      extra = !extra;
    });
  }

  Widget capturingPage([bool extra = false]) {
    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (widget.ctrl.value.aspectRatio * mediaSize.aspectRatio);
    return Down4StackBackground2(
      children: [
        GestureDetector(
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
          child: ClipRect(
            clipper: _MediaSizeClipper(mediaSize),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: CameraPreview(widget.ctrl),
            ),
          ),
        ),
      ],
      topButtons: [
        RealButton(
          mainButton: ConsoleButton(
            shouldBeDownButIsnt: widget.ctrl.value.isRecordingVideo,
            name: "Capture",
            isSpecial: widget.enableVideo,
            onPress: _takePicture,
            onLongPress: widget.enableVideo ? _startRecording : null,
            onLongPressUp: widget.enableVideo ? _stopRecording : null,
          ),
        ),
      ],
      bottomButtons: [
        RealButton(
          mainButton: ConsoleButton(
            name: "Back",
            onPress: () => !extra ? widget.cameraBack() : toggleExtra(),
            onLongPress: toggleExtra,
            isSpecial: true,
          ),
          extraButtons: [
            ConsoleButton(
              isMode: true,
              name: widget.ctrl.resolutionPreset.name.capitalize(),
              onPress: widget.nextRes,
            ),
            ConsoleButton(
              isMode: true,
              name: _flashMode.name.capitalize(),
              onPress: _nextFlashMode,
            ),
          ],
          showExtra: extra,
        ),
        RealButton(
          mainButton: ConsoleButton(
            isMode: true,
            name: widget.camNum == 0 ? "Rear" : "Front",
            onPress: widget.flip,
          ),
        )
      ],
    );
  }

  void videoPreview() {
    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (widget.ctrl.value.aspectRatio * mediaSize.aspectRatio);
    _preview = Down4StackBackground2(
      children: [
        ClipRect(
          clipper: _MediaSizeClipper(mediaSize),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: AspectRatio(
              aspectRatio: 1 / widget.ctrl.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            ),
          ),
        ),
      ],
      topButtons: [
        RealButton(
          mainButton: ConsoleButton(
            name: "Accept",
            onPress: () =>
                widget.cameraCallBack(_filePath, _isVideo, _toReverse),
          ),
        ),
      ],
      bottomButtons: [
        RealButton(
          mainButton: ConsoleButton(
            name: "Back",
            onPress: () async {
              _preview = null;
              await _videoPlayerController?.dispose();
              _videoPlayerController = null;
              setState(() {});
            },
          ),
        ),
        RealButton(
          mainButton: ConsoleButton(
            name: "Cancel",
            onPress: widget.cameraBack,
          ),
        )
      ],
    );
    setState(() {});
  }

  void imagePreview() {
    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (widget.ctrl.value.aspectRatio * mediaSize.aspectRatio);
    _preview = Down4StackBackground2(
      children: [
        ClipRect(
          clipper: _MediaSizeClipper(mediaSize),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: Image.file(File(_filePath!)),
          ),
        ),
      ],
      topButtons: [
        RealButton(
          mainButton: ConsoleButton(
            name: "Accept",
            onPress: () =>
                widget.cameraCallBack(_filePath, _isVideo, _toReverse),
          ),
        ),
      ],
      bottomButtons: [
        RealButton(
          mainButton: ConsoleButton(
            name: "Back",
            onPress: () => setState(() => _preview = null),
          ),
        ),
        RealButton(
          mainButton: ConsoleButton(
            name: "Cancel",
            onPress: widget.cameraBack,
          ),
        )
      ],
    );
    setState(() {});
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await widget.ctrl.dispose();
    await _videoPlayerController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _preview ?? capturingPage(extra);
  }
}

class _MediaSizeClipper extends CustomClipper<Rect> {
  final Size mediaSize;
  const _MediaSizeClipper(this.mediaSize);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, mediaSize.width, mediaSize.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}
