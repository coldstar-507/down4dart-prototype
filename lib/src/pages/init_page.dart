import 'dart:async';

import 'package:camera/camera.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:mime/mime.dart';

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
  ComposedID get willBeReplacedID => ComposedID(unik: id, region: region);

  @override
  void setTheState() => setState(() {});

  final List<Future<bool>> _calls = [];

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
      cameraInput = Down4Media.fromLocal(
          ComposedID(region: willBeReplacedID.region),
          mainCachedPath: p,
          metadata: Down4MediaMetadata(
              ownerID: willBeReplacedID,
              timestamp: makeTimestamp(),
              isReversed: isReversed,
              width: s.width,
              height: s.height,
              mime: lookupMimeType(p)!));
      setTheState();
    }
  }

  Size get imageSize => Size.square(imagePickerHeight);

  double get availHeight => g.sizes.bodySize.height;

  double get imagePickerHeight => availHeight * 0.12;

  double get spacerHeight => availHeight * 0.013;

  Widget get userImage =>
      cameraInput?.display(
          key: GlobalKey(), size: imageSize, forceSquare: true) ??
      g.ph;

  Widget get imagePicker => GestureDetector(
        onTap: selectFile,
        child: Container(
          width: imagePickerHeight,
          height: imagePickerHeight,
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
          id: ComposedID(unik: id, region: region),
          deviceID: widget.deviceID,
          name: firstName,
          lastName: lastName,
          latitude: widget.latitude,
          longitude: widget.longitude,
          media: cameraInput!));

  @override
  Console get console => Console(
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

  double get sidePadding => g.sizes.w * 0.04;
  
  double get bodyHeight =>
      (spacerHeight * 4) + (Console.buttonHeight * 4) + imagePickerHeight;

  Widget get fullWidg {
    return Flexible(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sidePadding),
        child: Column(
          children: [
            const Spacer(),
            SizedBox(height: g.sizes.headerHeight),
            imagePicker,
            SizedBox(height: spacerHeight),
            idInput.initInput,
            SizedBox(height: spacerHeight),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: firstNameInput.initInput),
                SizedBox(width: spacerHeight),
                Expanded(child: lastNameInput.initInput),
              ],
            ),
            SizedBox(height: spacerHeight),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                regionButton(Region.america),
                SizedBox(width: spacerHeight),
                regionButton(Region.europe),
                SizedBox(width: spacerHeight),
                regionButton(Region.asia),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }


  Widget regionButton(Region reg) => Expanded(
      child: GestureDetector(
          onTap: () => setState(() => region = reg),
          child: SizedBox(
              height: InitInput2.initInputHeight,
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
          final s = await decodeImageSize(await f.readAsBytes());
          tempInput = Down4Media.fromLocal(ComposedID(region: region),
              mainCachedPath: f.path,
              metadata: Down4MediaMetadata(
                  ownerID: willBeReplacedID,
                  timestamp: makeTimestamp(),
                  width: s.width,
                  isReversed: isReversed,
                  height: s.height,
                  mime: lookupMimeType(f.path)!));
          changeConsole(cameraConfirmationRowName);
        },
        onLongPress: () async {
          await cameraController!.startVideoRecording();
          setTheState();
        },
        onLongPressUp: () async {
          final XFile f = await cameraController!.stopVideoRecording();
          final vinfo = await FlutterVideoInfo().getVideoInfo(f.path);
          tempInput = Down4Media.fromLocal(ComposedID(),
              metadata: Down4MediaMetadata(
                  ownerID: g.self.id,
                  timestamp: makeTimestamp(),
                  isReversed: isReversed,
                  width: vinfo!.width!.toDouble(),
                  height: vinfo.height!.toDouble(),
                  mime: lookupMimeType(f.path)!));
          changeConsole(cameraConfirmationRowName);
        },
      );

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
        title: "Initialization",
        console: console,
        staticList: true,
        simplePageWidget: fullWidg,
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
