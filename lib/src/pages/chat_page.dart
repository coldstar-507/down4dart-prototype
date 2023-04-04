import 'dart:async';

import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '_page_utils.dart';

class ChatPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "chat-${p.id}";

  final Palette2<Chatable> p;
  // final List<BaseNode>? subNodes;
  final Map<ID, ChatMessage> messages;
  final Map<ID, Palette2> members;
  final List<ID> ordered;
  final List<Down4Object>? fo;
  final void Function(int) onPageChange;
  final void Function() back;
  final Future<void> Function([int limit]) loadMore;
  final void Function(Palette2<Branchable>) openNode;
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
    required this.p,
    required this.openNode,
    this.fo,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with Pager, Backable, Camera, Medias, Chatter {
  GlobalKey mediaModeKey = GlobalKey();
  GlobalKey mediaForwardModeKey = GlobalKey();

  @override
  List<(String, void Function(FireMedia m))> get mediasMode => [
        ("Send", (m) => send(mediaInput: m)),
        ("Remove", (m) => m.updateSaveStatus(false)),
      ];
  @override
  ID get selfID => g.self.id;
  @override
  FireMedia? cameraInput;
  @override
  late List<Down4Object>? fo = widget.fo;
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
      ScrollController(initialScrollOffset: g.vm.cv.pages[0].scroll)
        ..addListener(() {
          g.vm.cv.pages[0].scroll = scroller0.offset;
        });

  late ScrollController? scroller1 = widget.p.node is Groupable
      ? (ScrollController(initialScrollOffset: g.vm.cv.pages[1].scroll)
        ..addListener(() {
          g.vm.cv.pages[1].scroll = scroller1!.offset;
        }))
      : null;

  // Future<List<ButtonsInfo2>> buttonsOfNode(Palette2<Branchable> p) async {
  //   return [
  //     ButtonsInfo2(
  //         asset: g.fifty, pressFunc: () => widget.openNode(p), rightMost: true)
  //   ];
  // }

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
    console = Console(
      bottomInputs: [mainInput],
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

  Future<void> loadFullCamera() async {
    // TODO
  }

  @override
  Future<void> send({FireMedia? mediaInput, List<Down4Object>? fo}) async {
    final media = cameraInput ?? mediaInput;
    final text = _tec.value.text;
    if (text == "" && media != null && fo != null) return;

    final r = widget.messages.values.selected().asIDs().toList();

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

  // Future<void> loadSquaredCameraConsole(CameraController? ctrl, int cam) async {
  //   if (ctrl == null) {
  //     try {
  //       ctrl = CameraController(g.cameras[cam], ResolutionPreset.high);
  //       await ctrl.initialize();
  //     } catch (e) {
  //       loadChatConsole();
  //     }
  //   }
  //   _console = squaredCapturingConsole(
  //     cam: cam,
  //     uselessInput: _consoleInput,
  //     goToPreview: (p, ar, ir) {
  //       ctrl?.dispose();
  //       loadPreviewConsole(p, ar, ir);
  //     },
  //     back: () {
  //       ctrl?.dispose();
  //       loadChatConsole();
  //     },
  //     onVideoStarted: () => loadSquaredCameraConsole(ctrl, cam),
  //     nextCam: () => loadSquaredCameraConsole(null, (cam + 1) % 2),
  //     ctrl: ctrl!,
  //   );
  //   setState(() {});
  // }
  //
  // void loadPreviewConsole(String p, double ar, bool ir) {
  //   _console = squaredPreviewConsole(
  //     uselessInput: _consoleInput,
  //     path: p,
  //     aspectRatio: ar,
  //     isReversed: ir,
  //     back: () => loadSquaredCameraConsole(null, ir ? 1 : 0),
  //     cancel: loadChatConsole,
  //     accept: () {
  //       _cameraInput = makeCameraMedia(p, ar, ir);
  //       loadChatConsole();
  //     },
  //   );
  //   setState(() {});
  // }
  //
  // void loadMediasConsole([
  //   bool images = true,
  //   String mode = "Send",
  //   bool extra = false,
  // ]) {
  //   void selectMedia(FireMedia media) {
  //     if (mode == "Send") {
  //       send2(mediaInput: media);
  //       return;
  //     } else if (mode == "Remove") {
  //       media.updateSaveStatus(false);
  //     }
  //     loadMediasConsole(images, mode, extra);
  //   }
  //
  //   _console = mediaConsole(
  //       uselessInput: consoleInput,
  //       selectMedia: selectMedia,
  //       afterImport: () => loadMediasConsole(images, mode, extra),
  //       back: loadChatConsole,
  //       switchMediasType: () => loadMediasConsole(!images, mode, extra),
  //       switchMediaMode: () => mode == "Send"
  //           ? loadMediasConsole(images, "Remove", true)
  //           : loadMediasConsole(images, "Send", true),
  //       switchExtra: () => loadMediasConsole(images, mode, !extra),
  //       extra: extra,
  //       images: images,
  //       importGroupMedia: null,
  //       mode: mode);
  //
  //   setState(() {});
  // }
  //
  // void loadForwardingConsole([bool extra = false]) {
  //   _console = forwardingConsole(
  //       usefulInput: consoleInput,
  //       fObjects: widget.fo!,
  //       loadForwardingMediaConsole: loadForwardingMediasConsole,
  //       forward: send2,
  //       switchExtra: () => loadForwardingConsole(!extra),
  //       back: widget.back,
  //       extra: extra);
  //
  //   // final f = fObjects ?? widget.fo;
  //   // if (f == null) return loadBaseConsole();
  //   // _console = Console(
  //   //   bottomInputs: [_consoleInput],
  //   //   forwardingObjects: f.toList(),
  //   //   bottomButtons: [
  //   //     ConsoleButton(name: "Back", onPress: widget.back),
  //   //     ConsoleButton(
  //   //       key: mediaForwardModeKey,
  //   //       name: "Forward",
  //   //       onPress: () {
  //   //         if (extra) {
  //   //           loadForwardingConsole(extra: !extra, fObjects: f);
  //   //         } else {
  //   //           final r = widget.messages.values.selected().asIDs().toList();
  //   //           widget.send(Payload(
  //   //               media: null, replies: r, forwards: f, text: _tec.value.text));
  //   //         }
  //   //       },
  //   //       onLongPress: () => loadForwardingConsole(extra: !extra, fObjects: f),
  //   //       isSpecial: true,
  //   //       showExtra: extra,
  //   //       extraButtons: [
  //   //         ConsoleButton(
  //   //             name: "Medias",
  //   //             onPress: () => loadForwardingMediasConsole(fObjects: f)),
  //   //       ],
  //   //     )
  //   //   ],
  //   // );
  //   setState(() {});
  // }
  //
  // void loadForwardingMediasConsole([bool images = true]) {
  //   _console = forwardingMediaConsole(
  //     uselessInput: consoleInput,
  //     onSelectMedia: (media) => send2(mediaInput: media),
  //     switchType: () => loadForwardingMediasConsole(!images),
  //     forwardingObjects: widget.fo!,
  //     back: loadForwardingConsole,
  //     images: images,
  //   );
  //
  //   // _console = Console(
  //   //   bottomInputs: [consoleInput],
  //   //   consoleMedias2: ConsoleMedias2(
  //   //       showImages: images,
  //   //       onSelect: (media) => send2(mediaInput: media, fo: fObjects)),
  //   //   forwardingObjects: fObjects.toList(),
  //   //   bottomButtons: [
  //   //     ConsoleButton(
  //   //       name: "Back",
  //   //       onPress: () => loadForwardingConsole(fObjects: fObjects),
  //   //     ),
  //   //     ConsoleButton(
  //   //       name: images ? "Images" : "Videos",
  //   //       onPress: () =>
  //   //           loadForwardingMediasConsole(fObjects: fObjects, images: !images),
  //   //     )
  //   //   ],
  //   // );
  //   setState(() {});
  // }

  @override
  void loadBaseConsole({bool images = true}) {
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
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: cameraInput == null ? "Camera" : "@Camera",
          onPress: () => loadSquaredCameraConsole(null, 0),
        ),
        ConsoleButton(
          name: "Medias",
          onPress: () => loadMediasConsole(images),
        ),
      ],
    );
    setState(() {});
  }

  // Future<void> loadSquaredCameraConsole({
  //   CameraController? ctrl,
  //   int cam = 0,
  //   String? path,
  // }) async {
  //   if (ctrl == null) {
  //     try {
  //       ctrl = CameraController(g.cameras[cam], ResolutionPreset.medium);
  //       await ctrl.initialize();
  //     } catch (err) {
  //       loadBaseConsole();
  //     }
  //   }
  //
  //   Future<void> nextCam() async {
  //     await ctrl?.dispose();
  //     return loadSquaredCameraConsole(cam: (cam + 1) % 2);
  //   }
  //
  //   if (path == null) {
  //     _console = Console(
  //       bottomInputs: [consoleInput],
  //       cameraController: ctrl,
  //       topButtons: [
  //         ConsoleButton(
  //           name: "Capture",
  //           isSpecial: true,
  //           shouldBeDownButIsnt: ctrl!.value.isRecordingVideo,
  //           onPress: () async {
  //             final XFile f = await ctrl!.takePicture();
  //             loadSquaredCameraConsole(ctrl: ctrl, cam: cam, path: f.path);
  //           },
  //           onLongPress: () async {
  //             await ctrl!.startVideoRecording();
  //             loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
  //           },
  //           onLongPressUp: () async {
  //             final XFile f = await ctrl!.stopVideoRecording();
  //             loadSquaredCameraConsole(ctrl: ctrl, cam: cam, path: f.path);
  //           },
  //         ),
  //       ],
  //       bottomButtons: [
  //         ConsoleButton(
  //             name: "Back",
  //             onPress: () {
  //               ctrl?.dispose();
  //               loadBaseConsole();
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
  //         onPress: () async {
  //           Uint8List? tn;
  //           final Uint8List data = File(path).readAsBytesSync();
  //           final mediaID = u.deterministicMediaID(data, g.self.id);
  //           final mime = lookupMimeType(path)!;
  //           bool isVideo = extensionFromMime(mime).isVideoExtension();
  //           if (isVideo) {
  //             tn = await VideoThumbnail.thumbnailData(video: path, quality: 90);
  //           }
  //           final newMedia = FireMedia(mediaID,
  //               tinyThumbnail: tinyThumbnail(tn ?? data),
  //               mime: mime,
  //               owner: g.self.id,
  //               timestamp: u.timeStamp(),
  //               aspectRatio: ctrl!.value.aspectRatio,
  //               isReversed: cam == 1,
  //               isSquared: true);
  //           await newMedia.write(
  //               videoData: isVideo ? data : null, imageData: tn ?? data);
  //           _cameraInput = newMedia;
  //           loadBaseConsole();
  //         },
  //       ),
  //     ];
  //     final bottomButtons = [
  //       ConsoleButton(
  //         name: "Back",
  //         onPress: () {
  //           File(path).delete();
  //           loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
  //         },
  //       ),
  //       ConsoleButton(
  //           name: "Cancel",
  //           onPress: () {
  //             File(path).delete();
  //             ctrl?.dispose();
  //             loadBaseConsole();
  //           }),
  //     ];
  //
  //     print("PATH EXTENSION = ${path.extension()}");
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

  @override
  Widget build(BuildContext context) {
    final pages = widget.p is Groupable
        ? [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: widget.p.node.displayName,
                console: console,
                asMap: widget.messages,
                orderedKeys: widget.ordered,
                onRefresh: widget.loadMore),
            Down4Page(
              scrollController: scroller1,
              title: "Members",
              console: console,
              list: widget.members.values.toList(),
            ),
          ]
        : [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: widget.p.node.displayName,
                console: console,
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
