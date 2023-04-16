import 'dart:io';

// import 'package:better_player/better_player.dart';
import 'package:camera/camera.dart';
import 'package:down4/main.dart';
import 'package:down4/src/couch.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';

import '../_dart_utils.dart';
import '../data_objects.dart';
import '../globals.dart';
import '../render_objects/_render_utils.dart';
import '../render_objects/console.dart';

mixin Pager {
  ID get selfID;
  ConsoleInput get mainInput;
  Console get console;
  set console(Console c);
  void setTheState();
  void loadBaseConsole();
}

mixin Backable {
  void back();
}

mixin Camera on Pager {
  FireMedia? get cameraInput;
  set cameraInput(FireMedia? m);
  Size get _squaredCamSize => Size.square(Console.trueWidth);
  VideoPlayerController? videoPreview;
  CameraController? cameraController;

  Future<void> loadSquaredCameraConsole([int cam = 0]) async {
    if (cameraController == null) {
      try {
        cameraController =
            CameraController(g.cameras[cam], ResolutionPreset.high);
        await cameraController?.initialize();
      } catch (e) {
        loadBaseConsole();
      }
    }

    final bool isReversed = cam == 1;
    console = Console(
      bottomInputs: [mainInput],
      cameraController: cameraController,
      topButtons: [
        ConsoleButton(
          name: "Capture",
          isSpecial: true,
          shouldBeDownButIsnt: cameraController!.value.isRecordingVideo,
          onPress: () async {
            final XFile f = await cameraController!.takePicture();
            print(
                "CAMERA PREVIEW SIZE = ${cameraController?.value.previewSize}");
            final media = makeCameraMedia(
                cachedPath: f.path,
                size: cameraController!.value.previewSize!.inverted,
                isReversed: isReversed,
                owner: selfID,
                isSquared: true);
            loadPreviewConsole(media);
          },
          onLongPress: () async {
            await cameraController!.startVideoRecording();
            loadSquaredCameraConsole(cam);
          },
          onLongPressUp: () async {
            final XFile f = await cameraController!.stopVideoRecording();
            final media = makeCameraMedia(
                cachedPath: f.path,
                size: cameraController!.value.previewSize!.inverted,
                isReversed: isReversed,
                owner: selfID,
                isSquared: true);
            loadPreviewConsole(media);
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () {
              cameraController?.dispose();
              cameraController = null;
              loadBaseConsole();
            }),
        ConsoleButton(
            name: cam == 0 ? "Rear" : "Front",
            onPress: () async {
              await cameraController?.dispose();
              cameraController = null;
              loadSquaredCameraConsole((cam + 1) % 2);
            },
            isMode: true),
      ],
    );

    setTheState();
  }

  Future<VideoPlayerController?> _loopingController(FireMedia m) async {
    if (!m.isVideo) return null;
    final vpc = await m.videoController;
    await vpc?.initialize();
    return vpc
      ?..setLooping(true)
      ..play();
  }

  void loadPreviewConsole(FireMedia m) async {
    // videoPreview = await _loopingController(m);
    if (m.isVideo) {
      final file = await m.cachedFile;
      videoPreview = VideoPlayerController.file(file!);
      await videoPreview?.initialize();
      videoPreview?.setLooping(true);
      videoPreview?.play();
    }

    Widget videoPlayer() {
      return Down4VideoTransform(
          displaySize: _squaredCamSize,
          videoAspectRatio: m.aspectRatio,
          video: VideoPlayer(videoPreview!),
          isReversed: m.isReversed,
          isSquared: true);
    }

    console = Console(
      bottomInputs: [mainInput],
      previewMedia: m.isVideo
          ? videoPlayer()
          : m.displayImage(
              size: _squaredCamSize,
              forceSquare: true,
            ), //, controller: vpc),
      topButtons: [
        ConsoleButton(
            name: "Accept",
            onPress: () {
              // vpc?.dispose();
              cameraController?.dispose();
              cameraController = null;
              videoPreview?.dispose();
              cameraInput = m;
              loadBaseConsole();
            }),
      ],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () {
            // vpc?.dispose();
            videoPreview?.dispose();
            loadSquaredCameraConsole(m.isReversed ? 1 : 0);
          },
        ),
        ConsoleButton(
            name: "Cancel",
            onPress: () {
              cameraController?.dispose();
              cameraController = null;
              videoPreview?.dispose();
              loadBaseConsole();
            }),
      ],
    );
    setTheState();
  }
}

mixin Medias on Pager {
  List<Pair<String, void Function(FireMedia)>> get mediasMode;
  int currentMode = 0;

  Pair<String, void Function(FireMedia)> get curMode => mediasMode[currentMode];

  void loadMediasConsole([
    bool images = true,
    bool extra = false,
    void Function(FireMedia)? forNode,
  ]) {
    console = Console(
      bottomInputs: [mainInput],
      consoleMedias2: ConsoleMedias2(
        images: images,
        onSelect: forNode ?? curMode.second,
      ),
      topButtons: [
        ConsoleButton(
            name: "Import",
            onPress: () async {
              if (forNode != null) {
                final nodeMedia = await importNodeMedia();
                if (nodeMedia != null) {
                  forNode.call(nodeMedia);
                }
              } else {
                await importConsoleMedias(images: images);
                loadMediasConsole(images, extra, forNode);
              }
            }),
      ],
      bottomButtons: [
        ConsoleButton(
          showExtra: extra,
          isSpecial: forNode == null ? true : false,
          name: "Back",
          onPress: () => extra && forNode == null
              ? loadMediasConsole(images, !extra, forNode)
              : loadBaseConsole(),
          onLongPress: () => forNode == null
              ? loadMediasConsole(images, !extra, forNode)
              : null,
          extraButtons: [
            ConsoleButton(
              name: curMode.first,
              onPress: () {
                currentMode = (currentMode + 1) % mediasMode.length;
                loadMediasConsole(images, extra, forNode);
              },
              isMode: true,
            ),
          ],
        ),
        ConsoleButton(
          isMode: true,
          isActivated: forNode == null,
          isGreyedOut: forNode != null,
          name: images ? "Images" : "Videos",
          onPress: () => loadMediasConsole(!images, extra, forNode),
        ),
      ],
    );

    setTheState();
  }
}

mixin Sender {
  Future<void> send({FireMedia? mediaInput});
}

mixin Forwarder on Backable, Sender, Camera, Medias {
  List<Down4Object>? get fo;
  void Function()? get hyper => null;
  // set cameraInput(FireMedia? m);
  // FireMedia? get cameraInput;
  // ConsoleInput get input;
  // Console get console;
  // set console(Console c);

  // void loadBaseConsole();

  // Future<void> loadSquaredCameraConsole([
  //   CameraController? ctrl,
  //   int cam = 0,
  // ]) async {
  //   if (ctrl == null) {
  //     try {
  //       ctrl = CameraController(g.cameras[cam], ResolutionPreset.high);
  //       await ctrl.initialize();
  //     } catch (e) {
  //       loadBaseConsole();
  //     }
  //   }
  //   console = squaredCapturingConsole(
  //     cam: cam,
  //     uselessInput: input,
  //     goToPreview: (p, ar, ir) {
  //       ctrl?.dispose();
  //       loadPreviewConsole(p, ar, ir);
  //     },
  //     back: () {
  //       ctrl?.dispose();
  //       loadBaseConsole();
  //     },
  //     onVideoStarted: () => loadSquaredCameraConsole(ctrl, cam),
  //     nextCam: () => loadSquaredCameraConsole(null, (cam + 1) % 2),
  //     ctrl: ctrl!,
  //   );
  //   setTheState();
  // }
  //
  // void loadPreviewConsole(String p, double ar, bool ir) {
  //   console = squaredPreviewConsole(
  //     uselessInput: input,
  //     path: p,
  //     aspectRatio: ar,
  //     isReversed: ir,
  //     back: () => loadSquaredCameraConsole(null, ir ? 1 : 0),
  //     cancel: loadBaseConsole,
  //     accept: () {
  //       cameraInput = makeCameraMedia(p, ar, ir);
  //       loadBaseConsole();
  //     },
  //   );
  //   setTheState();
  // }

  // void loadMediasConsole([
  //   bool images = true,
  //   String mode = "Send",
  //   bool extra = false,
  // ]) {
  //   void selectMedia(FireMedia media) {
  //     if (mode == "Send") {
  //       send(mediaInput: media);
  //       return;
  //     } else if (mode == "Remove") {
  //       media.updateSaveStatus(false);
  //     }
  //     loadMediasConsole(images, mode, extra);
  //   }
  //
  //   console = mediaConsole(
  //       uselessInput: mainInput,
  //       selectMedia: selectMedia,
  //       afterImport: () => loadMediasConsole(images, mode, extra),
  //       back: loadBaseConsole,
  //       switchMediasType: () => loadMediasConsole(!images, mode, extra),
  //       switchMediaMode: () => mode == "Send"
  //           ? loadMediasConsole(images, "Remove", true)
  //           : loadMediasConsole(images, "Send", true),
  //       switchExtra: () => loadMediasConsole(images, mode, !extra),
  //       extra: extra,
  //       images: images,
  //       importGroupMedia: null,
  //       mode: mode);
  //
  //   setTheState();
  // }

  List<String> get forwardingConsoles => [
        "ForwardingConsole",
        "ForwardingMediasConsole",
        "ForwardingCameraConsole",
        "ForwardingPreviewConsole",
      ];

  void loadForwardingConsole([bool extra = false]) {
    console = Console(
      name: "ForwardingConsole",
      bottomInputs: [mainInput],
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: back),
        ConsoleButton(name: "Medias", onPress: loadForwardingMediasConsole),
        ConsoleButton(
          name: "Forward",
          onPress: () => extra ? loadForwardingConsole(!extra) : send(),
          onLongPress: () => loadForwardingConsole(!extra),
          isSpecial: true,
          showExtra: extra,
          extraButtons: [
            ConsoleButton(
              name: cameraInput == null ? "Camera" : "@Camera",
              onPress: loadForwardingCameraConsole,
            ),
            ...(hyper != null
                ? [ConsoleButton(name: "Hyper", onPress: hyper!)]
                : [])
          ],
        )
      ],
    );

    setTheState();
  }

  void loadForwardingMediasConsole([bool images = true]) {
    console = Console(
      name: "ForwardingMediasConsole",
      bottomInputs: [mainInput],
      consoleMedias2: ConsoleMedias2(
        images: images,
        onSelect: (m) => send(mediaInput: m),
      ),
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadForwardingConsole),
        ConsoleButton(
            name: images ? "Images" : "Videos",
            onPress: () => loadForwardingMediasConsole(!images))
      ],
    );
    setTheState();
  }

  Future<void> loadForwardingCameraConsole([
    CameraController? ctrl,
    int cam = 0,
  ]) async {
    if (ctrl == null) {
      try {
        ctrl = CameraController(g.cameras[cam], ResolutionPreset.high);
        await ctrl.initialize();
      } catch (e) {
        loadBaseConsole();
      }
    }

    final double aspectRatio = ctrl!.value.aspectRatio;
    final bool isReversed = cam == 1;
    console = Console(
      name: "ForwardingCameraConsole",
      bottomInputs: [mainInput],
      cameraController: ctrl,
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
            name: cam == 0 ? "Rear" : "Front",
            onPress: () => loadForwardingCameraConsole(null, (cam + 1) % 2),
            isMode: true),
        ConsoleButton(
          name: "Capture",
          isSpecial: true,
          shouldBeDownButIsnt: ctrl.value.isRecordingVideo,
          onPress: () async {
            final XFile f = await ctrl!.takePicture();
            final media = makeCameraMedia(
                cachedPath: f.path,
                size: ctrl.value.previewSize!,
                isReversed: isReversed,
                owner: selfID,
                isSquared: true);
            loadForwardingPreviewConsole(media);
          },
          onLongPress: () async {
            await ctrl!.startVideoRecording();
            loadForwardingCameraConsole(ctrl, cam);
          },
          onLongPressUp: () async {
            final XFile f = await ctrl!.stopVideoRecording();
            final media = makeCameraMedia(
                cachedPath: f.path,
                size: ctrl.value.previewSize!,
                isReversed: isReversed,
                owner: selfID,
                isSquared: true);
            loadForwardingPreviewConsole(media);
          },
        ),
      ],
    );

    setTheState();
  }

  void loadForwardingPreviewConsole(FireMedia m) async {
    final vpc = await _loopingController(m);
    console = Console(
      name: "ForwardingPreviewConsole",
      bottomInputs: [mainInput],
      previewMedia: m.display(size: _squaredCamSize, controller: vpc),
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () {
            vpc?.dispose();
            loadForwardingCameraConsole(null, m.isReversed ? 1 : 0);
          },
        ),
        ConsoleButton(
            name: "Cancel",
            onPress: () {
              vpc?.dispose();
              loadForwardingConsole();
            }),
        ConsoleButton(
            name: "Accept",
            onPress: () {
              vpc?.dispose();
              cameraInput = m;
              loadForwardingConsole();
            }),
      ],
    );

    setTheState();
  }
}

FireMedia makeCameraMedia({
  required String cachedPath,
  required Size size,
  required bool isReversed,
  required String owner,
  required bool isSquared,
}) {
  final mime = lookupMimeType(cachedPath)!;
  final data = File(cachedPath).readAsBytesSync();
  final id = deterministicMediaID(data, owner);
  return FireMedia(id,
      ownerID: owner,
      timestamp: makeTimestamp(),
      width: size.width,
      height: size.height,
      cachePath: cachedPath,
      isSquared: isSquared,
      isReversed: isReversed,
      mime: mime);
}
