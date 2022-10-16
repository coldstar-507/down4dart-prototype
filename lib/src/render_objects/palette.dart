import 'package:flutter/material.dart';

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
  static const double height = 60.0;
  final Node node;
  final String at;
  final void Function(String, String)? imPress,
      bodyPress,
      imLongPress,
      bodyLongPress;
  final bool selected;
  final List<ButtonsInfo> buttonsInfo;
  final String? messagePreview;

  const Palette({
    required this.node,
    required this.at,
    this.messagePreview,
    this.buttonsInfo = const [],
    this.imPress,
    this.bodyPress,
    this.imLongPress,
    this.bodyLongPress,
    this.selected = false,
    Key? key,
  }) : super(key: key);

  Palette invertedSelection() {
    return Palette(
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

  @override
  Widget build(BuildContext context) {
    final paletteHeight = Sizes.h * 0.08575;
    return Container(
      height: paletteHeight,
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      decoration: BoxDecoration(
        boxShadow: !selected
            ? [
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 6.0,
            spreadRadius: -6.0,
            offset: Offset(8.0, 8.0),
            blurStyle: BlurStyle.normal,
          )
        ]
            : null,
        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        border: Border.all(
          width: 2.0,
          color: selected ? PinkTheme.black : Colors.transparent,
        ),
      ),
      child: Container(
        // color: PinkTheme.nodeColors[node.type],
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: PinkTheme.nodeColors[node.type],
          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          textDirection: TextDirection.ltr,
          children: [
            GestureDetector(
              onTap: () => imPress?.call(node.id, at),
              onLongPress: () => imLongPress?.call(node.id, at),
              child: SizedBox(
                width: paletteHeight - 2.0, // borderWidth x2
                child: node.image != null
                    ? Image.memory(
                  node.image!.data,
                  fit: BoxFit.cover,
                )
                    : Image.asset(
                  "lib/src/assets/hashirama.jpg",
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => bodyPress?.call(node.id, at),
                onLongPress: () => bodyLongPress?.call(node.id, at),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: selected
                            ? PinkTheme.black
                            : PinkTheme.nodeColors[node.type]!,
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
                        node.name + " " + (node.lastName ?? ""),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const [Nodes.user, Nodes.friend, Nodes.nonFriend]
                          .contains(node.type)
                          ? Text(
                        "@" + node.id,
                        style: TextStyle(
                          fontSize: 8,
                          fontStyle: FontStyle.italic,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      )
                          : const [Nodes.hyperchat, Nodes.group]
                          .contains(node.type)
                          ? Text(
                        node.group!.map((id) => "@" + id).join(" "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 8,
                          fontStyle: FontStyle.italic,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      )
                          : const SizedBox.shrink(),
                      const SizedBox(height: 5),
                      messagePreview != null
                          ? Text(
                        messagePreview!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      )
                          : const SizedBox.shrink()
                    ],
                  ),
                ),
              ),
            ),
            Row(
                children: buttonsInfo
                    .map((e) => BasicActionButton(
                  color: PinkTheme.nodeColors[node.type],
                  goPress: e.pressFunc,
                  goLongPress: e.longPressFunc,
                  location: at,
                  id: node.id,
                  rightMost: e.rightMost,
                  assetPathFromLib: e.assetPath,
                ))
                    .toList())
          ],
        ),
      ),
    );
  }
}