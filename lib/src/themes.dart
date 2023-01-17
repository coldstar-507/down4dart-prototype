import 'data_objects.dart';
import 'package:flutter/material.dart';

class PinkTheme {
  static const buttonColor = Color.fromARGB(255, 250, 222, 224);
  static const myBubblesColor = Color.fromARGB(255, 252, 213, 216);
  // static const selfPaletteColor = Color.fromARGB(255, 199, 118, 132);
  static const bodyColor = buttonColor;
  static const inactivatedButtonColor = Color.fromARGB(255, 219, 214, 214);
  static const backGroundColor = Color.fromARGB(255, 255, 241, 242);
  static const headerColor = Color.fromARGB(255, 236, 155, 182);
  static const imageBorderColor = Color.fromARGB(255, 143, 29, 67);
  static const borderColor = Colors.black;
  static const qrColor = Color.fromARGB(255, 56, 3, 17);
  static const black = Colors.black;
  static const snipRibbon = Color.fromARGB(153, 255, 241, 242);
  static const Map<NodesColor, Color> nodeColors = {
    NodesColor.root: Color.fromARGB(255, 53, 3, 20),
    NodesColor.hyperchat: Color.fromARGB(255, 212, 168, 182),
    NodesColor.checkpoint: Color.fromARGB(255, 22, 94, 161),
    NodesColor.event: Color.fromARGB(255, 95, 28, 219),
    NodesColor.item: Color.fromARGB(255, 187, 108, 34),
    NodesColor.journal: Color.fromARGB(255, 90, 62, 134),
    NodesColor.market: Color.fromARGB(255, 34, 134, 64),
    NodesColor.ticket: Color.fromARGB(255, 233, 220, 30),
    NodesColor.friend: Color.fromARGB(255, 230, 174, 193),
    NodesColor.self: Color.fromARGB(255, 199, 118, 132),
    NodesColor.group: Color.fromARGB(255, 175, 134, 209),
    NodesColor.nonFriend: Color.fromARGB(255, 158, 92, 114),
    NodesColor.unsafeTx: Colors.red,
    NodesColor.mediumTx: Colors.yellow,
    NodesColor.safeTx: Colors.green,
  };
}
