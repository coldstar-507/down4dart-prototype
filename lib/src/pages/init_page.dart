import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';

import '../web_requests.dart' as r;
import '../down4_utility.dart' as u;

import '../render_objects/console.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';

class UserMakerPage extends StatefulWidget {
  final Future<bool> Function(String, String, String, Uint8List, bool) initUser;
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
  Uint8List _image = Uint8List(0);
  Console? _console;
  dynamic _inputs;
  bool _toReverse = false;
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

  bool get isReady => _isValidUsername && _image.isNotEmpty && _name.isNotEmpty;

  void inputs() {
    _inputs = [
      // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
      ConsoleInput(
        tec: tec1,
        inputCallBack: (id) async {
          _isValidUsername = await r.usernameIsValid(id);
          _id = id.toLowerCase();
          baseConsole();
        },
        placeHolder: "@username",
        value: _id == '' ? '' : '@' + _id,
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

  void baseConsole() {
    _console = Console(
      animatedInputs: false,
      topInputs: [_inputs[0]],
      inputs: [_inputs[1], _inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: camConsole),
        ConsoleButton(name: "Recover", onPress: () => print("TODO")),
        ConsoleButton(
            key: buttonKey,
            isActivated: isReady,
            name: "Proceed",
            onPress: () async {
              _errorTryAgain = !await widget.initUser(
                _id,
                _name,
                _lastName,
                _image,
                _toReverse,
              );
              if (_errorTryAgain) {
                setState(() {});
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
        toMirror: cam == 1,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () async {
              final compressedImage =
                  await FlutterImageCompress.compressWithFile(
                path,
                minHeight: 256,
                minWidth: 256,
                format: CompressFormat.png,
                quality: 60,
              );
              _image = compressedImage ?? Uint8List(0);
              _toReverse = cam == 1;
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
              withData: true);
          if (r?.files.single.bytes != null) {
            final compressedBytes = await FlutterImageCompress.compressWithList(
              r!.files.single.bytes!,
              minHeight: 520,
              minWidth: 520,
              quality: 40,
            );
            setState(() => _image = compressedBytes);
            baseConsole();
          }
        },
        name: _name,
        id: _id,
        lastName: _lastName,
        image: _image,
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
        columnWidgets: columnWidgets,
      )
    ]);
  }
}
