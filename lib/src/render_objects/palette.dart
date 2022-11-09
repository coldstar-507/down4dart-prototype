import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/down4_utility.dart';
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => goPress(id, location),
      onLongPress: () => goLongPress?.call(id, location),
      child: Container(
        padding: const EdgeInsets.all(2.0),
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
          fit: BoxFit.cover,
          gaplessPlayback: true,
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
}

class Palette extends StatelessWidget {
  final paletteHeight = Sizes.h * 0.08575;
  final AnimationController? _animationController;
  static const double height = 60.0;
  final BaseNode node;
  final String at;
  final void Function(String, String)? imPress,
      bodyPress,
      imLongPress,
      bodyLongPress;
  final bool selected;
  final List<ButtonsInfo> buttonsInfo;
  final String? messagePreview;
  final bool show, alignedRight;

  Image get nodeImage {
    switch (node.runtimeType) {
      case User:
        var user = node as User;
        return user.media != null
            ? Image.memory(user.media!.data, fit: BoxFit.cover)
            : Image.asset('lib/src/assets/hashirama.jpg', fit: BoxFit.cover);
      case GroupNode:
        var gn = node as GroupNode;
        return Image.memory(
          gn.media.data,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      case Payment:
        var pay = node as Payment;
        return pay.payment.independentGets < 2000000
            ? Image.asset('lib/src/assets/Dollar_Sign_1.png', fit: BoxFit.cover)
            : pay.payment.independentGets < 10000000
                ? Image.asset('lib/src/assets/Dollar_Sign_2.png',
                    fit: BoxFit.cover)
                : Image.asset('lib/src/assets/Dollar_Sign_3.png',
                    fit: BoxFit.cover);
    }
    throw 'stop breaking my app';
  }

  Palette({
    AnimationController? animationController,
    required this.node,
    required this.at,
    this.messagePreview,
    this.buttonsInfo = const [],
    this.imPress,
    this.bodyPress,
    this.imLongPress,
    this.bodyLongPress,
    this.selected = false,
    this.show = false,
    this.alignedRight = false,
    Key? key,
  })  : _animationController = animationController,
        super(key: key);

  Palette invertedSelection() {
    return Palette(
      animationController: _animationController,
      alignedRight: alignedRight,
      show: show,
      node: node,
      at: at,
      messagePreview: messagePreview,
      selected: !selected,
      imPress: imPress,
      buttonsInfo: buttonsInfo,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
    );
  }

  Palette animated(bool show, bool? alignedRight) {
    return Palette(
      show: show,
      alignedRight: alignedRight ?? this.alignedRight,
      node: node,
      at: at,
      messagePreview: messagePreview,
      selected: selected,
      imPress: imPress,
      buttonsInfo: buttonsInfo,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
    );
  }

  Palette withAnimationController(AnimationController ctrl) {
    return Palette(
      animationController: _animationController,
      alignedRight: alignedRight,
      show: show,
      node: node,
      at: at,
      messagePreview: messagePreview,
      selected: !selected,
      imPress: imPress,
      buttonsInfo: buttonsInfo,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
    );
  }

  Palette deactivated() {
    return Palette(
      node: node,
      at: at,
      buttonsInfo: const [],
    );
  }

  Widget get buttons => Row(
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
      );

  Widget animatedContainer2({required Widget child}) => AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        height: paletteHeight,
        width: show ? 400 : 0,
        clipBehavior: Clip.hardEdge,
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: show && !selected ? Colors.black54 : Colors.transparent,
              blurRadius: show && !selected ? 6.0 : 0.0,
              spreadRadius: -6.0,
              offset: show && !selected
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

  Widget animatedContainer({required Widget child}) =>
      _animationController != null
          ? SizeTransition(
              sizeFactor: CurvedAnimation(
                parent: _animationController!,
                curve: Curves.linear,
                reverseCurve: Curves.linear,
              ),
              axis: Axis.horizontal,
              axisAlignment: -1,
              child: child,
            )
          : Container(child: child);

  Widget mainContainer({required Widget child}) => Container(
        // height: paletteHeight,
        // width: 400,
        // margin: const EdgeInsets.only(left: 22.0, right: 22.0),
        decoration: BoxDecoration(
          // boxShadow: !selected
          //     ? [
          //         const BoxShadow(
          //           color: Colors.black54,
          //           blurRadius: 6.0,
          //           spreadRadius: -6.0,
          //           offset: Offset(8.0, 8.0),
          //           blurStyle: BlurStyle.normal,
          //         )
          //       ]
          //     : null,
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
          width: paletteHeight - 2.0, // borderWidth x2
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
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      )
                    : const SizedBox.shrink()
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    print("transitioning = $show");
    return Align(
      alignment: alignedRight ? Alignment.centerRight : Alignment.centerLeft,
      child: animatedContainer2(
        child: mainContainer(child: row(children: [image, body, buttons])),
        // child: mainContainer(
        //   child: row(children: [image, body, buttons]),
        // ),
      ),
    );
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
