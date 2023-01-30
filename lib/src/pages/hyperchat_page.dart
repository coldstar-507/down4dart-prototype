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

import '../boxes.dart';
import '../down4_utility.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/render_utils.dart' as ru;

class HyperchatPage extends StatefulWidget {
  final double initialOffset;
  final List<CameraDescription> cameras;
  final List<Palette> homePalettes, transitionedHomePalettes;
  final Iterable<Person> people;
  final void Function(r.HyperchatRequest) hyperchatRequest;
  final void Function(r.ChatRequest) ping;
  final void Function() back;
  final Self self;

  const HyperchatPage({
    required this.initialOffset,
    required this.people,
    required this.transitionedHomePalettes,
    required this.self,
    required this.homePalettes,
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
  var _tec = TextEditingController();
  MessageMedia? _cameraInput;
  CameraController? _ctrl;
  Console? _console;
  Map<Identifier, MessageMedia> _cachedImages = {};
  Map<Identifier, MessageMedia> _cachedVideos = {};
  late var _palettes = widget.homePalettes;
  late var _scrollController =
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
          _palettes = widget.transitionedHomePalettes;
          _scrollController.animateTo(0,
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
          if (image.file == null) continue;
          print("precached image id=${image.id}");
          precacheImage(FileImage(image.file!), context);
        }
      }).then((value) => print("precached all images"));
    });
  }

  Iterable<MessageMedia> get savedImages => widget.self.images.map(
      (mediaID) => _cachedImages[mediaID] ??= mediaID.getLocalMessageMedia()!);

  Iterable<MessageMedia> get savedVideos => widget.self.videos.map(
      (mediaID) => _cachedVideos[mediaID] ??= mediaID.getLocalMessageMedia()!);

  Future<void> send({MessageMedia? mediaInput}) async {
    if (_cameraInput == null && _tec.value.text.isEmpty && mediaInput == null) {
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
      text: _tec.value.text,
      mediaID: mediaInput?.id ?? _cameraInput?.id,
    );

    final pairs = (await ru.randomPrompts(10))
        .map((pair) => "${pair.first} ${pair.second}")
        .toList(growable: false);

    final targets = widget.people.whereType<User>().asIds().toSet();
    final hcReq = r.HyperchatRequest(
      message: msg,
      targets: targets.toList(growable: false),
      wordPairs: pairs,
      media: mediaInput ?? _cameraInput,
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
            elementAspectRatio: size?.aspectRatio ?? 1.0,
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

  ConsoleInput get consoleInput => ConsoleInput(placeHolder: ":)", tec: _tec);

  void loadMediaConsole([bool images = true]) {
    _console = Console(
      bottomInputs: [consoleInput],
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
    _console = Console(
      bottomInputs: [consoleInput],
      topButtons: [
        ConsoleButton(name: "Ping", onPress: ping),
        ConsoleButton(name: "Send", onPress: send),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _cameraInput == null ? "Camera" : "@Camera",
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
    _console = Console(
      bottomInputs: [consoleInput],
      toMirror: isReversed,
      videoPlayerController: vpc,
      imagePreviewPath: cachedPath,
      topButtons: [
        ConsoleButton(
            name: "Accept",
            onPress: () {
              _cameraInput = MessageMedia(
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
              _cameraInput = null;
              loadSquaredCameraConsole();
            }),
        ConsoleButton(
            name: "Cancel",
            onPress: () {
              _cameraInput = null;
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
    if (_ctrl == null || reloadCtrl) {
      try {
        _ctrl = CameraController(widget.cameras[cam], ResolutionPreset.medium);
        await _ctrl?.initialize();
      } catch (error) {
        loadBaseConsole();
      }
    }
    _ctrl?.setFlashMode(fm);
    _console = Console(
      bottomInputs: [consoleInput],
      cameraController: _ctrl,
      aspectRatio: _ctrl?.value.aspectRatio,
      topButtons: [
        ConsoleButton(name: "Squared", isMode: true, onPress: loadFullCamera),
        ConsoleButton(
          name: "Capture",
          isSpecial: true,
          shouldBeDownButIsnt: _ctrl?.value.isRecordingVideo == true,
          onPress: () async {
            var file = await _ctrl?.takePicture();
            if (file == null) loadBaseConsole();
            loadSquaredCameraPreview(
              cachedPath: file!.path,
              aspectRatio: _ctrl!.value.aspectRatio,
              isReversed: _ctrl?.cameraId == 1,
              isVideo: false,
            );
          },
          onLongPress: () async {
            await _ctrl?.startVideoRecording();
            loadSquaredCameraConsole(cam, fm);
          },
          onLongPressUp: () async {
            var file = await _ctrl?.stopVideoRecording();
            if (file == null) loadBaseConsole();
            loadSquaredCameraPreview(
              cachedPath: file!.path,
              aspectRatio: _ctrl!.value.aspectRatio,
              isReversed: _ctrl?.cameraId == 1,
              isVideo: true,
            );
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () async {
              await _ctrl?.dispose();
              _ctrl = null;
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
    if (_ctrl != null) await _ctrl!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        scrollController: _scrollController,
        staticList: true,
        title: "Hyperchat",
        console: _console!,
        list: _palettes,
      ),
    ]);
  }
}
