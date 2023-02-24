import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';
import 'package:down4/src/render_objects/profile.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../globals.dart';
import '../_down4_dart_utils.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

class ChatPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "c-${node.id}";

  final void Function(r.ChatRequest) send;
  final ChatableNode node;
  final Iterable<BaseNode>? subNodes;
  final void Function() back;
  final void Function(BaseNode) openNode;

  const ChatPage({
    // required this.senders,
    // required this.node,
    required this.subNodes,
    required this.send,
    required this.back,
    required this.node,
    required this.openNode,
    // required this.nodeToPalette,
    // this.pageIndex = 0,
    // this.onPageChange,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  GlobalKey mediaModeKey = GlobalKey();
  late Console _console;
  late ConsoleInput _consoleInput = consoleInput;
  var _tec = TextEditingController();
  MessageMedia? _cameraInput;
  List<ID> _msgsWithVideos = [];
  List<ID> loaded = [];

  late List<ID> mIds;
  late List<ID> ordered;

  Future<void> _loadSome() async {
    final nTotal = mIds.length;
    final nLoaded = loaded.length;
    final nToLoad = nLoaded + 30 < nTotal ? nLoaded + 30 : nTotal;
    final toLoad = ordered.sublist(nLoaded, nToLoad);
    await messages2(toLoad).toList();
    if (mounted) setState(() {});
  }

  Future<List<ButtonsInfo2>> buttonsOfNode(BaseNode node) async {
    return [
      ButtonsInfo2(
          assetPath: 'assets/images/50.png',
          pressFunc: () => widget.openNode(node),
          rightMost: true)
    ];
  }

  Map<ID, ChatMessage> _cachedMessages = {};

  Map<ID, Palette2> _members = {};

  void reload() => setState(() {});

  var lastOffsetUpdate = 0.0;

  String? _idOfLastMessageRead;

  @override
  void initState() {
    super.initState();
    mIds = widget.node.messages.toList();
    ordered = mIds.reversed.toList();
    _loadSome();
    loadMembers();
    loadBaseConsole();
  }

  @override
  void dispose() {
    for (final msgID in _msgsWithVideos) {
      _cachedMessages[msgID]?.mediaInfo?.videoController?.dispose();
    }
    _cameraInput?.delete();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
    mIds = widget.node.messages.toList();
    ordered = mIds.reversed.toList();
    reloadOne();
    print("DID UPDATE THE WIDGET");
  }

  Future<void> reloadOne() async {
    if (ordered.isEmpty) return;
    final last = ordered.first;
    if (loaded.isNotEmpty && loaded.first != last) {
      ID? prev = loaded.isEmpty ? null : loaded.first;
      final msg = await getChatMessage(last, prev, null, true);
      if (msg != null) {
        _cachedMessages[msg.id] = msg;
        loaded.insert(0, msg.id);
      }
      setState(() {});
    }
  }

  Future<void> loadMembers() async {
    final node_ = widget.node;
    if (node_ is GroupNode) {
      writePalette2(g.self, _members, buttonsOfNode, reload);
      for (final groupNode in widget.subNodes!) {
        writePalette2(groupNode, _members, buttonsOfNode, reload);
      }
    }
    setState(() {});
  }

  Future<ChatMessage?> getChatMessage(
    ID msgID,
    ID? prevMsgID,
    ID? nextMsgID,
    bool isLast,
  ) async {
    Message? msg = await msgID.getLocalMessage();
    if (msg == null) return null;
    Message? prevMsg, nextMsg;
    ChatMessage? prevChatMessage = _cachedMessages[prevMsgID];
    // If new message while in chat, we might want to remove the header of the
    // previous last message
    if (isLast &&
        prevMsgID != null &&
        prevChatMessage != null &&
        prevChatMessage.hasHeader &&
        msg.senderID == prevChatMessage.message.senderID &&
        msg.senderID != g.self.id) {
      // we need to remove its header
      _cachedMessages[prevMsgID] = prevChatMessage.withHeader(hasHeader: false);
      // and update it's size
    }

    if (_cachedMessages[msgID] != null) return _cachedMessages[msgID]!;

    prevMsg = await prevMsgID?.getLocalMessage();
    nextMsg = await nextMsgID?.getLocalMessage();

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

    final bool senderIsSelf = msg.senderID == g.self.id;
    final bool hasHeader = !senderIsSelf &&
        widget.node is GroupNode &&
        nextMsg?.senderID != msg.senderID;

    return ChatMessage(
        key: GlobalKey(),
        hasGap: hasGap,
        message: msg,
        // textInfo: ChatMessage.generateTextInfo(msg),
        mediaInfo: await ChatMessage.generateMediaInfo(msg),
        repliesInfo: await ChatMessage.generateRepliesInfo(msg, (replyID) {
          print("TODO, GO TO REPLY ID = $replyID");
        }),
        hasHeader: hasHeader,
        myMessage: g.self.id == msg.senderID,
        select: (id) {
          _cachedMessages[id] = _cachedMessages[id]!.invertedSelection();
          reload();
        });
  }

  Stream<void> messages2(List<ID> ids) async* {
    final n = ids.length;
    for (int i = 0; i < n; i++) {
      final msgID = ids[i];
      final nxt = loaded.isEmpty ? null : loaded.last;
      final prv = i < n - 1 ? ids[i + 1] : null;
      final isFirst = msgID == ordered.first;
      final msg = await getChatMessage(msgID, prv, nxt, isFirst);
      if (msg != null) {
        _cachedMessages[msg.id] = msg;
        loaded.add(msg.id);
        if (msg.mediaInfo?.media.isVideo ?? false) _msgsWithVideos.add(msg.id);
      }
    }
  }

  ConsoleInput get consoleInput {
    return ConsoleInput(
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
        loadMediasConsole();
      }
    }
    g.self.save();
  }

  void loadSavingConsole() {
    _console = Console(
      bottomInputs: [_consoleInput],
      topButtons: [
        ConsoleButton(
            name: "To Saved Messages",
            onPress: () {
              for (var msg in _cachedMessages.values) {
                if (msg.selected) {
                  g.self.messages.add(msg.message.id);
                  msg.message
                    ..isSaved = true
                    ..save();
                }
              }
              g.self.save();
              unselectSelectedMessage();
              loadBaseConsole();
            })
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
            name: "To Medias",
            onPress: () {
              for (var msg in _cachedMessages.values) {
                if (msg.selected && msg.hasMedia) {
                  if (msg.mediaInfo!.media.isVideo) {
                    g.self.videos.add(msg.mediaInfo!.media.id);
                  } else {
                    g.self.images.add(msg.mediaInfo!.media.id);
                  }
                  msg.mediaInfo!.media
                    ..isSaved = true
                    ..save();
                }
              }
              g.self.save();
              unselectSelectedMessage();
              loadBaseConsole();
            }),
      ],
    );
    setState(() {});
  }

  void saveSelectedMessages() async {
    for (final msg in _cachedMessages.values) {
      if (msg.selected) {
        _cachedMessages[msg.message.id] = msg.invertedSelection();
        g.self.messages.add(msg.message.id);
        msg.message
          ..isSaved = true
          ..save();
      }
    }
    g.self.save();
    setState(() {});
  }

  void unselectSelectedMessage() {
    for (final key in _cachedMessages.keys) {
      if (_cachedMessages[key]?.selected ?? false) {
        _cachedMessages[key] = _cachedMessages[key]!.invertedSelection();
      }
    }
    setState(() {});
  }

  void send2({MessageMedia? mediaInput}) {
    if (_tec.value.text == "" && mediaInput == null && _cameraInput == null) {
      return;
    }
    final ts = u.timeStamp();
    final theNode = widget.node;
    List<ID> targets;
    if (theNode is GroupNode) {
      targets = List<ID>.from((theNode.group))..remove(g.self.id);
    } else {
      targets = [theNode.id];
    }
    var msg = Message(
      root: widget.node is GroupNode ? widget.node.id : null,
      id: messagePushId(),
      timestamp: ts,
      senderID: g.self.id,
      mediaID: mediaInput?.id ?? _cameraInput?.id,
      text: _tec.value.text,
      replies: _cachedMessages.values
          .where((msg) => msg.selected)
          .map((msg) => msg.message.id)
          .toList(growable: false),
    );

    unselectSelectedMessage();

    print("TARGETS ===== $targets");

    var req = r.ChatRequest(
      message: msg,
      targets: targets,
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
        g.self.images.remove(media.id);
      } else {
        g.self.videos.remove(media.id);
      }
      media
        ..isSaved = false
        ..delete();
      loadMediasConsole(images: images, mode: mode, extra: extra);
    }

    _console = Console(
      consoleMedias2: ConsoleMedias2(
          showImages: images,
          onSelectMedia: (media) => send2(mediaInput: media)),
      // mediasInfo: consoleMedias(images: images, show: true),
      bottomInputs: [_consoleInput],
      topButtons: [
        ConsoleButton(
          name: "Import",
          onPress: () => handleImport(importImages: images),
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
      // mediasInfo: consoleMedias(images: images, show: false),
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

  @override
  Widget build(BuildContext context) {
    final pages = widget.node is GroupNode
        ? [
            Down4Page(
                isChatPage: true,
                title: widget.node.name,
                console: _console,
                asMap: _cachedMessages,
                orderedKeys: loaded,
                onRefresh: _cachedMessages.isEmpty ? null : _loadSome),
            Down4Page(
                title: "Members",
                console: _console,
                list: _members.values.toList()),
          ]
        : [
            Down4Page(
                isChatPage: true,
                title: widget.node.name,
                console: _console,
                asMap: _cachedMessages,
                orderedKeys: loaded,
                onRefresh: _cachedMessages.isEmpty ? null : _loadSome)
          ];

    return Andrew(
      pages: pages,
      onPageChange: (int newPageIndex) {
        for (final msgID in _msgsWithVideos) {
          _cachedMessages[msgID] = _cachedMessages[msgID]!.onPageTransition();
        }
      },
    );
  }
}
