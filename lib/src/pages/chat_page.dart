import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
// import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../_dart_utils.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/firebase.dart';
import '../data_objects/medias.dart';
import '../data_objects/messages.dart';
import '../data_objects/nodes.dart';
import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/chat_message.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';

import '_page_utils.dart';

class ChatPage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "chat-${viewState.node!.id}";

  final ViewState viewState;
  final List<Down4Object>? fo;
  final void Function(int) onPageChange;
  final void Function() back, add, money, hyper;
  final Future<void> Function([int limit]) loadMore;
  final void Function(BranchNode) openNode;
  final void Function(Chat) send;
  final void Function(List<Down4Object> fo) forward;
  final Chat? reactingTo;
  final Future<void> Function(ComposedID, Chat) react;

  const ChatPage({
    required this.add,
    required this.money,
    required this.hyper,
    required this.viewState,
    required this.loadMore,
    required this.onPageChange,
    required this.back,
    required this.send,
    required this.openNode,
    required this.forward,
    required this.react,
    this.reactingTo,
    this.fo,
    Key? key,
  }) : super(key: key);

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
        Hyper2,
        Money2,
        ForwardSender2,
        Saver2,
        Forwarder2 {
  ChatNode get node => widget.viewState.node as ChatNode;
  List<Down4ID> get orderedChats => widget.viewState.chat?.first ?? [];

  @override
  List<(String, void Function(FireMedia))> get mediasMode => [
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
            setState(() {});
            // loadBaseConsole();
            // loadMediasConsole(!m.isVideo, true);
          }
        ),
      ];
  @override
  List<Down4Object>? get fo => widget.fo;
  @override
  void setTheState() => setState(() {});

  late ScrollController scroller0 =
      ScrollController(initialScrollOffset: widget.viewState.pages[0].scroll)
        ..addListener(() {
          widget.viewState.pages[0].scroll = scroller0.offset;
        });

  late ScrollController? scroller1 = node is GroupNode
      ? (ScrollController(initialScrollOffset: widget.viewState.pages[1].scroll)
        ..addListener(() {
          widget.viewState.pages[1].scroll = scroller1!.offset;
        }))
      : null;

  Map<ComposedID, ChatMessage> get _messages =>
      widget.viewState.pages[0].objects.cast();
  Map<ComposedID, Palette2> get _group =>
      widget.viewState.pages[1].objects.cast();

  var lastOffsetUpdate = 0.0;

  String? _idOfLastMessageRead;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // console = theConsole;
    // if (fo != null) {
    //   loadForwardingConsole();
    // } else {
    //   loadBaseConsole();
    // }
  }

  @override
  void dispose() {
    scroller0.dispose();
    scroller1?.dispose();
    // aCtrl?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatPage old) {
    super.didUpdateWidget(old);
    if (widget.reactingTo != null) {
      forMediaMode = (
        "REACT",
        (FireMedia m) => widget.react(m.id, widget.reactingTo!),
      );

      changeConsole(basicMediaRowName);
    }

    print("UPDATED WIDGET");
    // if (forwardingConsoles.contains(console.name) && fo == null) {
    //   loadBaseConsole();
    // }
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
  Future<void> send({FireMedia? mediaInput}) async {
    final media = (cameraInput ?? mediaInput)
      ?..cache()
      ..merge();

    if (input.value == "" && media != null && fo != null) return;

    final p = Chat(Down4ID(),
        text: input.value,
        mediaID: media?.id,
        nodes: fo?.whereType<Palette2>().asComposedIDs().toSet(),
        replies: _messages.values.selected().asComposedIDs().toSet(),
        messages: fo?.whereType<ChatMessage>().asComposedIDs().toSet(),
        senderID: g.self.id,
        root: node.id,
        timestamp: makeTimestamp())
      ..cache()
      ..merge();

    widget.send(p);

    unselectSelectedMessage();
    input.clear();
    cameraInput = null;
    turnOffExtras();
    setTheState();
  }

  @override
  late List<Extra> extras = [
    Extra(setTheState: setTheState),
    Extra(setTheState: setTheState),
  ];

  Extra get mediaButtonExtra => extras[0];

  List<double> get baseConsoleWidth {
    if (forwarding) {
      if (hasFocus) {
        return [0.0, 0.2, 0.0, 0.6, 0.2];
      } else {
        return [0.25, 0.25, 0.0, 0.25, 0.25];
      }
    } else {
      if (hasFocus) {
        return [0.0, 0.2, 0.0, 0.6, 0.2];
      } else {
        return [0.0, 0.25, 0.25, 0.25, 0.25];
      }
    }
  }

  bool get forwarding => (fo ?? []).isNotEmpty;

  @override
  Console3 get console {
    return Console3(
      rows: [
        {
          "base": ConsoleRow(
            widgets: [
              forwardingObjectsWidget,
              mediasButton.withExtra(mediaButtonExtra, [
                forwarding ? cameraButton : forwardButton,
                saveButton,
              ]),
              cameraButton,
              inputs.single.consoleInput,
              sendButton,
            ],
            extension: null,
            widths: baseConsoleWidth, // goes to default even size
            inputMaxHeight: hasFocus ? input.ctrl.height : Console.buttonHeight,
          ),
          // "forward": ConsoleRow(
          //   inputMaxHeight: inputHeight,
          //   extension: null,
          //   widgets: [
          //     forwardingObjectsWidget,
          //     mediasButton,
          //     input,
          //     forwardButton.withExtra(
          //       buttons: [cameraButton],
          //       showExtra: showForwardButtonExtra,
          //       onLongPress: () {
          //         setState(() {
          //           showForwardButtonExtra = !showForwardButtonExtra;
          //         });
          //       },
          //     ),
          //   ],
          //   widths: focusNode.hasFocus ? [0.0, 0.2, 0.6, 0.2] : null,
          // ),
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
    final pages = node is GroupNode
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
    if (currentPageIndex == 0) {
      widget.forward(_messages.values.selected().toList(growable: false));
    } else {
      widget.forward(_group.values.selected().toList(growable: false));
    }
  }

  @override
  void saveToMedias() {
    final selectedMedias = _messages.values
        .selected()
        .where((chat) => chat.hasMedia)
        .map((chat) => chat.mediaInfo!.media);
    for (final media in selectedMedias) {
      media.updateSaveStatus(true);
    }
    unselectSelectedMessage();
    changeConsole("base");
  }

  @override
  void saveToMessages() {
    for (var chat in _messages.values.selected()) {
      chat.message.copiedFor(root: g.self.id)
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
}
