import 'package:flutter/material.dart';

import '../data_objects.dart';
import '../boxes.dart';
import '../themes.dart';

class ProfileWidget extends StatelessWidget {
  final Node node;
  const ProfileWidget({
    required this.node,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final squareImageSize = Sizes.w * 0.84;
    return Container(
      clipBehavior: Clip.hardEdge,
      width: squareImageSize,
      margin: EdgeInsets.only(
        left: Sizes.w * 0.08,
        right: Sizes.w * 0.08,
        top: (Sizes.w * 0.08) - (Sizes.w * 0.02),
      ),
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6.0,
            spreadRadius: -6.0,
            offset: Offset(8.0, 8.0),
            blurStyle: BlurStyle.normal,
          )
        ],
        borderRadius: BorderRadius.all(Radius.circular(16.0)),
        color: PinkTheme.buttonColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.memory(
            node.image!.data,
            fit: BoxFit.cover,
            width: squareImageSize,
            height: squareImageSize,
          ),
          const SizedBox(height: 8.0),
          Text(
            node.name + (node.lastName != null ? " " + node.lastName! : ""),
            style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8.0),
          Container(
              padding: const EdgeInsets.all(8.0),
              child: node.description != null &&
                  (node.description ?? "").isNotEmpty
                  ? Text(node.description!, textAlign: TextAlign.justify)
                  : const SizedBox.shrink()),
          node.description != null && (node.description ?? "").isNotEmpty
              ? const SizedBox(height: 8.0)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
