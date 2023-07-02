import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../data_objects/_data_utils.dart';
import '../render_objects/_render_utils.dart'
    show Down4PageWidget, InvertedSize;
import '../render_objects/console.dart';
import '../pages/_page_utils.dart';
import '../globals.dart';

class SnipCamera extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "snip";

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

class _SnipCameraState extends State<SnipCamera>
    with WidgetsBindingObserver, Pager2, Input2 {
  VideoPlayerController? vpc;
  String? filePath;
  String? mimetype;
  String? text;
  bool hasInput = false;

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
    // capturingPage();
    // widget.ctrl.setFlashMode(FlashMode.off);
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
      throw "ERROR TRYING TO RECORD VIDEO $e";
      widget.cameraBack();
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

  // Widget capturingPage([bool extra = false]) {
  //   // final cscal = 1.143;
  //   // final cal = 1 / (ctrl.value.aspectRatio * g.sizes.fullAspectRatio);
  //   // print("full = ${g.sizes.fullAspectRatio}");
  //   // print("cam = ${ctrl.value.aspectRatio}");
  //   // print("cscal = $cscal");
  //   // print("calll = $cal");
  //   // print("CAMERA IS READY? $readyCamera");
  //   return Stack(children: [
  //     !readyCamera
  //         ? Container(color: Colors.black)
  //         : GestureDetector(
  //             onTap: () => print("LALALALALAL"),
  //             onScaleStart: (details) => _baseScale = _scale,
  //             onScaleUpdate: (details) {
  //               if (_baseScale * details.scale < minZoom) {
  //                 _scale = minZoom;
  //               } else if (_baseScale * details.scale > maxZoom) {
  //                 _scale = maxZoom;
  //               } else {
  //                 _scale = _baseScale * details.scale;
  //               }
  //               if (_scale >= minZoom && _scale <= maxZoom) {
  //                 ctrl.setZoomLevel(_scale);
  //               }
  //             },
  //             child: previewsContainer(
  //               child: CameraPreview(ctrl),
  //             ),
  //           ),
  //     consoleBody(Console3(
  //             rows: [
  //           {
  //             "base": ConsoleRow(widgets: [
  //               ConsoleButton(name: "BACK", onPress: widget.cameraBack),
  //               ConsoleButton(
  //                   name: ctrl.value.flashMode.name.toUpperCase(),
  //                   onPress: _nextFlashMode,
  //                   isMode: true),
  //               ConsoleButton(
  //                   isMode: true,
  //                   name: camNum == 0 ? "REAR" : "FRONT",
  //                   onPress: flip),
  //               ConsoleButton(
  //                   shouldBeDownButIsnt: ctrl.value.isRecordingVideo,
  //                   name: "CAPTURE",
  //                   isSpecial: widget.enableVideo,
  //                   onPress: _takePicture,
  //                   onLongPress: widget.enableVideo ? _startRecording : null,
  //                   onLongPressUp: widget.enableVideo ? _stopRecording : null),
  //             ], extension: null, widths: null, inputMaxHeight: null)
  //           }
  //         ],
  //             currentConsolesName: currentConsolesName,
  //             currentPageIndex: currentPageIndex)
  //         // Console3(
  //         //
  //         //   invertedColors: true,
  //         //   topButtons: [],
  //         //   bottomButtons: [
  //         //
  //         //
  //         //
  //         //   ],
  //         //   // consoleRow: Console3(
  //         //   //   widgets: [
  //         //   //     ConsoleButton(name: "BACK", onPress: widget.cameraBack),
  //         //   //     ConsoleButton(
  //         //   //         isMode: true,
  //         //   //         name: camNum == 0 ? "REAR" : "FRONT",
  //         //   //         onPress: flip),
  //         //   //     ConsoleButton(
  //         //   //         shouldBeDownButIsnt: ctrl.value.isRecordingVideo,
  //         //   //         name: "CAPTURE",
  //         //   //         isSpecial: widget.enableVideo,
  //         //   //         onPress: _takePicture,
  //         //   //         onLongPress: widget.enableVideo ? _startRecording : null,
  //         //   //         onLongPressUp: widget.enableVideo ? _stopRecording : null),
  //         //   //   ],
  //         //   // ),
  //         // ),
  //         ),
  //   ]);
  // }

  // void videoPreview() {
  //   _preview = Stack(children: [
  //     previewsContainer(
  //       child: VideoPlayer(vpc),
  //       reverse: toReverse,
  //     ),
  //     inputBody(hasInput),
  //     consoleBody(Console3(
  //             rows: [
  //           {
  //             "base": ConsoleRow(widgets: [
  //               ConsoleButton(
  //                 name: "BACK",
  //                 onPress: () => setState(() {
  //                   File(filePath).delete();
  //                   tec.clear();
  //                   vpc.dispose();
  //                   setState(() {
  //                     _preview = null;
  //                   });
  //                 }),
  //               ),
  //               ConsoleButton(
  //                 name: "TEXT",
  //                 onPress: () => videoPreview(
  //                   vpc,
  //                   filePath,
  //                   mimetype,
  //                   toReverse,
  //                   text,
  //                   !hasInput,
  //                 ),
  //               ),
  //               ConsoleButton(
  //                 name: "ACCEPT",
  //                 onPress: () {
  //                   vpc.dispose();
  //                   widget.cameraCallBack(
  //                     path: filePath,
  //                     mimetype: mimetype,
  //                     isReversed: toReverse,
  //                     text: tec.value.text,
  //                     size: ctrl.value.previewSize!.inverted,
  //                   );
  //                 },
  //               ),
  //             ], extension: null, widths: null, inputMaxHeight: null)
  //           }
  //         ],
  //             currentConsolesName: currentConsolesName,
  //             currentPageIndex: currentPageIndex)
  //         // Console(
  //         //   invertedColors: true,
  //         //   topButtons: [],
  //         //   bottomButtons: [
  //         //     ConsoleButton(
  //         //       name: "BACK",
  //         //       onPress: () => setState(() {
  //         //         File(filePath).delete();
  //         //         tec.clear();
  //         //         vpc.dispose();
  //         //         setState(() {
  //         //           _preview = null;
  //         //         });
  //         //       }),
  //         //     ),
  //         //     ConsoleButton(
  //         //       name: "TEXT",
  //         //       onPress: () => videoPreview(
  //         //         vpc,
  //         //         filePath,
  //         //         mimetype,
  //         //         toReverse,
  //         //         text,
  //         //         !hasInput,
  //         //       ),
  //         //     ),
  //         //     ConsoleButton(
  //         //       name: "ACCEPT",
  //         //       onPress: () {
  //         //         vpc.dispose();
  //         //         widget.cameraCallBack(
  //         //           path: filePath,
  //         //           mimetype: mimetype,
  //         //           isReversed: toReverse,
  //         //           text: tec.value.text,
  //         //           size: ctrl.value.previewSize!.inverted,
  //         //         );
  //         //       },
  //         //     ),
  //         //   ],
  //         //   // consoleRow: Console3(
  //         //   //   widgets: [
  //         //   //
  //         //   //   ],
  //         //   // ),
  //         // ),
  //         ),
  //   ]);
  //   setState(() {});
  // }

  // void imagePreview() {
  //   _preview = Stack(children: [
  //     previewsContainer(reverse: toReverse, child: Image.file(File(filePath))),
  //     inputBody(hasInput),
  //     consoleBody(
  //       Console3(
  //           rows: [
  //             {
  //               "base": ConsoleRow(widgets: [
  //                 ConsoleButton(
  //                   name: "BACK",
  //                   onPress: () => setState(() {
  //                     tec.clear();
  //                     File(filePath).delete();
  //                     setState(() {
  //                       _preview = null;
  //                     });
  //                   }),
  //                 ),
  //                 ConsoleButton(
  //                   name: "TEXT",
  //                   isMode: false,
  //                   onPress: () => imagePreview(
  //                     filePath,
  //                     mimetype,
  //                     toReverse,
  //                     text,
  //                     !hasInput,
  //                   ),
  //                 ),
  //                 ConsoleButton(
  //                   name: "ACCEPT",
  //                   onPress: () => widget.cameraCallBack(
  //                       path: filePath,
  //                       mimetype: mimetype,
  //                       isReversed: toReverse,
  //                       text: tec.value.text,
  //                       size: ctrl.value.previewSize!.inverted),
  //                 ),
  //               ], extension: null, widths: null, inputMaxHeight: null)
  //             }
  //           ],
  //           currentConsolesName: currentConsolesName,
  //           currentPageIndex: currentPageIndex),
  //     )
  //     // Console(
  //     //   invertedColors: true,
  //     //   topButtons: [],
  //     //   // consoleRow: Console3(
  //     //   //   widgets: [
  //     //   //
  //     //   //   ],
  //     //   // ),
  //     //   bottomButtons: [
  //     //     ConsoleButton(
  //     //       name: "BACK",
  //     //       onPress: () => setState(() {
  //     //         tec.clear();
  //     //         File(filePath).delete();
  //     //         setState(() {
  //     //           _preview = null;
  //     //         });
  //     //       }),
  //     //     ),
  //     //     ConsoleButton(
  //     //       name: "TEXT",
  //     //       isMode: false,
  //     //       onPress: () => imagePreview(
  //     //         filePath,
  //     //         mimetype,
  //     //         toReverse,
  //     //         text,
  //     //         !hasInput,
  //     //       ),
  //     //     ),
  //     //     ConsoleButton(
  //     //       name: "ACCEPT",
  //     //       onPress: () => widget.cameraCallBack(
  //     //           path: filePath,
  //     //           mimetype: mimetype,
  //     //           isReversed: toReverse,
  //     //           text: tec.value.text,
  //     //           size: ctrl.value.previewSize!.inverted),
  //     //     ),
  //     //   ],
  //     // )),
  //   ]);
  //   setState(() {});
  // }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        hasPreview
            ? previewsContainer(
                reverse: toReverse,
                child:
                    isVideo ? VideoPlayer(vpc!) : Image.file(File(filePath!)))
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
                    child: previewsContainer(
                      child: CameraPreview(ctrl),
                    ),
                  ),
        hasInput ? input.snipInput : const SizedBox.shrink(),
        consoleBody(console),
      ],
    );

    // return _preview ?? capturingPage();
  }

  @override
  List<Extra> extras = [];

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(widgets: [
                ConsoleButton(
                    name: "BACK", onPress: widget.cameraBack, isInverted: true),
                ConsoleButton(
                    name: ctrl.value.flashMode.name.toUpperCase(),
                    onPress: _nextFlashMode,
                    isInverted: true,
                    isMode: true),
                ConsoleButton(
                    isMode: true,
                    name: camNum == 0 ? "REAR" : "FRONT",
                    isInverted: true,
                    onPress: flip),
                ConsoleButton(
                    shouldBeDownButIsnt: ctrl.value.isRecordingVideo,
                    name: "CAPTURE",
                    isSpecial: widget.enableVideo,
                    onPress: _takePicture,
                    isInverted: true,
                    onLongPress: widget.enableVideo ? _startRecording : null,
                    onLongPressUp: widget.enableVideo ? _stopRecording : null),
              ], extension: null, widths: null, inputMaxHeight: null),
              "preview": ConsoleRow(widgets: [
                ConsoleButton(
                  name: "BACK",
                  isInverted: true,
                  onPress: () => setState(() {
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
                ConsoleButton(
                  name: "TEXT",
                  isInverted: true,
                  isMode: hasInput,
                  onPress: () => setState(() => hasInput = !hasInput),
                ),
                ConsoleButton(
                  name: "SEND",
                  isInverted: true,
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
              ], extension: null, widths: null, inputMaxHeight: null)
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  List<String> currentConsolesName = ["base"];

  @override
  void setTheState() {
    setState(() {});
  }
}
