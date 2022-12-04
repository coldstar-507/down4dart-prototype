import 'package:flutter/material.dart';

import '../data_objects.dart';
import '../boxes.dart';

import 'palette.dart';
import 'chat_message.dart';
import 'palette_maker.dart';
import 'render_utils.dart';

class PaletteList extends StatelessWidget {
  final List<Palette> palettes;
  const PaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final gapSize = Sizes.h * 0.02; // 2%
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.builder(
        reverse: true,
        itemBuilder: (c, i) => palettes[i],
        itemCount: palettes.length,
        padding: EdgeInsets.only(top: gapSize),
      ),
      // child: ListView.separated(
      //   padding: const EdgeInsets.only(top: 0),
      //   reverse: true,
      //   itemBuilder: (c, i) => i == 0
      //       ? const SizedBox.shrink()
      //       : i == palettes.length + 2 - 1
      //           ? const SizedBox.shrink()
      //           : palettes[i - 1],
      //   separatorBuilder: (c, i) => Container(height: gapSize),
      //   itemCount: palettes.length + 2,
      // ),
    );
  }
}

// class MessageList4 extends StatelessWidget {
//   final Map<Identifier, Palette> senders;
//   final Map<Identifier, ChatMessage> messageMap;
//   final void Function(String, String) select;
//   final void Function(ChatMessage) cache;
//   final void Function(String, String) getTheMedia;
//   final List<Identifier> messages;
//   final User self;
//   final bool staticHeight;
//   const MessageList4({
//     this.staticHeight = false,
//     required this.senders,
//     required this.messages,
//     required this.self,
//     required this.getTheMedia,
//     required this.messageMap,
//     required this.select,
//     required this.cache,
//     Key? key,
//   }) : super(key: key);
//
//   MessageList4 withStaticHeight(bool withStaticHeight) {
//     return MessageList4(
//       senders: senders,
//       messages: messages,
//       self: self,
//       getTheMedia: getTheMedia,
//       messageMap: messageMap,
//       select: select,
//       cache: cache,
//       staticHeight: withStaticHeight,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     Down4Message? prevMsgCache;
//     return ScrollConfiguration(
//       behavior: NoGlow(),
//       child: ListView.separated(
//         reverse: true,
//         itemBuilder: (c, i) {
//           if (i == 0 || i == messages.length + 2 - 1) {
//             return const SizedBox.shrink();
//           }
//           if (messageMap[messages[i - 1]] != null) {
//             return messageMap[messages[i - 1]]!;
//           } else {
//             Down4Message? prevMsg;
//             if (i < messages.length) {
//               prevMsg = messageMap[messages[i]]?.message ??
//                   b.loadMessage(messages[i]);
//             }
//             final msg = prevMsgCache ?? b.loadMessage(messages[i - 1]);
//             if (msg == null) return const SizedBox.shrink();
//
//             List<ReplyData> replies = [];
//             if (msg.replies != null) {
//               for (final reply in msg.replies!) {
//                 var theMessage =
//                     messageMap[reply]?.message ?? b.loadMessage(reply);
//                 if (theMessage != null) {
//                   var sender = senders[theMessage.senderID]!.node as User;
//                   final replyData = ReplyData(
//                     messageRefID: reply,
//                     thumbnail: sender.media!,
//                     body: theMessage.text ?? "&attachment",
//                     type: sender.colorCode,
//                   );
//                   replies.add(replyData);
//                 }
//               }
//             }
//
//             final chat = ChatMessage(
//               key: GlobalKey(),
//               // sizeCallBack: (s) => s,
//               // width: Sizes.w * 0.76,
//               precalculatedSize: const Size(3, 3),
//               repliesData: replies,
//               sender: senders[msg.senderID]!,
//               message: msg,
//               myMessage: msg.senderID == self.id,
//               at: "",
//               hasHeader: msg.senderID != prevMsg?.senderID,
//               select: select,
//             );
//             cache(chat);
//             if (msg.mediaID != null) getTheMedia(msg.mediaID!, msg.id);
//             prevMsgCache = prevMsg;
//             return chat;
//           }
//         },
//         separatorBuilder: (c, i) => Container(height: 4.0),
//         itemCount: messages.length + 2,
//       ),
//     );
//   }
// }

class DynamicList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<dynamic> list;
  final bool reversed;
  final double? topPadding;
  const DynamicList({
    this.scrollController,
    this.topPadding,
    required this.list,
    this.reversed = true,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final gapSize = Sizes.h * 0.02;
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.only(top: topPadding ?? gapSize),
        reverse: reversed,
        itemBuilder: (_, i) => list[i],
        itemCount: list.length,
      ),
    );
  }
}

class StaticList extends StatelessWidget {
  final ScrollController? scrollController;
  final List<Widget> list;
  final bool reversed;
  final double? topPadding;
  const StaticList({
    this.scrollController,
    this.topPadding,
    required this.list,
    this.reversed = true,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gapSize = Sizes.h * 0.02;
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: Align(
        alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        reverse: reversed,
        controller: scrollController,
        padding: EdgeInsets.only(top: topPadding ?? gapSize),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.end,
          children: list,
        ),
      ),
      ),
    );
  }
}

// class StaticList extends StatelessWidget {
//   final ScrollController? scrollController;
//   final List<Widget> list;
//   final bool reversed;
//   final double? topPadding;
//   const StaticList({
//     this.scrollController,
//     this.topPadding,
//     required this.list,
//     this.reversed = true,
//     Key? key,
//   }) : super(key: key);
//   @override
//   Widget build(BuildContext context) {
//     final gapSize = Sizes.h * 0.02;
//     return ScrollConfiguration(
//       behavior: NoGlow(),
//       child: ListView(
//         shrinkWrap: true,
//         controller: scrollController,
//         padding: EdgeInsets.only(top: topPadding ?? gapSize),
//         reverse: reversed,
//         children: list,
//         // itemBuilder: (_, i) => list[i],
//         // itemCount: list.length,
//       ),
//     );
//   }
// }

class FutureNodesList extends StatelessWidget {
  final String at;
  final Palette? Function(BaseNode node, String at) nodeToPalette;
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
            final palettes = (asyncSnapshot.data as List<BaseNode>)
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
