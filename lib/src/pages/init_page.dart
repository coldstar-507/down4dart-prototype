import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../data_objects.dart';
import '_page_utils.dart';

import '../web_requests.dart' as r;

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

class _UserMakerPageState extends State<UserMakerPage> with Pager, Camera {
  late String mainPlaceHolder = widget.errorMessage ?? "@username";
  late FocusNode f1 = FocusNode()..addListener(_onFocusChange);
  late FocusNode f2 = FocusNode()..addListener(_onFocusChange);
  late FocusNode f3 = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!f1.hasFocus && !f2.hasFocus && !f3.hasFocus && _onBaseConsole) {
      inputs();
      loadBaseConsole();
    }
  }

  final buttonKey = GlobalKey();
  @override
  String selfID = "";
  String _name = "";
  String _lastName = "";
  @override
  late Console console;
  @override
  ConsoleInput get mainInput => _inputs.first;
  @override
  FireMedia? cameraInput;
  @override
  void setTheState() => setState(() {});

  List<Future<bool>> _calls = [];

  late List<ConsoleInput> _inputs;
  bool _onBaseConsole = true;
  bool _isValidUsername = false;

  var tec1 = TextEditingController();
  var tec2 = TextEditingController();
  var tec3 = TextEditingController();

  late Timer timer;

  void placeHolderTimeOut() {
    if (widget.errorMessage != null) {
      Future.delayed(const Duration(seconds: 2), () {
        mainPlaceHolder = "@username";
        _onFocusChange(); // this is actually what we want
      });
    }
  }

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 444), (timer) async {
      print("TIMER CALL");
      if (_calls.isNotEmpty) {
        _isValidUsername = await _calls.last;
        loadBaseConsole();
      }
    });
    placeHolderTimeOut();
    inputs();
    if (_onBaseConsole) loadBaseConsole();
  }

  @override
  void dispose() {
    timer.cancel();
    f1.dispose();
    f2.dispose();
    f3.dispose();
    super.dispose();
  }

  bool get isReady =>
      _isValidUsername && cameraInput != null && _name.isNotEmpty;

  void inputs() {
    _inputs = [
      // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
      ConsoleInput(
          focus: f1,
          tec: tec1,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Console.consoleRad)),
          inputCallBack: (id) async {
            _calls.add(r.usernameIsValid(id));
            selfID = id.toLowerCase();
          },
          placeHolder: mainPlaceHolder),
      ConsoleInput(
        focus: f2,
        tec: tec2,
        inputCallBack: (firstName) {
          _name = firstName;
          loadBaseConsole();
        },
        placeHolder: 'First Name',
        value: _name,
      ),
      ConsoleInput(
        focus: f3,
        tec: tec3,
        inputCallBack: (lastName) {
          setState(() => _lastName = lastName);
        },
        placeHolder: "(Last Name)",
        value: _lastName,
      )
    ];
  }

  @override
  void loadBaseConsole({bool activatedProceed = true}) {
    _onBaseConsole = true;
    console = Console(
      initializationConsole: true,
      animatedInputs: false,
      topInputs: [_inputs[0]],
      bottomInputs: [_inputs[1], _inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: loadSquaredCameraConsole),
        ConsoleButton(
            name: "Recover", isGreyedOut: true, onPress: () => print("TODO")),
        ConsoleButton(
            // key: buttonKey,
            isActivated: isReady && activatedProceed,
            isGreyedOut: !isReady,
            name: "Proceed",
            onPress: () => widget.initUser(
                id: selfID,
                name: _name,
                lastName: _lastName,
                media: cameraInput!)),
      ],
    );
    setState(() {});
  }

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
    final columnWidgets = [
      UserMakerPalette(
          selectFile: () async {
            FilePickerResult? r = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'png', 'jpeg'],
                withData: true);
            if (r?.files.single.path != null && r?.files.single.bytes != null) {
              final String p = r!.files.single.path!;
              final s = await decodeImageSize(r.files.single.bytes!);
              cameraInput = makeCameraMedia(p, s.aspectRatio, false, selfID);
              loadBaseConsole();
            }
          },
          name: _name,
          id: selfID,
          lastName: _lastName,
          media: cameraInput),
      // _errorTryAgain
      //     ? Container(
      //         margin: const EdgeInsets.symmetric(horizontal: 22.0),
      //         child: const Text(
      //           "Rare error, someone might have just taken that username, please try again",
      //           textAlign: TextAlign.center,
      //         ))
      //     : const SizedBox.shrink(),
    ];

    return Andrew(pages: [
      Down4Page(
        title: "Initialization",
        console: console,
        list: columnWidgets,
      )
    ]);
  }
}
