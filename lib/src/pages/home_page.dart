import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/data_objects/messages.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/render_objects/_render_utils.dart';

import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../data_objects/nodes.dart';
import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '../globals.dart';

import '_page_utils.dart';

class HomePage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "home";
  final String? promptMessage;
  ViewState get homeState => g.vm.currentView;

  final void Function(String text) ping;
  final void Function(ChatN, List<Locals>) openChat; // TODO what is this?
  final void Function(Iterable<Chat>) send;
  final void Function() forward;
  final void Function() hyperchat, themes, openPreview;
  final void Function() group, money, search, delete, snip;
  const HomePage({
    required this.themes,
    required this.hyperchat,
    required this.group,
    required this.money,
    required this.snip,
    required this.ping,
    required this.openPreview,
    required this.search,
    required this.delete,
    required this.send,
    required this.openChat,
    required this.forward,
    this.promptMessage,
    Key? key,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with
        WidgetsBindingObserver,
        Pager2,
        Sender2,
        Input2,
        Medias2,
        Camera2,
        Forward2,
        Compose2,
        Hyper2,
        Money2,
        Boost2,
        Append2 {
  late String placeHolder = widget.promptMessage ?? ":)";

  late ScrollController scroller =
      ScrollController(initialScrollOffset: widget.homeState.currentPage.scroll)
        ..addListener(() {
          widget.homeState.currentPage.scroll = scroller.offset;
        });

  @override
  void setTheState() => setState(() {});

  Map<ComposedID, Palette> get palettes =>
      widget.homeState.currentPage.state.cast();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      previewFunction: widget.openPreview,
      staticRow: g.vm.mode == Modes.append ? basicAppendRow : null,
      addFriends: widget.search,
      themes: widget.themes,
      pages: [
        Down4Page(
            scrollController: scroller,
            staticList: true,
            title: "Down4",
            trueLen: palettes.length,
            list: palettes.values.toList().formatted(),
            console: console)
      ],
    );
  }

  ConsoleButton get groupButton =>
      ConsoleButton(name: "GROUP", onPress: widget.group)
          .withExtra(extraGroup, [
        ConsoleButton(name: "DELETE", onPress: widget.delete),
        ConsoleButton(name: "FORWARD", onPress: widget.forward),
        ConsoleButton(name: "COMPOSE", onPress: () => changeConsole("compose")),
        appendButton,
      ]);

  ConsoleButton get closeButton =>
      ConsoleButton(name: "CLOSE", onPress: () => changeConsole("home"))
          .withExtra(extraClose, [cameraButton]);

  ConsoleButton get snipButton =>
      ConsoleButton(name: "SNIP", onPress: widget.snip);

  @override
  Console3 get console => Console3(
          rows: [
            {
              "home": ConsoleRow(
                widgets: [groupButton, hyperButton, moneyButton, snipButton],
                extension: null,
                widths: null,
                inputMaxHeight: null,
              ),
              "compose": ConsoleRow(
                widgets: [
                  closeButton,
                  mediasButton,
                  input.consoleInput,
                  sendButton
                ],
                extension: null,
                widths: hasFocus ? [0.0, 0.2, 0.6, 0.2] : null,
                inputMaxHeight: hasFocus ? input.height : Console.buttonHeight,
              ),
              basicMediaRowName: basicMediasRow,
              basicCameraRowName: basicCameraRow,
              cameraConfirmationRowName: cameraConfirmationRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  List<(String, void Function(Down4Media))> get mediasMode => [
        (
          "SEND",
          (m) async {
            await m.use();
            send(mediaInput: m);
          }
        ),
        (
          "REMOVE",
          (m) {
            m.updateSaveStatus(false);
            setTheState();
          }
        ),
      ];

  @override
  Future<void> send({Down4Media? mediaInput}) async {
    final fo = g.vm.forwardingObjects;
    final media = mediaInput ?? cameraInput
      ?..cache()
      ..merge();
    if (media == null && input.value.isEmpty && fo.isEmpty) return;
    final messages = palettes.values
        .selected()
        .asNodes<ChatN>()
        .asComposedIDs()
        .map((root) => Chat(Down4ID(),
            senderID: g.self.id,
            root: root,
            nodes: fo.palettes().asComposedIDs().toSet(),
            messages: fo.chatMsgs().asIDs().toSet(),
            text: input.value,
            timestamp: makeTimestamp(),
            mediaID: media?.id)
          ..cache()
          ..merge());

    widget.send(messages);

    g.vm.forwardingObjects.clear();
    input.clear();
  }

  @override
  String get backFromCameraConsoleName => "compose";

  @override
  String get backFromMediasConsoleName => "compose";

  @override
  List<String> currentConsolesName = ["home"];

  @override
  int get currentPageIndex => 0;

  @override
  void hyper() => widget.hyperchat();

  @override
  void money() => widget.money();

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
    ),
  ];

  Extra get extraGroup => extras[0];
  Extra get extraClose => extras[1];

  @override
  late List<Extra> extras = [
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
  ];

  @override
  void forward() {
    final sel = g.vm.currentView.allPageSelection();
    g.vm.forwardingObjects.addAll(sel);
    g.vm.mode = Modes.forward;
    widget.forward();
  }
  
  @override
  void boost() {
    print("TODO, IMPLEMENT BOOST FUNC");
  }

}
