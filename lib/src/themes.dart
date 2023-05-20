import 'data_objects.dart';
import 'package:flutter/material.dart';

abstract class Down4Theme {
  String get font;
  Color get snipArrowColor;
  Color get messageArrowColor;
  Color get noMessageArrowColor;
  Color get idColor;
  Color get refreshIndicatorColor;
  Color get cursorColor;
  Color get messageSenderColor;
  Color get messageForwarderColor;
  Color get buttonColor;
  Color get myBubblesColor;
  Color get otherBubblesColor;
  // Color get consoleBorderColor;
  Color get bubbleTextColor;
  Color get bubbleTimestampTextColor;
  Color get inactivatedButtonColor;
  Color get backGroundColor;
  Color get headerColor;
  Color get headerTextColor;
  Color get paletteBorderColor;
  Color get paletteTextColor;
  Color get inputColor;
  Color get inputBorderColor;
  Color get consoleBorderColor;
  Color get inputTextColor;
  Color get buttonTextColor;
  Color get qrColor;
  Color get snipRibbon;
  TextStyle get inputTextStyle;
  TextStyle get chatBubbleTextStyle;
  TextStyle get chatBubbleDateTextStyle;
  TextStyle get chatRepilesTextStyle;
  TextStyle get inputPlaceholderTextStyle;
  TextStyle get consoleTextStyle;
  Map<NodesColor, Color> get nodeColors;
  Color get messageSelectionBorderColor;
  Color get messageSelectionOverlayColor;
  Color get messageShadowColor;
  Brightness get keyBoardTheme;
}

class BlackTheme implements Down4Theme {
  @override
  String get font => "Roboto";

  @override
  TextStyle get consoleTextStyle => TextStyle(
      fontFamily: font,
      fontSize: 14,
      overflow: TextOverflow.fade,
      color: Colors.amber,
      decorationStyle: TextDecorationStyle.solid,
      fontWeight: FontWeight.bold);

  @override
  TextStyle get chatRepilesTextStyle =>
      TextStyle(fontFamily: font, fontSize: 11, color: Colors.white54);

  @override
  TextStyle get chatBubbleTextStyle =>
      TextStyle(fontFamily: font, color: Colors.black);

  @override
  TextStyle get chatBubbleDateTextStyle => TextStyle(
      fontFamily: font, fontSize: 10, color: Colors.black45, height: 0.8);

  @override
  TextStyle get inputTextStyle =>
      TextStyle(fontFamily: font, fontSize: 16, color: Colors.white70);

  @override
  TextStyle get inputPlaceholderTextStyle =>
      TextStyle(fontFamily: font, fontSize: 16, color: Colors.white30);

  @override
  Color get idColor => Colors.white70;

  @override
  Color get consoleBorderColor => Colors.black;

  @override
  Color get refreshIndicatorColor => Colors.white;

  @override
  Color get cursorColor => Colors.black;

  @override
  Color get bubbleTextColor => Colors.black;

  @override
  Color get bubbleTimestampTextColor => const Color.fromARGB(255, 73, 73, 73);

  @override
  Color get buttonTextColor => const Color.fromARGB(110, 255, 255, 255);

  @override
  Color get headerTextColor => Colors.white;

  @override
  Color get inputBorderColor => const Color.fromARGB(255, 0, 0, 0);

  @override
  Color get inputColor => const Color.fromARGB(255, 37, 37, 37);

  @override
  Color get inputTextColor => const Color.fromARGB(255, 161, 161, 161);

  @override
  Color get paletteBorderColor => const Color.fromARGB(255, 255, 255, 255);

  @override
  Color get paletteTextColor => const Color.fromARGB(255, 201, 201, 201);

  @override
  Color get buttonColor => const Color.fromARGB(255, 0, 0, 0);

  @override
  Color get myBubblesColor => Colors.blueGrey.shade400;

  @override
  Color get otherBubblesColor => Colors.grey.shade500;

  @override
  Color get inactivatedButtonColor => const Color.fromARGB(255, 73, 73, 73);

  @override
  Color get backGroundColor => const Color.fromARGB(255, 0, 0, 0);

  @override
  Color get headerColor => const Color.fromARGB(255, 0, 0, 0);

  @override
  Color get qrColor => Colors.white;

  @override
  Color get snipRibbon => const Color.fromARGB(153, 255, 241, 242);

  @override
  Map<NodesColor, Color> get nodeColors => {
        NodesColor.root: const Color.fromARGB(255, 53, 3, 20),
        NodesColor.hyperchat: const Color.fromARGB(255, 47, 12, 22),
        NodesColor.checkpoint: const Color.fromARGB(255, 22, 94, 161),
        NodesColor.event: const Color.fromARGB(255, 95, 28, 219),
        NodesColor.item: const Color.fromARGB(255, 187, 108, 34),
        NodesColor.journal: const Color.fromARGB(255, 90, 62, 134),
        NodesColor.market: const Color.fromARGB(255, 34, 134, 64),
        NodesColor.ticket: const Color.fromARGB(255, 233, 220, 30),
        NodesColor.friend: const Color.fromARGB(255, 41, 29, 86),
        NodesColor.self: const Color.fromARGB(255, 14, 28, 79),
        NodesColor.group: const Color.fromARGB(255, 5, 41, 63),
        NodesColor.nonFriend: const Color.fromARGB(255, 54, 17, 31),
        NodesColor.unsafeTx: Colors.red,
        NodesColor.mediumTx: Colors.yellow,
        NodesColor.safeTx: Colors.green,
      };

  @override
  Color get messageForwarderColor => Colors.white60;

  @override
  Color get messageSenderColor => Colors.white60;

  @override
  Color get messageArrowColor => const Color.fromARGB(116, 255, 241, 242);

  @override
  Color get noMessageArrowColor => const Color.fromARGB(37, 255, 241, 242);

  @override
  Color get snipArrowColor => const Color.fromARGB(115, 143, 0, 9);

  @override
  Color get messageSelectionBorderColor => Colors.white;

  @override
  Color get messageSelectionOverlayColor => Colors.black38;

  @override
  Color get messageShadowColor => Colors.transparent;

  @override
  Brightness get keyBoardTheme => Brightness.dark;
}

class PinkTheme implements Down4Theme {
  @override
  String get font => "Alice";

  @override
  TextStyle get consoleTextStyle => TextStyle(
      fontFamily: font,
      fontSize: 12,
      overflow: TextOverflow.fade,
      color: Colors.amber,
      decorationStyle: TextDecorationStyle.solid,
      fontWeight: FontWeight.bold);

  @override
  TextStyle get chatRepilesTextStyle =>
      TextStyle(fontFamily: font, fontSize: 11, color: Colors.black54);

  @override
  TextStyle get chatBubbleTextStyle =>
      TextStyle(fontFamily: font, color: Colors.black);

  @override
  TextStyle get chatBubbleDateTextStyle => TextStyle(
      fontFamily: font, fontSize: 10, color: Colors.black45, height: 0.8);

  @override
  TextStyle get inputTextStyle =>
      TextStyle(fontFamily: font, fontSize: 16, color: Colors.black87);

  @override
  TextStyle get inputPlaceholderTextStyle =>
      TextStyle(fontFamily: font, fontSize: 16, color: Colors.black38);

  @override
  Color get messageArrowColor => const Color.fromARGB(116, 255, 241, 242);

  @override
  Color get noMessageArrowColor => const Color.fromARGB(37, 255, 241, 242);

  @override
  Color get snipArrowColor => const Color.fromARGB(100, 143, 0, 9);

  @override
  Color get idColor => Colors.black87;

  @override
  Color get consoleBorderColor => buttonColor;

  // @override
  // Color get consoleBorderColor => Colors.black;

  @override
  Color get refreshIndicatorColor => qrColor;

  @override
  Color get cursorColor => Colors.black;

  @override
  Color get messageForwarderColor => qrColor;

  @override
  Color get messageSenderColor => qrColor;

  @override
  Color get buttonColor => const Color.fromARGB(255, 250, 222, 224);

  @override
  Color get myBubblesColor => const Color.fromARGB(255, 252, 213, 216);

  @override
  Color get inactivatedButtonColor => const Color.fromARGB(255, 219, 214, 214);

  @override
  Color get backGroundColor => const Color.fromARGB(255, 255, 241, 242);

  @override
  Color get headerColor => qrColor;

  @override
  Color get qrColor => const Color.fromARGB(255, 56, 3, 17);

  @override
  Color get snipRibbon => const Color.fromARGB(153, 255, 241, 242);

  @override
  Color get bubbleTextColor => Colors.black;

  @override
  Color get bubbleTimestampTextColor => Colors.black26;

  @override
  Color get buttonTextColor => Colors.black;

  @override
  Color get headerTextColor => Colors.white;

  @override
  Color get inputBorderColor => buttonColor;

  @override
  Color get inputColor => Colors.white;

  @override
  Color get inputTextColor => Colors.black;

  @override
  Color get otherBubblesColor => buttonColor;

  @override
  Color get paletteBorderColor => Colors.black;

  @override
  Color get paletteTextColor => Colors.black;

  @override
  Map<NodesColor, Color> get nodeColors => const {
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

  @override
  Color get messageSelectionBorderColor => Colors.black54;

  @override
  Color get messageSelectionOverlayColor => Colors.transparent;

  @override
  Color get messageShadowColor => Colors.black38;

  @override
  Brightness get keyBoardTheme => Brightness.light;
}
