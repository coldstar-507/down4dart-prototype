import 'dart:async';

import 'package:down4/src/data_objects/nodes.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/render_objects/palette.dart';
import 'package:flutter/material.dart';

import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '_page_utils.dart';

import '../globals.dart';

import '../render_objects/console.dart';
import '../render_objects/navigator.dart';

class HyperchatPage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "hyper";
  final void Function(String text) ping;
  final void Function() back, openPreview;
  final List<Palette> initialPalettes;
  final double initialOffset;
  final void Function(
    Down4Media? m,
    String? textInput,
    Set<ComposedID> members,
  ) makeHyperchat;

  ViewState get viewState => g.vm.currentView;

  const HyperchatPage({
    required this.initialPalettes,
    required this.initialOffset,
    required this.openPreview,
    required this.makeHyperchat,
    required this.back,
    required this.ping,
    Key? key,
  }) : super(key: key);

  @override
  State<HyperchatPage> createState() => _HyperchatPageState();
}

class _HyperchatPageState extends State<HyperchatPage>
    with
        TickerProviderStateMixin,
        Pager2,
        Transition2,
        WidgetsBindingObserver,
        Camera2,
        Medias2,
        Input2,
        Sender2,
        Compose2 {
  @override
  late var mainScroll =
      ScrollController(initialScrollOffset: widget.initialOffset);

  late Set<PersonN> trueTargets;

  @override
  List<String> currentConsolesName = ["base"];

  @override
  int get currentPageIndex => 0;

  @override
  late List<MyTextEditor> inputs = [
    MyTextEditor(
      onInput: onInput,
      onFocusChange: onFocusChange,
      config: Input2.multiLine,
    ),
  ];

  List<Down4Widget> get renderPalettes =>
      transitedPalettes ?? widget.initialPalettes;

  Extra get mediasExtra => extras[0];

  @override
  late List<Extra> extras = [Extra(setTheState: setTheState)];

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

  Set<Down4Object> get fo => g.vm.forwardingObjects;

  @override
  void setTheState() => setState(() {});

  @override
  TickerProvider get ticker => this;

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
  Console3 get console => Console3(
          rows: [
            {
              "base": basicComposeRow,
              basicCameraRowName: basicCameraRow,
              cameraConfirmationRowName: cameraConfirmationRow,
              basicMediaRowName: basicMediasRow,
            }
          ],
          currentConsolesName: currentConsolesName,
          currentPageIndex: currentPageIndex);


  @override
  Future<void> send({Down4Media? mediaInput}) async {
    final media = mediaInput ??
        (cameraInput
          ?..cache()
          ..merge()
          ..writeFromCachedPath());
    
    final text = input.value;
    if (text.isEmpty && media == null && fo.isEmpty) return;

    final ids = trueTargets.map((n) => n.id);
    final members = Set<ComposedID>.from(ids)..add(g.self.id);

    widget.makeHyperchat(media, text, members);
  }

  void loadFullCamera() {
    // TODO
  }

  @override
  Widget build(BuildContext context) {
    return Andrew(
      previewFunction: widget.openPreview,
      backFunction: widget.back,
      pages: [
        Down4Page(
            scrollController: mainScroll,
            staticList: true,
            title: "Hyperchat",
            console: console,
            list: renderPalettes),
      ],
    );
  }
}
