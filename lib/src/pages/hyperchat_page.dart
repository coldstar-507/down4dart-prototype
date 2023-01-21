import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:down4/src/render_objects/render_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:down4/src/data_objects.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:english_words/english_words.dart' as w;

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
  final Iterable<Person> people;
  final void Function(r.HyperchatRequest) hyperchatRequest;
  final void Function(r.ChatRequest) ping;
  final void Function() back;
  final Self self;

  const HyperchatPage({
    required this.initialOffset,
    required this.people,
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
  MessageMedia? cameraInput;
  CameraController? ctrl;
  Console? console;
  Map<Identifier, MessageMedia> _cachedImages = {};
  Map<Identifier, MessageMedia> _cachedVideos = {};
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
      final keys = widget.self.images;
      final nImages = keys.length;
      final nImagesToLoad = nImages <= 25 ? nImages : 25;
      for (int i = 0; i < nImagesToLoad; i++) {
        final mediaID = keys.elementAt(i);
        final media = mediaID.getLocalMessageMedia();
        if (media != null) _cachedImages[mediaID] = media;
        print("load media id=$mediaID");
      }
    }).then((value) {
      Future(() {
        print("loaded all images");
        for (final image in _cachedImages.values) {
          print("precached image id=${image.id}");
          if (image.file != null) {
            precacheImage(FileImage(image.file!), context);
          }
        }
      }).then((value) => print("precached all images"));
    });
  }

  Iterable<MessageMedia> get savedImages => widget.self.images.map(
      (mediaID) => _cachedImages[mediaID] ??= mediaID.getLocalMessageMedia()!);

  Iterable<MessageMedia> get savedVideos => widget.self.videos.map(
      (mediaID) => _cachedVideos[mediaID] ??= mediaID.getLocalMessageMedia()!);

  void send({MessageMedia? mediaInput}) {
    if (cameraInput == null && tec.value.text.isEmpty && mediaInput == null) {
      return;
    }

    final messageID = messagePushId();
    final ts = u.timeStamp();
    final idd = utf8.encode(messageID + ts.toRadixString(16));
    final randomRoot = sha1(idd).toBase58();

    final msg = Message(
      root: randomRoot,
      id: messageID,
      senderID: widget.self.id,
      timestamp: u.timeStamp(),
      text: tec.value.text,
      mediaID: mediaInput?.id ?? cameraInput?.id,
    );

    final pairs = w
        .generateWordPairs(safeOnly: false)
        .take(10)
        .map((e) => "${e.first} ${e.second}")
        .toList(growable: false);

    final targets = widget.people.asIds().toSet()..remove(widget.self.id);
    final hcReq = r.HyperchatRequest(
      message: msg,
      targets: targets.toList(),
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
        // final bytes = await file.readAsBytes();
        // final decodedImage = await decodeImageFromList(bytes);
        final mediaID = u.randomMediaID();
        final size = await calculateImageDimension(f: File(file.path));
        final down4Media = MessageMedia(
          id: mediaID,
          path: file.path,
          isSaved: true,
          metadata: MediaMetadata(
            timestamp: u.timeStamp(),
            isSquared: false,
            isVideo: false,
            isReversed: false,
            owner: widget.self.id,
            elementAspectRatio: 1 / (size?.aspectRatio ?? 1.0),
          ),
        )..save();
        _cachedImages[mediaID] = down4Media;
        widget.self
          ..images.add(mediaID)
          ..save();
      }
    } else {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      if (video == null) return;
      final videoInfo = FlutterVideoInfo();
      final info = await videoInfo.getVideoInfo(video.path);
      final mediaID = u.randomMediaID();
      final down4Media = MessageMedia(
        id: mediaID,
        path: video.path,
        isSaved: true,
        metadata: MediaMetadata(
          isSquared: false,
          isReversed: false,
          isVideo: true,
          timestamp: u.timeStamp(),
          owner: widget.self.id,
          elementAspectRatio: (info?.width ?? 1.0) / (info?.height ?? 1.0),
        ),
      );
      _cachedVideos[mediaID] = down4Media;
      widget.self
        ..videos.add(mediaID)
        ..save();
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

  Future<void> loadSquaredCameraPreview({
    required String cachedPath,
    required bool isVideo,
    required bool isReversed,
    required double aspectRatio,
  }) async {
    VideoPlayerController? vpc;
    if (isVideo) {
      vpc = VideoPlayerController.file(File(cachedPath));
      await vpc.initialize();
    }
    console = Console(
      inputs: [consoleInput],
      toMirror: isReversed,
      videoPlayerController: vpc,
      imagePreviewPath: cachedPath,
      topButtons: [
        ConsoleButton(
            name: "Accept",
            onPress: () {
              cameraInput = MessageMedia(
                path: cachedPath,
                id: u.randomMediaID(),
                metadata: MediaMetadata(
                  isReversed: isReversed,
                  isVideo: isVideo,
                  isSquared: true,
                  canSkipCheck: true,
                  owner: widget.self.id,
                  elementAspectRatio: aspectRatio,
                  timestamp: u.timeStamp(),
                ),
              );
              loadBaseConsole();
            }),
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
            loadSquaredCameraPreview(
              cachedPath: file!.path,
              aspectRatio: ctrl!.value.aspectRatio,
              isReversed: ctrl?.cameraId == 1,
              isVideo: false,
            );
          },
          onLongPress: () async {
            await ctrl?.startVideoRecording();
            loadSquaredCameraConsole(cam, fm);
          },
          onLongPressUp: () async {
            var file = await ctrl?.stopVideoRecording();
            if (file == null) loadBaseConsole();
            loadSquaredCameraPreview(
              cachedPath: file!.path,
              aspectRatio: ctrl!.value.aspectRatio,
              isReversed: ctrl?.cameraId == 1,
              isVideo: true,
            );
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () async {
              await ctrl?.dispose();
              ctrl = null;
              loadBaseConsole();
            }),
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
