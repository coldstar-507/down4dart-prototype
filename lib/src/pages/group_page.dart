import 'dart:async';
import 'dart:io';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:down4/src/data_objects.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../globals.dart';
import '../_down4_dart_utils.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/_down4_flutter_utils.dart';

class GroupPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "GroupPage";
  final List<Palette2> homePalettes, palettesForTransition;
  final Iterable<Person> people;
  final int nHidden;
  final void Function() back;
  final void Function(r.GroupRequest) groupRequest;
  final double initialOffset;

  const GroupPage({
    required this.people,
    required this.nHidden,
    required this.palettesForTransition,
    required this.back,
    required this.groupRequest,
    required this.homePalettes,
    required this.initialOffset,
    Key? key,
  }) : super(key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  // GlobalKey mediaModeKey = GlobalKey(); // TODO this button is not in group
  Console? _console;
  late List<Widget> _items = [...widget.homePalettes];
  var _tec = TextEditingController();
  var _tec2 = TextEditingController();
  bool _private = true;
  late final double offset = Palette.fullHeight * (widget.nHidden + 1);
  late var _scrollController = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );

  NodeMedia? _groupImage;
  String _groupName = "";

  MessageMedia? _cameraInput;

  ConsoleInput get consoleInput => ConsoleInput(placeHolder: ":)", tec: _tec);

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
    animatedTransition();
  }

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          print(
            "PALETTES FOR TRANSITION = ${widget.palettesForTransition.map((e) => e.node.name).toList()}",
          );
          _items = [...widget.palettesForTransition, groupMaker(fold: false)];
          _scrollController.jumpTo(widget.initialOffset + offset);
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

  PaletteMaker groupMaker({required bool fold}) {
    return PaletteMaker(
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
  }

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
      senderID: g.self.id,
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

  // Future<void> handleImport({
  //   bool groupImageImport = false,
  //   bool importImages = true,
  // }) async {
  //   if (importImages) {
  //     final result = await FilePicker.platform.pickFiles(
  //         allowMultiple: !groupImageImport,
  //         allowedExtensions: u.imageExtensions.withoutDots(),
  //         type: FileType.custom,
  //         withData: true);
  //     if (result == null) return;
  //     for (final file in result.files) {
  //       if (file.path == null || file.bytes == null) continue;
  //       final mediaID = u.deterministicMediaID(file.bytes!, g.self.id);
  //       final size = await decodeImageSize(file.bytes!);
  //       final mediaMetadata = MediaMetadata(
  //           owner: g.self.id,
  //           timestamp: u.timeStamp(),
  //           elementAspectRatio: 1 / size.aspectRatio,
  //           extension: file.path!.extension());
  //       if (groupImageImport) {
  //         _groupImage = NodeMedia(
  //             data: file.bytes!, id: mediaID, metadata: mediaMetadata);
  //         loadBaseConsole();
  //         reloadItems();
  //         // animatedTransition();
  //       } else {
  //         final f = await writeMedia(mediaData: file.bytes!, mediaID: mediaID);
  //         MessageMedia(id: mediaID, path: f.path, metadata: mediaMetadata)
  //           ..isSaved = true
  //           ..save();
  //         g.self.images.add(mediaID);
  //         loadMediaConsole();
  //       }
  //     }
  //     g.self.save();
  //   } else {
  //     final result = await FilePicker.platform.pickFiles(
  //         allowMultiple: true,
  //         allowedExtensions: u.videoExtensions.withoutDots(),
  //         type: FileType.custom,
  //         withData: true);
  //     if (result == null) return;
  //     for (final file in result.files) {
  //       if (file.path == null || file.bytes == null) continue;
  //       final fvi = FlutterVideoInfo();
  //       final mediaID = u.deterministicMediaID(file.bytes!, g.self.id);
  //       final f = await writeMedia(mediaData: file.bytes!, mediaID: mediaID);
  //       final videoInfo = await fvi.getVideoInfo(file.path!);
  //       final ar = (videoInfo?.width ?? 1.0) / (videoInfo?.height ?? 1.0);
  //       final tn =
  //           await VideoThumbnail.thumbnailData(video: f.path, quality: 90);
  //       String? thumbnailPath;
  //       if (tn != null) {
  //         final f = await writeMedia(
  //             mediaData: tn, mediaID: mediaID, isThumbnail: true);
  //         thumbnailPath = f.path;
  //       }
  //       MessageMedia(
  //           id: mediaID,
  //           path: f.path,
  //           isSaved: true,
  //           thumbnail: thumbnailPath,
  //           metadata: MediaMetadata(
  //               extension: file.path!.extension(),
  //               isSquared: false,
  //               isReversed: false,
  //               elementAspectRatio: ar,
  //               timestamp: u.timeStamp(),
  //               owner: g.self.id))
  //         ..isSaved = true
  //         ..save();
  //       g.self.videos.add(mediaID);
  //       loadMediaConsole(images: false);
  //     }
  //     g.self.save();
  //   }
  // }

  void reloadItems() {
    setState(() {
      _items = [
        ..._items.sublist(0, _items.length - 1),
        groupMaker(fold: false),
      ];
    });
  }

  void loadMediaConsole({bool images = true, bool forGroupImage = false}) {
    void selectMedia(MessageMedia media) {
      if (forGroupImage) {
        _groupImage = media.asNodeMedia();
        loadBaseConsole();
        reloadItems();
      } else {
        send(mediaInput: media);
      }
    }

    _console = Console(
      bottomInputs: [consoleInput],
      consoleMedias2: ConsoleMedias2(
          showImages: images, onSelectMedia: (media) => selectMedia(media)),
      topButtons: [
        ConsoleButton(
            name: "Import",
            onPress: () async {
              if (forGroupImage) {
                final nodeMedia = await importNodeMedia();
                if (nodeMedia != null) {
                  _groupImage = nodeMedia;
                  loadBaseConsole();
                  reloadItems();
                } else {
                  await importConsoleMedias(images: images);
                  loadMediaConsole();
                }
              }
            }),
      ],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () => loadBaseConsole(images: images),
        ),
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

  void loadBaseConsole({bool images = true}) {
    _console = Console(
      // mediasInfo: consoleMedias(images: images, show: false),
      bottomInputs: [consoleInput],
      topButtons: [
        ConsoleButton(
          isMode: true,
          isActivated: false,
          greyedOut: true,
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
                id: mediaID,
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
  void dispose() async {
    _cameraInput?.delete();
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
