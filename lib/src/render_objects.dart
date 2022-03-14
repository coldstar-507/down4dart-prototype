import 'package:flutter/material.dart';
import 'package:flutter_testproject/main.dart';
import 'data_objects.dart';
import 'dart:convert';

const Color buttonColor = Color.fromARGB(255, 250, 222, 224);

const Map<NodeTypes, Color> colors = {
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

class Down4Container extends StatelessWidget {
  final double? height, width;
  final Widget child;
  final Color borderColor;
  final Color? backgroundColor;
  final double? paddingRight, paddingLeft, paddingTop, paddingBottom;
  final double? maxWidth, minWidth, maxHeight, minHeight;
  const Down4Container(
      {Key? key,
      this.height,
      this.width,
      required this.borderColor,
      required this.child,
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
    return Container(
      height: height,
      width: width,
      constraints: BoxConstraints(
          maxHeight: maxHeight ?? double.infinity,
          minHeight: minHeight ?? 0.0,
          maxWidth: maxWidth ?? double.infinity,
          minWidth: minWidth ?? 0.0),
      padding: EdgeInsets.only(
        left: paddingLeft ?? 0.0,
        right: paddingRight ?? 0.0,
        top: paddingTop ?? 0.0,
        bottom: paddingBottom ?? 0.0,
      ),
      decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(width: .5, color: borderColor)),
      child: child,
    );
  }
}

class Palette extends StatelessWidget {
  static const double _height = 50.0;
  final Node _node;
  final Color _color, _borderColor;
  final VoidCallback _go, _snip, _sel;
  Palette(Node node, bool selected, VoidCallback go, VoidCallback snip,
      VoidCallback sel,
      {Key? key})
      : _node = node,
        _color = colors[node.t]!,
        _borderColor = selected ? Colors.black : colors[node.t]!,
        _go = go,
        _snip = snip,
        _sel = sel,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Down4Container(
      height: _height,
      borderColor: _borderColor,
      backgroundColor: _color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: _sel,
            onLongPress: _snip,
            child: Down4Container(
              borderColor: _borderColor,
              child: Image.asset('lib/src/assets/hashirama.jpg'),
            ),
          ),
          Expanded(
              child: GestureDetector(
                  onTap: _sel,
                  child: Down4Container(
                      paddingLeft: 10.0,
                      paddingTop: 10.0,
                      borderColor: _borderColor,
                      child: Text(
                        _node.nm,
                        textDirection: TextDirection.ltr,
                      )))),
          GestureDetector(
            onTap: _go,
            child: Down4Container(
              borderColor: _borderColor,
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
  final Color color;
  final String name;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConsoleButton(
      {required this.name, required this.onTap, this.onLongPress, Key? key})
      : color = buttonColor,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Down4Container(
              backgroundColor: color,
              borderColor: Colors.black,
              height: height,
              child: Center(
                child: Text(
                  name,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.black),
                ),
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
        child: Column(children: [
          Row(
            children: topButtons!,
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
  static const int maxWidthPercentage = 66;
  static const double headerHeight = 24.0;
  final Message message;
  final Color headerColor, bodyColor;
  final bool myMessage, selected;
  final VoidCallback select;
  const ChatMessage(
      {required this.message,
      required this.headerColor,
      required this.bodyColor,
      required this.myMessage,
      required this.selected,
      required this.select,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: myMessage ? Alignment.topRight : Alignment.topLeft,
      child: Down4Container(
        maxWidth: 240,
        borderColor: selected ? Colors.black : mainBackgroundColor,
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
                      child: Down4Container(
                          height: headerHeight,
                          child: Image.asset('lib/src/assets/hashirama.jpg'),
                          borderColor: selected ? Colors.black : headerColor),
                    ),
                    Expanded(
                      child: GestureDetector(
                        child: Down4Container(
                          paddingLeft: 2.0,
                          paddingTop: 2.0,
                          height: headerHeight,
                          child: Text(
                            message.nm,
                            textDirection: TextDirection.ltr,
                          ),
                          borderColor: selected ? Colors.black : headerColor,
                          backgroundColor: headerColor,
                        ),
                      ),
                    ),
                  ],
                ),
                message.t == null
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        child: Down4Container(
                          paddingLeft: 2.0,
                          paddingBottom: 2.0,
                          paddingRight: 2.0,
                          paddingTop: 2.0,
                          borderColor: selected ? Colors.black : bodyColor,
                          backgroundColor: bodyColor,
                          child: Text(message.t!,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(color: Colors.black)),
                        ),
                      ),
                message.p == null
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        child: Down4Container(
                          borderColor: selected ? Colors.black : bodyColor,
                          backgroundColor: bodyColor,
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

class Down4Fit extends StatelessWidget {
  final Color? backgroundColor;
  final Color borderColor;
  final double? height, width;
  final double? padding;
  final double? paddingLeft, paddingRight, paddingTop, paddingBottom;
  final Widget? child;
  final BoxFit boxFit;

  const Down4Fit({
    Key? key,
    required this.borderColor,
    this.boxFit = BoxFit.contain,
    this.backgroundColor,
    this.height,
    this.width,
    this.padding,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(width: 0.5, color: borderColor)),
      child: FittedBox(
        fit: boxFit,
        child: child,
      ),
    );
  }
}

class Down4Sized extends StatelessWidget {
  final Color? backgroundColor;
  final Color borderColor;
  final double? height, width;
  final double? padding;
  final double? paddingLeft, paddingRight, paddingTop, paddingBottom;
  final Widget? child;
  final BoxFit boxFit;

  const Down4Sized({
    Key? key,
    required this.borderColor,
    this.boxFit = BoxFit.contain,
    this.backgroundColor,
    this.height,
    this.width,
    this.padding,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(width: 0.5, color: borderColor)),
      child: SizedBox(
        height: height,
        width: width,
        child: child,
      ),
    );
  }
}

class Down4Limited extends StatelessWidget {
  final Color? backgroundColor;
  final Color borderColor;
  final double? height, width, maxHeight, maxWidth, minHeight, minWidth;
  final double? padding;
  final double? paddingLeft, paddingRight, paddingTop, paddingBottom;
  final Widget? child;
  final BoxFit boxFit;

  const Down4Limited({
    Key? key,
    required this.borderColor,
    this.maxHeight,
    this.minHeight,
    this.maxWidth,
    this.minWidth,
    this.boxFit = BoxFit.contain,
    this.backgroundColor,
    this.height,
    this.width,
    this.padding,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(width: 0.5, color: borderColor)),
      child: LimitedBox(
        maxHeight: maxHeight ?? double.infinity,
        maxWidth: maxWidth ?? double.infinity,
        child: child,
      ),
    );
  }
}

class Down4Constrained extends StatelessWidget {
  final Color? backgroundColor;
  final Color borderColor;
  final double? height, width, maxHeight, maxWidth, minHeight, minWidth;
  final double? padding;
  final double? paddingLeft, paddingRight, paddingTop, paddingBottom;
  final Widget? child;
  final BoxFit boxFit;

  const Down4Constrained({
    Key? key,
    required this.borderColor,
    this.maxHeight,
    this.minHeight,
    this.maxWidth,
    this.minWidth,
    this.boxFit = BoxFit.contain,
    this.backgroundColor,
    this.height,
    this.width,
    this.padding,
    this.paddingBottom,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(width: 0.5, color: borderColor)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: maxHeight ?? double.infinity,
            minHeight: minHeight ?? 0.0,
            maxWidth: maxWidth ?? double.infinity,
            minWidth: minWidth ?? 0.0),
        child: child,
      ),
    );
  }
}
