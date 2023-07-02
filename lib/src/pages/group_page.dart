import 'dart:async';
import 'dart:convert' show base64Encode, utf8;

import 'package:down4/src/data_objects/messages.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/bsv/_bsv_utils.dart';

import '../_dart_utils.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/firebase.dart';
import '../data_objects/medias.dart';
import '../data_objects/nodes.dart';
import '_page_utils.dart';

import '../globals.dart';
import '../_dart_utils.dart' as u;

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/_render_utils.dart';

class GroupPage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "group";
  final List<Palette2> homePalettes, palettesForTransition;
  final Iterable<PersonNode> people;
  final int nHidden;
  final void Function() back;
  final void Function(Group group, FireMedia m, Chat c) makeGroup;
  final double initialOffset;

  const GroupPage({
    required this.people,
    required this.nHidden,
    required this.palettesForTransition,
    required this.back,
    required this.makeGroup,
    required this.homePalettes,
    required this.initialOffset,
    Key? key,
  }) : super(key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage>
    with
        WidgetsBindingObserver,
        Pager2,
        Input2,
        Medias2,
        Camera2,
        Sender2,
        Compose2 {
  // @override
  // late Console console;
  late List<Widget> _items = [...widget.homePalettes];
  // final _tec = TextEditingController();
  // final _tec2 = TextEditingController();
  bool _private = true;
  late final double offset = Palette2.fullHeight * (widget.nHidden + 1);
  late final _scrollController = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );

  FireMedia? _groupImage;
  String _groupName = "";

  // @override
  // late final aCtrl =
  //     AnimationController(duration: Console.animationDuration, vsync: this)
  //       ..addListener(() {
  //         loadBaseConsole();
  //       });

  // @override
  // late FocusNode focusNode = FocusNode()..addListener(onFocusChange);

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
          }
        ),
      ];

  // @override
  // ID get selfID => g.self.id;
  // @override
  // FireMedia? cameraInput;
  // @override
  // void back() => widget.back();
  @override
  void setTheState() => setState(() {});

  // @override
  // late ConsoleInput mainInput = ConsoleInput(
  //     placeHolder: "",
  //     tec: _tec,
  //     focus: focusNode,
  //     maxLines: 8,
  //     inputCallBack: (_) => loadBaseConsole());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // loadBaseConsole();
    animatedTransition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> animatedTransition() async {
    Future(() => setState(() {
          print(
            "PALETTES FOR TRANSITION = ${widget.palettesForTransition.map((e) => e.node.displayName).toList()}",
          );
          _items = [...widget.palettesForTransition, groupMaker(fold: false)];
          _scrollController.jumpTo(widget.initialOffset + offset);
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }));
  }

  void forGroupNode(FireMedia m) {
    _groupImage = m;
    reloadItems();
  }

  PaletteMaker groupMaker({required bool fold}) {
    return PaletteMaker(
        fold: fold,
        colorCode: NodesColor.group,
        tec: groupInput,
        id: Down4ID(unique: "groupMaker"),
        name: _groupName,
        // hintText: "Group Name",
        image: _groupImage,
        // nameCallBack: (name) => setState(() => _groupName = name),
        type: Nodes.group,
        imagePress: () {
          forMediaMode = ("PUT", forGroupNode);
          changeConsole(basicMediaRowName);
        });
  }

  @override
  Future<void> send({FireMedia? mediaInput}) async {
    final media = mediaInput ?? cameraInput
      ?..cache()
      ..merge();
    final text = input.value;
    if (_groupImage == null || _groupName.isEmpty) return;
    if (text.isEmpty && media == null) return;

    final groupID = ComposedID();

    final chat = Chat(Down4ID(),
        text: text,
        mediaID: media?.id,
        senderID: g.self.id,
        root: groupID,
        timestamp: makeTimestamp())
      ..cache()
      ..merge();

    final members = Set<ComposedID>.from(widget.people.asComposedIDs())
      ..add(g.self.id);

    final group = Group(groupID,
        activity: makeTimestamp(),
        isPrivate: _private,
        name: _groupName,
        mediaID: _groupImage!.id,
        group: members,
        ownerID: g.self.id);

    widget.makeGroup(group, _groupImage!, chat);
  }

  void reloadItems() {
    setState(() {
      _items = [
        ..._items.sublist(0, _items.length - 1),
        groupMaker(fold: false),
      ];
    });
  }

  // @override
  // void loadMediasConsole([
  //   bool images = true,
  //   bool extra = false,
  //   void Function(FireMedia)? forGroup,
  // ]) {
  //   console = mediaConsole(
  //       uselessInput: mainInput,
  //       selectMedia: forGroup ?? ,
  //       afterImport: () => loadMediasConsole(images, mode, extra, group),
  //       back: back,
  //       switchMediasType: () => loadMediasConsole(!images, mode, extra, group),
  //       switchMediaMode: switchMode,
  //       switchExtra: () => loadMediasConsole(images, !extra, forGroup),
  //       importGroupMedia: forGroup,
  //       mode: mediasMode[currentMode].$1,
  //       extra: extra,
  //       images: images);
  //
  //   // console = Console(
  //   //   bottomInputs: [input],
  //   //   consoleMedias2: ConsoleMedias2(
  //   //       showImages: images, onSelect: (media) => selectMedia(media)),
  //   //   topButtons: [
  //   //     ConsoleButton(
  //   //         name: "Import",
  //   //         onPress: () async {
  //   //           if (group) {
  //   //             final nodeMedia = await importNodeMedia();
  //   //             if (nodeMedia != null) {
  //   //               _groupImage = nodeMedia;
  //   //               loadBaseConsole();
  //   //               reloadItems();
  //   //             } else {
  //   //               await importConsoleMedias(images: images);
  //   //               loadMediasConsole(images, mode, group);
  //   //             }
  //   //           }
  //   //         }),
  //   //   ],
  //   //   bottomButtons: [
  //   //     ConsoleButton(
  //   //       name: "Back",
  //   //       onPress: () => loadBaseConsole(images: images),
  //   //     ),
  //   //     ConsoleButton(
  //   //       isMode: true,
  //   //       isActivated: !group,
  //   //       isGreyedOut: group,
  //   //       name: images ? "Images" : "Videos",
  //   //       onPress: () => loadMediaConsole(images: !images),
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
  //   console = Console(
  //     // mediasInfo: consoleMedias(images: images, show: false),
  //     bottomInputs: [],
  //     topButtons: [
  //       ConsoleButton(
  //         isMode: true,
  //         isActivated: false,
  //         isGreyedOut: true,
  //         name: _private ? "Private" : "Public",
  //         onPress: () {
  //           _private = !_private;
  //           loadBaseConsole();
  //         },
  //       ),
  //     ],
  //     bottomButtons: [
  //       ConsoleButton(name: "Back", onPress: widget.back),
  //       ConsoleButton(
  //         name: cameraInput == null ? "Camera" : "@Camera",
  //         onPress: loadSquaredCameraConsole,
  //       ),
  //       ConsoleButton(name: "Medias", onPress: loadMediasConsole),
  //     ],
  //     // consoleRow: Console3(
  //     //   beginSizes: const [0.25, 0.25, 0.25, 0.25],
  //     //   endSizes: const [0.0, 0.25, 0.50, 0.25],
  //     //   ctrl: aCtrl,
  //     //   maxHeight: Console.buttonHeight,        widgets: [
  //     //     // ConsoleButton(name: "Back", onPress: widget.back),
  //     //     ConsoleButton(
  //     //       name: cameraInput == null ? "CAMERA" : "@CAMERA",
  //     //       onPress: loadSquaredCameraConsole,
  //     //     ),
  //     //     // ConsoleButton(
  //     //     //   isMode: true,
  //     //     //   isActivated: false,
  //     //     //   isGreyedOut: true,
  //     //     //   name: _private ? "PRIVATE" : "PUBLIC",
  //     //     //   onPress: () {
  //     //     //     _private = !_private;
  //     //     //     loadBaseConsole();
  //     //     //   },
  //     //     // ),
  //     //     ConsoleButton(name: "MEDIAS", onPress: loadMediasConsole),
  //     //     mainInput,
  //     //     ConsoleButton(name: "SEND", onPress: send),
  //     //   ],
  //     // ),
  //   );
  //   setState(() {});
  // }

  // Future<void> loadSquaredCameraConsole({
  //   CameraController? ctrl,
  //   int cam = 0,
  //   String? path,
  //   String? mimetype,
  // }) async {
  //   if (ctrl == null) {
  //     try {
  //       ctrl = CameraController(g.cameras[cam], ResolutionPreset.high);
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
  //     console = Console(
  //       bottomInputs: [input],
  //       cameraController: ctrl,
  //       topButtons: [
  //         ConsoleButton(
  //           name: "Capture",
  //           isSpecial: true,
  //           shouldBeDownButIsnt: ctrl!.value.isRecordingVideo,
  //           onPress: () async {
  //             final XFile f = await ctrl!.takePicture();
  //             loadSquaredCameraConsole(
  //                 ctrl: ctrl, cam: cam, path: f.path, mimetype: f.mimeType);
  //           },
  //           onLongPress: () async {
  //             await ctrl!.startVideoRecording();
  //             loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
  //           },
  //           onLongPressUp: () async {
  //             final XFile f = await ctrl!.stopVideoRecording();
  //             loadSquaredCameraConsole(
  //                 ctrl: ctrl, cam: cam, path: f.path, mimetype: f.mimeType);
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
  //           final bool isVideo = path.extension().isVideoExtension();
  //           if (isVideo) {
  //             tn = await VideoThumbnail.thumbnailData(video: path, quality: 90);
  //           }
  //           vpc?.dispose();
  //           cameraInput = FireMedia(mediaID,
  //               tinyThumbnail: makeTiny(tn ?? data),
  //               owner: g.self.id,
  //               timestamp: u.timeStamp(),
  //               aspectRatio: ctrl!.value.aspectRatio,
  //               extension: path.extension(),
  //               isReversed: cam == 1,
  //               isSquared: true,
  //               mime: mimetype!);
  //           await cameraInput!.write(
  //               imageData:  tn ?? data,
  //               videoData: isVideo ? data : null);
  //           loadBaseConsole();
  //         },
  //       ),
  //     ];
  //     final bottomButtons = [
  //       ConsoleButton(
  //         name: "Back",
  //         onPress: () {
  //           File(path).delete();
  //           vpc?.dispose();
  //           loadSquaredCameraConsole(ctrl: ctrl, cam: cam);
  //         },
  //       ),
  //       ConsoleButton(
  //           name: "Cancel",
  //           onPress: () {
  //             File(path).delete();
  //             vpc?.dispose();
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
  //       console = Console(
  //           bottomInputs: [input],
  //           videoForPreview: VideoPreview(
  //               videoPlayer: BetterPlayer(controller: vpc),
  //               videoAspectRatio: ctrl!.value.aspectRatio,
  //               isReversed: cam == 1),
  //           topButtons: topBottons,
  //           bottomButtons: bottomButtons);
  //     } else {
  //       console = Console(
  //           bottomInputs: [input],
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

  // @override
  // void dispose() async {
  //   // focusNode.dispose();
  //   // aCtrl!.dispose();
  //   // cameraInput?.delete();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      backFunction: widget.back,
      pages: [
        Down4Page(
          scrollController: _scrollController,
          staticList: true,
          trueLen: widget.people.length + 1,
          title: "Group",
          list: _items,
          console: console,
        ),
      ],
    );
  }

  @override
  Console3 get console => Console3(
          rows: [
            {
              basicComposeRowName: basicComposeRow,
              basicMediaRowName: basicMediasRow,
              basicCameraRowName: basicCameraRow,
              cameraConfirmationRowName: cameraConfirmationRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  late List<String> currentConsolesName = [basicComposeRowName];

  @override
  int get currentPageIndex => 0;

  @override
  String get backFromCameraConsoleName => basicComposeRowName;

  @override
  String get backFromMediasConsoleName => basicComposeRowName;

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
    ),
    MyTextEditor(
        onInput: (s, h) {
          _groupName = s;
          onInput(s, h);
        },
        specificStyle: g.theme.paletteNameStyle(selected: false),
        placeholderStyle: g.theme.palettePlaceholderTextStyle,
        onFocusChange: onFocusChange,
        maxWidth: g.sizes.w * (1 / golden),
        isConsoleInput: false,
        config: Input2.singleLine,
        placeHolder: "Group Name..."),
  ];

  MyTextEditor get groupInput => inputs[1];

  @override
  late List<Extra> extras = [];
}
