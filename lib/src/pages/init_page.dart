import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';

import '../web_requests.dart' as r;
import '../down4_utility.dart' as u;

import '../render_objects/console.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/render_utils.dart';

class UserMakerPage extends StatefulWidget {
  final Future<bool> Function(String, String, String, String, double, bool)
      initUser;
  final void Function() success;
  final List<CameraDescription> cameras;

  const UserMakerPage({
    required this.initUser,
    required this.success,
    required this.cameras,
    Key? key,
  }) : super(key: key);

  @override
  State<UserMakerPage> createState() => _UserMakerPageState();
}

class _UserMakerPageState extends State<UserMakerPage> {
  final buttonKey = GlobalKey();
  String _id = "";
  String _name = "";
  String _lastName = "";
  String _imagePath = "";
  Console? _console;
  dynamic _inputs;
  double _imageAspectRatio = 1.0;
  bool _toReverse = false;
  List<Future<bool>> _readyUsernameCalls = [];
  bool _isValidUsername = false;
  bool _errorTryAgain = false;
  var tec1 = TextEditingController();
  var tec2 = TextEditingController();
  var tec3 = TextEditingController();

  @override
  void initState() {
    super.initState();
    inputs();
    baseConsole();
  }

  bool get isReady =>
      _isValidUsername && _imagePath.isNotEmpty && _name.isNotEmpty;

  void inputs() {
    _inputs = [
      // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
      ConsoleInput(
        tec: tec1,
        inputCallBack: (id) async {
          _readyUsernameCalls.add(r.usernameIsValid(id));
          _isValidUsername = await _readyUsernameCalls.last;
          _id = id.toLowerCase();
          baseConsole();
        },
        placeHolder: "@username",
        value: _id == '' ? '' : '@$_id',
      ),
      ConsoleInput(
        tec: tec2,
        inputCallBack: (firstName) {
          _name = firstName;
          baseConsole();
        },
        placeHolder: 'First Name',
        value: _name,
      ),
      ConsoleInput(
        tec: tec3,
        inputCallBack: (lastName) {
          setState(() => _lastName = lastName);
        },
        placeHolder: "(Last Name)",
        value: _lastName,
      )
    ];
  }

  void baseConsole({bool activatedProceed = true}) {
    _console = Console(
      animatedInputs: false,
      topInputs: [_inputs[0]],
      bottomInputs: [_inputs[1], _inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: camConsole),
        ConsoleButton(name: "Recover", onPress: () => print("TODO")),
        ConsoleButton(
            key: buttonKey,
            isActivated: isReady && activatedProceed,
            greyedOut: !isReady,
            name: "Proceed",
            onPress: () async {
              baseConsole(activatedProceed: false);
              _errorTryAgain = !await widget.initUser(
                _id,
                _name,
                _lastName,
                _imagePath,
                _imageAspectRatio,
                _toReverse,
              );
              if (_errorTryAgain) {
                baseConsole();
              } else {
                widget.success();
              }
            }),
      ],
    );
    setState(() {});
  }

  Future<void> camConsole({
    CameraController? ctrl,
    int cam = 0,
    bool reload = false,
    String? path,
  }) async {
    if (ctrl == null || reload) {
      try {
        ctrl = CameraController(
          widget.cameras[cam],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await ctrl.initialize();
      } catch (err) {
        baseConsole();
      }
    }

    void nextCam() => cam == 0
        ? camConsole(ctrl: ctrl, cam: 1, reload: true)
        : camConsole(ctrl: ctrl, cam: 0, reload: true);

    if (path == null) {
      _console = Console(
        cameraController: ctrl,
        toMirror: cam == 1,
        aspectRatio: ctrl?.value.aspectRatio,
        topButtons: [
          ConsoleButton(
            name: "Capture",
            onPress: () async {
              XFile? f = await ctrl?.takePicture();
              camConsole(ctrl: ctrl, cam: cam, reload: false, path: f?.path);
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: baseConsole),
          ConsoleButton(
            name: cam == 0 ? "Front" : "Rear",
            onPress: nextCam,
            isMode: true,
          ),
        ],
      );
    } else {
      _console = Console(
        imagePreviewPath: path,
        aspectRatio: ctrl?.value.aspectRatio ?? 1.0,
        toMirror: cam == 1,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () async {
              _imagePath = path;
              _toReverse = cam == 1;
              _imageAspectRatio = ctrl!.value.aspectRatio;
              baseConsole();
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            onPress: () => camConsole(ctrl: ctrl, cam: cam, reload: false),
          ),
          ConsoleButton(
              name: "Cancel",
              onPress: () {
                ctrl?.dispose();
                baseConsole();
              }),
        ],
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final columnWidgets = [
      UserMakerPalette(
        selectFile: () async {
          FilePickerResult? r = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['jpg', 'png', 'jpeg'],
              withData: false);
          if (r?.files.single.path != null) {
            final String thePath = r?.files.single.path as String;
            final imageSize =
                await calculateImageDimension(f: io.File(thePath));
            _imageAspectRatio = imageSize?.aspectRatio ?? 1.0;
            _imagePath = r!.files.single.path!;
            baseConsole();
          }
        },
        name: _name,
        id: _id,
        lastName: _lastName,
        imagePath: _imagePath,
      ),
      _errorTryAgain
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 22.0),
              child: const Text(
                "Rare error, someone might have just taken that username, please try again",
                textAlign: TextAlign.center,
              ))
          : const SizedBox.shrink(),
    ];

    return Andrew(pages: [
      Down4Page(
        title: "Initialization",
        console: _console!,
        list: columnWidgets,
      )
    ]);
  }
}
