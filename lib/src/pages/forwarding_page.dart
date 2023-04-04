import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/home.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/web_requests.dart';
import 'package:flutter/material.dart';

import '../data_objects.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../globals.dart';

class ForwardingPage extends StatefulWidget implements Down4PageWidget {
  @override
  ID get id => "forward";
  final List<Down4Object> fObjects;
  final void Function() back;
  final void Function(List<Down4Object>, Palette2<Chatable>) openChat;
  final void Function(List<Down4Object>, Transition) hyper;
  final Future<void> Function(Payload, Iterable<Palette2<Chatable>>) forward;

  const ForwardingPage({
    // required this.homePalettes,
    required this.openChat,
    required this.hyper,
    required this.fObjects,
    required this.forward,
    required this.back,
    // required this.hiddenState,
    Key? key,
  }) : super(key: key);

  @override
  State<ForwardingPage> createState() => _ForwadingPageState();
}

class _ForwadingPageState extends State<ForwardingPage> {
  final GlobalKey _forwardKey = GlobalKey();
  late Console _console;
  final _tec = TextEditingController();
  late final fo = widget.fObjects;

  late ScrollController scroller =
      ScrollController(initialScrollOffset: g.vm.cv.cp.scroll)
        ..addListener(() {
          print("listening to scroll = ${scroller.offset}");
          g.vm.cv.cp.scroll = scroller.offset;
        });

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  Map<ID, Palette2<Chatable>> get _forwardState => g.vm.cv.cp.objects.cast();

  Iterable<Palette2<Chatable>> get _fList => _forwardState.values;

  Iterable<Palette2<Chatable>> get selection => _fList.where((p) => p.selected);

  Map<ID, Palette2> get hiddenState => g.vm.home.pages[1].objects.cast();

  ConsoleInput get input => ConsoleInput(tec: _tec, placeHolder: ":)");

  Transition hyperTransition() {
    return selectionTransition(
        originalList: _fList.toList(),
        state: _forwardState,
        hiddenState: hiddenState,
        scrollOffset: g.vm.cv.cp.scroll);
  }

  ConsoleMedias2 cm(bool showImages) {
    return ConsoleMedias2(
      showImages: showImages,
      onSelect: (media) => widget.forward(
          Payload(
              isSnip: false,
              forwards: widget.fObjects,
              text: _tec.value.text,
              media: media,
              replies: null),
          selection),
    );
  }

  void reload() => setState(() {});

  @override
  void initState() {
    super.initState();
    loadForwardingConsole();
    // loadPalettes();
  }

  void loadForwardingMediasConsole({bool images = true}) {
    _console = Console(
      bottomInputs: [input],
      consoleMedias2: ConsoleMedias2(
        showImages: images,
        onSelect: (media) => widget.forward(
          Payload(
              isSnip: false,
              forwards: fo,
              text: _tec.value.text,
              media: media,
              replies: null),
          selection,
        ),
      ),
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: () => loadForwardingConsole()),
        ConsoleButton(
          name: images ? "Images" : "Videos",
          onPress: () => loadForwardingMediasConsole(images: !images),
        )
      ],
    );
    setState(() {});
  }

  void loadForwardingConsole({bool extra = false}) {
    _console = Console(
      bottomInputs: [input],
      forwardingObjects: fo,
      bottomButtons: [
        ConsoleButton(name: "Back", onPress: widget.back),
        ConsoleButton(
          key: _forwardKey,
          name: "Forward",
          onLongPress: () => loadForwardingConsole(extra: !extra),
          onPress: () => extra
              ? loadForwardingConsole(extra: !extra)
              : widget.forward(
                  Payload(
                      isSnip: false,
                      replies: null,
                      forwards: fo,
                      text: _tec.value.text,
                      media: null),
                  selection),
          isSpecial: true,
          showExtra: extra,
          extraButtons: [
            ConsoleButton(
                name: "Hyper",
                onPress: () => widget.hyper(fo, hyperTransition())),
            ConsoleButton(
                name: "Medias", onPress: () => loadForwardingMediasConsole()),
            ConsoleButton(name: "Camera", onPress: () => print("TODO")),
          ],
        ),
      ],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ps = _fList.toList(growable: false);
    return Andrew(pages: [
      Down4Page(
        staticList: true,
        trueLen: ps.length,
        title: "Forward",
        console: _console,
        list: ps,
        scrollController: scroller,
      ),
    ]);
  }
}
