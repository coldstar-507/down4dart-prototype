import 'package:flutter/material.dart';
import 'package:down4/src/couch.dart';
import 'package:video_player/video_player.dart';
import '../_dart_utils.dart' show Pair, golden;

import '../data_objects.dart';
import '../globals.dart';
import '../themes.dart';

import '_render_utils.dart';
import 'palette.dart' show Palette, Palette2;

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
  final FireMedia media;
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
  final ID nodeRef;
  final bool myMessage, selected, isPost;
  final void Function(ID id)? select;
  final FireMessage message;
  final bool hasGap, hasHeader;
  final void Function(FireNode)? openNode;

  final ChatMediaInfo? mediaInfo;
  final List<ChatReplyInfo>? repliesInfo;
  final List<FireNode>? nodes;

  bool get videoIsPlaying =>
      mediaInfo?.videoController?.value.isPlaying ?? false;

  const ChatMessage({
    required this.nodeRef,
    required this.nodes,
    required this.hasHeader,
    required this.message,
    required this.myMessage,
    required this.hasGap,
    required this.mediaInfo,
    required this.openNode,
    required this.repliesInfo,
    this.isPost = false,
    this.selected = false,
    required this.select,
    Key? key,
  }) : super(key: key);

  ChatMessage withOpenNode({
    required void Function(FireNode)? open,
  }) {
    return ChatMessage(
        message: message,
        repliesInfo: repliesInfo,
        nodeRef: nodeRef,
        mediaInfo: mediaInfo,
        openNode: open,
        nodes: nodes,
        isPost: isPost,
        myMessage: myMessage,
        hasGap: hasGap,
        hasHeader: hasHeader,
        select: select,
        selected: selected);
  }

  ChatMessage withHeader({required bool hasHeader}) {
    return ChatMessage(
      message: message,
      repliesInfo: repliesInfo,
      mediaInfo: mediaInfo,
      openNode: openNode,
      nodes: nodes,
      nodeRef: nodeRef,
      isPost: isPost,
      myMessage: myMessage,
      hasGap: hasGap,
      hasHeader: hasHeader,
      select: select,
      selected: selected,
    );
  }

  ChatMessage reloaded(FireMessage msg) {
    return ChatMessage(
      message: msg,
      isPost: isPost,
      nodeRef: nodeRef,
      repliesInfo: repliesInfo,
      nodes: nodes,
      mediaInfo: mediaInfo,
      openNode: openNode,
      hasHeader: hasHeader,
      myMessage: myMessage,
      hasGap: hasGap,
      select: select,
      selected: selected,
    );
  }

  ChatMessage withNodes(List<FireNode>? pNodes) {
    return ChatMessage(
        message: message,
        repliesInfo: repliesInfo,
        nodeRef: nodeRef,
        mediaInfo: mediaInfo,
        openNode: openNode,
        nodes: pNodes,
        isPost: isPost,
        myMessage: myMessage,
        hasGap: hasGap,
        hasHeader: hasHeader,
        select: select,
        selected: selected);
  }

  ChatMessage invertedSelection() {
    return ChatMessage(
      message: message,
      isPost: isPost,
      nodeRef: nodeRef,
      repliesInfo: repliesInfo,
      nodes: nodes,
      mediaInfo: mediaInfo,
      openNode: openNode,
      hasHeader: hasHeader,
      myMessage: myMessage,
      hasGap: hasGap,
      select: select,
      selected: !selected,
    );
  }

  ChatMessage onPageTransition() {
    if (videoIsPlaying) {
      return ChatMessage(
        message: message,
        isPost: isPost,
        nodeRef: nodeRef,
        repliesInfo: repliesInfo,
        mediaInfo: mediaInfo
          ?..videoController?.pause()
          ..videoController?.seekTo(Duration.zero),
        nodes: nodes,
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

  static double get maxMessageWidth => g.sizes.w * 0.76;

  static double get textPadding => 12.0;

  static double get messageBorder => 4.0;

  static double get maxTextWidth =>
      maxMessageWidth - textPadding - messageBorder;

  Color get messageColor =>
      myMessage ? g.theme.myBubblesColor : g.theme.otherBubblesColor;

  Down4TextBubble? get bubble => !hasText
      ? null
      : Down4TextBubble(
          text: message.text!,
          dateText: timeString(message),
          inheritedWidth: hasMedia ? maxTextWidth : null);

  double get bodyHeight {
    final double bubbleHeight = bubble?.calcHeight ?? 0.0;
    final double mediaHeight = mediaInfo?.precalculatedMediaSize.height ?? 0.0;
    // final double repliesHeight = (repliesInfo?.length ?? 0.0) * headerHeight;
    final double palettesHeight = (nodes?.length ?? 0.0) * nodeHeight;
    if (bubbleHeight > 0) {
      return bubbleHeight + mediaHeight + palettesHeight + textPadding;
    } else {
      return mediaHeight + palettesHeight;
    }
  }

  double? get bubbleWidth => !hasText ? null : bubble!.calcWidth + textPadding;

  bool get hasText => (message.text ?? "").isNotEmpty; // textInfo != null;

  bool get hasMedia => mediaInfo != null;

  bool get hasPalettes => (nodes ?? []).isNotEmpty;

  static String timeString(FireMessage message) {
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

    return "    $timeStr";
  }

  static Future<ChatMediaInfo?> generateMediaInfo(FireMessage message) async {
    if (message.mediaID == null) return null;
    // print("GENERATING MEDIA INFO");
    double mediaHeight = 0;
    double mediaWidth = 0;
    final media = await global<FireMedia>(message.mediaID!);
    if (media == null) return null;
    mediaWidth = ChatMessage.maxMessageWidth - ChatMessage.messageBorder;
    mediaHeight = mediaWidth * (media.isSquared ? 1.0 : 1 / media.aspectRatio);

    VideoPlayerController? vpc;
    if (media.isVideo) {
      vpc = await media.videoController;
    }

    return ChatMediaInfo(
        media: media,
        precalculatedMediaSize: Size(mediaWidth, mediaHeight),
        videoController: vpc);
  }

  static Future<List<ChatReplyInfo>?> generateRepliesInfo(
      FireMessage message, void Function(String) goToReply) async {
    if (message.replies == null) return null;
    List<ChatReplyInfo> chatReplies = [];
    for (final replyID in message.replies!) {
      final reply = await global<FireMessage>(replyID);
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

  static bool displayGap(FireMessage msg, FireMessage prevMsg) {
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
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(6.0)),
                color: g.theme.chatRepilesTextStyle.color,
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                // color: PinkTheme.nodeColors[replyData.type],
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  replyData.senderID,
                  style: g.theme.chatRepilesTextStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                replyData.body,
                style: g.theme.chatRepilesTextStyle,
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
            style: TextStyle(color: g.theme.messageSenderColor, fontSize: 13),
          ),
        ]));
  }

  Widget? get forwarderHeader {
    if (message.forwardedFrom == null) return null;
    return SizedBox(
        height: headerHeight * 0.8,
        child: Row(children: [
          Text(
            "   >> ${message.forwardedFrom}",
            style: TextStyle(
              color: g.theme.messageForwarderColor,
              fontSize: 13,
            ),
          ),
        ]));
  }

  double get nodeHeight => Palette2.paletteHeight / golden;

  Widget? get messagePalettes {
    if (!hasPalettes && (message.nodes ?? {}).isEmpty) return null;
    Widget unloadedPalette(ID id) {
      return Container(
        key: GlobalKey(),
        height: nodeHeight,
        color: Colors.black54,
        child: Row(
          children: [
            Image.asset("assets/images/down4_inverted.png",
                cacheHeight: (nodeHeight * 2).toInt(),
                cacheWidth: (nodeHeight * 2).toInt()),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(top: 12.0, left: 12.0),
                    child: Text(id)))
          ],
        ),
      );
    }

    Widget loadedPalette(FireNode n) {
      return Container(
        key: GlobalKey(),
        height: nodeHeight,
        color: Colors.white10,
        // n.id == g.self.id
        //     ? g.theme.nodeColors[NodesColor.self]
        //     : g.theme.nodeColors[n.colorCode],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            n.nodeImage(Size.square(nodeHeight)),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(top: 6.0, left: 6.0),
                    child: Text(n.displayName,
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        style: TextStyle(color: g.theme.paletteTextColor)))),
            GestureDetector(
                onTap: () => openNode?.call(n),
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: openNode == null
                      ? const SizedBox.shrink()
                      : Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: g.theme.noMessageArrowColor,
                        ),
                )))
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => select?.call(message.id),
      child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(
                  top: (!hasMedia && !hasText
                      ? const Radius.circular(4.0)
                      : Radius.zero),
                  bottom: const Radius.circular(4.0))),
          child: Column(
              children: hasPalettes
                  ? nodes!.map((node) => loadedPalette(node)).toList()
                  : message.nodes!
                      .map((nodeID) => unloadedPalette(nodeID))
                      .toList())),
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
                    bottom: Radius.circular(hasText || hasPalettes ? 0 : 4)),
              ),
              child: child));
    }

    return mediaBody(
      child: mi.media.display(
        size: mi.precalculatedMediaSize,
        controller: mi.videoController,
      ),
    );
  }

  Widget? get text {
    if (!hasText) return null;
    return GestureDetector(
        onTap: () => select?.call(message.id),
        child: Container(
            padding: const EdgeInsets.all(6.0),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
                color: myMessage
                    ? g.theme.myBubblesColor
                    : g.theme.otherBubblesColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(hasMedia ? 0 : 4),
                  bottom: Radius.circular(hasPalettes ? 0 : 4),
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
              color: Colors.transparent,
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
                        color: selected
                            ? g.theme.messageSelectionBorderColor
                            : Colors.transparent,
                      )),
                  child: Stack(
                    children: [
                      Column(
                          textDirection: TextDirection.ltr,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            media ?? const SizedBox.shrink(),
                            text ?? const SizedBox.shrink(),
                            messagePalettes ?? const SizedBox.shrink()
                          ]),
                      // GestureDetector(
                      //   onTap: () => select?.call(message.id),
                      //   child: SizedBox(
                      //     width: bubbleWidth ?? maxMessageWidth,
                      //     height: bodyHeight,
                      //     child: Container(
                      //       color: selected
                      //           ? g.theme.messageSelectionOverlayColor
                      //           : Colors.transparent,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ))),
          header2 ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  double get messageOpacity {
    if (nodeRef == g.self.id) {
      // saved message are always sent
      return 1;
    } else if (message.senderID != g.self.id) {
      // if the sender is not us, it's always sent (received)
      return 1;
    } else if (message.isSent) {
      // else we check the sent status
      return 1;
    } else {
      // if it's not sent yet, usually takes less than a sec, message has
      // some transparancy
      return .75;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: messageOpacity,
      child: Column(
        crossAxisAlignment:
            myMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          hasGap ? const SizedBox(height: 20) : const SizedBox.shrink(),
          chatMessage,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
