import 'dart:math';

import 'package:flutter/material.dart';
import 'package:down4/src/render_objects/_down4_flutter_utils.dart';

import '../data_objects.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '../globals.dart';

class HomePage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "HomePage";
  final ScrollController scrollController;
  final String? promptMessage;
  final List<Palette2> palettes;
  final void Function(String text) ping;
  final void Function(ChatableNode, List<Down4Object>) openNode;
  final void Function(Payload, List<ChatableNode>) send;
  final void Function(List<Down4Object>?) hyperchat;
  final void Function() group, money, search, delete, snip;
  const HomePage({
    required this.scrollController,
    required this.palettes,
    required this.hyperchat,
    required this.group,
    required this.money,
    required this.snip,
    required this.ping,
    required this.search,
    required this.delete,
    required this.send,
    required this.openNode,
    this.promptMessage,
    Key? key,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GlobalKey groupButtonKey = GlobalKey();
  GlobalKey forwardButtonKey = GlobalKey();
  late String placeHolder = widget.promptMessage ?? ":)";
  bool extra = false;
  bool extra2 = false;
  bool forwading = false;

  Map<ID, Palette2> _f = {};
  void ref() => setState(() {});

  Future<List<ButtonsInfo2>> bGen(
    ChatableNode n, {
    required List<Down4Object> f,
  }) async {
    return [
      ButtonsInfo2(
          asset: g.fifty,
          pressFunc: () => widget.openNode(n, f),
          rightMost: true)
    ];
  }

  ConsoleInput get input => ConsoleInput(tec: _tec, placeHolder: placeHolder);

  @override
  void initState() {
    super.initState();
    if (widget.promptMessage != null) {
      Future.delayed(const Duration(seconds: 2), () {
        placeHolder = ":)";
        loadBaseConsole();
      });
    }
    loadBaseConsole();
  }

  late Console _homeConsole;

  var _tec = TextEditingController();

  void ping() {
    if (_tec.value.text.isEmpty) return;
    widget.ping(_tec.value.text);
    _tec.clear();
  }

  void forward(List<Down4Object> fObjects, MessageMedia? media) {
    final sel = widget.palettes.selected().asNodes<ChatableNode>().toList();
    if (sel.isNotEmpty) {
      final p = Payload(r: null, f: fObjects, t: _tec.value.text, m: media);
      widget.send(p, sel);
    }
  }

  void loadBaseConsole() {
    _homeConsole = Console(
      bottomInputs: [input],
      topButtons: [
        ConsoleButton(name: "Hyperchat", onPress: () => widget.hyperchat(null)),
        ConsoleButton(name: "Money", onPress: widget.money),
      ],
      bottomButtons: [
        ConsoleButton(
            key: groupButtonKey,
            showExtra: extra,
            name: "Group",
            onPress: () {
              if (extra) {
                extra = false;
                loadBaseConsole();
              } else {
                widget.group();
              }
            },
            isSpecial: true,
            onLongPress: () {
              extra = !extra;
              loadBaseConsole();
            },
            extraButtons: [
              ConsoleButton(name: "Delete", onPress: widget.delete),
              ConsoleButton(
                name: "Forward",
                onPress: () async {
                  final f = widget.palettes.selected().toList();
                  for (final n in widget.palettes.asNodes<ChatableNode>()) {
                    await writePalette2(n, _f, (n) => bGen(n, f: f), ref);
                  }
                  forwading = true;
                  loadForwardingConsole(fObjects: f);
                },
              ),
            ]),
        ConsoleButton(name: "Search", onPress: widget.search),
        ConsoleButton(
          name: "Ping",
          onPress: ping,
          onLongPress: widget.snip,
          isSpecial: true,
        ),
      ],
    );
    setState(() {});
  }

  void loadForwardingMediasConsole({
    bool images = true,
    required List<Down4Object> fObjects,
  }) {
    _homeConsole = Console(
      bottomInputs: [input],
      consoleMedias2: ConsoleMedias2(
          showImages: images,
          onSelect: (media) => widget.send(
              Payload(f: fObjects, t: _tec.value.text, m: media, r: null),
              widget.palettes.selected().asNodes<ChatableNode>().toList())),
      forwardingObjects: fObjects,
      bottomButtons: [
        ConsoleButton(
          name: "Back",
          onPress: () {
            extra2 = false;
            loadForwardingConsole(fObjects: fObjects);
          },
        ),
        ConsoleButton(
          name: images ? "Images" : "Videos",
          onPress: () => loadForwardingMediasConsole(
            images: !images,
            fObjects: fObjects,
          ),
        )
      ],
    );
    setState(() {});
  }

  void loadForwardingConsole({required List<Down4Object> fObjects}) {
    _homeConsole = Console(
      bottomInputs: [input],
      forwardingObjects: fObjects,
      bottomButtons: [
        ConsoleButton(
            name: "Back",
            onPress: () {
              extra = false;
              forwading = false;
              loadBaseConsole();
            }),
        ConsoleButton(
          key: forwardButtonKey,
          name: "Forward",
          onLongPress: () {
            extra2 = !extra2;
            loadForwardingConsole(fObjects: fObjects);
          },
          onPress: () {
            if (extra2) {
              extra2 = false;
              loadForwardingConsole(fObjects: fObjects);
            } else {
              final sel =
                  widget.palettes.selected().asNodes<ChatableNode>().toList();
              if (sel.isNotEmpty) {
                widget.send(
                  Payload(r: null, f: fObjects, t: _tec.value.text, m: null),
                  sel,
                );
              }
            }
          },
          isSpecial: true,
          showExtra: extra2,
          extraButtons: [
            ConsoleButton(
                name: "Hyper", onPress: () => widget.hyperchat(fObjects)),
            ConsoleButton(
                name: "Medias",
                onPress: () => loadForwardingMediasConsole(fObjects: fObjects)),
            ConsoleButton(name: "Camera", onPress: () => print("TODO")),
          ],
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(pages: [
      Down4Page(
          scrollController: widget.scrollController,
          staticList: true,
          title: "Home",
          list: !forwading ? widget.palettes : _f.values.toList(),
          console: _homeConsole)
    ]);
  }
}
