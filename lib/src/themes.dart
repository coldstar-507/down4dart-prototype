import 'package:flutter/material.dart';

import 'data_objects/_data_utils.dart';
import 'data_objects/nodes.dart';

/// Flutter icons Down4Icon
/// Copyright (C) 2023 by original authors @ fluttericon.com, fontello.com
/// This font was generated by FlutterIcon.com, which is derived from Fontello.
///
/// To use this font, place it in your fonts/ directory and include the
/// following in your pubspec.yaml
///
/// flutter:
///   fonts:
///    - family:  Down4Icon
///      fonts:
///       - asset: fonts/Down4Icon.ttf
///
///
///

final Map<String, Down4Theme> themesRegistry = {
  BlackTheme().name: BlackTheme(),
  PinkTheme().name: PinkTheme(),
};

class Down4Icon {
  Down4Icon._();

  static const _kFontFam = 'Down4Icon';
  static const String? _kFontPkg = null;

  static const IconData down4Inverted =
      IconData(0xe800, fontFamily: _kFontFam, fontPackage: _kFontPkg);
  // static const IconData down4_inverted_white =
  //     IconData(0xe801, fontFamily: _kFontFam, fontPackage: _kFontPkg);
}

abstract class Down4Theme {
  Icon down4Icon(Color color);

  String get name;
  String get font;

  Color get bottomNavigationBarColor;
  Brightness get bottonNavigationIconBrightness;
  Brightness get topStatusIconBrightness;

  Color get chatReactionCounterColor;
  TextStyle get chatReactionCounterTextStyle;

  Color get down4IconForLoadingScreenColor;
  Color get down4IconForPaletteColor;
  Color get paletteColor;
  Color get paletteSelectionOverlayColor;
  Color get backArrowColor;
  Color get snipArrowColor;
  Color get messageArrowColor;
  Color get noMessageArrowColor;
  // Color get idColor;
  Color get refreshIndicatorColor;
  Color get cursorColor;
  Color buttonColor({required bool isActivated, required bool isInverted});
  Color get myBubblesColor;
  Color get otherBubblesColor;
  // Color get consoleBorderColor;

  // Color get bubbleTextColor;
  // Color get bubbleTimestampTextColor;

  TextStyle headerTextStyle2(Color c);

  Color get headerTextColor;

  Color get _unactivatedButtonColor;
  Color get _buttonColor;
  Color get _invertedButtonColor;
  Color get buttonTextColor;
  Color get _unactivatedButtonTextColor;
  Color get _invertedButtonTextColor;

  Color get backGroundColor;
  Color get headerColor;

  TextStyle headerTextStyle({required bool activated});
  TextStyle get messageSenderTextStyle;
  TextStyle get messageForwarderTextStyle;

  Color get paletteBorderColor;
  Color get paletteTextColor;
  Color get inputColor;
  Color get selectedRegionColor;
  Color get inputBorderColor;
  Color get consoleBorderColor;

  // Color get inputTextColor;
  // Color get buttonTextColor;

  Color get qrColor;

  TextStyle get snipInputTextStyle;
  Color get snipRibbon;

  TextStyle paletteNameStyle({required bool selected, Color? color});

  TextStyle paletteIDTextStyle({
    required bool selected,
    Color? color,
  });
  TextStyle palettePreviewTextStyle({
    required bool selected,
    Color? color,
  });

  TextStyle consoleButtonTextStyle({
    required bool isMode,
    required bool isSpecial,
    required bool isInverted,
    required bool isActivated,
  });

  TextStyle get inputTextStyle;
  TextStyle get inputPlaceholderTextStyle;
  TextStyle get palettePlaceholderTextStyle;
  TextStyle get chatBubbleTextStyle;
  TextStyle get chatBubbleDateTextStyle;
  TextStyle get chatRepilesTextStyle;
  TextStyle get consoleTextStyle;

  Map<NodesColor, Color> get nodeColors;
  Color get messageSelectionBorderColor;
  Color get messageSelectionOverlayColor;
  Color get messageShadowColor;
  Brightness get keyBoardTheme;

  TextStyle get tipTextStyle => TextStyle(
      fontFamily: font,
      fontSize: 20,
      overflow: TextOverflow.fade,
      color: Colors.green.withOpacity(0.7),
      fontWeight: FontWeight.bold);

  TextStyle get discountTextStyle => TextStyle(
      fontFamily: font,
      fontSize: 20,
      overflow: TextOverflow.fade,
      color: Colors.red.withOpacity(0.7),
      fontWeight: FontWeight.bold);
}

class BlackTheme extends Down4Theme {
  @override
  String get name => "Blackout";

  @override
  String get font => "Roboto";

  @override
  Icon down4Icon(Color color) => Icon(Down4Icon.down4Inverted, color: color);

  @override
  TextStyle get consoleTextStyle => TextStyle(
      fontFamily: font,
      fontSize: 15,
      overflow: TextOverflow.fade,
      color: Colors.amber.withOpacity(0.7),
      fontWeight: FontWeight.bold);

  @override
  TextStyle get chatRepilesTextStyle =>
      TextStyle(fontFamily: font, fontSize: 11, color: Colors.white54);

  @override
  TextStyle get chatBubbleTextStyle =>
      TextStyle(fontFamily: font, color: Colors.black, fontSize: 16);

  @override
  TextStyle get chatBubbleDateTextStyle => TextStyle(
      fontFamily: font, fontSize: 12, color: Colors.black45, height: 0.8);

  @override
  TextStyle get chatReactionCounterTextStyle => TextStyle(
      fontSize: 10,
      fontFamily: font,
      color: Colors.white,
      fontWeight: FontWeight.bold);

  @override
  get chatReactionCounterColor => Colors.black;

  @override
  TextStyle get inputTextStyle =>
      TextStyle(fontFamily: font, fontSize: 16, color: Colors.white70);

  @override
  TextStyle get inputPlaceholderTextStyle =>
      TextStyle(fontFamily: font, fontSize: 16, color: Colors.white30);

  @override
  Color get consoleBorderColor => Colors.black;

  @override
  Color get refreshIndicatorColor => Colors.white;

  @override
  Color get cursorColor => Colors.black;

  // @override
  // Color get bubbleTextColor => Colors.black;

  // @override
  // Color get bubbleTimestampTextColor => const Color.fromARGB(255, 73, 73, 73);

  // @override
  // Color get buttonTextColor => const Color.fromARGB(110, 255, 255, 255);

  // @override
  // Color get headerTextColor => Colors.white;

  @override
  Color get inputBorderColor => const Color.fromARGB(255, 0, 0, 0);

  @override
  Color get inputColor => const Color.fromARGB(255, 37, 37, 37);

  // @override
  // Color get inputTextColor => const Color.fromARGB(255, 161, 161, 161);

  @override
  Color get paletteBorderColor => const Color.fromARGB(255, 255, 255, 255);

  @override
  Color get paletteTextColor => const Color.fromARGB(255, 201, 201, 201);

  @override
  Color buttonColor({required bool isActivated, required bool isInverted}) =>
      isInverted
          ? _invertedButtonColor
          : isActivated
              ? _buttonColor
              : _unactivatedButtonColor;

  @override
  Color get myBubblesColor => Colors.blueGrey.shade400;

  @override
  Color get otherBubblesColor => Colors.grey.shade500;

  // @override
  // Color get inactivatedButtonColor => const Color.fromARGB(255, 73, 73, 73);

  @override
  Color get backGroundColor => const Color.fromARGB(255, 0, 0, 0);

  @override
  Color get headerColor => const Color.fromARGB(255, 0, 0, 0);

  @override
  Color get qrColor => Colors.white;

  @override
  Map<NodesColor, Color> get nodeColors => {
        NodesColor.root: const Color.fromARGB(255, 53, 3, 20),
        NodesColor.hyperchat: paletteTextColor,
        NodesColor.checkpoint: const Color.fromARGB(255, 22, 94, 161),
        NodesColor.event: const Color.fromARGB(255, 95, 28, 219),
        NodesColor.item: const Color.fromARGB(255, 187, 108, 34),
        NodesColor.journal: const Color.fromARGB(255, 90, 62, 134),
        NodesColor.market: const Color.fromARGB(255, 34, 134, 64),
        NodesColor.ticket: const Color.fromARGB(255, 233, 220, 30),
        NodesColor.friend: paletteTextColor,
        NodesColor.self: consoleTextStyle.color!,
        NodesColor.group: paletteTextColor,
        NodesColor.nonFriend: paletteTextColor.withOpacity(0.5),
        NodesColor.unsafeTx: Colors.red,
        NodesColor.mediumTx: Colors.yellow,
        NodesColor.safeTx: Colors.green,
      };

  // @override
  // Color get messageForwarderColor => Colors.white60;
  //
  // @override
  // Color get messageSenderColor => Colors.white60;

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

  @override
  TextStyle paletteIDTextStyle({required bool selected, Color? color}) =>
      TextStyle(
          fontSize: 8,
          color: color ?? paletteTextColor,
          fontStyle: FontStyle.italic,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal);

  @override
  TextStyle paletteNameStyle({required bool selected, Color? color}) =>
      TextStyle(
          overflow: TextOverflow.ellipsis,
          fontSize: 16,
          color: paletteTextColor,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal);

  @override
  TextStyle palettePreviewTextStyle({required bool selected, Color? color}) =>
      TextStyle(
          fontSize: 13,
          color: paletteTextColor,
          fontWeight: !selected ? FontWeight.normal : FontWeight.bold);

  @override
  TextStyle headerTextStyle({required bool activated}) => TextStyle(
      fontWeight: FontWeight.bold,
      fontFamily: font,
      color: activated ? Colors.white : Colors.white24,
      fontSize: 20);

  @override
  TextStyle headerTextStyle2(Color c) => TextStyle(
      fontWeight: FontWeight.bold, fontFamily: font, color: c, fontSize: 20);

  @override
  Color get headerTextColor => Colors.white;

  @override
  TextStyle consoleButtonTextStyle({
    required bool isMode,
    required bool isSpecial,
    required bool isInverted,
    required bool isActivated,
  }) =>
      TextStyle(
          fontSize: 12,
          overflow: TextOverflow.fade,
          color: !isActivated
              ? _unactivatedButtonTextColor
              : isInverted
                  ? _invertedButtonTextColor
                  : buttonTextColor,
          decoration: isSpecial ? TextDecoration.underline : null,
          decorationStyle: TextDecorationStyle.solid,
          fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
          fontWeight: FontWeight.bold);

  @override
  Color get _buttonColor => Colors.black;

  @override
  Color get buttonTextColor => Colors.white54;

  @override
  Color get _unactivatedButtonColor => Colors.black;

  @override
  Color get _invertedButtonColor => buttonTextColor.withOpacity(0.2);

  @override
  Color get _invertedButtonTextColor => _buttonColor;

  @override
  Color get _unactivatedButtonTextColor => Colors.white10;

  @override
  TextStyle get messageForwarderTextStyle =>
      TextStyle(color: Colors.white60, fontSize: 13, fontFamily: font);

  @override
  TextStyle get messageSenderTextStyle =>
      TextStyle(color: Colors.white60, fontSize: 13, fontFamily: font);

  @override
  TextStyle get palettePlaceholderTextStyle => const TextStyle(
      overflow: TextOverflow.ellipsis, fontSize: 16, color: Colors.white30);

  @override
  Color get paletteSelectionOverlayColor => Colors.white10;

  @override
  Color get paletteColor => Colors.black;

  @override
  Color get backArrowColor => Colors.white;

  @override
  Color get down4IconForPaletteColor => Colors.white;

  @override
  Color get down4IconForLoadingScreenColor => Colors.white;

  @override
  TextStyle get snipInputTextStyle => const TextStyle(color: Colors.white);

  @override
  Color get snipRibbon => Colors.black54;

  @override
  Color get bottomNavigationBarColor => Colors.black;

  @override
  Brightness get bottonNavigationIconBrightness => Brightness.light;

  @override
  Brightness get topStatusIconBrightness => Brightness.light;

  @override
  Color get selectedRegionColor => const Color.fromARGB(255, 56, 56, 56);
}

class PinkTheme extends Down4Theme {
  @override
  Icon down4Icon(Color color) => Icon(Down4Icon.down4Inverted, color: color);

  @override
  String get name => "Alice";

  @override
  String get font => "Alice";

  @override
  TextStyle get consoleTextStyle => TextStyle(
      fontFamily: font,
      fontSize: 16,
      overflow: TextOverflow.ellipsis,
      color: qrColor,
      decorationStyle: TextDecorationStyle.solid,
      fontWeight: FontWeight.bold);

  @override
  TextStyle get chatRepilesTextStyle =>
      TextStyle(fontFamily: font, fontSize: 11, color: Colors.black54);

  @override
  TextStyle get chatBubbleTextStyle =>
      TextStyle(fontFamily: font, color: Colors.black, fontSize: 16);

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
  Color get messageArrowColor => Colors.black;

  @override
  Color get noMessageArrowColor => Colors.black26;

  @override
  Color get snipArrowColor => Colors.red.shade900;

  @override
  Color get consoleBorderColor =>
      buttonColor(isActivated: true, isInverted: false);

  // @override
  // Color get consoleBorderColor => Colors.black;

  @override
  Color get refreshIndicatorColor => qrColor;

  @override
  Color get cursorColor => Colors.black;

  @override
  Color buttonColor({required bool isActivated, required bool isInverted}) =>
      isInverted
          ? _invertedButtonColor
          : isActivated
              ? _buttonColor
              : _unactivatedButtonColor;

  @override
  Color get myBubblesColor => const Color.fromARGB(255, 252, 213, 216);

  // @override
  // Color get inactivatedButtonColor => const Color.fromARGB(255, 219, 214, 214);

  @override
  Color get backGroundColor => _buttonColor;

  @override
  Color get headerColor => qrColor;

  @override
  Color get qrColor => const Color.fromARGB(255, 56, 3, 17);

  // @override
  // Color get bubbleTextColor => Colors.black;

  // @override
  // Color get bubbleTimestampTextColor => Colors.black26;

  // @override
  // Color get buttonTextColor => Colors.black;

  // @override
  // Color get headerTextColor => Colors.white;

  @override
  Color get inputBorderColor =>
      buttonColor(isActivated: true, isInverted: false);

  @override
  Color get inputColor => paletteColor;

  // @override
  // Color get inputTextColor => Colors.black;

  @override
  Color get otherBubblesColor =>
      paletteColor; //c// onst  Color.fromARGB(255, 255, 230, 231);

  @override
  Color get paletteBorderColor => Colors.black;

  @override
  Color get paletteTextColor => Colors.black;

  @override
  Map<NodesColor, Color> get nodeColors => {
        NodesColor.root: Color.fromARGB(255, 53, 3, 20),
        NodesColor.checkpoint: Color.fromARGB(255, 22, 94, 161),
        NodesColor.event: Color.fromARGB(255, 95, 28, 219),
        NodesColor.item: Color.fromARGB(255, 187, 108, 34),
        NodesColor.journal: Color.fromARGB(255, 90, 62, 134),
        NodesColor.market: Color.fromARGB(255, 34, 134, 64),
        NodesColor.ticket: Color.fromARGB(255, 233, 220, 30),
        // NodesColor.hyperchat: Color.fromARGB(255, 212, 168, 182),
        NodesColor.hyperchat: paletteTextColor,
        // NodesColor.friend: Color.fromARGB(255, 230, 174, 193),
        NodesColor.friend: paletteTextColor,
        // NodesColor.self: Color.fromARGB(255, 199, 118, 132),
        NodesColor.self: qrColor,
        // NodesColor.group: Color.fromARGB(255, 175, 134, 209),
        NodesColor.group: paletteTextColor,
        // NodesColor.nonFriend: Color.fromARGB(255, 158, 92, 114),
        NodesColor.nonFriend: Colors.black45,
        NodesColor.unsafeTx: Colors.red,
        NodesColor.mediumTx: Colors.yellow,
        NodesColor.safeTx: Colors.green,
      };

  @override
  Color get messageSelectionBorderColor => Colors.black;

  @override
  Color get messageSelectionOverlayColor => Colors.transparent;

  @override
  Color get messageShadowColor => Colors.black38;

  @override
  Brightness get keyBoardTheme => Brightness.light;

  @override
  TextStyle paletteIDTextStyle({required bool selected, Color? color}) =>
      TextStyle(
          fontSize: 8,
          fontFamily: font,
          color: color,
          fontStyle: FontStyle.italic,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal);

  @override
  TextStyle paletteNameStyle({required bool selected, Color? color}) =>
      TextStyle(
          overflow: TextOverflow.ellipsis,
          fontSize: 16,
          fontFamily: font,
          color: Colors.black,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal);

  @override
  TextStyle palettePreviewTextStyle({required bool selected, Color? color}) =>
      TextStyle(
          fontSize: 13,
          fontFamily: font,
          color: Colors.black,
          fontWeight: !selected ? FontWeight.normal : FontWeight.bold);

  @override
  TextStyle headerTextStyle({required bool activated}) => TextStyle(
      fontWeight: FontWeight.bold,
      fontFamily: font,
      color: activated ? backGroundColor : backGroundColor.withOpacity(0.4),
      fontSize: 20);

  @override
  TextStyle consoleButtonTextStyle({
    required bool isMode,
    required bool isSpecial,
    required bool isActivated,
    required bool isInverted,
  }) =>
      TextStyle(
          fontFamily: font,
          fontSize: 12,
          overflow: TextOverflow.fade,
          color: isInverted
              ? _invertedButtonTextColor
              : isActivated
                  ? buttonTextColor
                  : _unactivatedButtonTextColor,
          decoration: isSpecial ? TextDecoration.underline : null,
          decorationStyle: TextDecorationStyle.solid,
          fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
          fontWeight: FontWeight.bold);

  @override
  Color get _buttonColor => _palePink;

  @override
  Color get buttonTextColor => Colors.black87;

  @override
  Color get _invertedButtonColor => buttonTextColor.withOpacity(0.5);

  @override
  Color get _invertedButtonTextColor => _buttonColor;

  @override
  Color get _unactivatedButtonColor => Colors.grey;

  @override
  Color get _unactivatedButtonTextColor => buttonTextColor.withOpacity(0.8);

  // @override
  // Color get messageForwarderColor => qrColor;
  //
  // @override
  // Color get messageSenderColor => qrColor;

  @override
  TextStyle get messageForwarderTextStyle =>
      TextStyle(color: qrColor, fontSize: 13, fontFamily: font);

  @override
  TextStyle get messageSenderTextStyle =>
      TextStyle(color: qrColor, fontSize: 13, fontFamily: font);

  @override
  TextStyle get palettePlaceholderTextStyle => const TextStyle(
      overflow: TextOverflow.ellipsis, fontSize: 16, color: Colors.black38);

  @override
  Color get paletteSelectionOverlayColor => qrColor.withOpacity(0.4);

  Color get _palePink => const Color.fromARGB(255, 255, 241, 242);
  Color get _darkerPink => const Color.fromARGB(255, 250, 222, 224);
  Color get _darkerDarkerPink => const Color.fromARGB(255, 250, 192, 196);

  @override
  Color get paletteColor => _darkerPink;

  @override
  Color get backArrowColor => backGroundColor;

  @override
  Color get down4IconForPaletteColor => qrColor;

  @override
  Color get down4IconForLoadingScreenColor => qrColor;

  @override
  TextStyle get chatReactionCounterTextStyle => TextStyle(
      fontSize: 10,
      fontFamily: font,
      color: qrColor.withOpacity(0.7),
      fontWeight: FontWeight.bold);

  @override
  get chatReactionCounterColor => _darkerPink;

  @override
  TextStyle headerTextStyle2(Color c) => TextStyle(
      fontWeight: FontWeight.bold, fontFamily: font, color: c, fontSize: 20);

  @override
  Color get headerTextColor => backGroundColor;

  @override
  TextStyle get snipInputTextStyle =>
      TextStyle(fontFamily: font, color: qrColor);

  @override
  Color get snipRibbon => _palePink.withOpacity(0.7);

  @override
  Color get bottomNavigationBarColor => backGroundColor;

  @override
  Brightness get bottonNavigationIconBrightness => Brightness.dark;

  @override
  Brightness get topStatusIconBrightness => Brightness.light;

  @override
  Color get selectedRegionColor => _darkerDarkerPink;
}
