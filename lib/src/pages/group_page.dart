import 'dart:async';
import 'dart:io';
import 'dart:convert' show utf8;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:down4/src/data_objects.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../boxes.dart';
import '../down4_utility.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/render_utils.dart';

class GroupPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Self self;
  final List<Palette> homePalettes, transitionedHomePalettes;
  final Iterable<Person> people;
  final void Function() back;
  final void Function(r.GroupRequest) groupRequest;
  final double initialOffset;

  const GroupPage({
    required this.people,
    required this.transitionedHomePalettes,
    required this.self,
    required this.back,
    required this.groupRequest,
    required this.homePalettes,
    required this.cameras,
    required this.initialOffset,
    Key? key,
  }) : super(key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  Console? _console;
  CameraController? _ctrl;
  late List<Widget> _items = [...widget.homePalettes, groupMaker(fold: true)];
  var _tec = TextEditingController();
  var _tec2 = TextEditingController();
  bool _private = true;
  late var _scrollController =
      ScrollController(initialScrollOffset: widget.initialOffset);

  NodeMedia? _groupImage;
  String _groupName = "";

  MessageMedia? _cameraInput;

  Map<Identifier, MessageMedia> _cachedImages = {};
  Map<Identifier, MessageMedia> _cachedVideos = {};

  Iterable<MessageMedia> get savedImages => widget.self.images.map(
      (mediaID) => _cachedImages[mediaID] ??= mediaID.getLocalMessageMedia()!);

  Iterable<MessageMedia> get savedVideos => widget.self.videos.map(
      (mediaID) => _cachedVideos[mediaID] ??= mediaID.getLocalMessageMedia()!);

  ConsoleInput get consoleInput => ConsoleInput(placeHolder: ":)", tec: _tec);

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
    animatedTransition();
    asyncImageLoad();
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
          precacheImage(FileImage(image.file!), context);
        }
      }).then((value) => print("precached all images"));
    });
  }

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          _items = [
            ...widget.transitionedHomePalettes,
            groupMaker(fold: false)
          ];
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

  PaletteMaker groupMaker({required bool fold}) => PaletteMaker(
        fold: fold,
        colorCode: NodesColor.group,
        tec: _tec2,
        id: "",
        name: _groupName,
        hintText: "Group Name",
        image: _groupImage,
        nameCallBack: (name) => setState(() => _groupName = name),
        type: Nodes.group,
        imagePress: () => loadMediaConsole(forGroupImage: true),
      );

  Future<void> send({MessageMedia? mediaInput}) async {
    if (_groupImage == null || _groupName.isEmpty) return;
    if (_cameraInput == null && _tec.value.text.isEmpty && mediaInput == null) {
      return;
    }

    final ts = u.timeStamp();
    final idd =
        utf8.encode(_groupName + _groupImage!.id + ts.toRadixString(16));
    final groupID = sha1(idd).toBase58();

    final msg = Message(
      root: groupID,
      id: messagePushId(),
      senderID: widget.self.id,
      timestamp: u.timeStamp(),
      mediaID: mediaInput?.id ?? _cameraInput?.id,
      text: _tec.value.text,
    );

    final targets = widget.people.whereType<User>().asIds().toSet();
    final grpReq = r.GroupRequest(
      groupID: groupID,
      name: _groupName,
      groupMedia: _groupImage!,
      message: msg,
      private: _private,
      targets: targets.toList(),
      media: mediaInput ?? _cameraInput,
    );

    widget.groupRequest(grpReq);
  }

  Future<void> handleImport({
    bool groupImageImport = false,
    bool importImages = true,
  }) async {
    if (importImages) {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
        requestFullMetadata: false,
      );
      for (final file in files) {
        final mediaID = u.randomMediaID();
        // final appPath = b.writeToDocs(cachedPath: file.path, mediaID: mediaID);
        final size = calculateImageDimension(f: File(file.path));
        final down4Media = MessageMedia(
            path: file.path,
            id: mediaID,
            metadata: MediaMetadata(
              isSquared: false,
              isVideo: false,
              isReversed: false,
              timestamp: u.timeStamp(),
              owner: widget.self.id,
              elementAspectRatio: (await size)?.aspectRatio ?? 1.0,
            ));
        if (groupImageImport) {
          _groupImage = down4Media.asNodeMedia();
          loadBaseConsole();
          animatedTransition(); // hack
        } else {
          _cachedImages[mediaID] = down4Media
            ..isSaved = true
            ..save();
          loadMediaConsole();
          widget.self
            ..images.add(mediaID)
            ..save();
        }
      }
    } else {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      if (video == null) return;
      final fvi = FlutterVideoInfo();
      final mediaID = u.randomMediaID();
      // final appPath = b.writeToDocs(cachedPath: video.path, mediaID: mediaID);
      final videoInfo = await fvi.getVideoInfo(video.path);

      final down4Media = MessageMedia(
          id: mediaID,
          path: video.path,
          isSaved: true,
          metadata: MediaMetadata(
            isSquared: false,
            isReversed: false,
            elementAspectRatio:
                (videoInfo?.width ?? 1.0) / (videoInfo?.height ?? 1.0),
            timestamp: u.timeStamp(),
            owner: widget.self.id,
            isVideo: true,
          ))
        ..save();
      _cachedVideos[mediaID] = down4Media;
      widget.self
        ..videos.add(mediaID)
        ..save();
      loadMediaConsole(images: false);
    }
  }

  void loadMediaConsole({bool images = true, bool forGroupImage = false}) {
    _console = Console(
      bottomInputs: [consoleInput],
      images: true,
      selectMedia: (media) {
        if (forGroupImage) {
          _groupImage = media.asNodeMedia();
          loadBaseConsole();
          animatedTransition();
        } else {
          send(mediaInput: media);
        }
      },
      medias: images ? savedImages.toList() : savedVideos.toList(),
      topButtons: [
        ConsoleButton(name: "Import", onPress: handleImport),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
          isMode: true,
          isActivated: !forGroupImage,
          greyedOut: forGroupImage,
          name: images ? "Images" : "Videos",
          onPress: () => loadMediaConsole(images: !images),
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
        ConsoleButton(
          isMode: true,
          name: _private ? "Private" : "Public",
          onPress: () {
            _private = !_private;
            loadBaseConsole();
          },
        ),
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
                id: u.randomMediaID(),
                path: cachedPath,
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
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        scrollController: _scrollController,
        staticList: true,
        title: "Group",
        list: _items,
        console: _console!,
      ),
    ]);
  }
}
