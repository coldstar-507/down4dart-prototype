import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:down4/src/down4_utility.dart';
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
  final MessageMedia media;
  const Down4VideoPlayer({required this.media, Key? key}) : super(key: key);

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
    _videoController = widget.media.file != null
        ? VideoPlayerController.file(widget.media.file!)
        : VideoPlayerController.network(widget.media.url);
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

class Down4ImageViewer extends StatelessWidget {
  final MessageMedia media;
  final Size displaySize;
  final bool forceSquareAnyways;
  const Down4ImageViewer({
    required this.media,
    required this.displaySize,
    this.forceSquareAnyways = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final forcedSquared = media.metadata.isSquared || forceSquareAnyways;
    final isReversed = media.metadata.isReversed;
    final aspectRatio = media.metadata.elementAspectRatio;
    if (media.metadata.isSquared) {
      print("""========== ASPECT RATIO ===========
             ${media.metadata.elementAspectRatio}
      """);
    }
    return ClipRect(
      clipper: MediaSizeClipper(displaySize),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isReversed ? math.pi : 0),
        child: Transform.scale(
          scaleY: forcedSquared && aspectRatio > 1 ? aspectRatio : null,
          scaleX: forcedSquared && aspectRatio <= 1 ? 1 / aspectRatio : null,
          scale: !forcedSquared ? 1.0 : null,
          child: SizedBox.fromSize(
            size: displaySize,
            child: media.file != null
                ? Image.file(
                    media.file!,
                    cacheHeight: displaySize.height.toInt(),
                    cacheWidth: displaySize.width.toInt(),
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    media.url,
                    cacheHeight: displaySize.height.toInt(),
                    cacheWidth: displaySize.width.toInt(),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ),
    );

    // media.file != null
    //     ? Image.file(
    //         media.file!,
    //         fit: BoxFit.cover,
    //         gaplessPlayback: true,
    //       )
    //     : Image.network(
    //         media.url,
    //         fit: BoxFit.cover,
    //         gaplessPlayback: true,
    //       );
  }
}

extension PaletteExtensionsMap on Map<Identifier, Palette> {
  Map<Identifier, Palette> those(List<Identifier> ids) {
    var map = <Identifier, Palette>{};
    for (final id in ids) {
      map[id] = this[id]!;
    }
    return map;
  }
}

extension PaletteExtensions on Iterable<Palette> {
  List<Palette> inThatOrder(Iterable<Identifier> ids) {
    var theList = <Palette>[];
    var palIds = asIds();
    for (final id in ids) {
      if (palIds.contains(id)) {
        theList.add(firstWhere((p) => p.node.id == id));
      }
    }
    return theList;
  }

  List<Palette> inReversedOrder(Iterable<Identifier> ids) {
    var theList = <Palette>[];
    var palIds = asIds();
    for (final id in ids.toList(growable: false).reversed) {
      if (palIds.contains(id)) {
        theList.add(firstWhere((p) => p.node.id == id));
      }
    }
    return theList;
  }

  List<Palette> formatted() => toList(growable: false)
    ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  List<Palette> formattedReverse() => toList(growable: false)
    ..sort((a, b) => a.node.activity.compareTo(b.node.activity));
  Iterable<Palette> unfolded() => where((p) => !p.fold);
  Iterable<Palette> folded() => where((p) => p.fold);
  Iterable<Palette> deactivated() => map((p) => p.deactivated());
  Iterable<BaseNode> asNodes<BaseNode>() =>
      map((p) => p.node).whereType<BaseNode>();
  Iterable<Palette> selected() => where((p) => p.selected);
  Iterable<Palette> notSelected() => where((p) => !p.selected);
  Iterable<Identifier> asIds() => map((e) => e.node.id);
  Iterable<Palette> chatables() => where((p) => p.node is ChatableNode);
  Iterable<Palette> users() => where((p) => p.node is User);
  Iterable<Palette> people() => where((p) => p.node is Person);
  Iterable<Palette> groups() => where((p) => p.node is GroupNode);
  Iterable<Palette> those(Iterable<Identifier> ids) =>
      where((p) => ids.contains(p.node.id));
  Iterable<Palette> notThose(Iterable<Identifier> ids) =>
      where((p) => !ids.contains(p.node.id));
  Iterable<Palette> forwardables() =>
      where((p) => p.node.isPublicGroup || p.node is User);
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

enum DisplayType {
  image,
  video,
  camera,
}

class Down4Display extends StatelessWidget {
  final Size renderRect;
  final double captureAspectRatio;
  final Widget child;
  final bool isReversed;
  final DisplayType displayType;

  const Down4Display({
    required this.captureAspectRatio,
    required this.displayType,
    required this.isReversed,
    required this.renderRect,
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scale = renderRect.aspectRatio * captureAspectRatio;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(isReversed ? math.pi : 0),
      child: Transform.scale(
        scale: displayType == DisplayType.video
            ? null
            : scale > 1
                ? scale
                : 1 / scale,
        scaleY: displayType == DisplayType.video ? captureAspectRatio : null,
        child: Center(child: child),
      ),
    );
  }
}

Future<Size>? calculateImageDimension({File? f, Uint8List? d, String? url}) {
  Completer<Size> completer = Completer();
  Image? image = f != null
      ? Image.file(f)
      : d != null
          ? Image.memory(d)
          : url != null
              ? Image.network(url)
              : null;
  if (image == null) return null;
  image.image.resolve(const ImageConfiguration()).addListener(
    ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        var myImage = image.image;
        Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
        completer.complete(size);
      },
    ),
  );
  return completer.future;
}

Future<Size> decodeImageSize(Uint8List d) async {
  final decodedImage = await decodeImageFromList(d);
  return Size(
    decodedImage.width.toDouble(),
    decodedImage.height.toDouble(),
  );
}

Future<List<Pair<String, String>>> randomPrompts(int qty) async {
  const String adjPath = "lib/src/assets/texts/descriptive_adjectives.txt";
  const String nounsPath = "lib/src/assets/texts/concrete_nouns.txt";

  final adjectives = (await rootBundle.loadString(adjPath)).split('\n');
  final nouns = (await rootBundle.loadString(nounsPath)).split('\n');

  final r = math.Random();
  return List<Pair<String, String>>.generate(qty, (_) {
    final i = r.nextInt(adjectives.length);
    final j = r.nextInt(nouns.length);
    final adjective = adjectives[i];
    final noun = nouns[j];
    return Pair(adjective, noun);
  });
}
