import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'data_objects.dart';
import 'render_utility.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:video_player/video_player.dart';

class PinkTheme {
  static const buttonColor = Color.fromARGB(255, 250, 222, 224);
  static const bodyColor = buttonColor;
  static const inactivatedButtonColor = Color.fromARGB(255, 219, 214, 214);
  static const backGroundColor = Color.fromARGB(255, 255, 241, 242);
  static const headerColor = Color.fromARGB(255, 236, 155, 182);
  static const imageBorderColor = Color.fromARGB(255, 143, 29, 67);
  static const borderColor = Colors.black;
  static const qrColor = Color.fromARGB(255, 56, 3, 17);
  static const black = Colors.black;
  static const Map<Nodes, Color> nodeColors = {
    Nodes.root: Color.fromARGB(255, 53, 3, 20),
    Nodes.hyperchat: Color.fromARGB(255, 212, 168, 182),
    Nodes.checkpoint: Color.fromARGB(255, 22, 94, 161),
    Nodes.event: Color.fromARGB(255, 95, 28, 219),
    Nodes.item: Color.fromARGB(255, 187, 108, 34),
    Nodes.journal: Color.fromARGB(255, 90, 62, 134),
    Nodes.market: Color.fromARGB(255, 34, 134, 64),
    Nodes.ticket: Color.fromARGB(255, 233, 220, 30),
    Nodes.user: Color.fromARGB(255, 230, 174, 193),
    Nodes.friend: Color.fromARGB(255, 230, 174, 193),
    Nodes.group: Color.fromARGB(255, 175, 134, 209),
    Nodes.nonFriend: Color.fromARGB(255, 158, 92, 114),
  };
}

class RealButton {
  final ConsoleButton mainButton;
  final List<ConsoleButton>? extraButtons;
  final bool showExtra;
  RealButton(
      {required this.mainButton, this.extraButtons, this.showExtra = false});
}

class Down4PalettePage extends StatelessWidget {
  final List<Palette> palettes;
  final List<RealButton> bottomButtons;
  final List<RealButton>? topButtons;
  final List<ConsoleInput>? bottomInputs, topInputs;
  const Down4PalettePage({
    required this.palettes,
    required this.bottomButtons,
    this.topButtons,
    this.bottomInputs,
    this.topInputs,
    Key? key,
  }) : super(key: key);

  List<Widget> getExtraTopButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 31) / (topButtons?.length ?? 1);
    List<Widget> extras = [];
    int i = 0;
    for (final b in topButtons ?? <RealButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
            bottom: 16.0 + (ConsoleButton.height * 2),
            left: 16.0 + (buttonWidth * i),
            child: Container(
              height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
              width: (screenWidth - 32) / topButtons!.length,
              decoration: BoxDecoration(border: Border.all(width: 0.5)),
              child: Column(children: b.extraButtons!),
            )));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  List<Widget> getExtraBottomButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 30) / bottomButtons.length;
    List<Widget> extras = [];
    int i = 0;
    for (final b in bottomButtons) {
      if (b.showExtra) {
        extras.add(Positioned(
          bottom: 16.0 + ConsoleButton.height,
          left: 16.0 + (buttonWidth * i),
          child: Container(
            height: (b.extraButtons!.length * ConsoleButton.height) + 1,
            width: buttonWidth,
            decoration: BoxDecoration(border: Border.all(width: 0.5)),
            child: Column(children: b.extraButtons!),
          ),
        ));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final extraBottomButtons = getExtraBottomButtons(screenWidth);
    final extraTopButtons = getExtraTopButtons(screenWidth);
    return Container(
      color: PinkTheme.backGroundColor,
      child: Stack(children: [
        Column(children: [
          PaletteList(palettes: palettes),
          Console(
            bottomButtons: bottomButtons.map((e) => e.mainButton).toList(),
            topButtons: topButtons?.map((e) => e.mainButton).toList(),
            topInputs: topInputs,
            inputs: bottomInputs,
          )
        ]),
        ...extraBottomButtons,
        ...extraTopButtons,
      ]),
    );
  }
}

class Down4ColumnBackground extends StatelessWidget {
  final List<Widget> children;
  const Down4ColumnBackground({required this.children, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Column(
          // crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: children),
    );
  }
}

class Down4StackBackground extends StatelessWidget {
  final List<Widget> children;
  const Down4StackBackground({required this.children, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinkTheme.backGroundColor,
      child: Stack(children: children),
    );
  }
}

class Down4StackBackground2 extends StatelessWidget {
  final List<Widget> children;
  final List<RealButton> bottomButtons;
  final List<RealButton>? topButtons;
  final List<ConsoleInput>? bottomInputs, topInputs;
  const Down4StackBackground2({
    required this.children,
    required this.bottomButtons,
    this.topButtons,
    this.bottomInputs,
    this.topInputs,
    Key? key,
  }) : super(key: key);

  List<Widget> getExtraTopButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 31) / (topButtons?.length ?? 1);
    List<Widget> extras = [];
    int i = 0;
    for (final b in topButtons ?? <RealButton>[]) {
      if (b.showExtra) {
        extras.add(Positioned(
            bottom: 16.0 + (ConsoleButton.height * 2),
            left: 16.0 + (buttonWidth * i),
            child: Container(
              height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
              width: (screenWidth - 32) / topButtons!.length,
              decoration: BoxDecoration(border: Border.all(width: 0.5)),
              child: Column(children: b.extraButtons!),
            )));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  List<Widget> getExtraBottomButtons(double screenWidth) {
    final buttonWidth = (screenWidth - 31) / bottomButtons.length;
    List<Widget> extras = [];
    int i = 0;
    for (final b in bottomButtons) {
      if (b.showExtra) {
        extras.add(Positioned(
          bottom: 16.0 + ConsoleButton.height,
          left: 16.0 + (buttonWidth * i),
          child: Container(
            height: b.extraButtons!.length * (ConsoleButton.height + 0.5),
            width: buttonWidth,
            decoration: BoxDecoration(border: Border.all(width: 0.5)),
            child: Column(children: b.extraButtons!),
          ),
        ));
      } else {
        extras.add(const SizedBox.shrink());
      }
      i++;
    }
    return extras;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final extraBottomButtons = getExtraBottomButtons(screenWidth);
    final extraTopButtons = getExtraTopButtons(screenWidth);
    return Container(
      color: PinkTheme.backGroundColor,
      child: Stack(children: [
        ...children,
        Column(children: [
          const Spacer(),
          Console(
            bottomButtons: bottomButtons.map((e) => e.mainButton).toList(),
            topButtons: topButtons?.map((e) => e.mainButton).toList(),
            topInputs: topInputs,
            inputs: bottomInputs,
          )
        ]),
        ...extraBottomButtons,
        ...extraTopButtons,
      ]),
    );
  }
}

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
        child: Image.asset(assetPathFromLib, fit: BoxFit.cover),
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

class ProfileWidget extends StatelessWidget {
  final Node node;
  const ProfileWidget({
    required this.node,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
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
          Image.memory(node.image.data, fit: BoxFit.cover),
          const SizedBox(height: 8.0),
          Text(
            node.name + (node.lastName != null ? " " + node.lastName! : ""),
            style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8.0),
          Container(
              padding: const EdgeInsets.all(8.0),
              child: node.description != null
                  ? Text(node.description!, textAlign: TextAlign.justify)
                  : const SizedBox.shrink()),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
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

  const Palette({
    required this.node,
    required this.at,
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
    return Container(
      height: Palette.height,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: () => imPress?.call(node.id, at),
            onLongPress: () => imLongPress?.call(node.id, at),
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  bottomLeft: Radius.circular(4.0),
                ),
              ),
              width: Palette.height - 2.0, // borderWidth x2
              child: Image.memory(
                node.image.data,
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
                  color: PinkTheme.nodeColors[node.type],
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
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
          buttonsInfo.isNotEmpty
              ? Row(
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
              : Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    color: PinkTheme.nodeColors[node.type],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4.0),
                      bottomRight: Radius.circular(4.0),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class NewPalette extends StatelessWidget {
  static const double height = 60.0;
  final Node node;
  final void Function(String)? imPress,
      bodyPress,
      imLongPress,
      bodyLongPress,
      goPress,
      goLongPress;
  final bool selected;

  const NewPalette({
    required this.node,
    this.imPress,
    this.bodyPress,
    this.imLongPress,
    this.bodyLongPress,
    this.goPress,
    this.goLongPress,
    this.selected = false,
    Key? key,
  }) : super(key: key);

  NewPalette invertedSelection() {
    return NewPalette(
      node: node,
      selected: !selected,
      imPress: imPress,
      imLongPress: imLongPress,
      bodyPress: bodyPress,
      bodyLongPress: bodyLongPress,
      goPress: goPress,
      goLongPress: goLongPress,
    );
  }

  NewPalette deactivated() {
    return NewPalette(node: node);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Palette.height,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: () => imPress?.call(node.id),
            onLongPress: () => imLongPress?.call(node.id),
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  bottomLeft: Radius.circular(4.0),
                ),
              ),
              width: Palette.height - 2.0, // borderWidth x2
              child: Image.memory(
                node.image.data,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => bodyPress?.call(node.id),
              onLongPress: () => bodyLongPress?.call(node.id),
              child: Container(
                decoration: BoxDecoration(
                  color: PinkTheme.nodeColors[node.type],
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
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
          goPress != null
              ? GestureDetector(
                  onTap: () => goPress?.call(node.id),
                  onLongPress: () => goPress?.call(node.id),
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: PinkTheme.nodeColors[node.type],
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4.0),
                        bottomRight: Radius.circular(4.0),
                      ),
                    ),
                    child: Image.asset("lib/src/assets/rightBlackArrow.png"),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    color: PinkTheme.nodeColors[node.type],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4.0),
                      bottomRight: Radius.circular(4.0),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class ConsoleButton extends StatelessWidget {
  static const double height = 26.0;
  final String name;
  final bool isSpecial, isMode, shouldBeDownButIsnt, isActivated;
  final void Function() onPress;
  final void Function()? onLongPress;
  final void Function()? onLongPressUp;

  const ConsoleButton({
    required this.name,
    required this.onPress,
    this.shouldBeDownButIsnt = false,
    this.isMode = false,
    this.isSpecial = false,
    this.isActivated = true,
    this.onLongPress,
    this.onLongPressUp,
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
        child: isActivated
            ? TouchableOpacity(
                shouldBeDownButIsnt: shouldBeDownButIsnt,
                onPress: onPress,
                onLongPress: onLongPress,
                onLongPressUp: onLongPressUp,
                child: Container(
                  color: PinkTheme.buttonColor,
                  child: Center(
                    child: Text(
                      name,
                      style: TextStyle(
                        decoration: isSpecial ? TextDecoration.underline : null,
                        decorationStyle: TextDecorationStyle.solid,
                        fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                color: PinkTheme.inactivatedButtonColor,
                child: Center(
                  child: Text(
                    name,
                    style: TextStyle(
                      decoration: isSpecial ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.solid,
                      fontStyle: isMode ? FontStyle.italic : FontStyle.normal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// Could refactor to use Down4Input
class ConsoleInput extends StatefulWidget {
  final TextInputType type;
  final String placeHolder;
  final String value;
  final String prefix;
  final void Function(String) inputCallBack;
  final Key k = GlobalKey();
  TextEditingController tec;
  ConsoleInput(
      {this.type = TextInputType.text,
      required this.inputCallBack,
      required this.placeHolder,
      required this.tec,
      this.prefix = "",
      this.value = "",
      Key? key})
      : super(key: key);

  @override
  _ConsoleInputState createState() => _ConsoleInputState();
}

class _ConsoleInputState extends State<ConsoleInput> {
  @override
  void initState() {
    super.initState();
    widget.tec = widget.tec
      ..text = widget.value
      ..selection = TextSelection.collapsed(offset: widget.value.length);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(
          minHeight: ConsoleButton.height,
          maxHeight: ConsoleButton.height * 4,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 0.5),
        ),
        child: TextField(
          controller: widget.tec,
          key: widget.k,
          maxLines: null,
          keyboardType: widget.type,
          textAlignVertical: TextAlignVertical.center,
          textAlign: TextAlign.center,
          style: TextStyle(),
          decoration: InputDecoration(
            isDense: true,
            isCollapsed: true,
            contentPadding: const EdgeInsets.all(2.0),
            hintText: widget.placeHolder,
            border: InputBorder.none,
          ),
          textDirection: TextDirection.ltr,
          onChanged: (value) {
            if (value.isNotEmpty) {
              String output;
              if (value.substring(0, widget.prefix.length) != widget.prefix) {
                output = widget.prefix + value;
              } else {
                output = value;
              }
              setState(() {
                widget.tec.text = output;
                widget.tec.selection =
                    TextSelection.collapsed(offset: output.length);
              });
              widget.inputCallBack(output.substring(widget.prefix.length));
            } else {
              widget.inputCallBack(value);
            }
          },
        ),
      ),
    );
  }
}

class Down4Input extends StatefulWidget {
  final TextInputType type;
  final String placeHolder;
  final String value;
  final String prefix;
  final TextAlign textAlign;
  final EdgeInsets padding;
  final void Function(String) inputCallBack;
  const Down4Input(
      {this.type = TextInputType.text,
      required this.inputCallBack,
      required this.placeHolder,
      this.padding = EdgeInsets.zero,
      this.textAlign = TextAlign.left,
      this.prefix = "",
      this.value = "",
      Key? key})
      : super(key: key);

  @override
  _Down4InputState createState() => _Down4InputState();
}

class _Down4InputState extends State<Down4Input> {
  var tec = TextEditingController();
  final Key k = GlobalKey();

  @override
  void initState() {
    super.initState();
    tec = tec
      ..text = widget.value
      ..selection = TextSelection.collapsed(offset: widget.value.length);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: tec,
      key: k,
      keyboardType: widget.type,
      textAlignVertical: TextAlignVertical.top,
      textAlign: widget.textAlign,
      decoration: InputDecoration(
          contentPadding: widget.padding,
          hintText: widget.placeHolder,
          border: InputBorder.none),
      textDirection: TextDirection.ltr,
      onChanged: (value) {
        if (value.isNotEmpty) {
          String output;
          if (value.substring(0, widget.prefix.length) != widget.prefix) {
            output = widget.prefix + value;
          } else {
            output = value;
          }
          setState(() {
            tec.text = output;
            tec.selection = TextSelection.collapsed(offset: output.length);
          });
          widget.inputCallBack(output.substring(widget.prefix.length));
        } else {
          widget.inputCallBack(value);
        }
      },
    );
  }
}

class Console extends StatelessWidget {
  final List<ConsoleButton>? topButtons;
  final List<ConsoleButton> bottomButtons;
  final CameraPreview? cameraPreview;
  final double? aspectRatio;
  final bool? toMirror, images;
  final List<Down4Media>? medias;
  final void Function(Down4Media)? selectMedia;
  final String? imagePreviewPath;
  final VideoPlayerController? videoPlayerController;
  final List<ConsoleInput>? inputs, topInputs;
  const Console({
    required this.bottomButtons,
    this.selectMedia,
    this.images,
    this.medias,
    this.imagePreviewPath,
    this.videoPlayerController,
    this.toMirror,
    this.aspectRatio,
    this.cameraPreview,
    this.inputs,
    this.topInputs,
    this.topButtons,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // both margin (16+16=32) + 1 = 0.5x1 for the Main container border
    final double mirror = toMirror == true ? math.pi : 0;
    var camWidthAndHeight = MediaQuery.of(context).size.width - 33.0;
    return Container(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      decoration:
          BoxDecoration(border: Border.all(width: 0.5, color: Colors.black)),
      child: Column(
        children: [
          Row(textDirection: TextDirection.ltr, children: topInputs ?? []),
          Row(textDirection: TextDirection.ltr, children: inputs ?? []),
          images == true
              ? Container(
                  width: camWidthAndHeight,
                  height: camWidthAndHeight,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 0.5),
                    color: PinkTheme.buttonColor,
                  ),
                  child: (ListView.builder(
                      itemCount: (medias?.length ?? 0 / 4.0).ceil(),
                      itemBuilder: ((context, index) {
                        Widget f(int i) {
                          if ((medias?.length ?? 0) > i) {
                            return medias?[i].metadata.isVideo == true
                                ? SizedBox(
                                    height: (camWidthAndHeight / 4) - 0.25,
                                    width: (camWidthAndHeight / 4) - 0.25,
                                    child: Down4VideoPlayer(
                                      vid: medias![i].file!,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: () => selectMedia?.call(medias![i]),
                                    child: SizedBox(
                                      height: (camWidthAndHeight / 5) - 0.2,
                                      width: (camWidthAndHeight / 5) - 0.2,
                                      child: Image.memory(
                                        medias![i].data,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                          } else {
                            return const SizedBox.shrink();
                          }
                        }

                        return Row(
                          children: [
                            f((index * 5)),
                            f((index * 5) + 1),
                            f((index * 5) + 2),
                            f((index * 5) + 3),
                            f((index * 5) + 4)
                          ],
                        );
                      }))),
                )
              : cameraPreview != null
                  ? Container(
                      width: camWidthAndHeight,
                      height: camWidthAndHeight,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: .5)),
                      child: Transform.scale(
                          alignment: Alignment.center,
                          scaleY: aspectRatio,
                          child: AspectRatio(
                              aspectRatio: aspectRatio!,
                              child: cameraPreview!)))
                  : imagePreviewPath != null
                      ? Container(
                          width: camWidthAndHeight,
                          height: camWidthAndHeight,
                          decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.black, width: 0.5)),
                          child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(mirror),
                              child: Image.file(
                                io.File(imagePreviewPath!),
                                fit: BoxFit.cover,
                              )))
                      : videoPlayerController != null
                          ? Container(
                              clipBehavior: Clip.hardEdge,
                              width: camWidthAndHeight,
                              height: camWidthAndHeight,
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.black, width: 0.5)),
                              child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(mirror),
                                  child: Transform.scale(
                                      scaleY: aspectRatio,
                                      child:
                                          VideoPlayer(videoPlayerController!))))
                          : const SizedBox.shrink(),
          Row(
            children: topButtons ?? [],
            textDirection: TextDirection.ltr,
          ),
          Row(
            children: bottomButtons,
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  static const double headerHeight = 24.0;
  final String at;
  final Down4Message message;
  final bool myMessage, selected, hasHeader;
  final void Function(Identifier, Identifier)? select;
  const ChatMessage({
    required this.message,
    required this.myMessage,
    required this.at,
    required this.hasHeader,
    this.selected = false,
    this.select,
    Key? key,
  }) : super(key: key);

  ChatMessage invertedSelection() {
    return ChatMessage(
      hasHeader: hasHeader,
      message: message,
      myMessage: myMessage,
      at: at,
      select: select,
      selected: !selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.76;
    return Align(
      alignment: message.isChat == false
          ? Alignment.topCenter
          : myMessage
              ? Alignment.topRight
              : Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 22.0, right: 22.0),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
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
            border: Border.all(
                width: 2.0,
                color: selected ? Colors.black : Colors.transparent)),
        child: IntrinsicWidth(
          child: Column(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              hasHeader
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        GestureDetector(
                          onTap: () => select?.call(message.messageID, at),
                          child: Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4.0),
                              ),
                            ),
                            height: ChatMessage.headerHeight,
                            width: ChatMessage.headerHeight,
                            child: Image.memory(
                              base64Decode(message.senderThumbnail),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => select?.call(message.messageID, at),
                            child: Container(
                              clipBehavior: Clip.hardEdge,
                              decoration: const BoxDecoration(
                                color: PinkTheme.headerColor,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(4.0),
                                ),
                              ),
                              padding: const EdgeInsets.only(
                                  left: 2.0, top: 2.0, right: 2.0),
                              height: ChatMessage.headerHeight,
                              child: Text(
                                message.senderName,
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
              message.text == null || message.text == ""
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: () => select?.call(message.messageID, at),
                      child: Container(
                        padding: const EdgeInsets.all(6.0),
                        clipBehavior: Clip.hardEdge,
                        decoration: message.media == null
                            ? BoxDecoration(
                                color: PinkTheme.bodyColor,
                                borderRadius: hasHeader
                                    ? const BorderRadius.only(
                                        bottomLeft: Radius.circular(4.0),
                                        bottomRight: Radius.circular(4.0),
                                      )
                                    : const BorderRadius.all(
                                        Radius.circular(4.0),
                                      ),
                              )
                            : BoxDecoration(
                                color: PinkTheme.bodyColor,
                                borderRadius: hasHeader
                                    ? null
                                    : const BorderRadius.only(
                                        topRight: Radius.circular(4.0),
                                        topLeft: Radius.circular(4.0),
                                      ),
                              ),
                        child: Text(
                          message.text!,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
              message.media != null
                  ? message.media!.metadata.isVideo
                      ? Container(
                          clipBehavior: Clip.hardEdge,
                          height: maxWidth,
                          width: maxWidth,
                          decoration: BoxDecoration(
                            borderRadius: hasHeader ||
                                    (message.text != null && message.text != "")
                                ? const BorderRadius.only(
                                    bottomLeft: Radius.circular(4.0),
                                    bottomRight: Radius.circular(4.0),
                                  )
                                : const BorderRadius.all(Radius.circular(4.0)),
                          ),
                          child: Down4VideoPlayer(
                            vid: message.media!.file!,
                            key: GlobalKey(),
                          ))
                      : GestureDetector(
                          onTap: () => select?.call(message.messageID, at),
                          child: Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              borderRadius: hasHeader ||
                                      (message.text != null &&
                                          message.text != "")
                                  ? const BorderRadius.only(
                                      bottomLeft: Radius.circular(4.0),
                                      bottomRight: Radius.circular(4.0),
                                    )
                                  : const BorderRadius.all(
                                      Radius.circular(4.0)),
                            ),
                            child: Image.memory(
                              message.media!.data,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        )
                  : const SizedBox.shrink()
            ],
          ),
        ),
      ),
    );
  }
}

class Down4VideoPlayer extends StatefulWidget {
  final File vid;
  const Down4VideoPlayer({required this.vid, Key? key}) : super(key: key);

  @override
  _Down4VideoPlayerState createState() => _Down4VideoPlayerState();
}

class _Down4VideoPlayerState extends State<Down4VideoPlayer> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    initController();
  }

  Future<void> initController() async {
    _videoController = VideoPlayerController.file(widget.vid);
    await _videoController?.initialize();
    setState(() {});
  }

  void touch() {
    if (_videoController?.value.isPlaying == true) {
      _videoController?.pause();
    } else {
      _videoController?.play();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _videoController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: touch,
      child: _videoController != null
          ? VideoPlayer(_videoController!)
          : const SizedBox.shrink(),
    );
  }
}

class PaletteList extends StatelessWidget {
  final List<Palette> palettes;
  const PaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ScrollConfiguration(
        behavior: NoGlow(),
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 0),
          reverse: true,
          itemBuilder: (c, i) => i == 0
              ? const SizedBox.shrink()
              : i == palettes.length + 2 - 1
                  ? const SizedBox.shrink()
                  : palettes[i - 1],
          separatorBuilder: (c, i) => Container(height: 16.0),
          itemCount: palettes.length + 2,
        ),
      ),
    );
  }
}

class NewPaletteList extends StatelessWidget {
  final List<NewPalette> palettes;
  const NewPaletteList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ScrollConfiguration(
        behavior: NoGlow(),
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 0),
          reverse: true,
          itemBuilder: (c, i) => i == 0
              ? const SizedBox.shrink()
              : i == palettes.length + 2 - 1
                  ? const SizedBox.shrink()
                  : palettes[i - 1],
          separatorBuilder: (c, i) => Container(height: 16.0),
          itemCount: palettes.length + 2,
        ),
      ),
    );
  }
}

class MessageList4 extends StatelessWidget {
  final Map<Identifier, ChatMessage> messageMap;
  final void Function(String, String) select;
  final void Function(ChatMessage) cache;
  final List<Identifier> messages;
  final Node self;
  const MessageList4({
    required this.messages,
    required this.self,
    required this.messageMap,
    required this.select,
    required this.cache,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Down4Message? prevMsgCache;
    return Expanded(
      child: ScrollConfiguration(
        behavior: NoGlow(),
        child: ListView.separated(
          reverse: true,
          itemBuilder: (c, i) {
            if (i == 0 || i == messages.length + 2 - 1) {
              return const SizedBox.shrink();
            }
            if (messageMap[messages[i - 1]] != null) {
              return messageMap[messages[i - 1]]!;
            } else {
              Down4Message? prevMsg;
              if (i < messages.length) {
                prevMsg = messageMap[messages[i]]?.message ??
                    Down4Message.fromLocal(messages[i]);
              }
              final msg =
                  prevMsgCache ?? Down4Message.fromLocal(messages[i - 1]);
              final chat = ChatMessage(
                message: msg,
                myMessage: msg.senderID == self.id,
                at: "",
                hasHeader: msg.senderID != prevMsg?.senderID,
                select: select,
              );
              cache(chat);
              prevMsgCache = prevMsg;
              return chat;
            }
          },
          separatorBuilder: (c, i) => Container(height: 4.0),
          itemCount: messages.length + 2,
        ),
      ),
    );
  }
}

class DynamicList extends StatelessWidget {
  final List<dynamic> palettes;
  const DynamicList({required this.palettes, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: ScrollConfiguration(
            behavior: NoGlow(),
            child: ListView.separated(
                padding: const EdgeInsets.only(top: 0),
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

class UserPaletteMaker extends StatelessWidget {
  final void Function(Map<String, String>) infoCallBack;
  final Map<String, dynamic> info;
  const UserPaletteMaker(
      {required this.infoCallBack, required this.info, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tec = TextEditingController()
      ..text = info['id'].toLowerCase()
      ..selection = TextSelection.collapsed(offset: info['id'].length);
    return Container(
      height: Palette.height,
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
              if (r?.files.single.bytes != null) {
                infoCallBack(
                  {...info, 'image': base64Encode(r!.files.single.bytes!)},
                );
              }
            },
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.0),
                bottomLeft: Radius.circular(4.0),
              )),
              width: Palette.height - 2.0, // borderWidth x2
              child: info['image'] == null || info['image'] == ""
                  ? Image.asset(
                      'lib/src/assets/picture_place_holder_2.png',
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Image.memory(
                      base64Decode(info['image']!),
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                color: PinkTheme.headerColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4.0),
                  bottomRight: Radius.circular(4.0),
                ),
              ),
              padding: const EdgeInsets.only(left: 10.0, top: 10.0),
              child: TextField(
                controller: tec,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: info['id'] == "" ? "" : "@",
                  hintText: "@username",
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.only(bottom: Palette.height / 2),
                ),
                textDirection: TextDirection.ltr,
                onChanged: ((value) {
                  infoCallBack({...info, 'id': value.toLowerCase()});
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserMakerPalette extends StatelessWidget {
  static const double height = 60.0;
  final String name, lastName, id;
  final List<int> image;
  final void Function() selectFile;

  const UserMakerPalette({
    required this.name,
    required this.lastName,
    required this.id,
    required this.selectFile,
    required this.image,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Palette.height,
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6.0,
            spreadRadius: -6.0,
            offset: Offset(8.0, 8.0),
            blurStyle: BlurStyle.normal,
          ),
        ],
        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        border: Border.all(width: 2.0, color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: selectFile,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  bottomLeft: Radius.circular(4.0),
                ),
              ),
              width: Palette.height - 2.0, // borderWidth x2
              child: image.isNotEmpty
                  ? Image.memory(
                      Uint8List.fromList(image),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Image.asset(
                      'lib/src/assets/picture_place_holder_2.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: PinkTheme.headerColor,
                border: Border(
                  left: BorderSide(color: PinkTheme.headerColor, width: 1.0),
                ),
              ),
              padding: const EdgeInsets.only(left: 6.0, top: 5.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (name == '' ? "Name" : name) +
                        " " +
                        (lastName == '' ? "" : lastName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  Text(
                    "@" + (id == '' ? "username" : id),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.normal),
                  )
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2.0),
            decoration: const BoxDecoration(
              color: PinkTheme.headerColor,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(4.0),
                bottomRight: Radius.circular(4.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaletteMaker extends StatelessWidget {
  final void Function(String) nameCallBack;
  final void Function(Uint8List) imageCallBack;
  final String name, id;
  final String hintText;
  final Uint8List image;
  final void Function(Identifier)? go;
  final Nodes type;
  final Nodes? parentType;
  const PaletteMaker({
    required this.id,
    required this.name,
    required this.nameCallBack,
    required this.imageCallBack,
    required this.image,
    required this.hintText,
    this.go,
    this.type = Nodes.user,
    this.parentType,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        height: Palette.height,
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
                  if (r?.files.single.bytes != null) {
                    imageCallBack(r!.files.single.bytes!);
                  }
                },
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.0),
                    bottomLeft: Radius.circular(4.0),
                  )),
                  width: Palette.height - 2.0, // borderWidth x2
                  child: image.isEmpty
                      ? Image.asset(
                          'lib/src/assets/picture_place_holder_2.png',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Image.memory(
                          image,
                          gaplessPlayback: true,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              Expanded(
                child: Container(
                    padding: const EdgeInsets.only(left: 10.0, top: 10.0),
                    color: PinkTheme.nodeColors[type], //PinkTheme.headerColor,
                    child: Down4Input(
                      inputCallBack: nameCallBack,
                      placeHolder: hintText,
                      padding:
                          const EdgeInsets.only(bottom: Palette.height / 2),
                    ) // TextField(
                    //   textAlignVertical: TextAlignVertical.top,
                    //   decoration: InputDecoration(
                    //       hintText: hintText,
                    //       border: InputBorder.none,
                    //       contentPadding: const EdgeInsets.only(
                    //           bottom: (SingleActionPalette.height) / 2)),
                    //   textDirection: TextDirection.ltr,
                    //   onChanged: nameCallBack,
                    // ),
                    ),
              ),
              GestureDetector(
                  onTap: () {
                    if (name.isNotEmpty && image.isNotEmpty) {
                      go?.call(id);
                    }
                  },
                  child: Container(
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.all(2.0),
                      width: type != Nodes.user ? Palette.height - 2.0 : 4.0,
                      decoration: BoxDecoration(
                          color: PinkTheme
                              .nodeColors[type], //PinkTheme.headerColor,
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4.0),
                              bottomRight: Radius.circular(4.0))),
                      child: go != null
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

// class LocalPaletteMaker extends StatelessWidget {
//   final void Function(String) nameCallBack;
//   final void Function(Uint8List) imageCallBack;
//   final String name, id;
//   final String hintText;
//   final Uint8List image;
//   final LocalNodes type;
//   const LocalPaletteMaker({
//     required this.id,
//     required this.name,
//     required this.nameCallBack,
//     required this.imageCallBack,
//     required this.image,
//     required this.hintText,
//     required this.type,
//     Key? key,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: Palette.height,
//       margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//       decoration: BoxDecoration(
//           boxShadow: const [
//             BoxShadow(
//                 color: Colors.black54,
//                 blurRadius: 6.0,
//                 spreadRadius: -6.0,
//                 offset: Offset(8.0, 8.0),
//                 blurStyle: BlurStyle.normal)
//           ],
//           borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//           border: Border.all(width: 2.0, color: Colors.transparent)),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         textDirection: TextDirection.ltr,
//         children: [
//           GestureDetector(
//             onTap: () async {
//               FilePickerResult? r = await FilePicker.platform.pickFiles(
//                   type: FileType.custom,
//                   allowedExtensions: ['jpg', 'png', 'jpeg'],
//                   withData: true);
//               if (r?.files.single.bytes != null) {
//                 imageCallBack(r!.files.single.bytes!);
//               }
//             },
//             child: Container(
//               clipBehavior: Clip.hardEdge,
//               decoration: const BoxDecoration(
//                   borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(4.0),
//                 bottomLeft: Radius.circular(4.0),
//               )),
//               width: Palette.height - 2.0, // borderWidth x2
//               child: image.isEmpty
//                   ? Image.asset(
//                       'lib/src/assets/picture_place_holder_2.png',
//                       fit: BoxFit.cover,
//                       gaplessPlayback: true,
//                     )
//                   : Image.memory(
//                       image,
//                       gaplessPlayback: true,
//                       fit: BoxFit.cover,
//                     ),
//             ),
//           ),
//           Expanded(
//             child: Container(
//                 padding: const EdgeInsets.only(left: 10.0, top: 10.0),
//                 color: PinkTheme.nodeColors[type], //PinkTheme.headerColor,
//                 child: Down4Input(
//                   inputCallBack: nameCallBack,
//                   placeHolder: hintText,
//                   padding: const EdgeInsets.only(bottom: Palette.height / 2),
//                 ) // TextField(
//                 //   textAlignVertical: TextAlignVertical.top,
//                 //   decoration: InputDecoration(
//                 //       hintText: hintText,
//                 //       border: InputBorder.none,
//                 //       contentPadding: const EdgeInsets.only(
//                 //           bottom: (SingleActionPalette.height) / 2)),
//                 //   textDirection: TextDirection.ltr,
//                 //   onChanged: nameCallBack,
//                 // ),
//                 ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class LocalPalette extends StatelessWidget {
//   static const double height = 60.0;
//   final LocalNode node;
//   final void Function(String)? imPress,
//       bodyPress,
//       imLongPress,
//       bodyLongPress,
//       goPress,
//       goLongPress;
//   final bool selected;

//   const LocalPalette({
//     required this.node,
//     this.imPress,
//     this.bodyPress,
//     this.imLongPress,
//     this.bodyLongPress,
//     this.goLongPress,
//     this.goPress,
//     this.selected = false,
//     Key? key,
//   }) : super(key: key);

//   LocalPalette invertedSelection() {
//     return LocalPalette(
//       node: node,
//       selected: !selected,
//       imPress: imPress,
//       imLongPress: imLongPress,
//       bodyPress: bodyPress,
//       bodyLongPress: bodyLongPress,
//       goPress: goPress,
//       goLongPress: goLongPress,
//     );
//   }

//   LocalPalette deactivated() {
//     return LocalPalette(
//       node: node,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: Palette.height,
//       margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//       decoration: BoxDecoration(
//         boxShadow: !selected
//             ? [
//                 const BoxShadow(
//                   color: Colors.black54,
//                   blurRadius: 6.0,
//                   spreadRadius: -6.0,
//                   offset: Offset(8.0, 8.0),
//                   blurStyle: BlurStyle.normal,
//                 )
//               ]
//             : null,
//         borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//         border: Border.all(
//           width: 2.0,
//           color: selected ? PinkTheme.black : Colors.transparent,
//         ),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         textDirection: TextDirection.ltr,
//         children: [
//           GestureDetector(
//             onTap: () => imPress?.call(node.id),
//             onLongPress: () => imLongPress?.call(node.id),
//             child: Container(
//               clipBehavior: Clip.hardEdge,
//               decoration: const BoxDecoration(
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(4.0),
//                   bottomLeft: Radius.circular(4.0),
//                 ),
//               ),
//               width: Palette.height - 2.0, // borderWidth x2
//               child: Image.memory(
//                 node.image.data,
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           Expanded(
//             child: GestureDetector(
//               onTap: () => bodyPress?.call(node.id),
//               onLongPress: () => bodyLongPress?.call(node.id),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: PinkTheme.nodeColors[node.type],
//                   border: Border(
//                     left: BorderSide(
//                       color: selected
//                           ? PinkTheme.black
//                           : PinkTheme.nodeColors[node.type]!,
//                       width: 1.0,
//                     ),
//                   ),
//                 ),
//                 padding: const EdgeInsets.only(left: 6.0, top: 5.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       node.name + " " + (node.lastName ?? ""),
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight:
//                             selected ? FontWeight.bold : FontWeight.normal,
//                       ),
//                     ),
//                     node.type == Nodes.user
//                         ? Text(
//                             "@" + node.id,
//                             style: TextStyle(
//                               fontSize: 10,
//                               fontWeight: selected
//                                   ? FontWeight.bold
//                                   : FontWeight.normal,
//                             ),
//                           )
//                         : const SizedBox.shrink(),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           goPress != null
//               ? GestureDetector(
//                   onTap: () => goPress!.call(node.id),
//                   onLongPress: () => goLongPress?.call(node.id),
//                   child: Container(
//                     padding: const EdgeInsets.all(2.0),
//                     decoration: BoxDecoration(
//                       color: PinkTheme.nodeColors[node.type],
//                       borderRadius: const BorderRadius.only(
//                         topRight: Radius.circular(4.0),
//                         bottomRight: Radius.circular(4.0),
//                       ),
//                     ),
//                     child: Image.asset(
//                       "lib/src/assets/rightBlackArrow.png",
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                 )
//               : Container(
//                   padding: const EdgeInsets.all(2.0),
//                   decoration: BoxDecoration(
//                     color: PinkTheme.nodeColors[node.type],
//                     borderRadius: const BorderRadius.only(
//                       topRight: Radius.circular(4.0),
//                       bottomRight: Radius.circular(4.0),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }
// }
