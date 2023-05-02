import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:video_player/video_player.dart';

import '../_dart_utils.dart';
import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '_page_utils.dart';

class ChatPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "chat-${viewState.node!.id}";

  final ViewState viewState;
  final List<Down4Object>? fo;
  final void Function(int) onPageChange;
  final void Function() back;
  final Future<void> Function([int limit]) loadMore;
  final void Function(Branchable) openNode;
  final void Function(Payload) send;
  final void Function(List<Down4Object> fo) forward;

  const ChatPage({
    required this.viewState,
    required this.loadMore,
    required this.onPageChange,
    required this.back,
    required this.send,
    required this.openNode,
    required this.forward,
    this.fo,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with Pager, Backable, Camera, Medias, Sender, Forwarder {
  GlobalKey mediaModeKey = GlobalKey();
  GlobalKey mediaForwardModeKey = GlobalKey();

  Chatable get node => widget.viewState.node as Chatable;
  List<ID> get orderedChats => widget.viewState.chat?.first ?? [];

  // @override
  // VideoPlayerController? videoPreview;

  @override
  List<Pair<String, void Function(FireMedia)>> get mediasMode => [
        Pair("Send", (m) async {
          await m.use();
          send(mediaInput: m);
        }),
        Pair("Remove", (m) {
          m.updateSaveStatus(false);
          loadMediasConsole(!m.isVideo, true);
        }),
      ];
  @override
  ID get selfID => g.self.id;
  @override
  FireMedia? cameraInput;
  @override
  List<Down4Object>? get fo => widget.fo;
  @override
  void back() => widget.back();
  @override
  void setTheState() => setState(() {});
  @override
  late Console console;
  @override
  late ConsoleInput mainInput = consoleInput;
  final _tec = TextEditingController();

  late ScrollController scroller0 =
      ScrollController(initialScrollOffset: widget.viewState.pages[0].scroll)
        ..addListener(() {
          widget.viewState.pages[0].scroll = scroller0.offset;
        });

  late ScrollController? scroller1 = node is Groupable
      ? (ScrollController(initialScrollOffset: widget.viewState.pages[1].scroll)
        ..addListener(() {
          widget.viewState.pages[1].scroll = scroller1!.offset;
        }))
      : null;

  Map<ID, ChatMessage> get _messages =>
      widget.viewState.pages[0].objects.cast();
  Map<ID, Palette2> get _group => widget.viewState.pages[1].objects.cast();

  var lastOffsetUpdate = 0.0;

  String? _idOfLastMessageRead;

  @override
  void initState() {
    super.initState();
    if (fo != null) {
      loadForwardingConsole();
    } else {
      loadBaseConsole();
    }
  }

  @override
  void dispose() {
    scroller0.dispose();
    scroller1?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
    if (forwardingConsoles.contains(console.name) && fo == null) {
      loadBaseConsole();
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
    console = Console(
      bottomInputs: [mainInput],
      topButtons: [
        ConsoleButton(
            name: "To Saved Messages",
            onPress: () async {
              for (var chat in _messages.values.selected()) {
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
              final selectedMedias = _messages.values
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
    for (final key in _messages.keys) {
      if (_messages[key]?.selected ?? false) {
        _messages[key] = _messages[key]!.invertedSelection();
      }
    }
    setState(() {});
  }

  Future<void> loadFullCamera() async {
    // TODO
  }

  @override
  Future<void> send({FireMedia? mediaInput}) async {
    final media = cameraInput ?? mediaInput;
    final text = _tec.value.text;
    if (text == "" && media != null && fo != null) return;

    final r = _messages.values.selected().asIDs().toList();

    final p = Payload(
        media: media,
        text: _tec.value.text,
        forwards: fo,
        replies: r,
        isSnip: false);

    widget.send(p);

    unselectSelectedMessage();
    cameraInput = null;
    _tec.clear();
  }

  @override
  void loadBaseConsole({bool images = true, bool extra = false}) {
    console = Console(
      bottomInputs: [mainInput],
      topButtons: [
        ConsoleButton(name: "Save", onPress: loadSavingConsole),
        ConsoleButton(
          name: "Send",
          onPress: () {
            send();
            loadBaseConsole();
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: !extra ? widget.back : loadBaseConsole,
          showExtra: extra,
          onLongPress: () => loadBaseConsole(extra: !extra),
          isSpecial: true,
          extraButtons: [
            ConsoleButton(
              name: "Forward",
              onPress: () => widget.forward(
                _messages.values.selected().toList(growable: false),
              ),
            ),
          ],
        ),
        ConsoleButton(
          name: cameraInput == null ? "Camera" : "@Camera",
          onPress: () => loadSquaredCameraConsole(0),
        ),
        ConsoleButton(
          name: "Medias",
          onPress: () => loadMediasConsole(images),
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = node is Groupable
        ? [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: node.displayName,
                console: console,
                asMap: _messages,
                orderedKeys: orderedChats,
                onRefresh: widget.loadMore),
            Down4Page(
              scrollController: scroller1,
              title: "Members",
              console: console,
              list: _group.values.toList(),
            ),
          ]
        : [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: node.displayName,
                console: console,
                asMap: _messages,
                orderedKeys: orderedChats,
                onRefresh: widget.loadMore)
          ];

    return Andrew(
      pages: pages,
      initialPageIndex: widget.viewState.currentIndex,
      onPageChange: widget.onPageChange,
    );
  }
}

// Future<void> squaredCamera(
//   Console c,
//   void Function() b,
//   ConsoleInput i,
//   void Function(String f) cb, {
//   CameraController? ctrl,
//   int cam = 0,
//   String? path,
// }) async {
//   if (ctrl == null) {
//     try {
//       ctrl = CameraController(g.cameras[cam], ResolutionPreset.medium);
//       await ctrl.initialize();
//     } catch (err) {
//       b();
//     }
//   }
//
//   Future<void> nextCam() async {
//     await ctrl?.dispose();
//     return squaredCamera(c, b, i, cb, cam: (cam + 1) % 2);
//   }
//
//   if (path == null) {
//     c = Console(
//       bottomInputs: [i],
//       cameraController: ctrl,
//       topButtons: [
//         ConsoleButton(
//           name: "Capture",
//           isSpecial: true,
//           shouldBeDownButIsnt: ctrl!.value.isRecordingVideo,
//           onPress: () async {
//             final XFile f = await ctrl!.takePicture();
//             squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam, path: f.path);
//           },
//           onLongPress: () async {
//             await ctrl!.startVideoRecording();
//             squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam);
//           },
//           onLongPressUp: () async {
//             final XFile f = await ctrl!.stopVideoRecording();
//             squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam, path: f.path);
//           },
//         ),
//       ],
//       bottomButtons: [
//         ConsoleButton(
//             name: "Back",
//             onPress: () {
//               ctrl?.dispose();
//               b();
//             }),
//         ConsoleButton(
//           name: cam == 0 ? "Rear" : "Front",
//           onPress: nextCam,
//           isMode: true,
//         ),
//       ],
//     );
//   } else {
//     BetterPlayerController? vpc;
//     final topBottons = [
//       ConsoleButton(
//         name: "Accept",
//         onPress: () => cb(path),
//       ),
//     ];
//     final bottomButtons = [
//       ConsoleButton(
//         name: "Back",
//         onPress: () => squaredCamera(c, b, i, cb, ctrl: ctrl, cam: cam),
//       ),
//       ConsoleButton(
//           name: "Cancel",
//           onPress: () {
//             ctrl?.dispose();
//             b();
//           }),
//     ];
//
//     if (path.extension().isVideoExtension()) {
//       vpc = BetterPlayerController(const BetterPlayerConfiguration());
//       await vpc.setupDataSource(BetterPlayerDataSource.file(path));
//       await vpc.setLooping(true);
//       await vpc.play();
//       _console = Console(
//           bottomInputs: [consoleInput],
//           videoForPreview: VideoPreview(
//               videoPlayer: BetterPlayer(controller: vpc),
//               videoAspectRatio: ctrl!.value.aspectRatio,
//               isReversed: cam == 1),
//           topButtons: topBottons,
//           bottomButtons: bottomButtons);
//     } else {
//       _console = Console(
//           bottomInputs: [consoleInput],
//           imageForPreview: ImagePreview(
//               path: path,
//               isReversed: cam == 1,
//               imageAspectRatio: ctrl!.value.aspectRatio),
//           topButtons: topBottons,
//           bottomButtons: bottomButtons);
//     }
//   }
//   setState(() {});
// }
