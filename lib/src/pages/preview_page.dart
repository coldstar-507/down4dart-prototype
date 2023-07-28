import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:flutter/material.dart';

import '../data_objects/_data_utils.dart';

import '../render_objects/console.dart';
import '../render_objects/navigator.dart';
import '../globals.dart';

class PreviewPage extends StatefulWidget implements Down4PageWidget {
  @override
  String get id => "preview";
  ViewState get viewState => g.vm.currentView;

  final void Function() back;
  Set<Down4Object> get fObjects => g.vm.forwardingObjects;

  const PreviewPage({required this.back, Key? key}) : super(key: key);

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  Map<Down4ID, Down4SelectionWidget> get previewObjects =>
    g.vm.currentView.pages[0].state.cast();

  void setTheState() => setState(() {});

  Console3 get console => Console3(
        currentPageIndex: 0,
        currentConsolesName: const ["base"],
        rows: [
          {
            "base": ConsoleRow(
                inputMaxHeight: null,
                widths: null,
                extension: null,
                widgets: [
                  ConsoleButton(
                      name: "CLEAR",
                      onPress: () {
                        g.vm.forwardingObjects.clear();
                        previewObjects.clear();
                        setTheState();
                      }),
                  ConsoleButton(
                      name: "REMOVE",
                      onPress: () {
                        final sel = List.from(previewObjects.values.selected());
                        for (final s in sel) {
                          previewObjects.remove(s.id);
                          g.vm.forwardingObjects.remove(s);
                        }
                        setTheState();
                      }),
                ]),
          }
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Andrew(
      backFunction: () {
        if (g.vm.forwardingObjects.isEmpty) {
          g.vm.mode = Modes.def;
        }
        widget.back();
      },
      pages: [
        Down4Page(
          title: "Preview",
          list: previewObjects.values.toList(),
          console: console,
        ),
      ],
    );
  }
}
