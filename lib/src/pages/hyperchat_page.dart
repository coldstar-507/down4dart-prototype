import 'dart:async';

import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:video_player/video_player.dart';

import '_page_utils.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/_render_utils.dart' as ru;

class HyperchatPage extends StatefulWidget implements Down4PageWidget {
  ID get id => "hyper";
  final Transition transition;
  final List<Down4Object>? fo;
  final void Function(String text) ping;
  final void Function() back;
  final void Function(Payload p, Set<ID> group) makeHyperchat;

  const HyperchatPage({
    required this.transition,
    required this.makeHyperchat,
    required this.back,
    required this.ping,
    required this.fo,
    Key? key,
  }) : super(key: key);

  @override
  State<HyperchatPage> createState() => _HyperchatPageState();
}

class _HyperchatPageState extends State<HyperchatPage>
    with
        WidgetsBindingObserver,
        Pager2,
        // Backable,
        Camera2,
        Medias2,
        Input2,
        Sender2,
        Forwarder2,
        Compose2
// Forwarder,
// SingleTickerProviderStateMixin
{
  // late final _tec = TextEditingController(); //..addListener(onTec);
  //
  // @override
  // late final aCtrl =
  //     AnimationController(duration: Console.animationDuration, vsync: this)
  //       ..addListener(() {
  //         if (fo == null) {
  //           loadBaseConsole();
  //         } else {
  //           // loadForwardingConsole();
  //         }
  //       });

  // @override
  // late FocusNode focusNode = FocusNode()..addListener(onFocusChange);

  // @override
  // ID get selfID => g.self.id;

  @override
  List<(String, void Function(FireMedia))> get mediasMode => [
        (
          "SEND",
          (m) async {
            await m.use();
            send(mediaInput: m);
          }
        ),
        (
          "REMOVE",
          (m) {
            m.updateSaveStatus(false);
            setState(() {});
            // loadMediasConsole(!m.isVideo, true);
          }
        ),
      ];

  // @override
  // VideoPlayerController? videoPreview;

  // void onTec() {
  //   print("TEC IS CHANGING BABY");
  //   loadBaseConsole();
  // }

  // @override
  // late ConsoleInput mainInput = ConsoleInput(
  //   // prefix: "   ",
  //   placeHolder: "",
  //   tec: _tec,
  //   inputCallBack: (_) => loadBaseConsole(),
  //   maxLines: 8,
  //   focus: focusNode,
  // );

  // void loadInput({int maxlines = 8}) {
  //   mainInput = ConsoleInput(
  //     prefix: "   ",
  //     placeHolder: "",
  //     tec: _tec,
  //     maxLines: maxlines,
  //     focus: _focusNode,
  //   );
  // }

  // @override
  // late Console console;
  // @override
  // FireMedia? cameraInput;
  // @override
  // void back() => widget.back();
  @override
  List<Down4Object>? get fo => widget.fo;
  @override
  void setTheState() => setState(() {});

  late List<Palette2> _palettes = widget.transition.preTransition;
  late final double offset = widget.transition.nHidden * Palette2.fullHeight;
  late ScrollController scroller =
      ScrollController(initialScrollOffset: widget.transition.scroll);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // if (widget.fo != null) {
    //   // loadForwardingConsole();
    // } else {
    //   loadBaseConsole();
    // }
    animatedTransition();
  }

  @override
  void dispose() {
    // focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  bool get forwarding => (fo ?? []).isNotEmpty;

  // bool extraMediaButton = false;

  // final GlobalKey mediasButtonKey = GlobalKey();

  ConsoleRow get theRow => forwarding
      ? ConsoleRow(
          widgets: [
            forwardingObjectsWidget,
            mediasButton.withExtra(mediasExtra, [cameraButton]),
            input.widget,
            sendButton,
          ],
          extension: null,
          widths: hasFocus ? [0.0, 0.2, 0.6, 0.2] : null,
          inputMaxHeight: hasFocus ? input.height : Console.buttonHeight,
        )
      : basicComposeRow;

  // bool showExtraMediaButton = false;

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": theRow,
              basicCameraRowName: basicCameraRow,
              basicMediaRowName: basicMediasRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          _palettes = widget.transition.postTransition;
          scroller.jumpTo(widget.transition.scroll + offset);
          scroller.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

  @override
  Future<void> send({FireMedia? mediaInput}) async {
    final media = mediaInput ?? cameraInput;
    final text = input.value;
    if (text.isEmpty && media == null) return;

    final p = Payload(
        text: text,
        media: media,
        forwards: widget.fo,
        replies: null,
        isSnip: false);

    final group = Set<ID>.from(widget.transition.trueTargets.asIDs())
      ..add(g.self.id);
    widget.makeHyperchat(p, group);
  }

  // void ping() {
  //   if (_tec.value.text.isEmpty) return;
  //   widget.ping(_tec.value.text);
  //   _tec.clear();
  // }

  // void loadMediaConsole([
  //   bool images = true,
  //   String mode = "Send",
  //   bool extra = false,
  // ]) {
  //   _console = mediaConsole(
  //       uselessInput: consoleInput,
  //       selectMedia: (m) => send(mediaInput: m),
  //       afterImport: () => loadMediaConsole(images),
  //       back: loadBaseConsole,
  //       switchMediasType: () => loadMediaConsole(!images),
  //       switchMediaMode: () => mode == "Send"
  //           ? loadMediaConsole(images, "Remove", extra)
  //           : loadMediaConsole(images, "Send", extra),
  //       switchExtra: () => loadMediaConsole(images, mode, !extra),
  //       importGroupMedia: null,
  //       mode: mode,
  //       extra: extra,
  //       images: images);
  //
  //   // _console = Console(
  //   //   consoleMedias2: ConsoleMedias2(
  //   //       showImages: images, onSelect: (media) => send(mediaInput: media)),
  //   //   bottomInputs: [consoleInput],
  //   //   topButtons: [
  //   //     ConsoleButton(
  //   //       name: "Import",
  //   //       onPress: () async {
  //   //         await importConsoleMedias(images: images);
  //   //         loadMediaConsole(images);
  //   //       },
  //   //     ),
  //   //   ],
  //   //   bottomButtons: [
  //   //     ConsoleButton(name: "Back", onPress: loadBaseConsole),
  //   //     ConsoleButton(
  //   //       isMode: true,
  //   //       name: images ? "Images" : "Videos",
  //   //       onPress: () => loadMediaConsole(!images),
  //   //     ),
  //   //   ],
  //   // );
  //   setState(() {});
  // }

  void loadFullCamera() {
    // TODO
  }

  // @override
  // void loadBaseConsole({bool images = true}) {
  //   if (fo == null) {
  //     loadNormalConsole();
  //   } else {
  //     // loadForwardingConsole();
  //   }
  // }

  // void loadNormalConsole() {
  //   print("RELOADING RELOADING");
  //
  //   console = Console(
  //     // bottomInputs: [mainInput],
  //     topButtons: [
  //       ConsoleButton(name: "Ping", onPress: ping),
  //       ConsoleButton(name: "Send", onPress: send),
  //     ],
  //     bottomButtons: [
  //       ConsoleButton(name: "Back", onPress: widget.back),
  //       ConsoleButton(
  //           name: cameraInput == null ? "Camera" : "@Camera",
  //           onPress: () => loadSquaredCameraConsole(0)),
  //       ConsoleButton(name: "Medias", onPress: loadMediasConsole),
  //     ],
  //     // consoleRow: Console3(
  //     //   maxHeight: Console.buttonHeight,
  //     //   ctrl: aCtrl,
  //     //   beginSizes: const [0.25, 0.25, 0.25, 0.25],
  //     //   endSizes: const [0.0, 0.20, 0.60, 0.20],
  //     //   widgets: [
  //     //     ConsoleButton(
  //     //         name: cameraInput == null ? "CAMERA" : "@CAMERA",
  //     //         onPress: () => loadSquaredCameraConsole(0)),
  //     //     ConsoleButton(name: "MEDIAS", onPress: loadMediasConsole),
  //     //     mainInput,
  //     //     ConsoleButton(name: "SEND", onPress: send),
  //     //   ],
  //     // ),
  //   );
  //   setState(() {});
  // }

  // Future<void> loadSquaredCameraConsole([
  //   CameraController? ctrl,
  //   int cam = 0,
  // ]) async {
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
  //     return loadSquaredCameraConsole(null, (cam + 1) % 2);
  //   }
  //
  //   _console = squaredCapturingConsole(
  //       uselessInput: consoleInput,
  //       goToPreview: loadPreviewConsole,
  //       back: loadBaseConsole,
  //       onVideoStarted: () => loadSquaredCameraConsole(ctrl, cam),
  //       nextCam: nextCam,
  //       ctrl: ctrl!,
  //       cam: cam);
  //
  //   // if (path == null) {
  //   //   _console = Console(
  //   //     bottomInputs: [consoleInput],
  //   //     cameraController: ctrl,
  //   //     topButtons: [
  //   //       ConsoleButton(
  //   //         name: "Capture",
  //   //         isSpecial: true,
  //   //         shouldBeDownButIsnt: ctrl!.value.isRecordingVideo,
  //   //         onPress: () async {
  //   //           final XFile f = await ctrl!.takePicture();
  //   //           loadSquaredCameraConsole(
  //   //               ctrl: ctrl, cam: cam, path: f.path, mimetype: f.mimeType);
  //   //         },
  //   //         onLongPress: () async {
  //   //           await ctrl!.startVideoRecording();
  //   //           loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
  //   //         },
  //   //         onLongPressUp: () async {
  //   //           final XFile f = await ctrl!.stopVideoRecording();
  //   //           loadSquaredCameraConsole(
  //   //               ctrl: ctrl, cam: cam, path: f.path, mimetype: f.mimeType);
  //   //         },
  //   //       ),
  //   //     ],
  //   //     bottomButtons: [
  //   //       ConsoleButton(
  //   //           name: "Back",
  //   //           onPress: () {
  //   //             ctrl?.dispose();
  //   //             loadBaseConsole();
  //   //           }),
  //   //       ConsoleButton(
  //   //         name: cam == 0 ? "Rear" : "Front",
  //   //         onPress: nextCam,
  //   //         isMode: true,
  //   //       ),
  //   //     ],
  //   //   );
  //   // } else {
  //   //   BetterPlayerController? vpc;
  //   //   final topBottons = [
  //   //     ConsoleButton(
  //   //       name: "Accept",
  //   //       onPress: () async {
  //   //         Uint8List? tn;
  //   //         final Uint8List data = File(path).readAsBytesSync();
  //   //         final mediaID = u.deterministicMediaID(data, g.self.id);
  //   //         bool isVideo = path.extension().isVideoExtension();
  //   //         if (isVideo) {
  //   //           tn = await VideoThumbnail.thumbnailData(video: path, quality: 90);
  //   //         }
  //   //         vpc?.dispose();
  //   //         final newMedia = FireMedia(mediaID,
  //   //             tinyThumbnail: ru.makeTiny(tn ?? data),
  //   //             mime: mimetype!,
  //   //             owner: g.self.id,
  //   //             timestamp: u.timeStamp(),
  //   //             aspectRatio: ctrl!.value.aspectRatio,
  //   //             extension: path.extension(),
  //   //             isReversed: cam == 1,
  //   //             isSquared: true);
  //   //         await newMedia.write(
  //   //             videoData: isVideo ? data : null, imageData: tn ?? data);
  //   //         _cameraInput = newMedia;
  //   //         loadBaseConsole();
  //   //       },
  //   //     ),
  //   //   ];
  //   //   final bottomButtons = [
  //   //     ConsoleButton(
  //   //       name: "Back",
  //   //       onPress: () {
  //   //         File(path).delete();
  //   //         vpc?.dispose();
  //   //         loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
  //   //       },
  //   //     ),
  //   //     ConsoleButton(
  //   //         name: "Cancel",
  //   //         onPress: () {
  //   //           File(path).delete();
  //   //           vpc?.dispose();
  //   //           ctrl?.dispose();
  //   //           loadBaseConsole();
  //   //         }),
  //   //   ];
  //   //
  //   //   print("PATH EXTENSION = ${path.extension()}");
  //   //   if (path.extension().isVideoExtension()) {
  //   //     vpc = BetterPlayerController(const BetterPlayerConfiguration());
  //   //     await vpc.setupDataSource(BetterPlayerDataSource.file(path));
  //   //     await vpc.setLooping(true);
  //   //     await vpc.play();
  //   //     _console = Console(
  //   //         bottomInputs: [consoleInput],
  //   //         videoForPreview: VideoPreview(
  //   //             videoPlayer: BetterPlayer(controller: vpc),
  //   //             videoAspectRatio: ctrl!.value.aspectRatio,
  //   //             isReversed: cam == 1),
  //   //         topButtons: topBottons,
  //   //         bottomButtons: bottomButtons);
  //   //   } else {
  //   //     _console = Console(
  //   //         bottomInputs: [consoleInput],
  //   //         imageForPreview: ImagePreview(
  //   //             path: path,
  //   //             isReversed: cam == 1,
  //   //             imageAspectRatio: ctrl!.value.aspectRatio),
  //   //         topButtons: topBottons,
  //   //         bottomButtons: bottomButtons);
  //   //   }
  //   // }
  //   setState(() {});
  // }
  //
  // void loadPreviewConsole(String p, double ar, bool ir) {
  //   _console = squaredPreviewConsole(
  //     uselessInput: consoleInput,
  //     path: p,
  //     aspectRatio: ar,
  //     isReversed: ir,
  //     back: () => loadSquaredCameraConsole(null, ir ? 1 : 0),
  //     cancel: loadBaseConsole,
  //     accept: () {
  //       _cameraInput = makeCameraMedia(p, ar, ir);
  //       loadBaseConsole();
  //     },
  //   );
  //   setState(() {});
  // }

  // void loadForwardingConsole({bool extra = false}) {
  //   _console = Console(
  //     bottomInputs: [consoleInput],
  //     forwardingObjects: widget.fo,
  //     bottomButtons: [
  //       ConsoleButton(name: "Back", onPress: widget.back),
  //       ConsoleButton(
  //         name: "Forward",
  //         onPress: () {
  //           if (extra) {
  //             loadForwardingConsole(extra: !extra);
  //           } else {
  //             send();
  //           }
  //         },
  //         onLongPress: () => loadForwardingConsole(extra: !extra),
  //         isSpecial: true,
  //         showExtra: extra,
  //         extraButtons: [
  //           ConsoleButton(
  //             name: "Medias",
  //             onPress: () => loadForwardingMediasConsole(),
  //           ),
  //         ],
  //       )
  //     ],
  //   );
  //   setState(() {});
  // }
  //
  // void loadForwardingMediasConsole({bool images = true}) {
  //   _console = Console(
  //     bottomInputs: [consoleInput],
  //     consoleMedias2: ConsoleMedias2(
  //         showImages: images, onSelect: (media) => send(mediaInput: media)),
  //     forwardingObjects: widget.fo,
  //     bottomButtons: [
  //       ConsoleButton(
  //         name: "Back",
  //         onPress: () => loadForwardingConsole(),
  //       ),
  //       ConsoleButton(
  //         name: images ? "Images" : "Videos",
  //         onPress: () => loadForwardingMediasConsole(images: !images),
  //       )
  //     ],
  //   );
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    return Andrew(backButton: backArrow(back: widget.back), pages: [
      Down4Page(
          scrollController: scroller,
          staticList: true,
          trueLen: widget.transition.trueTargets.length,
          title: "Hyperchat",
          console: console,
          list: _palettes),
    ]);
  }

  @override
  String get backFromCameraConsoleName => "base";

  @override
  String get backFromMediasConsoleName => "base";

  @override
  List<String> currentConsolesName = ["base"];

  @override
  int get currentPageIndex => 0;

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
        onInput: onInput,
        onFocusChange: onFocusChange,
        config: Input2.multiLine,
        ctrl: InputController()),
  ];

  Extra get mediasExtra => extras[0];

  @override
  late List<Extra> extras = [
    Extra(setTheState: setTheState),
  ];
}
