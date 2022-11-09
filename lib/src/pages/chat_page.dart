import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

import '../boxes.dart';
import '../down4_utility.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/lists.dart';
import '../render_objects/navigator.dart';

class ChatPage extends StatefulWidget {
  final Map<Identifier, Palette> senders;
  final User self;
  final ChatableNode node;
  final List<Palette> group;
  final List<CameraDescription> cameras;
  final void Function(r.ChatRequest) send;
  final void Function() back;
  final Palette? Function(BaseNode, String) nodeToPalette;
  final int pageIndex;
  final Function(int)? onPageChange;

  const ChatPage({
    required this.senders,
    required this.node,
    required this.send,
    required this.self,
    required this.back,
    required this.cameras,
    required this.nodeToPalette,
    required this.group,
    this.pageIndex = 0,
    this.onPageChange,
    Key? key,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Console? _console;
  ConsoleInput? _consoleInput;
  var tec = TextEditingController();
  Down4Media? _cameraInput, _mediaInput;
  Map<Identifier, Down4Media> _cachedMedias = {};
  Map<Identifier, ChatMessage> _cachedMessages = {};

  Map<Identifier, Down4Media> _cachedImages = {};
  Map<Identifier, Down4Media> _cachedVideos = {};

  List<Down4Media> get savedImages {
    if (_cachedImages.isEmpty && b.images.keys.isEmpty) {
      return <Down4Media>[];
    } else if (_cachedImages.values.isEmpty && b.images.keys.isNotEmpty) {
      for (final mediaID in b.images.keys) {
        _cachedImages[mediaID] = b.loadSavedImage(mediaID);
      }
      return _cachedImages.values.toList();
    } else {
      return _cachedImages.values.toList();
    }
  }

  List<Down4Media> get savedVideos {
    if (_cachedVideos.isEmpty && b.videos.keys.isEmpty) {
      return <Down4Media>[];
    } else if (_cachedVideos.values.isEmpty && b.videos.keys.isNotEmpty) {
      for (final mediaID in b.videos.keys) {
        _cachedVideos[mediaID] = b.loadSavedVideo(mediaID);
      }
      return _cachedVideos.values.toList();
    } else {
      return _cachedVideos.values.toList();
    }
  }

  ConsoleInput get consoleInput => _consoleInput = ConsoleInput(
        tec: tec,
        inputCallBack: (t) => null,
        placeHolder: ":)",
      );

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
        _cachedMedias[mediaID] = Down4Media(
          id: mediaID,
          data: compressedData,
          metadata: MediaMetadata(owner: widget.self.id, timestamp: ts),
        );
        Boxes.instance.saveImage(_cachedMedias[mediaID]!);
      }
    }
    setState(() {});
  }

  void saveSelectedMessages() async {
    for (final msg in _cachedMessages.values) {
      if (msg.selected) {
        _cachedMessages[msg.message.id] = msg.invertedSelection();
        final media = msg.media;
        if (media != null) {
          final save = media.metadata.isVideo ? b.saveVideo : b.saveImage;
          save(media);
        }
      }
    }
    setState(() {});
  }

  void send2() {
    if (tec.value.text != "" || _mediaInput != null || _cameraInput != null) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final targets = widget.node.targets(widget.self.id);

      var msg = Down4Message(
        type: Messages.chat,
        id: u.generateMessageID(widget.self.id, ts),
        timestamp: ts,
        senderID: widget.self.id,
        mediaID: _mediaInput?.id ?? _cameraInput?.id,
        text: tec.value.text,
      );

      var req = r.ChatRequest(
        message: msg,
        targets: targets,
        media: _mediaInput ?? _cameraInput,
      );

      widget.send(req);
      tec.clear();
    }
  }

  void getTheMedia(Identifier mediaID, Identifier msgID) async {
    var media = await getMessageMediaFromEverywhere(mediaID);
    if (media == null) return;
    _cachedMessages[msgID] = _cachedMessages[msgID]!.withMedia(media);
    setState(() {});
  }

  MessageList4 get messageList => MessageList4(
        senders: widget.senders,
        messages: (widget.node.messages ?? <String>[]).reversed.toList(),
        self: widget.self,
        messageMap: _cachedMessages,
        cache: (msg) => _cachedMessages[msg.message.id] = msg,
        getTheMedia: getTheMedia,
        select: (id, _) {
          _cachedMessages[id] = _cachedMessages[id]!.invertedSelection();
          setState(() {});
        },
      );

  Future<void> camConsole([
    CameraController? ctrl,
    int cameraIdx = 0,
    ResolutionPreset resolution = ResolutionPreset.medium,
    FlashMode flashMode = FlashMode.off,
    bool reloadCtrl = false,
  ]) async {
    if (ctrl == null || reloadCtrl) {
      try {
        ctrl = CameraController(
          widget.cameras[cameraIdx],
          resolution,
          enableAudio: true,
        );
        await ctrl.initialize();
      } catch (err) {
        baseConsole();
      }
    }

    ctrl?.setFlashMode(flashMode);

    void nextCam() =>
        camConsole(ctrl, (cameraIdx + 1) % 2, resolution, FlashMode.off, true);

    // void nextCam() => cameraIdx == 0
    //     ? camConsole(ctrl, 1, resolution, FlashMode.off, true)
    //     : camConsole(ctrl, 0, resolution, FlashMode.off, true);

    void nextRes() async {
      switch (resolution) {
        case ResolutionPreset.low:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.medium, flashMode, true);
        case ResolutionPreset.medium:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.high, flashMode, true);
        case ResolutionPreset.high:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.low, flashMode, true);
        case ResolutionPreset.veryHigh:
          // TODO: Handle this case.
          break;
        case ResolutionPreset.ultraHigh:
          // TODO: Handle this case.
          break;
        case ResolutionPreset.max:
          // TODO: Handle this case.
          break;
      }
    }

    void nextFlash() => flashMode == FlashMode.off
        ? camConsole(ctrl, cameraIdx, resolution, FlashMode.torch)
        : camConsole(ctrl, cameraIdx, resolution, FlashMode.off);

    if (_cameraInput == null) {
      _console = Console(
        cameraController: ctrl,
        aspectRatio: ctrl?.value.aspectRatio,
        topButtons: [
          ConsoleButton(
            name: cameraIdx == 0 ? "Front" : "Rear",
            onPress: nextCam,
            isMode: true,
          ),
          ConsoleButton(
            name: "Capture",
            onPress: () async {
              XFile? f = await ctrl?.takePicture();
              if (f != null) {
                _cameraInput = Down4Media.fromCamera(
                  f.path,
                  MediaMetadata(
                    owner: widget.self.id,
                    timestamp: u.timeStamp(),
                    isVideo: false,
                    toReverse: cameraIdx == 1,
                  ),
                );
                camConsole(ctrl, cameraIdx, resolution, FlashMode.off, false);
              }
            },
            onLongPress: () async => await ctrl?.startVideoRecording(),
            onLongPressUp: () async {
              XFile? f = await ctrl?.stopVideoRecording();
              if (f != null) {
                _cameraInput = Down4Media.fromCamera(
                  f.path,
                  MediaMetadata(
                    owner: widget.self.id,
                    timestamp: u.timeStamp(),
                    isVideo: true,
                    toReverse: cameraIdx == 1,
                  ),
                );
                camConsole(ctrl, cameraIdx, resolution, FlashMode.off, false);
              }
            },
            shouldBeDownButIsnt: ctrl?.value.isRecordingVideo ?? false,
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: baseConsole),
          ConsoleButton(
            name: resolution.name.capitalize(),
            onPress: nextRes,
            isMode: true,
          ),
          ConsoleButton(
            name: flashMode.name.capitalize(),
            onPress: nextFlash,
            isMode: true,
          ),
        ],
      );
    } else {
      String? imPrev;
      VideoPlayerController? videoCtrl;
      if (_cameraInput!.metadata.isVideo) {
        videoCtrl = VideoPlayerController.file(_cameraInput!.file!);
        await videoCtrl.initialize();
        await videoCtrl.setLooping(true);
        await videoCtrl.play();
      } else {
        imPrev = _cameraInput!.path;
      }
      _console = Console(
        imagePreviewPath: imPrev,
        videoPlayerController: videoCtrl,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () {
              videoCtrl?.dispose();
              ctrl?.dispose();
              baseConsole();
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            onPress: () {
              videoCtrl?.dispose();
              _cameraInput = null;
              camConsole(ctrl, cameraIdx, resolution, flashMode, false);
            },
          ),
          ConsoleButton(
              name: "Cancel",
              onPress: () {
                videoCtrl?.dispose();
                ctrl?.dispose();
                baseConsole();
              }),
        ],
      );
    }
    setState(() {});
  }

  void baseConsole() {
    _console = Console(
      inputs: [_consoleInput ?? consoleInput],
      topButtons: [
        ConsoleButton(name: "Save", onPress: saveSelectedMessages),
        ConsoleButton(
          name: "Send",
          onPress: () {
            send2();
            baseConsole();
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _cameraInput == null ? "Camera" : "@Camera",
          onPress: camConsole,
        ),
        ConsoleButton(
          name: "Medias",
          onPress: mediasConsole,
        ),
      ],
    );
    setState(() {});
  }

  void mediasConsole([bool images = true]) {
    _console = Console(
      images: true,
      medias: images ? savedImages : savedVideos,
      selectMedia: (media) {
        _mediaInput = media;
        send2();
      },
      topButtons: [
        ConsoleButton(name: "Import", onPress: handleImport),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: baseConsole),
        ConsoleButton(
          isMode: true,
          name: images ? "Images" : "Videos",
          onPress: () => mediasConsole(!images),
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_console == null) baseConsole();

    if (widget.group.isNotEmpty) {
      print("IT'S A FUCKING GROUP YOU FUCKING FAGGOT, STOP FUCKING AROUND!");
    }

    List<Down4Page> pages = widget.group.isEmpty
        ? [
            Down4Page(
              title: widget.node.name,
              console: _console!,
              messageList: messageList,
            ),
          ]
        : [
            Down4Page(
              title: widget.node.name,
              console: _console!,
              messageList: messageList,
            ),
            Down4Page(
                title: "People", console: _console!, palettes: widget.group),
          ];

    return Jeff(
      initialPageIndex: widget.pageIndex,
      pages: pages,
      onPageChange: widget.onPageChange,
    );
  }
}
