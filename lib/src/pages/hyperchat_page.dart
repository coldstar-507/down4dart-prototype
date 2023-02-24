import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:down4/src/data_objects.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../globals.dart';
import '../_down4_dart_utils.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/_down4_flutter_utils.dart' as ru;

class HyperchatPage extends StatefulWidget implements Down4PageWidget {
  ID get id => "HyperchatPage";
  final double initialOffset;
  // final u.Triple<List<Palette2>, Iterable<Person>, int> transition;
  final List<Palette2> palettesForTransition;
  final int nHidden;
  final Iterable<Person> people;
  final List<Palette2> homePalettes; //, transitionedHomePalettes;
  // final Iterable<Person> people;
  final void Function(r.HyperchatRequest) hyperchatRequest;
  final void Function(r.PingRequest) ping;
  final void Function() back;
  // final Self self;

  const HyperchatPage({
    required this.initialOffset,
    // required this.transition,
    required this.palettesForTransition,
    required this.nHidden,
    required this.people,
    // required this.transitionedHomePalettes,
    required this.homePalettes,
    required this.hyperchatRequest,
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
  late List<Palette2> _palettes = widget.homePalettes;
  late final double offset = widget.nHidden * Palette.fullHeight;
  late var _scrollController =
      ScrollController(initialScrollOffset: widget.initialOffset);

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
    animatedTransition();
  }

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          _palettes = [...widget.palettesForTransition];
          _scrollController.jumpTo(widget.initialOffset + offset);
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

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
      senderID: g.self.id,
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
    if (_tec.value.text.isEmpty) return;
    widget.ping(r.PingRequest(
        senderID: g.self.id,
        text: _tec.value.text,
        targets: widget.people.asIds().toList()));
    _tec.clear();
  }

  ConsoleInput get consoleInput {
    return ConsoleInput(
      placeHolder: ":)",
      tec: _tec,
      maxLines: 6,
    );
  }

  void loadMediaConsole([bool images = true]) {
    _console = Console(
      consoleMedias2: ConsoleMedias2(
          showImages: images,
          onSelectMedia: (media) => send(mediaInput: media)),
      bottomInputs: [consoleInput],
      // mediasInfo: consoleMedias(images: images, show: true),
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

  void loadBaseConsole({bool images = true}) {
    _console = Console(
      // mediasInfo: consoleMedias(images: images, show: false),
      bottomInputs: [consoleInput],
      topButtons: [
        ConsoleButton(name: "Ping", onPress: ping),
        ConsoleButton(name: "Send", onPress: send),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
            name: _cameraInput == null ? "Camera" : "@Camera",
            onPress: loadSquaredCameraConsole),
        ConsoleButton(name: "Medias", onPress: () => loadMediaConsole(images)),
      ],
    );
    setState(() {});
  }

  Future<void> handleImport({required bool importImages}) async {
    if (importImages) {
      final results = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: u.imageExtensions.withoutDots(),
          allowMultiple: true,
          allowCompression: true,
          withData: true);
      if (results == null) return;
      for (final file in results.files) {
        if (file.path == null && file.bytes != null) continue;
        final mediaID = u.deterministicMediaID(file.bytes!, g.self.id);
        final size = await decodeImageSize(file.bytes!);
        final f = await writeMedia(mediaData: file.bytes!, mediaID: mediaID);
        MessageMedia(
            id: mediaID,
            isSaved: true,
            path: f.path,
            metadata: MediaMetadata(
                isSquared: false,
                isReversed: false,
                extension: file.path!.extension(),
                timestamp: u.timeStamp(),
                owner: g.self.id,
                elementAspectRatio: 1.0 / size.aspectRatio))
          ..isSaved = true
          ..save();
        g.self.images.add(mediaID);
        loadMediaConsole();
      }
    } else {
      final videos = await FilePicker.platform.pickFiles(
          allowedExtensions: u.videoExtensions.withoutDots(),
          type: FileType.custom,
          withData: true,
          allowCompression: true,
          allowMultiple: true);
      if (videos == null) return;
      for (final video in videos.files) {
        if (video.path == null || video.bytes == null) continue;
        final videoInfoGetter = FlutterVideoInfo();
        final videoInfo = await videoInfoGetter.getVideoInfo(video.path!);
        final mediaID = u.deterministicMediaID(video.bytes!, g.self.id);
        final f = await writeMedia(mediaData: video.bytes!, mediaID: mediaID);
        final tn =
            await VideoThumbnail.thumbnailData(video: f.path, quality: 90);
        String? thumbnailPath;
        if (tn != null) {
          final f = await writeMedia(
              mediaData: tn, mediaID: mediaID, isThumbnail: true);
          thumbnailPath = f.path;
        }
        MessageMedia(
            id: mediaID,
            path: f.path,
            thumbnail: thumbnailPath,
            metadata: MediaMetadata(
                isReversed: false,
                isSquared: false,
                extension: video.path!.extension(),
                timestamp: u.timeStamp(),
                owner: g.self.id,
                elementAspectRatio:
                    (videoInfo?.width ?? 1.0) / (videoInfo?.height ?? 1.0)))
          ..isSaved = true
          ..save();
        g.self.videos.add(mediaID);
        loadMediaConsole();
        // _cachedSavedVideos[mediaID] = down4Media;
      }
    }
    g.self.save();
  }

  Future<void> loadSquaredCameraConsole({
    CameraController? ctrl,
    int cam = 0,
    String? path,
  }) async {
    if (ctrl == null) {
      try {
        ctrl = CameraController(g.cameras[cam], ResolutionPreset.high);
        await ctrl.initialize();
      } catch (err) {
        loadBaseConsole();
      }
    }

    Future<void> nextCam() async {
      await ctrl?.dispose();
      return loadSquaredCameraConsole(cam: (cam + 1) % 2);
    }

    if (path == null) {
      _console = Console(
        bottomInputs: [consoleInput],
        cameraController: ctrl,
        topButtons: [
          ConsoleButton(
            name: "Capture",
            isSpecial: true,
            shouldBeDownButIsnt: ctrl!.value.isRecordingVideo,
            onPress: () async {
              final XFile f = await ctrl!.takePicture();
              loadSquaredCameraConsole(ctrl: ctrl, cam: cam, path: f.path);
            },
            onLongPress: () async {
              await ctrl!.startVideoRecording();
              loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
            },
            onLongPressUp: () async {
              final XFile f = await ctrl!.stopVideoRecording();
              loadSquaredCameraConsole(ctrl: ctrl, cam: cam, path: f.path);
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
              name: "Back",
              onPress: () {
                ctrl?.dispose();
                loadBaseConsole();
              }),
          ConsoleButton(
            name: cam == 0 ? "Rear" : "Front",
            onPress: nextCam,
            isMode: true,
          ),
        ],
      );
    } else {
      VideoPlayerController? vpc;
      final topBottons = [
        ConsoleButton(
          name: "Accept",
          onPress: () async {
            String? thumbnailPath;
            final mediaID = u.randomMediaID();
            if (path.extension().isVideoExtension()) {
              final tn =
                  await VideoThumbnail.thumbnailData(video: path, quality: 90);
              if (tn != null) {
                final f = await writeMedia(
                    mediaData: tn, mediaID: mediaID, isThumbnail: true);
                thumbnailPath = f.path;
              }
            }
            vpc?.dispose();
            _cameraInput = MessageMedia(
                path: path,
                thumbnail: thumbnailPath,
                id: u.randomMediaID(),
                metadata: MediaMetadata(
                    owner: g.self.id,
                    timestamp: u.timeStamp(),
                    elementAspectRatio: ctrl!.value.aspectRatio,
                    extension: path.extension(),
                    isReversed: cam == 1,
                    isSquared: true));
            loadBaseConsole();
          },
        ),
      ];
      final bottomButtons = [
        ConsoleButton(
          name: "Back",
          onPress: () {
            File(path).delete();
            vpc?.dispose();
            loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
          },
        ),
        ConsoleButton(
            name: "Cancel",
            onPress: () {
              File(path).delete();
              vpc?.dispose();
              ctrl?.dispose();
              loadBaseConsole();
            }),
      ];

      print("PATH EXTENSION = ${path.extension()}");
      if (path.extension().isVideoExtension()) {
        vpc = VideoPlayerController.file(File(path));
        await vpc.initialize();
        await vpc.setLooping(true);
        await vpc.play();
        _console = Console(
            bottomInputs: [consoleInput],
            videoForPreview: VideoPreview(
                videoPlayer: VideoPlayer(vpc),
                videoAspectRatio: ctrl!.value.aspectRatio,
                isReversed: cam == 1),
            topButtons: topBottons,
            bottomButtons: bottomButtons);
      } else {
        _console = Console(
            bottomInputs: [consoleInput],
            imageForPreview: ImagePreview(
                path: path,
                isReversed: cam == 1,
                imageAspectRatio: ctrl!.value.aspectRatio),
            topButtons: topBottons,
            bottomButtons: bottomButtons);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _cameraInput?.delete();
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
          list: _palettes),
    ]);
  }
}
