import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

import '../data_objects.dart';
import '_page_utils.dart';

import '../web_requests.dart' as r;

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/_render_utils.dart';

class UserMakerPage extends StatefulWidget {
  // final void Function() success;
  final String? errorMessage;
  final Future<void> Function({
    required String id,
    required String name,
    required String lastName,
    required FireMedia media,
  }) initUser;

  const UserMakerPage({
    required this.initUser,
    // required this.success,
    this.errorMessage,
    Key? key,
  }) : super(key: key);

  @override
  State<UserMakerPage> createState() => _UserMakerPageState();
}

class _UserMakerPageState extends State<UserMakerPage>
    with WidgetsBindingObserver, Pager2, Camera2, Input2 {
  late String mainPlaceHolder = widget.errorMessage ?? "@username";
  // late FocusNode f1 = FocusNode()..addListener(_onFocusChange);
  // late FocusNode f2 = FocusNode()..addListener(_onFocusChange);
  // late FocusNode f3 = FocusNode()..addListener(_onFocusChange);

  // void _onFocusChange() {
  //   if (!f1.hasFocus && !f2.hasFocus && !f3.hasFocus && _onBaseConsole) {
  //     inputs();
  //     loadBaseConsole();
  //   }
  // }

  String id = "";
  String firstName = "";
  String lastName = "";
  // @override
  // late Console console;
  // @override
  // ConsoleInput get mainInput => _inputs.first;
  // @override
  // FireMedia? cameraInput;
  @override
  void setTheState() => setState(() {});

  List<Future<bool>> _calls = [];

  // @override
  // VideoPlayerController? videoPreview;

  // late List<ConsoleInput> _inputs;
  // bool _onBaseConsole = true;
  bool _isValidUsername = false;
  //
  // var tec1 = TextEditingController();
  // var tec2 = TextEditingController();
  // var tec3 = TextEditingController();

  late Timer timer;

  // void placeHolderTimeOut() {
  //   if (widget.errorMessage != null) {
  //     Future.delayed(const Duration(seconds: 2), () {
  //       mainPlaceHolder = "@username";
  //       _onFocusChange(); // this is actually what we want
  //     });
  //   }
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(milliseconds: 444), (timer) async {
      print("TIMER CALL");
      if (_calls.isNotEmpty) {
        _isValidUsername = await _calls.last;
      }
    });
    // placeHolderTimeOut();
    // inputs();
  }

  @override
  void dispose() {
    for (final i in inputs) {
      i.fn.dispose();
    }
    timer.cancel();
    // f1.dispose();
    // f2.dispose();
    // f3.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get isReady =>
      _isValidUsername && cameraInput != null && firstName.isNotEmpty;

  // void inputs() {
  //   _inputs = [
  //     // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
  //     ConsoleInput(
  //         focus: f1,
  //         tec: tec1,
  //         borderRadius:
  //             BorderRadius.vertical(top: Radius.circular(Console.consoleRad)),
  //         inputCallBack: (id) async {
  //           _calls.add(r.usernameIsValid(id));
  //           selfID = id.toLowerCase();
  //         },
  //         placeHolder: mainPlaceHolder),
  //     ConsoleInput(
  //       focus: f2,
  //       tec: tec2,
  //       inputCallBack: (firstName) {
  //         _name = firstName;
  //         loadBaseConsole();
  //       },
  //       placeHolder: 'First Name',
  //       value: _name,
  //     ),
  //     ConsoleInput(
  //       focus: f3,
  //       tec: tec3,
  //       inputCallBack: (lastName) {
  //         setState(() => _lastName = lastName);
  //       },
  //       placeHolder: "(Last Name)",
  //       value: _lastName,
  //     )
  //   ];
  // }

  void selectFile() async {
    FilePickerResult? r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg'],
        withData: true);
    if (r?.files.single.path != null && r?.files.single.bytes != null) {
      final String p = r!.files.single.path!;
      final s = await decodeImageSize(r.files.single.bytes!);
      cameraInput = makeCameraMedia(
          cachedPath: p,
          size: s,
          isReversed: false,
          isSquared: true,
          owner: id);
      setTheState();
      // loadBaseConsole();
    }
  }

  double get imageSize => g.sizes.w * 0.3;

  Widget get imagePicker => GestureDetector(
        onTap: selectFile,
        child: Container(
          width: g.sizes.w * 0.3,
          height: g.sizes.w * 0.3,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
          child: cameraInput?.display(size: Size.square(imageSize)) ?? g.ph,
        ),
      );

  // @override
  // void loadBaseConsole({bool activatedProceed = true}) {
  //   _onBaseConsole = true;
  //   console = Console(
  //     initializationConsole: true,
  //     animatedInputs: false,
  //     topInputs: [_inputs[0]],
  //     bottomInputs: [_inputs[1], _inputs[2]],
  //     bottomButtons: [
  //       ConsoleButton(name: "Camera", onPress: loadSquaredCameraConsole),
  //       ConsoleButton(
  //           name: "Recover", isGreyedOut: true, onPress: () => print("TODO")),
  //       ConsoleButton(
  //           // key: buttonKey,
  //           isActivated: isReady && activatedProceed,
  //           isGreyedOut: !isReady,
  //           name: "Proceed",
  //           onPress: () => widget.initUser(
  //               id: selfID,
  //               name: _name,
  //               lastName: _lastName,
  //               media: cameraInput!)),
  //     ],
  //   );
  //   setState(() {});
  // }

  ConsoleButton get recoverButton => ConsoleButton(
      name: "RECOVER", isGreyedOut: true, onPress: () => print("TODO"));
  ConsoleButton get proceedButton => ConsoleButton(
      // key: buttonKey,
      isActivated: isReady,
      isGreyedOut: !isReady,
      name: "PROCEED",
      onPress: () => widget.initUser(
          id: id, name: firstName, lastName: lastName, media: cameraInput!));

  @override
  Console3 get console => Console3(
          rows: [
            {
              "base": ConsoleRow(
                  widgets: [cameraButton, recoverButton, proceedButton],
                  extension: null,
                  widths: null,
                  inputMaxHeight: null),
              basicCameraRowName: basicCameraRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
        onInput: (s, h) => _calls.add(r.usernameIsValid(id = s)),
        onFocusChange: onFocusChange,
        config: Input2.singleLine,
        ctrl: InputController(placeHolder: "username"),
        alignment: AlignmentDirectional.center),
    MyTextEditor(
        onInput: onInput,
        onFocusChange: onFocusChange,
        config: Input2.singleLine,
        ctrl: InputController(placeHolder: "First Name"),
        alignment: AlignmentDirectional.center),
    MyTextEditor(
        onInput: onInput,
        onFocusChange: onFocusChange,
        config: Input2.singleLine,
        ctrl: InputController(placeHolder: "(Last Name)"),
        alignment: AlignmentDirectional.center),
  ];

  MyTextEditor get usernameInput => inputs[0];
  MyTextEditor get nameInput => inputs[1];
  MyTextEditor get lastNameInput => inputs[2];

  Widget get full => Container(
        color: g.theme.backGroundColor,
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              imagePicker,
              usernameInput.widget,
              nameInput.widget,
              lastNameInput.widget,
            ],
          ),
        ),
      );

  // Future<void> camConsole({
  //   CameraController? ctrl,
  //   int cam = 0,
  //   String? path,
  //   String? mimetype,
  // }) async {
  //   if (ctrl == null) {
  //     try {
  //       ctrl = CameraController(
  //         g.cameras[cam],
  //         ResolutionPreset.high,
  //         enableAudio: false,
  //       );
  //       await ctrl.initialize();
  //     } catch (err) {
  //       baseConsole();
  //     }
  //   }
  //   _onBaseConsole = false;
  //   Future<void> nextCam() async {
  //     await ctrl?.dispose();
  //     return camConsole(cam: (cam + 1) % 2);
  //   }
  //
  //   if (path == null || mimetype == null) {
  //     console = Console(
  //       initializationConsole: true,
  //       cameraController: ctrl,
  //       topButtons: [
  //         ConsoleButton(
  //           name: "Capture",
  //           onPress: () async {
  //             XFile f = await ctrl!.takePicture();
  //             camConsole(
  //               ctrl: ctrl,
  //               cam: cam,
  //               path: f.path,
  //               mimetype: f.mimeType,
  //             );
  //           },
  //         ),
  //       ],
  //       bottomButtons: [
  //         ConsoleButton(name: "Back", onPress: baseConsole),
  //         ConsoleButton(
  //           name: cam == 0 ? "Front" : "Rear",
  //           onPress: nextCam,
  //           isMode: true,
  //         ),
  //       ],
  //     );
  //   } else {
  //     console = Console(
  //       initializationConsole: true,
  //       previewMedia: makeCameraMedia(
  //         path,
  //         ctrl?.value.aspectRatio ?? 1.0,
  //         cam == 1,
  //       ),
  //       // imageForPreview: ImagePreview(
  //       //     path: path,
  //       //     isReversed: cam == 1,
  //       //     imageAspectRatio: ctrl?.value.aspectRatio ?? 1.0),
  //       topButtons: [
  //         ConsoleButton(
  //           name: "Accept",
  //           onPress: () async {
  //             _imagePath = path;
  //             _isReversed = cam == 1;
  //             _imageAspectRatio = ctrl!.value.aspectRatio;
  //             _mimeType = mimetype;
  //             // _imageExtension = p.extension(path);
  //             baseConsole();
  //           },
  //         ),
  //       ],
  //       bottomButtons: [
  //         ConsoleButton(
  //           name: "Back",
  //           onPress: () {
  //             io.File(path).delete();
  //             camConsole(ctrl: ctrl, cam: cam);
  //           },
  //         ),
  //         ConsoleButton(
  //             name: "Cancel",
  //             onPress: () {
  //               ctrl?.dispose();
  //               baseConsole();
  //             }),
  //       ],
  //     );
  //   }
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    // final columnWidgets = [
    //   UserMakerPalette(
    //       selectFile: () async {
    //         FilePickerResult? r = await FilePicker.platform.pickFiles(
    //             type: FileType.custom,
    //             allowedExtensions: ['jpg', 'png', 'jpeg'],
    //             withData: true);
    //         if (r?.files.single.path != null && r?.files.single.bytes != null) {
    //           final String p = r!.files.single.path!;
    //           final s = await decodeImageSize(r.files.single.bytes!);
    //           cameraInput = makeCameraMedia(
    //               cachedPath: p,
    //               size: s,
    //               isReversed: false,
    //               isSquared: true,
    //               owner: selfID);
    //           loadBaseConsole();
    //         }
    //       },
    //       name: _name,
    //       id: selfID,
    //       lastName: _lastName,
    //       media: cameraInput),
    //   // _errorTryAgain
    //   //     ? Container(
    //   //         margin: const EdgeInsets.symmetric(horizontal: 22.0),
    //   //         child: const Text(
    //   //           "Rare error, someone might have just taken that username, please try again",
    //   //           textAlign: TextAlign.center,
    //   //         ))
    //   //     : const SizedBox.shrink(),
    // ];

    return Andrew(pages: [
      Down4Page(
        title: "Initialization",
        console: console,
        list: [full],
      )
    ]);
  }

  @override
  String get backFromCameraConsoleName => "base";

  @override
  late List<Extra> extras = [];
}
