import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:down4/src/data_objects.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:down4/src/render_objects/render_utils.dart';
import 'package:video_player/video_player.dart';
// import 'package:english_words/english_words.dart' as rw;
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
  final void Function(r.HyperchatRequest) hyperchatRequest;
  final void Function(r.ChatRequest) ping;
  final void Function() back;
  final User self;

  const HyperchatPage({
    required this.initialOffset,
    required this.userTargets,
    required this.transitioned,
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
  Down4Media? cameraInput;
  CameraController? ctrl;
  Console? console;
  Map<Identifier, Down4Media> _cachedImages = {};
  Map<Identifier, Down4Media> _cachedVideos = {};
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
              curve: Curves.easeInOut);
        }));
  }

  Future<void> asyncImageLoad() async {
    Future(() {
      final keys = b.images.keys;
      final nImages = keys.length;
      final nImagesToLoad = nImages <= 25 ? nImages : 25;
      for (int i = 0; i < nImagesToLoad; i++) {
        final mediaID = keys.elementAt(i);
        _cachedImages[mediaID] = b.loadSavedImage(mediaID);
        print("load media id=$mediaID");
      }
    }).then((value) {
      Future(() {
        print("loaded all images");
        for (final image in _cachedImages.values) {
          print("precached image id=${image.id}");
          precacheImage(MemoryImage(image.data), context);
        }
      }).then((value) => print("precached all images"));
    });
  }

  Iterable<Down4Media> get savedImages => b.images.keys
      .map((mediaID) => _cachedImages[mediaID] ??= b.loadSavedImage(mediaID));

  Iterable<Down4Media> get savedVideos => b.videos.keys
      .map((mediaID) => _cachedVideos[mediaID] ??= b.loadSavedVideo(mediaID));

  void send({Down4Media? mediaInput}) {
    if (cameraInput == null && tec.value.text.isEmpty && mediaInput == null) {
      return;
    }

    final messageID = messagePushId();
    final randomRoot = sha1(utf8.encode(messageID)).toBase58();

    final msg = Down4Message(
      root: randomRoot,
      type: Messages.chat,
      id: messageID,
      senderID: widget.self.id,
      timestamp: u.timeStamp(),
      mediaID: mediaInput?.id ?? cameraInput?.id,
      text: tec.value.text,
    );

    final pairs = u
        .randomPairs(10)
        .map((e) => "${e.first} ${e.second}")
        .toList(growable: false);

    final hcReq = r.HyperchatRequest(
      message: msg,
      targets: widget.userTargets.asIds().toList()..remove(widget.self.id),
      wordPairs: pairs,
      media: mediaInput ?? cameraInput,
    );

    widget.hyperchatRequest(hcReq);
  }

  void ping() {
    // TODO
  }

  Future<void> handleImport({required bool importImages}) async {
    if (importImages) {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
        requestFullMetadata: false,
      );
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final decodedImage = await decodeImageFromList(bytes);
        final mediaID = u.generateMediaID(bytes);
        final down4Media = Down4Media(
          id: mediaID,
          data: bytes,
          metadata: MediaMetadata(
            timestamp: u.timeStamp(),
            owner: widget.self.id,
            aspectRatio: decodedImage.height / decodedImage.width,
          ),
        )..save(toPersonal: true);
        _cachedImages[mediaID] = down4Media;
      }
    } else {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      if (video == null) return;
      final bytes = await video.readAsBytes();
      final mediaID = u.generateMediaID(bytes);
      final down4Media = Down4Media(
        id: mediaID,
        data: bytes,
        metadata: MediaMetadata(
          timestamp: u.timeStamp(),
          owner: widget.self.id,
          isVideo: true,
        ),
      );
      _cachedVideos[mediaID] = down4Media;
    }
    loadMediaConsole();
  }

  ConsoleInput get consoleInput => ConsoleInput(placeHolder: ":)", tec: tec);

  void loadMediaConsole([bool images = true]) {
    console = Console(
      inputs: [consoleInput],
      selectMedia: (media) => send(mediaInput: media),
      images: true,
      medias: images ? savedImages.toList() : savedVideos.toList(),
      topButtons: [
        ConsoleButton(
          name: "Import",
          onPress: () => handleImport(importImages: images),
        ),
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
          name: cameraInput == null ? "Camera" : "@Camera",
          onPress: loadSquaredCameraConsole,
        ),
        ConsoleButton(name: "Medias", onPress: loadMediaConsole),
      ],
    );
    setState(() {});
  }

  Future<void> loadSquaredCameraPreview() async {
    if (cameraInput == null) return loadBaseConsole();
    VideoPlayerController? vpc;
    String? path;
    if (cameraInput!.metadata.isVideo) {
      vpc = VideoPlayerController.file(cameraInput!.file!);
      await vpc.initialize();
    } else {
      path = cameraInput!.path;
    }

    console = Console(
      inputs: [consoleInput],
      toMirror: cameraInput!.metadata.toReverse,
      videoPlayerController: vpc,
      imagePreviewPath: path,
      topButtons: [
        ConsoleButton(name: "Accept", onPress: loadBaseConsole),
      ],
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () {
              cameraInput = null;
              loadSquaredCameraConsole();
            }),
        ConsoleButton(
            name: "Cancel",
            onPress: () {
              cameraInput = null;
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
            cameraInput = Down4Media.fromCamera(
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
            cameraInput = Down4Media.fromCamera(
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
        staticList: true,
        title: "Hyperchat",
        console: console!,
        palettes: palettes,
      ),
    ]);
  }
}
