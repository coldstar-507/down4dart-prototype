import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:down4/src/render_objects/render_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
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
  var _tec = TextEditingController();
  // CameraController? _ctrl;
  MessageMedia? _cameraInput;
  Map<Identifier, ChatMessage> _cachedMessages = {};
  Map<Identifier, Message?> _cachedDown4Message = {};
  static const gap = 20;
  int _takeLimit = 30;
  String? _idOfLastMessageRead;

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      print("REACHED THE TOP!!!!");
      setState(() {
        _takeLimit += gap;
      });
    }
    if (_scrollController.offset <=
            _scrollController.position.minScrollExtent &&
        !_scrollController.position.outOfRange) {
      print("REACHED THE BOTTOM");
    }
  }

  late var _scrollController = ScrollController()..addListener(_scrollListener);

  Map<Identifier, MessageMedia> _cachedImages = {};
  Map<Identifier, MessageMedia> _cachedVideos = {};

  @override
  void initState() {
    super.initState();
    asyncImageLoad();
    messages.take(gap).toList();
    // loadMessages();
    loadBaseConsole();
  }

  @override
  void didUpdateWidget(ChatPage cp) {
    super.didUpdateWidget(cp);
    // loadMessages(isUpdate: true);
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

  double get maxMessageWidth => Sizes.w * 0.76;

  double get textPadding => 12.0;

  double get messageBorder => 4.0;

  double get maxTextWidth => maxMessageWidth - textPadding - messageBorder;

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

  bool displayGap(Message msg, Message prevMsg) {
    final prevMsgTS = DateTime.fromMillisecondsSinceEpoch(prevMsg.timestamp);
    final curMsgTS = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
    if (curMsgTS.difference(prevMsgTS).inMinutes > 20) {
      return true;
    } else {
      return false;
    }
  }

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

  List<dynamic>? textAsStringList(Message msg) {
    List<String>? specialDisplayText;
    double? neededWidth;
    bool lastStringAndDateOnSameLine = false;
    double heightIfNotOnSameLine = 0.0;
    double oneLineTextHeight = 0.0;

    if (msg.text?.isEmpty ?? true) return null;

    specialDisplayText = [];
    neededWidth = 0.0;

    final text = msg.text!;
    final transform1 = text.split("\n");
    final transform2 = transform1.join(" \n ");

    final words = transform2.split(" ")..add(timeString(msg));
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
          oneLineTextHeight = wordTp.height;
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

          oneLineTextHeight = currentTp.height;

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

    return [
      specialDisplayText,
      neededWidth,
      oneLineTextHeight,
      heightIfNotOnSameLine,
      lastStringAndDateOnSameLine,
    ];
  }

  TextStyle get textStyle => const TextStyle(fontFamily: "Alice");

  TextStyle get dateStyle => const TextStyle(fontFamily: "Alice", fontSize: 10);

  ChatMessage loadMessage(
    Identifier msgID,
    Identifier? prevMsgID,
    Identifier? nextMsgID,
    bool isLast,
  ) {
    Message msg;
    Message? prevMsg, nextMsg;
    ChatMessage? prevChatMessage;

    // If new message while in chat, we might want to remove the header of the
    // previous last message
    if (isLast &&
        prevMsgID != null &&
        ((prevChatMessage = _cachedMessages[prevMsgID]) != null) &&
        prevChatMessage!.hasHeader) {
      msg = _cachedDown4Message[msgID] ??= msgID.getLocalMessage()!;
      if (msg.senderID == prevChatMessage.message.senderID &&
          msg.senderID != widget.self.id) {
        // we need to remove its header
        // and update it's size
        final lastMessageSize = prevChatMessage.precalculatedSize;
        final newSize = Size(lastMessageSize.width,
            lastMessageSize.height - ChatMessage.headerHeight);
        _cachedMessages[prevMsgID] =
            prevChatMessage.withHeader(header: "", newSize: newSize);
      }
    }

    if (_cachedMessages[msgID] != null) return _cachedMessages[msgID]!;

    msg = _cachedDown4Message[msgID] ??= msgID.getLocalMessage()!;
    prevMsg = prevMsgID != null
        ? _cachedDown4Message[prevMsgID] ??= prevMsgID.getLocalMessage()
        : null;
    nextMsg = nextMsgID != null
        ? _cachedDown4Message[nextMsgID] ??= nextMsgID.getLocalMessage()
        : null;

    double mediaHeight = 0;
    double mediaWidth = 0;
    bool hasGap = false;

    if (prevMsg != null) hasGap = displayGap(msg, prevMsg);

    MessageMedia? media;
    if (msg.mediaID != null) {
      media = msg.mediaID!.getLocalMessageMedia();
      if (media != null) {
        mediaWidth = maxMessageWidth - messageBorder;
        mediaHeight = mediaWidth *
            (media.metadata.isSquared
                ? 1.0
                : media.metadata.elementAspectRatio);
      }
    }
    if (!msg.isRead) {
      msg
        ..isRead = true
        ..save();
    } else {
      _idOfLastMessageRead ??= msg.id;
    }

    final bool senderIsSelf = msg.senderID == widget.self.id;
    final List<ReplyData>? repliesData = msg.replies
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
    final bool hasHeader = !senderIsSelf &&
        widget.node is GroupNode &&
        nextMsg?.senderID != msg.senderID;

    String? headerText;
    if (hasReplies) {
      final minRepLen = minReplyDisplayLen(repliesData!);
      print("""
        =====================================
        MIN REP LEN OF REP = $minRepLen
        MAX LEN = $maxTextWidth
        REP FIRST = ${repliesData.first.body}
        """);
      minWidth =
          minRepLen > maxMessageWidth ? maxMessageWidth / golden : minRepLen;
    }
    if (hasHeader) {
      headerText = "-${msg.senderID}";
      final tp = TextPainter(
        text: TextSpan(
            text: "-${msg.senderID}   ",
            style: const TextStyle(fontFamily: "Alice", fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout();
      if (minWidth < tp.width && tp.width < maxMessageWidth / golden) {
        print("AAAAA");
        minWidth = tp.width;
      }
    }

    final textData = textAsStringList(msg);
    final hasText = textData != null;

    final lineStrings = textData?[0] as List<String>?;
    final textWidth = textData?[1] as double?;
    final oneTextLineHeight = textData?[2] ?? 0.0;
    final heightIfNotOnSameLine = textData?[3] ?? 0.0;
    final lastStringAndDateOnSameLine = textData?[4] ?? false;

    final headerSize = hasHeader ? ChatMessage.headerHeight : 0;
    final repliesHeight = (repliesData?.length ?? 0) * ChatMessage.headerHeight;
    final nLines = hasText ? lineStrings!.length - 1 : 0;

    var messageHeight =
        mediaHeight + messageBorder + headerSize + repliesHeight;
    messageHeight += hasText
        ? (nLines * oneTextLineHeight) + textPadding + heightIfNotOnSameLine
        : 0;

    var messageWidth = media != null
        ? maxMessageWidth
        : lineStrings != null
            ? textWidth! + textPadding + messageBorder
            : 0.0; // TODO, will be forwarding nodes, or messages
    messageWidth = messageWidth < minWidth ? minWidth : messageWidth;

    return _cachedMessages[msg.id] = ChatMessage(
      key: GlobalKey(),
      hasGap: hasGap,
      repliesData: repliesData,
      sender: widget.senders[msg.senderID]!,
      message: msg,
      myMessage: widget.self.id == msg.senderID,
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
  }

  Iterable<ChatMessage> get messages sync* {
    final msgs = widget.node.messages.toList(growable: false);
    final int nMsg = msgs.length;
    for (int i = nMsg - 1; i >= 0; i--) {
      final Identifier msgID = msgs[i];
      final Identifier? prevMsgID = i > 0 ? msgs[i - 1] : null;
      final Identifier? nextMsgID = i < nMsg - 1 ? msgs[i + 1] : null;
      final isFirst = i == nMsg - 1;
      yield loadMessage(msgID, prevMsgID, nextMsgID, isFirst);
    }
  }

  ConsoleInput get consoleInput => _consoleInput = ConsoleInput(
        tec: _tec,
        inputCallBack: (t) => null,
        placeHolder: ":)",
      );

  // Future<void> loadMessages({bool isUpdate = false}) async {
  //   final loadedMessagesKeys = _cachedMessages.keys.toSet();
  //   final allMessagesKeys = widget.node.messages;
  //   List<String> messageToLoad =
  //       allMessagesKeys.difference(loadedMessagesKeys).toList(growable: false);
  //   print("Messages to load $messageToLoad");
  //
  //   final maxWidth = Sizes.w * 0.76;
  //   const textPadding = 12;
  //   const messageBorder = 4;
  //   final maxTextWidth = maxWidth - textPadding - messageBorder;
  //
  //   if (!isUpdate) messageToLoad = messageToLoad.reversed.toList();
  //   TextStyle textStyle = const TextStyle(fontFamily: "Alice");
  //   TextStyle dateStyle = const TextStyle(fontFamily: "Alice", fontSize: 10);
  //
  //   for (var i = 0; i < messageToLoad.length; i++) {
  //     double oneTextLineHeight = 0;
  //     double mediaHeight = 0;
  //     double mediaWidth = 0;
  //
  //     final msgID = messageToLoad[i];
  //     Message? prevMsg = isUpdate
  //         ? _cachedDown4Message.isEmpty
  //             ? null
  //             : _cachedDown4Message.values.last
  //         : i < messageToLoad.length - 1
  //             ? messageToLoad[i + 1].getLocalMessage()
  //             : null;
  //     Message? nextMessage =
  //         !isUpdate && i > 0 ? messageToLoad[i - 1].getLocalMessage() : null;
  //
  //     if (nextMessage != null) {
  //       _cachedDown4Message[nextMessage.id] ??= nextMessage;
  //     }
  //     bool hasGap = false;
  //     Message? down4Message =
  //         _cachedDown4Message[msgID] ??= msgID.getLocalMessage();
  //     if (prevMsg != null) {
  //       _cachedDown4Message[prevMsg.id] ??= prevMsg;
  //       if (down4Message != null) {
  //         final prevMsgTS =
  //             DateTime.fromMillisecondsSinceEpoch(prevMsg.timestamp);
  //         final curMsgTS =
  //             DateTime.fromMillisecondsSinceEpoch(down4Message.timestamp);
  //         if (curMsgTS.difference(prevMsgTS).inMinutes > 20) {
  //           hasGap = true;
  //         }
  //       }
  //     }
  //
  //     if (down4Message == null) return;
  //     MessageMedia? media;
  //     if (down4Message.mediaID != null) {
  //       media = down4Message.mediaID!.getLocalMessageMedia();
  //       if (media != null) {
  //         mediaWidth = maxWidth - messageBorder;
  //         mediaHeight = mediaWidth *
  //             (media.metadata.isSquared
  //                 ? 1.0
  //                 : media.metadata.elementAspectRatio);
  //       }
  //     }
  //     if (!down4Message.isRead) {
  //       down4Message
  //         ..isRead = true
  //         ..save();
  //     } else {
  //       idOfLastMessageRead ??= down4Message.id;
  //     }
  //
  //     bool lastStringAndDateOnSameLine = false;
  //     double heightIfNotOnSameLine = 0.0;
  //     List<dynamic>? textAsStringList() {
  //       List<String>? specialDisplayText;
  //       double? neededWidth;
  //
  //       if (down4Message.text?.isEmpty ?? true) return null;
  //
  //       specialDisplayText = [];
  //       neededWidth = 0.0;
  //
  //       final text = down4Message.text!;
  //       final transform1 = text.split("\n");
  //       final transform2 = transform1.join(" \n ");
  //
  //       // var words = down4Message.text!.split(" ");
  //       final words = transform2.split(" ")..add(timeString(down4Message));
  //       var previousString = "";
  //
  //       // pervious string should always be < max
  //       for (final word in words) {
  //         if (word == words.last) {
  //           double dateWidth;
  //           double prevWidth = 0;
  //           String dateString = "      $word";
  //           final timeTp = TextPainter(
  //             text: TextSpan(text: dateString, style: dateStyle),
  //             textDirection: TextDirection.ltr,
  //           )..layout();
  //           dateWidth = timeTp.width;
  //           if (previousString.isNotEmpty) {
  //             final prevTp = TextPainter(
  //               text: TextSpan(text: previousString, style: textStyle),
  //               textDirection: TextDirection.ltr,
  //             )..layout();
  //             prevWidth = prevTp.width;
  //           }
  //           specialDisplayText.add(previousString);
  //           specialDisplayText.add(dateString);
  //           if (dateWidth + prevWidth > maxTextWidth) {
  //             // in this case, prevString + date is too wide
  //             if (prevWidth > neededWidth!) neededWidth = prevWidth;
  //             lastStringAndDateOnSameLine = false;
  //             heightIfNotOnSameLine = timeTp.height;
  //           } else {
  //             if (prevWidth + dateWidth > neededWidth!) {
  //               neededWidth = prevWidth + dateWidth;
  //             }
  //             lastStringAndDateOnSameLine = true;
  //           }
  //         } else if (word == "\n") {
  //           specialDisplayText.add(previousString);
  //           final specialTp = TextPainter(
  //             text: TextSpan(text: previousString, style: textStyle),
  //             textDirection: TextDirection.ltr,
  //           )..layout();
  //           if (specialTp.width > neededWidth!) {
  //             neededWidth = specialTp.width;
  //           }
  //           previousString = "";
  //         } else if (word.isNotEmpty) {
  //           final wordTp = TextPainter(
  //             text: TextSpan(text: word, style: textStyle),
  //             textDirection: TextDirection.ltr,
  //           )..layout();
  //           var wordLen = wordTp.width;
  //           var words = [word];
  //           while (wordLen > maxTextWidth) {
  //             final splitLen = (words.first.length / 2).ceil();
  //             words = words
  //                 .map((w) => [w.substring(0, splitLen), w.substring(splitLen)])
  //                 .expand((element) => element)
  //                 .toList();
  //             wordLen = words
  //                 .map((w) => TextPainter(
  //                     text: TextSpan(text: w, style: textStyle),
  //                     textDirection: TextDirection.ltr)
  //                   ..layout())
  //                 .map((e) => e.width)
  //                 .reduce(max);
  //           }
  //           if (words.length > 1) {
  //             // we have a word split
  //             if (previousString.isNotEmpty) {
  //               specialDisplayText.add(previousString);
  //             }
  //             for (final word in words) {
  //               specialDisplayText.add(word);
  //             }
  //             oneTextLineHeight = wordTp.height;
  //             if (wordLen > neededWidth!) neededWidth = wordLen;
  //             previousString = "";
  //           } else {
  //             final currentString =
  //                 previousString.isEmpty ? word : "$previousString $word";
  //
  //             final previousTp = TextPainter(
  //               text: TextSpan(text: previousString, style: textStyle),
  //               textDirection: TextDirection.ltr,
  //             )..layout();
  //
  //             final currentTp = TextPainter(
  //               text: TextSpan(text: currentString, style: textStyle),
  //               textDirection: TextDirection.ltr,
  //             )..layout();
  //
  //             oneTextLineHeight = currentTp.height;
  //
  //             // if the current text is larger than the available width
  //             if (currentTp.width >= maxTextWidth) {
  //               // we add the previousString to the list of display text
  //               specialDisplayText.add(previousString);
  //               // if the previous layout is bigger than our current biggest width,
  //               // it because the new biggest width
  //               if (previousTp.width > neededWidth!) {
  //                 neededWidth = previousTp.width;
  //               }
  //               // now we set the previous string as the word
  //               previousString = word;
  //             } else {
  //               // if the current text is not larger than available width
  //               // we simply update it
  //               previousString = currentString;
  //             }
  //           }
  //         }
  //       }
  //
  //       return [specialDisplayText, neededWidth];
  //     }
  //
  //     final bool senderIsSelf = down4Message.senderID == widget.self.id;
  //     final List<ReplyData>? repliesData = down4Message.replies
  //         ?.map((msgID) {
  //           final replyMsg =
  //               _cachedDown4Message[msgID] ??= msgID.getLocalMessage();
  //           final replyUser = widget.senders[replyMsg?.senderID];
  //           if (replyMsg == null || replyUser == null) return null;
  //           final String replyBody = replyMsg.text?.isNotEmpty ?? false
  //               ? replyMsg.text!
  //               : "&attachment";
  //           return ReplyData(
  //             senderID: replyMsg.senderID,
  //             senderName: replyUser.node.name,
  //             messageRefID: replyMsg.id,
  //             thumbnail: replyUser.nodeImage,
  //             body: replyBody,
  //             type: replyUser.node.colorCode,
  //           );
  //         })
  //         .whereType<ReplyData>()
  //         .toList(growable: false);
  //
  //     double minWidth = 0;
  //     final bool hasReplies = (repliesData?.length ?? 0) > 0;
  //     final bool hasHeader = !senderIsSelf &&
  //         theNode is GroupNode &&
  //         nextMessage?.senderID != down4Message.senderID;
  //
  //     double minReplyDisplayLen(List<ReplyData> rds) {
  //       var lens = <double>[];
  //       for (final r in rds) {
  //         final firstWordInReply = r.body.split(" ").first;
  //         final tp = TextPainter(
  //           text: TextSpan(
  //               text: "${r.senderID}: $firstWordInReply",
  //               style: const TextStyle(fontSize: 12, fontFamily: "Alice")),
  //           textDirection: TextDirection.ltr,
  //         )..layout();
  //         lens.add(tp.width);
  //       }
  //       return lens.fold<double>(double.maxFinite, (p, e) => min(p, e));
  //     }
  //
  //     String? headerText;
  //     if (hasReplies) {
  //       final minRepLen = minReplyDisplayLen(repliesData!);
  //       print("""
  //       =====================================
  //       MIN REP LEN OF REP = $minRepLen
  //       MAX LEN = $maxWidth
  //       REP FIRST = ${repliesData.first.body}
  //       """);
  //       minWidth = minRepLen > maxWidth ? maxWidth / golden : minRepLen;
  //     }
  //     if (hasHeader) {
  //       headerText = "-${down4Message.senderID}";
  //       final tp = TextPainter(
  //         text: TextSpan(
  //             text: "-${down4Message.senderID}   ",
  //             style: const TextStyle(fontFamily: "Alice", fontSize: 13)),
  //         textDirection: TextDirection.ltr,
  //       )..layout();
  //       if (minWidth < tp.width && tp.width < maxWidth / golden) {
  //         print("AAAAA");
  //         minWidth = tp.width;
  //       }
  //     }
  //
  //     final textData = textAsStringList();
  //     final lineStrings = textData?[0] as List<String>?;
  //     final textWidth = textData?[1] as double?;
  //     final headerSize = hasHeader ? ChatMessage.headerHeight : 0;
  //     final repliesHeight =
  //         (repliesData?.length ?? 0) * ChatMessage.headerHeight;
  //     final hasText = lineStrings != null;
  //     final nLines = hasText ? lineStrings.length - 1 : 0;
  //     var messageHeight =
  //         mediaHeight + messageBorder + headerSize + repliesHeight;
  //
  //     messageHeight += hasText
  //         ? (nLines * oneTextLineHeight) + textPadding + heightIfNotOnSameLine
  //         : 0;
  //
  //     var messageWidth = media != null
  //         ? maxWidth
  //         : lineStrings != null
  //             ? textWidth! + textPadding + messageBorder
  //             : 0.0; // TODO, will be forwarding nodes, or messages
  //     messageWidth = messageWidth < minWidth ? minWidth : messageWidth;
  //
  //     var chatMessage = ChatMessage(
  //       key: GlobalKey(),
  //       hasGap: hasGap,
  //       repliesData: repliesData,
  //       sender: widget.senders[down4Message.senderID]!,
  //       message: down4Message,
  //       myMessage: widget.self.id == down4Message.senderID,
  //       lastStringOnSameLine: lastStringAndDateOnSameLine,
  //       heightIfNotOnSameLine: heightIfNotOnSameLine,
  //       at: "",
  //       precalculatedSize: Size(messageWidth, messageHeight),
  //       precalculatedMediaSize:
  //           media != null ? Size(mediaWidth, mediaHeight) : null,
  //       specialDisplayTexts: lineStrings,
  //       // if is update, means it's a single new message with a header
  //       headerText: headerText,
  //       media: media,
  //       select: (id, _) => setState(() {
  //         _cachedMessages[id] = _cachedMessages[id]!.invertedSelection();
  //       }),
  //     );
  //
  //     if (isUpdate) {
  //       if (_cachedMessages.isNotEmpty) {
  //         // last message receive is the first in the list
  //         final lastMessage = _cachedMessages.values.first;
  //         if (lastMessage.message.senderID == down4Message.senderID) {
  //           // we need to remove its header
  //           // and update it's size
  //           final lastMessageSize = lastMessage.precalculatedSize;
  //           final newSize = Size(
  //               lastMessageSize.width, lastMessageSize.height - headerSize);
  //           _cachedMessages[lastMessage.message.id] =
  //               lastMessage.withHeader(header: "", newSize: newSize);
  //         }
  //       }
  //       _cachedMessages = {down4Message.id: chatMessage, ..._cachedMessages};
  //       setState(() {});
  //     } else {
  //       _cachedMessages[down4Message.id] = chatMessage;
  //       setState(() {
  //         print("CACHED MESSAGE LEN = ${_cachedMessages.length}");
  //         print("TOTAL MESSAGE LEN  = ${widget.node.messages.length}");
  //       });
  //     }
  //   }
  // }

  Future<void> handleImport({required bool importImages}) async {
    if (importImages) {
      final results = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'svg'],
        allowMultiple: true,
        allowCompression: true,
        withData: true,
      );

      // final files = await ImagePicker().pickMultiImage(
      //   maxWidth: 512,
      //   maxHeight: 512,
      //   imageQuality: 70,
      //   requestFullMetadata: false,
      // );

      if (results == null) return;
      for (final file in results.files) {
        if (file.bytes == null || file.path == null) continue;
        final mediaID = u.deterministicMediaID(file.bytes!);
        final size = await decodeImageSize(file.bytes!);
        final down4Media = MessageMedia(
          id: mediaID,
          isSaved: true,
          path: file.path!,
          metadata: MediaMetadata(
            isSquared: false,
            isVideo: false,
            isReversed: false,
            timestamp: u.timeStamp(),
            owner: widget.self.id,
            elementAspectRatio: 1.0 / size.aspectRatio,
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
    if (_tec.value.text == "" && mediaInput == null && _cameraInput == null) {
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
      text: _tec.value.text,
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
    _tec.clear();
    _cameraInput = null;
  }

  Future<void> loadFullCamera() async {
    // TODO
  }

  Future<void> loadSquaredCameraPreview({
    required int cam,
    required String cachedPath,
    required bool isVideo,
    required CameraController ctrl,
  }) async {
    VideoPlayerController? vpc;
    if (isVideo) {
      vpc = VideoPlayerController.file(File(cachedPath));
      await vpc.initialize();
    }
    _console = Console(
      inputs: [consoleInput],
      toMirror: cam == 1,
      aspectRatio: ctrl.value.aspectRatio,
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
                  isReversed: ctrl.cameraId == 1,
                  isVideo: isVideo,
                  isSquared: true,
                  canSkipCheck: true,
                  owner: widget.self.id,
                  elementAspectRatio: ctrl.value.aspectRatio,
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
              loadSquaredCameraConsole(cam: cam, ctrl: ctrl);
            }),
        ConsoleButton(
            name: "Cancel",
            onPress: () async {
              await ctrl.dispose();
              _cameraInput = null;
              loadBaseConsole();
            }),
      ],
    );

    setState(() {});
  }

  Future<void> loadSquaredCameraConsole({
    required int cam,
    CameraController? ctrl,
    FlashMode fm = FlashMode.off,
    bool reloadCtrl = false,
  }) async {
    Future<void> nextFlashMode() => loadSquaredCameraConsole(
          cam: cam,
          ctrl: ctrl,
          fm: fm == FlashMode.off ? FlashMode.torch : FlashMode.off,
        );

    Future<void> nextCam() async {
      await ctrl?.dispose();
      return loadSquaredCameraConsole(cam: (cam + 1) % 2);
    }

    Future<void> initCam(int cameraID) async {
      try {
        ctrl = CameraController(
          widget.cameras[cameraID],
          ResolutionPreset.medium,
        );
        await ctrl!.initialize();
      } catch (error) {
        print("Error initializing cam in chat_page: $e");
        loadBaseConsole();
      }
    }

    if (ctrl == null) await initCam(cam);
    print("""
    ============================
    ${ctrl!.cameraId} is the camera id
    ${ctrl!.description.sensorOrientation} is the sensor Orientation
    $cam is the camera number
    ============================
    """);
    ctrl!.setFlashMode(fm);

    _console = Console(
      inputs: [consoleInput],
      cameraController: ctrl,
      aspectRatio: ctrl!.value.aspectRatio,
      topButtons: [
        ConsoleButton(
          name: "Squared",
          isMode: true,
          onPress: loadFullCamera,
          isActivated: false,
          greyedOut: true,
        ),
        ConsoleButton(
          name: "Capture",
          isSpecial: true,
          shouldBeDownButIsnt: ctrl!.value.isRecordingVideo == true,
          onPress: () async {
            var file = await ctrl!.takePicture();
            loadSquaredCameraPreview(
              cam: cam,
              cachedPath: file.path,
              isVideo: false,
              ctrl: ctrl!,
            );
          },
          onLongPress: () async {
            await ctrl!.startVideoRecording();
            loadSquaredCameraConsole(cam: cam, ctrl: ctrl, fm: fm);
          },
          onLongPressUp: () async {
            var file = await ctrl!.stopVideoRecording();
            loadSquaredCameraPreview(
              cam: cam,
              cachedPath: file.path,
              ctrl: ctrl!,
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
              loadBaseConsole();
            }),
        ConsoleButton(
          name: cam == 0 ? "Rear" : "Front",
          isMode: true,
          onPress: nextCam,
        ),
        ConsoleButton(
          isMode: true,
          name: fm.name.capitalize(),
          onPress: nextFlashMode,
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
          onPress: () => loadSquaredCameraConsole(cam: 0),
        ),
        ConsoleButton(
          name: "Medias",
          onPress: mediasConsole,
        ),
      ],
    );
    setState(() {});
  }

  void mediasConsole({
    bool images = true,
    String mode = "Send",
    bool extra = false,
  }) {
    void switchMode() => mode == "Send"
        ? mediasConsole(images: images, mode: "Delete", extra: true)
        : mediasConsole(images: images, mode: "Send", extra: true);

    void selectMedia(MessageMedia media) {
      if (mode == "Send") return send2(mediaInput: media);
      if (!media.isVideo) {
        widget.self.images.remove(media.id);
      } else {
        widget.self.videos.remove(media.id);
      }
      media
        ..isSaved = false
        ..delete();
      mediasConsole(images: images, mode: mode, extra: extra);
    }

    _console = Console(
      images: true,
      inputs: [_consoleInput ?? consoleInput],
      medias: images ? savedImages.toList() : savedVideos.toList(),
      selectMedia: selectMedia,
      topButtons: [
        ConsoleButton(
          name: "Import",
          onPress: () => handleImport(importImages: images),
        ),
      ],
      bottomButtons: [
        ConsoleButton(
          showExtra: extra,
          isSpecial: true,
          name: "Back",
          onPress: () => extra
              ? mediasConsole(images: images, mode: mode, extra: !extra)
              : loadBaseConsole(),
          onLongPress: () =>
              mediasConsole(images: images, mode: mode, extra: true),
          extraButtons: [
            ConsoleButton(name: mode, onPress: switchMode, isMode: true),
          ],
        ),
        ConsoleButton(
          isMode: true,
          name: images ? "Images" : "Videos",
          onPress: () => mediasConsole(images: !images),
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
              list: messages.take(_takeLimit).toList(),
              scrollController: _scrollController,
              // iterables: messages.take(10),
            ),
            Down4Page(
              title: "People",
              console: _console!,
              list: widget.senders.values.toList(),
            ),
          ]
        : [
            Down4Page(
              isChatPage: true,
              title: widget.node.name,
              console: _console!,
              list: messages.take(_takeLimit).toList(),
              scrollController: _scrollController,
              // iterables: messages.take(10),
              // messages: _cachedMessages.values.toList(),
            ),
          ];

    return Andrew(
      initialPageIndex: widget.pageIndex,
      pages: pages,
      onPageChange: widget.onPageChange,
    );
  }
}
