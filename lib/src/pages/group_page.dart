import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show utf8;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:down4/src/data_objects.dart';
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
  final User self;
  // final List<Palette> Function() transition;
  final List<Palette> palettes, transitioned;
  final Iterable<User> userTargets;
  // final void Function(Group) afterMessageCallback;
  final void Function() back;
  final void Function(r.GroupRequest) groupRequest;
  final double initialOffset;

  const GroupPage({
    // required this.transition,
    required this.userTargets,
    required this.transitioned,
    required this.self,
    // required this.afterMessageCallback,
    required this.back,
    required this.groupRequest,
    required this.palettes,
    required this.cameras,
    required this.initialOffset,
    Key? key,
  }) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  Console? console;
  CameraController? ctrl;
  late List<Widget> items = [...widget.palettes, groupMaker(fold: true)];
  var tec = TextEditingController();
  var tec2 = TextEditingController();
  bool private = true;
  late var scrollController =
      ScrollController(initialScrollOffset: widget.initialOffset);

  Map<Identifier, Down4Media> _cachedImages = {};
  Map<Identifier, Down4Media> _cachedVideos = {};

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

  Down4Media? groupImage;
  String groupName = "";

  Down4Media? cameraInput;

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
    animatedTransition();
    asyncImageLoad();
  }

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          items = [...widget.transitioned, groupMaker(fold: false)];
          scrollController.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

  PaletteMaker groupMaker({required bool fold}) => PaletteMaker(
        fold: fold,
        colorCode: NodesColor.group,
        tec: tec2,
        id: "",
        name: groupName,
        hintText: "Group Name",
        image: groupImage,
        nameCallBack: (name) => setState(() => groupName = name),
        type: Nodes.group,
        imagePress: () => loadMediaConsole(forGroupImage: true),
      );

  ConsoleInput get singleInput => ConsoleInput(placeHolder: ":)", tec: tec);

  void send({Down4Media? mediaInput}) {
    if (groupImage == null || groupName.isEmpty) return;
    if (cameraInput == null && tec.value.text.isEmpty && mediaInput == null) {
      return;
    }

    final msg = Down4Message(
      type: Messages.chat,
      id: messagePushId(),
      senderID: widget.self.id,
      timestamp: u.timeStamp(),
      mediaID: mediaInput?.id ?? cameraInput?.id,
      text: tec.value.text,
    );

    final groupID =
        sha256(utf8.encode(groupName + groupImage!.id + msg.id)).toBase58();

    final grpReq = r.GroupRequest(
      groupID: groupID,
      name: groupName,
      groupMedia: groupImage!,
      message: msg,
      private: private,
      targets: widget.userTargets.asIds().toList()..remove(widget.self.id),
      media: mediaInput ?? cameraInput,
    );

    widget.groupRequest(grpReq);
  }

  // Future<void> handleImport({required bool importImages}) async {
  //   if (importImages) {
  //     final files = await ImagePicker().pickMultiImage(
  //       maxWidth: 512,
  //       maxHeight: 512,
  //       imageQuality: 70,
  //       requestFullMetadata: false,
  //     );
  //     for (final file in files) {
  //       final bytes = await file.readAsBytes();
  //       final decodedImage = await decodeImageFromList(bytes);
  //       final mediaID = u.generateMediaID(bytes);
  //       final down4Media = Down4Media(
  //         id: mediaID,
  //         data: bytes,
  //         metadata: MediaMetadata(
  //           timestamp: u.timeStamp(),
  //           owner: widget.self.id,
  //           aspectRatio: decodedImage.height / decodedImage.width,
  //         ),
  //       )..save(toPersonal: true);
  //       _cachedImages[mediaID] = down4Media;
  //     }
  //   } else {
  //     final video = await ImagePicker().pickVideo(
  //       source: ImageSource.gallery,
  //       maxDuration: const Duration(seconds: 15),
  //     );
  //     if (video == null) return;
  //     final bytes = await video.readAsBytes();
  //     final mediaID = u.generateMediaID(bytes);
  //     final down4Media = Down4Media(
  //       id: mediaID,
  //       data: bytes,
  //       metadata: MediaMetadata(
  //         timestamp: u.timeStamp(),
  //         owner: widget.self.id,
  //         isVideo: true,
  //       ),
  //     );
  //     _cachedVideos[mediaID] = down4Media;
  //   }
  //   loadMediaConsole();
  // }

  Future<void> handleImport(
      {bool groupImageImport = false, bool importImages = true}) async {
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
        );
        if (groupImageImport) {
          groupImage = down4Media;
          loadBaseConsole();
          animatedTransition();
        } else {
          down4Media.save(toPersonal: true);
          _cachedImages[mediaID] = down4Media;
          loadMediaConsole();
        }
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
      )..save(toPersonal: true);
      _cachedVideos[mediaID] = down4Media;
      loadMediaConsole(images: false);
    }
  }

  void loadMediaConsole({bool images = true, bool forGroupImage = false}) {
    console = Console(
      inputs: [singleInput],
      images: true,
      selectMedia: (media) {
        if (forGroupImage) {
          groupImage = media;
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
    console = Console(
      inputs: [singleInput],
      topButtons: [
        ConsoleButton(
          isMode: true,
          name: private ? "Private" : "Public",
          onPress: () {
            private = !private;
            loadBaseConsole();
          },
        ),
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
      inputs: [singleInput],
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
      inputs: [singleInput],
      aspectRatio: ctrl?.value.aspectRatio,
      cameraController: ctrl,
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
    ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        scrollController: scrollController,
        staticList: true,
        title: "Group",
        columnWidgets: items,
        console: console!,
      ),
    ]);
  }
}
