import 'package:flutter/material.dart';
import 'package:down4/src/down4_utility.dart';
import 'package:hive/hive.dart';

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';

class BasicActionButton extends StatelessWidget {
  final void Function(String, String) goPress;
  final void Function(String, String)? goLongPress;
  final bool rightMost;
  final String location, id, assetPathFromLib;
  final Color? color;
  const BasicActionButton({
    required this.goPress,
    required this.location,
    required this.id,
    required this.rightMost,
    required this.assetPathFromLib,
    this.color = PinkTheme.headerColor,
    this.goLongPress,
    Key? key,
  }) : super(key: key);

  // late final AnimationController scaleCtrl = AnimationController(
  //   vsync: this,
  //   duration: const Duration(milliseconds: 600),
  // );
  // late final Animation<double> _animation = CurvedAnimation(
  //   parent: scaleCtrl,
  //   curve: Curves.easeOut,
  // );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => goPress(id, location),
      onLongPress: () => goLongPress?.call(id, location),
      child: Container(
        height: Palette.height,
        width: Palette.height,
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: rightMost
              ? const BorderRadius.only(
                  topRight: Radius.circular(4.0),
                  bottomRight: Radius.circular(4.0),
                )
              : null,
        ),
        child: Image.asset(
          assetPathFromLib,
          fit: BoxFit.contain,
          // gaplessPlayback: true,
        ),
      ),
    );
  }
}

class ButtonsInfo {
  final String assetPath;
  final void Function(String, String) pressFunc;
  final void Function(String, String)? longPressFunc;
  final bool rightMost;
  ButtonsInfo({
    required this.assetPath,
    required this.pressFunc,
    required this.rightMost,
    this.longPressFunc,
  });

  ButtonsInfo thatDoesNothing() => ButtonsInfo(
        assetPath: assetPath,
        pressFunc: (a, b) {},
        rightMost: rightMost,
      );
}

class Palette extends StatelessWidget {
  double get paletteHeight => Sizes.h * 0.08575;
  double get gapSize => Sizes.h * 0.02;
  static const double height = 60.0;
  final BaseNode node;
  final String at;
  final void Function(String, String)? imPress,
      bodyPress,
      imLongPress,
      bodyLongPress;
  final bool selected, messagePreviewWasRead, snipOrMessageToRead;
  final List<ButtonsInfo> buttonsInfo;
  final String? messagePreview;
  final bool squish, alignedRight, fold, fadeButton, fade;
  final int containerMS, fadeMS, fadeButtonMS;

  Image get nodeImage {
    Object n = node;
    if (n is User) {
      return n.media != null
          ? Image.memory(n.media!.data, fit: BoxFit.cover)
          : Image.asset('lib/src/assets/hashirama.jpg', fit: BoxFit.cover);
    } else if (n is GroupNode) {
      return Image.memory(
        n.media.data,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (n is Payment) {
      return n.payment.independentGets < 2000000
          ? Image.asset('lib/src/assets/Dollar_Sign_1.png', fit: BoxFit.cover)
          : n.payment.independentGets < 10000000
              ? Image.asset('lib/src/assets/Dollar_Sign_2.png',
                  fit: BoxFit.cover)
              : Image.asset('lib/src/assets/Dollar_Sign_3.png',
                  fit: BoxFit.cover);
    }
    // switch (node.runtimeType) {
    //   case User:
    //     var user = node as User;
    //     return user.media != null
    //         ? Image.memory(user.media!.data, fit: BoxFit.cover)
    //         : Image.asset('lib/src/assets/hashirama.jpg', fit: BoxFit.cover);
    //   case GroupNode:
    //     var gn = node as GroupNode;
    //     return Image.memory(
    //       gn.media.data,
    //       fit: BoxFit.cover,
    //       gaplessPlayback: true,
    //     );
    //   case Payment:
    //     var pay = node as Payment;
    //     return pay.payment.independentGets < 2000000
    //         ? Image.asset('lib/src/assets/Dollar_Sign_1.png', fit: BoxFit.cover)
    //         : pay.payment.independentGets < 10000000
    //             ? Image.asset('lib/src/assets/Dollar_Sign_2.png',
    //                 fit: BoxFit.cover)
    //             : Image.asset('lib/src/assets/Dollar_Sign_3.png',
    //                 fit: BoxFit.cover);
    // }
    throw 'stop breaking my app';
  }

  const Palette({
    required this.node,
    required this.at,
    this.fadeMS = 100,
    this.containerMS = 600,
    this.fadeButtonMS = 100,
    this.messagePreview,
    this.buttonsInfo = const [],
    this.imPress,
    this.bodyPress,
    this.imLongPress,
    this.bodyLongPress,
    this.selected = false,
    this.messagePreviewWasRead = false,
    this.snipOrMessageToRead = false,
    this.squish = true,
    this.fold = false,
    this.alignedRight = false,
    this.fadeButton = false,
    this.fade = false,
    Key? key,
  }) : super(key: key);

  Palette invertedSelection() {
    return Palette(
      fold: fold,
      alignedRight: alignedRight,
      squish: squish,
      node: node,
      at: at,
      messagePreview: messagePreview,
      snipOrMessageToRead: snipOrMessageToRead,
      selected: !selected,
      imPress: imPress,
      buttonsInfo: buttonsInfo,
      messagePreviewWasRead: messagePreviewWasRead,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
    );
  }

  Palette animated({
    bool? squish,
    bool? alignedRight,
    bool? fold,
    bool? fade,
    bool? selected,
    bool? fadeButton,
    int? containerMS,
    int? fadeMS,
    int? fadeButtonMS,
  }) {
    return Palette(
      fadeButton: fadeButton ?? this.fadeButton,
      squish: squish ?? this.squish,
      alignedRight: alignedRight ?? this.alignedRight,
      fold: fold ?? this.fold,
      node: node,
      at: at,
      snipOrMessageToRead: snipOrMessageToRead,
      messagePreviewWasRead: messagePreviewWasRead,
      messagePreview: messagePreview,
      selected: selected ?? this.selected,
      imPress: imPress,
      buttonsInfo: buttonsInfo,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
      fade: fade ?? this.fade,
      containerMS: containerMS ?? this.containerMS,
      fadeMS: fadeMS ?? this.fadeMS,
      fadeButtonMS: fadeButtonMS ?? this.fadeButtonMS,
    );
  }

  Palette deactivated() {
    return Palette(
      squish: squish,
      fold: fold,
      alignedRight: alignedRight,
      messagePreview: messagePreview,
      node: node,
      at: at,
      buttonsInfo: buttonsInfo
          .map((button) => button.thatDoesNothing())
          .toList(growable: false),
    );
  }

  Palette withoutButton() {
    return Palette(
      squish: squish,
      fold: fold,
      alignedRight: alignedRight,
      node: node,
      at: at,
    );
  }

  Widget get buttons => AnimatedOpacity(
      opacity: fadeButton ? 0 : 1,
      // : snipOrMessageToRead
      //     ? 1
      //     : 0.50,
      curve: Curves.easeOut,
      duration: Duration(milliseconds: fadeButtonMS),
      child: Row(
        children: buttonsInfo
            .map((e) => BasicActionButton(
                  color: PinkTheme.nodeColors[node.colorCode],
                  goPress: e.pressFunc,
                  goLongPress: e.longPressFunc,
                  location: at,
                  id: node.id,
                  rightMost: e.rightMost,
                  assetPathFromLib: e.assetPath,
                ))
            .toList(),
      ));

  Widget animatedContainer2({required Widget child}) => AnimatedContainer(
        duration: Duration(milliseconds: containerMS),
        height: fold ? 0 : paletteHeight,
        // width: squish ? 0 : null,
        clipBehavior: Clip.hardEdge,
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: squish && !selected && !fold
                  ? Colors.black54
                  : Colors.transparent,
              blurRadius: squish && !selected && !fold ? 6.0 : 0.0,
              spreadRadius: -6.0,
              offset: squish && !selected && !fold
                  ? const Offset(6.0, 6.0)
                  : const Offset(0, 0),
              blurStyle: BlurStyle.normal,
            ),
          ],
          // borderRadius: const BorderRadius.all(Radius.circular(6.0)),
          // border: Border.all(
          //   width: 2.0,
          //   color: selected ? PinkTheme.black : Colors.transparent,
          // ),
        ),
        child: child,
      );

  Widget mainContainer({required Widget child}) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(6.0)),
          border: Border.all(
            width: 2.0,
            color: selected ? PinkTheme.black : Colors.transparent,
          ),
        ),
        child: child,
      );

  Widget row({required List<Widget> children}) => Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: PinkTheme.nodeColors[node.colorCode],
          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          textDirection: TextDirection.ltr,
          children: children,
        ),
      );

  Widget get image => GestureDetector(
        onTap: () => imPress?.call(node.id, at),
        onLongPress: () => imLongPress?.call(node.id, at),
        child: SizedBox(
          width: paletteHeight - 4.0,
          height: paletteHeight - 4.0, // borderWidth x2
          child: nodeImage,
        ),
      );

  Widget get body => Expanded(
        child: GestureDetector(
          onTap: () => bodyPress?.call(node.id, at),
          onLongPress: () => bodyLongPress?.call(node.id, at),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected
                      ? PinkTheme.black
                      : PinkTheme.nodeColors[node.colorCode]!,
                  width: 1.0,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 6.0, top: 5.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    overflow: TextOverflow.ellipsis,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  node.displayID,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 8,
                    fontStyle: FontStyle.italic,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 5),
                messagePreview != null
                    ? Text(
                        messagePreview!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          // fontStyle: messagePreviewWasRead
                          //     ? FontStyle.normal
                          //     : FontStyle.italic,
                          fontWeight:
                              !selected ? FontWeight.normal : FontWeight.bold,
                        ),
                      )
                    : const SizedBox.shrink()
              ],
            ),
          ),
        ),
      );

  // Widget shadowContainer({required Widget child}) => SizedBox(
  //       height: paletteHeight,
  //       child: AnimatedContainer(
  //         duration: Duration(milliseconds: containerMS),
  //         clipBehavior: Clip.hardEdge,
  //         curve: Curves.easeOut,
  //         decoration: BoxDecoration(
  //           boxShadow: [
  //             BoxShadow(
  //               color: squish && !selected && !fold
  //                   ? Colors.black54
  //                   : Colors.transparent,
  //               blurRadius: squish && !selected && !fold ? 6.0 : 0.0,
  //               spreadRadius: -6.0,
  //               offset: squish && !selected && !fold
  //                   ? const Offset(6.0, 6.0)
  //                   : const Offset(0, 0),
  //               blurStyle: BlurStyle.normal,
  //             ),
  //           ],
  //         ),
  //         child: child,
  //       ),
  //     );

  // Widget get thePalette => AnimatedContainer(
  //       margin: const EdgeInsets.symmetric(horizontal: 22.0),
  //       duration: Duration(milliseconds: containerMS),
  //       height: fold ? 0 : gapSize + paletteHeight,
  //       curve: Curves.easeOut,
  //       decoration: BoxDecoration(
  //         boxShadow: [
  //           BoxShadow(
  //             color: squish && !selected && !fold
  //                 ? Colors.black54
  //                 : Colors.transparent,
  //             blurRadius: squish && !selected && !fold ? 6.0 : 0.0,
  //             spreadRadius: -6.0,
  //             offset: squish && !selected && !fold
  //                 ? const Offset(6.0, 6.0)
  //                 : const Offset(0, 0),
  //             blurStyle: BlurStyle.normal,
  //           ),
  //         ],
  //         // borderRadius: const BorderRadius.all(Radius.circular(6.0)),
  //         // border: Border.all(
  //         //   width: 2.0,
  //         //   color: selected ? PinkTheme.black : Colors.transparent,
  //         // ),
  //       ),
  //       child: Column(
  //         children: [
  //           shadowContainer(
  //               child: mainContainer(
  //                   child: row(children: [image, body, buttons]))),
  //           SizedBox(height: gapSize),
  //         ],
  //       ),
  //     );

  @override
  Widget build(BuildContext context) {
    // return AnimatedOpacity(
    //   opacity: fade ? 0 : 1,
    //   duration: Duration(milliseconds: fadeMS),
    //   curve: Curves.easeOut,
    //   child: Align(
    //     alignment: alignedRight ? Alignment.centerRight : Alignment.centerLeft,
    //     child: thePalette,
    //   ),
    // );

    return AnimatedOpacity(
        opacity: fade ? 0 : 1,
        curve: Curves.easeOut,
        duration: Duration(milliseconds: fadeMS),
        child: Align(
          alignment:
              alignedRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(children: [
            animatedContainer2(
              child:
                  mainContainer(child: row(children: [image, body, buttons])),
            ),
            AnimatedContainer(
                duration: Duration(milliseconds: containerMS),
                curve: Curves.easeOut,
                height: fold ? 0 : gapSize),
          ]),
        ));
    // return Container(
    //   height: paletteHeight,
    //   margin: const EdgeInsets.only(left: 22.0, right: 22.0),
    //   decoration: BoxDecoration(
    //     boxShadow: !selected
    //         ? [
    //             const BoxShadow(
    //               color: Colors.black54,
    //               blurRadius: 6.0,
    //               spreadRadius: -6.0,
    //               offset: Offset(8.0, 8.0),
    //               blurStyle: BlurStyle.normal,
    //             )
    //           ]
    //         : null,
    //     borderRadius: const BorderRadius.all(Radius.circular(6.0)),
    //     border: Border.all(
    //       width: 2.0,
    //       color: selected ? PinkTheme.black : Colors.transparent,
    //     ),
    //   ),
    //   child: Container(
    //     clipBehavior: Clip.hardEdge,
    //     decoration: BoxDecoration(
    //       color: PinkTheme.nodeColors[node.colorCode],
    //       borderRadius: const BorderRadius.all(Radius.circular(4.0)),
    //     ),
    //     child: Row(
    //       crossAxisAlignment: CrossAxisAlignment.stretch,
    //       textDirection: TextDirection.ltr,
    //       children: [
    //         GestureDetector(
    //           onTap: () => imPress?.call(node.id, at),
    //           onLongPress: () => imLongPress?.call(node.id, at),
    //           child: SizedBox(
    //             width: paletteHeight - 2.0, // borderWidth x2
    //             child: node.image,
    //           ),
    //         ),
    //         Expanded(
    //           child: GestureDetector(
    //             onTap: () => bodyPress?.call(node.id, at),
    //             onLongPress: () => bodyLongPress?.call(node.id, at),
    //             child: Container(
    //               decoration: BoxDecoration(
    //                 border: Border(
    //                   left: BorderSide(
    //                     color: selected
    //                         ? PinkTheme.black
    //                         : PinkTheme.nodeColors[node.colorCode]!,
    //                     width: 1.0,
    //                   ),
    //                 ),
    //               ),
    //               padding: const EdgeInsets.only(left: 6.0, top: 5.0),
    //               child: Column(
    //                 mainAxisAlignment: MainAxisAlignment.start,
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Text(
    //                     node.name,
    //                     maxLines: 1,
    //                     style: TextStyle(
    //                       overflow: TextOverflow.ellipsis,
    //                       fontSize: 14,
    //                       fontWeight:
    //                           selected ? FontWeight.bold : FontWeight.normal,
    //                     ),
    //                   ),
    //                   Text(
    //                     node.displayID,
    //                     style: TextStyle(
    //                       fontSize: 8,
    //                       fontStyle: FontStyle.italic,
    //                       fontWeight:
    //                           selected ? FontWeight.bold : FontWeight.normal,
    //                     ),
    //                   ),
    //                   const SizedBox(height: 5),
    //                   messagePreview != null
    //                       ? Text(
    //                           messagePreview!,
    //                           overflow: TextOverflow.ellipsis,
    //                           maxLines: 1,
    //                           style: TextStyle(
    //                             fontSize: 12,
    //                             fontWeight: selected
    //                                 ? FontWeight.bold
    //                                 : FontWeight.normal,
    //                           ),
    //                         )
    //                       : const SizedBox.shrink()
    //                 ],
    //               ),
    //             ),
    //           ),
    //         ),
    //         Row(
    //             children: buttonsInfo
    //                 .map((e) => BasicActionButton(
    //                       color: PinkTheme.nodeColors[node.colorCode],
    //                       goPress: e.pressFunc,
    //                       goLongPress: e.longPressFunc,
    //                       location: at,
    //                       id: node.id,
    //                       rightMost: e.rightMost,
    //                       assetPathFromLib: e.assetPath,
    //                     ))
    //                 .toList())
    //       ],
    //     ),
    //   ),
    // );
  }
}

// class Palette2 extends StatefulWidget {
//   final paletteHeight = Sizes.h * 0.08575;
//   static const double height = 60.0;
//   final BaseNode node;
//   final String at;
//   final void Function(String, String)? imPress,
//       bodyPress,
//       imLongPress,
//       bodyLongPress;
//   final bool selected;
//   final List<ButtonsInfo> buttonsInfo;
//   final String? messagePreview;
//   final bool expand, alignedRight, fold;
//
//   Image get nodeImage {
//     switch (node.runtimeType) {
//       case User:
//         var user = node as User;
//         return user.media != null
//             ? Image.memory(user.media!.data, fit: BoxFit.cover)
//             : Image.asset('lib/src/assets/hashirama.jpg', fit: BoxFit.cover);
//       case GroupNode:
//         var gn = node as GroupNode;
//         return Image.memory(
//           gn.media.data,
//           fit: BoxFit.cover,
//           gaplessPlayback: true,
//         );
//       case Payment:
//         var pay = node as Payment;
//         return pay.payment.independentGets < 2000000
//             ? Image.asset('lib/src/assets/Dollar_Sign_1.png', fit: BoxFit.cover)
//             : pay.payment.independentGets < 10000000
//                 ? Image.asset('lib/src/assets/Dollar_Sign_2.png',
//                     fit: BoxFit.cover)
//                 : Image.asset('lib/src/assets/Dollar_Sign_3.png',
//                     fit: BoxFit.cover);
//     }
//     throw 'stop breaking my app';
//   }
//
//   Palette invertedSelection() {
//     return Palette(
//       fold: fold,
//       alignedRight: alignedRight,
//       expand: expand,
//       node: node,
//       at: at,
//       messagePreview: messagePreview,
//       selected: !selected,
//       imPress: imPress,
//       buttonsInfo: buttonsInfo,
//       imLongPress: imLongPress,
//       bodyPress: bodyPress,
//       bodyLongPress: bodyLongPress,
//     );
//   }
//
//   Palette animated({bool? expand, bool? alignedRight, bool? fold}) {
//     return Palette(
//       expand: expand ?? this.expand,
//       alignedRight: alignedRight ?? this.alignedRight,
//       fold: fold ?? this.fold,
//       node: node,
//       at: at,
//       messagePreview: messagePreview,
//       selected: selected,
//       imPress: imPress,
//       buttonsInfo: buttonsInfo,
//       imLongPress: imLongPress,
//       bodyPress: bodyPress,
//       bodyLongPress: bodyLongPress,
//     );
//   }
//
//   Palette deactivated() {
//     return Palette(
//       expand: expand,
//       fold: fold,
//       alignedRight: alignedRight,
//       node: node,
//       at: at,
//       buttonsInfo: const [],
//     );
//   }
//
//   Palette2({
//     required this.node,
//     required this.at,
//     this.messagePreview,
//     this.buttonsInfo = const [],
//     this.imPress,
//     this.bodyPress,
//     this.imLongPress,
//     this.bodyLongPress,
//     this.selected = false,
//     this.expand = false,
//     this.fold = false,
//     this.alignedRight = false,
//     Key? key,
//   }) : super(key: key);
//
//   @override
//   State<Palette2> createState() => _Palette2State();
// }
//
// class _Palette2State extends State<Palette2> {
//   Widget get buttons => Row(
//         children: buttonsInfo
//             .map((e) => BasicActionButton(
//                   color: PinkTheme.nodeColors[node.colorCode],
//                   goPress: e.pressFunc,
//                   goLongPress: e.longPressFunc,
//                   location: at,
//                   id: node.id,
//                   rightMost: e.rightMost,
//                   assetPathFromLib: e.assetPath,
//                 ))
//             .toList(),
//       );
//
//   Widget animatedContainer2({required Widget child}) => AnimatedContainer(
//         duration: const Duration(milliseconds: 600),
//         height: fold ? 0 : paletteHeight,
//         width: expand ? 400 : 0,
//         clipBehavior: Clip.hardEdge,
//         curve: Curves.easeOut,
//         margin: const EdgeInsets.symmetric(horizontal: 22),
//         decoration: BoxDecoration(
//           boxShadow: [
//             BoxShadow(
//               color: expand && !selected && !fold
//                   ? Colors.black54
//                   : Colors.transparent,
//               blurRadius: expand && !selected && !fold ? 6.0 : 0.0,
//               spreadRadius: -6.0,
//               offset: expand && !selected && !fold
//                   ? const Offset(6.0, 6.0)
//                   : const Offset(0, 0),
//               blurStyle: BlurStyle.normal,
//             ),
//           ],
//           // borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//           // border: Border.all(
//           //   width: 2.0,
//           //   color: selected ? PinkTheme.black : Colors.transparent,
//           // ),
//         ),
//         child: child,
//       );
//
//   Widget mainContainer({required Widget child}) => Container(
//         decoration: BoxDecoration(
//           borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//           border: Border.all(
//             width: 2.0,
//             color: selected ? PinkTheme.black : Colors.transparent,
//           ),
//         ),
//         child: child,
//       );
//
//   Widget row({required List<Widget> children}) => Container(
//         clipBehavior: Clip.hardEdge,
//         decoration: BoxDecoration(
//           color: PinkTheme.nodeColors[node.colorCode],
//           borderRadius: const BorderRadius.all(Radius.circular(4.0)),
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           textDirection: TextDirection.ltr,
//           children: children,
//         ),
//       );
//
//   Widget get image => GestureDetector(
//         onTap: () => imPress?.call(node.id, at),
//         onLongPress: () => imLongPress?.call(node.id, at),
//         child: SizedBox(
//           width: paletteHeight - 2.0, // borderWidth x2
//           child: nodeImage,
//         ),
//       );
//
//   Widget get body => Expanded(
//         child: GestureDetector(
//           onTap: () => bodyPress?.call(node.id, at),
//           onLongPress: () => bodyLongPress?.call(node.id, at),
//           child: Container(
//             decoration: BoxDecoration(
//               border: Border(
//                 left: BorderSide(
//                   color: selected
//                       ? PinkTheme.black
//                       : PinkTheme.nodeColors[node.colorCode]!,
//                   width: 1.0,
//                 ),
//               ),
//             ),
//             padding: const EdgeInsets.only(left: 6.0, top: 5.0),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.start,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   node.name,
//                   maxLines: 1,
//                   overflow: TextOverflow.clip,
//                   style: TextStyle(
//                     overflow: TextOverflow.ellipsis,
//                     fontSize: 14,
//                     fontWeight: selected ? FontWeight.bold : FontWeight.normal,
//                   ),
//                 ),
//                 Text(
//                   node.displayID,
//                   maxLines: 1,
//                   overflow: TextOverflow.clip,
//                   style: TextStyle(
//                     fontSize: 8,
//                     fontStyle: FontStyle.italic,
//                     fontWeight: selected ? FontWeight.bold : FontWeight.normal,
//                   ),
//                 ),
//                 const SizedBox(height: 5),
//                 messagePreview != null
//                     ? Text(
//                         messagePreview!,
//                         overflow: TextOverflow.ellipsis,
//                         maxLines: 1,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight:
//                               selected ? FontWeight.bold : FontWeight.normal,
//                         ),
//                       )
//                     : const SizedBox.shrink()
//               ],
//             ),
//           ),
//         ),
//       );
//
//   @override
//   Widget build(BuildContext context) {
//     final gapSize = Sizes.h * 0.02;
//     return Align(
//       alignment: alignedRight ? Alignment.centerRight : Alignment.centerLeft,
//       child: Column(children: [
//         animatedContainer2(
//           child: mainContainer(child: row(children: [image, body, buttons])),
//         ),
//         AnimatedContainer(
//             duration: const Duration(milliseconds: 600),
//             curve: Curves.easeOut,
//             height: fold ? 0 : gapSize),
//       ]),
//     );
//     // return Container(
//     //   height: paletteHeight,
//     //   margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//     //   decoration: BoxDecoration(
//     //     boxShadow: !selected
//     //         ? [
//     //             const BoxShadow(
//     //               color: Colors.black54,
//     //               blurRadius: 6.0,
//     //               spreadRadius: -6.0,
//     //               offset: Offset(8.0, 8.0),
//     //               blurStyle: BlurStyle.normal,
//     //             )
//     //           ]
//     //         : null,
//     //     borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//     //     border: Border.all(
//     //       width: 2.0,
//     //       color: selected ? PinkTheme.black : Colors.transparent,
//     //     ),
//     //   ),
//     //   child: Container(
//     //     clipBehavior: Clip.hardEdge,
//     //     decoration: BoxDecoration(
//     //       color: PinkTheme.nodeColors[node.colorCode],
//     //       borderRadius: const BorderRadius.all(Radius.circular(4.0)),
//     //     ),
//     //     child: Row(
//     //       crossAxisAlignment: CrossAxisAlignment.stretch,
//     //       textDirection: TextDirection.ltr,
//     //       children: [
//     //         GestureDetector(
//     //           onTap: () => imPress?.call(node.id, at),
//     //           onLongPress: () => imLongPress?.call(node.id, at),
//     //           child: SizedBox(
//     //             width: paletteHeight - 2.0, // borderWidth x2
//     //             child: node.image,
//     //           ),
//     //         ),
//     //         Expanded(
//     //           child: GestureDetector(
//     //             onTap: () => bodyPress?.call(node.id, at),
//     //             onLongPress: () => bodyLongPress?.call(node.id, at),
//     //             child: Container(
//     //               decoration: BoxDecoration(
//     //                 border: Border(
//     //                   left: BorderSide(
//     //                     color: selected
//     //                         ? PinkTheme.black
//     //                         : PinkTheme.nodeColors[node.colorCode]!,
//     //                     width: 1.0,
//     //                   ),
//     //                 ),
//     //               ),
//     //               padding: const EdgeInsets.only(left: 6.0, top: 5.0),
//     //               child: Column(
//     //                 mainAxisAlignment: MainAxisAlignment.start,
//     //                 crossAxisAlignment: CrossAxisAlignment.start,
//     //                 children: [
//     //                   Text(
//     //                     node.name,
//     //                     maxLines: 1,
//     //                     style: TextStyle(
//     //                       overflow: TextOverflow.ellipsis,
//     //                       fontSize: 14,
//     //                       fontWeight:
//     //                           selected ? FontWeight.bold : FontWeight.normal,
//     //                     ),
//     //                   ),
//     //                   Text(
//     //                     node.displayID,
//     //                     style: TextStyle(
//     //                       fontSize: 8,
//     //                       fontStyle: FontStyle.italic,
//     //                       fontWeight:
//     //                           selected ? FontWeight.bold : FontWeight.normal,
//     //                     ),
//     //                   ),
//     //                   const SizedBox(height: 5),
//     //                   messagePreview != null
//     //                       ? Text(
//     //                           messagePreview!,
//     //                           overflow: TextOverflow.ellipsis,
//     //                           maxLines: 1,
//     //                           style: TextStyle(
//     //                             fontSize: 12,
//     //                             fontWeight: selected
//     //                                 ? FontWeight.bold
//     //                                 : FontWeight.normal,
//     //                           ),
//     //                         )
//     //                       : const SizedBox.shrink()
//     //                 ],
//     //               ),
//     //             ),
//     //           ),
//     //         ),
//     //         Row(
//     //             children: buttonsInfo
//     //                 .map((e) => BasicActionButton(
//     //                       color: PinkTheme.nodeColors[node.colorCode],
//     //                       goPress: e.pressFunc,
//     //                       goLongPress: e.longPressFunc,
//     //                       location: at,
//     //                       id: node.id,
//     //                       rightMost: e.rightMost,
//     //                       assetPathFromLib: e.assetPath,
//     //                     ))
//     //                 .toList())
//     //       ],
//     //     ),
//     //   ),
//     // );
//   }
// }
