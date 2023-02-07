import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter/services.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'palette.dart';

import '../data_objects.dart';

Image down4Logo(double dimension) => Image.asset(
      "lib/src/assets/images/down4_inverted.png",
      height: dimension,
      width: dimension,
    );

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
  final VideoPlayerController videoController;
  // final Widget Function(double) rotatingLogo;
  final MessageMedia media;
  // final String? thumbnail;
  final Color backgroundColor;
  final Size displaySize;
  final bool forceSquareAnyways;
  final bool autoPlay;
  const Down4VideoPlayer({
    // this.thumbnail,
    // required this.rotatingLogo,
    required this.videoController,
    required this.backgroundColor,
    required this.media,
    required this.autoPlay,
    required this.displaySize,
    this.forceSquareAnyways = false,
    Key? key,
  }) : super(key: key);

  @override
  State<Down4VideoPlayer> createState() => _Down4VideoPlayerState();
}

class _Down4VideoPlayerState extends State<Down4VideoPlayer>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    if (widget.videoController.value.isInitialized) {
      widget.videoController.addListener(_listenOnEnd);
      print("LISTENING ON END OF VIDEO ID ${widget.media.id}");
    } else {
      _animationController =
          AnimationController(vsync: this, duration: const Duration(seconds: 2))
            ..repeat();
    }

    print("INITIALIZING STATE OF VIDEO ID ${widget.media.id}");
  }

  @override
  void didUpdateWidget(Down4VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("DID UPDATE WIDGET OF VIDEO ID ${widget.media.id}");
  }

  @override
  void dispose() {
    print("DISPOSING STATE OF VIDEO ID ${widget.media.id}");
    _animationController?.dispose();
    if (widget.videoController.value.isInitialized) {
      print("REMOVING LISTEN ON END OF VIDEO ID ${widget.media.id}");
      widget.videoController.removeListener(_listenOnEnd);
    }
    super.dispose();
  }

  bool loading = false;

  Future<void> _initController() async {
    setState(() {
      loading = true;
    });
    await widget.videoController.initialize();
    widget.videoController.addListener(_listenOnEnd);
    if (widget.autoPlay) {
      widget.videoController
        ..setLooping(true)
        ..play();
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> _pauseOrPlay() async {
    if (!widget.autoPlay) {
      if (widget.videoController.value.isPlaying == true) {
        await widget.videoController.pause();
        await widget.videoController.seekTo(Duration.zero);
      } else {
        await widget.videoController.play();
      }
    }
    setState(() {});
  }

  Future<void> onTap() async {
    if (!widget.videoController.value.isInitialized) {
      await _initController();
    }
    await _pauseOrPlay();
  }

  void _listenOnEnd() async {
    if (widget.videoController.value.duration ==
            widget.videoController.value.position &&
        !widget.videoController.value.isPlaying) {
      await widget.videoController.seekTo(Duration.zero);
      print("CLOSING VIDEO!");
      setState(() {});
    }
  }

  AnimationController? _animationController;

  Widget rotatingLogo(double dimension) {
    return AnimatedBuilder(
      animation: _animationController!,
      builder: (_, child) => Transform.rotate(
          angle: _animationController!.value * 2 * math.pi, child: child),
      child: down4Logo(dimension),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.videoController.value.isInitialized && !loading) {
      print("THUMBNAIL PATH = ${widget.media.thumbnail}");
      return Stack(children: [
        Down4ImageTransform(
            image: Image.file(widget.media.thumbnailFile!,
                fit: BoxFit.cover,
                cacheHeight: widget.displaySize.height.toInt(),
                cacheWidth: widget.displaySize.width.toInt()),
            imageAspectRatio: widget.media.metadata.elementAspectRatio,
            displaySize: widget.displaySize,
            isSquared:
                widget.media.metadata.isSquared || widget.forceSquareAnyways,
            isReversed: widget.media.metadata.isReversed),
        Center(
            child: SizedBox.square(
                dimension: widget.displaySize.aspectRatio > 1
                    ? widget.displaySize.height / 4
                    : widget.displaySize.width / 4,
                child: GestureDetector(
                    onTap: onTap,
                    child: Image.asset("lib/src/assets/images/filled.png",
                        fit: BoxFit.cover))))
      ]);
      // return FutureBuilder(
      //   future: _initController(),
      //   builder: (context, snapshot) {
      //     if (snapshot.connectionState == ConnectionState.done) {
      //       if (widget.videoController.value.isPlaying) {
      //         return GestureDetector(
      //           onTap: _pauseOrPlay,
      //           child: Down4VideoTransform(
      //               displaySize: widget.displaySize,
      //               isReversed: widget.media.metadata.isReversed,
      //               isSquared: widget.media.metadata.isSquared ||
      //                   widget.forceSquareAnyways,
      //               video: VideoPlayer(widget.videoController),
      //               videoAspectRatio: widget.media.metadata.elementAspectRatio),
      //         );
      //       } else {
      //         return Stack(
      //           children: [
      //             Down4ImageTransform(
      //                 image: Image.memory(widget.thumbnail!,
      //                     fit: BoxFit.cover,
      //                     cacheHeight: widget.displaySize.height.toInt(),
      //                     cacheWidth: widget.displaySize.width.toInt()),
      //                 imageAspectRatio:
      //                     widget.media.metadata.elementAspectRatio,
      //                 displaySize: widget.displaySize,
      //                 isSquared: widget.media.metadata.isSquared ||
      //                     widget.forceSquareAnyways,
      //                 isReversed: widget.media.metadata.isReversed),
      //             Center(
      //                 child: SizedBox.square(
      //                     dimension: widget.displaySize.aspectRatio > 1
      //                         ? widget.displaySize.height / 4
      //                         : widget.displaySize.width / 4,
      //                     child: GestureDetector(
      //                         onTap: _pauseOrPlay,
      //                         child: Image.asset(
      //                             "lib/src/assets/images/filled.png",
      //                             fit: BoxFit.cover))))
      //           ],
      //         );
      //       }
      //     } else {
      //       return S
      //     }
      //   },
      // );
    } else if (!widget.videoController.value.isInitialized && loading) {
      return Stack(children: [
        Down4ImageTransform(
            image: Image.file(widget.media.thumbnailFile!,
                fit: BoxFit.cover,
                cacheHeight: widget.displaySize.height.toInt(),
                cacheWidth: widget.displaySize.width.toInt()),
            imageAspectRatio: widget.media.metadata.elementAspectRatio,
            displaySize: widget.displaySize,
            isSquared:
                widget.media.metadata.isSquared || widget.forceSquareAnyways,
            isReversed: widget.media.metadata.isReversed),
        Center(
            child: GestureDetector(
                onTap: onTap,
                child: rotatingLogo(widget.displaySize.aspectRatio > 1
                    ? widget.displaySize.height / 4
                    : widget.displaySize.width / 4)))
      ]);
    } else {
      return widget.videoController.value.isPlaying
          ? GestureDetector(
              onTap: _pauseOrPlay,
              child: Down4VideoTransform(
                  displaySize: widget.displaySize,
                  isReversed: widget.media.metadata.isReversed,
                  isSquared: widget.media.metadata.isSquared ||
                      widget.forceSquareAnyways,
                  video: VideoPlayer(widget.videoController),
                  videoAspectRatio: widget.media.metadata.elementAspectRatio))
          : Stack(children: [
              Down4ImageTransform(
                  image: Image.file(widget.media.thumbnailFile!,
                      fit: BoxFit.cover,
                      cacheHeight: widget.displaySize.height.toInt(),
                      cacheWidth: widget.displaySize.width.toInt()),
                  imageAspectRatio: widget.media.metadata.elementAspectRatio,
                  displaySize: widget.displaySize,
                  isSquared: widget.media.metadata.isSquared ||
                      widget.forceSquareAnyways,
                  isReversed: widget.media.metadata.isReversed),
              Center(
                  child: SizedBox.square(
                      dimension: widget.displaySize.aspectRatio > 1
                          ? widget.displaySize.height / 4
                          : widget.displaySize.width / 4,
                      child: GestureDetector(
                          onTap: _pauseOrPlay,
                          child: Image.asset("lib/src/assets/images/filled.png",
                              fit: BoxFit.cover))))
            ]);
    }
  }
}

class Down4ImageTransform extends StatelessWidget {
  final double imageAspectRatio;
  final Size displaySize;
  final bool isSquared, isReversed;
  final Image image;
  const Down4ImageTransform({
    required this.image,
    required this.imageAspectRatio,
    required this.displaySize,
    required this.isSquared,
    required this.isReversed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: MediaSizeClipper(displaySize),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isReversed ? math.pi : 0),
        child: Transform.scale(
            scaleY: isSquared && imageAspectRatio > 1 ? imageAspectRatio : null,
            scaleX: isSquared && imageAspectRatio <= 1
                ? 1 / imageAspectRatio
                : null,
            scale: !isSquared ? 1.0 : null,
            child: SizedBox.fromSize(size: displaySize, child: image)),
      ),
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
    final theImage = media.file != null
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
          );
    return Down4ImageTransform(
      displaySize: displaySize,
      isSquared: forcedSquared,
      imageAspectRatio: aspectRatio,
      isReversed: isReversed,
      image: theImage,
    );
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

class Down4VideoTransform extends StatelessWidget {
  final Size displaySize;
  final double videoAspectRatio;
  final VideoPlayer video;
  final bool isReversed, isSquared;

  const Down4VideoTransform({
    required this.displaySize,
    required this.videoAspectRatio,
    required this.video,
    required this.isReversed,
    required this.isSquared,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipper: MediaSizeClipper(displaySize),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isReversed ? math.pi : 0),
        child: Transform.scale(
            scaleY: isSquared && videoAspectRatio > 1 ? videoAspectRatio : null,
            scaleX: isSquared && videoAspectRatio <= 1
                ? 1 / videoAspectRatio
                : null,
            scale: !isSquared ? 1.0 : null,
            child: SizedBox.fromSize(size: displaySize, child: video)),
      ),
    );
  }
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
    final adjective = adjectives[i].trim();
    final noun = nouns[j].trim();
    return Pair(adjective, noun);
  });
}

Future<void> clearAppCache() async {
  var tempDir = await getTemporaryDirectory();
  Directory(tempDir.path).delete(recursive: true);
}
