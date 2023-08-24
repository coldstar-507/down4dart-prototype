import 'dart:async';

import 'package:down4/src/data_objects/messages.dart';
import 'package:flutter/material.dart';

import '../_dart_utils.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../data_objects/nodes.dart';
import '_page_utils.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/palette.dart';
import '../render_objects/navigator.dart';
import '../render_objects/palette_maker.dart';
import '../render_objects/_render_utils.dart';

class GroupPage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "group";
  final List<Palette> initialPalettes;
  final void Function() back;
  final void Function(Group group, Down4Image m, Chat c) makeGroup;
  final double initialOffset;

  ViewState get viewState => g.vm.currentView;

  const GroupPage({
    required this.back,
    required this.makeGroup,
    required this.initialPalettes,
    required this.initialOffset,
    Key? key,
  }) : super(key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        Pager2,
        Transition2,
        Input2,
        Medias2,
        Camera2,
        Sender2,
        Compose2 {
  // TODO
  bool _private = true;

  late List<Down4Widget> renderPalettes =
      transitedPalettes ?? widget.initialPalettes;

  late Set<PersonN> trueTargets;

  Down4Image? _groupImage;
  String _groupName = "";

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
            setState(() {});
          }
        ),
      ];

  @override
  TickerProvider get ticker => this;

  @override
  Console3 get console => Console3(
          rows: [
            {
              basicComposeRowName: basicComposeRow,
              basicMediaRowName: basicMediasRow,
              basicCameraRowName: basicCameraRow,
              cameraConfirmationRowName: cameraConfirmationRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);

  @override
  late List<String> currentConsolesName = [basicComposeRowName];

  @override
  int get currentPageIndex => 0;

  @override
  String get backFromCameraConsoleName => basicComposeRowName;

  @override
  String get backFromMediasConsoleName => basicComposeRowName;

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
    ),
    MyTextEditor(
        onInput: (s, h) {
          _groupName = s;
          onInput(s, h);
        },
        specificStyle: g.theme.paletteNameStyle(selected: false),
        placeholderStyle: g.theme.palettePlaceholderTextStyle,
        onFocusChange: onFocusChange,
        maxWidth: g.sizes.w * (1 / golden),
        isConsoleInput: false,
        config: Input2.singleLine,
        placeHolder: "Group Name..."),
  ];

  MyTextEditor get groupInput => inputs[1];

  @override
  late List<Extra> extras = [];

  @override
  late ScrollController mainScroll =
      ScrollController(initialScrollOffset: widget.initialOffset);

  @override
  void setTheState() => setState(() {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    animatedTransition(widget.initialPalettes, widget.initialOffset);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void animatedTransition(List<Palette>? ogs, double? ogOffset) {
    final (transited, nHidden, tt) = transitionPalettes(ogs!);
    trueTargets = tt;
    Future(() {
      final offset = (nHidden + 1) * Palette.fullHeight;
      renderPalettes = [...transited, groupMaker()];
      mainScroll.jumpTo(ogOffset! + offset);
      mainScroll.animateTo(0, duration: transDuration, curve: Curves.easeInOut);
      foldAnim.forward();
      fadeAnim.forward();
      setTheState();
    });
  }

  void forGroupNode(Down4Image m) {
    _groupImage = m;
    reloadItems();
  }

  PaletteMaker groupMaker() {
    return PaletteMaker(
        fold: false,
        colorCode: NodesColor.group,
        tec: groupInput,
        id: Down4ID(unique: "groupMaker"),
        name: _groupName,
        image: _groupImage,
        type: Nodes.group,
        imagePress: () {
          forMediaMode = ("PUT", forGroupNode);
          nextType(specificType: MediaType.images);
          changeConsole(basicMediaRowName);
        });
  }

  @override
  Future<void> send({Down4Media? mediaInput}) async {
    final media = mediaInput ?? (cameraInput
      ?..cache()
      ..merge()
      ..writeFromCachedPath());
    
    final text = input.value;
    if (_groupImage == null || _groupName.isEmpty) return;
    if (text.isEmpty && media == null) return;

    final groupID = ComposedID();
    final members = Set<ComposedID>.from(trueTargets.cpIDs())..add(g.self.id);
    final group = Group(groupID,
        activity: makeTimestamp(),
        isConnected: true,
        isPrivate: _private,
        name: _groupName,
        mediaID: _groupImage!.id,
        group: members,
        ownerID: g.self.id);

    final chat = Chat(ComposedID(),
        root: group.root_,
        text: text,
        mediaID: media?.id,
        senderID: g.self.id,
        timestamp: makeTimestamp())
      ..cache()
      ..merge();

    widget.makeGroup(group, _groupImage!, chat);
  }

  void reloadItems() {
    renderPalettes = [
      ...renderPalettes.sublist(0, renderPalettes.length - 1),
      groupMaker(),
    ];
    setTheState();
  }

  void loadFullCamera() {
    // TODO
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      backFunction: widget.back,
      pages: [
        Down4Page(
          scrollController: mainScroll,
          staticList: true,
          title: "Group",
          list: renderPalettes,
          console: console,
        ),
      ],
    );
  }
}
