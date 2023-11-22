import 'dart:async';

import 'package:down4/src/data_objects/couch.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';

import '../_dart_utils.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../data_objects/messages.dart';
import '../data_objects/nodes.dart';
import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '_page_utils.dart';

class ChatPage extends StatefulWidget with Down4PageWidget {
  @override
  final String id;

  Down4ID get nodeID => Down4ID.fromString(id.split("@")[1])!;

  final void Function(int) onPageChange;
  final void Function() back, add, money, hyper, openPreview;
  final Future<void> Function([int limit]) loadMore;
  final void Function(BranchN) openNode;
  final void Function(Iterable<Chat>) send;
  final void Function() forward;
  final Chat? reactingTo;
  final void Function(ComposedID, Chat) react;
  final ViewState viewState;

  const ChatPage({
    required this.id,
    required this.add,
    required this.money,
    required this.hyper,
    required this.loadMore,
    required this.onPageChange,
    required this.back,
    required this.send,
    required this.openNode,
    required this.forward,
    required this.react,
    required this.openPreview,
    required this.viewState,
    this.reactingTo,
    super.key,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with
        WidgetsBindingObserver,
        Pager2,
        Input2,
        Camera2,
        Medias2,
        Sender2,
        Add2,
        Compose2,
        Hyper2,
        Money2,
        Saver2,
        Forward2,
        Boost2,
        Append2 {
  ViewState get vs => widget.vs;

  ChatN get node => local<ChatN>(widget.nodeID)!;

  List<Down4ID> get orderedChats => vs.orderedChats ?? [];

  @override
  List<(String, void Function(Down4Media))> get mediasMode => [
        (
          "SEND",
          (m) {
            m.use();
            send(mediaInput: m);
          }
        ),
        (
          "REMOVE",
          (m) {
            m.updateSaveStatus(false);
            setState(() {});
          }
        ),
      ];

  @override
  void setTheState() => setState(() {});

  late ScrollController scroller0 =
      ScrollController(initialScrollOffset: vs.pages[0].scroll)
        ..addListener(() => vs.pages[0].scroll = scroller0.offset);

  late ScrollController? scroller1 = node is GroupN
      ? (ScrollController(initialScrollOffset: vs.pages[1].scroll)
        ..addListener(() => vs.pages[1].scroll = scroller1!.offset))
      : null;

  Map<Down4ID, ChatMessage> get _messages => vs.pages[0].state.cast();
  Map<ComposedID, Palette> get _group => vs.pages[1].state.cast();

  var lastOffsetUpdate = 0.0;

  String? _idOfLastMessageRead;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    scroller0.dispose();
    scroller1?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatPage old) {
    super.didUpdateWidget(old);
    if (widget.reactingTo != null) {
      forMediaMode = (
        "REACT",
        (Down4Media m) => widget.react(m.id, widget.reactingTo!),
      );

      changeConsole(basicMediaRowName);
    }
    print("UPDATED WIDGET");
  }

  void unselectSelectedMessage() {
    for (final key in _messages.keys) {
      if (_messages[key]?.selected ?? false) {
        _messages[key] = _messages[key]!.invertedSelection();
      }
    }
    setState(() {});
  }

  Future<void> loadFullCamera() async {
    // TODO
  }

  @override
  Future<void> send({Down4Media? mediaInput}) async {
    final media = mediaInput ??
        (cameraInput
          ?..cache()
          ..merge());
    final doneWrite = media?.writeFromCachedPath();

    var chts = <Chat>[];

    final fm = g.vm.forwardingObjects
        .whereType<ChatMessage>()
        .map((e) => e.message)
        .map((m) => m.forwarded(g.self.id, node.root_)
          ..cache()
          ..merge())
        .toList();

    chts.addAll(fm.reversed);

    final fnds = g.vm.forwardingObjects.palettes().asComposedIDs().toSet();
    if (media != null || input.value.isNotEmpty || fnds.isNotEmpty) {
      final c = Chat(ComposedID(),
          root: node.root_,
          txt: input.value,
          mediaID: media?.id,
          nodes: fnds,
          replies: _messages.values.selected().asIDs().toSet(),
          senderID: g.self.id,
          timestamp: makeTimestamp())
        ..cache()
        ..merge();

      chts.add(c);
    }

    if (chts.isNotEmpty) {
      g.vm.mode = Modes.def;
      g.vm.forwardingObjects.clear();
      await doneWrite;
      widget.send(chts);
      unselectSelectedMessage();
      input.clear();
      cameraInput = null;
      turnOffExtras();
      setTheState();
    }
  }

  @override
  late List<Extra> extras = [
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
  ];

  Extra get mediaButtonExtra => extras[0];

  ConsoleRow get baseRow => ConsoleRow(
        inputMaxHeight: input.hasFocus ? input.height : null,
        widths: input.hasFocus ? [0.2, 0.0, 0.6, 0.2] : null,
        extension: null,
        widgets: [
          mediasButton.withExtra(
              mediaButtonExtra, [appendButton, forwardButton, saveButton]),
          cameraButton,
          input.consoleInput,
          sendButton,
        ],
      );

  @override
  Console get console {
    return Console(
      rows: [
        {
          "base": baseRow,
          basicMediaRowName: basicMediasRow,
          basicCameraRowName: basicCameraRow,
          cameraConfirmationRowName: cameraConfirmationRow,
          basicSavingRowName: basicSavingRow,
        },
        {
          "base2": ConsoleRow(
            widths: null,
            inputMaxHeight: null,
            extension: null,
            widgets: [forwardButton, hyperButton, moneyButton, addButton],
          )
        }
      ],
      currentConsolesName: currentConsolesName,
      currentPageIndex: widget.viewState.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = node is GroupN
        ? [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: node.displayName,
                console: console,
                asMap: _messages,
                orderedKeys: orderedChats,
                onRefresh: widget.loadMore),
            Down4Page(
              scrollController: scroller1,
              title: "Members",
              console: console,
              list: _group.values.toList(),
            ),
          ]
        : [
            Down4Page(
                scrollController: scroller0,
                isChatPage: true,
                title: node.displayName,
                console: console,
                asMap: _messages,
                orderedKeys: orderedChats,
                onRefresh: widget.loadMore)
          ];

    return Andrew(
      staticRow: g.vm.mode == Modes.append ? basicAppendRow : null,
      previewFunction: widget.openPreview,
      backFunction: widget.back,
      pages: pages,
      initialPageIndex: widget.viewState.currentIndex,
      onPageChange: (ix) {
        widget.onPageChange(ix);
        onPageSwitch();
      },
    );
  }

  @override
  List<String> currentConsolesName = ["base", "base2"];

  @override
  int get currentPageIndex => widget.viewState.currentIndex;

  @override
  String get backFromCameraConsoleName => "base";

  @override
  String get backFromMediasConsoleName => "base";

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
    ),
  ];

  @override
  void forward() {
    final sel = vs.allPageSelection();
    g.vm.forwardingObjects.addAll(sel);
    // g.vm.mode = Modes.forward;
    widget.forward();
  }

  @override
  void saveToMedias() {
    final selectedMedias = _messages.values
        .selected()
        .messages()
        .where((chat) => chat.hasMedia)
        .map((chat) => chat.mediaInfo!.media);
    for (final media in selectedMedias) {
      media.updateSaveStatus(true);
      if (!g.savedMediasIDs[media.type]!.contains(media.id)) {
        g.savedMediasIDs[media.type]!.add(media.id);
      }
    }

    unselectSelectedMessage();
    changeConsole("base");
  }

  @override
  void saveToMessages() {
    final msgs = _messages.values.selected().messages().toList().reversed;
    for (var chat in msgs) {
      chat.message.copiedFor(g.self.root(g.self.id)) // crazy
        ..cache()
        ..merge();
    }
    unselectSelectedMessage();
    changeConsole("base");
  }

  @override
  void add() => widget.add();

  @override
  void hyper() => widget.hyper();

  @override
  void money() => widget.money();

  @override
  void boost() {
    print("TODO: BOOST IMPLEMENTATION");
  }
}
