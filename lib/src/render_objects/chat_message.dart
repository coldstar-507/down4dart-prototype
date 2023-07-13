import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../_dart_utils.dart' show Pair, golden;

import '../data_objects/couch.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../data_objects/messages.dart';
import '../data_objects/nodes.dart';
import '../globals.dart';

import '_render_utils.dart';
import 'palette.dart' show Palette, Palette2;

class ChatReplyInfo {
  final Down4ID messageRefID;
  final ComposedID senderID; // senderName,
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
  final Down4Media media;
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
  Down4ID get id => message.id;

  static const double headerHeight = 18.0;
  final ComposedID nodeRef;
  final bool myMessage, selected, isPost;
  final void Function(Down4ID id)? select;
  final Chat message;
  final bool hasGap, hasHeader;
  final void Function(Down4Node)? openNode;

  final ChatMediaInfo? mediaInfo;
  final List<ChatReplyInfo>? repliesInfo;
  final List<Down4Node>? nodes;

  List<Reaction> get reactions => message.reactions.values.toList();

  final Future<void> Function(Chat message) react;

  final Future<void> Function(Chat, Down4ID) increment;

  bool get videoIsPlaying =>
      mediaInfo?.videoController?.value.isPlaying ?? false;

  bool get hasReactions => (reactions ?? []).isNotEmpty;

  const ChatMessage({
    required this.increment,
    required this.react,
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
    required void Function(Down4Node)? open,
  }) {
    return ChatMessage(
      message: message,
      repliesInfo: repliesInfo,
      nodeRef: nodeRef,
      mediaInfo: mediaInfo,
      react: react,
      increment: increment,
      openNode: open,
      nodes: nodes,
      isPost: isPost,
      myMessage: myMessage,
      hasGap: hasGap,
      hasHeader: hasHeader,
      select: select,
      selected: selected,
    );
  }

  ChatMessage withHeader({required bool hasHeader}) {
    return ChatMessage(
      message: message,
      repliesInfo: repliesInfo,
      mediaInfo: mediaInfo,
      openNode: openNode,
      react: react,
      increment: increment,
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

  ChatMessage reloaded(Chat msg) {
    return ChatMessage(
      message: msg,
      isPost: isPost,
      nodeRef: nodeRef,
      repliesInfo: repliesInfo,
      nodes: nodes,
      increment: increment,
      react: react,
      mediaInfo: mediaInfo,
      openNode: openNode,
      hasHeader: hasHeader,
      myMessage: myMessage,
      hasGap: hasGap,
      select: select,
      selected: selected,
    );
  }

  ChatMessage withNodes(List<Down4Node>? pNodes) {
    return ChatMessage(
      message: message,
      repliesInfo: repliesInfo,
      nodeRef: nodeRef,
      mediaInfo: mediaInfo,
      openNode: openNode,
      react: react,
      increment: increment,
      nodes: pNodes,
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
      nodeRef: nodeRef,
      repliesInfo: repliesInfo,
      react: react,
      nodes: nodes,
      increment: increment,
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
        react: react,
        increment: increment,
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

  static double get maxMessageWidth => g.sizes.w * 0.8;

  static double get textPadding => 9.0;

  // static double get messageBorder => 4.0;

  static double get maxTextWidth =>
      maxMessageWidth - (2 * textPadding) - lateralBorderWidth;

  Color get messageColor =>
      myMessage ? g.theme.myBubblesColor : g.theme.otherBubblesColor;

  Down4TextBubble? get bubble => !hasText
      ? null
      : Down4TextBubble(
          text: message.text!,
          dateText: timeString(message),
          inheritedWidth: hasMedia ? maxTextWidth : null);

  static double get smallestBubbleHeight =>
      Down4TextBubble(text: " ", dateText: " ", inheritedWidth: null)
          .calcHeight;

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

  double? get bubbleWidth =>
      !hasText ? null : bubble!.calcWidth + (2 * textPadding);

  bool get hasText => (message.text ?? "").isNotEmpty; // textInfo != null;

  bool get hasMedia => mediaInfo != null;

  bool get hasPalettes => (nodes ?? []).isNotEmpty;

  static String timeString(Chat message) {
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

  static Future<ChatMediaInfo?> generateMediaInfo(Chat message) async {
    if (message.mediaID == null) return null;
    // print("GENERATING MEDIA INFO");
    double mediaHeight = 0;
    double mediaWidth = 0;
    final media = await global<Down4Media>(message.mediaID!,
        doFetch: true, doMergeIfFetch: true, tempID: message.tempMediaID);
    if (media == null) return null;
    if (message.tempMediaID != null) {
      await media.updateTempReferences(
          message.tempMediaID!, message.tempMediaTS!);
    }

    mediaWidth = maxMessageWidth - (bodyBorderWidth * 2);
    mediaHeight = mediaWidth * (media.isSquared ? 1.0 : 1 / media.aspectRatio);

    VideoPlayerController? vpc;
    if (media is Down4Video) {
      vpc = (media.newReadyController()) ?? (await media.futureController());
    }

    return ChatMediaInfo(
        media: media,
        precalculatedMediaSize: Size(mediaWidth, mediaHeight),
        videoController: vpc);
  }

  static Future<List<ChatReplyInfo>?> generateRepliesInfo(
      Chat message, void Function(Down4ID) goToReply) async {
    if (message.replies == null) return null;
    List<ChatReplyInfo> chatReplies = [];
    for (final replyID in message.replies!) {
      final reply = await global<Chat>(replyID);
      if (reply == null) continue;

      final info = ChatReplyInfo(
          onPressReply: () => goToReply.call(replyID),
          senderID: reply.senderID,
          messageRefID: reply.id,
          body: reply.messagePreview);

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

  static bool displayGap(Chat msg, Chat prevMsg) {
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
                  replyData.senderID.unique,
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
          Text("-${message.senderID}   ",
              style: g.theme.messageSenderTextStyle),
        ]));
  }

  Widget? get forwarderHeader {
    if (message.forwardedFromID == null) return null;
    return SizedBox(
        height: headerHeight * 0.8,
        child: Row(children: [
          Text(
            "   >> ${message.forwardedFromID}",
            style: g.theme.messageForwarderTextStyle,
          ),
        ]));
  }

  double get nodeHeight => Palette2.paletteHeight / golden;

  Widget? get messagePalettes {
    if (!hasPalettes && (message.nodes ?? {}).isEmpty) return null;
    Widget unloadedPalette(Down4ID id) {
      return Container(
        key: GlobalKey(),
        height: nodeHeight,
        color: Colors.black54,
        child: Row(
          children: [
            g.theme.down4Icon(g.theme.down4IconForPaletteColor),
            // Image.asset("assets/images/down4_inverted.png",
            //     cacheHeight: (nodeHeight * 2).toInt(),
            //     cacheWidth: (nodeHeight * 2).toInt()),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(top: 12.0, left: 12.0),
                    child: Text(id.unique)))
          ],
        ),
      );
    }

    Widget loadedPalette(Down4Node n) {
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
      onLongPress: () => react(message),
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
          onLongPress: () => react(message),
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
        forceSquare: mi.media.isSquared,
        controller: mi.videoController,
      ),
    );
  }

  Widget? get text {
    if (!hasText) return null;
    return GestureDetector(
        onTap: () => select?.call(message.id),
        onLongPress: () => react(message),
        child: Container(
            padding: EdgeInsets.all(textPadding),
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

  double get reactionWidth => smallestReactionSize;

  static double get bodyBorderWidth => 2.0;

  static double get lateralBorderWidth => bodyBorderWidth * 2;

  static double get messageMargin => 12.0;

  double get widthForReactions =>
      (g.sizes.w - messageWidth - (messageMargin * 2) - lateralBorderWidth);

  double get heightForReaction => bodyHeight + lateralBorderWidth;

  bool get hasMoreHeightForReactions => heightForReaction > widthForReactions;

  double get sizeForReactions => max(heightForReaction, widthForReactions);

  double get messageWidth =>
      hasMedia ? maxMessageWidth : bubbleWidth ?? maxMessageWidth;

  double get smallestReactionSize =>
      smallestBubbleHeight + lateralBorderWidth + (2 * textPadding);

  int get nReactions => reactions?.length ?? 0;

  int get maxReactionForThisMessage {
    int nReaction = 0;
    while (sizeForReactions / (nReaction * reactionWidth) >= 1) {
      nReaction++;
    }
    return min(nReaction - 1, nReactions);
  }

  Widget? reaction(Reaction r) {
    final media = cache<Down4Media>(r.mediaID);

    if (media == null) return null;

    // TextStyle style() => TextStyle(
    //     fontSize: 10,
    //     fontFamily: g.theme.font,
    //     color: Colors.white,
    //     fontWeight: FontWeight.bold);

    final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
            text: r.reactors.length.toString(),
            style: g.theme.chatReactionCounterTextStyle))
      ..layout();
    final maxi = max(tp.height, tp.width);

    return SizedBox.square(
      dimension: reactionWidth,
      child: Stack(
        children: [
          Padding(
            // width: reactionWidth,
            // height: reactionWidth,
            padding: const EdgeInsets.all(2),
            child: GestureDetector(
              onTap: () => increment(message, r.id),
              child: Container(
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(4)),
                clipBehavior: Clip.hardEdge,
                child: media.display(
                  forceSquare: true,
                  size: Size.square(reactionWidth),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: maxi,
              height: maxi,
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(
                  color: g.theme.chatReactionCounterColor,
                  borderRadius: BorderRadius.all(Radius.circular(maxi / 2))),
              child: Text(
                r.reactors.length.toString(),
                style: g.theme.chatReactionCounterTextStyle,
                softWrap: false,
              ),
            ),
          )
        ],
      ),
    );

    // return SizedBox.square(
    //   dimension: rad * 2,
    //   child: Stack(
    //     children: [
    //       Container(
    //         // width: rad * 2,
    //         // height: rad * 2,
    //         decoration: BoxDecoration(
    //             borderRadius: BorderRadius.circular(rad), color: messageColor),
    //         clipBehavior: Clip.hardEdge,
    //         child: Center(
    //           child: Container(
    //             width: (rad - messageBorder) * 2,
    //             height: (rad - messageBorder) * 2,
    //             decoration: BoxDecoration(
    //                 borderRadius: BorderRadius.circular(rad - messageBorder)),
    //             clipBehavior: Clip.hardEdge,
    //             child: media.displayImage(
    //               forceSquare: true,
    //               size: Size.square((rad - messageBorder) * 2),
    //             ),
    //           ),
    //         ),
    //       ),
    //       Positioned(
    //         bottom: 0,
    //         right: 0,
    //         child: Text(
    //           r.reactionCount.toString(),
    //           style: g.theme.inputTextStyle,
    //           softWrap: false,
    //         ),
    //       )
    //     ],
    //   ),
    // );
  }

  Widget get chatMessage {
    return Container(
      margin: EdgeInsets.only(
          left: myMessage ? 0 : messageMargin,
          right: myMessage ? messageMargin : 0),
      // constraints: BoxConstraints(maxWidth: messageWidth),
      child: Column(
        crossAxisAlignment:
            myMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: messageWidth),
            child: forwarderHeader ?? replies ?? const SizedBox.shrink(),
          ),

          // animatedContainer(
          //     child:
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                myMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              myMessage
                  ? hasMoreHeightForReactions
                      ? reactionsColumn
                      : reactionsRow
                  : const SizedBox.shrink(),
              Container(
                  constraints: BoxConstraints(maxWidth: messageWidth),
                  decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(6.0)),
                      border: Border.all(
                        width: bodyBorderWidth,
                        color: selected
                            ? g.theme.messageSelectionBorderColor
                            : Colors.transparent,
                      )),
                  child: Column(
                      textDirection: TextDirection.ltr,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        media ?? const SizedBox.shrink(),
                        text ?? const SizedBox.shrink(),
                        messagePalettes ?? const SizedBox.shrink()
                      ])
                  // )
                  ),
              myMessage
                  ? const SizedBox.shrink()
                  : hasMoreHeightForReactions
                      ? reactionsColumn
                      : reactionsRow,
            ],
          ),
          // hasReactions ? const SizedBox(height: 2.0) : const SizedBox.shrink(),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: messageWidth),
            child: header2 ?? const SizedBox.shrink(),
          ),
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

  int get nDisplayReaction => nReactions <= maxReactionForThisMessage
      ? nReactions
      : maxReactionForThisMessage;

  Widget get reactionsRow =>
      // AnimatedContainer(
      // duration: Console.animationDuration,
      // constraints: BoxConstraints(maxWidth: messageWidth),
      // decoration: BoxDecoration(
      //     // color: messageColor.withOpacity(0.7),
      //     borderRadius: const BorderRadius.all(Radius.circular(6.0))),
      // child:
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widthForReactions),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget?>.generate(maxReactionForThisMessage,
                  (index) => reaction(reactions![index]))
              .whereType<Widget>()
              .toList(),
        ),
        // ),
      );

  Widget get reactionsColumn =>
      // AnimatedContainer(
      // duration: Console.animationDuration,
      // constraints: BoxConstraints(maxWidth: messageWidth),
      // decoration: BoxDecoration(
      //     // color: messageColor.withOpacity(0.7),
      //     borderRadius: const BorderRadius.all(Radius.circular(6.0))),
      // child:
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: heightForReaction),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: List<Widget?>.generate(maxReactionForThisMessage,
                  (index) => reaction(reactions![index]))
              .whereType<Widget>()
              .toList(),
        ),
        // ),
      );

  // Widget get reactionsWidget => Row(children: [
  //       SizedBox(width: reactionGapWidth),
  //       ...List<Widget?>.generate(
  //               nDisplayReaction, (index) => reaction(reactions![index]))
  //           .whereType<Widget>()
  //           .map((element) =>
  //               Row(children: [element, SizedBox(width: reactionGapWidth)]))
  //           .toList()
  //     ]);

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
