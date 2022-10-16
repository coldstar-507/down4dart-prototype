import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

import '../boxes.dart';
import '../down4_utility.dart' as u;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/utils.dart';


class GroupPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Node self;
  final List<Palette> palettes;
  final void Function(Node) afterMessageCallback;
  final void Function() back;
  final Future<bool> Function(GroupRequest) groupRequest;

  const GroupPage({
    required this.self,
    required this.afterMessageCallback,
    required this.back,
    required this.groupRequest,
    required this.palettes,
    required this.cameras,
    Key? key,
  }) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  Console? console;
  ConsoleInput? singleInput;
  CameraController? ctrl;
  List<Widget> items = [];
  var tec = TextEditingController();
  var tec2 = TextEditingController();
  bool private = true;

  Map<Identifier, Down4Media> cachedImages = {};
  Map<Identifier, Down4Media> cachedVideos = {};

  List<Down4Media> get savedImages {
    if (cachedImages.isEmpty && b.images.keys.isEmpty) {
      return <Down4Media>[];
    } else if (cachedImages.values.isEmpty && b.images.keys.isNotEmpty) {
      for (final mediaID in b.images.keys) {
        cachedImages[mediaID] = b.loadSavedImage(mediaID);
      }
      return cachedImages.values.toList();
    } else {
      return cachedImages.values.toList();
    }
  }

  List<Down4Media> get savedVideos {
    if (cachedVideos.isEmpty && b.videos.keys.isEmpty) {
      return <Down4Media>[];
    } else if (cachedVideos.values.isEmpty && b.videos.keys.isNotEmpty) {
      for (final mediaID in b.videos.keys) {
        cachedVideos[mediaID] = b.loadSavedVideo(mediaID);
      }
      return cachedVideos.values.toList();
    } else {
      return cachedVideos.values.toList();
    }
  }

  Down4Media? groupImage;
  Down4Media? mediaInput;
  String groupName = "";

  @override
  void initState() {
    super.initState();
    loadBaseConsole();
    loadPalettes();
  }

  PaletteMaker groupMaker() => PaletteMaker(
    tec: tec2,
    id: "",
    // will calculate the ID on hyperchat creation for hyperchats
    name: groupName,
    hintText: "Group Name",
    image: groupImage?.data ?? Uint8List(0),
    nameCallBack: (name) => setState(() => groupName = name),
    type: Nodes.group,
    imageCallBack: (data) {
      final dataForID = widget.self.id.codeUnits + data.toList();
      final imageID = u.generateMediaID(dataForID.asUint8List());
      groupImage = Down4Media(
        data: data,
        id: imageID,
        metadata: MediaMetadata(
          owner: widget.self.id,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      loadPalettes();
    },
  );

  void loadPalettes() {
    items.clear();
    items.add(groupMaker());
    items.addAll(widget.palettes);
    setState(() {});
  }

  void send() {
    if (mediaInput == null && tec.value.text.isEmpty) return;
    if (groupImage == null || groupName.isEmpty) return;

    final selfID = widget.self.id;
    final targets = widget.palettes.asIds();

    final msg = Down4Message(
      type: Messages.chat,
      id: messagePushId(),
      senderID: selfID,
      timestamp: u.timeStamp(),
      mediaID: mediaInput?.id,
      text: tec.value.text,
    );

    final grpReq = GroupRequest(
      name: groupName,
      groupImage: groupImage!,
      msg: msg,
      private: private,
      targets: targets,
      media: mediaInput,
    );

    widget.groupRequest(grpReq);
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
    setState(() {});
  }

  void loadMediaConsole([bool images = true]) {
    console = Console(
      images: true,
      selectMedia: (media) {
        mediaInput = media;
        send();
      },
      medias: images ? savedImages : savedVideos,
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
      inputs: [ConsoleInput(placeHolder: ":)", tec: tec)],
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
            mediaInput = Down4Media.fromCamera(
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
            mediaInput = Down4Media.fromCamera(
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
    await ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Jeff(pages: [
      Down4Page(title: "Group", columnWidgets: items, console: console!),
    ]);
  }
}
