import 'dart:io';

import 'package:camera/camera.dart';
import 'package:mime/mime.dart';

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
  Future<void> loadSquaredCameraConsole([
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
    console = squaredCapturingConsole(
      user: selfID,
      cam: cam,
      uselessInput: mainInput,
      goToPreview: (m) {
        ctrl?.dispose();
        loadPreviewConsole(m);
      },
      back: () {
        ctrl?.dispose();
        loadBaseConsole();
      },
      onVideoStarted: () => loadSquaredCameraConsole(ctrl, cam),
      nextCam: () => loadSquaredCameraConsole(null, (cam + 1) % 2),
      ctrl: ctrl!,
    );
    setTheState();
  }

  void loadPreviewConsole(FireMedia m) {
    console = squaredPreviewConsole(
      media: m,
      uselessInput: mainInput,
      back: () => loadSquaredCameraConsole(null, m.isReversed ? 1 : 0),
      cancel: loadBaseConsole,
      accept: () {
        cameraInput = m;
        loadBaseConsole();
      },
    );
    setTheState();
  }
}

mixin Medias on Pager {
  List<(String mode, void Function(FireMedia m) onSelect)> get mediasMode;
  int currentMode = 0;

  void switchMediaMode() {
    currentMode = (currentMode + 1) % mediasMode.length;
    setTheState();
  }

  void loadMediasConsole([
    bool images = true,
    bool extra = false,
    void Function(FireMedia)? forNode,
  ]) {
    console = mediaConsole(
        uselessInput: mainInput,
        selectMedia: forNode ?? mediasMode[currentMode].$2,
        afterImport: () => loadMediasConsole(images, extra),
        back: loadBaseConsole,
        switchMediasType: () => loadMediasConsole(!images, extra),
        switchMediaMode: switchMediaMode,
        switchExtra: () => loadMediasConsole(images, !extra),
        importGroupMedia: forNode,
        mode: mediasMode[currentMode].$1,
        extra: extra,
        images: images);

    setTheState();
  }
}

mixin Chatter on Camera, Backable {
  List<Down4Object>? get fo;
  // set cameraInput(FireMedia? m);
  // FireMedia? get cameraInput;
  // ConsoleInput get input;
  // Console get console;
  // set console(Console c);

  // void loadBaseConsole();

  Future<void> send({FireMedia? mediaInput});

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

  void loadForwardingConsole([bool extra = false]) {
    console = forwardingConsole(
        usefulInput: mainInput,
        fObjects: fo!,
        loadForwardingMediaConsole: loadForwardingMediasConsole,
        forward: send,
        switchExtra: () => loadForwardingConsole(!extra),
        back: back,
        extra: extra);
    setTheState();
  }

  void loadForwardingMediasConsole([bool images = true]) {
    console = forwardingMediaConsole(
        uselessInput: mainInput,
        onSelectMedia: (media) => send(mediaInput: media),
        switchType: () => loadForwardingMediasConsole(!images),
        forwardingObjects: fo!,
        back: loadForwardingConsole,
        images: images);
    setTheState();
  }
}

FireMedia makeCameraMedia(String p, double ar, bool ir, String o) {
  final mime = lookupMimeType(p)!;
  final data = File(p).readAsBytesSync();
  final id = deterministicMediaID(data, o);
  return FireMedia(id,
      owner: o,
      timestamp: makeTimestamp(),
      aspectRatio: ar,
      cachePath: p,
      isReversed: ir,
      mime: mime);
}

Console squaredCapturingConsole({
  required ID user,
  required ConsoleInput uselessInput,
  required void Function(FireMedia) goToPreview,
  required void Function() back,
  required void Function() onVideoStarted,
  required void Function() nextCam,
  required CameraController ctrl,
  required int cam,
}) {
  final double ar = ctrl.value.aspectRatio;
  final bool isReversed = cam == 1;
  return Console(
    bottomInputs: [uselessInput],
    cameraController: ctrl,
    topButtons: [
      ConsoleButton(
        name: "Capture",
        isSpecial: true,
        shouldBeDownButIsnt: ctrl.value.isRecordingVideo,
        onPress: () async {
          final XFile f = await ctrl.takePicture();
          final media = makeCameraMedia(f.path, ar, isReversed, user);
          goToPreview(media);
        },
        onLongPress: () async {
          await ctrl.startVideoRecording();
          onVideoStarted();
        },
        onLongPressUp: () async {
          final XFile f = await ctrl.stopVideoRecording();
          final media = makeCameraMedia(f.path, ar, isReversed, user);
          goToPreview(media);
        },
      ),
    ],
    bottomButtons: [
      ConsoleButton(name: "Back", onPress: back),
      ConsoleButton(
        name: cam == 0 ? "Rear" : "Front",
        onPress: nextCam,
        isMode: true,
      ),
    ],
  );
}

Console squaredPreviewConsole({
  required ConsoleInput uselessInput,
  required FireMedia media,
  required void Function() back,
  required void Function() cancel,
  required void Function() accept,
}) {
  // BetterPlayerController? vpc;

  return Console(
    bottomInputs: [uselessInput],
    previewMedia: media,
    topButtons: [
      ConsoleButton(name: "Accept", onPress: accept),
    ],
    bottomButtons: [
      ConsoleButton(name: "Back", onPress: back),
      ConsoleButton(name: "Cancel", onPress: cancel),
    ],
  );

  // if (extensionFromMime(lookupMimeType(path)!).isVideoExtension()) {
  //   vpc = BetterPlayerController(const BetterPlayerConfiguration());
  //   await vpc.setupDataSource(BetterPlayerDataSource.file(path));
  //   await vpc.setLooping(true);
  //   await vpc.play();
  //   return Console(
  //       bottomInputs: [uselessInput],
  //       videoForPreview: VideoPreview(
  //           videoPlayer: BetterPlayer(controller: vpc),
  //           videoAspectRatio: aspectRatio,
  //           isReversed: isReversed),
  //       topButtons: topButtons,
  //       bottomButtons: bottomButtons);
  // } else {
  //   return Console(
  //       bottomInputs: [uselessInput],
  //       imageForPreview: ImagePreview(
  //           path: path, isReversed: isReversed, imageAspectRatio: aspectRatio),
  //       topButtons: topButtons,
  //       bottomButtons: bottomButtons);
  // }
}

Console mediaConsole({
  required ConsoleInput uselessInput,
  required void Function(FireMedia) selectMedia,
  required void Function() afterImport,
  required void Function() back,
  required void Function() switchMediasType,
  required void Function() switchMediaMode,
  required void Function() switchExtra,
  required void Function(FireMedia)? importGroupMedia,
  required String mode,
  required bool extra,
  required bool images,
  // bool forGroupImage = false,
}) {
  return Console(
    bottomInputs: [uselessInput],
    consoleMedias2: ConsoleMedias2(showImages: images, onSelect: selectMedia),
    topButtons: [
      ConsoleButton(
          name: "Import",
          onPress: () async {
            if (importGroupMedia != null) {
              final nodeMedia = await importNodeMedia();
              if (nodeMedia != null) {
                importGroupMedia(nodeMedia);
              } else {
                await importConsoleMedias(images: images);
                afterImport();
              }
            }
          }),
    ],
    bottomButtons: [
      ConsoleButton(
        showExtra: extra,
        isSpecial: true,
        name: "Back",
        onPress: () => extra ? switchExtra() : back(),
        onLongPress: switchExtra,
        extraButtons: [
          ConsoleButton(name: mode, onPress: switchMediaMode, isMode: true),
        ],
      ),
      ConsoleButton(
        isMode: true,
        isActivated: importGroupMedia == null,
        isGreyedOut: importGroupMedia != null,
        name: images ? "Images" : "Videos",
        onPress: switchMediasType,
      ),
    ],
  );
  // setState(() {});
}

Console forwardingConsole({
  required ConsoleInput usefulInput,
  required List<Down4Object> fObjects,
  required void Function() loadForwardingMediaConsole,
  required void Function() forward,
  required void Function() switchExtra,
  required void Function() back,
  required bool extra,
}) {
  return Console(
    bottomInputs: [usefulInput],
    forwardingObjects: fObjects,
    bottomButtons: [
      ConsoleButton(name: "Back", onPress: back),
      ConsoleButton(
        name: "Forward",
        onPress: () => extra ? switchExtra() : forward(),
        onLongPress: switchExtra,
        isSpecial: true,
        showExtra: extra,
        extraButtons: [
          ConsoleButton(name: "Medias", onPress: loadForwardingMediaConsole),
        ],
      )
    ],
  );
}

Console forwardingMediaConsole({
  required ConsoleInput uselessInput,
  required void Function(FireMedia) onSelectMedia,
  required void Function() switchType,
  required List<Down4Object> forwardingObjects,
  required void Function() back,
  required bool images,
}) {
  return Console(
    bottomInputs: [uselessInput],
    consoleMedias2: ConsoleMedias2(showImages: images, onSelect: onSelectMedia),
    forwardingObjects: forwardingObjects,
    bottomButtons: [
      ConsoleButton(name: "Back", onPress: back),
      ConsoleButton(name: images ? "Images" : "Videos", onPress: switchType)
    ],
  );
}
