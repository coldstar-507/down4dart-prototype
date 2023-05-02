import 'dart:convert';

import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';

import '../couch.dart';
import '../data_objects.dart';
import '../globals.dart';
import '../themes.dart';

// class BasicActionButton extends StatelessWidget {
//   final void Function(String, String) goPress;
//   final void Function(String, String)? goLongPress;
//   final bool rightMost;
//   final String location, id, assetPathFromLib;
//   // final Color? color;
//   const BasicActionButton({
//     required this.goPress,
//     required this.location,
//     required this.id,
//     required this.rightMost,
//     required this.assetPathFromLib,
//     // this.color = PinkTheme.headerColor,
//     this.goLongPress,
//     Key? key,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => goPress(id, location),
//       onLongPress: () => goLongPress?.call(id, location),
//       child: Container(
//         height: Palette.paletteHeight,
//         width: Palette.paletteHeight,
//         padding: const EdgeInsets.all(6.0),
//         decoration: BoxDecoration(
//           // color: color,
//           borderRadius: rightMost
//               ? const BorderRadius.only(
//                   topRight: Radius.circular(4.0),
//                   bottomRight: Radius.circular(4.0),
//                 )
//               : null,
//         ),
//         child: Image.asset(assetPathFromLib,
//             fit: BoxFit.contain, gaplessPlayback: true),
//       ),
//     );
//   }
// }

class BasicActionButton2 extends StatelessWidget {
  final ButtonsInfo2 bi;
  const BasicActionButton2({required this.bi, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: bi.pressFunc,
      onLongPress: bi.longPressFunc,
      child: Container(
          height: Palette.paletteHeight,
          width: Palette.paletteHeight,
          padding: const EdgeInsets.all(6.0),
          decoration: BoxDecoration(
              borderRadius: bi.rightMost
                  ? const BorderRadius.only(
                      topRight: Radius.circular(4.0),
                      bottomRight: Radius.circular(4.0))
                  : null),
          child: bi.asset),
    );
  }
}

// class ButtonsInfo {
//   final String assetPath;
//   final void Function(String, String) pressFunc;
//   final void Function(String, String)? longPressFunc;
//   final bool rightMost;
//   ButtonsInfo({
//     required this.assetPath,
//     required this.pressFunc,
//     required this.rightMost,
//     this.longPressFunc,
//   });
//
//   ButtonsInfo thatDoesNothing() => ButtonsInfo(
//         assetPath: assetPath,
//         pressFunc: (a, b) {},
//         rightMost: rightMost,
//       );
// }

class ButtonsInfo2 {
  final Image asset;
  final void Function() pressFunc;
  final void Function()? longPressFunc;
  final bool rightMost;
  ButtonsInfo2({
    required this.asset,
    required this.pressFunc,
    required this.rightMost,
    this.longPressFunc,
  });

  ButtonsInfo2 thatDoesNothing() => ButtonsInfo2(
        asset: asset,
        pressFunc: () {},
        rightMost: rightMost,
      );
}

class Palette2 extends StatelessWidget implements Down4Object {
  @override
  ID get id => node.id;
  final Widget _image;

  final FireNode node;
  final void Function()? imPress, imLongPress, bodyPress, bodyLongPress;
  final bool selected, fade, fadeButton, fold, squish, show;
  final List<ButtonsInfo2> buttonsInfo2;
  final int containerMS, fadeMS, fadeButtonMS;
  final String? messagePreview;

  Palette2({
    required this.node,
    this.fadeMS = 100,
    this.containerMS = 600,
    this.fadeButtonMS = 100,
    this.messagePreview,
    this.buttonsInfo2 = const [],
    this.imPress,
    this.bodyPress,
    this.imLongPress,
    this.bodyLongPress,
    this.selected = false,
    this.squish = true,
    this.fold = false,
    this.fadeButton = false,
    this.show = true,
    this.fade = false,
    required Key key,
  })  : _image = GestureDetector(
            onTap: imPress, onLongPress: imLongPress, child: node.nodeImage()),
        super(key: key);

  Palette2 select() {
    return Palette2(
      key: key!,
      fold: fold,
      squish: squish,
      show: show,
      node: node,
      fade: fade,
      fadeButton: fadeButton,
      fadeButtonMS: fadeButtonMS,
      fadeMS: fadeMS,
      messagePreview: messagePreview,
      selected: !selected,
      imPress: imPress,
      buttonsInfo2: buttonsInfo2,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
    );
  }

  Palette2 showing(bool s) {
    return Palette2(
      key: key!,
      fold: fold,
      squish: squish,
      show: s,
      node: node,
      fade: fade,
      fadeButton: fadeButton,
      fadeButtonMS: fadeButtonMS,
      fadeMS: fadeMS,
      messagePreview: messagePreview,
      selected: selected,
      imPress: imPress,
      buttonsInfo2: buttonsInfo2,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
    );
  }

  Palette2 animated({
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
    return Palette2(
      key: key!,
      fadeButton: fadeButton ?? this.fadeButton,
      squish: squish ?? this.squish,
      fold: fold ?? this.fold,
      node: node,
      // image: image,
      messagePreview: messagePreview,
      selected: selected ?? this.selected,
      imPress: imPress,
      buttonsInfo2: buttonsInfo2,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
      fade: fade ?? this.fade,
      containerMS: containerMS ?? this.containerMS,
      fadeMS: fadeMS ?? this.fadeMS,
      fadeButtonMS: fadeButtonMS ?? this.fadeButtonMS,
    );
  }

  Palette2 deactivated() {
    return Palette2(
        key: key!,
        squish: squish,
        fold: fold,
        messagePreview: messagePreview,
        node: node,
        buttonsInfo2: buttonsInfo2
            .map((button) => button.thatDoesNothing())
            .toList(growable: false));
  }

  Palette2 withoutButton() {
    return Palette2(
        squish: squish, fold: fold, node: node, key: key!); //, image: image);
  }

  Palette2 copy() {
    return Palette2(
        key: key!,
        fold: fold,
        squish: squish,
        node: node,
        fade: fade,
        // image: image,
        fadeButton: fadeButton,
        fadeButtonMS: fadeButtonMS,
        fadeMS: fadeMS,
        messagePreview: messagePreview,
        selected: selected,
        imPress: imPress,
        buttonsInfo2: buttonsInfo2,
        imLongPress: imLongPress,
        bodyPress: bodyPress,
        bodyLongPress: bodyLongPress);
  }

  Widget get buttons => AnimatedOpacity(
      opacity: fadeButton ? 0 : 1,
      curve: Curves.easeInOut,
      duration: Duration(milliseconds: fadeButtonMS),
      child: Row(
        children: buttonsInfo2.map((bi) => BasicActionButton2(bi: bi)).toList(),
      ));

  Widget animatedContainer2({required Widget child}) => AnimatedContainer(
        duration: Duration(milliseconds: containerMS),
        height: fold ? 0 : Palette.paletteHeight,
        // width: squish ? 0 : null,
        clipBehavior: Clip.hardEdge,
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(horizontal: Palette.paletteMargin),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: squish && !selected && !fold
                  ? Palette.shadowColor
                  : Colors.transparent,
              blurRadius:
                  squish && !selected && !fold ? Palette.blurRadius : 0.0,
              spreadRadius: Palette.spreadRadius,
              offset: squish && !selected && !fold
                  ? Palette.shadowOffset
                  : const Offset(0, 0),
              blurStyle: BlurStyle.normal,
            ),
          ],
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

  Widget get body => Expanded(
        child: GestureDetector(
          onTap: bodyPress,
          onLongPress: bodyLongPress,
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
                Text(node.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                        overflow: TextOverflow.ellipsis,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal)),
                Text(node.displayID,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                        fontSize: 8,
                        fontStyle: FontStyle.italic,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal)),
                const SizedBox(height: 5),
                messagePreview != null
                    ? Text(messagePreview!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: !selected
                                ? FontWeight.normal
                                : FontWeight.bold))
                    : const SizedBox.shrink()
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: fade ? 0 : 1,
      curve: Curves.easeInOut,
      duration: Duration(milliseconds: fadeMS),
      child: Column(children: [
        animatedContainer2(
          child: mainContainer(
            child: row(children: [_image, body, buttons]),
          ),
        ),
        AnimatedContainer(
            duration: Duration(milliseconds: containerMS),
            curve: Curves.easeInOut,
            height: fold ? 0 : Palette.gapSize),
      ]),
    );
  }
}

class Palette {
  static double get paletteHeight => g.sizes.h * 0.1136;
  static double get gapSize => g.sizes.h * 0.0119;
  static double get paletteMargin => g.sizes.w * 0.042;
  static double get blurRadius => 6.0;
  static double get spreadRadius => -7.0;
  static double get fullHeight => paletteHeight + gapSize;
  static Offset get shadowOffset => const Offset(6.0, 6.0);
  static Color get shadowColor => Colors.black.withOpacity(0.66);
  // final FireNode node;
  // final String at;
  // final void Function(String, String)? imPress,
  //     bodyPress,
  //     imLongPress,
  //     bodyLongPress;
  // final bool selected, messagePreviewWasRead, snipOrMessageToRead;
  // final List<ButtonsInfo> buttonsInfo;
  // final String? messagePreview;
  // final bool squish, alignedRight, fold, fadeButton, fade;
  // final int containerMS, fadeMS, fadeButtonMS;

  // Image get nodeImage {
  //   FireNode n = node;
  //   if (n is User) {
  //     return n.media != null
  //         ? Image.memory(n.media!.data,
  //             fit: BoxFit.cover, gaplessPlayback: true)
  //         : Image.asset('assets/images/hashirama.jpg', fit: BoxFit.cover);
  //   } else if (n is Groupable) {
  //     return Image.memory(n.media.data,
  //         fit: BoxFit.cover, gaplessPlayback: true);
  //   } else if (n is Payment) {
  //     return n.payment.independentGets < 2000000
  //         ? Image.asset('assets/images/Dollar_Sign_1.png', fit: BoxFit.cover)
  //         : n.payment.independentGets < 10000000
  //             ? Image.asset('assets/images/Dollar_Sign_2.png',
  //                 fit: BoxFit.cover)
  //             : Image.asset('assets/images/Dollar_Sign_3.png',
  //                 fit: BoxFit.cover);
  //   } else if (n is Self) {
  //     return Image.memory(n.media.data,
  //         fit: BoxFit.cover, gaplessPlayback: true);
  //   }
  //   throw 'stop breaking my app';
  // }

  // const Palette({
  //   required this.node,
  //   required this.at,
  //   this.fadeMS = 100,
  //   this.containerMS = 600,
  //   this.fadeButtonMS = 100,
  //   this.messagePreview,
  //   this.buttonsInfo = const [],
  //   this.imPress,
  //   this.bodyPress,
  //   this.imLongPress,
  //   this.bodyLongPress,
  //   this.selected = false,
  //   this.messagePreviewWasRead = false,
  //   this.snipOrMessageToRead = false,
  //   this.squish = true,
  //   this.fold = false,
  //   this.alignedRight = false,
  //   this.fadeButton = false,
  //   this.fade = false,
  //   Key? key,
  // }) : super(key: key);

  // Palette invertedSelection() {
  //   return Palette(
  //     fold: fold,
  //     alignedRight: alignedRight,
  //     squish: squish,
  //     node: node,
  //     at: at,
  //     fade: fade,
  //     fadeButton: fadeButton,
  //     fadeButtonMS: fadeButtonMS,
  //     fadeMS: fadeMS,
  //     messagePreview: messagePreview,
  //     snipOrMessageToRead: snipOrMessageToRead,
  //     selected: !selected,
  //     imPress: imPress,
  //     buttonsInfo: buttonsInfo,
  //     messagePreviewWasRead: messagePreviewWasRead,
  //     imLongPress: imLongPress,
  //     bodyPress: bodyPress,
  //     bodyLongPress: bodyLongPress,
  //   );
  // }

  // Palette animated({
  //   bool? squish,
  //   bool? alignedRight,
  //   bool? fold,
  //   bool? fade,
  //   bool? selected,
  //   bool? fadeButton,
  //   int? containerMS,
  //   int? fadeMS,
  //   int? fadeButtonMS,
  // }) {
  //   return Palette(
  //     fadeButton: fadeButton ?? this.fadeButton,
  //     squish: squish ?? this.squish,
  //     alignedRight: alignedRight ?? this.alignedRight,
  //     fold: fold ?? this.fold,
  //     node: node,
  //     at: at,
  //     snipOrMessageToRead: snipOrMessageToRead,
  //     messagePreviewWasRead: messagePreviewWasRead,
  //     messagePreview: messagePreview,
  //     selected: selected ?? this.selected,
  //     imPress: imPress,
  //     buttonsInfo: buttonsInfo,
  //     imLongPress: imLongPress,
  //     bodyPress: bodyPress,
  //     bodyLongPress: bodyLongPress,
  //     fade: fade ?? this.fade,
  //     containerMS: containerMS ?? this.containerMS,
  //     fadeMS: fadeMS ?? this.fadeMS,
  //     fadeButtonMS: fadeButtonMS ?? this.fadeButtonMS,
  //   );
  // }

  // Palette deactivated() {
  //   return Palette(
  //     squish: squish,
  //     fold: fold,
  //     alignedRight: alignedRight,
  //     messagePreview: messagePreview,
  //     node: node,
  //     at: at,
  //     buttonsInfo: buttonsInfo
  //         .map((button) => button.thatDoesNothing())
  //         .toList(growable: false),
  //   );
  // }

  // Palette withoutButton() {
  //   return Palette(
  //     squish: squish,
  //     fold: fold,
  //     alignedRight: alignedRight,
  //     node: node,
  //     at: at,
  //   );
  // }

  // Widget get buttons => AnimatedOpacity(
  //     opacity: fadeButton ? 0 : 1,
  //     curve: Curves.easeInOut,
  //     duration: Duration(milliseconds: fadeButtonMS),
  //     child: Row(
  //       children: buttonsInfo
  //           .map((e) => BasicActionButton(
  //                 goPress: e.pressFunc,
  //                 goLongPress: e.longPressFunc,
  //                 location: at,
  //                 id: node.id,
  //                 rightMost: e.rightMost,
  //                 assetPathFromLib: e.assetPath,
  //               ))
  //           .toList(),
  //     ));

  // Widget animatedContainer2({required Widget child}) => AnimatedContainer(
  //       duration: Duration(milliseconds: containerMS),
  //       height: fold ? 0 : paletteHeight,
  //       // width: squish ? 0 : null,
  //       clipBehavior: Clip.hardEdge,
  //       curve: Curves.easeInOut,
  //       margin: EdgeInsets.symmetric(horizontal: paletteMargin),
  //       decoration: BoxDecoration(
  //         boxShadow: [
  //           BoxShadow(
  //             color: squish && !selected && !fold
  //                 ? shadowColor
  //                 : Colors.transparent,
  //             blurRadius: squish && !selected && !fold ? blurRadius : 0.0,
  //             spreadRadius: spreadRadius,
  //             offset: squish && !selected && !fold
  //                 ? shadowOffset
  //                 : const Offset(0, 0),
  //             blurStyle: BlurStyle.normal,
  //           ),
  //         ],
  //       ),
  //       child: child,
  //     );

  // Widget mainContainer({required Widget child}) => Container(
  //       decoration: BoxDecoration(
  //         borderRadius: const BorderRadius.all(Radius.circular(6.0)),
  //         border: Border.all(
  //           width: 2.0,
  //           color: selected ? PinkTheme.black : Colors.transparent,
  //         ),
  //       ),
  //       child: child,
  //     );

  // Widget row({required List<Widget> children}) => Container(
  //       clipBehavior: Clip.hardEdge,
  //       decoration: BoxDecoration(
  //         color: PinkTheme.nodeColors[node.colorCode],
  //         borderRadius: const BorderRadius.all(Radius.circular(4.0)),
  //       ),
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.stretch,
  //         textDirection: TextDirection.ltr,
  //         children: children,
  //       ),
  //     );

  // Widget get image => GestureDetector(
  //       onTap: () => imPress?.call(node.id, at),
  //       onLongPress: () => imLongPress?.call(node.id, at),
  //       child: SizedBox(
  //         width: paletteHeight - 4.0,
  //         height: paletteHeight - 4.0, // borderWidth x2
  //         child: nodeImage,
  //       ),
  //     );

  // Widget get body => Expanded(
  //       child: GestureDetector(
  //         onTap: () => bodyPress?.call(node.id, at),
  //         onLongPress: () => bodyLongPress?.call(node.id, at),
  //         child: Container(
  //           decoration: BoxDecoration(
  //             border: Border(
  //               left: BorderSide(
  //                 color: selected
  //                     ? PinkTheme.black
  //                     : PinkTheme.nodeColors[node.colorCode]!,
  //                 width: 1.0,
  //               ),
  //             ),
  //           ),
  //           padding: const EdgeInsets.only(left: 6.0, top: 5.0),
  //           child: Column(
  //             mainAxisAlignment: MainAxisAlignment.start,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 node.name,
  //                 maxLines: 1,
  //                 overflow: TextOverflow.clip,
  //                 style: TextStyle(
  //                   overflow: TextOverflow.ellipsis,
  //                   fontSize: 14,
  //                   fontWeight: selected ? FontWeight.bold : FontWeight.normal,
  //                 ),
  //               ),
  //               Text(
  //                 node.displayID,
  //                 maxLines: 1,
  //                 overflow: TextOverflow.clip,
  //                 style: TextStyle(
  //                   fontSize: 8,
  //                   fontStyle: FontStyle.italic,
  //                   fontWeight: selected ? FontWeight.bold : FontWeight.normal,
  //                 ),
  //               ),
  //               const SizedBox(height: 5),
  //               messagePreview != null
  //                   ? Text(
  //                       messagePreview!,
  //                       overflow: TextOverflow.ellipsis,
  //                       maxLines: 1,
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         fontWeight:
  //                             !selected ? FontWeight.normal : FontWeight.bold,
  //                       ),
  //                     )
  //                   : const SizedBox.shrink()
  //             ],
  //           ),
  //         ),
  //       ),
  //     );

  // @override
  // Widget build(BuildContext context) {
  //   return AnimatedOpacity(
  //       opacity: fade ? 0 : 1,
  //       curve: Curves.easeInOut,
  //       duration: Duration(milliseconds: fadeMS),
  //       child: Align(
  //         alignment:
  //             alignedRight ? Alignment.centerRight : Alignment.centerLeft,
  //         child: Column(children: [
  //           animatedContainer2(
  //             child:
  //                 mainContainer(child: row(children: [image, body, buttons])),
  //           ),
  //           AnimatedContainer(
  //               duration: Duration(milliseconds: containerMS),
  //               curve: Curves.easeInOut,
  //               height: fold ? 0 : gapSize),
  //         ]),
  //       ));
  // }
}
