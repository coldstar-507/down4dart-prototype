import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'render_objects.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';
import 'down4_utility.dart';

class CameraConsole extends StatefulWidget {
  final List<CameraDescription> cameras;
  final void Function(String?, bool?) cameraCallBack;
  final void Function() cameraBack;
  const CameraConsole(
      {required this.cameras,
      required this.cameraBack,
      required this.cameraCallBack,
      Key? key})
      : super(key: key);

  @override
  _CameraConsoleState createState() => _CameraConsoleState();
}

class _CameraConsoleState extends State<CameraConsole> {
  CameraController? _cameraController;
  String? _filePath;
  Console? _console;
  int _currentCameraIndex = 0;
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
    print('''
===============================================================================

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                  FlashMode=${_flashMode.name}

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

================================================================================
''');
  }

  Future<void> _initController() async {
    try {
      _cameraController = CameraController(
          widget.cameras[_currentCameraIndex], _resolution,
          enableAudio: _audio);
      await _cameraController?.initialize();
      await _cameraController?.setFlashMode(_flashMode);
    } catch (err) {
      widget.cameraCallBack(null, null);
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
              onPress: _takePicture,
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording),
          ConsoleButton(
              isMode: true,
              name: _resolution.name.capitalize(),
              onPress: _nextResolution)
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: widget.cameraBack),
          ConsoleButton(
              isMode: true,
              name: _flashMode.name.capitalize(),
              onPress: _nextFlashMode),
          ConsoleButton(
              isMode: true,
              name: _currentCameraIndex == 0 ? "Rear" : "Front",
              onPress: _nextCam)
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
      widget.cameraCallBack(null, null);
    }
    setState(() {
      _console = Console(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _cameraController?.value.aspectRatio,
        toMirror: _currentCameraIndex == 1,
        topButtons: [
          ConsoleButton(
              name: "Accept",
              onPress: () {
                widget.cameraCallBack(_filePath, true);
              }),
        ],
        bottomButtons: [
          ConsoleButton(
              name: "Back",
              onPress: () {
                _setCapturingConsole();
              }),
          ConsoleButton(
              name: "Cancel", onPress: () => widget.cameraCallBack(null, null))
        ],
      );
    });
  }

  void _setImagePreviewConsole() {
    setState(() {
      _console = Console(
        imagePreviewPath: _filePath,
        toMirror: _currentCameraIndex == 1,
        topButtons: [
          ConsoleButton(
              name: "Accept",
              onPress: () => widget.cameraCallBack(_filePath, false))
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: _setCapturingConsole),
          ConsoleButton(
              name: "Cancel", onPress: () => widget.cameraCallBack(null, null))
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
    _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;
    _setCapturingConsole();
  }

  Future<void> _takePicture() async {
    try {
      final xfile = await _cameraController?.takePicture();
      final path = xfile?.path;
      final bytes = await xfile?.readAsBytes();
      print("""
      --

        file path = $path
        file size = ${bytes?.length}

      --
      """);
      _filePath = path;
    } catch (e) {
      widget.cameraCallBack(null, null);
    }
    _setImagePreviewConsole();
  }

  Future<void> _startRecording() async {
    try {
      await _cameraController?.startVideoRecording();
      _drawCapturingConsole();
    } catch (e) {
      widget.cameraCallBack(null, null);
    }
  }

  Future<void> _stopRecording() async {
    try {
      XFile? f = await _cameraController?.stopVideoRecording();
      final path = f?.path;
      final bytes = await f?.readAsBytes();
      print('''
===============================================================================

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                  Size of video=${bytes?.length}
                  Path of video=$path

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

================================================================================
''');
      _filePath = path;
    } catch (e) {
      widget.cameraCallBack(null, null);
    }
    _setVideoPreviewConsole();
  }

  @override
  Widget build(BuildContext context) {
    return _console ?? Container();
  }
}
