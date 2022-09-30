import 'data_objects.dart';
import 'package:flutter/material.dart';
import 'render_objects.dart';
import 'render_pages.dart';

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
  static const snipRibbon = Color.fromARGB(153, 255, 241, 242);
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

class Jeff extends StatefulWidget {
  final List<String> titles;
  final List<Widget> bodies;
  final List<PageConsole> consoles;
  final int index;

  const Jeff({
    required this.titles,
    required this.bodies,
    required this.consoles,
    required this.index,
    Key? key,
  }) : super(key: key);
  @override
  _JeffState createState() => _JeffState();
}

class _JeffState extends State<Jeff> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.index;
  }

  void onPageChanged(int index) {
    _index = index;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        Scaffold(
          body: Container(
            color: PinkTheme.backGroundColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: PinkTheme.qrColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 3.0,
                        spreadRadius: 3.0,
                      ),
                    ],
                  ),
                  height: 32,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.titles
                        .map((e) => Text(" " + e + " ",
                            style: TextStyle(
                              color: e == widget.titles[_index]
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: e == widget.titles[_index] ? 18 : 14,
                            )))
                        .toList(growable: false),
                  ),
                ),
                Expanded(
                  child: PageView(
                    children: widget.bodies,
                    onPageChanged: onPageChanged,
                  ),
                ),
                widget.consoles[_index],
              ],
            ),
          ),
        ),
        ...widget.consoles[_index].getExtraTopButtons(w),
        ...widget.consoles[_index].getExtraBottomButtons(w),
      ],
    );
  }
}
