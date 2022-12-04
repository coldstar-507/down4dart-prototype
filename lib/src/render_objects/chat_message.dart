import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';
import 'palette.dart';

import 'render_utils.dart';

class ReplyData {
  final String messageRefID, senderName;
  final Image thumbnail;
  final String body;
  final NodesColor type;
  const ReplyData({
    required this.senderName,
    required this.messageRefID,
    required this.thumbnail,
    required this.body,
    required this.type,
  });
}

// class ChatMessage extends StatelessWidget {
//   final Palette sender;
//   static const double headerHeight = 18.0;
//   final String at;
//   final Down4Message message;
//   final bool myMessage, selected, hasHeader, isPost;
//   final void Function(Identifier, Identifier)? select;
//   final void Function(Identifier)? pressReply;
//   final List<ReplyData>? repliesData;
//   final Down4Media? media;
//   final bool show, transitionFromRight;
//   // final double width;
//   final List<String>? specialDisplayTexts;
//   final Size precalculatedSize;
//   final Size? precalculatedMediaSize;
//
//   const ChatMessage({
//     required this.precalculatedSize,
//     required this.sender,
//     required this.message,
//     required this.myMessage,
//     required this.at,
//     required this.hasHeader,
//     this.precalculatedMediaSize,
//     this.specialDisplayTexts,
//     this.show = true,
//     this.transitionFromRight = false,
//     this.repliesData,
//     this.pressReply,
//     this.media,
//     this.isPost = false,
//     this.selected = false,
//     this.select,
//     Key? key,
//   }) : super(key: key);
//
//   double get maxWidth => Sizes.w * 0.76;
//
//   bool get hasText => message.text?.isNotEmpty ?? false;
//
//   bool get hasReplies => repliesData?.isNotEmpty ?? false;
//
//   // ChatMessage withMedia(Down4Media media) {
//   //   return ChatMessage(
//   //     precalculatedSize: precalculatedSize,
//   //     sender: sender,
//   //     message: message,
//   //     specialDisplayTexts: specialDisplayTexts,
//   //     pressReply: pressReply,
//   //     repliesData: repliesData,
//   //     precalculatedMediaSize: precalculatedMediaSize,
//   //     myMessage: myMessage,
//   //     select: select,
//   //     selected: selected,
//   //     show: show,
//   //     transitionFromRight: transitionFromRight,
//   //     isPost: isPost,
//   //     at: at,
//   //     hasHeader: hasHeader,
//   //     media: media,
//   //   );
//   // }
//
//   ChatMessage withHeader({required bool withHeader, Size? newSize}) {
//     return ChatMessage(
//       sender: sender,
//       hasHeader: withHeader,
//       message: message,
//       myMessage: myMessage,
//       specialDisplayTexts: specialDisplayTexts,
//       precalculatedMediaSize: precalculatedMediaSize,
//       pressReply: pressReply,
//       precalculatedSize: newSize ?? precalculatedSize,
//       transitionFromRight: transitionFromRight,
//       repliesData: repliesData,
//       show: show,
//       at: at,
//       select: select,
//       selected: selected,
//       media: media,
//     );
//   }
//
//   ChatMessage invertedSelection() {
//     return ChatMessage(
//       sender: sender,
//       hasHeader: hasHeader,
//       message: message,
//       myMessage: myMessage,
//       specialDisplayTexts: specialDisplayTexts,
//       precalculatedMediaSize: precalculatedMediaSize,
//       pressReply: pressReply,
//       precalculatedSize: precalculatedSize,
//       transitionFromRight: transitionFromRight,
//       repliesData: repliesData,
//       show: show,
//       at: at,
//       select: select,
//       selected: !selected,
//       media: media,
//     );
//   }
//
//   ChatMessage animated({required bool show, bool? transitionFromRight}) {
//     return ChatMessage(
//       precalculatedSize: precalculatedSize,
//       sender: sender,
//       message: message,
//       myMessage: myMessage,
//       select: select,
//       precalculatedMediaSize: precalculatedMediaSize,
//       pressReply: pressReply,
//       repliesData: repliesData,
//       specialDisplayTexts: specialDisplayTexts,
//       selected: selected,
//       show: show,
//       transitionFromRight: transitionFromRight ?? this.transitionFromRight,
//       isPost: isPost,
//       at: at,
//       hasHeader: hasHeader,
//       media: media,
//     );
//   }
//
//   Widget reply(ReplyData replyData) => GestureDetector(
//         onTap: null, // TODO: on reply tap
//         child: Row(
//           textDirection: TextDirection.ltr,
//           children: [
//             Container(
//               height: ChatMessage.headerHeight,
//               width: ChatMessage.headerHeight / 4,
//               color: PinkTheme.qrColor,
//             ),
//             Expanded(
//               child: Container(
//                 color: PinkTheme.nodeColors[replyData.type],
//                 height: ChatMessage.headerHeight,
//                 child: Text(
//                   replyData.body,
//                   overflow: TextOverflow.ellipsis,
//                   maxLines: 1,
//                 ),
//               ),
//             ),
//             SizedBox(
//               height: ChatMessage.headerHeight,
//               width: ChatMessage.headerHeight,
//               child: replyData.thumbnail,
//             ),
//           ],
//         ),
//       );
//
//   Widget replies(List<ReplyData> replies) => Container(
//         clipBehavior: Clip.hardEdge,
//         decoration: const BoxDecoration(
//             borderRadius: BorderRadius.vertical(top: Radius.circular(4.0))),
//         child: Column(
//           textDirection: TextDirection.ltr,
//           children: replies.map((r) => reply(r)).toList(),
//         ),
//       );
//
//   Widget get header => Container(
//         clipBehavior: Clip.hardEdge,
//         decoration: const BoxDecoration(
//             borderRadius: BorderRadius.vertical(bottom: Radius.circular(4))),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           textDirection: TextDirection.ltr,
//           children: [
//             GestureDetector(
//               onTap: () => select?.call(message.id, at),
//               child: Container(
//                 decoration: BoxDecoration(
//                   borderRadius: !hasReplies
//                       ? const BorderRadius.only(
//                           topLeft: Radius.circular(4.0),
//                         )
//                       : null,
//                 ),
//                 height: ChatMessage.headerHeight,
//                 width: ChatMessage.headerHeight,
//                 child: sender.image,
//               ),
//             ),
//             Expanded(
//               child: GestureDetector(
//                 onTap: () => select?.call(message.id, at),
//                 child: Container(
//                   // clipBehavior: Clip.hardEdge,
//                   color: PinkTheme.nodeColors[sender.node.colorCode],
//                   padding:
//                       const EdgeInsets.only(left: 2.0, top: 2.0, right: 2.0),
//                   height: ChatMessage.headerHeight,
//                   child: Text(
//                     sender.node.name,
//                     textDirection: TextDirection.ltr,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//
//   Widget get image => GestureDetector(
//         onTap: () => select?.call(message.id, at),
//         child: Container(
//           clipBehavior: Clip.hardEdge,
//           height: precalculatedMediaSize!.height,
//           width: precalculatedMediaSize!.width,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.vertical(
//                 top: Radius.circular(hasReplies ? 0 : 4),
//                 bottom: Radius.circular((hasText || hasHeader) ? 0 : 4)),
//           ),
//           child: Image.memory(
//             media!.data,
//             fit: BoxFit.cover,
//             gaplessPlayback: true,
//           ),
//         ),
//       );
//
//   Widget get video => Container(
//         clipBehavior: Clip.hardEdge,
//         height: precalculatedMediaSize!.height,
//         width: precalculatedMediaSize!.width,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.vertical(
//               top: Radius.circular(hasReplies ? 0 : 4),
//               bottom: Radius.circular((hasText || hasHeader) ? 0 : 4)),
//         ),
//         child: Down4VideoPlayer(
//           vid: media!.file!,
//           key: GlobalKey(),
//         ),
//       );
//
//   Widget get text => GestureDetector(
//         onTap: () => select?.call(message.id, at),
//         child: Container(
//           // alignment: AlignmentDirectional.centerStart,
//           padding: const EdgeInsets.all(6.0),
//           clipBehavior: Clip.hardEdge,
//           decoration: BoxDecoration(
//               color: PinkTheme.bodyColor,
//               borderRadius: BorderRadius.vertical(
//                 top: Radius.circular(hasReplies || media != null ? 0 : 4),
//                 bottom: Radius.circular(hasHeader ? 0 : 4),
//               )),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: specialDisplayTexts!
//                 .map((str) => AnimatedDefaultTextStyle(
//                       duration: Duration(milliseconds: show ? 900 : 300),
//                       curve: show ? Curves.easeInQuad : Curves.easeOut,
//                       // str,
//                       maxLines: 1,
//                       // textDirection: TextDirection.ltr,
//                       style: TextStyle(
//                           fontFamily: "Alice",
//                           color: Colors.black.withOpacity(show ? 1 : 0)),
//                       textAlign: TextAlign.left,
//                       overflow: TextOverflow.clip,
//                       child: Text(str),
//                     ))
//                 .toList(growable: false),
//           ),
//           // child: size == null
//           //     ? Text(
//           //         message.text!,
//           //         textDirection: TextDirection.ltr,
//           //         style: const TextStyle(color: Colors.black),
//           //         textAlign: TextAlign.left,
//           //       )
//           //     : Column(
//           //         crossAxisAlignment: CrossAxisAlignment.start,
//           //         children: specialDisplayTexts!
//           //             .map((str) => Text(
//           //                   str,
//           //                   maxLines: 1,
//           //                   textDirection: TextDirection.ltr,
//           //                   style: const TextStyle(color: Colors.black),
//           //                   textAlign: TextAlign.left,
//           //                   overflow: TextOverflow.clip,
//           //                 ))
//           //             .toList(growable: false),
//           //       ),
//         ),
//       );
//
//   Widget animatedContainer({required Widget child}) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 600),
//       margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//       transformAlignment:
//           transitionFromRight ? Alignment.centerRight : Alignment.centerLeft,
//       clipBehavior: Clip.hardEdge,
//       curve: Curves.easeOut,
//       decoration: BoxDecoration(
//           borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//           boxShadow: [
//             BoxShadow(
//               color: show && !selected ? Colors.black54 : Colors.transparent,
//               blurRadius: show && !selected ? 4.0 : 0.0,
//               spreadRadius: -6.0,
//               offset: show && !selected
//                   ? const Offset(5.0, 5.0)
//                   : const Offset(0.0, 0.0),
//               blurStyle: BlurStyle.normal,
//             ),
//           ]),
//       child: child,
//     );
//   }
//
//   Widget get chatMessage => Align(
//         alignment: isPost
//             ? Alignment.center
//             : myMessage
//                 ? Alignment.centerRight
//                 : Alignment.centerLeft,
//         child: animatedContainer(
//           child: Container(
//             height: precalculatedSize.height,
//             width: precalculatedSize.width,
//             decoration: BoxDecoration(
//                 borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//                 border: Border.all(
//                     width: 2.0,
//                     color: selected ? Colors.black : Colors.transparent)),
//             child: Column(
//               textDirection: TextDirection.ltr,
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 hasReplies ? replies(repliesData!) : const SizedBox.shrink(),
//                 media != null
//                     ? media!.metadata.isVideo
//                         ? video
//                         : image
//                     : const SizedBox.shrink(),
//                 message.text?.isEmpty ?? true ? const SizedBox.shrink() : text,
//                 hasHeader ? header : const SizedBox.shrink(),
//               ],
//             ),
//           ),
//         ),
//       );
//
//   @override
//   Widget build(BuildContext context) {
//     print("show=$show");
//     // if (size == null) {
//     //   WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
//     //     final key = super.key as GlobalKey;
//     //     final size = key.currentContext!.size!;
//     //     print(
//     //       "Drew the mothafuka, callingback the size: (h,w) = (${size.height},${size.width})",
//     //     );
//     //     sizeCallBack(size);
//     //   });
//     // }
//     return AnimatedOpacity(
//       duration: const Duration(milliseconds: 600),
//       opacity: show ? 1 : 0,
//       curve: Curves.easeOut,
//       child: Column(children: [chatMessage, const SizedBox(height: 4)]),
//     );
//   }
// }

class ChatMessage extends StatelessWidget {
  final Palette sender;
  static const double headerHeight = 18.0;
  final String at;
  final Down4Message message;
  final bool myMessage, selected, hasHeader, isPost;
  final void Function(Identifier, Identifier)? select;
  final void Function(Identifier)? pressReply;
  final List<ReplyData>? repliesData;
  final Down4Media? media;
  final bool show, transitionFromRight;
  // final double width;
  final List<String>? specialDisplayTexts;
  final Size precalculatedSize;
  final Size? precalculatedMediaSize;

  const ChatMessage({
    required this.precalculatedSize,
    required this.sender,
    required this.message,
    required this.myMessage,
    required this.at,
    required this.hasHeader,
    this.precalculatedMediaSize,
    this.specialDisplayTexts,
    this.show = true,
    this.transitionFromRight = false,
    this.repliesData,
    this.pressReply,
    this.media,
    this.isPost = false,
    this.selected = false,
    this.select,
    Key? key,
  }) : super(key: key);

  double get maxWidth => Sizes.w * 0.76;

  bool get hasText => message.text?.isNotEmpty ?? false;

  bool get hasReplies => repliesData?.isNotEmpty ?? false;

  // ChatMessage withMedia(Down4Media media) {
  //   return ChatMessage(
  //     precalculatedSize: precalculatedSize,
  //     sender: sender,
  //     message: message,
  //     specialDisplayTexts: specialDisplayTexts,
  //     pressReply: pressReply,
  //     repliesData: repliesData,
  //     precalculatedMediaSize: precalculatedMediaSize,
  //     myMessage: myMessage,
  //     select: select,
  //     selected: selected,
  //     show: show,
  //     transitionFromRight: transitionFromRight,
  //     isPost: isPost,
  //     at: at,
  //     hasHeader: hasHeader,
  //     media: media,
  //   );
  // }

  ChatMessage withHeader({required bool withHeader, Size? newSize}) {
    return ChatMessage(
      sender: sender,
      hasHeader: withHeader,
      message: message,
      myMessage: myMessage,
      specialDisplayTexts: specialDisplayTexts,
      precalculatedMediaSize: precalculatedMediaSize,
      pressReply: pressReply,
      precalculatedSize: newSize ?? precalculatedSize,
      transitionFromRight: transitionFromRight,
      repliesData: repliesData,
      show: show,
      at: at,
      select: select,
      selected: selected,
      media: media,
    );
  }

  ChatMessage invertedSelection() {
    return ChatMessage(
      sender: sender,
      hasHeader: hasHeader,
      message: message,
      myMessage: myMessage,
      specialDisplayTexts: specialDisplayTexts,
      precalculatedMediaSize: precalculatedMediaSize,
      pressReply: pressReply,
      precalculatedSize: precalculatedSize,
      transitionFromRight: transitionFromRight,
      repliesData: repliesData,
      show: show,
      at: at,
      select: select,
      selected: !selected,
      media: media,
    );
  }

  ChatMessage animated({required bool show, bool? transitionFromRight}) {
    return ChatMessage(
      precalculatedSize: precalculatedSize,
      sender: sender,
      message: message,
      myMessage: myMessage,
      select: select,
      precalculatedMediaSize: precalculatedMediaSize,
      pressReply: pressReply,
      repliesData: repliesData,
      specialDisplayTexts: specialDisplayTexts,
      selected: selected,
      show: show,
      transitionFromRight: transitionFromRight ?? this.transitionFromRight,
      isPost: isPost,
      at: at,
      hasHeader: hasHeader,
      media: media,
    );
  }

  Widget reply(ReplyData replyData) => Container(
        height: ChatMessage.headerHeight,
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6),
        child: GestureDetector(
          onTap: null, // TODO: on reply tap
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
                child: Container(
                  // color: PinkTheme.nodeColors[replyData.type],
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    replyData.body,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              Container(
                // color: PinkTheme.nodeColors[replyData.type],
                // padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  replyData.senderName,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  overflow: TextOverflow.clip,
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

  Widget replies(List<ReplyData> replies) => Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(4.0))),
        child: Column(
          textDirection: TextDirection.ltr,
          children: replies.map((r) => reply(r)).toList(),
        ),
      );

  Widget get header => Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(4))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            GestureDetector(
              onTap: () => select?.call(message.id, at),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: !hasReplies
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(4.0),
                        )
                      : null,
                ),
                height: ChatMessage.headerHeight,
                width: ChatMessage.headerHeight,
                child: sender.image,
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => select?.call(message.id, at),
                child: Container(
                  // clipBehavior: Clip.hardEdge,
                  color: PinkTheme.nodeColors[sender.node.colorCode],
                  padding:
                      const EdgeInsets.only(left: 2.0, top: 2.0, right: 2.0),
                  height: ChatMessage.headerHeight,
                  child: Text(
                    sender.node.name,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget get image => GestureDetector(
        onTap: () => select?.call(message.id, at),
        child: Container(
          clipBehavior: Clip.hardEdge,
          height: precalculatedMediaSize!.height,
          width: precalculatedMediaSize!.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(4),
                bottom: Radius.circular((hasText || hasHeader) ? 0 : 4)),
          ),
          child: Image.memory(
            media!.data,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );

  Widget get video => Container(
        clipBehavior: Clip.hardEdge,
        height: precalculatedMediaSize!.height,
        width: precalculatedMediaSize!.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
              top: const Radius.circular(4),
              bottom: Radius.circular((hasText || hasHeader) ? 0 : 4)),
        ),
        child: Down4VideoPlayer(
          vid: media!.file!,
          key: GlobalKey(),
        ),
      );

  Widget get text => GestureDetector(
        onTap: () => select?.call(message.id, at),
        child: Container(
          // alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.all(6.0),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
              color: myMessage ? PinkTheme.myBubblesColor : PinkTheme.bodyColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(media != null ? 0 : 4),
                bottom: Radius.circular(hasHeader ? 0 : 4),
              )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: specialDisplayTexts!
                .map((str) => AnimatedDefaultTextStyle(
                      duration: Duration(milliseconds: show ? 900 : 300),
                      curve: show ? Curves.easeInQuad : Curves.easeOut,
                      // str,
                      maxLines: 1,
                      // textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontFamily: "Alice",
                          color: Colors.black.withOpacity(show ? 1 : 0)),
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.clip,
                      child: Text(str),
                    ))
                .toList(growable: false),
          ),
          // child: size == null
          //     ? Text(
          //         message.text!,
          //         textDirection: TextDirection.ltr,
          //         style: const TextStyle(color: Colors.black),
          //         textAlign: TextAlign.left,
          //       )
          //     : Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: specialDisplayTexts!
          //             .map((str) => Text(
          //                   str,
          //                   maxLines: 1,
          //                   textDirection: TextDirection.ltr,
          //                   style: const TextStyle(color: Colors.black),
          //                   textAlign: TextAlign.left,
          //                   overflow: TextOverflow.clip,
          //                 ))
          //             .toList(growable: false),
          //       ),
        ),
      );

  Widget animatedContainer({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      transformAlignment:
          transitionFromRight ? Alignment.centerRight : Alignment.centerLeft,
      clipBehavior: Clip.hardEdge,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(6.0)),
          boxShadow: [
            BoxShadow(
              color: show && !selected ? Colors.black54 : Colors.transparent,
              blurRadius: show && !selected ? 4.0 : 0.0,
              spreadRadius: -6.0,
              offset: show && !selected
                  ? const Offset(5.0, 5.0)
                  : const Offset(0.0, 0.0),
              blurStyle: BlurStyle.normal,
            ),
          ]),
      child: child,
    );
  }

  Widget get chatMessage => Align(
        alignment: isPost
            ? Alignment.center
            : myMessage
                ? Alignment.centerRight
                : Alignment.centerLeft,
        child: Container(
            margin: const EdgeInsets.only(left: 22.0, right: 22.0),
            height: precalculatedSize.height,
            width: precalculatedSize.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hasReplies ? replies(repliesData!) : const SizedBox.shrink(),
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
                        media != null
                            ? media!.metadata.isVideo
                                ? video
                                : image
                            : const SizedBox.shrink(),
                        message.text?.isEmpty ?? true
                            ? const SizedBox.shrink()
                            : text,
                        hasHeader ? header : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ],
            )),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: show ? 1 : 0,
      curve: Curves.easeOut,
      child: Column(children: [chatMessage, const SizedBox(height: 4)]),
    );
  }
}

// class ChatMessage extends StatelessWidget {
//   final Palette sender;
//   static const double headerHeight = 18.0;
//   final String at;
//   final Down4Message message;
//   final bool myMessage, selected, hasHeader, isPost;
//   final void Function(Identifier, Identifier)? select;
//   final void Function(Identifier)? pressReply;
//   final List<ReplyData>? repliesData;
//   final Down4Media? media;
//   final bool show, transitionFromRight;
//   // final double width;
//   final List<String>? specialDisplayTexts;
//   final Size precalculatedSize;
//   final Size? precalculatedMediaSize;
//
//   const ChatMessage({
//     required this.precalculatedSize,
//     required this.sender,
//     required this.message,
//     required this.myMessage,
//     required this.at,
//     required this.hasHeader,
//     this.precalculatedMediaSize,
//     this.specialDisplayTexts,
//     this.show = true,
//     this.transitionFromRight = false,
//     this.repliesData,
//     this.pressReply,
//     this.media,
//     this.isPost = false,
//     this.selected = false,
//     this.select,
//     Key? key,
//   }) : super(key: key);
//
//   double get maxWidth => Sizes.w * 0.76;
//
//   bool get hasText => message.text?.isNotEmpty ?? false;
//
//   bool get hasReplies => repliesData?.isNotEmpty ?? false;
//
//   // ChatMessage withMedia(Down4Media media) {
//   //   return ChatMessage(
//   //     precalculatedSize: precalculatedSize,
//   //     sender: sender,
//   //     message: message,
//   //     specialDisplayTexts: specialDisplayTexts,
//   //     pressReply: pressReply,
//   //     repliesData: repliesData,
//   //     precalculatedMediaSize: precalculatedMediaSize,
//   //     myMessage: myMessage,
//   //     select: select,
//   //     selected: selected,
//   //     show: show,
//   //     transitionFromRight: transitionFromRight,
//   //     isPost: isPost,
//   //     at: at,
//   //     hasHeader: hasHeader,
//   //     media: media,
//   //   );
//   // }
//
//   ChatMessage withHeader({required bool withHeader, Size? newSize}) {
//     return ChatMessage(
//       sender: sender,
//       hasHeader: withHeader,
//       message: message,
//       myMessage: myMessage,
//       specialDisplayTexts: specialDisplayTexts,
//       precalculatedMediaSize: precalculatedMediaSize,
//       pressReply: pressReply,
//       precalculatedSize: newSize ?? precalculatedSize,
//       transitionFromRight: transitionFromRight,
//       repliesData: repliesData,
//       show: show,
//       at: at,
//       select: select,
//       selected: selected,
//       media: media,
//     );
//   }
//
//   ChatMessage invertedSelection() {
//     return ChatMessage(
//       sender: sender,
//       hasHeader: hasHeader,
//       message: message,
//       myMessage: myMessage,
//       specialDisplayTexts: specialDisplayTexts,
//       precalculatedMediaSize: precalculatedMediaSize,
//       pressReply: pressReply,
//       precalculatedSize: precalculatedSize,
//       transitionFromRight: transitionFromRight,
//       repliesData: repliesData,
//       show: show,
//       at: at,
//       select: select,
//       selected: !selected,
//       media: media,
//     );
//   }
//
//   ChatMessage animated({required bool show, bool? transitionFromRight}) {
//     return ChatMessage(
//       precalculatedSize: precalculatedSize,
//       sender: sender,
//       message: message,
//       myMessage: myMessage,
//       select: select,
//       precalculatedMediaSize: precalculatedMediaSize,
//       pressReply: pressReply,
//       repliesData: repliesData,
//       specialDisplayTexts: specialDisplayTexts,
//       selected: selected,
//       show: show,
//       transitionFromRight: transitionFromRight ?? this.transitionFromRight,
//       isPost: isPost,
//       at: at,
//       hasHeader: hasHeader,
//       media: media,
//     );
//   }
//
//   Widget reply(ReplyData replyData) => GestureDetector(
//         onTap: () => print("TODO"), // TODO: on reply tap
//         child: Row(
//           textDirection: TextDirection.ltr,
//           children: [
//             Expanded(
//               child: Container(
//                 color: Colors.transparent,
//                 height: ChatMessage.headerHeight,
//                 child: Text(
//                   replyData.body,
//                   overflow: TextOverflow.ellipsis,
//                   maxLines: 1,
//                 ),
//               ),
//             ),
//             SizedBox(
//               height: ChatMessage.headerHeight,
//               width: ChatMessage.headerHeight,
//               child: replyData.thumbnail,
//             ),
//           ],
//         ),
//       );
//
//   Widget replies(List<ReplyData> replies) => Column(
//         textDirection: TextDirection.ltr,
//         children: replies.map((r) => reply(r)).toList(),
//       );
//
//   Widget get header => Container(
//         clipBehavior: Clip.hardEdge,
//         decoration: const BoxDecoration(
//             borderRadius: BorderRadius.vertical(bottom: Radius.circular(4))),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           textDirection: TextDirection.ltr,
//           children: [
//             GestureDetector(
//               onTap: () => select?.call(message.id, at),
//               child: Container(
//                 decoration: BoxDecoration(
//                   borderRadius: !hasReplies
//                       ? const BorderRadius.only(
//                           topLeft: Radius.circular(4.0),
//                         )
//                       : null,
//                 ),
//                 height: ChatMessage.headerHeight,
//                 width: ChatMessage.headerHeight,
//                 child: sender.image,
//               ),
//             ),
//             Expanded(
//               child: GestureDetector(
//                 onTap: () => select?.call(message.id, at),
//                 child: Container(
//                   // clipBehavior: Clip.hardEdge,
//                   color: PinkTheme.nodeColors[sender.node.colorCode],
//                   padding:
//                       const EdgeInsets.only(left: 2.0, top: 2.0, right: 2.0),
//                   height: ChatMessage.headerHeight,
//                   child: Text(
//                     sender.node.name,
//                     textDirection: TextDirection.ltr,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//
//   Widget get newHeader => GestureDetector(
//         onTap: () => select?.call(message.id, at),
//         child: Align(
//           alignment: myMessage
//               ? AlignmentDirectional.centerEnd
//               : AlignmentDirectional.centerStart,
//           child: Container(
//             // clipBehavior: Clip.hardEdge,
//             height: headerHeight,
//             child: Row(
//               children: [
//                 Container(
//                   height: headerHeight,
//                   width: headerHeight,
//                   clipBehavior: Clip.hardEdge,
//                   decoration: const BoxDecoration(
//                     // color: PinkTheme.nodeColors[sender.node.colorCode],
//                     shape: BoxShape.circle,
//                   ),
//                   child: sender.image,
//                 ),
//                 Text(sender.node.name)
//               ],
//             ),
//           ),
//         ),
//       );
//
//   Widget get image => GestureDetector(
//         onTap: () => select?.call(message.id, at),
//         child: Container(
//           clipBehavior: Clip.hardEdge,
//           height: precalculatedMediaSize!.height,
//           width: precalculatedMediaSize!.width,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.vertical(
//                 top: const Radius.circular(4),
//                 bottom: Radius.circular(hasText ? 0 : 4)),
//           ),
//           child: Image.memory(
//             media!.data,
//             fit: BoxFit.cover,
//             gaplessPlayback: true,
//           ),
//         ),
//       );
//
//   Widget get video => Container(
//         clipBehavior: Clip.hardEdge,
//         height: precalculatedMediaSize!.height,
//         width: precalculatedMediaSize!.width,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.vertical(
//               top: const Radius.circular(4),
//               bottom: Radius.circular(hasText ? 0 : 4)),
//         ),
//         child: Down4VideoPlayer(
//           vid: media!.file!,
//           key: GlobalKey(),
//         ),
//       );
//
//   Widget get text => GestureDetector(
//         onTap: () => select?.call(message.id, at),
//         child: Container(
//           padding: const EdgeInsets.all(6.0),
//           clipBehavior: Clip.hardEdge,
//           decoration: BoxDecoration(
//               color: PinkTheme.bodyColor,
//               borderRadius: BorderRadius.vertical(
//                 top: Radius.circular(media != null ? 0 : 4),
//                 bottom: const Radius.circular(4),
//               )),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               ...specialDisplayTexts!.map((str) => AnimatedDefaultTextStyle(
//                     duration: Duration(milliseconds: show ? 900 : 300),
//                     curve: show ? Curves.easeInQuad : Curves.easeOut,
//                     maxLines: 1,
//                     style: TextStyle(
//                         fontFamily: "Alice",
//                         color: Colors.black.withOpacity(show ? 1 : 0)),
//                     textAlign: TextAlign.left,
//                     overflow: TextOverflow.clip,
//                     child: Text(str),
//                   )),
//               Row(children: [
//                 const Spacer(),
//                 Align(
//                   alignment: AlignmentDirectional.centerEnd,
//                   child: hasHeader ? newHeader : const SizedBox.shrink(),
//                 )
//               ])
//             ],
//           ),
//         ),
//       );
//
//   Widget animatedContainer({required Widget child}) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 600),
//       transformAlignment:
//           transitionFromRight ? Alignment.centerRight : Alignment.centerLeft,
//       clipBehavior: Clip.hardEdge,
//       curve: Curves.easeOut,
//       decoration: BoxDecoration(
//           borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//           boxShadow: [
//             BoxShadow(
//               color: show && !selected ? Colors.black54 : Colors.transparent,
//               blurRadius: show && !selected ? 4.0 : 0.0,
//               spreadRadius: -6.0,
//               offset: show && !selected
//                   ? const Offset(5.0, 5.0)
//                   : const Offset(0.0, 0.0),
//               blurStyle: BlurStyle.normal,
//             ),
//           ]),
//       child: child,
//     );
//   }
//
//   Widget get chatMessage => Align(
//         alignment: isPost
//             ? Alignment.center
//             : myMessage
//                 ? Alignment.centerRight
//                 : Alignment.centerLeft,
//         child: Container(
//           height: precalculatedSize.height,
//           width: precalculatedSize.width,
//           margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//           child: Column(
//             textDirection: TextDirection.ltr,
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               hasReplies ? replies(repliesData!) : const SizedBox.shrink(),
//               animatedContainer(
//                 child: DecoratedBox(
//                   decoration: BoxDecoration(
//                       borderRadius:
//                           const BorderRadius.all(Radius.circular(6.0)),
//                       border: Border.all(
//                           width: 2.0,
//                           color: selected ? Colors.black : Colors.transparent)),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       media != null
//                           ? media!.metadata.isVideo
//                               ? video
//                               : image
//                           : const SizedBox.shrink(),
//                       message.text?.isEmpty ?? true
//                           ? const SizedBox.shrink()
//                           : text,
//                     ],
//                   ),
//                 ),
//               ),
//               // hasHeader ? newHeader : const SizedBox.shrink(),
//             ],
//           ),
//         ),
//       );
//
//   @override
//   Widget build(BuildContext context) {
//     print("show=$show");
//     // if (size == null) {
//     //   WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
//     //     final key = super.key as GlobalKey;
//     //     final size = key.currentContext!.size!;
//     //     print(
//     //       "Drew the mothafuka, callingback the size: (h,w) = (${size.height},${size.width})",
//     //     );
//     //     sizeCallBack(size);
//     //   });
//     // }
//     return AnimatedOpacity(
//       duration: const Duration(milliseconds: 600),
//       opacity: show ? 1 : 0,
//       curve: Curves.easeOut,
//       child: Column(children: [chatMessage, const SizedBox(height: 4)]),
//     );
//   }
// }
