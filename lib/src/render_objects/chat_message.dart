import 'dart:math' show max;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../_down4_dart_utils.dart' show Pair;

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';

import '_down4_flutter_utils.dart';

class ChatReplyInfo {
  final Identifier messageRefID, senderID; // senderName,
  // final Image thumbnail;
  final String body;
  // final NodesColor type;
  final void Function() onPressReply;
  const ChatReplyInfo({
    required this.onPressReply,
    // required this.senderName,
    required this.senderID,
    required this.messageRefID,
    // required this.thumbnail,
    required this.body,
    // required this.type,
  });
}

class ChatMediaInfo {
  final MessageMedia media;
  final Size precalculatedMediaSize;
  final VideoPlayerController? videoController;
  const ChatMediaInfo({
    required this.media,
    required this.precalculatedMediaSize,
    this.videoController,
  });
}

class ChatTextInfo {
  final List<String> specialDisplayTexts;
  final double heightIfNotOnSameLine, neededWidth, singleLineHeight;
  final bool lastStringOnSameLine;
  const ChatTextInfo({
    required this.specialDisplayTexts,
    required this.heightIfNotOnSameLine,
    required this.lastStringOnSameLine,
    required this.neededWidth,
    required this.singleLineHeight,
  });
}

class ChatMessage extends StatelessWidget {
  static const double headerHeight = 18.0;
  final bool myMessage, selected, isPost;
  final void Function(Identifier id)? select;
  // final void Function(Identifier id)? goToReply;
  final Message message;
  final bool hasGap, hasHeader;
  // final Widget Function(double) spinningLogo;

  // final VideoPlayerController? videoController;
  final ChatTextInfo? textInfo;
  final ChatMediaInfo? mediaInfo;
  final List<ChatReplyInfo>? repliesInfo;

  // const ChatMessage._({
  //   this.textInfo,
  //   this.mediaInfo,
  //   this.replyInfo,
  //   required this.spinningLogo,
  //   required this.hasHeader,
  //   required this.message,
  //   required this.goToReply,
  //   required this.myMessage,
  //   required this.hasGap,
  //   this.videoController,
  //   this.isPost = false,
  //   this.selected = false,
  //   required this.select,
  //   Key? key,
  // }) : super(key: key);

  const ChatMessage({
    required this.hasHeader,
    required this.message,
    // required this.goToReply,
    required this.myMessage,
    required this.hasGap,
    // required this.spinningLogo,
    // this.videoController,
    required this.mediaInfo,
    required this.textInfo,
    required this.repliesInfo,
    this.isPost = false,
    this.selected = false,
    required this.select,
    Key? key,
  }) : super(key: key);

  ChatMessage withHeader({required bool hasHeader}) {
    return ChatMessage(
      // spinningLogo: spinningLogo,
      message: message,
      // goToReply: goToReply,
      repliesInfo: repliesInfo,
      mediaInfo: mediaInfo,
      textInfo: textInfo,
      // videoController: videoController,
      isPost: isPost,
      myMessage: myMessage,
      hasGap: hasGap,
      hasHeader: hasHeader,
      select: select,
      selected: selected,
    );
  }

  ChatMessage invertedSelection() {
    return ChatMessage(
      // spinningLogo: spinningLogo,
      message: message,
      // goToReply: goToReply,
      isPost: isPost,
      repliesInfo: repliesInfo,
      mediaInfo: mediaInfo,
      textInfo: textInfo,
      // videoController: videoController,
      hasHeader: hasHeader,
      myMessage: myMessage,
      hasGap: hasGap,
      select: select,
      selected: !selected,
    );
  }

  ChatMessage onPageTransition() {
    if (mediaInfo?.videoController?.value.isPlaying ?? false) {
      return ChatMessage(
        // spinningLogo: spinningLogo,
        message: message,
        // goToReply: goToReply,
        isPost: isPost,
        // videoController: videoController
        // ?..pause()
        // ..seekTo(Duration.zero),
        repliesInfo: repliesInfo,
        mediaInfo: mediaInfo
          ?..videoController?.pause()
          ..videoController?.seekTo(Duration.zero),
        textInfo: textInfo,
        hasHeader: hasHeader,
        myMessage: myMessage,
        hasGap: hasGap,
        select: select,
        selected: selected,
      );
    } else {
      return this;
    }
  }

  static TextStyle get textStyle => const TextStyle(fontFamily: "Alice");

  static TextStyle get dateStyle =>
      const TextStyle(fontFamily: "Alice", fontSize: 10);

  static double get maxMessageWidth => Sizes.w * 0.76;

  static double get textPadding => 12.0;

  static double get messageBorder => 4.0;

  static double get maxTextWidth =>
      maxMessageWidth - textPadding - messageBorder;

  bool get hasText => textInfo != null;

  bool get hasMedia => mediaInfo != null;

  static String timeString(Message message) {
    final ts = DateTime.fromMillisecondsSinceEpoch(message.timestamp).toLocal();
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

  static ChatTextInfo? generateTextInfo(Message message) {
    if (message.text?.isEmpty ?? true) return null;
    print("GENERATING TEXT INFO");

    List<String>? specialDisplayText;
    double neededWidth;
    bool lastStringAndDateOnSameLine = false;
    double heightIfNotOnSameLine = 0.0;
    double oneLineTextHeight = 0.0;

    specialDisplayText = [];
    neededWidth = 0.0;

    final text = message.text!;
    final transform1 = text.split("\n");
    final transform2 = transform1.join(" \n ");

    final words = transform2.split(" ")..add(timeString(message));
    var previousString = "";

    // pervious string should always be < max
    for (final word in words) {
      if (word == words.last) {
        double dateWidth;
        double prevWidth = 0;
        String dateString = "      $word";
        final timeTp = TextPainter(
          text: TextSpan(text: dateString, style: ChatMessage.dateStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        dateWidth = timeTp.width;
        if (previousString.isNotEmpty) {
          final prevTp = TextPainter(
            text: TextSpan(text: previousString, style: ChatMessage.textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          prevWidth = prevTp.width;
        }
        specialDisplayText.add(previousString);
        specialDisplayText.add(dateString);
        if (dateWidth + prevWidth > ChatMessage.maxTextWidth) {
          // in this case, prevString + date is too wide
          if (prevWidth > neededWidth) neededWidth = prevWidth;
          lastStringAndDateOnSameLine = false;
          heightIfNotOnSameLine = timeTp.height;
        } else {
          if (prevWidth + dateWidth > neededWidth) {
            neededWidth = prevWidth + dateWidth;
          }
          lastStringAndDateOnSameLine = true;
        }
      } else if (word == "\n") {
        specialDisplayText.add(previousString);
        final specialTp = TextPainter(
          text: TextSpan(text: previousString, style: ChatMessage.textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        if (specialTp.width > neededWidth) {
          neededWidth = specialTp.width;
        }
        previousString = "";
      } else if (word.isNotEmpty) {
        final wordTp = TextPainter(
          text: TextSpan(text: word, style: ChatMessage.textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        var wordLen = wordTp.width;
        var words = [word];
        while (wordLen > ChatMessage.maxTextWidth) {
          final splitLen = (words.first.length / 2).ceil();
          words = words
              .map((w) => [w.substring(0, splitLen), w.substring(splitLen)])
              .expand((element) => element)
              .toList();
          wordLen = words
              .map((w) => TextPainter(
                  text: TextSpan(text: w, style: ChatMessage.textStyle),
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
          if (wordLen > neededWidth) neededWidth = wordLen;
          previousString = "";
        } else {
          final currentString =
              previousString.isEmpty ? word : "$previousString $word";

          final previousTp = TextPainter(
            text: TextSpan(text: previousString, style: ChatMessage.textStyle),
            textDirection: TextDirection.ltr,
          )..layout();

          final currentTp = TextPainter(
            text: TextSpan(text: currentString, style: ChatMessage.textStyle),
            textDirection: TextDirection.ltr,
          )..layout();

          oneLineTextHeight = currentTp.height;

          // if the current text is larger than the available width
          if (currentTp.width >= ChatMessage.maxTextWidth) {
            // we add the previousString to the list of display text
            specialDisplayText.add(previousString);
            // if the previous layout is bigger than our current biggest width,
            // it because the new biggest width
            if (previousTp.width > neededWidth) {
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

    return ChatTextInfo(
      specialDisplayTexts: specialDisplayText,
      heightIfNotOnSameLine: heightIfNotOnSameLine,
      lastStringOnSameLine: lastStringAndDateOnSameLine,
      neededWidth: neededWidth,
      singleLineHeight: oneLineTextHeight,
    );
    //   specialDisplayText,
    //   neededWidth,
    //   oneLineTextHeight,
    //   heightIfNotOnSameLine,
    //   lastStringAndDateOnSameLine,
    // ];
  }

  static ChatMediaInfo? generateMediaInfo(Message message) {
    if (message.mediaID == null) return null;
    print("GENERATING MEDIA INFO");
    double mediaHeight = 0;
    double mediaWidth = 0;
    MessageMedia? media = message.mediaID!.getLocalMessageMedia();
    if (media == null) return null;
    mediaWidth = ChatMessage.maxMessageWidth - ChatMessage.messageBorder;
    mediaHeight = mediaWidth *
        (media.metadata.isSquared ? 1.0 : media.metadata.elementAspectRatio);

    VideoPlayerController? vpc;
    if (media.isVideo) {
      vpc = VideoPlayerController.file(media.file!);
    }

    return ChatMediaInfo(
        media: media,
        precalculatedMediaSize: Size(mediaWidth, mediaHeight),
        videoController: vpc);
  }

  static List<ChatReplyInfo>? generateRepliesInfo(
      Message message, void Function(String) goToReply) {
    if (message.replies == null) return null;
    print("GENERATING REPLIES INFO");
    return message.replies!
        .map((replyID) {
          final replyMsg = replyID.getLocalMessage();
          if (replyMsg == null) return null;
          final String replyBody = replyMsg.text?.isNotEmpty ?? false
              ? replyMsg.text!
              : "&attachment";
          return ChatReplyInfo(
              onPressReply: () => goToReply.call(replyID),
              senderID: replyMsg.senderID,
              messageRefID: replyMsg.id,
              body: replyBody);
        })
        .whereType<ChatReplyInfo>()
        .toList(growable: false);
  }

  static bool displayGap(Message msg, Message prevMsg) {
    final prevMsgTS = DateTime.fromMillisecondsSinceEpoch(prevMsg.timestamp);
    final curMsgTS = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
    if (curMsgTS.difference(prevMsgTS).inMinutes > 20) {
      return true;
    } else {
      return false;
    }
  }

  Widget reply(ChatReplyInfo replyData) {
    return Container(
      height: ChatMessage.headerHeight,
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6),
      child: GestureDetector(
        onTap: replyData.onPressReply,
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            Container(
              width: 2,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(6.0)),
                color: Colors.black54,
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                // color: PinkTheme.nodeColors[replyData.type],
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  replyData.senderID,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                replyData.body,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),

            // SizedBox(
            //   height: ChatMessage.headerHeight,
            //   width: ChatMessage.headerHeight,
            //   child: replyData.thumbnail,
            // ),
          ],
        ),
      ),
    );
  }

  Widget? get replies {
    final ri = repliesInfo;
    if (ri == null) return null;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4.0))),
      child: Column(
        textDirection: TextDirection.ltr,
        children: ri.map((r) => reply(r)).toList(),
      ),
    );
  }

  Widget? get header2 {
    if (!hasHeader) return null;
    return SizedBox(
        height: headerHeight,
        child: Row(children: [
          const Spacer(),
          Text(
            "-${message.senderID}   ",
            style: const TextStyle(color: PinkTheme.qrColor, fontSize: 13),
          ),
          // const Spacer(),
        ]));
  }

  Widget? get media {
    final mi = mediaInfo;
    if (mi == null) return null;
    Widget mediaBody({required Widget child}) {
      return GestureDetector(
          onTap: () => select?.call(message.id),
          child: Container(
              clipBehavior: Clip.hardEdge,
              height: mi.precalculatedMediaSize.height,
              width: mi.precalculatedMediaSize.width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(4),
                    bottom: Radius.circular(textInfo != null ? 0 : 4)),
              ),
              child: child));
    }

    // Future<void> generateThumbnail() async {
    //   print("MEDIA THUMBNAIL IS NULL, GENERATING IT!");
    //   final thumbnail = await VideoThumbnail.thumbnailFile(
    //       video: mi.media.hasFile ? mi.media.path : mi.media.url, quality: 95);
    //   mi.media.thumbnail = thumbnail;
    //   mi.media.save();
    // }

    Widget theMedia() {
      if (mi.media.isVideo) {
        // if (mi.media.thumbnail == null) {
        //   return FutureBuilder(
        //     future: generateThumbnail(),
        //     builder: (context, snapshot) {
        //       if (snapshot.connectionState == ConnectionState.done) {
        //         return Down4VideoPlayer(
        //             videoController: mi.videoController!,
        //             rotatingLogo: spinningLogo,
        //             backgroundColor: myMessage
        //                 ? PinkTheme.myBubblesColor
        //                 : PinkTheme.buttonColor,
        //             media: mi.media,
        //             autoPlay: false,
        //             displaySize: mi.precalculatedMediaSize);
        //       } else {
        //         return Container(
        //             color: myMessage
        //                 ? PinkTheme.myBubblesColor
        //                 : PinkTheme.buttonColor,
        //             child: Center(
        //                 child: spinningLogo(
        //                     mi.precalculatedMediaSize.aspectRatio > 1
        //                         ? mi.precalculatedMediaSize.height
        //                         : mi.precalculatedMediaSize.width)));
        //       }
        //     },
        //   );
        // } else {
        return Down4VideoPlayer(
            // rotatingLogo: spinningLogo,
            videoController: mi.videoController!
            // ? VideoPlayerController.file(mi.media.file!)
            // : VideoPlayerController.network(mi.media.url)
            ,
            backgroundColor:
                myMessage ? PinkTheme.myBubblesColor : PinkTheme.buttonColor,
            media: mi.media,
            autoPlay: false,
            displaySize: mi.precalculatedMediaSize);
        // }
      } else {
        return Down4ImageViewer(
            media: mi.media, displaySize: mi.precalculatedMediaSize);
      }
    }

    return mediaBody(child: theMedia());

    // return GestureDetector(
    //   onTap: () => select?.call(message.id),
    //   child: Container(
    //     clipBehavior: Clip.hardEdge,
    //     height: mi.precalculatedMediaSize.height,
    //     width: mi.precalculatedMediaSize.width,
    //     decoration: BoxDecoration(
    //       borderRadius: BorderRadius.vertical(
    //           top: const Radius.circular(4),
    //           bottom: Radius.circular(_textInfo != null ? 0 : 4)),
    //     ),
    //     child: mi.media.isVideo
    //         ? Down4VideoPlayer(
    //             media: mi.media,
    //             autoPlay: false,
    //             displaySize: mi.precalculatedMediaSize,
    //             backgroundColor: myMessage
    //                 ? PinkTheme.myBubblesColor
    //                 : PinkTheme.buttonColor)
    //         : Down4ImageViewer(
    //             media: mi.media,
    //             displaySize: mi.precalculatedMediaSize,
    //           ),
    //   ),
    // );
  }

  Widget? get text {
    final ti = textInfo;
    if (ti == null) return null;
    final dateText = ti.specialDisplayTexts.last;
    final nSpecialText = ti.specialDisplayTexts.length;
    final beforeLast = ti.specialDisplayTexts[nSpecialText - 2];
    final texts = ti.specialDisplayTexts.sublist(0, nSpecialText - 1);
    return GestureDetector(
      onTap: () => select?.call(message.id),
      child: Container(
        // alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.all(6.0),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: myMessage ? PinkTheme.myBubblesColor : PinkTheme.bodyColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(mediaInfo != null ? 0 : 4),
              bottom: const Radius.circular(4),
            )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: texts
              .map(
                (str) => str != beforeLast
                    ? Text(str, maxLines: 1)
                    : ti.lastStringOnSameLine
                        ? Row(
                            textDirection: TextDirection.ltr,
                            children: [
                              Text(str, maxLines: 1),
                              const Spacer(),
                              Text(
                                dateText,
                                maxLines: 1,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.black54),
                              )
                            ],
                          )
                        : Column(
                            textDirection: TextDirection.ltr,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(str, maxLines: 1),
                              Row(
                                children: [
                                  const Spacer(),
                                  Text(
                                    dateText,
                                    maxLines: 1,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black54),
                                  )
                                ],
                              ),
                            ],
                          ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget animatedContainer({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      clipBehavior: Clip.hardEdge,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(6.0)),
          boxShadow: [
            BoxShadow(
              color: !selected ? Colors.black54 : Colors.transparent,
              blurRadius: !selected ? 4.0 : 0.0,
              spreadRadius: -6.0,
              offset:
                  !selected ? const Offset(5.0, 5.0) : const Offset(0.0, 0.0),
              blurStyle: BlurStyle.normal,
            ),
          ]),
      child: child,
    );
  }

  Size get chatMessageSize {
    final headerSize = hasHeader ? headerHeight : 0;
    final repliesHeight = (repliesInfo?.length ?? 0) * headerHeight;
    final nLines = hasText ? textInfo!.specialDisplayTexts.length - 1 : 0;

    var messageHeight = (mediaInfo?.precalculatedMediaSize.height ?? 0) +
        messageBorder +
        headerSize +
        repliesHeight;

    messageHeight += hasText
        ? (nLines * textInfo!.singleLineHeight) +
            textPadding +
            textInfo!.heightIfNotOnSameLine
        : 0;

    final messageWidth = mediaInfo != null
        ? maxMessageWidth
        : hasText
            ? textInfo!.neededWidth + textPadding + messageBorder
            : 0.0; // TODO, will be forwarding nodes, or messages

    return Size(messageWidth, messageHeight);
  }

  Widget get chatMessage {
    return Align(
      alignment: isPost
          ? Alignment.bottomCenter
          : myMessage
              ? Alignment.bottomRight
              : Alignment.bottomLeft,
      child: Container(
          margin: const EdgeInsets.only(left: 22.0, right: 22.0),
          height: chatMessageSize.height,
          width: chatMessageSize.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              replies ?? const SizedBox.shrink(),
              animatedContainer(
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(6.0)),
                      border: Border.all(
                        width: 2.0,
                        color: selected ? Colors.black : Colors.transparent,
                      )),
                  child: Column(
                    textDirection: TextDirection.ltr,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      media ?? const SizedBox.shrink(),
                      text ?? const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
              header2 ?? const SizedBox.shrink(),
            ],
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      hasGap ? const SizedBox(height: 20) : const SizedBox.shrink(),
      chatMessage,
      const SizedBox(height: 4),
    ]);
  }
}
