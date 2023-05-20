import 'dart:convert';

import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/bsv/_bsv_utils.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';

import 'palette.dart';

import '../data_objects.dart';
import '../globals.dart';
import '../themes.dart';

import '../render_objects/lists.dart';

class ProfileWidget extends StatelessWidget implements Down4Object {
  @override
  ID get id => node.id;

  final FireNode node;
  const ProfileWidget({required this.node, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final node_ = node;
    final additionalGap = g.sizes.w * 0.02;
    final theGap = additionalGap + Palette.paletteMargin;
    final squareImageSize = g.sizes.w - 2 * theGap;
    return Container(
      clipBehavior: Clip.hardEdge,
      margin: EdgeInsets.only(
          left: theGap,
          right: theGap,
          top: theGap - Palette.gapSize,
          bottom: theGap),
      decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black54,
                blurRadius: 6.0,
                spreadRadius: -6.0,
                offset: Offset(8.0, 8.0),
                blurStyle: BlurStyle.normal)
          ],
          borderRadius: const BorderRadius.all(Radius.circular(16.0)),
          color: Colors.white10), // g.theme.nodeColors[node_.colorCode]),
      child: Column(
        children: [
          node.nodeImage(Size.square(squareImageSize)),
          const SizedBox(height: 8.0),
          Down4Text(
              text: node.displayName,
              style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: g.theme.font,
                  color: Colors.black)),
          // Text(node.name,
          //     style:
          //         const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
          //     textAlign: TextAlign.center,
          //     maxLines: 1),
          const SizedBox(height: 8.0),
          (node_ is Personable && (node_.description ?? "").isNotEmpty)
              ? Container(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(node_.description!, textAlign: TextAlign.justify))
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
