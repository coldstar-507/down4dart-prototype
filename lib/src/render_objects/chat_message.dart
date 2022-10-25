import 'package:flutter/material.dart';

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';

import 'utils.dart';

class ReplyData {
  final String messageRefID;
  final Down4Media thumbnail;
  final String body;
  final Nodes type;
  const ReplyData({
    required this.messageRefID,
    required this.thumbnail,
    required this.body,
    required this.type,
  });
}

class ChatMessage extends StatelessWidget {
  final Node sender;
  static const double headerHeight = 24.0;
  final String at;
  final Down4Message message;
  final bool myMessage, selected, hasHeader, isPost, hasReplies;
  final void Function(Identifier, Identifier)? select;
  final void Function(Identifier)? pressReply;
  final List<ReplyData> repliesData;
  final Down4Media? media;
  ChatMessage({
    required this.sender,
    required this.message,
    required this.myMessage,
    required this.at,
    required this.hasHeader,
    this.repliesData = const [],
    this.pressReply,
    this.media,
    this.isPost = false,
    this.selected = false,
    this.select,
    Key? key,
  })  : hasReplies = repliesData.isNotEmpty,
        super(key: key);

  ChatMessage withMedia(Down4Media media) {
    return ChatMessage(
      sender: sender,
      message: message,
      myMessage: myMessage,
      select: select,
      selected: selected,
      isPost: isPost,
      at: at,
      hasHeader: hasHeader,
      media: media,
    );
  }

  ChatMessage invertedSelection() {
    return ChatMessage(
      sender: sender,
      hasHeader: hasHeader,
      message: message,
      myMessage: myMessage,
      at: at,
      select: select,
      selected: !selected,
      media: media,
    );
  }

  Widget reply(ReplyData replyData) => GestureDetector(
        onTap: null, // TODO: on reply tap
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(
              child: Container(
                color: PinkTheme.nodeColors[replyData.type],
                height: ChatMessage.headerHeight,
                child: Text(replyData.body,
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ),
            SizedBox(
              height: ChatMessage.headerHeight,
              width: ChatMessage.headerHeight,
              child: Image.memory(replyData.thumbnail.data, fit: BoxFit.cover),
            ),
          ],
        ),
      );

  Widget replies(List<ReplyData> replies) => Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
          topRight: Radius.circular(4.0),
          topLeft: Radius.circular(4.0),
        )),
        child: Column(
          textDirection: TextDirection.ltr,
          children: replies.map((r) => reply(r)).toList(),
        ),
      );

  Widget header() => Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: () => select?.call(message.id, at),
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: !hasReplies
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(4.0),
                      )
                    : null,
              ),
              height: ChatMessage.headerHeight,
              width: ChatMessage.headerHeight,
              child: Image.memory(
                sender.image!.data,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => select?.call(message.id, at),
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: PinkTheme.headerColor,
                  borderRadius: !hasReplies
                      ? const BorderRadius.only(
                          topRight: Radius.circular(4.0),
                        )
                      : null,
                ),
                padding: const EdgeInsets.only(left: 2.0, top: 2.0, right: 2.0),
                height: ChatMessage.headerHeight,
                child: Text(
                  sender.name,
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ],
      );

  Widget image() => GestureDetector(
        onTap: () => select?.call(message.id, at),
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: (hasHeader || hasReplies) ||
                    (message.text != null && message.text != "")
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(4.0),
                    bottomRight: Radius.circular(4.0),
                  )
                : const BorderRadius.all(Radius.circular(4.0)),
          ),
          child: Image.memory(
            media!.data,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );

  Widget video(double maxWidth) => Container(
        clipBehavior: Clip.hardEdge,
        height: maxWidth,
        width: maxWidth,
        decoration: BoxDecoration(
          borderRadius: (hasHeader || hasReplies) ||
                  (message.text != null && message.text != "")
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(4.0),
                  bottomRight: Radius.circular(4.0),
                )
              : const BorderRadius.all(Radius.circular(4.0)),
        ),
        child: Down4VideoPlayer(
          vid: media!.file!,
          key: GlobalKey(),
        ),
      );

  Widget text() => GestureDetector(
        onTap: () => select?.call(message.id, at),
        child: Container(
          padding: const EdgeInsets.all(6.0),
          clipBehavior: Clip.hardEdge,
          decoration: media == null
              ? BoxDecoration(
                  color: PinkTheme.bodyColor,
                  borderRadius: hasHeader || hasReplies
                      ? const BorderRadius.only(
                          bottomLeft: Radius.circular(4.0),
                          bottomRight: Radius.circular(4.0),
                        )
                      : const BorderRadius.all(
                          Radius.circular(4.0),
                        ),
                )
              : BoxDecoration(
                  color: PinkTheme.bodyColor,
                  borderRadius: hasHeader || hasReplies
                      ? null
                      : const BorderRadius.only(
                          topRight: Radius.circular(4.0),
                          topLeft: Radius.circular(4.0),
                        ),
                ),
          child: Text(
            message.text!,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Colors.black),
            textAlign: TextAlign.left,
          ),
        ),
      );

  Widget getMessage(double maxWidth) {
    return Align(
      alignment: isPost
          ? Alignment.topCenter
          : myMessage
              ? Alignment.topRight
              : Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 22.0, right: 22.0),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
            boxShadow: !selected
                ? [
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 4.0,
                      spreadRadius: -6.0,
                      offset: Offset(5.0, 5.0),
                      blurStyle: BlurStyle.normal,
                    )
                  ]
                : null,
            border: Border.all(
                width: 2.0,
                color: selected ? Colors.black : Colors.transparent)),
        child: IntrinsicWidth(
          child: Column(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hasReplies ? replies(repliesData) : const SizedBox.shrink(),
              hasHeader ? header() : const SizedBox.shrink(),
              message.text == null || message.text == ""
                  ? const SizedBox.shrink()
                  : text(),
              media != null
                  ? media!.metadata.isVideo
                      ? video(maxWidth)
                      : image()
                  : const SizedBox.shrink()
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = Sizes.w * 0.76;
    return getMessage(maxWidth);
  }
}
