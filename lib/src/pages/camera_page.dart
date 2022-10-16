import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';

import '../down4_utility.dart';
import '../render_objects/console.dart';

// class CameraConsole extends StatefulWidget {
//   final List<CameraDescription> cameras;
//   final void Function(
//     String? filePath,
//     bool? isVideo,
//     bool? toReverse,
//   ) cameraCallBack;
//   final void Function() cameraBack;
//   final bool enableVideo;
//   const CameraConsole(
//       {required this.cameras,
//       required this.cameraBack,
//       required this.cameraCallBack,
//       this.enableVideo = true,
//       Key? key})
//       : super(key: key);
//
//   @override
//   _CameraConsoleState createState() => _CameraConsoleState();
// }
//
// class _CameraConsoleState extends State<CameraConsole> {
//   CameraController? _cameraController;
//   String? _filePath;
//   Console? _console;
//   int _cameraIndex = 0; // 0 = rear, 1 = front
//   bool _audio = true;
//   FlashMode _flashMode = FlashMode.off;
//   ResolutionPreset _resolution = ResolutionPreset.low;
//   VideoPlayerController? _videoPlayerController;
//
//   @override
//   void initState() {
//     super.initState();
//     _setCapturingConsole();
//   }
//
//   void _nextResolution() {
//     switch (_resolution) {
//       case ResolutionPreset.low:
//         _resolution = ResolutionPreset.medium;
//         break;
//       case ResolutionPreset.medium:
//         _resolution = ResolutionPreset.high;
//         break;
//       case ResolutionPreset.high:
//         _resolution = ResolutionPreset.low;
//         break;
//       case ResolutionPreset.veryHigh:
//         break;
//       case ResolutionPreset.ultraHigh:
//         break;
//       case ResolutionPreset.max:
//         break;
//     }
//     _setCapturingConsole();
//   }
//
//   void _nextFlashMode() {
//     if (_flashMode == FlashMode.off) {
//       _flashMode = FlashMode.torch;
//     } else {
//       _flashMode = FlashMode.off;
//     }
//     _cameraController?.setFlashMode(_flashMode);
//     _drawCapturingConsole();
//   }
//
//   Future<void> _initController() async {
//     try {
//       _cameraController = CameraController(
//           widget.cameras[_cameraIndex], _resolution,
//           enableAudio: _audio);
//       await _cameraController?.initialize();
//       await _cameraController?.setFlashMode(_flashMode);
//     } catch (err) {
//       widget.cameraCallBack(null, null, null);
//     }
//     setState(() {});
//   }
//
//   Future<void> _setCapturingConsole() async {
//     await _initController();
//     _drawCapturingConsole();
//   }
//
//   void _drawCapturingConsole() {
//     setState(() {
//       _console = Console(
//         cameraController: _cameraController!,
//         aspectRatio: _cameraController?.value.aspectRatio,
//         topButtons: [
//           ConsoleButton(
//             shouldBeDownButIsnt: _cameraController!.value.isRecordingVideo,
//             name: "Capture",
//             isSpecial: widget.enableVideo,
//             onPress: _takePicture,
//             onLongPress: widget.enableVideo ? _startRecording : null,
//             onLongPressUp: widget.enableVideo ? _stopRecording : null,
//           ),
//           ConsoleButton(
//             isMode: true,
//             name: _resolution.name.capitalize(),
//             onPress: _nextResolution,
//           ),
//         ],
//         bottomButtons: [
//           ConsoleButton(name: "Back", onPress: widget.cameraBack),
//           ConsoleButton(
//             isMode: true,
//             name: _flashMode.name.capitalize(),
//             onPress: _nextFlashMode,
//           ),
//           ConsoleButton(
//             isMode: true,
//             name: _cameraIndex == 0 ? "Rear" : "Front",
//             onPress: _nextCam,
//           )
//         ],
//       );
//     });
//   }
//
//   Future<void> _setVideoPreviewConsole() async {
//     _videoPlayerController = VideoPlayerController.file(File(_filePath!));
//     try {
//       await _videoPlayerController?.initialize();
//       await _videoPlayerController?.setLooping(true);
//       await _videoPlayerController?.play();
//     } catch (err) {
//       widget.cameraCallBack(null, null, null);
//     }
//     setState(() {
//       _console = Console(
//         videoPlayerController: _videoPlayerController,
//         aspectRatio: _cameraController?.value.aspectRatio,
//         toMirror: _cameraIndex == 1,
//         topButtons: [
//           ConsoleButton(
//             name: "Accept",
//             onPress: () =>
//                 widget.cameraCallBack(_filePath, true, _cameraIndex == 1),
//           ),
//         ],
//         bottomButtons: [
//           ConsoleButton(
//               name: "Back",
//               onPress: () {
//                 _setCapturingConsole();
//               }),
//           ConsoleButton(
//             name: "Cancel",
//             onPress: () => widget.cameraCallBack(null, null, null),
//           )
//         ],
//       );
//     });
//   }
//
//   void _setImagePreviewConsole() {
//     setState(() {
//       _console = Console(
//         imagePreviewPath: _filePath,
//         toMirror: _cameraIndex == 1,
//         topButtons: [
//           ConsoleButton(
//             name: "Accept",
//             onPress: () =>
//                 widget.cameraCallBack(_filePath, false, _cameraIndex == 1),
//           ),
//         ],
//         bottomButtons: [
//           ConsoleButton(name: "Back", onPress: _setCapturingConsole),
//           ConsoleButton(
//             name: "Cancel",
//             onPress: () => widget.cameraCallBack(null, null, null),
//           )
//         ],
//       );
//     });
//   }
//
//   @override
//   Future<void> dispose() async {
//     super.dispose();
//     await _cameraController?.dispose();
//     await _videoPlayerController?.dispose();
//   }
//
//   void _nextCam() {
//     _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
//     _setCapturingConsole();
//   }
//
//   Future<void> _takePicture() async {
//     try {
//       final xfile = await _cameraController?.takePicture();
//       final path = xfile?.path;
//       _filePath = path;
//     } catch (e) {
//       widget.cameraCallBack(null, null, null);
//     }
//     _setImagePreviewConsole();
//   }
//
//   Future<void> _startRecording() async {
//     try {
//       await _cameraController?.startVideoRecording();
//       _drawCapturingConsole();
//     } catch (e) {
//       widget.cameraCallBack(null, null, null);
//     }
//   }
//
//   Future<void> _stopRecording() async {
//     try {
//       XFile? f = await _cameraController?.stopVideoRecording();
//       final path = f?.path;
//       _filePath = path;
//     } catch (e) {
//       widget.cameraCallBack(null, null, null);
//     }
//     _setVideoPreviewConsole();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return _console ?? Container();
//   }
// }

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

  @override
  void initState() {
    super.initState();
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

  Widget capturingPage([bool extra = false]) {
    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (widget.ctrl.value.aspectRatio * mediaSize.aspectRatio);
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
        child: SizedBox(
          height: mediaSize.height,
          width: mediaSize.width,
          child: Transform.scale(
            scaleX: scale,
            alignment: Alignment.center,
            child: CameraPreview(widget.ctrl),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          width: mediaSize.width,
          child: Console(
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
              ConsoleButton(
                name: "Back",
                onPress: () =>
                !extra ? widget.cameraBack() : capturingPage(!extra),
                onLongPress: () => capturingPage(!extra),
                isSpecial: true,
                showExtra: extra,
                extraButtons: [
                  ConsoleButton(
                    isMode: true,
                    name: widget.ctrl.resolutionPreset.name.capitalize(),
                    onPress: widget.nextRes,
                  ),
                  ConsoleButton(
                    isMode: true,
                    name: widget.ctrl.value.flashMode.name.capitalize(),
                    onPress: _nextFlashMode,
                  ),
                ],
              ),
              ConsoleButton(
                isMode: true,
                name: widget.camNum == 0 ? "Rear" : "Front",
                onPress: widget.flip,
              ),
            ],
          ),
        ),
      ),
    ]);
    // return Jeff(
    //   index: 0,
    //   titles: ["TODO"],
    //   bodies: [
    //     PageBody(
    //       stackWidgets: [
    //         GestureDetector(
    //           onTap: () => print("LALALALALAL"),
    //           onScaleStart: (details) => _baseScale = _scale,
    //           onScaleUpdate: (details) {
    //             if (_baseScale * details.scale < widget.minZoom) {
    //               _scale = widget.minZoom;
    //             } else if (_baseScale * details.scale > widget.maxZoom) {
    //               _scale = widget.maxZoom;
    //             } else {
    //               _scale = _baseScale * details.scale;
    //             }
    //             if (_scale >= widget.minZoom && _scale <= widget.maxZoom) {
    //               widget.ctrl.setZoomLevel(_scale);
    //             }
    //           },
    //           child: SizedBox(
    //             height: mediaSize.height,
    //             width: mediaSize.width,
    //             child: Transform.scale(
    //               scaleX: scale,
    //               alignment: Alignment.center,
    //               child: CameraPreview(widget.ctrl),
    //             ),
    //           ),
    //         ),
    //       ],
    //     ),
    //   ],
    //   consoles: [
    //     PageConsole(
    //       console: Console(
    //         topButtons: [
    //           ConsoleButton(
    //             shouldBeDownButIsnt: widget.ctrl.value.isRecordingVideo,
    //             name: "Capture",
    //             isSpecial: widget.enableVideo,
    //             onPress: _takePicture,
    //             onLongPress: widget.enableVideo ? _startRecording : null,
    //             onLongPressUp: widget.enableVideo ? _stopRecording : null,
    //           ),
    //         ],
    //         bottomButtons: [
    //           ConsoleButton(
    //             name: "Back",
    //             onPress: () =>
    //                 !extra ? widget.cameraBack() : capturingPage(!extra),
    //             onLongPress: () => capturingPage(!extra),
    //             isSpecial: true,
    //             extraButtons: [
    //               ConsoleButton(
    //                 isMode: true,
    //                 name: widget.ctrl.resolutionPreset.name.capitalize(),
    //                 onPress: widget.nextRes,
    //               ),
    //               ConsoleButton(
    //                 isMode: true,
    //                 name: widget.ctrl.value.flashMode.name.capitalize(),
    //                 onPress: _nextFlashMode,
    //               ),
    //             ],
    //             showExtra: extra,
    //           ),
    //           ConsoleButton(
    //             isMode: true,
    //             name: widget.camNum == 0 ? "Rear" : "Front",
    //             onPress: widget.flip,
    //           ),
    //         ],
    //       ),
    //     ),
    //   ],
    // );
  }

  void videoPreview(
      VideoPlayerController vpc,
      String filePath,
      bool isVideo,
      bool toReverse, [
        String? text,
        bool input = false,
      ]) {
    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (widget.ctrl.value.aspectRatio * mediaSize.aspectRatio);
    _preview = Stack(children: [
      SizedBox(
        height: mediaSize.height,
        width: mediaSize.width,
        child: Transform.scale(
          scaleX: scale,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(toReverse ? math.pi : 0),
            child: VideoPlayer(vpc),
          ),
        ),
      ),
      input
          ? Center(
        child: Container(
          width: mediaSize.width,
          decoration: const BoxDecoration(
            // border: Border.symmetric(
            //   horizontal: BorderSide(color: Colors.black38),
            // ),
            color: Colors.black38,
            // color: PinkTheme.snipRibbon,
          ),
          constraints: BoxConstraints(
            minHeight: 16,
            maxHeight: mediaSize.height,
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
          : const SizedBox.shrink(),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          width: mediaSize.width,
          // height: mediaSize.height,
          child: Console(
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
                onPress: () {
                  _preview = null;
                  vpc.dispose();
                  setState(() {});
                },
              ),
              ConsoleButton(
                name: "Text",
                onPress: () => videoPreview(
                  vpc,
                  filePath,
                  isVideo,
                  toReverse,
                  text,
                  !input,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);

    // _preview = Jeff(
    //   index: 0,
    //   titles: ["TODO"],
    //   bodies: [
    //     PageBody(
    //       stackWidgets: [
    //         SizedBox(
    //           height: mediaSize.height,
    //           width: mediaSize.width,
    //           child: Transform.scale(
    //             scaleX: scale,
    //             child: Transform(
    //               alignment: Alignment.center,
    //               transform: Matrix4.rotationY(toReverse ? math.pi : 0),
    //               child: VideoPlayer(vpc),
    //             ),
    //           ),
    //         ),
    //         input
    //             ? Center(
    //                 child: Container(
    //                   width: mediaSize.width,
    //                   decoration: const BoxDecoration(
    //                     // border: Border.symmetric(
    //                     //   horizontal: BorderSide(color: Colors.black38),
    //                     // ),
    //                     color: Colors.black38,
    //                     // color: PinkTheme.snipRibbon,
    //                   ),
    //                   constraints: BoxConstraints(
    //                     minHeight: 16,
    //                     maxHeight: mediaSize.height,
    //                   ),
    //                   child: TextField(
    //                     autofocus: input,
    //                     textInputAction: TextInputAction.done,
    //                     cursorColor: Colors.white,
    //                     controller: tec,
    //                     textAlign: TextAlign.center,
    //                     decoration: const InputDecoration(
    //                       border: InputBorder.none,
    //                       isDense: true,
    //                       isCollapsed: true,
    //                     ),
    //                     maxLines: 15,
    //                     minLines: 1,
    //                     style: const TextStyle(color: Colors.white),
    //                     // style: const TextStyle(color: PinkTheme.black),
    //                   ),
    //                 ),
    //               )
    //             : const SizedBox.shrink(),
    //       ],
    //     ),
    //   ],
    //   consoles: [
    //     PageConsole(
    //       console: Console(
    //         topButtons: [
    //           ConsoleButton(
    //             name: "Accept",
    //             onPress: () async {
    //               await vpc.dispose();
    //               widget.cameraCallBack(
    //                 filePath,
    //                 isVideo,
    //                 toReverse,
    //                 tec.value.text,
    //                 widget.ctrl.value.aspectRatio,
    //               );
    //             },
    //           ),
    //         ],
    //         bottomButtons: [
    //           ConsoleButton(
    //             name: "Back",
    //             onPress: () {
    //               _preview = null;
    //               vpc.dispose();
    //               setState(() {});
    //             },
    //           ),
    //           ConsoleButton(
    //             name: "Text",
    //             onPress: () => videoPreview(
    //               vpc,
    //               filePath,
    //               isVideo,
    //               toReverse,
    //               text,
    //               !input,
    //             ),
    //           ),
    //         ],
    //       ),
    //     ),
    //   ],
    // );
    setState(() {});
  }

  void imagePreview(
      String filePath,
      bool isVideo,
      bool toReverse, [
        String? text,
        bool input = false,
      ]) {
    final mediaSize = MediaQuery.of(context).size;
    final scale = 1 / (widget.ctrl.value.aspectRatio * mediaSize.aspectRatio);
    _preview = Stack(children: [
      SizedBox(
        height: mediaSize.height,
        width: mediaSize.width,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(toReverse ? math.pi : 0),
          child: Image.file(File(filePath), fit: BoxFit.cover),
        ),
      ),
      input
          ? Center(
        child: Container(
          width: mediaSize.width,
          decoration: const BoxDecoration(
            color: Colors.black38,
            // color: PinkTheme.snipRibbon,
          ),
          constraints: BoxConstraints(
            minHeight: 16,
            maxHeight: mediaSize.height,
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
          ),
        ),
      )
          : const SizedBox.shrink(),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          // height: mediaSize.height,
            width: mediaSize.width,
            child: Console(
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
                  onPress: () => setState(() => _preview = null),
                ),
                ConsoleButton(
                  name: "Text",
                  isMode: false,
                  onPress: () => imagePreview(
                    filePath,
                    isVideo,
                    toReverse,
                    text,
                    !input,
                  ),
                ),
              ],
            )),
      ),
    ]);

    // _preview = Jeff(
    //   index: 0,
    //   titles: ["TODO"],
    //   bodies: [
    //     PageBody(
    //       stackWidgets: [
    //         SizedBox(
    //           height: mediaSize.height,
    //           width: mediaSize.width,
    //           child: Transform(
    //             alignment: Alignment.center,
    //             transform: Matrix4.rotationY(toReverse ? math.pi : 0),
    //             child: Image.file(File(filePath), fit: BoxFit.cover),
    //           ),
    //         ),
    //         input
    //             ? Center(
    //                 child: Container(
    //                   width: mediaSize.width,
    //                   decoration: const BoxDecoration(
    //                     color: Colors.black38,
    //                     // color: PinkTheme.snipRibbon,
    //                   ),
    //                   constraints: BoxConstraints(
    //                     minHeight: 16,
    //                     maxHeight: mediaSize.height,
    //                   ),
    //                   child: TextField(
    //                     autofocus: input,
    //                     textInputAction: TextInputAction.done,
    //                     cursorColor: Colors.white,
    //                     controller: tec,
    //                     textAlign: TextAlign.center,
    //                     decoration: const InputDecoration(
    //                       border: InputBorder.none,
    //                       isDense: true,
    //                       isCollapsed: true,
    //                     ),
    //                     maxLines: 15,
    //                     minLines: 1,
    //                     style: const TextStyle(color: Colors.white),
    //                   ),
    //                 ),
    //               )
    //             : const SizedBox.shrink(),
    //       ],
    //     )
    //   ],
    //   consoles: [
    //     PageConsole(
    //       console: Console(
    //         topButtons: [
    //           ConsoleButton(
    //             name: "Accept",
    //             onPress: () => widget.cameraCallBack(
    //               filePath,
    //               isVideo,
    //               toReverse,
    //               tec.value.text,
    //               widget.ctrl.value.aspectRatio,
    //             ),
    //           ),
    //         ],
    //         bottomButtons: [
    //           ConsoleButton(
    //             name: "Back",
    //             onPress: () => setState(() => _preview = null),
    //           ),
    //           ConsoleButton(
    //             name: "Text",
    //             isMode: false,
    //             onPress: () => imagePreview(
    //               filePath,
    //               isVideo,
    //               toReverse,
    //               text,
    //               !input,
    //             ),
    //           ),
    //         ],
    //       ),
    //     ),
    //   ],
    // );

    setState(() {});
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await widget.ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _preview ?? capturingPage();
  }
}
