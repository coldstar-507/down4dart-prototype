import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:hive/hive.dart' as hive;
import 'package:camera/camera.dart';
import 'package:dartsv/dartsv.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'render_utility.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:video_player/video_player.dart';

class PinkTheme {
  static const buttonColor = Color.fromARGB(255, 250, 222, 224);
  static const bodyColor = buttonColor;
  static const inactivatedButtonColor = Color.fromARGB(255, 219, 214, 214);
  static const backGroundColor = Color.fromARGB(255, 255, 241, 242);
  static const headerColor = Color.fromARGB(255, 236, 155, 182);
  static const imageBorderColor = Color.fromARGB(255, 143, 29, 67);
  static const borderColor = Colors.black;
  static const qrColor = Color.fromARGB(255, 56, 3, 17);
  static const black = Colors.black;
  static const Map<NodeTypes, Color> nodeColors = {
    NodeTypes.rt: Color.fromARGB(255, 53, 3, 20),
    NodeTypes.cht: Color.fromARGB(255, 119, 8, 45),
    NodeTypes.cpt: Color.fromARGB(255, 22, 94, 161),
    NodeTypes.evt: Color.fromARGB(255, 95, 28, 219),
    NodeTypes.itm: Color.fromARGB(255, 187, 108, 34),
    NodeTypes.jnl: Color.fromARGB(255, 90, 62, 134),
    NodeTypes.mkt: Color.fromARGB(255, 34, 134, 64),
    NodeTypes.tkt: Color.fromARGB(255, 233, 220, 30),
    NodeTypes.usr: Color.fromARGB(255, 236, 61, 119),
  };
}

class Down4ColumnBackground extends StatelessWidget {
  List<Widget> children;
  Down4ColumnBackground({required this.children, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Column(
          // crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: children),
    );
  }
}

class Down4StackBackground extends StatelessWidget {
  List<Widget> children;
  Down4StackBackground({required this.children, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Stack(children: children),
    );
  }
}

class SingleActionPalette extends StatelessWidget {
  static const double height = 60.0;
  final Node node;
  final int activity;
  final String at;
  final void Function()? imPress,
      bodyPress,
      goPress,
      imLongPress,
      bodyLongPress,
      goLongPress;
  final bool selected;

  SingleActionPalette invertedSelection() {
    return SingleActionPalette(
        node: node,
        at: at,
        selected: !selected,
        imPress: imPress,
        imLongPress: imLongPress,
        bodyPress: bodyPress,
        bodyLongPress: bodyLongPress,
        goPress: goPress,
        goLongPress: goLongPress);
  }

  const SingleActionPalette({
    required this.node,
    this.activity = 1 << 63,
    this.at = "",
    this.imPress,
    this.bodyPress,
    this.goPress,
    this.imLongPress,
    this.bodyLongPress,
    this.goLongPress,
    this.selected = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SingleActionPalette.height,
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      decoration: BoxDecoration(
        boxShadow: !selected
            ? [
                const BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6.0,
                  spreadRadius: -6.0,
                  offset: Offset(8.0, 8.0),
                  blurStyle: BlurStyle.normal,
                )
              ]
            : null,
        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        border: Border.all(
          width: 2.0,
          color: selected ? PinkTheme.black : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: imPress,
            onLongPress: imLongPress,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  bottomLeft: Radius.circular(4.0),
                ),
              ),
              width: SingleActionPalette.height - 2.0, // borderWidth x2
              child: Image.memory(
                node.image.data,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: bodyPress,
              onLongPress: bodyLongPress,
              child: Material(
                child: Container(
                  decoration: BoxDecoration(
                    color: PinkTheme.headerColor,
                    border: Border(
                      left: BorderSide(
                        color:
                            selected ? PinkTheme.black : PinkTheme.headerColor,
                        width: 1.0,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 6.0, top: 5.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.name + " " + (node.lastName ?? ""),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal),
                      ),
                      node.type == NodeTypes.usr
                          ? Text(
                              "@" + node.id,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          goPress != null
              ? GestureDetector(
                  onTap: goPress,
                  onLongPress: goLongPress,
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: const BoxDecoration(
                      color: PinkTheme.headerColor,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4.0),
                        bottomRight: Radius.circular(4.0),
                      ),
                    ),
                    child: Image.asset('lib/src/assets/rightBlackArrow.png'),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: const BoxDecoration(
                    color: PinkTheme.headerColor,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(4.0),
                      bottomRight: Radius.circular(4.0),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class ConsoleButton extends StatelessWidget {
  static const double height = 26.0;
  final String name;
  final bool isSpecial, isMode, shouldBeDownButIsnt, isActivated;
  final void Function() onPress;
  final void Function()? onLongPress;
  final void Function()? onLongPressUp;

  const ConsoleButton({
    required this.name,
    required this.onPress,
    this.shouldBeDownButIsnt = false,
    this.isMode = false,
    this.isSpecial = false,
    this.isActivated = true,
    this.onLongPress,
    this.onLongPressUp,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: PinkTheme.black,
            border: Border.all(color: Colors.black, width: 0.5)),
        child: isActivated
            ? TouchableOpacity(
                shouldBeDownButIsnt: shouldBeDownButIsnt,
                onPress: onPress,
                onLongPress: onLongPress,
                onLongPressUp: onLongPressUp,
                child: Material(
                  child: Container(
                    color: PinkTheme.buttonColor,
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(
                          decoration:
                              isSpecial ? TextDecoration.underline : null,
                          decorationStyle: TextDecorationStyle.solid,
                          fontStyle:
                              isMode ? FontStyle.italic : FontStyle.normal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Material(
                child: Container(
                  color: PinkTheme.inactivatedButtonColor,
                  child: Center(
                    child: Text(
                      name,
                      style: TextStyle(
                        decoration: isSpecial ? TextDecoration.underline : null,
                        decorationStyle: TextDecorationStyle.solid,
                        fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class InputObjects extends StatefulWidget {
  final TextInputType type;
  final String placeHolder;
  final String value;
  final String prefix;
  final void Function(String) inputCallBack;
  final Key k = GlobalKey();
  InputObjects(
      {this.type = TextInputType.text,
      required this.inputCallBack,
      required this.placeHolder,
      this.prefix = "",
      this.value = "",
      Key? key})
      : super(key: key);

  @override
  _InputObjectState createState() => _InputObjectState();
}

class _InputObjectState extends State<InputObjects> {
  var tec = TextEditingController();

  @override
  void initState() {
    super.initState();
    tec = tec
      ..text = widget.value
      ..selection = TextSelection.collapsed(offset: widget.value.length);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: ConsoleButton.height,
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 0.5)),
        child: Material(
          child: TextField(
            controller: tec,
            key: widget.k,
            keyboardType: widget.type,
            textAlignVertical: TextAlignVertical.center,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(10.0),
                hintText: widget.placeHolder,
                border: InputBorder.none),
            textDirection: TextDirection.ltr,
            onChanged: (value) {
              if (value.isNotEmpty) {
                String output;
                if (value.substring(0, widget.prefix.length) != widget.prefix) {
                  output = widget.prefix + value;
                } else {
                  output = value;
                }
                setState(() {
                  tec.text = output;
                  tec.selection =
                      TextSelection.collapsed(offset: output.length);
                });
                widget.inputCallBack(output.substring(widget.prefix.length));
              } else {
                widget.inputCallBack(value);
              }
            },
          ),
        ),
      ),
    );
  }
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? topButtons, extraButtons;
  final List<ConsoleButton> bottomButtons;
  final CameraPreview? cameraPreview;
  final double? aspectRatio;
  final bool? toMirror;
  final String? imagePreviewPath;
  final VideoPlayerController? videoPlayerController;
  final List<InputObjects>? inputs, topInputs;
  const Console(
      {required this.bottomButtons,
      this.imagePreviewPath,
      this.videoPlayerController,
      this.toMirror,
      this.aspectRatio,
      this.cameraPreview,
      this.inputs,
      this.topInputs,
      this.topButtons,
      this.extraButtons,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // both margin (16+16=32) + 1 = 0.5x1 for the Main container border
    final double mirror = toMirror == true ? math.pi : 0;
    var camWidthAndHeight = MediaQuery.of(context).size.width - 33.0;
    return Container(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      decoration:
          BoxDecoration(border: Border.all(width: 0.5, color: Colors.black)),
      child: Column(children: [
        Row(textDirection: TextDirection.ltr, children: topInputs ?? []),
        Row(textDirection: TextDirection.ltr, children: inputs ?? []),
        cameraPreview != null
            ? Container(
                width: camWidthAndHeight,
                height: camWidthAndHeight,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: .5)),
                child: Transform.scale(
                    alignment: Alignment.center,
                    scaleY: aspectRatio,
                    child: AspectRatio(
                        aspectRatio: aspectRatio!, child: cameraPreview!)))
            : imagePreviewPath != null
                ? Container(
                    width: camWidthAndHeight,
                    height: camWidthAndHeight,
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 0.5)),
                    child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(mirror),
                        child: Image.file(
                          io.File(imagePreviewPath!),
                          fit: BoxFit.cover,
                        )))
                : videoPlayerController != null
                    ? Container(
                        clipBehavior: Clip.hardEdge,
                        width: camWidthAndHeight,
                        height: camWidthAndHeight,
                        decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.black, width: 0.5)),
                        child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(mirror),
                            child: Transform.scale(
                                scaleY: aspectRatio,
                                child: VideoPlayer(videoPlayerController!))))
                    : const SizedBox.shrink(),
        Row(
          children: topButtons ?? [],
          textDirection: TextDirection.ltr,
        ),
        Row(
          children: bottomButtons,
          textDirection: TextDirection.ltr,
        )
      ]),
    );
  }
}

// class Media extends StatefulWidget {
//   final Down4Media _media;
//   const Media(Down4Media media, [Key? key])
//       : _media = media,
//         super(key: key);

//   @override
//   _Media createState() => _Media();
// }

// class _Media extends State<Media> {
//   VideoPlayerController? _vc;
//   dynamic theMedia;

//   @override
//   void initState() {
//     super.initState();
//     final m = widget._media;
//     if (m.hasThumbnail) {
//       theMedia = Image.memory(
//         base64Decode(m.thumbnail),
//         gaplessPlayback: true,
//         fit: BoxFit.cover,
//       );
//     }
//     _fetchMedia();
//   }

//   Future<void> _fetchMedia() async {
//     var m = widget._media;

//     if (m.usePlaceHolder) {
//       theMedia = Image.asset(
//         'lib/src/assets/hashirama.jpg',
//         gaplessPlayback: true,
//         fit: BoxFit.cover,
//       );
//     } else if (m.isImage && m.hasData) {
//       theMedia = Image.memory(
//         base64Decode(m.data),
//         gaplessPlayback: true,
//         fit: BoxFit.cover,
//       );
//     } else if (m.isOnlyOnDatabase && m.isImage) {
//       await m.downloadData();
//       theMedia = m.hasData
//           ? Image.memory(
//               base64Decode(m.data),
//               gaplessPlayback: true,
//               fit: BoxFit.cover,
//             )
//           : null;
//     } else if (m.isOnlyOnDatabase && m.isVideo) {
//       String dataSource;
//       if (!m.hasURL) {
//         dataSource = await m.downloadURL();
//       } else {
//         dataSource = m.url;
//       }
//       _vc = VideoPlayerController.network(dataSource);
//       await _vc?.initialize();
//       if (_vc != null) {
//         theMedia = GestureDetector(
//           onTap: () {
//             if (_vc!.value.isPlaying) {
//               _vc!.pause();
//             } else {
//               _vc!.play();
//             }
//           },
//           child: VideoPlayer(_vc!),
//         );
//       }
//       theMedia = null;
//     }
//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     return theMedia ?? const SizedBox.shrink();
//   }
// }

class ChatMessage extends StatefulWidget {
  static const double headerHeight = 24.0;
  final Down4Message message;
  final bool myMessage;
  final void Function(Identifier)? select;
  final List<Identifier>? reactionIDs;
  const ChatMessage({
    required this.message,
    required this.myMessage,
    this.select,
    this.reactionIDs,
    Key? key,
  }) : super(key: key);

  @override
  _ChatMessageState createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  VideoPlayerController? _videoController;
  dynamic media;
  bool selected = false;

  void _select() {
    setState(() => selected = true);
  }

  @override
  void initState() async {
    super.initState();
    if (widget.message.media != null) {
      if (widget.message.isVideo) {
        final blob = html.Blob([widget.message.media!.data]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        _videoController = VideoPlayerController.network(url);
        await _videoController!.initialize();
        media = GestureDetector(
          onTap: () {
            if (_videoController!.value.isPlaying) {
              _videoController!.pause();
            } else {
              _videoController!.play();
            }
          },
          child: VideoPlayer(_videoController!),
        );
      } else {
        media = GestureDetector(
          onTap: _select,
          child: Image.memory(
            widget.message.media!.data,
            fit: BoxFit.cover,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.message.isChat == false
          ? Alignment.topCenter
          : widget.myMessage
              ? Alignment.topRight
              : Alignment.topLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.66),
        decoration: BoxDecoration(
            border: Border.all(
                width: 2.0,
                color: selected ? Colors.black : Colors.transparent)),
        child: IntrinsicWidth(
          child: Column(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.ltr,
                children: [
                  GestureDetector(
                    onTap: _select,
                    child: SizedBox(
                      height: ChatMessage.headerHeight,
                      child: Image.memory(widget.message.thumbnail),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _select,
                      child: Container(
                        padding: const EdgeInsets.only(
                            left: 2.0, top: 2.0, right: 2.0),
                        color: PinkTheme.headerColor,
                        height: ChatMessage.headerHeight,
                        child: Text(
                          widget.message.name,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              widget.message.text == null
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: _select,
                      child: Container(
                        padding: const EdgeInsets.all(2.0),
                        color: PinkTheme.bodyColor,
                        child: Text(
                          widget.message.text!,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
              media ?? const SizedBox.shrink()
            ],
          ),
        ),
      ),
    );
  }
}

class PaletteList extends StatelessWidget {
  final List<SingleActionPalette> palettes;
  const PaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                padding: const EdgeInsets.only(top: 0),
                reverse: true,
                itemBuilder: (c, i) => i == 0
                    ? const SizedBox.shrink()
                    : i == palettes.length + 2 - 1
                        ? const SizedBox.shrink()
                        : palettes[i - 1],
                separatorBuilder: (c, i) => Container(height: 16.0),
                itemCount: palettes.length + 2)));
  }
}

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  const MessageList({required this.messages, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                padding: const EdgeInsets.only(top: 0),
                itemBuilder: (c, i) => i == 0
                    ? const SizedBox.shrink()
                    : i == messages.length + 2 - 1
                        ? const SizedBox.shrink()
                        : messages[i],
                separatorBuilder: (c, i) => Container(height: 16.0),
                itemCount: messages.length + 2)));
  }
}

class UserPaletteMaker extends StatelessWidget {
  final void Function(Map<String, String>) infoCallBack;
  final Map<String, dynamic> info;
  const UserPaletteMaker(
      {required this.infoCallBack, required this.info, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tec = TextEditingController()
      ..text = info['id'].toLowerCase()
      ..selection = TextSelection.collapsed(offset: info['id'].length);
    return Container(
      height: SingleActionPalette.height,
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      decoration: BoxDecoration(
          boxShadow: const [
            BoxShadow(
                color: Colors.black54,
                blurRadius: 6.0,
                spreadRadius: -6.0,
                offset: Offset(8.0, 8.0),
                blurStyle: BlurStyle.normal)
          ],
          borderRadius: const BorderRadius.all(Radius.circular(6.0)),
          border: Border.all(width: 2.0, color: Colors.transparent)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: () async {
              FilePickerResult? r = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'png', 'jpeg'],
                  withData: true);
              if (r?.files.single.bytes != null) {
                infoCallBack(
                  {...info, 'image': base64Encode(r!.files.single.bytes!)},
                );
              }
            },
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.0),
                bottomLeft: Radius.circular(4.0),
              )),
              width: SingleActionPalette.height - 2.0, // borderWidth x2
              child: info['image'] == null || info['image'] == ""
                  ? Image.asset(
                      'lib/src/assets/picture_place_holder_2.png',
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Image.memory(
                      base64Decode(info['image']!),
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                color: PinkTheme.headerColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4.0),
                  bottomRight: Radius.circular(4.0),
                ),
              ),
              padding: const EdgeInsets.only(left: 10.0, top: 10.0),
              child: TextField(
                controller: tec,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: info['id'] == "" ? "" : "@",
                  hintText: "@username",
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(
                      bottom: SingleActionPalette.height / 2),
                ),
                textDirection: TextDirection.ltr,
                onChanged: ((value) {
                  infoCallBack({...info, 'id': value.toLowerCase()});
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserMakerPalette extends StatelessWidget {
  static const double height = 60.0;
  final String name, lastName, id;
  final Uint8List image;
  final void Function() selectFile;

  const UserMakerPalette({
    required this.name,
    required this.lastName,
    required this.id,
    required this.selectFile,
    required this.image,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SingleActionPalette.height,
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6.0,
            spreadRadius: -6.0,
            offset: Offset(8.0, 8.0),
            blurStyle: BlurStyle.normal,
          ),
        ],
        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        border: Border.all(width: 2.0, color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: selectFile,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  bottomLeft: Radius.circular(4.0),
                ),
              ),
              width: SingleActionPalette.height - 2.0, // borderWidth x2
              child: image.isNotEmpty
                  ? Image.memory(
                      image,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Image.asset(
                      'lib/src/assets/picture_place_holder_2.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: PinkTheme.headerColor,
                border: Border(
                  left: BorderSide(color: PinkTheme.headerColor, width: 1.0),
                ),
              ),
              padding: const EdgeInsets.only(left: 6.0, top: 5.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (name == '' ? "Name" : name) +
                        " " +
                        (lastName == '' ? "" : lastName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  Text(
                    "@" + (id == '' ? "username" : id),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.normal),
                  )
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2.0),
            decoration: const BoxDecoration(
              color: PinkTheme.headerColor,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(4.0),
                bottomRight: Radius.circular(4.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaletteMaker extends StatelessWidget {
  final void Function(String infoKey, Map<String, dynamic>) infoCallBack;
  final Map<String, dynamic> info;
  final void Function(Identifier)? go;
  final Identifier parentID, infoKey;
  final NodeTypes type;
  final NodeTypes? parentType;
  const PaletteMaker(
      {required this.infoCallBack,
      required this.infoKey,
      required this.info,
      this.go,
      this.type = NodeTypes.usr,
      this.parentType,
      this.parentID = "",
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        height: SingleActionPalette.height,
        margin: const EdgeInsets.only(left: 22.0, right: 22.0),
        decoration: BoxDecoration(
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6.0,
                  spreadRadius: -6.0,
                  offset: Offset(8.0, 8.0),
                  blurStyle: BlurStyle.normal)
            ],
            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
            border: Border.all(width: 2.0, color: Colors.transparent)),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: TextDirection.ltr,
            children: [
              GestureDetector(
                onTap: () async {
                  FilePickerResult? r = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'png', 'jpeg'],
                      withData: true);
                  if (r?.files.single.bytes != null) {
                    infoCallBack(
                      infoKey,
                      {...info, 'image': base64Encode(r!.files.single.bytes!)},
                    );
                  }
                },
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.0),
                    bottomLeft: Radius.circular(4.0),
                  )),
                  width: SingleActionPalette.height - 2.0, // borderWidth x2
                  child: info['image'] == null || info['image'] == ""
                      ? Image.asset(
                          'lib/src/assets/picture_place_holder_2.png',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Image.memory(
                          base64Decode(info['image']!),
                          gaplessPlayback: true,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Expanded(
                  child: Material(
                      child: Container(
                          padding: const EdgeInsets.only(left: 10.0, top: 10.0),
                          color: PinkTheme.headerColor,
                          child: TextField(
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                  hintText: "Pick a name and an image!",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(
                                      bottom:
                                          (SingleActionPalette.height) / 2)),
                              textDirection: TextDirection.ltr,
                              onChanged: ((value) => infoCallBack(
                                  infoKey, {...info, 'name': value})))))),
              GestureDetector(
                  onTap: () {
                    if (info['name'] != null) {
                      go?.call(
                          sha1(parentID.codeUnits + info['name']!.codeUnits)
                              .toString());
                    }
                  },
                  child: Container(
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.all(2.0),
                      width: type != NodeTypes.usr
                          ? SingleActionPalette.height - 2.0
                          : 4.0,
                      decoration: const BoxDecoration(
                          color: PinkTheme.headerColor,
                          borderRadius: BorderRadius.only(
                              topRight: Radius.circular(4.0),
                              bottomRight: Radius.circular(4.0))),
                      child: type != NodeTypes.usr
                          ? Image.asset('lib/src/assets/rightBlackArrow.png')
                          : const SizedBox.shrink()))
            ]));
  }
}

class PaletteMakerList extends StatelessWidget {
  final List<PaletteMaker> palettes;
  const PaletteMakerList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                reverse: true,
                itemBuilder: (c, i) => i == 0
                    ? const SizedBox.shrink()
                    : i == palettes.length + 2 - 1
                        ? const SizedBox.shrink()
                        : palettes[i - 1],
                separatorBuilder: (c, i) => Container(height: 16.0),
                itemCount: palettes.length + 2)));
  }
}
