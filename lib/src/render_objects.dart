import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'dart:convert';

class PinkTheme {
  static const buttonColor = Color.fromARGB(255, 250, 222, 224);
  static const bodyColor = buttonColor;
  static const backGroundColor = Color.fromARGB(255, 255, 241, 242);
  static const headerColor = Color.fromARGB(255, 250, 81, 138);
  static const imageBorderColor = Color.fromARGB(255, 143, 29, 67);
  static const borderColor = Colors.black;
  static const qrColor = Color.fromARGB(255, 56, 3, 17);
  static const black = Colors.black;
  static const Map<NodeTypes, Color> nodeColors = {
    NodeTypes.rt: Color.fromARGB(255, 53, 3, 20),
    NodeTypes.cht: Color.fromARGB(255, 119, 8, 45),
    NodeTypes.cpt: Color.fromARGB(255, 22, 94, 161),
    NodeTypes.evt: Color.fromARGB(255, 95, 28, 219),
    NodeTypes.itm: Color.fromARGB(255, 187, 108, 34),
    NodeTypes.jnl: Color.fromARGB(255, 90, 62, 134),
    NodeTypes.mkt: Color.fromARGB(255, 34, 134, 64),
    NodeTypes.tkt: Color.fromARGB(255, 233, 220, 30),
    NodeTypes.usr: Color.fromARGB(255, 236, 61, 119),
  };
}

class Down4Container extends StatelessWidget {
  final double? height, width;
  final Widget? child;
  final bool borderSpecific, borderRadiusSpecific, borderRadius, shadow, clip;
  final double radiusTopRight,
      radiusTopLeft,
      radiusBottomRight,
      radiusBottomLeft;
  final double borderWidth;
  final Color borderColor;
  final Color backgroundColor;
  final double? padding;
  final double paddingRight, paddingLeft, paddingTop, paddingBottom;
  final double? maxWidth, minWidth, maxHeight, minHeight;
  final Color borderRightColor,
      borderLeftColor,
      borderTopColor,
      borderBottomColor;
  final double borderRightWidth,
      borderLeftWidth,
      borderTopWidth,
      borderBottomWidth;
  final double radius;
  const Down4Container({
    Key? key,
    this.clip = true,
    this.shadow = false,
    this.borderRadius = false,
    this.radiusBottomLeft = 0.0,
    this.radiusBottomRight = 0.0,
    this.radiusTopLeft = 0.0,
    this.radiusTopRight = 0.0,
    this.borderRadiusSpecific = false,
    this.radius = 0.0,
    this.borderSpecific = false,
    this.height,
    this.width,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.child,
    this.padding,
    this.backgroundColor = Colors.transparent,
    this.paddingRight = 0.0,
    this.paddingLeft = 0.0,
    this.paddingTop = 0.0,
    this.paddingBottom = 0.0,
    this.maxHeight,
    this.minHeight,
    this.maxWidth,
    this.minWidth,
    this.borderBottomColor = Colors.transparent,
    this.borderBottomWidth = 0.0,
    this.borderLeftColor = Colors.transparent,
    this.borderLeftWidth = 0.0,
    this.borderRightColor = Colors.transparent,
    this.borderRightWidth = 0.0,
    this.borderTopColor = Colors.transparent,
    this.borderTopWidth = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Container(
      clipBehavior: clip ? Clip.hardEdge : Clip.none,
      height: height,
      width: width,
      constraints: BoxConstraints(
          maxHeight: maxHeight ?? double.infinity,
          minHeight: minHeight ?? 0.0,
          maxWidth: maxWidth ?? double.infinity,
          minWidth: minWidth ?? 0.0),
      padding: padding != null
          ? EdgeInsets.all(padding!)
          : EdgeInsets.only(
              left: paddingLeft,
              right: paddingRight,
              top: paddingTop,
              bottom: paddingBottom,
            ),
      decoration: BoxDecoration(
          boxShadow: shadow
              ? [
                  const BoxShadow(
                      color: Colors.black87,
                      blurRadius: 12.0,
                      spreadRadius: -6.0,
                      offset: Offset(8.0, 8.0),
                      blurStyle: BlurStyle.normal)
                ]
              : null,
          color: backgroundColor,
          borderRadius: !borderRadius
              ? null
              : !borderRadiusSpecific
                  ? BorderRadius.all(Radius.circular(radius))
                  : BorderRadius.only(
                      topLeft: Radius.circular(radiusTopLeft),
                      topRight: Radius.circular(radiusTopRight),
                      bottomLeft: Radius.circular(radiusBottomLeft),
                      bottomRight: Radius.circular(radiusBottomRight)),
          border: borderSpecific
              ? Border(
                  right: BorderSide(
                      width: borderRightWidth, color: borderRightColor),
                  left: BorderSide(
                      width: borderLeftWidth, color: borderLeftColor),
                  top: BorderSide(width: borderTopWidth, color: borderTopColor),
                  bottom: BorderSide(
                      width: borderBottomWidth, color: borderBottomColor))
              : Border.all(width: borderWidth, color: borderColor)),
      child: child,
    ));
  }
}

class Down4Container2 extends StatelessWidget {
  final double? height, width;
  final Widget? child;
  final bool borderSpecific, borderRadiusSpecific, borderRadius, shadow, clip;
  final double radiusTopRight,
      radiusTopLeft,
      radiusBottomRight,
      radiusBottomLeft;
  final double borderWidth;
  final Color borderColor;
  final Color backgroundColor;
  final double? padding;
  final double paddingRight, paddingLeft, paddingTop, paddingBottom;
  final double? maxWidth, minWidth, maxHeight, minHeight;
  final Color borderRightColor,
      borderLeftColor,
      borderTopColor,
      borderBottomColor;
  final double borderRightWidth,
      borderLeftWidth,
      borderTopWidth,
      borderBottomWidth;
  final double radius;
  const Down4Container2({
    Key? key,
    this.clip = true,
    this.shadow = false,
    this.borderRadius = false,
    this.radiusBottomLeft = 0.0,
    this.radiusBottomRight = 0.0,
    this.radiusTopLeft = 0.0,
    this.radiusTopRight = 0.0,
    this.borderRadiusSpecific = false,
    this.radius = 0.0,
    this.borderSpecific = false,
    this.height,
    this.width,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.child,
    this.padding,
    this.backgroundColor = Colors.transparent,
    this.paddingRight = 0.0,
    this.paddingLeft = 0.0,
    this.paddingTop = 0.0,
    this.paddingBottom = 0.0,
    this.maxHeight,
    this.minHeight,
    this.maxWidth,
    this.minWidth,
    this.borderBottomColor = Colors.transparent,
    this.borderBottomWidth = 0.0,
    this.borderLeftColor = Colors.transparent,
    this.borderLeftWidth = 0.0,
    this.borderRightColor = Colors.transparent,
    this.borderRightWidth = 0.0,
    this.borderTopColor = Colors.transparent,
    this.borderTopWidth = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.hardEdge : Clip.none,
      height: height,
      width: width,
      constraints: BoxConstraints(
          maxHeight: maxHeight ?? double.infinity,
          minHeight: minHeight ?? 0.0,
          maxWidth: maxWidth ?? double.infinity,
          minWidth: minWidth ?? 0.0),
      padding: padding != null
          ? EdgeInsets.all(padding!)
          : EdgeInsets.only(
              left: paddingLeft,
              right: paddingRight,
              top: paddingTop,
              bottom: paddingBottom,
            ),
      decoration: BoxDecoration(
          boxShadow: shadow
              ? [
                  const BoxShadow(
                      color: Colors.black87,
                      blurRadius: 12.0,
                      spreadRadius: -6.0,
                      offset: Offset(8.0, 8.0),
                      blurStyle: BlurStyle.normal)
                ]
              : null,
          color: backgroundColor,
          borderRadius: !borderRadius
              ? null
              : !borderRadiusSpecific
                  ? BorderRadius.all(Radius.circular(radius))
                  : BorderRadius.only(
                      topLeft: Radius.circular(radiusTopLeft),
                      topRight: Radius.circular(radiusTopRight),
                      bottomLeft: Radius.circular(radiusBottomLeft),
                      bottomRight: Radius.circular(radiusBottomRight)),
          border: borderSpecific
              ? Border(
                  right: BorderSide(
                      width: borderRightWidth, color: borderRightColor),
                  left: BorderSide(
                      width: borderLeftWidth, color: borderLeftColor),
                  top: BorderSide(width: borderTopWidth, color: borderTopColor),
                  bottom: BorderSide(
                      width: borderBottomWidth, color: borderBottomColor))
              : Border.all(width: borderWidth, color: borderColor)),
      child: child,
    );
  }
}

class Palette extends StatelessWidget {
  static const double height = 50.0;
  final Node node;
  final void Function(Identifier)? sel, go, snip;
  final bool selected;
  const Palette(
      {required this.node,
      this.selected = false,
      this.go,
      this.snip,
      this.sel,
      Key? key})
      : super(key: key);

  Palette invertedSelection() {
    return Palette(
        node: node, selected: !selected, go: go, snip: snip, sel: sel);
  }

  @override
  Widget build(BuildContext context) {
    return Down4Container(
      height: height,
      borderWidth: 0.5,
      borderColor: selected ? Colors.black : Colors.black38,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
              onTap: () => sel?.call(node.id),
              onLongPress: () => snip?.call(node.id),
              child: Down4Container(
                  width: height - 2.0, // border width I guess
                  backgroundColor: PinkTheme.headerColor,
                  borderWidth: 0.5,
                  borderColor: selected ? Colors.black : Colors.black26,
                  child: Image.asset('lib/src/assets/hashirama.jpg',
                      fit: BoxFit.cover))),
          Expanded(
              child: GestureDetector(
                  onTap: () => sel?.call(node.id),
                  child: Down4Container(
                      borderColor: selected ? Colors.black : Colors.black26,
                      borderWidth: 0.5,
                      backgroundColor: PinkTheme.headerColor,
                      paddingLeft: 10.0,
                      paddingTop: 10.0,
                      child: Text(node.nm,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal))))),
          GestureDetector(
            onTap: () => go?.call(node.id),
            child: Down4Container(
              borderColor: selected ? Colors.black : Colors.black26,
              borderWidth: 0.5,
              backgroundColor: PinkTheme.headerColor,
              child: Image.asset('lib/src/assets/rightBlackArrow.png'),
            ),
          )
        ],
      ),
    );
  }
}

class Palette2 extends StatelessWidget {
  static const double height = 63.0;
  final Node node;
  final void Function(Identifier)? imPress,
      bodyPress,
      goPress,
      imLongPress,
      bodyLongPress,
      goLongPress;
  final bool selected;

  Palette2 invertedSelection() {
    return Palette2(
        node: node,
        selected: !selected,
        imPress: imPress,
        imLongPress: imLongPress,
        bodyPress: bodyPress,
        bodyLongPress: bodyLongPress,
        goPress: goPress,
        goLongPress: goLongPress);
  }

  const Palette2({
    required this.node,
    this.imPress,
    this.bodyPress,
    this.goPress,
    this.imLongPress,
    this.bodyLongPress,
    this.goLongPress,
    this.selected = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4Container2(
      shadow: selected ? false : true,
      height: Palette2.height,
      borderColor: selected ? PinkTheme.black : Colors.transparent,
      borderRadius: true,
      radius: 5.0,
      borderWidth: 2.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
              onTap: () => imPress?.call(node.id),
              onLongPress: () => imLongPress?.call(node.id),
              child: Down4Container2(
                  borderRadius: true,
                  borderRadiusSpecific: true,
                  radiusTopLeft: 3.0,
                  radiusBottomLeft: 3.0,
                  borderWidth: 3.0,
                  backgroundColor: PinkTheme.headerColor,
                  width: Palette2.height - 4.0, // -2.0 for border
                  // padding: 3.0,
                  child: Center(
                      child: Down4Container2(
                          borderRadius: true,
                          backgroundColor: PinkTheme.headerColor,
                          radius: 2.0,
                          borderColor: PinkTheme.imageBorderColor,
                          borderWidth: 1.0,
                          child: Image.asset(
                            'lib/src/assets/hashirama.jpg',
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                          ))))),
          Expanded(
            child: GestureDetector(
              onTap: () => bodyPress?.call(node.id),
              onLongPress: () => bodyLongPress?.call(node.id),
              child: Down4Container2(
                paddingLeft: 10.0,
                paddingTop: 12.0,
                backgroundColor: PinkTheme.headerColor,
                child: Text(
                  node.nm,
                  style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            ),
          ),
          GestureDetector(
              onTap: () => bodyPress?.call(node.id),
              onLongPress: () => bodyLongPress?.call(node.id),
              child: Down4Container2(
                  borderRadius: true,
                  borderRadiusSpecific: true,
                  radiusTopRight: 3.0,
                  radiusBottomRight: 3.0,
                  borderWidth: 3.0,
                  backgroundColor: PinkTheme.headerColor,
                  child: Image.asset('lib/src/assets/rightBlackArrow.png')))
        ],
      ),
    );
  }
}

class Palette3 extends StatelessWidget {
  static const double height = 60.0;
  final Node node;
  final String at;
  final void Function(String, Identifier)? imPress,
      bodyPress,
      goPress,
      imLongPress,
      bodyLongPress,
      goLongPress;
  final bool selected;

  Palette3 invertedSelection() {
    return Palette3(
        node: node,
        at: at,
        selected: !selected,
        imPress: imPress,
        imLongPress: imLongPress,
        bodyPress: bodyPress,
        bodyLongPress: bodyLongPress,
        goPress: goPress,
        goLongPress: goLongPress);
  }

  const Palette3({
    required this.node,
    required this.at,
    this.imPress,
    this.bodyPress,
    this.goPress,
    this.imLongPress,
    this.bodyLongPress,
    this.goLongPress,
    this.selected = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4Container2(
      shadow: selected ? false : true,
      height: Palette3.height,
      borderWidth: 2.0,
      borderRadius: true,
      radius: 6.0,
      borderColor: selected ? PinkTheme.black : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
              onTap: () => imPress?.call(at, node.id),
              onLongPress: () => imLongPress?.call(at, node.id),
              child: Down4Container2(
                  borderRadius: true,
                  borderRadiusSpecific: true,
                  radiusTopLeft: 4.0,
                  radiusBottomLeft: 4.0,
                  width: Palette3.height - 2.0, // borderWidth x2
                  child: Image.asset('lib/src/assets/hashirama.jpg',
                      fit: BoxFit.fill))),
          Expanded(
            child: GestureDetector(
              onTap: () => bodyPress?.call(at, node.id),
              onLongPress: () => bodyLongPress?.call(at, node.id),
              child: Down4Container2(
                borderSpecific: true,
                borderLeftColor:
                    selected ? PinkTheme.black : PinkTheme.headerColor,
                borderLeftWidth: 1.0,
                paddingLeft: 9.0, // 10.0 - 1.0
                paddingTop: 10.0,
                backgroundColor: PinkTheme.headerColor,
                child: Text(
                  node.nm,
                  style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            ),
          ),
          GestureDetector(
              onTap: () => bodyPress?.call(at, node.id),
              onLongPress: () => bodyLongPress?.call(at, node.id),
              child: Down4Container2(
                  borderRadius: true,
                  borderRadiusSpecific: true,
                  radiusTopRight: 4.0,
                  radiusBottomRight: 4.0,
                  padding: 2.0,
                  backgroundColor: PinkTheme.headerColor,
                  child: Image.asset('lib/src/assets/rightBlackArrow.png')))
        ],
      ),
    );
  }
}

class ConsoleButton extends StatelessWidget {
  static const double height = 30.0;
  final String name;
  final void Function() onPress;
  final void Function()? onLongPress;

  const ConsoleButton({
    required this.name,
    required this.onPress,
    this.onLongPress,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
          child: Ink(
              height: height,
              decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: PinkTheme.buttonColor,
                  border: Border.all(color: Colors.black, width: 0.5)),
              child: InkWell(
                  //borderRadius: BorderRadius.zero,
                  splashColor: Colors.black,
                  onTap: onPress,
                  onLongPress: onLongPress,
                  child: Center(
                      child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ))))),

      // child: Down4Container(
      //     padding: 1.0,
      //     height: height,
      //     borderColor: PinkTheme.black,
      //     child: TextButton(
      //       style:
      //         TextButton.styleFrom(
      //             backgroundColor: PinkTheme.buttonColor,
      //             primary: PinkTheme.black),
      //         onPressed: onPress,
      //         onLongPress: onLongPress,
      //         child: Center(
      //           child: Text(name),
      //         ))),
    );
  }
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? topButtons, extraButtons;
  final List<ConsoleButton> bottomButtons;
  final String? placeHolder;
  final void Function(String)? inputCallBack;
  const Console(
      {required this.bottomButtons,
      this.inputCallBack,
      this.placeHolder,
      this.topButtons,
      this.extraButtons,
      Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Down4Container(
        child: Column(children: [
          inputCallBack != null
              ? Down4Container(
                  height: ConsoleButton.height,
                  borderColor: PinkTheme.black,
                  backgroundColor: Colors.white,
                  child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          hintText: placeHolder, border: InputBorder.none),
                      textDirection: TextDirection.ltr,
                      onChanged: (value) => inputCallBack?.call(value)))
              : const SizedBox.shrink(),
          Row(
            children: topButtons ?? [],
            textDirection: TextDirection.ltr,
          ),
          Row(
            children: bottomButtons,
            textDirection: TextDirection.ltr,
          )
        ]),
        borderColor: Colors.black);
  }
}

class ChatMessage extends StatelessWidget {
  static const double _headerHeight = 24.0;
  final Down4Message message;
  final bool myMessage, selected;
  final void Function(Identifier)? select;
  final List<Identifier>? reactionIDs;
  const ChatMessage(
      {required this.message,
      required this.myMessage,
      this.select,
      this.selected = false,
      this.reactionIDs,
      Key? key})
      : super(key: key);

  ChatMessage invertedSelection() {
    return ChatMessage(
      message: message,
      myMessage: myMessage,
      selected: !selected,
      select: select,
      reactionIDs: reactionIDs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: !message.ch
          ? Alignment.topCenter
          : myMessage
              ? Alignment.topRight
              : Alignment.topLeft,
      child: Down4Container(
        maxWidth: MediaQuery.of(context).size.width * 0.66,
        borderColor: selected ? PinkTheme.black : PinkTheme.backGroundColor,
        child: IntrinsicWidth(
          child: Column(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.ltr,
                  children: [
                    GestureDetector(
                      onTap: () => select?.call(message.id),
                      child: Down4Container(
                        height: _headerHeight,
                        child: Image.asset('lib/src/assets/hashirama.jpg'),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => select?.call(message.id),
                        child: Down4Container(
                          paddingLeft: 2.0,
                          paddingTop: 2.0,
                          paddingRight: 2.0,
                          height: _headerHeight,
                          child: Text(
                            message.nm,
                            textDirection: TextDirection.ltr,
                          ),
                          backgroundColor: PinkTheme.headerColor,
                        ),
                      ),
                    ),
                  ],
                ),
                message.t == null
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () => select?.call(message.id),
                        child: Down4Container(
                          padding: 2.0,
                          backgroundColor: PinkTheme.bodyColor,
                          child: Text(message.t!,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(color: Colors.black)),
                        ),
                      ),
                message.p == null
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () => select?.call(message.id),
                        child: Down4Container(
                          backgroundColor: PinkTheme.bodyColor,
                          child: Image.memory(base64.decode(base64
                              .normalize(message.p!.replaceAll("\n", "")))),
                        ),
                      ),
              ]),
        ),
      ),
    );
  }
}

class PaletteList extends StatelessWidget {
  final List<Palette3> palettes;
  const PaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ListView.separated(
            itemBuilder: (c, i) => palettes[i],
            separatorBuilder: (c, i) => Container(height: 16.0),
            itemCount: palettes.length));
  }
}

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  const MessageList({required this.messages, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        itemBuilder: (c, i) => messages[i],
        separatorBuilder: (c, i) => Container(height: 16.0),
        itemCount: messages.length);
  }
}
