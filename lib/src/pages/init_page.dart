import 'dart:async';

import 'package:camera/camera.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../data_objects/_data_utils.dart';
import '../data_objects/firebase.dart';
import '../data_objects/medias.dart';
import '_page_utils.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/navigator.dart';
import '../render_objects/_render_utils.dart';

class UserMakerPage extends StatefulWidget {
  final String? errorMessage;
  final Future<void> Function({
    required ComposedID id,
    required String deviceID,
    required String name,
    required String lastName,
    required double longitude,
    required double latitude,
    required Down4Media media,
  }) initUser;

  final String deviceID;
  final double latitude, longitude;
  final Region? closestRegion;

  const UserMakerPage({
    required this.initUser,
    required this.latitude,
    required this.longitude,
    required this.closestRegion,
    required this.deviceID,
    this.errorMessage,
    Key? key,
  }) : super(key: key);

  @override
  State<UserMakerPage> createState() => _UserMakerPageState();
}

class _UserMakerPageState extends State<UserMakerPage>
    with WidgetsBindingObserver, Pager2, Camera2, Input2 {
  late String mainPlaceHolder = widget.errorMessage ?? "@username";

  String get id => idInput.value;
  String get firstName => firstNameInput.value;
  String get lastName => lastNameInput.value;
  late Region region = widget.closestRegion ?? Region.america;
  ComposedID get willBeReplacedID => ComposedID(unique: id, region: region);

  @override
  void setTheState() => setState(() {});

  List<Future<bool>> _calls = [];

  bool _isValidUsername = false;

  late Timer timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(milliseconds: 444), (timer) async {
      print("TIMER CALL");
      if (_calls.isNotEmpty) {
        print("USERNAME CALL");
        _isValidUsername = await _calls.last;
        setTheState();
      }
    });
  }

  @override
  void dispose() {
    for (final i in inputs) {
      i.fn.dispose();
    }
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get isReady =>
      _isValidUsername && cameraInput != null && firstName.isNotEmpty;

  void selectFile() async {
    FilePickerResult? r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg'],
        withData: true);
    if (r?.files.single.path != null && r?.files.single.bytes != null) {
      final String p = r!.files.single.path!;
      final s = await decodeImageSize(r.files.single.bytes!);
      cameraInput = await makeCameraMedia(
          writeFromCachedPath: false,
          cachedPath: p,
          size: s,
          isReversed: false,
          isSquared: true,
          owner: willBeReplacedID);
      setTheState();
    }
  }

  Size get imageSize => Size.square(g.sizes.w * 0.3);

  Widget get userImage =>
      cameraInput?.display(
          key: GlobalKey(), size: imageSize, forceSquare: true) ??
      g.ph;

  Widget get imagePicker => GestureDetector(
        onTap: selectFile,
        child: Container(
          width: g.sizes.w * 0.3,
          height: g.sizes.w * 0.3,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
          child: userImage,
        ),
      );

  ConsoleButton get recoverButton => ConsoleButton(
      name: "RECOVER", isGreyedOut: true, onPress: () => print("TODO"));
    
  ConsoleButton get proceedButton => ConsoleButton(
      isActivated: isReady,
      isGreyedOut: !isReady,
      name: "PROCEED",
      onPress: () => widget.initUser(
          id: ComposedID(unique: id, region: region),
          deviceID: widget.deviceID,
          name: firstName,
          lastName: lastName,
          latitude: widget.latitude,
          longitude: widget.longitude,
          media: cameraInput!));

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
              cameraConfirmationRowName: cameraConfirmationRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  ConsoleButton get cameraButton => ConsoleButton(
        name: "CAMERA",
        onPress: () async {
          if (cameraController == null) {
            cameraController = CameraController(cam, ResolutionPreset.high);
            await cameraController?.initialize();
            changeConsole("camera");
          }
        },
      );

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: (s, h) => _calls.add(isUsernameValid(s)),
      onFocusChange: onFocusChange,
      config: Input2.singleLine,
      placeHolder: "username",
      centered: true,
    ),
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.singleLine,
      placeHolder: "First Name",
      centered: true,
    ),
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.singleLine,
      placeHolder: "(Last Name)",
      centered: true,
    ),
  ];

  MyTextEditor get idInput => inputs[0];
  MyTextEditor get firstNameInput => inputs[1];
  MyTextEditor get lastNameInput => inputs[2];

  Widget get full => Container(
        color: g.theme.backGroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              imagePicker,
              const SizedBox(height: 20),
              idInput.initInput,
              const SizedBox(height: 20),
              firstNameInput.initInput,
              const SizedBox(height: 20),
              lastNameInput.initInput,
              ...widget.latitude == 0 && widget.longitude == 0
                  ? [
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          regionButton(Region.america),
                          const SizedBox(width: 20),
                          regionButton(Region.europe),
                          const SizedBox(width: 20),
                          regionButton(Region.asia),
                        ],
                      )
                    ]
                  : []
            ],
          ),
        ),
      );

  Widget regionButton(Region reg) => Expanded(
      child: GestureDetector(
          onTap: () => setState(() => region = reg),
          child: SizedBox(
              height: Console.buttonHeight,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: region == reg
                          ? g.theme.selectedRegionColor
                          : g.theme.inputColor,
                      borderRadius: BorderRadius.all(
                          Radius.circular(Console.buttonHeight / 2))),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                          alignment: AlignmentDirectional.center,
                          child: Text(reg.name.capitalize(),
                              style: TextStyle(
                                  color: g.theme.inputTextStyle.color,
                                  fontWeight: region == reg
                                      ? FontWeight.bold
                                      : FontWeight.normal))))))));

  @override
  ConsoleButton get cameraCaptureButton => ConsoleButton(
        name: "CAPTURE",
        isSpecial: true,
        shouldBeDownButIsnt: cameraController?.value.isRecordingVideo ?? false,
        onPress: () async {
          final XFile f = await cameraController!.takePicture();
          tempInput = await makeCameraMedia(
              writeFromCachedPath: false,
              cachedPath: f.path,
              size: cameraController!.value.previewSize!.inverted,
              isReversed: isReversed,
              owner: willBeReplacedID,
              isSquared: true);
          changeConsole(cameraConfirmationRowName);
        },
        onLongPress: () async {
          await cameraController!.startVideoRecording();
          setTheState();
        },
        onLongPressUp: () async {
          final XFile f = await cameraController!.stopVideoRecording();
          tempInput = await makeCameraMedia(
              writeFromCachedPath: false,
              cachedPath: f.path,
              size: cameraController!.value.previewSize!.inverted,
              isReversed: isReversed,
              owner: willBeReplacedID,
              isSquared: true);
          changeConsole(cameraConfirmationRowName);
        },
      );

  @override
  Widget build(BuildContext context) {
    print(
        "image id: ${cameraInput?.id.value}\nimage path: ${cameraInput?.mainCachedPath}\n");
    return Andrew(pages: [
      Down4Page(
        title: "Initialization",
        console: console,
        staticList: true,
        stackWidgets: [full],
      )
    ]);
  }

  @override
  String get backFromCameraConsoleName => "base";

  @override
  late List<Extra> extras = [];

  @override
  List<String> currentConsolesName = ["base"];
}
