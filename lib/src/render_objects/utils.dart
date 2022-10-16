import 'dart:io' as io;

import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

import 'palette.dart';

import '../data_objects.dart';

class Down4Input extends StatefulWidget {
  final TextInputType type;
  final String placeHolder;
  final String? prefix, postfix;
  final TextAlign textAlign;
  final TextAlignVertical textAlignVertical;
  final EdgeInsets padding;
  final TextEditingController tec;
  final void Function(String)? inputCallBack;
  const Down4Input({
    this.type = TextInputType.text,
    required this.placeHolder,
    required this.tec,
    this.inputCallBack,
    this.padding = EdgeInsets.zero,
    this.textAlign = TextAlign.left,
    this.textAlignVertical = TextAlignVertical.top,
    this.prefix,
    this.postfix,
    Key? key,
  }) : super(key: key);

  @override
  _Down4InputState createState() => _Down4InputState();
}

class _Down4InputState extends State<Down4Input> {
  final Key k = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.tec,
      key: k,
      keyboardType: widget.type,
      textAlignVertical: widget.textAlignVertical,
      textAlign: widget.textAlign,
      decoration: InputDecoration(
        contentPadding: widget.padding,
        hintText: widget.placeHolder,
        border: InputBorder.none,
        prefixIcon: widget.prefix != null ? Text(widget.prefix!) : null,
        prefixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
        suffixIcon: widget.postfix != null ? Text(widget.postfix!) : null,
        suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
      ),
      textDirection: TextDirection.ltr,
      onChanged: widget.inputCallBack,
    );
  }
}

class Down4VideoPlayer extends StatefulWidget {
  final io.File vid;
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

extension PaletteExtensions on List<Palette> {
  List<Node> asNodes() => map((e) => e.node).toList(growable: false);
  List<Palette> selected() => where((p) => p.selected).toList(growable: false);
  List<Identifier> asIds() => map((e) => e.node.id).toList(growable: false);
  List<Palette> chatables() => where((p) => const [
    Nodes.group,
    Nodes.friend,
    Nodes.nonFriend,
    Nodes.user,
    Nodes.hyperchat
  ].contains(p.node.type)).toList(growable: false);
}

class NoGlow extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class TouchableOpacity extends StatefulWidget {
  final Widget child;
  final void Function() onPress;
  final void Function()? onLongPress;
  final void Function()? onLongPressUp;
  final bool shouldBeDownButIsnt;
  final Duration duration = const Duration(milliseconds: 30);
  final double opacity = 0.5;

  const TouchableOpacity(
      {required this.child,
        required this.onPress,
        this.shouldBeDownButIsnt = false,
        this.onLongPress,
        this.onLongPressUp,
        Key? key})
      : super(key: key);

  @override
  _TouchableOpacityState createState() => _TouchableOpacityState();
}

class _TouchableOpacityState extends State<TouchableOpacity> {
  bool isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => isDown = true),
      onTapUp: (_) => setState(() => isDown = false),
      onTapCancel: () => setState(() => isDown = false),
      onTap: widget.onPress,
      onLongPress: widget.onLongPress,
      onLongPressUp: widget.onLongPressUp,
      child: Opacity(
        child: widget.child,
        opacity: isDown || widget.shouldBeDownButIsnt ? widget.opacity : 1,
      ),
    );
  }
}

class MediaSizeClipper extends CustomClipper<Rect> {
  final Size mediaSize;
  const MediaSizeClipper(this.mediaSize);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, mediaSize.width, mediaSize.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}