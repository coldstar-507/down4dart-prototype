import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';
import 'palette.dart';

import 'render_utils.dart';

class ReplyData {
  final String messageRefID, senderName, senderID;
  final Image thumbnail;
  final String body;
  final NodesColor type;
  const ReplyData({
    required this.senderName,
    required this.senderID,
    required this.messageRefID,
    required this.thumbnail,
    required this.body,
    required this.type,
  });
}

class ChatMessage extends StatelessWidget {
  final Palette sender;
  static const double headerHeight = 18.0;
  final String at;
  final Message message;
  final bool myMessage, selected, isPost;
  final void Function(Identifier, Identifier)? select;
  final void Function(Identifier)? pressReply;
  final List<ReplyData>? repliesData;
  final MessageMedia? media;
  final bool show, transitionFromRight, lastStringOnSameLine;
  final double heightIfNotOnSameLine;
  // final double width;
  final List<String>? specialDisplayTexts;
  final Size precalculatedSize;
  final Size? precalculatedMediaSize;
  final String? headerText;

  const ChatMessage({
    required this.precalculatedSize,
    required this.sender,
    required this.message,
    required this.myMessage,
    required this.at,
    required this.heightIfNotOnSameLine,
    required this.lastStringOnSameLine,
    this.headerText,
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

  bool get hasHeader => headerText?.isNotEmpty ?? false;

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

  ChatMessage withHeader({required String header, Size? newSize}) {
    return ChatMessage(
      sender: sender,
      headerText: header,
      message: message,
      myMessage: myMessage,
      specialDisplayTexts: specialDisplayTexts,
      precalculatedMediaSize: precalculatedMediaSize,
      lastStringOnSameLine: lastStringOnSameLine,
      heightIfNotOnSameLine: heightIfNotOnSameLine,
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
      headerText: headerText,
      message: message,
      myMessage: myMessage,
      specialDisplayTexts: specialDisplayTexts,
      lastStringOnSameLine: lastStringOnSameLine,
      heightIfNotOnSameLine: heightIfNotOnSameLine,
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
      lastStringOnSameLine: lastStringOnSameLine,
      heightIfNotOnSameLine: heightIfNotOnSameLine,
      precalculatedMediaSize: precalculatedMediaSize,
      pressReply: pressReply,
      repliesData: repliesData,
      specialDisplayTexts: specialDisplayTexts,
      selected: selected,
      show: show,
      transitionFromRight: transitionFromRight ?? this.transitionFromRight,
      isPost: isPost,
      at: at,
      headerText: headerText,
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
                    replyData.senderID,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              Expanded(
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

  Widget get header2 => SizedBox(
      height: headerHeight,
      child: Row(children: [
        const Spacer(),
        Text(
          "-${message.senderID}   ",
          style: const TextStyle(color: PinkTheme.qrColor, fontSize: 13),
        ),
        // const Spacer(),
      ]));

  Widget get image {
    print("METADATA = ${media!.metadata.toJson()}");
    print("RENDERING IMAGE ${media!.id}");
    return GestureDetector(
      onTap: () => select?.call(message.id, at),
      child: Container(
        clipBehavior: Clip.hardEdge,
        height: precalculatedMediaSize!.height,
        width: precalculatedMediaSize!.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
              top: const Radius.circular(4),
              bottom: Radius.circular(hasText ? 0 : 4)),
        ),
        child: Down4ImageViewer(media: media!),
      ),
    );
  }

  Widget get video {
    print("PRECALC VIDEO SIZE = $precalculatedMediaSize");
    print("VIDEO ID = ${media!.id}");
    return Container(
      clipBehavior: Clip.hardEdge,
      height: precalculatedMediaSize!.height,
      width: precalculatedMediaSize!.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
            top: const Radius.circular(4),
            bottom: Radius.circular(hasText ? 0 : 4)),
      ),
      child: Transform.scale(
        scaleY: media!.metadata.isSquared
            ? media!.metadata.elementAspectRatio
            : 1.0,
        child: Down4VideoPlayer(media: media!, key: GlobalKey()),
      ),
    );
  }

  Widget get text {
    final dateText = specialDisplayTexts!.last;
    final beforeLast = specialDisplayTexts![specialDisplayTexts!.length - 2];
    final texts =
        specialDisplayTexts!.sublist(0, specialDisplayTexts!.length - 1);
    return GestureDetector(
      onTap: () => select?.call(message.id, at),
      child: Container(
        // alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.all(6.0),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: myMessage ? PinkTheme.myBubblesColor : PinkTheme.bodyColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(media != null ? 0 : 4),
              bottom: const Radius.circular(4),
            )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: texts
              .map((str) => AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: show ? 900 : 300),
                    curve: show ? Curves.easeInQuad : Curves.easeInOut,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: "Alice",
                        color: Colors.black.withOpacity(show ? 1 : 0)),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.clip,
                    child: str != beforeLast
                        ? Text(str)
                        : lastStringOnSameLine
                            ? Row(
                                textDirection: TextDirection.ltr,
                                children: [
                                  Text(str),
                                  const Spacer(),
                                  Text(
                                    dateText,
                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                  )
                                ],
                              )
                            : Column(
                                textDirection: TextDirection.ltr,
                                children: [
                                  Text(str),
                                  Row(
                                    children: [
                                      const Spacer(),
                                      Text(
                                        dateText,
                                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                  ))
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget animatedContainer({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      transformAlignment:
          transitionFromRight ? Alignment.centerRight : Alignment.centerLeft,
      clipBehavior: Clip.hardEdge,
      curve: Curves.easeInOut,
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
                      ],
                    ),
                  ),
                ),
                hasHeader ? header2 : const SizedBox.shrink(),
              ],
            )),
      );

  @override
  Widget build(BuildContext context) {
    print(headerText);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: show ? 1 : 0,
      curve: Curves.easeInOut,
      child: Column(children: [chatMessage, const SizedBox(height: 4)]),
    );
  }
}

// class ChatMessage extends StatelessWidget {
//   final Palette sender;
//   static const double headerHeight = 18.0;
//   final String at;
//   final Message message;
//   final bool myMessage, selected, hasHeader, isPost;
//   final void Function(Identifier, Identifier)? select;
//   final void Function(Identifier)? pressReply;
//   final List<ReplyData>? repliesData;
//   final MessageMedia? media;
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
//   Widget reply(ReplyData replyData) => Container(
//         height: ChatMessage.headerHeight,
//         padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6),
//         child: GestureDetector(
//           onTap: null, // TODO: on reply tap
//           child: Row(
//             textDirection: TextDirection.ltr,
//             children: [
//               Container(
//                 width: 2,
//                 decoration: const BoxDecoration(
//                   borderRadius: BorderRadius.all(Radius.circular(6.0)),
//                   color: Colors.black54,
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   // color: PinkTheme.nodeColors[replyData.type],
//                   padding: const EdgeInsets.symmetric(horizontal: 4),
//                   child: Text(
//                     replyData.body,
//                     style: const TextStyle(fontSize: 11, color: Colors.black54),
//                     overflow: TextOverflow.ellipsis,
//                     maxLines: 1,
//                   ),
//                 ),
//               ),
//               Container(
//                 // color: PinkTheme.nodeColors[replyData.type],
//                 // padding: const EdgeInsets.symmetric(horizontal: 4),
//                 child: Text(
//                   replyData.senderName,
//                   style: const TextStyle(fontSize: 11, color: Colors.black54),
//                   overflow: TextOverflow.clip,
//                   maxLines: 1,
//                 ),
//               ),
//
//               // SizedBox(
//               //   height: ChatMessage.headerHeight,
//               //   width: ChatMessage.headerHeight,
//               //   child: replyData.thumbnail,
//               // ),
//             ],
//           ),
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
//   Widget get image {
//     print("METADATA = ${media!.metadata.toJson()}");
//     print("RENDERING IMAGE ${media!.id}");
//     return GestureDetector(
//       onTap: () => select?.call(message.id, at),
//       child: Container(
//         clipBehavior: Clip.hardEdge,
//         height: precalculatedMediaSize!.height,
//         width: precalculatedMediaSize!.width,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.vertical(
//               top: const Radius.circular(4),
//               bottom: Radius.circular((hasText || hasHeader) ? 0 : 4)),
//         ),
//         child: Down4ImageViewer(media: media!),
//       ),
//     );
//   }
//
//   Widget get video {
//     print("PRECALC VIDEO SIZE = $precalculatedMediaSize");
//     print("VIDEO ID = ${media!.id}");
//     return Container(
//       clipBehavior: Clip.hardEdge,
//       height: precalculatedMediaSize!.height,
//       width: precalculatedMediaSize!.width,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.vertical(
//             top: const Radius.circular(4),
//             bottom: Radius.circular((hasText || hasHeader) ? 0 : 4)),
//       ),
//       child: Transform.scale(
//         scaleY: media!.metadata.isSquared
//             ? media!.metadata.elementAspectRatio
//             : 1.0,
//         child: Down4VideoPlayer(media: media!, key: GlobalKey()),
//       ),
//     );
//   }
//
//   Widget get text => GestureDetector(
//         onTap: () => select?.call(message.id, at),
//         child: Container(
//           // alignment: AlignmentDirectional.centerStart,
//           padding: const EdgeInsets.all(6.0),
//           clipBehavior: Clip.hardEdge,
//           decoration: BoxDecoration(
//               color: myMessage ? PinkTheme.myBubblesColor : PinkTheme.bodyColor,
//               borderRadius: BorderRadius.vertical(
//                 top: Radius.circular(media != null ? 0 : 4),
//                 bottom: Radius.circular(hasHeader ? 0 : 4),
//               )),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: specialDisplayTexts!
//                 .map((str) => AnimatedDefaultTextStyle(
//                       duration: Duration(milliseconds: show ? 900 : 300),
//                       curve: show ? Curves.easeInQuad : Curves.easeInOut,
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
//         ),
//       );
//
//   Widget animatedContainer({required Widget child}) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 600),
//       transformAlignment:
//           transitionFromRight ? Alignment.centerRight : Alignment.centerLeft,
//       clipBehavior: Clip.hardEdge,
//       curve: Curves.easeInOut,
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
//             margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//             height: precalculatedSize.height,
//             width: precalculatedSize.width,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 hasReplies ? replies(repliesData!) : const SizedBox.shrink(),
//                 animatedContainer(
//                   child: Container(
//                     decoration: BoxDecoration(
//                         borderRadius:
//                             const BorderRadius.all(Radius.circular(6.0)),
//                         border: Border.all(
//                           width: 2.0,
//                           color: selected ? Colors.black : Colors.transparent,
//                         )),
//                     child: Column(
//                       textDirection: TextDirection.ltr,
//                       mainAxisSize: MainAxisSize.max,
//                       crossAxisAlignment: CrossAxisAlignment.stretch,
//                       children: [
//                         media != null
//                             ? media!.metadata.isVideo
//                                 ? video
//                                 : image
//                             : const SizedBox.shrink(),
//                         message.text?.isEmpty ?? true
//                             ? const SizedBox.shrink()
//                             : text,
//                         hasHeader ? header : const SizedBox.shrink(),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             )),
//       );
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedOpacity(
//       duration: const Duration(milliseconds: 600),
//       opacity: show ? 1 : 0,
//       curve: Curves.easeInOut,
//       child: Column(children: [chatMessage, const SizedBox(height: 4)]),
//     );
//   }
// }
