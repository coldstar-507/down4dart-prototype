import 'dart:math' show max;
import 'dart:typed_data' show Uint8List;

import 'package:down4/src/render_objects/qr.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../_down4_dart_utils.dart' show Pair, golden;

import '../data_objects.dart';
import '../globals.dart';
import '../themes.dart';
import '../web_requests.dart' show getNodes;

import '_down4_flutter_utils.dart';
import 'palette.dart' show Palette;

class ChatReplyInfo {
  final ID messageRefID, senderID; // senderName,
  final String body;
  final void Function() onPressReply;
  const ChatReplyInfo({
    required this.onPressReply,
    required this.senderID,
    required this.messageRefID,
    required this.body,
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

class ChatMessage extends StatelessWidget implements Down4Object {
  @override
  ID get id => message.id;

  static const double headerHeight = 18.0;
  final bool myMessage, selected, isPost;
  final void Function(ID id)? select;
  final Message message;
  final bool hasGap, hasHeader;
  final void Function(BaseNode) openNode;

  final ChatMediaInfo? mediaInfo;
  final List<ChatReplyInfo>? repliesInfo;

  const ChatMessage({
    required this.hasHeader,
    required this.message,
    required this.myMessage,
    required this.hasGap,
    required this.mediaInfo,
    required this.openNode,
    // required this.textInfo,
    required this.repliesInfo,
    this.isPost = false,
    this.selected = false,
    required this.select,
    Key? key,
  }) : super(key: key);

  ChatMessage withHeader({required bool hasHeader}) {
    return ChatMessage(
      message: message,
      repliesInfo: repliesInfo,
      mediaInfo: mediaInfo,
      openNode: openNode,
      // textInfo: textInfo,
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
      message: message,
      isPost: isPost,
      repliesInfo: repliesInfo,
      mediaInfo: mediaInfo,
      openNode: openNode,
      // textInfo: textInfo,
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
        message: message,
        isPost: isPost,
        repliesInfo: repliesInfo,
        mediaInfo: mediaInfo
          ?..videoController?.pause()
          ..videoController?.seekTo(Duration.zero),
        // textInfo: textInfo,
        openNode: openNode,
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

  static TextStyle get textStyle =>
      const TextStyle(fontFamily: "Alice", color: Colors.black);

  static TextStyle get globalDateStyle => const TextStyle(
      fontFamily: "Alice", fontSize: 10, color: Colors.black45, height: 0.8);

  static double get maxMessageWidth => g.sizes.w * 0.76;

  static double get textPadding => 12.0;

  static double get messageBorder => 4.0;

  static double get maxTextWidth =>
      maxMessageWidth - textPadding - messageBorder;

  Color get messageColor =>
      myMessage ? PinkTheme.myBubblesColor : PinkTheme.buttonColor;

  Down4TextBubble? get bubble => !hasText
      ? null
      : Down4TextBubble(
          text: message.text!,
          dateText: timeString(message),
          inheritedWidth: hasMedia ? maxTextWidth : null);

  double? get bubbleWidth => !hasText ? null : bubble!.calcWidth + textPadding;

  bool get hasText => (message.text ?? "").isNotEmpty; // textInfo != null;

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

    if (message.forwarderID == null) {
      return "    $timeStr";
    } else {
      return "${message.forwarderID}    $timeStr";
    }
  }

  static Future<ChatMediaInfo?> generateMediaInfo(Message message) async {
    if (message.mediaID == null) return null;
    // print("GENERATING MEDIA INFO");
    double mediaHeight = 0;
    double mediaWidth = 0;
    MessageMedia? media = await message.mediaID!.getLocalMessageMedia();
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

  static Future<List<ChatReplyInfo>?> generateRepliesInfo(
      Message message, void Function(String) goToReply) async {
    if (message.replies == null) return null;
    List<ChatReplyInfo> chatReplies = [];
    for (final replyID in message.replies!) {
      final reply = await replyID.getLocalMessage();
      if (reply == null) continue;
      final String replyBody =
          reply.text?.isNotEmpty ?? false ? reply.text! : "&attachment";

      final info = ChatReplyInfo(
          onPressReply: () => goToReply.call(replyID),
          senderID: reply.senderID,
          messageRefID: reply.id,
          body: replyBody);

      chatReplies.add(info);
    }

    return chatReplies;

    // print("GENERATING REPLIES INFO");
    // return message.replies!
    //     .map((replyID) async {
    //       final replyMsg = await replyID.getLocalMessage();
    //       if (replyMsg == null) return null;
    //       final String replyBody = replyMsg.text?.isNotEmpty ?? false
    //           ? replyMsg.text!
    //           : "&attachment";
    //       return ChatReplyInfo(
    //           onPressReply: () => goToReply.call(replyID),
    //           senderID: replyMsg.senderID,
    //           messageRefID: replyMsg.id,
    //           body: replyBody);
    //     })
    //     .whereType<ChatReplyInfo>()
    //     .toList(growable: false);
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
              flex: 3,
              child: Text(
                replyData.body,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              // const Spacer(),
            ),
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
        height: headerHeight * 0.8,
        child: Row(children: [
          const Spacer(),
          Text(
            "-${message.senderID}   ",
            style: const TextStyle(color: PinkTheme.qrColor, fontSize: 13),
          ),
        ]));
  }

  Widget? get forwarderHeader {
    if (message.forwarderID == null) return null;
    return SizedBox(
        height: headerHeight * 0.8,
        child: Row(children: [
          Text(
            ">>${message.forwarderID}   ",
            style: const TextStyle(color: PinkTheme.qrColor, fontSize: 13),
          ),
        ]));
  }

  Widget? get messagePalettes {
    if ((message.nodes ?? []).isEmpty) return null;
    double mpHeight() => Palette.paletteHeight / golden;
    Widget unloadedPalette(ID id) {
      return Container(
        height: mpHeight(),
        color: Colors.black54,
        child: Row(
          children: [
            Image.asset("assets/images/down4_inverted.png",
                cacheHeight: (mpHeight() * 2).toInt(),
                cacheWidth: (mpHeight() * 2).toInt()),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(top: 12.0, left: 12.0),
                    child: Text(id)))
          ],
        ),
      );
    }

    Widget loadedPalette(BaseNode node) {
      Image nodeImage() => node.media?.data != null
          ? Image.memory(node.media!.data,
              cacheHeight: (mpHeight() * 2).toInt(),
              cacheWidth: (mpHeight() * 2).toInt())
          : Image.asset("assets/images/hashirama.jpg",
              cacheHeight: (mpHeight() * 2).toInt(),
              cacheWidth: (mpHeight() * 2).toInt());

      return Container(
        height: mpHeight(),
        color: PinkTheme.nodeColors[node.colorCode],
        child: Row(
          children: [
            nodeImage(),
            Expanded(
                child: Column(children: [
              Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(node.name)),
              Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 12.0),
                  child: Text(node.displayID))
            ])),
            GestureDetector(
                onTap: () => openNode(node),
                child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                    child: Image.asset("assets/images/50.png",
                        cacheHeight: (mpHeight() * 2).toInt(),
                        cacheWidth: (mpHeight() * 2).toInt())))
          ],
        ),
      );
    }

    return FutureBuilder(
      future: getNodesFromEverywhere(message.nodes!.toSet()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ClipRect(
            child: Column(
              children:
                  message.nodes!.map((id) => unloadedPalette(id)).toList(),
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return ClipRect(
            child: Column(
              children: snapshot.requireData
                  .map((node) => loadedPalette(node))
                  .toList(),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
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
                color: messageColor,
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(4),
                    bottom: Radius.circular(hasText ? 0 : 4)),
              ),
              child: child));
    }

    Widget theMedia() {
      if (mi.media.isVideo) {
        return Down4VideoPlayer(
            videoController: mi.videoController!,
            backgroundColor:
                myMessage ? PinkTheme.myBubblesColor : PinkTheme.buttonColor,
            media: mi.media,
            autoPlay: false,
            displaySize: mi.precalculatedMediaSize);
      } else {
        return Down4ImageViewer(
            media: mi.media, displaySize: mi.precalculatedMediaSize);
      }
    }

    return mediaBody(child: theMedia());
  }

  Widget? get text {
    if (!hasText) return null;
    return GestureDetector(
        onTap: () => select?.call(message.id),
        child: Container(
            padding: const EdgeInsets.all(6.0),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
                color:
                    myMessage ? PinkTheme.myBubblesColor : PinkTheme.bodyColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(mediaInfo != null ? 0 : 4),
                  bottom: const Radius.circular(4),
                )),
            child: bubble));
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

  Widget get chatMessage {
    return Container(
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      constraints: BoxConstraints(maxWidth: bubbleWidth ?? maxMessageWidth),
      child: Column(
        crossAxisAlignment:
            myMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          forwarderHeader ?? replies ?? const SizedBox.shrink(),
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
                      children: [
                        media ?? const SizedBox.shrink(),
                        text ?? const SizedBox.shrink(),
                        messagePalettes ?? const SizedBox.shrink()
                      ]))),
          header2 ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          myMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        hasGap ? const SizedBox(height: 20) : const SizedBox.shrink(),
        chatMessage,
        const SizedBox(height: 4),
      ],
    );
  }
}
