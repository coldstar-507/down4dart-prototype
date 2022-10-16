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
  _UserMakerPageState createState() => _UserMakerPageState();
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
      topInputs: [_inputs[0]],
      inputs: [_inputs[1], _inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: () => print("TODO")),
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

  Future<void> camConsole([
    CameraController? ctrl,
    int cameraIdx = 0,
    ResolutionPreset resolution = ResolutionPreset.medium,
    FlashMode flashMode = FlashMode.off,
    bool reloadCtrl = false,
    String? path,
  ]) async {
    if (ctrl == null || reloadCtrl) {
      try {
        ctrl = CameraController(
          widget.cameras[cameraIdx],
          resolution,
          enableAudio: true,
        );
        await ctrl.initialize();
      } catch (err) {
        baseConsole();
      }
    }

    ctrl?.setFlashMode(flashMode);

    void nextCam() => cameraIdx == 0
        ? camConsole(ctrl, 1, resolution, FlashMode.off, true)
        : camConsole(ctrl, 0, resolution, FlashMode.off, true);

    void nextRes() {
      switch (resolution) {
        case ResolutionPreset.low:
          camConsole(ctrl, cameraIdx, ResolutionPreset.medium, flashMode, true);
          break;
        case ResolutionPreset.medium:
          camConsole(ctrl, cameraIdx, ResolutionPreset.high, flashMode, true);
          break;
        case ResolutionPreset.high:
          camConsole(ctrl, cameraIdx, ResolutionPreset.low, flashMode, true);
          break;
        case ResolutionPreset.veryHigh:
        // TODO: Handle this case.
          break;
        case ResolutionPreset.ultraHigh:
        // TODO: Handle this case.
          break;
        case ResolutionPreset.max:
        // TODO: Handle this case.
          break;
      }
    }

    void nextFlash() => flashMode == FlashMode.off
        ? camConsole(ctrl, cameraIdx, resolution, FlashMode.torch)
        : camConsole(ctrl, cameraIdx, resolution, FlashMode.off);

    if (path == null) {
      _console = Console(
        cameraController: ctrl,
        aspectRatio: ctrl?.value.aspectRatio,
        topButtons: [
          ConsoleButton(
            name: cameraIdx == 0 ? "Front" : "Rear",
            onPress: nextCam,
            isMode: true,
          ),
          ConsoleButton(
            name: "Capture",
            onPress: () async {
              XFile? f = await ctrl?.takePicture();
              if (f != null) {
                path = f.path;
                Uint8List? compressed;
                compressed = await FlutterImageCompress.compressWithFile(
                  path!,
                  minHeight: 520, // palette height
                  minWidth: 520, // palette height
                  quality: 40,
                );
                if (compressed != null) {
                  _image = compressed;
                } else {
                  path = null;
                }
              }
              camConsole(
                ctrl,
                cameraIdx,
                resolution,
                FlashMode.off,
                false,
                path,
              );
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: baseConsole),
          ConsoleButton(
            name: resolution.name.capitalize(),
            onPress: nextRes,
            isMode: true,
          ),
          ConsoleButton(
            name: flashMode.name.capitalize(),
            onPress: nextFlash,
            isMode: true,
          ),
        ],
      );
    } else {
      _console = Console(
        imagePreviewPath: path,
        toMirror: cameraIdx == 1,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () {
              _toReverse = cameraIdx == 1;
              baseConsole();
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
              name: "Back",
              onPress: () {
                _image = Uint8List(0);
                camConsole(ctrl, cameraIdx, resolution, flashMode, false, null);
              }),
          ConsoleButton(name: "Cancel", onPress: baseConsole),
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

    return Jeff(pages: [
      Down4Page(
        title: "Initialization",
        console: _console!,
        columnWidgets: columnWidgets,
      )
    ]);
  }
}
