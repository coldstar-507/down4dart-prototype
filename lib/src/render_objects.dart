import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'dart:convert';

class PinkTheme {
  static const buttonColor = Color.fromARGB(255, 250, 222, 224);
  static const bodyColor = buttonColor;
  static const backGroundColor = Color.fromARGB(255, 255, 241, 242);
  static const headerColor = Color.fromARGB(255, 250, 81, 138);
  static const borderColor = Colors.black;
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

class Separator extends StatelessWidget {
  const Separator({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(height: 16.0);
  }
}

class ExpandedSeparator extends StatelessWidget {
  const ExpandedSeparator({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container());
  }
}

class Down4Container extends StatelessWidget {
  final double? height, width;
  final Widget? child;
  final bool border;
  final double? borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final double? padding;
  final double? paddingRight, paddingLeft, paddingTop, paddingBottom;
  final double? maxWidth, minWidth, maxHeight, minHeight;
  const Down4Container(
      {Key? key,
      this.border = false,
      this.height,
      this.width,
      this.borderColor,
      this.borderWidth,
      this.child,
      this.padding,
      this.backgroundColor,
      this.paddingRight,
      this.paddingLeft,
      this.paddingTop,
      this.paddingBottom,
      this.maxHeight,
      this.minHeight,
      this.maxWidth,
      this.minWidth})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
        child: Container(
      height: height,
      width: width,
      color: !border ? backgroundColor : null,
      constraints: BoxConstraints(
          maxHeight: maxHeight ?? double.infinity,
          minHeight: minHeight ?? 0.0,
          maxWidth: maxWidth ?? double.infinity,
          minWidth: minWidth ?? 0.0),
      padding: padding != null
          ? EdgeInsets.all(padding!)
          : EdgeInsets.only(
              left: paddingLeft ?? 0.0,
              right: paddingRight ?? 0.0,
              top: paddingTop ?? 0.0,
              bottom: paddingBottom ?? 0.0,
            ),
      decoration: border
          ? BoxDecoration(
              color: backgroundColor,
              border:
                  Border.all(width: borderWidth ?? 0.5, color: borderColor!))
          : null,
      child: child,
    ));
  }
}

class Palette extends StatelessWidget {
  static const double height = 50.0;
  final Node node;
  final void Function(Identifier)? sel, go, snip;
  final bool selected;
  Palette(
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
      border: true,
      height: height,
      borderColor: selected ? PinkTheme.black : PinkTheme.backGroundColor,
      backgroundColor: PinkTheme.headerColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: () => sel?.call(node.id),
            onLongPress: () => snip?.call(node.id),
            child: Down4Container(
              child: Image.asset('lib/src/assets/hashirama.jpg'),
            ),
          ),
          Expanded(
              child: GestureDetector(
                  onTap: () => sel?.call(node.id),
                  child: Down4Container(
                      backgroundColor: PinkTheme.headerColor,
                      paddingLeft: 10.0,
                      paddingTop: 10.0,
                      child: Text(
                        node.nm,
                        textDirection: TextDirection.ltr,
                      )))),
          GestureDetector(
            onTap: () => go?.call(node.id),
            child: Down4Container(
              backgroundColor: PinkTheme.headerColor,
              child: Image.asset('lib/src/assets/rightBlackArrow.png'),
            ),
          )
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
      child: Down4Container(
          padding: 0.5,
          height: height,
          border: true,
          borderColor: PinkTheme.black,
          child: TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: PinkTheme.buttonColor,
                  primary: PinkTheme.black),
              onPressed: onPress,
              onLongPress: onLongPress,
              child: Center(
                child: Text(name),
              ))),
    );
  }
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? topButtons, extraButtons;
  final List<ConsoleButton> bottomButtons;
  const Console(
      {required this.bottomButtons,
      this.topButtons,
      this.extraButtons,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4Container(
        border: true,
        child: Column(children: [
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
        border: true,
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
