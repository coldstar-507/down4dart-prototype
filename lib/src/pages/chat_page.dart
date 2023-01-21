import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:down4/src/render_objects/render_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:video_player/video_player.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../boxes.dart';
import '../down4_utility.dart' as u;
import '../web_requests.dart' as r;
import '../down4_utility.dart' show golden;

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/lists.dart';
import '../render_objects/navigator.dart';

class ChatPage extends StatefulWidget {
  final Map<Identifier, Palette> senders;
  final Self self;
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
  CameraController? ctrl;
  MessageMedia? _cameraInput;
  Map<Identifier, ChatMessage> _cachedMessages = {};
  Map<Identifier, Message?> _cachedDown4Message = {};
  String? idOfLastMessageRead;

  Map<Identifier, MessageMedia> _cachedImages = {};
  Map<Identifier, MessageMedia> _cachedVideos = {};

  late var theNode = widget.node;
  late final bool isGroupChat = theNode is GroupNode;

  @override
  void initState() {
    super.initState();
    asyncImageLoad();
    loadMessages();
    loadBaseConsole();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
    loadMessages(isUpdate: true);
    print("Did update the chat page widget!");
  }

  Future<void> asyncImageLoad() async {
    Future(() {
      final keys = widget.self.images;
      final nImages = keys.length;
      final nImagesToLoad = nImages <= 25 ? nImages : 25;
      for (int i = 0; i < nImagesToLoad; i++) {
        final mediaID = keys.elementAt(i);
        var media = mediaID.getLocalMessageMedia();
        if (media != null) _cachedImages[mediaID] = media;
        print("load media id=$mediaID");
      }
    }).then((value) {
      Future(() {
        print("loaded all images");
        for (final image in _cachedImages.values) {
          print("precached image id=${image.id}");
          if (image.file != null) {
            precacheImage(FileImage(image.file!), context);
          }
        }
      }).then((value) => print("precached all images"));
    });
  }

  Iterable<MessageMedia> get savedImages => widget.self.images.map(
      (mediaID) => _cachedImages[mediaID] ??= mediaID.getLocalMessageMedia()!);

  Iterable<MessageMedia> get savedVideos => widget.self.videos.map(
      (mediaID) => _cachedVideos[mediaID] ??= mediaID.getLocalMessageMedia()!);

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
    final maxTextWidth = maxWidth - textPadding - messageBorder;

    // Useful functions to calculate things we might render in chat messages
    bool calculateIfShouldShowTimestamp(Message m1, Message m2) =>
        m1.senderID != m2.senderID ||
        isUpdate ||
        DateTime.fromMillisecondsSinceEpoch(m1.timestamp)
                .difference(DateTime.fromMillisecondsSinceEpoch(m2.timestamp))
                .inMinutes >
            30;
    String timeString(Message msg) {
      final ts = DateTime.fromMillisecondsSinceEpoch(msg.timestamp).toLocal();
      final now = DateTime.now().toLocal();
      String timeStr;
      final yearStr = ts.year.toString();
      final yearDigits =
          int.parse(yearStr.substring(yearStr.length - 2, yearStr.length));
      String tsDay, tsMonth, tsYear, tsHour, tsMin;
      tsDay = ts.day < 10 ? "0${ts.day}" : "${ts.day}";
      tsMonth = ts.month < 10 ? "0${ts.month}" : "${ts.month}";
      tsYear = yearDigits < 10 ? "0$yearDigits" : "$yearDigits";
      tsHour = ts.hour < 10 ? "0${ts.hour}" : "${ts.hour}";
      tsMin = ts.minute < 10 ? "0${ts.minute}" : "${ts.minute}";

      if (ts.add(const Duration(days: 1)).isBefore(now)) {
        var yearStr = ts.year.toString();
        yearStr = yearStr.substring(yearStr.length - 2, yearStr.length);
        timeStr = "$tsDay/$tsMonth/$tsYear $tsHour:$tsMin";
      } else {
        timeStr = "$tsHour:$tsMin";
      }
      return timeStr;
    }

    final reversedMessageToLoad =
        messageToLoad.toList(growable: false).reversed;
    TextStyle textStyle = const TextStyle(fontFamily: "Alice");
    TextStyle dateStyle = const TextStyle(fontFamily: "Alice", fontSize: 10);

    for (var i = 0; i < messageToLoad.length; i++) {
      double oneTextLineHeight = 0;
      double mediaHeight = 0;
      double mediaWidth = 0;

      final msgID = reversedMessageToLoad.elementAt(i);
      Message? prevMsg = isUpdate
          ? _cachedDown4Message.isEmpty
              ? null
              : _cachedDown4Message.values.last
          : i < messageToLoad.length - 1
              ? reversedMessageToLoad.elementAt(i + 1).getLocalMessage()
              : null;
      Message? nextMessage = !isUpdate && i > 0
          ? reversedMessageToLoad.elementAt(i - 1).getLocalMessage()
          : null;

      if (nextMessage != null) {
        _cachedDown4Message[nextMessage.id] ??= nextMessage;
      }
      Message? down4Message =
          _cachedDown4Message[msgID] ??= msgID.getLocalMessage();
      if (prevMsg != null) {
        _cachedDown4Message[prevMsg.id] ??= prevMsg;
      }

      print("THE DOWN4MESSAGE = $down4Message");
      if (down4Message == null) return;
      MessageMedia? media;
      if (down4Message.mediaID != null) {
        media = down4Message.mediaID!.getLocalMessageMedia();
        if (media != null) {
          mediaWidth = maxWidth - messageBorder;
          mediaHeight = mediaWidth *
              (media.metadata.isSquared
                  ? 1.0
                  : media.metadata.elementAspectRatio);
        }
      }
      if (!down4Message.isRead) {
        down4Message
          ..isRead = true
          ..save();
      } else {
        idOfLastMessageRead ??= down4Message.id;
      }

      // Message? prevMessage = isUpdate ? _cachedDown4Message.isEmpty ? null : _cachedDown4Message.values.last :
      // Message? prevMsg =
      //     _cachedDown4Message.isEmpty ? null : _cachedDown4Message.values.last;
      String? prevMsgSender = prevMsg?.senderID;

      bool lastStringAndDateOnSameLine = false;
      double heightIfNotOnSameLine = 0.0;
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
        final words = transform2.split(" ")..add(timeString(down4Message));
        var previousString = "";

        // pervious string should always be < max
        for (final word in words) {
          if (word == words.last) {
            double dateWidth;
            double prevWidth = 0;
            String dateString = "      $word";
            final timeTp = TextPainter(
              text: TextSpan(text: dateString, style: dateStyle),
              textDirection: TextDirection.ltr,
            )..layout();
            dateWidth = timeTp.width;
            if (previousString.isNotEmpty) {
              final prevTp = TextPainter(
                text: TextSpan(text: previousString, style: textStyle),
                textDirection: TextDirection.ltr,
              )..layout();
              prevWidth = prevTp.width;
            }
            specialDisplayText.add(previousString);
            specialDisplayText.add(dateString);
            if (dateWidth + prevWidth > maxTextWidth) {
              // in this case, prevString + date is too wide
              if (prevWidth > neededWidth!) neededWidth = prevWidth;
              lastStringAndDateOnSameLine = false;
              heightIfNotOnSameLine = timeTp.height;
            } else {
              if (prevWidth + dateWidth > neededWidth!) {
                neededWidth = prevWidth + dateWidth;
              }
              lastStringAndDateOnSameLine = true;
            }
          } else if (word == "\n") {
            specialDisplayText.add(previousString);
            final specialTp = TextPainter(
              text: TextSpan(text: previousString, style: textStyle),
              textDirection: TextDirection.ltr,
            )..layout();
            if (specialTp.width > neededWidth!) {
              neededWidth = specialTp.width;
            }
            previousString = "";
          } else if (word.isNotEmpty) {
            final wordTp = TextPainter(
              text: TextSpan(text: word, style: textStyle),
              textDirection: TextDirection.ltr,
            )..layout();
            var wordLen = wordTp.width;
            var words = [word];
            while (wordLen > maxTextWidth) {
              final splitLen = (words.first.length / 2).ceil();
              words = words
                  .map((w) => [w.substring(0, splitLen), w.substring(splitLen)])
                  .expand((element) => element)
                  .toList();
              wordLen = words
                  .map((w) => TextPainter(
                      text: TextSpan(text: w, style: textStyle),
                      textDirection: TextDirection.ltr)
                    ..layout())
                  .map((e) => e.width)
                  .reduce(max);
            }
            if (words.length > 1) {
              // we have a word split
              if (previousString.isNotEmpty) {
                specialDisplayText.add(previousString);
              }
              for (final word in words) {
                specialDisplayText.add(word);
              }
              oneTextLineHeight = wordTp.height;
              if (wordLen > neededWidth!) neededWidth = wordLen;
              previousString = "";
            } else {
              final currentString =
                  previousString.isEmpty ? word : "$previousString $word";

              final previousTp = TextPainter(
                text: TextSpan(text: previousString, style: textStyle),
                textDirection: TextDirection.ltr,
              )..layout();

              final currentTp = TextPainter(
                text: TextSpan(text: currentString, style: textStyle),
                textDirection: TextDirection.ltr,
              )..layout();

              oneTextLineHeight = currentTp.height;

              // if the current text is larger than the available width
              if (currentTp.width >= maxTextWidth) {
                // we add the previousString to the list of display text
                specialDisplayText.add(previousString);
                // if the previous layout is bigger than our current biggest width,
                // it because the new biggest width
                if (previousTp.width > neededWidth!) {
                  neededWidth = previousTp.width;
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
        }
        // don't leave out the last string
        // if (previousString.isNotEmpty && previousString != "\n") {
        //   final lastLiner = TextPainter(
        //     text: TextSpan(text: previousString, style: textStyle),
        //     textDirection: TextDirection.ltr,
        //   )..layout();
        //   if (lastLiner.width > neededWidth!) {
        //     neededWidth = lastLiner.width;
        //   }
        //   print("last String = $previousString");
        //   specialDisplayText.add(previousString);
        // }

        return [specialDisplayText, neededWidth];
      }

      final bool senderIsSelf = down4Message.senderID == widget.self.id;
      final List<ReplyData>? repliesData = down4Message.replies
          ?.map((msgID) {
            final replyMsg =
                _cachedDown4Message[msgID] ??= msgID.getLocalMessage();
            final replyUser = widget.senders[replyMsg?.senderID];
            if (replyMsg == null || replyUser == null) return null;
            final String replyBody = replyMsg.text?.isNotEmpty ?? false
                ? replyMsg.text!
                : "&attachment";
            return ReplyData(
              senderID: replyMsg.senderID,
              senderName: replyUser.node.name,
              messageRefID: replyMsg.id,
              thumbnail: replyUser.nodeImage,
              body: replyBody,
              type: replyUser.node.colorCode,
            );
          })
          .whereType<ReplyData>()
          .toList(growable: false);

      double minWidth = 0;
      final bool hasReplies = (repliesData?.length ?? 0) > 0;
      final bool hasHeader = (!senderIsSelf &&
          theNode is GroupNode &&
          nextMessage?.senderID != down4Message.senderID);

      double minReplyDisplayLen(List<ReplyData> rds) {
        var lens = <double>[];
        for (final r in rds) {
          final firstWordInReply = r.body.split(" ").first;
          final tp = TextPainter(
            text: TextSpan(
                text: "${r.senderID}: $firstWordInReply",
                style: const TextStyle(fontSize: 12, fontFamily: "Alice")),
            textDirection: TextDirection.ltr,
          )..layout();
          lens.add(tp.width);
        }
        return lens.fold<double>(double.maxFinite, (p, e) => min(p, e));
      }

      String? headerText;
      if (hasReplies) {
        final minRepLen = minReplyDisplayLen(repliesData!);
        print("""
        =====================================
        MIN REP LEN OF REP = $minRepLen
        MAX LEN = $maxWidth
        REP FIRST = ${repliesData.first.body}
        """);
        minWidth = minRepLen > maxWidth ? maxWidth / golden : minRepLen;
      }
      if (hasHeader) {
        headerText = "-${down4Message.senderID}";
        final tp = TextPainter(
          text: TextSpan(
              text: "-${down4Message.senderID}   ",
              style: const TextStyle(fontFamily: "Alice", fontSize: 13)),
          textDirection: TextDirection.ltr,
        )..layout();
        if (minWidth < tp.width && tp.width < maxWidth / golden) {
          print("AAAAA");
          minWidth = tp.width;
        }
      }

      final textData = textAsStringList();
      final lineStrings = textData?[0] as List<String>?;
      final textWidth = textData?[1] as double?;
      final headerSize = hasHeader ? ChatMessage.headerHeight : 0;
      final repliesHeight =
          (repliesData?.length ?? 0) * ChatMessage.headerHeight;
      final messageHeight = lineStrings != null
          ? ((lineStrings.length - (lastStringAndDateOnSameLine ? 1 : 0)) *
                      oneTextLineHeight +
                  textPadding) +
              mediaHeight +
              messageBorder +
              headerSize +
              repliesHeight
          : mediaHeight + messageBorder + headerSize + repliesHeight;
      var messageWidth = media != null
          ? maxWidth
          : lineStrings != null
              ? textWidth! + textPadding + messageBorder
              : 0.0; // TODO, will be forwarding nodes, or messages
      messageWidth = messageWidth < minWidth ? minWidth : messageWidth;

      print("Textwidth=$textWidth");
      print("Number of lines=${lineStrings?.length}");
      final precalculatedSize = Size(messageWidth, messageHeight);
      print("PrecalculatedSize=$precalculatedSize");
      print("MaxWidth=$maxWidth");
      var chatMessage = ChatMessage(
        key: GlobalKey(),
        repliesData: repliesData,
        sender: widget.senders[down4Message.senderID]!,
        message: down4Message,
        myMessage: widget.self.id == down4Message.senderID,
        lastStringOnSameLine: lastStringAndDateOnSameLine,
        heightIfNotOnSameLine: heightIfNotOnSameLine,
        at: "",
        precalculatedSize: Size(messageWidth, messageHeight),
        precalculatedMediaSize:
            media != null ? Size(mediaWidth, mediaHeight) : null,
        specialDisplayTexts: lineStrings,
        // if is update, means it's a single new message with a header
        headerText: headerText,
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
                lastMessage.withHeader(header: "", newSize: newSize);
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

  Future<void> handleImport({required bool importImages}) async {
    if (importImages) {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
        requestFullMetadata: false,
      );
      for (final file in files) {
        // final bytes = await file.readAsBytes();
        // final decodedImage = await decodeImageFromList(bytes);
        final mediaID = u.randomMediaID();
        // final appPath = b.writeToDocs(cachedPath: file.path, mediaID: mediaID);
        final size = calculateImageDimension(f: File(file.path));
        final down4Media = MessageMedia(
          id: mediaID,
          isSaved: true,
          path: file.path,
          metadata: MediaMetadata(
            isSquared: false,
            isVideo: false,
            isReversed: false,
            timestamp: u.timeStamp(),
            owner: widget.self.id,
            elementAspectRatio: 1 / ((await size)?.aspectRatio ?? 1.0),
          ),
        )..save();
        _cachedImages[mediaID] = down4Media;
        widget.self
          ..images.add(mediaID)
          ..save();
      }
    } else {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      if (video == null) return;
      final videoInfoGetter = FlutterVideoInfo();
      final videoInfo = await videoInfoGetter.getVideoInfo(video.path);
      final mediaID = u.randomMediaID();
      // final appPath = b.writeToDocs(cachedPath: video.path, mediaID: mediaID);
      final down4Media = MessageMedia(
        id: mediaID,
        path: video.path,
        metadata: MediaMetadata(
          isReversed: false,
          isSquared: false,
          isVideo: true,
          timestamp: u.timeStamp(),
          owner: widget.self.id,
          elementAspectRatio:
              (videoInfo?.width ?? 1.0) / (videoInfo?.height ?? 1.0),
        ),
      );
      _cachedVideos[mediaID] = down4Media;
    }
    mediasConsole();
  }

  void loadSavingConsole() {
    _console = Console(
      inputs: [_consoleInput ?? consoleInput],
      topButtons: [
        ConsoleButton(
            name: "To Saved Messages",
            onPress: () {
              for (var msg in _cachedMessages.values) {
                if (msg.selected) {
                  widget.self.messages.add(msg.message.id);
                  msg.message
                    ..isSaved = true
                    ..save();
                }
              }
              widget.self.save();
              unselectSelectedMessage();
            })
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
        ConsoleButton(
            name: "To Medias",
            onPress: () {
              for (var msg in _cachedMessages.values) {
                if (msg.selected) {
                  if (msg.media != null) {
                    if (msg.media!.isVideo) {
                      widget.self.videos.add(msg.media!.id);
                    } else {
                      widget.self.images.add(msg.media!.id);
                    }
                    msg.media!
                      ..isSaved = true
                      ..save();
                  }
                }
              }
              widget.self.save();
              unselectSelectedMessage();
            }),
      ],
    );
    setState(() {});
  }

  void saveSelectedMessages() async {
    for (final msg in _cachedMessages.values) {
      if (msg.selected) {
        _cachedMessages[msg.message.id] = msg.invertedSelection();
        widget.self.messages.add(msg.message.id);
        msg.message
          ..isSaved = true
          ..save();
      }
    }
    widget.self.save();
    setState(() {});
  }

  void unselectSelectedMessage() {
    for (final key in _cachedMessages.keys) {
      if (_cachedMessages[key]?.selected ?? false) {
        _cachedMessages[key] = _cachedMessages[key]!.invertedSelection();
      }
    }
    setState(() {});
  }

  void send2({MessageMedia? mediaInput}) {
    if (tec.value.text == "" && mediaInput == null && _cameraInput == null) {
      return;
    }
    final ts = u.timeStamp();
    final targets = widget.node.calculateTargets(widget.self.id);

    var msg = Message(
      root: widget.node is GroupNode ? widget.node.id : null,
      id: messagePushId(),
      timestamp: ts,
      senderID: widget.self.id,
      mediaID: mediaInput?.id ?? _cameraInput?.id,
      text: tec.value.text,
      replies: _cachedMessages.values
          .where((msg) => msg.selected)
          .map((msg) => msg.message.id)
          .toList(growable: false),
    );

    unselectSelectedMessage();

    var req = r.ChatRequest(
      message: msg,
      targets: targets.toList(),
      media: mediaInput ?? _cameraInput,
    );

    widget.send(req);
    tec.clear();
    _cameraInput = null;
  }

  Future<void> loadFullCamera() async {
    // TODO
  }

  Future<void> loadSquaredCameraPreview({
    required String cachedPath,
    required bool isVideo,
    required bool isReversed,
    required double aspectRatio,
  }) async {
    VideoPlayerController? vpc;
    if (isVideo) {
      vpc = VideoPlayerController.file(File(cachedPath));
      await vpc.initialize();
    }
    _console = Console(
      inputs: [consoleInput],
      toMirror: isReversed,
      videoPlayerController: vpc,
      imagePreviewPath: cachedPath,
      topButtons: [
        ConsoleButton(
            name: "Accept",
            onPress: () {
              _cameraInput = MessageMedia(
                path: cachedPath,
                id: u.randomMediaID(),
                metadata: MediaMetadata(
                  isReversed: isReversed,
                  isVideo: isVideo,
                  isSquared: true,
                  canSkipCheck: true,
                  owner: widget.self.id,
                  elementAspectRatio: aspectRatio,
                  timestamp: u.timeStamp(),
                ),
              );
              loadBaseConsole();
            }),
      ],
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () {
              _cameraInput = null;
              loadSquaredCameraConsole();
            }),
        ConsoleButton(
            name: "Cancel",
            onPress: () {
              _cameraInput = null;
              loadBaseConsole();
            }),
      ],
    );

    setState(() {});
  }

  Future<void> loadSquaredCameraConsole([
    int cam = 0,
    FlashMode fm = FlashMode.off,
    bool reloadCtrl = false,
  ]) async {
    if (ctrl == null || reloadCtrl) {
      try {
        ctrl = CameraController(widget.cameras[cam], ResolutionPreset.medium);
        await ctrl?.initialize();
      } catch (error) {
        loadBaseConsole();
      }
    }
    ctrl?.setFlashMode(fm);
    _console = Console(
      inputs: [consoleInput],
      cameraController: ctrl,
      aspectRatio: ctrl?.value.aspectRatio,
      topButtons: [
        ConsoleButton(name: "Squared", isMode: true, onPress: loadFullCamera),
        ConsoleButton(
          name: "Capture",
          isSpecial: true,
          shouldBeDownButIsnt: ctrl?.value.isRecordingVideo == true,
          onPress: () async {
            var file = await ctrl?.takePicture();
            if (file == null) loadBaseConsole();
            loadSquaredCameraPreview(
              cachedPath: file!.path,
              aspectRatio: ctrl!.value.aspectRatio,
              isReversed: ctrl?.cameraId == 1,
              isVideo: false,
            );
          },
          onLongPress: () async {
            await ctrl?.startVideoRecording();
            loadSquaredCameraConsole(cam, fm);
          },
          onLongPressUp: () async {
            var file = await ctrl?.stopVideoRecording();
            if (file == null) loadBaseConsole();
            loadSquaredCameraPreview(
              cachedPath: file!.path,
              aspectRatio: ctrl!.value.aspectRatio,
              isReversed: ctrl?.cameraId == 1,
              isVideo: true,
            );
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () async {
              await ctrl?.dispose();
              ctrl = null;
              loadBaseConsole();
            }),
        ConsoleButton(
          name: cam == 0 ? "Rear" : "Front",
          isMode: true,
          onPress: () => loadSquaredCameraConsole((cam + 1) % 2, fm, true),
        ),
        ConsoleButton(
          isMode: true,
          name: fm.name.capitalize(),
          onPress: () => loadSquaredCameraConsole(
              cam, fm == FlashMode.off ? FlashMode.torch : FlashMode.off),
        ),
      ],
    );
    setState(() {});
  }

  void loadBaseConsole() {
    _console = Console(
      inputs: [_consoleInput ?? consoleInput],
      topButtons: [
        ConsoleButton(name: "Save", onPress: loadSavingConsole),
        ConsoleButton(
          name: "Send",
          onPress: () {
            send2();
            loadBaseConsole();
          },
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          name: _cameraInput == null ? "Camera" : "@Camera",
          onPress: loadSquaredCameraConsole,
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
      selectMedia: (media) => send2(mediaInput: media),
      topButtons: [
        ConsoleButton(
          name: "Import",
          onPress: () => handleImport(importImages: images),
        ),
      ],
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: loadBaseConsole),
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
