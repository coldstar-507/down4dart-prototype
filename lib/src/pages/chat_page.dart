import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../boxes.dart';
import '../_down4_dart_utils.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class ChatPage extends StatefulWidget {
  final Map<Identifier, Palette> senders;
  final Self self;
  final ChatableNode node;
  final List<CameraDescription> cameras;
  final void Function(r.ChatRequest) send;
  final void Function() back;
  final Palette? Function(BaseNode, {String at}) nodeToPalette;
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
    this.pageIndex = 0,
    this.onPageChange,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Console? _console;
  ConsoleInput? _consoleInput;
  var _tec = TextEditingController();
  MessageMedia? _cameraInput;
  Map<Identifier, ChatMessage> _cachedMsgs = {};
  final _scollController = ScrollController();

  Future<void> _onRefresh() async {
    messages.skip(_cachedMsgs.length).take(40).toList();
    setState(() {});
  }

  late var _msgs = widget.node.messages.toList();
  late var _displayOrder = _msgs.reversed.toList();
  late var _msgLen = _msgs.length;
  var lastOffsetUpdate = 0.0;

  String? _idOfLastMessageRead;

  Iterable<ChatMessage> get loadedChatMessageWithVideos =>
      _cachedMsgs.values.where((msg) => msg.mediaInfo?.media.isVideo ?? false);

  @override
  void initState() {
    super.initState();
    messages.take(30).toList();
    loadBaseConsole();
  }

  @override
  void dispose() {
    for (final msg in loadedChatMessageWithVideos) {
      msg.mediaInfo!.videoController!.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
    setState(() {
      _msgs = widget.node.messages.toList();
      _displayOrder = _msgs.reversed.toList();
      _msgLen = _msgs.length;
      messages.take(1).toList();
    });
    print("Did update the chat page widget!");
  }

  ConsoleMedias consoleMedias({required bool images, required bool show}) {
    return ConsoleMedias(
      show: show,
      medias: images
          ? widget.self.images
              .map((mediaID) => mediaID.getLocalMessageMedia())
              .whereType<MessageMedia>()
          : widget.self.videos
              .map((mediaID) => mediaID.getLocalMessageMedia())
              .whereType<MessageMedia>(),
      onSelectMedia: (media) => send2(mediaInput: media),
      nMedias: images ? widget.self.images.length : widget.self.videos.length,
    );
  }

  ChatMessage? getChatMessage(
    Identifier msgID,
    Identifier? prevMsgID,
    Identifier? nextMsgID,
    bool isLast,
  ) {
    Message? msg = msgID.getLocalMessage();
    if (msg == null) return null;
    Message? prevMsg, nextMsg;
    ChatMessage? prevChatMessage = _cachedMsgs[prevMsgID];
    // If new message while in chat, we might want to remove the header of the
    // previous last message
    if (isLast &&
        prevMsgID != null &&
        prevChatMessage != null &&
        prevChatMessage.hasHeader &&
        msg.senderID == prevChatMessage.message.senderID &&
        msg.senderID != widget.self.id) {
      // we need to remove its header
      _cachedMsgs[prevMsgID] = prevChatMessage.withHeader(hasHeader: false);
      // and update it's size
    }

    if (_cachedMsgs[msgID] != null) return _cachedMsgs[msgID]!;

    prevMsg = prevMsgID?.getLocalMessage();
    nextMsg = nextMsgID?.getLocalMessage();

    bool hasGap = false;
    if (prevMsg != null) hasGap = ChatMessage.displayGap(msg, prevMsg);

    // mark as read
    if (!msg.isRead) {
      msg
        ..isRead = true
        ..save();
    } else {
      _idOfLastMessageRead ??= msg.id;
    }

    final bool senderIsSelf = msg.senderID == widget.self.id;
    final bool hasHeader = !senderIsSelf &&
        widget.node is GroupNode &&
        nextMsg?.senderID != msg.senderID;

    return _cachedMsgs[msg.id] = ChatMessage(
      key: GlobalKey(),
      hasGap: hasGap,
      message: msg,
      textInfo: ChatMessage.generateTextInfo(msg),
      mediaInfo: ChatMessage.generateMediaInfo(msg),
      repliesInfo: ChatMessage.generateRepliesInfo(msg, (replyID) {
        print("TODO, GO TO REPLY ID = $replyID");
      }),
      hasHeader: hasHeader,
      myMessage: widget.self.id == msg.senderID,
      select: (id) => setState(() {
        _cachedMsgs[id] = _cachedMsgs[id]!.invertedSelection();
      }),
    );
  }

  Iterable<ChatMessage?> get messages sync* {
    for (int i = _msgLen - 1; i >= 0; i--) {
      final Identifier msgID = _msgs[i];
      final Identifier? prevMsgID = i > 0 ? _msgs[i - 1] : null;
      final Identifier? nextMsgID = i < _msgLen - 1 ? _msgs[i + 1] : null;
      final isFirst = i == _msgLen - 1;
      yield getChatMessage(msgID, prevMsgID, nextMsgID, isFirst);
    }
  }

  ConsoleInput get consoleInput {
    return _consoleInput = ConsoleInput(
      maxLines: 7,
      tec: _tec,
      placeHolder: ":)",
    );
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
        print("THE PATH = ${file.path}");
        final mediaID = u.deterministicMediaID(file.bytes!, widget.self.id);
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
                owner: widget.self.id,
                elementAspectRatio: 1.0 / size.aspectRatio))
          ..isSaved = true
          ..save();
        widget.self.images.add(mediaID);
        loadMediasConsole();
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
        final mediaID = u.deterministicMediaID(video.bytes!, widget.self.id);
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
                owner: widget.self.id,
                elementAspectRatio:
                    (videoInfo?.width ?? 1.0) / (videoInfo?.height ?? 1.0)))
          ..isSaved = true
          ..save();
        widget.self.videos.add(mediaID);
        loadMediasConsole();
      }
    }
    widget.self.save();
  }

  void loadSavingConsole() {
    _console = Console(
      bottomInputs: [_consoleInput ?? consoleInput],
      topButtons: [
        ConsoleButton(
            name: "To Saved Messages",
            onPress: () {
              for (var msg in _cachedMsgs.values) {
                if (msg.selected) {
                  widget.self.messages.add(msg.message.id);
                  msg.message
                    ..isSaved = true
                    ..save();
                }
              }
              widget.self.save();
              unselectSelectedMessage();
              loadBaseConsole();
            })
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
            name: "To Medias",
            onPress: () {
              for (var msg in _cachedMsgs.values) {
                if (msg.selected && msg.hasMedia) {
                  if (msg.mediaInfo!.media.isVideo) {
                    widget.self.videos.add(msg.mediaInfo!.media.id);
                  } else {
                    widget.self.images.add(msg.mediaInfo!.media.id);
                  }
                  msg.mediaInfo!.media
                    ..isSaved = true
                    ..save();
                }
              }
              widget.self.save();
              unselectSelectedMessage();
              loadBaseConsole();
            }),
      ],
    );
    setState(() {});
  }

  void saveSelectedMessages() async {
    for (final msg in _cachedMsgs.values) {
      if (msg.selected) {
        _cachedMsgs[msg.message.id] = msg.invertedSelection();
        widget.self.messages.add(msg.message.id);
        msg.message
          ..isSaved = true
          ..save();
      }
    }
    widget.self.save();
    setState(() {});
  }

  void unselectSelectedMessage() {
    for (final key in _cachedMsgs.keys) {
      if (_cachedMsgs[key]?.selected ?? false) {
        _cachedMsgs[key] = _cachedMsgs[key]!.invertedSelection();
      }
    }
    setState(() {});
  }

  void send2({MessageMedia? mediaInput}) {
    if (_tec.value.text == "" && mediaInput == null && _cameraInput == null) {
      return;
    }
    final ts = u.timeStamp();
    final targets = widget.node.calculateTargets(widget.self.id);

    var msg = Message(
      root: widget.node is GroupNode ? widget.node.id : null,
      id: messagePushId(),
      timestamp: ts,
      senderID: widget.self.id,
      mediaID: mediaInput?.id ?? _cameraInput?.id,
      text: _tec.value.text,
      replies: _cachedMsgs.values
          .where((msg) => msg.selected)
          .map((msg) => msg.message.id)
          .toList(growable: false),
    );

    unselectSelectedMessage();

    var req = r.ChatRequest(
      message: msg,
      targets: targets.toList(),
      media: mediaInput ?? _cameraInput,
    );

    widget.send(req);
    _tec.clear();
    _cameraInput = null;
  }

  Future<void> loadFullCamera() async {
    // TODO
  }

  Future<void> loadSquaredCameraConsole({
    CameraController? ctrl,
    int cam = 0,
    String? path,
  }) async {
    if (ctrl == null) {
      try {
        ctrl = CameraController(widget.cameras[cam], ResolutionPreset.medium);
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
            name: cam == 0 ? "Front" : "Rear",
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
            final media = await copyMedia(fromPath: path, mediaID: mediaID);
            if (path.extension().isVideoExtension()) {
              final tn = await makeThumbnail(videoPath: path, mediaID: mediaID);
              thumbnailPath = tn?.path;
            }
            vpc?.dispose();
            _cameraInput = MessageMedia(
                path: media.path,
                thumbnail: thumbnailPath,
                id: mediaID,
                metadata: MediaMetadata(
                    owner: widget.self.id,
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

  void loadMediasConsole({
    bool images = true,
    String mode = "Send",
    bool extra = false,
  }) {
    void switchMode() => mode == "Send"
        ? loadMediasConsole(images: images, mode: "Delete", extra: true)
        : loadMediasConsole(images: images, mode: "Send", extra: true);

    void selectMedia(MessageMedia media) {
      if (mode == "Send") return send2(mediaInput: media);
      if (!media.isVideo) {
        widget.self.images.remove(media.id);
      } else {
        widget.self.videos.remove(media.id);
      }
      media
        ..isSaved = false
        ..delete();
      loadMediasConsole(images: images, mode: mode, extra: extra);
    }

    _console = Console(
      mediasInfo: consoleMedias(images: images, show: true),
      bottomInputs: [_consoleInput ?? consoleInput],
      topButtons: [
        ConsoleButton(
          name: "Import",
          onPress: () => handleImport(importImages: images),
        ),
      ],
      bottomButtons: [
        ConsoleButton(
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
      mediasInfo: consoleMedias(images: images, show: false),
      bottomInputs: [_consoleInput ?? consoleInput],
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

  @override
  Widget build(BuildContext context) {
    List<Down4Page> pages = widget.node is GroupNode
        ? [
            Down4Page(
              isChatPage: true,
              title: widget.node.name,
              console: _console!,
              asMap: _cachedMsgs,
              orderedKeys: _displayOrder,
              iterableLen: _cachedMsgs.length,
              onRefresh: _onRefresh,
            ),
            Down4Page(
              title: "Members",
              console: _console!,
              list: widget.senders.values.toList(),
            ),
          ]
        : [
            Down4Page(
              isChatPage: true,
              title: widget.node.name,
              console: _console!,
              asMap: _cachedMsgs,
              orderedKeys: _displayOrder,
              iterableLen: _cachedMsgs.length,
              onRefresh: _onRefresh,
            ),
          ];

    return Andrew(
      initialPageIndex: widget.pageIndex,
      pages: pages,
      onPageChange: (int newPageIndex) {
        for (final msg in loadedChatMessageWithVideos) {
          _cachedMsgs[msg.message.id] =
              _cachedMsgs[msg.message.id]!.onPageTransition();
        }
        widget.onPageChange?.call(newPageIndex);
      },
    );
  }
}
