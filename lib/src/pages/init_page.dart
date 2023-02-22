import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:down4/src/globals.dart';
import 'package:path/path.dart' as p;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';

import '../web_requests.dart' as r;
import '../_down4_dart_utils.dart' as u;
import '../data_objects.dart' show ID;

import '../render_objects/console.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/_down4_flutter_utils.dart';

class UserMakerPage extends StatefulWidget {
  final void Function() success;
  final Future<bool> Function({
    required String id,
    required String name,
    required String lastName,
    required String imPath,
    required String imExtension,
    required double imAspectRatio,
    required bool isSquared,
    required bool isReversed,
  }) initUser;

  const UserMakerPage({
    required this.initUser,
    required this.success,
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
  String _imageExtension = "";
  Console? _console;
  dynamic _inputs;
  double _imageAspectRatio = 1.0;
  bool _isReversed = false;
  bool _isSquared = false;
  bool _onBaseConsole = true;
  List<Future<bool>> _calls = [];
  bool _isValidUsername = false;
  bool _errorTryAgain = false;
  var tec1 = TextEditingController();
  var tec2 = TextEditingController();
  var tec3 = TextEditingController();

  late var timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 444), (timer) async {
      print("TIMER CALL");
      if (_calls.isNotEmpty) {
        _isValidUsername = await _calls.last;
        baseConsole();
      }
    });
    inputs();
    if (_onBaseConsole) baseConsole();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  bool get isReady =>
      _isValidUsername &&
      _imagePath.isNotEmpty &&
      _name.isNotEmpty &&
      _imageExtension.isNotEmpty;

  void inputs() {
    _inputs = [
      // preloading inputs here so they don't redraw on setState because the redraw hides the keyboard which is very undesirable
      ConsoleInput(
          tec: tec1,
          inputCallBack: (id) async {
            _calls.add(r.usernameIsValid(id));
            _id = id.toLowerCase();
          },
          placeHolder: "@username"),
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
    _onBaseConsole = true;
    _console = Console(
      initializationConsole: true,
      animatedInputs: false,
      topInputs: [_inputs[0]],
      bottomInputs: [_inputs[1], _inputs[2]],
      bottomButtons: [
        ConsoleButton(name: "Camera", onPress: camConsole),
        ConsoleButton(name: "Recover", onPress: () => print("TODO")),
        ConsoleButton(
            // key: buttonKey,
            isActivated: isReady && activatedProceed,
            greyedOut: !isReady,
            name: "Proceed",
            onPress: () async {
              baseConsole(activatedProceed: false);
              _errorTryAgain = !await widget.initUser(
                id: _id,
                name: _name,
                lastName: _lastName,
                imPath: _imagePath,
                imExtension: _imageExtension,
                imAspectRatio: _imageAspectRatio,
                isReversed: _isReversed,
                isSquared: _isSquared,
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
    String? path,
  }) async {
    if (ctrl == null) {
      try {
        ctrl = CameraController(
          g.cameras[cam],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await ctrl.initialize();
      } catch (err) {
        baseConsole();
      }
    }
    _onBaseConsole = false;
    Future<void> nextCam() async {
      await ctrl?.dispose();
      return camConsole(cam: (cam + 1) % 2);
    }

    if (path == null) {
      _console = Console(
        initializationConsole: true,
        cameraController: ctrl,
        topButtons: [
          ConsoleButton(
            name: "Capture",
            onPress: () async {
              XFile f = await ctrl!.takePicture();
              camConsole(ctrl: ctrl, cam: cam, path: f.path);
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
        initializationConsole: true,
        imageForPreview: ImagePreview(
            path: path,
            isReversed: cam == 1,
            imageAspectRatio: ctrl?.value.aspectRatio ?? 1.0),
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () async {
              _imagePath = path;
              _isReversed = cam == 1;
              _isSquared = true;
              _imageAspectRatio = ctrl!.value.aspectRatio;
              _imageExtension = p.extension(path);
              baseConsole();
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            onPress: () {
              io.File(path).delete();
              camConsole(ctrl: ctrl, cam: cam);
            },
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
          if (r?.files.single.path != null && r?.files.single.bytes != null) {
            final String thePath = r!.files.single.path as String;
            final imageSize = await decodeImageSize(r.files.single.bytes!);
            _isSquared = false;
            _imageAspectRatio = imageSize.aspectRatio;
            _imagePath = thePath;
            _imageExtension = p.extension(thePath);
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
