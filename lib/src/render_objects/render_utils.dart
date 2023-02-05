import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter/services.dart';
import 'package:down4/src/down4_utility.dart';
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

class Down4VideoPlayer2 extends StatelessWidget {
  final MessageMedia media;
  final Uint8List? thumbnail;
  final VideoPlayerController videoController;
  final Future<void> Function() touch, stop;

  final Color backgroundColor;
  final Size displaySize;
  final bool forceSquareAnyways;
  final bool autoPlay;
  const Down4VideoPlayer2({
    this.thumbnail,
    required this.touch,
    required this.stop,
    required this.videoController,
    required this.backgroundColor,
    required this.media,
    required this.autoPlay,
    required this.displaySize,
    this.forceSquareAnyways = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      videoController.value.isPlaying
          ? Down4VideoTransform(
              displaySize: displaySize,
              isReversed: media.isVideo,
              isSquared: media.metadata.isSquared || forceSquareAnyways,
              video: VideoPlayer(videoController),
              videoAspectRatio: media.metadata.elementAspectRatio)
          : Stack(
              children: [
                Down4ImageTransform(
                    image: Image.memory(thumbnail!,
                        fit: BoxFit.cover,
                        cacheHeight: displaySize.height.toInt(),
                        cacheWidth: displaySize.width.toInt()),
                    imageAspectRatio: media.metadata.elementAspectRatio,
                    displaySize: displaySize,
                    isSquared: media.metadata.isSquared || forceSquareAnyways,
                    isReversed: media.metadata.isReversed),
                Center(
                    child: SizedBox.square(
                        dimension: displaySize.aspectRatio > 1
                            ? displaySize.height / 4
                            : displaySize.width / 4,
                        child: GestureDetector(
                            onTap: touch,
                            child: Image.asset(
                                "lib/src/assets/images/filled.png",
                                fit: BoxFit.cover))))
              ],
            )
    ]);
  }
}

class Down4VideoPlayer extends StatefulWidget {
  final VideoPlayerController videoController;
  final Widget Function(double) rotatingLogo;
  final MessageMedia media;
  final Uint8List? thumbnail;
  final Color backgroundColor;
  final Size displaySize;
  final bool forceSquareAnyways;
  final bool autoPlay;
  const Down4VideoPlayer({
    this.thumbnail,
    required this.rotatingLogo,
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

class _Down4VideoPlayerState extends State<Down4VideoPlayer> {
  @override
  void initState() {
    super.initState();
    listenOnEnd();
  }

  Future<void> pauseOrPlay() async {
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

  void listenOnEnd() {
    widget.videoController.addListener(() async {
      if (widget.videoController.value.duration ==
              widget.videoController.value.position &&
          !widget.videoController.value.isPlaying) {
        await widget.videoController.seekTo(Duration.zero);
        print("CLOSING VIDEO!");
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
        "DISPLAYING VIDEO = ${widget.videoController.value.isPlaying || widget.thumbnail == null}");
    return widget.videoController.value.isPlaying || widget.thumbnail == null
        ? GestureDetector(
            onTap: pauseOrPlay,
            child: Down4VideoTransform(
                displaySize: widget.displaySize,
                isReversed: widget.media.metadata.isReversed,
                isSquared: widget.media.metadata.isSquared ||
                    widget.forceSquareAnyways,
                video: VideoPlayer(widget.videoController),
                videoAspectRatio: widget.media.metadata.elementAspectRatio))
        : Stack(children: [
            Down4ImageTransform(
                image: Image.memory(widget.thumbnail!,
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
                      onTap: pauseOrPlay,
                      child: Image.asset("lib/src/assets/images/filled.png",
                          fit: BoxFit.cover))),
            )
          ]);
    // return Transform(
    //   alignment: Alignment.center,
    //   transform: Matrix4.rotationY(isReversed ? math.pi : 0),
    //   child: GestureDetector(
    //     onTap: touch,
    //     child: VideoPlayer(_videoController),
    //   ),
    // );
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

// class Down4MediaViewer extends StatelessWidget {
//   final MessageMedia media;
//   final Size displaySize;
//   final Color backgroundColor;
//   final bool forceSquareAnyways;
//   final bool autoPlayIfVideo;
//   final Widget rotatingLogo;
//   const Down4MediaViewer({
//     required this.rotatingLogo,
//     required this.backgroundColor,
//     required this.media,
//     required this.displaySize,
//     this.forceSquareAnyways = false,
//     this.autoPlayIfVideo = false,
//     Key? key,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return media.isVideo
//         ? Down4VideoPlayer(
//             media: media,
//             backgroundColor: backgroundColor,
//             displaySize: displaySize,
//             forceSquareAnyways: forceSquareAnyways,
//             autoPlay: autoPlayIfVideo,
//             rotatingLogo: rotatingLogo,
//           )
//         : Down4ImageViewer(
//             media: media,
//             displaySize: displaySize,
//             forceSquareAnyways: forceSquareAnyways,
//           );
//   }
// }

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

// enum DisplayType {
//   image,
//   video,
//   camera,
// }

// class Down4Display extends StatelessWidget {
//   final Size renderRect;
//   final double captureAspectRatio;
//   final Widget child;
//   final bool isReversed;
//   final DisplayType displayType;

//   const Down4Display({
//     required this.captureAspectRatio,
//     required this.displayType,
//     required this.isReversed,
//     required this.renderRect,
//     required this.child,
//     Key? key,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final scale = renderRect.aspectRatio * captureAspectRatio;
//     return Transform(
//       alignment: Alignment.center,
//       transform: Matrix4.rotationY(isReversed ? math.pi : 0),
//       child: Transform.scale(
//         scale: displayType == DisplayType.video
//             ? null
//             : scale > 1
//                 ? scale
//                 : 1 / scale,
//         scaleY: displayType == DisplayType.video ? captureAspectRatio : null,
//         child: Center(child: child),
//       ),
//     );
//   }
// }

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

// Future<Size?> calculateImageDimension({
//   File? f,
//   Uint8List? d,
//   String? url,
// }) async {
//   Image? image = f != null
//       ? Image.file(f)
//       : d != null
//           ? Image.memory(d)
//           : url != null
//               ? Image.network(url)
//               : null;
//   if (image == null) return null;
//   Future<ImageInfo> getImageInfo(Image img) async {
//     final c = Completer<ImageInfo>();
//     img.image
//         .resolve(const ImageConfiguration())
//         .addListener(ImageStreamListener((ImageInfo i, bool _) {
//       c.complete(i);
//     }));
//     return c.future;
//   }

//   final info = await getImageInfo(image);
//   return Size(info.image.width.toDouble(), info.image.height.toDouble());
// }

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
