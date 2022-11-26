import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

import '../boxes.dart';
import '../down4_utility.dart' as u;
import '../web_requests.dart' as r;

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/lists.dart';
import '../render_objects/navigator.dart';

class ChatPage extends StatefulWidget {
  final Map<Identifier, Palette> senders;
  final User self;
  final ChatableNode node;
  // final List<Palette> group;
  final List<CameraDescription> cameras;
  final void Function(r.ChatRequest) send;
  final void Function() back;
  final Palette? Function(BaseNode, {String at}) nodeToPalette;
  final int pageIndex;
  final Function(int)? onPageChange;

  const ChatPage({
    required this.senders,
    required this.node,
    required this.send,
    required this.self,
    required this.back,
    required this.cameras,
    required this.nodeToPalette,
    // required this.group,
    this.pageIndex = 0,
    this.onPageChange,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Console? _console;
  ConsoleInput? _consoleInput;
  var tec = TextEditingController();
  Down4Media? _cameraInput, _mediaInput;
  Map<Identifier, Down4Media> _cachedMedias = {};
  Map<Identifier, ChatMessage> _cachedMessages = {};

  Map<Identifier, Down4Media> cachedImages = {};
  Map<Identifier, Down4Media> cachedVideos = {};

  @override
  void initState() {
    super.initState();
    asyncImageLoad();
    loadMessages();
    baseConsole();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
    loadMessages(isUpdate: true);
    print("Did update the chat page widget!");
  }

  Future<void> asyncImageLoad() async {
    Future(() {
      final keys = b.images.keys;
      final nImages = keys.length;
      final nImagesToLoad = nImages <= 25 ? nImages : 25;
      for (int i = 0; i < nImagesToLoad; i++) {
        final mediaID = keys.elementAt(i);
        cachedImages[mediaID] = b.loadSavedImage(mediaID);
        print("load media id=$mediaID");
      }
    }).then((value) {
      Future(() {
        print("loaded all images");
        for (final image in cachedImages.values) {
          print("precached image id=${image.id}");
          precacheImage(MemoryImage(image.data), context);
        }
      }).then((value) => print("precached all images"));
    });
  }

  Iterable<Down4Media> get savedImages => b.images.keys
      .map((mediaID) => cachedImages[mediaID] ??= b.loadSavedImage(mediaID));

  Iterable<Down4Media> get savedVideos => b.videos.keys
      .map((mediaID) => cachedVideos[mediaID] ??= b.loadSavedVideo(mediaID));

  ConsoleInput get consoleInput => _consoleInput = ConsoleInput(
        tec: tec,
        inputCallBack: (t) => null,
        placeHolder: ":)",
      );

  Future<void> loadMessages({bool isUpdate = false}) async {
    final loadedMessagesKeys = _cachedMessages.keys.toSet();
    final allMessagesKeys = widget.node.messages.toSet();
    final messageToLoad = allMessagesKeys.difference(loadedMessagesKeys);
    print("Messages to load $messageToLoad");

    final maxWidth = Sizes.w * 0.76;
    const textPadding = 12;
    const messageBorder = 4;
    for (var msgID in messageToLoad.toList(growable: false).reversed) {
      double oneTextLineHeight = 0;
      double mediaHeight = 0;
      double mediaWidth = 0;

      var down4Message = b.loadMessage(msgID);
      if (down4Message == null) return;
      Down4Media? media;
      if (down4Message.mediaID != null) {
        media = await getMessageMediaFromEverywhere(down4Message.mediaID!);
        if (media != null) {
          mediaWidth = maxWidth - messageBorder;
          mediaHeight = mediaWidth * (media.metadata.aspectRatio ?? 1.0);
        }
      }

      String? prevMsgSender = _cachedMessages.isEmpty
          ? null
          : _cachedMessages.values.last.message.senderID;

      List<dynamic>? textAsStringList() {
        List<String>? specialDisplayText;
        double? neededWidth;

        if (down4Message.text?.isEmpty ?? true) return null;

        specialDisplayText = [];
        neededWidth = 0.0;

        final text = down4Message.text!;
        final transform1 = text.split("\n");
        final transform2 = transform1.join(" \n ");

        // var words = down4Message.text!.split(" ");
        final words = transform2.split(" ");
        var previousString = "";

        // pervious string should always be < max
        for (final word in words) {
          if (word == "\n") {
            specialDisplayText.add(previousString);
            final specialTp = TextPainter(
              text: TextSpan(text: previousString),
              textDirection: TextDirection.ltr,
            )..layout();
            if (specialTp.width + 5 > neededWidth!) {
              neededWidth = specialTp.width + 5;
            }
            previousString = "";
          } else if (word.isNotEmpty) {
            final currentString =
                previousString.isEmpty ? word : "$previousString $word";

            final previousTp = TextPainter(
              text: TextSpan(text: previousString),
              textDirection: TextDirection.ltr,
            )..layout();

            final currentTp = TextPainter(
              text: TextSpan(text: currentString),
              textDirection: TextDirection.ltr,
            )..layout();

            oneTextLineHeight = currentTp.height;

            // if the current text is larger than the available width
            if (currentTp.width + 5 >= maxWidth - 16) {
              // we add the previousString to the list of display text
              specialDisplayText.add(previousString);
              // if the previous layout is bigger than our current biggest width,
              // it because the new biggest width
              if (previousTp.width + 5 > neededWidth!) {
                neededWidth = previousTp.width + 5;
              }
              // now we set the previous string as the word
              previousString = word;
            } else {
              // if the current text is not larger than available width
              // we simply update it
              previousString = currentString;
            }
          }
        }

        // don't leave out the last string
        if (previousString.isNotEmpty && previousString != "\n") {
          final lastLiner = TextPainter(
            text: TextSpan(text: previousString),
            textDirection: TextDirection.ltr,
          )..layout();
          if (lastLiner.width + 5 > neededWidth!) {
            neededWidth = lastLiner.width + 5;
          }
          print("last String = $previousString");
          specialDisplayText.add(previousString);
        }

        return [specialDisplayText, neededWidth];
      }

      final bool hasHeader =
          isUpdate ? true : prevMsgSender != down4Message.senderID;
      final textData = textAsStringList();
      final lineStrings = textData?[0] as List<String>?;
      final textWidth = textData?[1] as double?;
      final headerSize = hasHeader ? 18 : 0;
      final messageHeight = lineStrings != null
          ? (lineStrings.length * oneTextLineHeight + textPadding) +
              mediaHeight +
              messageBorder +
              headerSize
          : mediaHeight + messageBorder + headerSize;
      final messageWidth = media != null
          ? maxWidth
          : lineStrings != null
              ? textWidth! + textPadding + messageBorder
              : 0.0; // TODO, will be forwarding nodes, or messages

      print("Textwidth=$textWidth");
      print("Number of lines=${lineStrings?.length}");
      final precalculatedSize = Size(messageWidth, messageHeight);
      print("PrecalculatedSize=$precalculatedSize");
      print("MaxWidth=$maxWidth");

      var chatMessage = ChatMessage(
        key: GlobalKey(),
        sender: widget.senders[down4Message.senderID]!,
        message: down4Message,
        myMessage: widget.self.id == down4Message.senderID,
        at: "",
        precalculatedSize: Size(messageWidth, messageHeight),
        precalculatedMediaSize:
            media != null ? Size(mediaWidth, mediaHeight) : null,
        specialDisplayTexts: lineStrings,
        // if is update, means it's a single new message with a header
        hasHeader: hasHeader,
        media: media,
        select: (id, _) => setState(() {
          _cachedMessages[id] = _cachedMessages[id]!.invertedSelection();
        }),
      );

      if (isUpdate) {
        if (_cachedMessages.isNotEmpty) {
          // last message receive is the first in the list
          final lastMessage = _cachedMessages.values.first;
          if (lastMessage.message.senderID == down4Message.senderID) {
            // we need to remove its header
            // and update it's size
            final lastMessageSize = lastMessage.precalculatedSize;
            final newSize = Size(
                lastMessageSize.width, lastMessageSize.height - headerSize);
            _cachedMessages[lastMessage.message.id] =
                lastMessage.withHeader(withHeader: false, newSize: newSize);
          }
        }
        _cachedMessages = {down4Message.id: chatMessage, ..._cachedMessages};
        setState(() {});
      } else {
        _cachedMessages[down4Message.id] = chatMessage;
        setState(() {});
      }
    }
  }

  Future<void> handleImport() async {
    FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg'],
      withData: true,
      allowMultiple: true,
    );
    final ts = u.timeStamp();
    for (final pf in r?.files ?? <PlatformFile>[]) {
      if (pf.bytes != null) {
        final compressedData = await FlutterImageCompress.compressWithList(
          pf.bytes!,
          minHeight: 520,
          minWidth: 0,
        );
        final mediaID = u.generateMediaID(compressedData);
        _cachedMedias[mediaID] = Down4Media(
          id: mediaID,
          data: compressedData,
          metadata: MediaMetadata(owner: widget.self.id, timestamp: ts),
        );
        Boxes.instance.saveImage(_cachedMedias[mediaID]!);
      }
    }
    mediasConsole();
  }

  void saveSelectedMessages() async {
    for (final msg in _cachedMessages.values) {
      if (msg.selected) {
        _cachedMessages[msg.message.id] = msg.invertedSelection();
        final media = msg.media;
        if (media != null) {
          final save = media.metadata.isVideo ? b.saveVideo : b.saveImage;
          save(media);
        }
      }
    }
    setState(() {});
  }

  void send2() {
    if (tec.value.text != "" || _mediaInput != null || _cameraInput != null) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final targets = widget.node.targets(widget.self.id);

      var msg = Down4Message(
        type: Messages.chat,
        id: u.generateMessageID(widget.self.id, ts),
        timestamp: ts,
        senderID: widget.self.id,
        mediaID: _mediaInput?.id ?? _cameraInput?.id,
        text: tec.value.text,
      );

      var req = r.ChatRequest(
        message: msg,
        targets: targets,
        media: _mediaInput ?? _cameraInput,
      );

      widget.send(req);
      tec.clear();
    }
  }

  // void getTheMedia(Identifier mediaID, Identifier msgID) async {
  //   var media = await getMessageMediaFromEverywhere(mediaID);
  //   if (media == null) return;
  //   _cachedMessages[msgID] = _cachedMessages[msgID]!.withMedia(media);
  //   setState(() {});
  // }

  // MessageList4 get messageList => MessageList4(
  //       senders: widget.senders,
  //       messages: widget.node.messages.reversed.toList(),
  //       self: widget.self,
  //       messageMap: _cachedMessages,
  //       cache: (msg) => _cachedMessages[msg.message.id] = msg,
  //       getTheMedia: getTheMedia,
  //       select: (id, _) {
  //         _cachedMessages[id] = _cachedMessages[id]!.invertedSelection();
  //         setState(() {});
  //       },
  //     );

  Future<void> camConsole([
    CameraController? ctrl,
    int cameraIdx = 0,
    ResolutionPreset resolution = ResolutionPreset.medium,
    FlashMode flashMode = FlashMode.off,
    bool reloadCtrl = false,
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

    void nextCam() =>
        camConsole(ctrl, (cameraIdx + 1) % 2, resolution, FlashMode.off, true);

    // void nextCam() => cameraIdx == 0
    //     ? camConsole(ctrl, 1, resolution, FlashMode.off, true)
    //     : camConsole(ctrl, 0, resolution, FlashMode.off, true);

    void nextRes() async {
      switch (resolution) {
        case ResolutionPreset.low:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.medium, flashMode, true);
        case ResolutionPreset.medium:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.high, flashMode, true);
        case ResolutionPreset.high:
          return camConsole(
              ctrl, cameraIdx, ResolutionPreset.low, flashMode, true);
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

    if (_cameraInput == null) {
      _console = Console(
        inputs: [_consoleInput ?? consoleInput],
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
                _cameraInput = Down4Media.fromCamera(
                  f.path,
                  MediaMetadata(
                    owner: widget.self.id,
                    timestamp: u.timeStamp(),
                    isVideo: false,
                    toReverse: cameraIdx == 1,
                  ),
                );
                camConsole(ctrl, cameraIdx, resolution, FlashMode.off, false);
              }
            },
            onLongPress: () async => await ctrl?.startVideoRecording(),
            onLongPressUp: () async {
              XFile? f = await ctrl?.stopVideoRecording();
              if (f != null) {
                _cameraInput = Down4Media.fromCamera(
                  f.path,
                  MediaMetadata(
                    owner: widget.self.id,
                    timestamp: u.timeStamp(),
                    isVideo: true,
                    toReverse: cameraIdx == 1,
                  ),
                );
                camConsole(ctrl, cameraIdx, resolution, FlashMode.off, false);
              }
            },
            shouldBeDownButIsnt: ctrl?.value.isRecordingVideo ?? false,
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
      String? imPrev;
      VideoPlayerController? videoCtrl;
      if (_cameraInput!.metadata.isVideo) {
        videoCtrl = VideoPlayerController.file(_cameraInput!.file!);
        await videoCtrl.initialize();
        await videoCtrl.setLooping(true);
        await videoCtrl.play();
      } else {
        imPrev = _cameraInput!.path;
      }
      _console = Console(
        inputs: [_consoleInput ?? consoleInput],
        imagePreviewPath: imPrev,
        videoPlayerController: videoCtrl,
        topButtons: [
          ConsoleButton(
            name: "Accept",
            onPress: () {
              videoCtrl?.dispose();
              ctrl?.dispose();
              baseConsole();
            },
          ),
        ],
        bottomButtons: [
          ConsoleButton(
            name: "Back",
            onPress: () {
              videoCtrl?.dispose();
              _cameraInput = null;
              camConsole(ctrl, cameraIdx, resolution, flashMode, false);
            },
          ),
          ConsoleButton(
              name: "Cancel",
              onPress: () {
                videoCtrl?.dispose();
                ctrl?.dispose();
                baseConsole();
              }),
        ],
      );
    }
    setState(() {});
  }

  void baseConsole() {
    _console = Console(
      inputs: [_consoleInput ?? consoleInput],
      topButtons: [
        ConsoleButton(name: "Save", onPress: saveSelectedMessages),
        ConsoleButton(
          name: "Send",
          onPress: () {
            send2();
            baseConsole();
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _cameraInput == null ? "Camera" : "@Camera",
          onPress: camConsole,
        ),
        ConsoleButton(
          name: "Medias",
          onPress: mediasConsole,
        ),
      ],
    );
    setState(() {});
  }

  void mediasConsole([bool images = true]) {
    _console = Console(
      images: true,
      inputs: [_consoleInput ?? consoleInput],
      medias: images ? savedImages.toList() : savedVideos.toList(),
      selectMedia: (media) {
        _mediaInput = media;
        send2();
      },
      topButtons: [
        ConsoleButton(name: "Import", onPress: handleImport),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: baseConsole),
        ConsoleButton(
          isMode: true,
          name: images ? "Images" : "Videos",
          onPress: () => mediasConsole(!images),
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Down4Page> pages = widget.node is GroupNode
        ? [
            Down4Page(
              isChatPage: true,
              title: widget.node.name,
              console: _console!,
              messages: _cachedMessages.values.toList(),
            ),
            Down4Page(
              title: "People",
              console: _console!,
              palettes: widget.senders.values.toList(),
            ),
          ]
        : [
            Down4Page(
              isChatPage: true,
              title: widget.node.name,
              console: _console!,
              messages: _cachedMessages.values.toList(),
            ),
          ];

    return Andrew(
      initialPageIndex: widget.pageIndex,
      pages: pages,
      onPageChange: widget.onPageChange,
    );
  }
}
