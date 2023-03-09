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

  final ChatableNode node;
  final List<BaseNode>? subNodes;
  final List<Down4Object>? fObjects;
  final void Function() back;
  final void Function(BaseNode) openNode;
  final void Function(Payload) send;

  const ChatPage({
    required this.subNodes,
    required this.back,
    required this.send,
    required this.node,
    required this.openNode,
    this.fObjects,
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
          asset: g.fifty,
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
    reloadOne();
  }

  Future<void> reloadOne() async {
    mIds = widget.node.messages.toList();
    ordered = mIds.reversed.toList();
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

    final cm = ChatMessage(
        key: GlobalKey(),
        hasGap: hasGap,
        message: msg,
        mediaInfo: await ChatMessage.generateMediaInfo(msg),
        nodes: null,
        repliesInfo: await ChatMessage.generateRepliesInfo(msg, (replyID) {
          print("TODO, GO TO REPLY ID = $replyID");
        }),
        hasHeader: hasHeader,
        openNode: widget.openNode,
        myMessage: g.self.id == msg.senderID,
        select: (id) {
          _cachedMessages[id] = _cachedMessages[id]!.invertedSelection();
          setState(() {});
        });

    Future.microtask(() {
      if ((msg.nodes ?? []).isNotEmpty) {
        getNodesFromEverywhere(msg.nodes!.toSet()).then((nodes) {
          if (nodes.isNotEmpty) {
            _cachedMessages[msg.id] = _cachedMessages[msg.id]!.withNodes(nodes);
            setState(() {});
          }
        });
      }
    });

    // () async {
    //   if ((msg.nodes ?? []).isNotEmpty) {
    //     r.getNodes(msg.nodes!).then((nodes) {
    //       if ((nodes ?? []).isNotEmpty) {
    //         _cachedMessages[msg.id] = _cachedMessages[msg.id]!.withNodes(nodes);
    //       }
    //     });
    //   }
    // }();

    return cm;
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

  Future<void> send2({
    MessageMedia? mediaInput,
    List<Down4Object>? fObjects,
  }) async {
    final media = mediaInput ?? _cameraInput;
    final text = _tec.value.text;
    if (text == "" && media != null && fObjects != null) return;

    final r = _cachedMessages.values.selected().asIDs().toList();

    final p = Payload(m: media, t: _tec.value.text, f: fObjects, r: r);

    widget.send(p);

    final sendingToSelf = widget.node.id == g.self.id;

    final fMsg = p.forwardables.whereType<ChatMessage>();
    final msg = p.message;

    for (final m in fMsg) {
      m.message
        ..isRead = true
        ..isSaved = sendingToSelf
        ..save();
      widget.node.messages.add(m.id);
      await reloadOne();
    }

    if (msg != null) {
      msg
        ..isRead = true
        ..isSaved = sendingToSelf
        ..save();
      widget.node.messages.add(msg.id);
      await reloadOne();
    }

    unselectSelectedMessage();
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
      if (mode == "Send") {
        send2(mediaInput: media);
        return;
      }
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
    final f = fObjects ?? widget.fObjects;
    if (f == null) return loadBaseConsole();
    _console = Console(
      bottomInputs: [_consoleInput],
      forwardingObjects: f.toList(),
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: "Forward",
          onPress: () {
            if (extra) {
              loadForwardingConsole(extra: !extra, fObjects: f);
            } else {
              final r = _cachedMessages.values.selected().asIDs().toList();
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
  }

  void loadForwardingMediasConsole({
    required List<Down4Object> fObjects,
    bool images = true,
  }) {
    _console = Console(
      consoleMedias2: ConsoleMedias2(
          showImages: images,
          onSelect: (media) => send2(mediaInput: media, fObjects: fObjects)),
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
