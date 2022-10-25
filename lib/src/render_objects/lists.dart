import 'package:flutter/material.dart';

import '../data_objects.dart';
import '../boxes.dart';

import 'palette.dart';
import 'chat_message.dart';
import 'palette_maker.dart';
import 'utils.dart';

class PaletteList extends StatelessWidget {
  final List<Palette> palettes;
  const PaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final gapSize = Sizes.h * 0.02; // 2%
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
          separatorBuilder: (c, i) => Container(height: gapSize),
          itemCount: palettes.length + 2,
        ),
      ),
    );
  }
}

class MessageList4 extends StatelessWidget {
  final Map<Identifier, Node> senders;
  final Map<Identifier, ChatMessage> messageMap;
  final void Function(String, String) select;
  final void Function(ChatMessage) cache;
  final void Function(String, String) getTheMedia;
  final List<Identifier> messages;
  final Node self;
  const MessageList4({
    required this.senders,
    required this.messages,
    required this.self,
    required this.getTheMedia,
    required this.messageMap,
    required this.select,
    required this.cache,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Down4Message? prevMsgCache;
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.separated(
        reverse: true,
        itemBuilder: (c, i) {
          if (i == 0 || i == messages.length + 2 - 1) {
            return const SizedBox.shrink();
          }
          if (messageMap[messages[i - 1]] != null) {
            return messageMap[messages[i - 1]]!;
          } else {
            Down4Message? prevMsg;
            if (i < messages.length) {
              prevMsg = messageMap[messages[i]]?.message ??
                  b.loadMessage(messages[i]);
            }
            final msg = prevMsgCache ?? b.loadMessage(messages[i - 1]);
            if (msg == null) return const SizedBox.shrink();

            List<ReplyData> replies = [];
            if (msg.replies != null) {
              for (final reply in msg.replies!) {
                var theMessage =
                    messageMap[reply]?.message ?? b.loadMessage(reply);
                if (theMessage != null) {
                  final replyData = ReplyData(
                    messageRefID: reply,
                    thumbnail: senders[theMessage.senderID]!.image!,
                    body: theMessage.text ?? "&attachment",
                    type: senders[theMessage.senderID]!.type,
                  );
                  replies.add(replyData);
                }
              }
            }

            final chat = ChatMessage(
              repliesData: replies,
              sender: senders[msg.senderID]!,
              message: msg,
              myMessage: msg.senderID == self.id,
              at: "",
              hasHeader: msg.senderID != prevMsg?.senderID,
              select: select,
            );
            cache(chat);
            if (msg.mediaID != null) getTheMedia(msg.mediaID!, msg.id);
            prevMsgCache = prevMsg;
            return chat;
          }
        },
        separatorBuilder: (c, i) => Container(height: 4.0),
        itemCount: messages.length + 2,
      ),
    );
  }
}

class DynamicList extends StatelessWidget {
  final List<dynamic> list;
  final bool reversed;
  const DynamicList({
    required this.list,
    this.reversed = true,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final gapSize = Sizes.h * 0.02;
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.separated(
          padding: const EdgeInsets.only(top: 0),
          reverse: reversed,
          itemBuilder: (c, i) => i == 0
              ? const SizedBox.shrink()
              : i == list.length + 2 - 1
                  ? const SizedBox.shrink()
                  : list[i - 1],
          separatorBuilder: (c, i) => Container(height: gapSize),
          itemCount: list.length + 2),
    );
  }
}

class FutureNodesList extends StatelessWidget {
  final String at;
  final Palette? Function(Node node, String at) nodeToPalette;
  final List<Identifier> nodeIDs;
  const FutureNodesList({
    required this.at,
    required this.nodeToPalette,
    required this.nodeIDs,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getNodesFromEverywhere(nodeIDs),
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.done &&
              asyncSnapshot.hasData) {
            final palettes = (asyncSnapshot.data as List<Node>)
                .map((e) => nodeToPalette(e, at))
                .whereType<Palette>()
                .toList();
            return PaletteList(palettes: palettes);
          }
          return const SizedBox.shrink();
        });
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
