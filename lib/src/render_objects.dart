import 'package:dartsv/dartsv.dart';
import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'dart:convert';
import 'render_utility.dart';
import 'package:file_picker/file_picker.dart';

class PinkTheme {
  static const buttonColor = Color.fromARGB(255, 250, 222, 224);
  static const bodyColor = buttonColor;
  static const backGroundColor = Color.fromARGB(255, 255, 241, 242);
  static const headerColor = Color.fromRGBO(255, 103, 154, 1);
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
    return Container(
        height: Palette3.height,
        margin: const EdgeInsets.only(left: 22.0, right: 22.0),
        decoration: BoxDecoration(
            boxShadow: !selected
                ? [
                    const BoxShadow(
                        color: Colors.black54,
                        blurRadius: 6.0,
                        spreadRadius: -6.0,
                        offset: Offset(8.0, 8.0),
                        blurStyle: BlurStyle.normal)
                  ]
                : null,
            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
            border: Border.all(
                width: 2.0,
                color: selected ? PinkTheme.black : Colors.transparent)),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: TextDirection.ltr,
            children: [
              GestureDetector(
                  onTap: () => imPress?.call(at, node.id),
                  onLongPress: () => imLongPress?.call(at, node.id),
                  child: Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4.0),
                        bottomLeft: Radius.circular(4.0),
                      )),
                      width: Palette3.height - 2.0, // borderWidth x2
                      child: Image.asset('lib/src/assets/hashirama.jpg',
                          fit: BoxFit.fill))),
              Expanded(
                  child: GestureDetector(
                      onTap: () => bodyPress?.call(at, node.id),
                      onLongPress: () => bodyLongPress?.call(at, node.id),
                      child: Material(
                          child: Container(
                              decoration: BoxDecoration(
                                  color: PinkTheme.headerColor,
                                  border: Border(
                                      left: BorderSide(
                                          color: selected
                                              ? PinkTheme.black
                                              : PinkTheme.headerColor,
                                          width: 1.0))),
                              padding:
                                  const EdgeInsets.only(left: 9.0, top: 10.0),
                              child: Text(
                                node.nm,
                                style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                              ))))),
              GestureDetector(
                  onTap: () => bodyPress?.call(at, node.id),
                  onLongPress: () => bodyLongPress?.call(at, node.id),
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: const BoxDecoration(
                        color: PinkTheme.headerColor,
                        borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4.0),
                            bottomRight: Radius.circular(4.0))),
                    child: Image.asset('lib/src/assets/rightBlackArrow.png'),
                  ))
            ]));
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
        child: Container(
            height: height,
            decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: PinkTheme.black,
                border: Border.all(color: Colors.black, width: 0.5)),
            child: TouchableOpacity(
                onPress: onPress,
                onLongPress: onLongPress,
                child: Material(
                    child: Container(
                        color: PinkTheme.buttonColor,
                        child: Center(
                            child: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))))))));

    return Expanded(
      child: Material(
          //child: Ink(
          child: Container(
              height: height,
              decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color: PinkTheme.buttonColor,
                  border: Border.all(color: Colors.black, width: 0.5)),
              child: TextButton(
                  //InkWell(
                  //borderRadius: BorderRadius.zero,
                  //splashColor: Colors.black,
                  //onTap: onPress,
                  onPressed: onPress,
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
  final TextInputType? textInputType;
  final void Function(String)? inputCallBack;
  const Console(
      {required this.bottomButtons,
      this.inputCallBack,
      this.textInputType,
      this.placeHolder,
      this.topButtons,
      this.extraButtons,
      Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      decoration:
          BoxDecoration(border: Border.all(width: 0.5, color: Colors.black)),
      child: Column(children: [
        inputCallBack != null
            ? Container(
                height: ConsoleButton.height,
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 0.5)),
                child: Material(
                    child: TextField(
                        keyboardType: textInputType,
                        textAlignVertical: TextAlignVertical.center,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                            hintText: placeHolder, border: InputBorder.none),
                        textDirection: TextDirection.ltr,
                        onChanged: (value) => inputCallBack?.call(value))))
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
    );
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
        child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.66),
            decoration: BoxDecoration(
                border: Border.all(
                    width: 2.0,
                    color: selected ? Colors.black : Colors.transparent)),
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
                            child: SizedBox(
                                height: _headerHeight,
                                child: Image.asset(
                                    'lib/src/assets/hashirama.jpg'))),
                        Expanded(
                            child: GestureDetector(
                                onTap: () => select?.call(message.id),
                                child: Container(
                                    padding: const EdgeInsets.only(
                                        left: 2.0, top: 2.0, right: 2.0),
                                    color: PinkTheme.headerColor,
                                    height: _headerHeight,
                                    child: Text(
                                      message.nm,
                                      textDirection: TextDirection.ltr,
                                    ))))
                      ]),
                  message.t == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () => select?.call(message.id),
                          child: Container(
                              padding: const EdgeInsets.all(2.0),
                              color: PinkTheme.bodyColor,
                              child: Text(message.t!,
                                  textDirection: TextDirection.ltr,
                                  style:
                                      const TextStyle(color: Colors.black)))),
                  message.p == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () => select?.call(message.id),
                          child: Container(
                              color: PinkTheme.bodyColor,
                              child: Image.memory(base64.decode(
                                  base64.normalize(
                                      message.p!.replaceAll("\n", ""))))))
                ]))));
  }
}

class PaletteList extends StatelessWidget {
  final List<Palette3> palettes;
  const PaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                reverse: true,
                itemBuilder: (c, i) => i == 0
                    ? const SizedBox.shrink()
                    : i == palettes.length + 2 - 1
                        ? const SizedBox.shrink()
                        : palettes[i - 1],
                separatorBuilder: (c, i) => Container(height: 16.0),
                itemCount: palettes.length + 2)));
  }
}

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  const MessageList({required this.messages, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                itemBuilder: (c, i) => i == 0
                    ? const SizedBox.shrink()
                    : i == messages.length + 2 - 1
                        ? const SizedBox.shrink()
                        : messages[i],
                separatorBuilder: (c, i) => Container(height: 16.0),
                itemCount: messages.length + 2)));
  }
}

class PaletteMaker extends StatefulWidget {
  final void Function(Map<String, String>) infoCallBack;
  final void Function(Identifier)? go;
  final Identifier parentID;
  final NodeTypes type;
  final NodeTypes? parentType;
  PaletteMaker(
      {required this.infoCallBack,
      this.go,
      this.type = NodeTypes.usr,
      this.parentType,
      this.parentID = "",
      Key? key})
      : super(key: key);

  @override
  State<PaletteMaker> createState() => _PaletteMakerState();
}

class _PaletteMakerState extends State<PaletteMaker> {
  Map<String, String> info = {};
  late NodeTypes type;
  @override
  void initState() {
    super.initState();
    type = widget.type;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: Palette3.height,
        margin: const EdgeInsets.only(left: 22.0, right: 22.0),
        decoration: BoxDecoration(
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6.0,
                  spreadRadius: -6.0,
                  offset: Offset(8.0, 8.0),
                  blurStyle: BlurStyle.normal)
            ],
            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
            border: Border.all(width: 2.0, color: Colors.transparent)),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: TextDirection.ltr,
            children: [
              GestureDetector(
                  onTap: () async {
                    FilePickerResult? r = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'png', 'jpeg'],
                        withData: true);
                    if (r != null) {
                      setState(() {
                        info['image'] = base64Encode(r.files.single.bytes!);
                      });
                      widget.infoCallBack(info);
                    }
                  },
                  child: Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4.0),
                        bottomLeft: Radius.circular(4.0),
                      )),
                      width: Palette3.height - 2.0, // borderWidth x2
                      child: info['image'] == null
                          ? Image.asset(
                              'lib/src/assets/picture_place_holder_2.png',
                              fit: BoxFit.cover,
                            )
                          : Image.memory(
                              base64Decode(info['image']!),
                              gaplessPlayback: true,
                              fit: BoxFit.cover,
                            ))),
              Expanded(
                  child: Material(
                      child: Container(
                          padding: const EdgeInsets.only(left: 10.0, top: 10.0),
                          color: PinkTheme.headerColor,
                          child: TextField(
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                  hintText: "Pick a name and an image!",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(
                                      bottom: (Palette3.height) / 2)),
                              textDirection: TextDirection.ltr,
                              onChanged: ((value) {
                                setState(() => info['name'] = value);
                                widget.infoCallBack(info);
                              }))))),
              GestureDetector(
                  onTap: () => info['name'] != null
                      ? widget.go?.call(sha1(widget.parentID.codeUnits +
                              info['name']!.codeUnits)
                          .toString())
                      : {},
                  child: Container(
                      padding: const EdgeInsets.all(2.0),
                      width: Palette3.height - 2.0,
                      decoration: const BoxDecoration(
                          color: PinkTheme.headerColor,
                          borderRadius: BorderRadius.only(
                              topRight: Radius.circular(4.0),
                              bottomRight: Radius.circular(4.0))),
                      child: widget.type != NodeTypes.usr
                          ? Image.asset('lib/src/assets/rightBlackArrow.png')
                          : const SizedBox.shrink()))
            ]));
  }
}

class PaletteMakerList extends StatelessWidget {
  final List<PaletteMaker> palettes;
  const PaletteMakerList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                reverse: true,
                itemBuilder: (c, i) => i == 0
                    ? const SizedBox.shrink()
                    : i == palettes.length + 2 - 1
                        ? const SizedBox.shrink()
                        : palettes[i - 1],
                separatorBuilder: (c, i) => Container(height: 16.0),
                itemCount: palettes.length + 2)));
  }
}
