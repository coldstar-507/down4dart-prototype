import 'package:flutter/material.dart';

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
  final Duration duration = const Duration(milliseconds: 30);
  final double opacity = 0.5;

  TouchableOpacity(
      {required this.child, required this.onPress, this.onLongPress});

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
      child: AnimatedOpacity(
        child: widget.child,
        duration: widget.duration,
        opacity: isDown ? widget.opacity : 1,
      ),
    );
  }
}
