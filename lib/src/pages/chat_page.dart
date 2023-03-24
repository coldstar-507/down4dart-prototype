import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../globals.dart';
import '../_down4_dart_utils.dart' as u;

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../bsv/utils.dart' show sha1;

class ChatPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "chat-${node.id}";

  final Chatable node;
  // final List<BaseNode>? subNodes;
  final Map<ID, ChatMessage> messages;
  final Map<ID, Palette2> members;
  final List<ID> ordered;
  final List<Down4Object>? fo;
  final void Function(int) onPageChange;
  final void Function() back;
  final Future<void> Function([int limit]) loadMore;
  final void Function(FireNode) openNode;
  final void Function(Payload) send;

  const ChatPage({
    // required this.subNodes,
    required this.loadMore,
    required this.ordered,
    required this.members,
    required this.messages,
    required this.onPageChange,
    required this.back,
    required this.send,
    required this.node,
    required this.openNode,
    this.fo,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  GlobalKey mediaModeKey = GlobalKey();
  GlobalKey mediaForwardModeKey = GlobalKey();
  late Console _console;
  late ConsoleInput _consoleInput = consoleInput;
  var _tec = TextEditingController();
  FireMedia? _cameraInput;
  List<ID> _msgsWithVideos = [];
  // List<ID> loaded = [];

  late ScrollController scroller0 =
      ScrollController(initialScrollOffset: g.vm.cv.pages[0].scroll)
        ..addListener(() {
          g.vm.cv.pages[0].scroll = scroller0.offset;
        });

  late ScrollController? scroller1 = widget.node is Groupable
      ? (ScrollController(initialScrollOffset: g.vm.cv.pages[1].scroll)
        ..addListener(() {
          g.vm.cv.pages[1].scroll = scroller1!.offset;
        }))
      : null;

  Future<List<ButtonsInfo2>> buttonsOfNode(FireNode node) async {
    return [
      ButtonsInfo2(
          asset: g.fifty,
          pressFunc: () => widget.openNode(node),
          rightMost: true)
    ];
  }

  var lastOffsetUpdate = 0.0;

  String? _idOfLastMessageRead;

  @override
  void initState() {
    super.initState();
    if (widget.fo != null) {
      loadForwardingConsole();
    } else {
      loadBaseConsole();
    }
  }

  @override
  void dispose() {
    scroller0.dispose();
    scroller1?.dispose();
    _cameraInput?.delete();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
  }

  ConsoleInput get consoleInput {
    return ConsoleInput(
      maxLines: 7,
      tec: _tec,
      placeHolder: ":)",
    );
  }

  void loadSavingConsole() {
    _console = Console(
      bottomInputs: [_consoleInput],
      topButtons: [
        ConsoleButton(
            name: "To Saved Messages",
            onPress: () async {
              for (var chat in widget.messages.values.selected()) {
                chat.message.updateSavedStatus(true);
              }
              // g.self.save();
              unselectSelectedMessage();
              loadBaseConsole();
            })
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
            name: "To Medias",
            onPress: () {
              final selectedMedias = widget.messages.values
                  .selected()
                  .where((chat) => chat.hasMedia)
                  .map((chat) => chat.mediaInfo!.media);
              for (final media in selectedMedias) {
                media.updateSaveStatus(true);
              }
              // g.self.save();
              unselectSelectedMessage();
              loadBaseConsole();
            }),
      ],
    );
    setState(() {});
  }

  void unselectSelectedMessage() {
    for (final key in widget.messages.keys) {
      if (widget.messages[key]?.selected ?? false) {
        widget.messages[key] = widget.messages[key]!.invertedSelection();
      }
    }
    setState(() {});
  }

  Future<void> send2({FireMedia? mediaInput, List<Down4Object>? fo}) async {
    final media = mediaInput ?? _cameraInput;
    final text = _tec.value.text;
    if (text == "" && media != null && fo != null) return;

    final r = widget.messages.values.selected().asIDs().toList();

    final p = Payload(m: media, t: _tec.value.text, f: fo, r: r);

    widget.send(p);

    unselectSelectedMessage();
    _cameraInput = null;
    _tec.clear();

    loadBaseConsole();
  }

  Future<void> loadFullCamera() async {
    // TODO
  }

  Future<void> loadSquaredCameraConsole({
    CameraController? ctrl,
    int cam = 0,
    String? path,
    String? mimetype,
  }) async {
    if (ctrl == null) {
      try {
        ctrl = CameraController(g.cameras[cam], ResolutionPreset.medium);
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
              loadSquaredCameraConsole(
                  ctrl: ctrl, cam: cam, path: f.path, mimetype: f.mimeType);
            },
            onLongPress: () async {
              await ctrl!.startVideoRecording();
              loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
            },
            onLongPressUp: () async {
              final XFile f = await ctrl!.stopVideoRecording();
              loadSquaredCameraConsole(
                  ctrl: ctrl, cam: cam, path: f.path, mimetype: f.mimeType);
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
            Uint8List? tn;
            final Uint8List data = File(path).readAsBytesSync();
            final mediaID = u.deterministicMediaID(data, g.self.id);
            bool isVideo = path.extension().isVideoExtension();
            if (isVideo) {
              tn = await VideoThumbnail.thumbnailData(video: path, quality: 90);
            }
            vpc?.dispose();
            final tiny = resizeImage(isVideo ? tn! : data, 20, 20);
            final newMedia = FireMedia(mediaID,
                tinyThumbnail: base64Encode(tiny),
                mimetype: mimetype!,
                owner: g.self.id,
                timestamp: u.timeStamp(),
                aspectRatio: ctrl!.value.aspectRatio,
                extension: path.extension(),
                isReversed: cam == 1,
                references: {},
                isSquared: true);
            await newMedia.write(
                videoData: isVideo ? data : null,
                imageData: isVideo ? tn : data);
            _cameraInput = newMedia;
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

  void loadMediasConsole({
    bool images = true,
    String mode = "Send",
    bool extra = false,
  }) {
    void switchMode() => mode == "Send"
        ? loadMediasConsole(images: images, mode: "Remove", extra: true)
        : loadMediasConsole(images: images, mode: "Send", extra: true);

    void selectMedia(FireMedia media) {
      if (mode == "Send") {
        send2(mediaInput: media);
        return;
      } else if (mode == "Remove") {
        media.updateSaveStatus(false);
      }
      // if (!media.isVideo) {
      //   g.self.images.remove(media.id);
      // } else {
      //   g.self.videos.remove(media.id);
      // }
      // media
      //   ..isSaved = false
      loadMediasConsole(images: images, mode: mode, extra: extra);
    }

    _console = Console(
      consoleMedias2: ConsoleMedias2(showImages: images, onSelect: selectMedia),
      bottomInputs: [_consoleInput],
      topButtons: [
        ConsoleButton(
          name: "Import",
          onPress: () async {
            await importConsoleMedias(images: images);
            loadMediasConsole(images: images, mode: mode, extra: extra);
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(
          key: mediaModeKey,
          showExtra: extra,
          isSpecial: true,
          name: "Back",
          onPress: () => extra
              ? loadMediasConsole(images: images, mode: mode, extra: !extra)
              : loadBaseConsole(),
          onLongPress: () =>
              loadMediasConsole(images: images, mode: mode, extra: true),
          extraButtons: [
            ConsoleButton(name: mode, onPress: switchMode, isMode: true),
          ],
        ),
        ConsoleButton(
          isMode: true,
          name: images ? "Images" : "Videos",
          onPress: () => loadMediasConsole(images: !images),
        ),
      ],
    );
    setState(() {});
  }

  void loadBaseConsole({bool images = true}) {
    _console = Console(
      bottomInputs: [_consoleInput],
      topButtons: [
        ConsoleButton(name: "Save", onPress: loadSavingConsole),
        ConsoleButton(
          name: "Send",
          onPress: () {
            send2();
            loadBaseConsole();
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _cameraInput == null ? "Camera" : "@Camera",
          onPress: () => loadSquaredCameraConsole(cam: 0),
        ),
        ConsoleButton(
          name: "Medias",
          onPress: () => loadMediasConsole(images: images),
        ),
      ],
    );
    setState(() {});
  }

  void loadForwardingConsole({
    List<Down4Object>? fObjects,
    bool extra = false,
  }) {
    final f = fObjects ?? widget.fo;
    if (f == null) return loadBaseConsole();
    _console = Console(
      bottomInputs: [_consoleInput],
      forwardingObjects: f.toList(),
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          key: mediaForwardModeKey,
          name: "Forward",
          onPress: () {
            if (extra) {
              loadForwardingConsole(extra: !extra, fObjects: f);
            } else {
              final r = widget.messages.values.selected().asIDs().toList();
              widget.send(Payload(m: null, r: r, f: f, t: _tec.value.text));
            }
          },
          onLongPress: () => loadForwardingConsole(extra: !extra, fObjects: f),
          isSpecial: true,
          showExtra: extra,
          extraButtons: [
            ConsoleButton(
                name: "Medias",
                onPress: () => loadForwardingMediasConsole(fObjects: f)),
          ],
        )
      ],
    );
    setState(() {});
  }

  void loadForwardingMediasConsole({
    required List<Down4Object> fObjects,
    bool images = true,
  }) {
    _console = Console(
      bottomInputs: [consoleInput],
      consoleMedias2: ConsoleMedias2(
          showImages: images,
          onSelect: (media) => send2(mediaInput: media, fo: fObjects)),
      forwardingObjects: fObjects.toList(),
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () => loadForwardingConsole(fObjects: fObjects),
        ),
        ConsoleButton(
          name: images ? "Images" : "Videos",
          onPress: () =>
              loadForwardingMediasConsole(fObjects: fObjects, images: !images),
        )
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.node is Groupable
        ? [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: widget.node.displayName,
                console: _console,
                asMap: widget.messages,
                orderedKeys: widget.ordered,
                onRefresh: widget.loadMore),
            Down4Page(
              scrollController: scroller1,
              title: "Members",
              console: _console,
              list: widget.members.values.toList(),
            ),
          ]
        : [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: widget.node.displayName,
                console: _console,
                asMap: widget.messages,
                orderedKeys: widget.ordered,
                onRefresh: widget.loadMore)
          ];

    return Andrew(
      pages: pages,
      initialPageIndex: g.vm.cv.ci,
      onPageChange: widget.onPageChange,
    );
  }
}
