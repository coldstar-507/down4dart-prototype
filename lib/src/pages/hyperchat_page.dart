import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_testproject/src/render_objects/render_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:english_words/english_words.dart' as rw;
import 'package:file_picker/file_picker.dart';

import '../boxes.dart';
import '../down4_utility.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class HyperchatPage extends StatefulWidget {
  final double initialOffset;
  final List<CameraDescription> cameras;
  final List<Palette> palettes, transitioned;
  final Iterable<User> userTargets;
  // final List<Palette> Function() transition;
  final void Function(r.HyperchatRequest) hyperchatRequest;
  final void Function(r.ChatRequest) ping;
  final void Function() back;
  final User self;

  const HyperchatPage({
    required this.initialOffset,
    required this.userTargets,
    required this.transitioned,
    // required this.transition,
    required this.self,
    required this.palettes,
    required this.hyperchatRequest,
    required this.cameras,
    required this.back,
    required this.ping,
    Key? key,
  }) : super(key: key);

  @override
  State<HyperchatPage> createState() => _HyperchatPageState();
}

class _HyperchatPageState extends State<HyperchatPage> {
  var tec = TextEditingController();
  Down4Media? mediaInput;
  CameraController? ctrl;
  Console? console;
  Map<Identifier, Down4Media> cachedImages = {};
  Map<Identifier, Down4Media> cachedVideos = {};
  late var palettes = widget.palettes;
  late var scrollController =
      ScrollController(initialScrollOffset: widget.initialOffset);

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
    asyncImageLoad();
    delayed();
  }

  Future<void> delayed() async {
    Future(() => setState(() {
          palettes = widget.transitioned;
          scrollController.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut);
        }));
  }

  Future<void> asyncImageLoad() async {
    Future(() {
      final keys = b.images.keys;
      final nImages = keys.length;
      final nImagesToLoad = nImages <= 25 ? nImages : 25;
      for (int i = 0; i < nImagesToLoad; i++) {
        final mediaID = keys.elementAt(i);
        cachedImages[mediaID] = b.loadSavedImage(mediaID);
        print("load media id=$mediaID");
      }
    }).then((value) {
      Future(() {
        print("loaded all images");
        for (final image in cachedImages.values) {
          print("precached image id=${image.id}");
          precacheImage(MemoryImage(image.data), context);
        }
      }).then((value) => print("precached all images"));
    });
  }

  Iterable<Down4Media> get savedImages => b.images.keys
      .map((mediaID) => cachedImages[mediaID] ??= b.loadSavedImage(mediaID));

  Iterable<Down4Media> get savedVideos => b.videos.keys
      .map((mediaID) => cachedVideos[mediaID] ??= b.loadSavedVideo(mediaID));

  void send() {
    if (mediaInput == null && tec.value.text.isEmpty) return;

    final msg = Down4Message(
      type: Messages.chat,
      id: messagePushId(),
      senderID: widget.self.id,
      timestamp: u.timeStamp(),
      mediaID: mediaInput?.id,
      text: tec.value.text,
    );

    final pairs = rw
        .generateWordPairs(safeOnly: false)
        .take(10)
        .map((e) => "${e.first} ${e.second}")
        .toList(growable: false);

    final hcReq = r.HyperchatRequest(
      message: msg,
      targets: widget.userTargets.asIds().toList(growable: false),
      wordPairs: pairs,
      media: mediaInput,
    );

    widget.hyperchatRequest(hcReq);
  }

  void ping() {
    // TODO
  }

  Future<void> handleImport() async {
    FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg'],
      withData: true,
      allowMultiple: true,
    );
    final ts = u.timeStamp();
    for (final pf in r?.files ?? <PlatformFile>[]) {
      if (pf.bytes != null) {
        final compressedData = await FlutterImageCompress.compressWithList(
          pf.bytes!,
          minHeight: 520,
          minWidth: 0,
        );
        final mediaID = u.generateMediaID(compressedData);
        cachedImages[mediaID] = Down4Media(
          id: mediaID,
          data: compressedData,
          metadata: MediaMetadata(owner: widget.self.id, timestamp: ts),
        );
        b.saveImage(cachedImages[mediaID]!);
      }
    }
    loadMediaConsole();
  }

  ConsoleInput get consoleInput => ConsoleInput(placeHolder: ":)", tec: tec);

  void loadMediaConsole([bool images = true]) {
    console = Console(
      inputs: [consoleInput],
      selectMedia: (media) {
        mediaInput = media;
        send();
      },
      images: true,
      medias: images ? savedImages.toList() : savedVideos.toList(),
      topButtons: [
        ConsoleButton(name: "Import", onPress: handleImport),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
          isMode: true,
          name: images ? "Images" : "Videos",
          onPress: () => loadMediaConsole(!images),
        ),
      ],
    );
    setState(() {});
  }

  void loadFullCamera() {
    // TODO
  }

  void loadBaseConsole() {
    console = Console(
      inputs: [consoleInput],
      topButtons: [
        ConsoleButton(name: "Ping", onPress: ping),
        ConsoleButton(name: "Send", onPress: send),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: mediaInput == null ? "Camera" : "@Camera",
          onPress: loadSquaredCameraConsole,
        ),
        ConsoleButton(name: "Medias", onPress: loadMediaConsole),
      ],
    );
    setState(() {});
  }

  Future<void> loadSquaredCameraPreview() async {
    if (mediaInput == null) return loadBaseConsole();
    VideoPlayerController? vpc;
    String? path;
    if (mediaInput!.metadata.isVideo) {
      vpc = VideoPlayerController.file(mediaInput!.file!);
      await vpc.initialize();
    } else {
      path = mediaInput!.path;
    }

    console = Console(
      inputs: [consoleInput],
      videoPlayerController: vpc,
      imagePreviewPath: path,
      topButtons: [
        ConsoleButton(name: "Accept", onPress: loadBaseConsole),
      ],
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () {
              mediaInput = null;
              loadSquaredCameraConsole();
            }),
        ConsoleButton(
            name: "Cancel",
            onPress: () {
              mediaInput = null;
              loadBaseConsole();
            }),
      ],
    );

    setState(() {});
  }

  Future<void> loadSquaredCameraConsole([
    int cam = 0,
    FlashMode fm = FlashMode.off,
    bool reloadCtrl = false,
  ]) async {
    if (ctrl == null || reloadCtrl) {
      try {
        ctrl = CameraController(widget.cameras[cam], ResolutionPreset.medium);
        await ctrl?.initialize();
      } catch (error) {
        loadBaseConsole();
      }
    }
    ctrl?.setFlashMode(fm);
    console = Console(
      inputs: [consoleInput],
      cameraController: ctrl,
      aspectRatio: ctrl?.value.aspectRatio,
      topButtons: [
        ConsoleButton(name: "Squared", isMode: true, onPress: loadFullCamera),
        ConsoleButton(
          name: "Capture",
          isSpecial: true,
          shouldBeDownButIsnt: ctrl?.value.isRecordingVideo == true,
          onPress: () async {
            var file = await ctrl?.takePicture();
            if (file == null) loadBaseConsole();
            mediaInput = Down4Media.fromCamera(
                file!.path,
                MediaMetadata(
                  owner: widget.self.id,
                  isVideo: false,
                  timestamp: u.timeStamp(),
                  toReverse: cam == 1,
                ));
            // await ctrl?.dispose();
            // ctrl = null;
            loadSquaredCameraPreview();
          },
          onLongPress: () async {
            await ctrl?.startVideoRecording();
            loadSquaredCameraConsole(cam, fm);
          },
          onLongPressUp: () async {
            var file = await ctrl?.stopVideoRecording();
            if (file == null) loadBaseConsole();
            mediaInput = Down4Media.fromCamera(
                file!.path,
                MediaMetadata(
                  owner: widget.self.id,
                  isVideo: true,
                  timestamp: u.timeStamp(),
                  toReverse: cam == 1,
                ));
            // await ctrl?.dispose();
            // ctrl = null;
            loadSquaredCameraPreview();
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
          name: cam == 0 ? "Rear" : "Front",
          isMode: true,
          onPress: () => loadSquaredCameraConsole((cam + 1) % 2, fm, true),
        ),
        ConsoleButton(
          isMode: true,
          name: fm.name.capitalize(),
          onPress: () => loadSquaredCameraConsole(
              cam, fm == FlashMode.off ? FlashMode.torch : FlashMode.off),
        ),
      ],
    );
    setState(() {});
  }

  @override
  void dispose() async {
    if (ctrl != null) await ctrl!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        scrollController: scrollController,
        title: "Hyperchat",
        console: console!,
        palettes: palettes,
      ),
    ]);
  }
}
