import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import '../couch.dart' show cache, global;
import 'package:image/image.dart' as IMG;

// import 'package:better_player/better_player.dart';
import '../themes.dart';
import 'palette.dart';

import '../data_objects.dart';
import 'chat_message.dart' show ChatMessage;
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../globals.dart';

// class FireVideo extends StatefulWidget {
//   final FireMedia media;
//   final Size displaySize;
//   final bool forceSquare;
//   const FireVideo(this.media,
//       {required this.displaySize, this.forceSquare = false, Key? key})
//       : super(key: key);
//
//   @override
//   State<FireVideo> createState() => _FireVideoState();
// }
//
// class _FireVideoState extends State<FireVideo> {
//   BetterPlayerController? _controller;
//   BetterPlayer? _player;
//
//
//   Widget videoTransform(BetterPlayer video) => Down4VideoTransform(
//       displaySize: widget.displaySize,
//       videoAspectRatio: widget.media.aspectRatio,
//       video: video,
//       isReversed: widget.media.isReversed,
//       isSquared: widget.media.isSquared || widget.forceSquare);
//
//   Future<BetterPlayerDataSource?> playerDataSource() async {
//     Uint8List? local = await widget.media.videoData;
//     if (local != null) {
//       return BetterPlayerDataSource.memory(local,
//           videoExtension: widget.media.extension);
//     } else {
//       final url = await widget.media.videoUrl;
//       if (url == null) return null;
//       return BetterPlayerDataSource.network(url);
//     }
//   }
//
//   Future<void> loadController() async {
//     final datasource = await playerDataSource();
//     if (datasource == null) return null;
//     _controller =   BetterPlayerController(
//         BetterPlayerConfiguration(aspectRatio: widget.media.aspectRatio),
//         betterPlayerDataSource: datasource);
//   }
//
//   Future<void>() loadPlayer() async {
//     if (_controller == null) await loadController();
//     if (_controller == null) return;
//     _player = BetterPlayer(controller: _controller!);
//   }
//
//
//
//   Widget preview() {
//     return Stack(
//       children: [
//         displayImage(displaySize: displaySize, forceSquare: forceSquare),
//         Center(
//             child: SizedBox.square(
//                 dimension: displaySize.aspectRatio > 1
//                     ? displaySize.height / 4
//                     : displaySize.width / 4,
//                 child: GestureDetector(
//                     onTap: _pauseOrPlay,
//                     child: Image.asset("assets/images/filled.png",
//                         fit: BoxFit.cover))))
//       ],
//     );
//   }
// }

class FireNodeImageDisplay extends StatefulWidget {
  final FireNode node;
  final Size? displaySize;
  const FireNodeImageDisplay(
    this.node, [
    this.displaySize,
    Key? key,
  ]) : super(key: key);

  @override
  State<FireNodeImageDisplay> createState() => _FireNodeImageDisplayState();
}

class _FireNodeImageDisplayState extends State<FireNodeImageDisplay> {
  late FireMedia? media = cache<FireMedia>(widget.node.mediaID);
  late Image image = media?.tinyThumbnail != null
      ? memoryIm(base64Decode(media!.tinyThumbnail!))
      : widget.node.defaultNodeImage(widget.displaySize);
  Image? realImage;

  void loadImage() {
    if (media?.cachedFile != null) {
      // print("Will render file image");
      realImage = fileIm(media!.cachePath!);
    } else if (media?.cachedImage != null) {
      // print("Will render memory image");
      realImage = memoryIm(media!.cachedImage!);
    } else if (media?.cachedUrl != null) {
      // print("Will render network image");
      realImage = netIm(media!.cachedUrl!);
    }
    setState(() {});
  }

  Widget transformedImage(Image image) => Down4ImageTransform(
      image: image,
      imageAspectRatio: media?.aspectRatio ?? 1.0,
      displaySize: widget.displaySize ?? Size.square(Palette.paletteHeight),
      isScaled: true,
      isReversed: media?.isReversed ?? false);

  Image memoryIm(Uint8List d) => Image.memory(d,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheHeight: widget.displaySize?.height.toInt() ??
          Palette.paletteHeight.toInt() * 2,
      cacheWidth: widget.displaySize?.width.toInt() ??
          Palette.paletteHeight.toInt() * 2);

  Image fileIm(String p) => Image.file(File(p),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheHeight: widget.displaySize?.height.toInt() ??
          Palette.paletteHeight.toInt() * 2,
      cacheWidth: widget.displaySize?.width.toInt() ??
          Palette.paletteHeight.toInt() * 2);

  Image netIm(String url) => Image.network(url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheHeight: widget.displaySize?.height.toInt() ??
          Palette.paletteHeight.toInt() * 2,
      cacheWidth: widget.displaySize?.width.toInt() ??
          Palette.paletteHeight.toInt() * 2);

  void loadThatBoy() async {
    loadImage();
    media ??= await global<FireMedia>(widget.node.mediaID,
        doFetch: true, mediaInfo: (withData: false, onlineID: null));
    if (media == null) return;
    loadImage();

    if (media?.cachePath != null) return;
    if (media?.cachedImage == null) await media?.imageData;
    if (media?.cachedImage != null) return loadImage();
    if (media?.cachedUrl == null && media?.isVideo == false) await media?.url;
    if (media?.cachedUrl != null) return loadImage();
  }

  @override
  void didUpdateWidget(FireNodeImageDisplay old) {
    super.didUpdateWidget(old);
    if (widget.node.mediaID != media?.id) {
      print("RELOADING THAT BOY!");
      loadThatBoy();
    }
  }

  @override
  void initState() {
    super.initState();
    loadThatBoy();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.fromSize(
          size: widget.displaySize ?? Size.square(Palette.paletteHeight),
          child: widget.node.iconPlaceHolder ?? transformedImage(image),
        ),
        SizedBox.fromSize(
          size: widget.displaySize ?? Size.square(Palette.paletteHeight),
          child: AnimatedOpacity(
              curve: Curves.easeInExpo,
              duration: const Duration(milliseconds: 400),
              opacity: realImage == null ? 0 : 1,
              child: realImage != null
                  ? transformedImage(realImage!)
                  : const SizedBox.shrink()),
        )
      ],
    );
  }
}

class FireImageDisplay extends StatefulWidget {
  final FireMedia media;
  final Size displaySize;
  final bool forceSquareAnyways;
  const FireImageDisplay(
    this.media,
    this.displaySize, [
    this.forceSquareAnyways = false,
    Key? key,
  ]) : super(key: key);

  @override
  State<FireImageDisplay> createState() => _FireImageDisplay();
}

class _FireImageDisplay extends State<FireImageDisplay> {
  late FireMedia media = widget.media;
  late Image image = media.tinyThumbnail == null
      ? memoryIm(g.background)
      : memoryIm(base64Decode(media.tinyThumbnail!));
  Image? realImage;

  bool get squared => media.isSquared || widget.forceSquareAnyways;

  Widget transformedImage(Image image) => Down4ImageTransform(
      image: image,
      imageAspectRatio: media.aspectRatio,
      displaySize: widget.displaySize,
      isScaled: media.isSquared || widget.forceSquareAnyways,
      isReversed: media.isReversed);

  void loadImage() {
    if (media.cachePath != null) {
      realImage = fileIm(media.cachePath!);
    } else if (media.cachedImage != null) {
      realImage = memoryIm(media.cachedImage!);
    } else if (media.cachedUrl != null) {
      realImage = netIm(media.cachedUrl!);
    }
    setState(() {});
  }

  Image memoryIm(Uint8List d) {
    return Image.memory(d,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheHeight: widget.displaySize.height.toInt(),
        cacheWidth: widget.displaySize.width.toInt());
  }

  Image fileIm(String p) {
    return Image.file(File(p),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheHeight: widget.displaySize.height.toInt(),
        cacheWidth: widget.displaySize.width.toInt());
  }

  Image netIm(String url) {
    return Image.network(url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheHeight: widget.displaySize.height.toInt(),
        cacheWidth: widget.displaySize.width.toInt());
  }

  void loadThatBoy() async {
    loadImage();
    if (media.cachePath != null) return;
    if (media.cachedImage == null) await media.imageData;
    if (media.cachedImage != null) return loadImage();
    if (media.cachedUrl == null && !media.isVideo) await media.url;
    if (media.cachedUrl != null) return loadImage();
  }

  @override
  void didUpdateWidget(FireImageDisplay old) {
    super.didUpdateWidget(old);
    if (media.id != widget.media.id) {
      media = widget.media;
      loadThatBoy();
    }
  }

  @override
  void initState() {
    super.initState();
    loadThatBoy();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.fromSize(
          size: widget.displaySize,
          child: transformedImage(image),
        ),
        SizedBox.fromSize(
          size: widget.displaySize,
          child: AnimatedOpacity(
              curve: Curves.easeInExpo,
              duration: const Duration(seconds: 1),
              opacity: realImage == null ? 0 : 1,
              child: realImage != null
                  ? transformedImage(realImage!)
                  : const SizedBox.shrink()),
        )
      ],
    );

    // return SizedBox.fromSize(
    //     size: widget.displaySize,
    //     child: DecoratedBox(
    //         decoration: BoxDecoration(
    //             image: DecorationImage(image: image.image, fit: BoxFit.cover)),
    //         child: AnimatedOpacity(
    //             curve: Curves.easeInExpo,
    //             duration: const Duration(seconds: 2),
    //             opacity: realImage == null ? 0 : 1,
    //             child: realImage != null
    //                 ? transformedImage(realImage!)
    //                 : const SizedBox.shrink())));

    // if (image == null) return SizedBox.fromSize(size: widget.displaySize);
    // return Down4ImageTransform(
    //     image: image!,
    //     imageAspectRatio: media.aspectRatio,
    //     displaySize: widget.displaySize,
    //     isSquared: media.isSquared,
    //     isReversed: media.isReversed);
  }
}

extension InvertedSize on Size {
  Size get inverted => Size(height, width);
}

extension MediaDisplay on FireMedia {
  Widget display({
    required Size size,
    bool forceSquare = false,
    VideoPlayerController? controller,
    bool autoPlay = false,
  }) {
    if (isVideo) {
      return displayVideo(
          size: size,
          controller: controller,
          forceSquare: forceSquare,
          autoPlay: autoPlay);
    } else {
      return displayImage(size: size, forceSquare: forceSquare);
    }
  }

  Widget displayVideo({
    required Size size,
    VideoPlayerController? controller,
    bool autoPlay = false,
    bool forceSquare = false,
  }) {
    return Down4VideoPlayer(
        videoController: controller,
        backgroundColor: Colors.black45,
        media: this,
        autoPlay: autoPlay,
        displaySize: size);
  }

  Widget displaySnip({VideoPlayerController? controller}) {
    double scale = g.sizes.fullAspectRatio * aspectRatio;
    if (isVideo) return displayVideo(size: size, controller: controller);
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isReversed ? math.pi : 0),
        child: Transform.scale(
          scale: scale > 1 ? scale : 1 / scale,
          child: SizedBox(
            height: aspectRatio * g.sizes.w,
            width: g.sizes.w,
            child: displayCachedImage,
          ),
        ),
      ),
    );
  }

  // Widget display2({
  //   required Size size,
  //   bool forceSquare = false,
  //   required BetterPlayer? player,
  //   bool autoPlay = false,
  // }) {
  //   if (isVideo) {
  //     final bpc = BetterPlayer.file(cachePath!,
  //         betterPlayerConfiguration: const BetterPlayerConfiguration(
  //             autoPlay: true, aspectRatio: 1.0, looping: true));

  //     return SizedBox.fromSize(
  //       size: size,
  //       child: bpc,
  //     );

  //     // return displayVideo2(
  //     //     size: size,
  //     //     forceSquare: forceSquare,
  //     //     player: player!,
  //     //     autoPlay: autoPlay);
  //   } else {
  //     return displayImage(size: size);
  //   }
  // }

  // Widget displayVideo2({
  //   required Size size,
  //   required BetterPlayer player,
  //   bool autoPlay = false,
  //   bool forceSquare = false,
  // }) {
  //   return SizedBox.fromSize(size: size, child: player);

  //   // return Down4VideoPlayer2(
  //   //     videoController: controller,
  //   //     backgroundColor: Colors.black45,
  //   //     media: this,
  //   //     displaySize: size);
  // }

  Widget displayImage({required Size size, bool forceSquare = false}) {
    return FireImageDisplay(this, size, forceSquare);
  }
}
//   // Widget displayVideo({required Size displaySize, bool forceSquare = false}) {
//   //
//   //   Widget videoTransform(BetterPlayer video) => Down4VideoTransform(
//   //       displaySize: displaySize,
//   //       videoAspectRatio: aspectRatio,
//   //       video: video,
//   //       isReversed: isReversed,
//   //       isSquared: isSquared || forceSquare);
//   //
//   //   Future<BetterPlayerDataSource?> playerDataSource() async {
//   //     Uint8List? local = await videoData;
//   //     if (local != null) {
//   //       return BetterPlayerDataSource.memory(local, videoExtension: extension);
//   //     } else {
//   //       final url = await url;
//   //       if (url == null) return null;
//   //       return BetterPlayerDataSource.network(url);
//   //     }
//   //   }
//   //
//   //   Future<BetterPlayerController?> player() async {
//   //     final datasource = await playerDataSource();
//   //     if (datasource == null) return null;
//   //     return BetterPlayerController(
//   //         BetterPlayerConfiguration(aspectRatio: aspectRatio),
//   //         betterPlayerDataSource: datasource);
//   //   }
//   //
//   //   Widget preview() {
//   //     return Stack(
//   //       children: [
//   //         displayImage(displaySize: displaySize, forceSquare: forceSquare),
//   //         Center(
//   //             child: SizedBox.square(
//   //                 dimension: displaySize.aspectRatio > 1
//   //                     ? displaySize.height / 4
//   //                     : displaySize.width / 4,
//   //                 child: GestureDetector(
//   //                     onTap: _pauseOrPlay,
//   //                     child: Image.asset("assets/images/filled.png",
//   //                         fit: BoxFit.cover))))
//   //       ],
//   //     );
//   //   }
//   // }
//
//   Widget displayVideo({
//     required Size displaySize,
//     required VideoPlayerController controller,
//     bool autoPlay = false,
//     bool forceSquare = false,
//   }) {
//     return Down4VideoPlayer(
//         videoController: controller,
//         backgroundColor: Colors.black45,
//         autoPlay: autoPlay,
//         media: this,
//         displaySize: displaySize);
//   }
//
//   // Widget displayImage({required Size displaySize, bool forceSquare = false}) {
//   //   Widget imageTransform(Image image) => Down4ImageTransform(
//   //       image: image,
//   //       imageAspectRatio: aspectRatio,
//   //       displaySize: displaySize,
//   //       isSquared: isSquared || forceSquare,
//   //       isReversed: isReversed);
//   //
//   //   // return Image.memory(base64Decode(tinyThumbnail!),
//   //   //     fit: BoxFit.cover, gaplessPlayback: true);
//   //
//   //   // Future<Image?> theImage() async {
//   //   //   if (cachePath != null) {
//   //   //     return Image.file(File(cachePath!),
//   //   //         fit: BoxFit.cover, gaplessPlayback: true);
//   //   //   } else {
//   //   //     final d = await imageData;
//   //   //     if (d != null) {
//   //   //       return Image.memory(d, fit: BoxFit.cover, gaplessPlayback: true);
//   //   //     }
//   //   //   }
//   //   //   return null;
//   //   // }
//   //   //
//   //   // if (cachedImage != null) {
//   //   //   return imageTransform(
//   //   //       Image.memory(cachedImage!, fit: BoxFit.cover, gaplessPlayback: true));
//   //   // }
//   //   // return FutureBuilder(
//   //   //   future: theImage(),
//   //   //   builder: (ctx, asn) {
//   //   //     if (!asn.hasData) {
//   //   //       final ttn = tinyThumbnail;
//   //   //       if (ttn != null) {
//   //   //         return imageTransform(Image.memory(base64Decode(ttn),
//   //   //             fit: BoxFit.cover, gaplessPlayback: true));
//   //   //       } else {
//   //   //         return const SizedBox.shrink();
//   //   //       }
//   //   //     }
//   //   //     return imageTransform(asn.requireData!);
//   //   //   },
//   //   // );
//   // }
//
//   // Widget displayMedia({
//   //   required Size displaySize,
//   //   bool forceSquare = false,
//   //   BetterPlayerController? videoController,
//   // }) {
//   //   if (isVideo) {
//   //     return displayVideo(
//   //         displaySize: displaySize,
//   //         forceSquare: forceSquare,
//   //         controller: videoController);
//   //   } else {
//   //     return FireImageDisplay(this, displaySize, forceSquare);
//   //   }
//   // }
// }

// class FireImageViewer extends StatelessWidget {
//   final FireMedia media;
//   final Size displaySize;
//   final bool forceSquareAnyways;
//
//   const FireImageViewer({
//     required this.media,
//     required this.displaySize,
//     required this.forceSquareAnyways,
//     Key? key,
//   }) : super(key: key);
//
//   Widget transform(Image image) => Down4ImageTransform(
//       image: image,
//       imageAspectRatio: media.aspectRatio,
//       displaySize: displaySize,
//       isSquared: media.isSquared,
//       isReversed: media.isReversed);
//
//   @override
//   Widget build(BuildContext context) {
//     if (media.cachedImage != null) {
//       return transform(Image.memory(media.cachedImage!));
//     }
//     return FutureBuilder(
//       future: media.imageData,
//       builder: (ctx, asn) {
//         if (!asn.hasData) {
//           transform(Image.memory(base64Decode(media.tinyThumbnail)));
//         }
//         return transform(Image.memory(asn.requireData!));
//       },
//     );
//   }
// }

Widget down4Logo(double dimension, Color color) {
  return Center(
      child: SizedBox.square(
    dimension: dimension,
    child: FittedBox(child: Icon(Down4Icon.down4Inverted, color: color)),
  ));

  // return Image.asset(
  //   "assets/images/down4_inverted_white.png",
  //   height: dimension,
  //   width: dimension,
  // );
}

Widget backArrow() {
  return Center(
    child: SizedBox.fromSize(
      size: Size.square(g.sizes.headerHeight / 2),
      child: FittedBox(
        child: Icon(Icons.arrow_back_ios_new_rounded,
            color: g.theme.backArrowColor),
      ),
    ),
  );
}

abstract class Down4PageWidget extends Widget {
  ID get id;
}

class PageManager {
  List<ID> _idStack;
  Map<ID, Down4PageWidget> pages;
  PageManager()
      : _idStack = [],
        pages = {};

  Down4PageWidget get currentPage => pages[_idStack.last]!;
  Down4PageWidget get prevPage => pages[_idStack[_idStack.length - 2]]!;

  int get nPages => _idStack.length;

  ID get currentID => _idStack.last;
  Iterable<ID> get path => _idStack
      .asMap()
      .map((i, id) => _idStack.sublist(i + 1).contains(id)
          ? MapEntry(i, null)
          : MapEntry(i, id))
      .values
      .whereType<ID>();

  void put(Down4PageWidget page) {
    _idStack.add(page.id);
    pages[page.id] = page;
  }

  void refresh(Down4PageWidget page) => pages[page.id] = page;

  void popInBetween() {
    final n = nPages;
    for (int i = 1; i < n - 1; i++) {
      pages.remove(_idStack[i]);
      _idStack.removeAt(i);
    }
  }

  void popUntilHome() {
    final n = nPages;
    for (int i = 0; i < n - 1; i++) {
      pop();
    }
  }

  void pop() {
    final last = _idStack.removeLast();
    // id could be twice in stack because graph can be cyclic
    // in this case we don't remove the page from pages to keep the state
    if (!_idStack.contains(last)) pages.remove(last);
  }
}

class Down4TextPainter extends CustomPainter {
  final TextPainter painter;
  const Down4TextPainter({required this.painter});

  @override
  void paint(Canvas canvas, Size size) {
    painter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRebuildSemantics(Down4TextPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Down4TextBubblePainter extends CustomPainter {
  final TextPainter textPainter, datePainter;
  final Offset dateOffset;

  const Down4TextBubblePainter({
    required this.textPainter,
    required this.datePainter,
    required this.dateOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    textPainter.paint(canvas, const Offset(0, 0));
    datePainter.paint(canvas, dateOffset);
  }

  @override
  bool shouldRebuildSemantics(Down4TextBubblePainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Down4TextBubble extends StatelessWidget {
  final String text, dateText;
  final double? inheritedWidth;
  late final TextPainter textPainter, datePainter;
  late final double calcWidth, calcHeight;
  late final bool dateOnSameLine;
  late final Offset dateOffset;

  Down4TextBubble({
    required this.text,
    required this.dateText,
    this.inheritedWidth,
    Key? key,
  }) : super(key: key) {
    final ts = TextSpan(text: text, style: g.theme.chatBubbleTextStyle);
    final ds = TextSpan(text: dateText, style: g.theme.chatBubbleDateTextStyle);

    textPainter = TextPainter(
        text: ts,
        textDirection: TextDirection.ltr,
        textWidthBasis: TextWidthBasis.longestLine);
    datePainter = TextPainter(
        text: ds,
        textDirection: TextDirection.ltr,
        textWidthBasis: TextWidthBasis.longestLine);

    textPainter.layout(maxWidth: ChatMessage.maxTextWidth);
    datePainter.layout();
    final metrics = textPainter.computeLineMetrics();

    final widthWithDateOnSameLine = metrics.last.width + datePainter.width;
    final maxTextWidth = textPainter.width;

    dateOnSameLine = widthWithDateOnSameLine <= ChatMessage.maxTextWidth;

    calcWidth = inheritedWidth ??
        math.max(dateOnSameLine ? widthWithDateOnSameLine : 0, maxTextWidth);
    calcHeight = textPainter.height + (dateOnSameLine ? 0 : datePainter.height);

    dateOffset = Offset(
      calcWidth - datePainter.width,
      calcHeight - (datePainter.height * 1 / golden),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: CustomPaint(
            painter: Down4TextBubblePainter(
                textPainter: textPainter,
                datePainter: datePainter,
                dateOffset: dateOffset),
            isComplex: true,
            size: Size(inheritedWidth ?? calcWidth, calcHeight)));
  }
}

class Down4Text extends StatelessWidget {
  final String text;
  final Size? inheritedSize;
  final TextStyle style;

  late final Size calculatedSize;
  late final TextPainter painter;
  Down4Text({
    required this.text,
    required this.style,
    this.inheritedSize,
    Key? key,
  }) : super(key: key) {
    painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr);
    painter.layout(maxWidth: inheritedSize?.width ?? double.infinity);
    calculatedSize = Size(painter.width, painter.height);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: CustomPaint(
            painter: Down4TextPainter(painter: painter),
            size: inheritedSize ?? calculatedSize,
            isComplex: true));
  }
}

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
      style: TextStyle(
          overflow: TextOverflow.ellipsis,
          fontSize: 16,
          color: g.theme.paletteTextColor,
          fontWeight: FontWeight.normal),
      textAlign: widget.textAlign,
      decoration: InputDecoration(
        hintStyle: TextStyle(
            overflow: TextOverflow.ellipsis,
            fontSize: 16,
            color: g.theme.paletteTextColor,
            fontWeight: FontWeight.normal),
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

// class Down4VideoPlayer2 extends StatefulWidget {
//   final BetterPlayerController? videoController;
//   final FireMedia media;
//   final Color backgroundColor;
//   final Size displaySize;
//   final bool forceSquareAnyways;
//   // final bool autoPlay;
//   const Down4VideoPlayer2({
//     required this.videoController,
//     required this.backgroundColor,
//     required this.media,
//     // required this.autoPlay,
//     required this.displaySize,
//     this.forceSquareAnyways = false,
//     Key? key,
//   }) : super(key: key);

//   @override
//   State<Down4VideoPlayer2> createState() => _Down4VideoPlayerState2();
// }

// class _Down4VideoPlayerState2 extends State<Down4VideoPlayer2> {
//   double turns = 0.0;
//   Timer? timer;
//   bool ready = false;

//   late BetterPlayerController bpc = widget.videoController ??
//       BetterPlayerController(BetterPlayerConfiguration(autoPlay: true));

//   @override
//   void dispose() {
//     print("DISPOSING STATE OF VIDEO ID ${widget.media.id}");
//     if (ready) {
//       print("REMOVING LISTEN ON END OF VIDEO ID ${widget.media.id}");
//       bpc.removeEventsListener(_listenOnEnd2);
//     }
//     if (mounted) super.dispose();
//   }

//   @override
//   void didUpdateWidget(Down4VideoPlayer2 oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     print("DID UPDATE WIDGET OF VIDEO ID ${widget.media.id}");
//   }

//   Future<BetterPlayerDataSource?> playerDataSource() async {
//     if (widget.media.cachePath != null) {
//       print("FOUND PATH, RETURNING FILE BETTERPLAYER!");
//       return BetterPlayerDataSource.file(widget.media.cachePath!);
//     }

//     Uint8List? local; // = await widget.media.videoData;
//     if (local != null) {
//       return BetterPlayerDataSource.memory(local,
//           videoExtension: widget.media.extension);
//     } else {
//       final url = await widget.media.url;
//       if (url == null) return null;
//       return BetterPlayerDataSource.network(url);
//     }
//   }

//   bool get hasDatasource => bpc.hasCurrentDataSourceStarted;

//   // bool get videoIsInitialized => bpc.isVideoInitialized() ?? false;

//   bool get videoIsPlaying => bpc.isPlaying() ?? false;

//   bool loading = false;

//   void startTurning() {
//     timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
//       setState(() {
//         turns += 2 * math.pi / 10;
//         turns = turns % (2 * math.pi);
//       });
//     });
//   }

//   // Future<void> _initController() async {
//   //   setState(() {
//   //     loading = true;
//   //   });
//   //   final dataSource = await playerDataSource();
//   //   print("DATASOURCE == ${dataSource}");
//   //   if (dataSource == null) return;
//   //   await bpc.setupDataSource(dataSource);
//   //   bpc.addEventsListener(_listenOnEnd2);
//   //   setState(() {
//   //     loading = false;
//   //     ready = true;
//   //     timer?.cancel();
//   //   });
//   // }

//   double get logoDimensions => widget.displaySize.aspectRatio > 1
//       ? widget.displaySize.height / 4
//       : widget.displaySize.width / 4;

//   // Future<void> _pauseOrPlay() async {
//   //   // if (!widget.autoPlay) {
//   //   if (videoIsPlaying) {
//   //     await bpc.pause();
//   //     await bpc.seekTo(Duration.zero);
//   //   } else {
//   //     await bpc.play();
//   //   }
//   //   // }
//   //   setState(() {});
//   // }

//   // Future<void> onTap() async {
//   //   if (!ready) {
//   //     startTurning();
//   //     await _initController();
//   //   }
//   //   await _pauseOrPlay();
//   // }

//   // void _listenOnEnd2(BetterPlayerEvent ev) async {
//   //   if (ev.betterPlayerEventType == BetterPlayerEventType.finished) {
//   //     bpc
//   //       ..pause()
//   //       ..seekTo(Duration.zero);
//   //     setState(() {});
//   //   }
//   // }

//   // Widget thumbnail() {
//   //   return const ColoredBox(color: Colors.blue);
//   //   // return FireImageDisplay(
//   //   //     widget.media, widget.displaySize, widget.forceSquareAnyways);
//   // }

//   // Widget playButton() {
//   //   return SizedBox.square(
//   //       dimension: widget.displaySize.aspectRatio > 1
//   //           ? widget.displaySize.height / 4
//   //           : widget.displaySize.width / 4,
//   //       child: GestureDetector(
//   //           onTap: onTap,
//   //           child: Image.asset("assets/images/filled.png", fit: BoxFit.cover)));
//   // }

//   Widget rotatingLogo(double dimension) {
//     return AnimatedRotation(
//       duration: const Duration(seconds: 1),
//       turns: turns,
//       child: down4Logo(dimension),
//     );
//   }

//   Widget video() {
//     return SizedBox.fromSize(
//             size: widget.displaySize,
//             child:
//                 //  AspectRatio(
//                 //     aspectRatio: widget.displaySize.aspectRatio,
//                 //     child:
//                 BetterPlayer(controller: bpc))
//         // )
//         ;

//     // if (videoIsPlaying) {
//     //   return GestureDetector(
//     //       onTap: _pauseOrPlay,
//     //       child: Down4VideoTransform2(
//     //           displaySize: widget.displaySize,
//     //           isReversed: widget.media.isReversed,
//     //           isSquared: widget.media.isSquared || widget.forceSquareAnyways,
//     //           video: BetterPlayer(controller: bpc),
//     //           videoAspectRatio: widget.media.aspectRatio));
//     // } else {
//     //   return Stack(children: [thumbnail(), playButton()]);
//     // }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return video();
//     if (!ready && !loading) {
//       return Stack(children: [thumbnail()]); //, playButton()]);
//     } else if (!ready && loading) {
//       return Stack(children: [thumbnail(), rotatingLogo(logoDimensions)]);
//     } else {
//       return video();
//     }
//   }
// }

class Down4ImageTransform extends StatelessWidget {
  final double imageAspectRatio;
  final Size displaySize;
  final bool isScaled, isReversed;
  final Widget image;
  const Down4ImageTransform({
    required this.image,
    required this.imageAspectRatio,
    required this.displaySize,
    required this.isScaled,
    required this.isReversed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isVegan = (imageAspectRatio > displaySize.aspectRatio);
    // return SizedBox.fromSize(
    //     size: displaySize,
    //     child: Transform(
    //         alignment: Alignment.center,
    //         transform: Matrix4.rotationY(isReversed ? math.pi : 0),
    //         child: image));
    // return SizedBox.fromSize(
    //   size: displaySize,
    //   child: Transform(
    //     alignment: Alignment.center,
    //     transform: Matrix4.rotationY(isReversed ? math.pi : 0),
    //     child: Transform.scale(
    //         scaleY: isSquared && imageAspectRatio > 1 ? imageAspectRatio : null,
    //         scaleX: isSquared && imageAspectRatio <= 1
    //             ? 1 / imageAspectRatio
    //             : null,
    //         scale: !isSquared ? 1.0 : null,
    //         child: image),
    //   ),
    // );
    return ClipRect(
      clipper: MediaSizeClipper(displaySize),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isReversed ? math.pi : 0),
        child: Transform.scale(
          scaleY:
              isScaled && imageAspectRatio < 1 ? 1 / imageAspectRatio : null,
          scaleX: isScaled && imageAspectRatio > 1 ? imageAspectRatio : null,
          scale: !isScaled || imageAspectRatio == 1 ? 1.0 : null,
          child: SizedBox.fromSize(size: displaySize, child: image),
          //  Transform.scale(
          //     scale: 1.0,
          // scale: isSquared
          //     ? imageAspectRatio > 1
          //         ? imageAspectRatio
          //         : 1 / imageAspectRatio
          //     : 1.0,
          // child:

          //  ),
        ),
      ),
    );
  }
}

class Down4VideoPlayer extends StatefulWidget {
  final VideoPlayerController? videoController;
  // final AnimationController animationController;
  // final Widget Function(double) rotatingLogo;
  final FireMedia media;
  final Color backgroundColor;
  final Size displaySize;
  final bool forceSquareAnyways;
  final bool autoPlay;
  const Down4VideoPlayer({
    // this.thumbnail,
    // required this.rotatingLogo,
    // required this.animationController,
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
  bool controllerCreatedOnThisState = false;
  double turns = 0.0;
  Timer? timer;
  late VideoPlayerController? ctrl = widget.videoController;

  bool get ctrlIsInitialized => ctrl?.value.isInitialized ?? false;

  bool get isPlaying => ctrl?.value.isPlaying ?? false;

  Future<void> loadControllerIfNull() async {
    if (ctrl == null) {
      ctrl = await widget.media.videoController;
      controllerCreatedOnThisState = true;
    }

    if (ctrlIsInitialized) ctrl?.addListener(_listenOnEnd);
  }

  @override
  void initState() {
    super.initState();
    loadControllerIfNull();
  }

  @override
  void didUpdateWidget(Down4VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("DID UPDATE WIDGET OF VIDEO ID ${widget.media.id}");
  }

  @override
  void dispose() {
    print("DISPOSING STATE OF VIDEO ID ${widget.media.id}");
    if (controllerCreatedOnThisState) ctrl?.dispose();
    if (ctrlIsInitialized) {
      print("REMOVING LISTEN ON END OF VIDEO ID ${widget.media.id}");
      ctrl!.removeListener(_listenOnEnd);
    }
    if (mounted) super.dispose();
  }

  bool loading = false;

  void startTurning() {
    timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        turns += 2 * math.pi / 10;
        turns = turns % (2 * math.pi);
      });
    });
  }

  Future<void> _initController() async {
    setState(() {
      loading = true;
    });
    await ctrl?.initialize();
    timer?.cancel();
    ctrl?.addListener(_listenOnEnd);
    setState(() {
      loading = false;
    });
  }

  Future<void> _pauseOrPlay() async {
    if (isPlaying) {
      await ctrl?.pause();
      await ctrl?.seekTo(Duration.zero);
    } else {
      await ctrl?.play();
    }
    setState(() {});
  }

  Future<void> onTap() async {
    if (!ctrlIsInitialized) {
      startTurning();
      await _initController();
    }
    await _pauseOrPlay();
  }

  void _listenOnEnd() async {
    if (ctrl?.value.duration == ctrl?.value.position && !isPlaying) {
      await ctrl?.seekTo(Duration.zero);
      print("CLOSING VIDEO!");
      setState(() {});
    }
  }

  Widget rotatingLogo(double dimension) {
    return Center(
        child: AnimatedRotation(
      duration: const Duration(seconds: 1),
      turns: turns,
      child: down4Logo(dimension, g.theme.messageSelectionBorderColor),
    ));
  }

  Widget thumbnail() => FireImageDisplay(
      widget.media, widget.displaySize, widget.forceSquareAnyways);

  double get properLogoDimension => widget.displaySize.aspectRatio > 1
      ? widget.displaySize.height / 4
      : widget.displaySize.width / 4;

  Widget playButton() => Center(
      child: SizedBox.square(
          dimension: widget.displaySize.aspectRatio > 1
              ? widget.displaySize.height / 4
              : widget.displaySize.width / 4,
          child: GestureDetector(
              onTap: onTap,
              child: FittedBox(
                  child: Icon(Icons.play_arrow,
                      color: g.theme.messageSelectionBorderColor))
              // Image.asset("assets/images/filled.png", fit: BoxFit.cover)
              )));

  Widget video() => GestureDetector(
      onTap: _pauseOrPlay,
      child: Down4VideoTransform(
          displaySize: widget.displaySize,
          isReversed: widget.media.isReversed,
          isScaled: widget.media.isSquared || widget.forceSquareAnyways,
          video: VideoPlayer(ctrl!),
          videoAspectRatio: widget.media.aspectRatio));

  @override
  Widget build(BuildContext context) {
    print("VIDEO IS PLAYING = $isPlaying");
    if (!ctrlIsInitialized && !loading) {
      return Stack(children: [thumbnail(), playButton()]);
    } else if (!ctrlIsInitialized && loading) {
      return Stack(children: [
        thumbnail(),
        rotatingLogo(properLogoDimension),
      ]);
    } else if (isPlaying) {
      return video();
    } else {
      return Stack(children: [thumbnail(), playButton()]);
    }
  }
}

// class Down4ImageViewer extends StatelessWidget {
//   final FireMedia media;
//   final Size displaySize;
//   final bool forceSquareAnyways;
//   const Down4ImageViewer({
//     required this.media,
//     required this.displaySize,
//     this.forceSquareAnyways = false,
//     Key? key,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final isSquared = media.metadata.isSquared || forceSquareAnyways;
//     final isReversed = media.metadata.isReversed;
//     final aspectRatio = media.metadata.elementAspectRatio;
//     final theImage = media.file != null
//         ? Image.file(media.file!,
//             gaplessPlayback: true,
//             cacheHeight: displaySize.height.toInt() * (isSquared ? 1 : 2),
//             cacheWidth: displaySize.width.toInt() * (isSquared ? 1 : 2),
//             fit: BoxFit.cover)
//         : Image.network(media.url,
//             gaplessPlayback: true,
//             cacheHeight: displaySize.height.toInt() * (isSquared ? 1 : 2),
//             cacheWidth: displaySize.width.toInt() * (isSquared ? 1 : 2),
//             fit: BoxFit.cover);
//     return Down4ImageTransform(
//       displaySize: displaySize,
//       isSquared: isSquared,
//       imageAspectRatio: aspectRatio,
//       isReversed: isReversed,
//       image: theImage,
//     );
//   }
// }

extension ChatMessageExtension on Iterable<ChatMessage> {
  Iterable<ChatMessage> selected() => where((e) => e.selected);
  Iterable<ID> asIDs() => map((e) => e.id);
}

// extension PaletteExtensionsMap on Map<ID, Palette> {
//   Map<ID, Palette> those(List<ID> ids) {
//     var map = <ID, Palette>{};
//     for (final id in ids) {
//       map[id] = this[id]!;
//     }
//     return map;
//   }
// }

// extension PaletteExtensions on Iterable<Palette> {
//   List<Palette> inThatOrder(Iterable<ID> ids) {
//     var theList = <Palette>[];
//     var palIds = asIds();
//     for (final id in ids) {
//       if (palIds.contains(id)) {
//         theList.add(firstWhere((p) => p.node.id == id));
//       }
//     }
//     return theList;
//   }

//   List<Palette> inReversedOrder(Iterable<ID> ids) {
//     var theList = <Palette>[];
//     var palIds = asIds();
//     for (final id in ids.toList(growable: false).reversed) {
//       if (palIds.contains(id)) {
//         theList.add(firstWhere((p) => p.node.id == id));
//       }
//     }
//     return theList;
//   }

//   List<Palette> formatted() => toList(growable: false)
//     ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
//   List<Palette> formattedReverse() => toList(growable: false)
//     ..sort((a, b) => a.node.activity.compareTo(b.node.activity));
//   Iterable<Palette> unfolded() => where((p) => !p.fold);
//   Iterable<Palette> folded() => where((p) => p.fold);
//   Iterable<Palette> deactivated() => map((p) => p.deactivated());
//   Iterable<BaseNode> asNodes<BaseNode>() =>
//       map((p) => p.node).whereType<BaseNode>();
//   Iterable<Palette> selected() => where((p) => p.selected);
//   Iterable<Palette> notSelected() => where((p) => !p.selected);
//   Iterable<ID> asIds() => map((e) => e.node.id);
//   Iterable<Palette> chatables() => where((p) => p.node is Chatable);
//   Iterable<Palette> users() => where((p) => p.node is User);
//   Iterable<Palette> people() => where((p) => p.node is Personable);
//   Iterable<Palette> groups() => where((p) => p.node is Groupable);
//   Iterable<Palette> those(Iterable<ID> ids) =>
//       where((p) => ids.contains(p.node.id));
//   Iterable<Palette> notThose(Iterable<ID> ids) =>
//       where((p) => !ids.contains(p.node.id));
//   Iterable<Palette> forwardables() =>
//       where((p) => p.node.isPublicGroup || p.node is User);
// }

extension MapHelpers on Map<ID, Palette2> {
  Iterable<Palette2?> those(Iterable<ID> ids) sync* {
    for (final id in ids) {
      yield this[id];
    }
  }
}

extension NonNullPalettes on Iterable<Palette2?> {
  Iterable<Palette2> noNull() => whereType<Palette2>();
}

extension Palette2Extensions on List<Palette2> {
  List<Palette2> formattedReverse() => toList(growable: false)
    ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  List<Palette2> formatted() => toList(growable: false)
    ..sort((a, b) => a.node.activity.compareTo(b.node.activity));
}

extension IterablePalette2Extensions on Iterable<Palette2> {
  Iterable<Palette2> deactivated() => map((p) => p.deactivated());
  Iterable<Palette2> selected() => where((element) => element.selected);
  Iterable<Palette2> notSelected() => where((p) => !p.selected);
  Iterable<Palette2> whereNodeIsNot<T extends FireNode>() =>
      where((p) => p.node is! T);
  Iterable<Palette2> whereNodeIs<T extends FireNode>() =>
      where((p) => p.node is T);

  Iterable<Palette2> showing() => where((p) => p.show);
  Iterable<Palette2> hidden() => where((p) => !p.show);
  Iterable<ID> asIds() => map((e) => e.node.id);
  Iterable<BaseNode> asNodes<BaseNode>() =>
      map((p) => p.node).whereType<BaseNode>();
  Iterable<Palette2> those(Iterable<ID> ids) =>
      where((p) => ids.contains(p.node.id));
  Iterable<Palette2> notThose(Iterable<ID> ids) =>
      where((p) => !ids.contains(p.node.id));
  List<Palette2> inThatOrder(Iterable<ID> ids) {
    var theList = <Palette2>[];
    var palIds = asIds();
    for (final id in ids) {
      if (palIds.contains(id)) {
        theList.add(firstWhere((p) => p.node.id == id));
      }
    }
    return theList;
  }

  List<Palette2> inReversedOrder(Iterable<ID> ids) {
    var theList = <Palette2>[];
    var palIds = asIds();
    for (final id in ids.toList(growable: false).reversed) {
      if (palIds.contains(id)) {
        theList.add(firstWhere((p) => p.node.id == id));
      }
    }
    return theList;
  }

  Set<ID> allPeopleIds() {
    Set<ID> ids = {};
    for (final node in asNodes()) {
      if (node is Groupable) {
        ids.addAll(node.group);
      } else if (node is Personable) {
        ids.add(node.id);
      }
    }
    return ids;
  }
}

extension ImageOfNodes on FireNode {
  Widget nodeImage([Size? s]) => FireNodeImageDisplay(this, s);

  // cache<FireMedia>(mediaID)?.displayImage(
  //     displaySize: Size.square(Palette.paletteHeight * 2),
  //     forceSquare: true) ??
  // defaultNodeImage;

//   Widget get transformedImage {
//     if (media != null) {
//       return Down4ImageTransform(
//           image: nodeImage,
//           imageAspectRatio: media!.metadata.elementAspectRatio,
//           displaySize: Size.square(Palette.paletteHeight),
//           isSquared: true,
//           isReversed: media!.metadata.isReversed);
//     } else {
//       return nodeImage;
//     }
//   }

  Widget? get iconPlaceHolder {
    final node = this;
    if (this is NodeTheme) {
      return down4Logo(
        Palette2.paletteHeight,
        g.theme.down4IconForPaletteColor,
      );
    }
    return null;
  }

  Image defaultNodeImage([Size? s]) {
    final n = this;
    if (n is User) {
      return Image.asset('assets/images/hashirama.jpg',
          fit: BoxFit.cover,
          cacheHeight: s?.height.toInt() ?? Palette.paletteHeight.toInt(),
          cacheWidth: s?.width.toInt() ?? Palette.paletteHeight.toInt());
      // n.media != null
      // ? Image.memory(n.media!.data,
      //     fit: BoxFit.cover,
      //     gaplessPlayback: true,
      //     cacheHeight: (Palette.paletteHeight * 3).toInt(),
      //     cacheWidth: (Palette.paletteHeight * 3).toInt())
      // :
    } else if (n is Groupable) {
      return Image.asset('assets/images/hashirama.jpg',
          fit: BoxFit.cover,
          cacheHeight: s?.height.toInt() ?? Palette.paletteHeight.toInt(),
          cacheWidth: s?.width.toInt() ?? Palette.paletteHeight.toInt());
    } else if (n is Payment) {
      return n.payment.independentGets < 2000000
          ? g.d1
          : n.payment.independentGets < 10000000
              ? g.d2
              : g.d3;
    } else if (n is Self) {
      return Image.asset('assets/images/hashirama.jpg',
          fit: BoxFit.cover,
          cacheHeight: s?.height.toInt() ?? Palette.paletteHeight.toInt(),
          cacheWidth: s?.width.toInt() ?? Palette.paletteHeight.toInt());
    } else if (n is NodeTheme) {
      return g.lg;
    }
    throw 'stop breaking my app';
  }
}

class NoGlow extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
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
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => isDown = true),
      onTapUp: (_) => setState(() => isDown = false),
      onTapCancel: () => setState(() => isDown = false),
      onTap: widget.onPress,
      onLongPress: widget.onLongPress,
      onLongPressUp: widget.onLongPressUp,
      child: Opacity(
        opacity: isDown || widget.shouldBeDownButIsnt ? widget.opacity : 1,
        child: widget.child,
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
  final bool isReversed, isScaled;

  const Down4VideoTransform({
    required this.displaySize,
    required this.videoAspectRatio,
    required this.video,
    required this.isReversed,
    required this.isScaled,
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
          scaleY: isScaled && videoAspectRatio > 1 ? videoAspectRatio : null,
          scaleX: isScaled && videoAspectRatio < 1 ? videoAspectRatio : null,
          scale: !isScaled || videoAspectRatio == 1 ? 1.0 : null,
          child: Transform.scale(
            scale:
                isScaled && videoAspectRatio != 1 ? 1 / videoAspectRatio : 1.0,
            child: SizedBox.fromSize(size: displaySize, child: video),
          ),
        ),
      ),
    );
  }
}

// class Down4VideoTransform2 extends StatelessWidget {
//   final Size displaySize;
//   final double videoAspectRatio;
//   final BetterPlayer video;
//   final bool isReversed, isSquared;

//   const Down4VideoTransform2({
//     required this.displaySize,
//     required this.videoAspectRatio,
//     required this.video,
//     required this.isReversed,
//     required this.isSquared,
//     Key? key,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return ClipRect(
//       clipper: MediaSizeClipper(displaySize),
//       child: Transform(
//         alignment: Alignment.center,
//         transform: Matrix4.rotationY(isReversed ? math.pi : 0),
//         child: Transform.scale(
//             scaleY: isSquared && videoAspectRatio > 1 ? videoAspectRatio : null,
//             scaleX: isSquared && videoAspectRatio <= 1
//                 ? 1 / videoAspectRatio
//                 : null,
//             scale: !isSquared ? 1.0 : null,
//             child: SizedBox.fromSize(size: displaySize, child: video)),
//       ),
//     );
//   }
// }

Future<Size> decodeImageSize(Uint8List d) async {
  final decodedImage = await decodeImageFromList(d);
  return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
}

Future<List<String>> randomPrompts(int qty) async {
  const String adjPath = "assets/texts/descriptive_adjectives.txt";
  const String nounsPath = "assets/texts/concrete_nouns.txt";
  final adjectives = (await rootBundle.loadString(adjPath)).split('\n');
  final nouns = (await rootBundle.loadString(nounsPath)).split('\n');

  final r = math.Random();
  return List<String>.generate(qty, (_) {
    final i = r.nextInt(adjectives.length);
    final j = r.nextInt(nouns.length);
    final adjective = adjectives[i].trim();
    final noun = nouns[j].trim();
    return "$adjective $noun";
  });
}

Future<void> clearAppCache() async {
  var tempDir = await getTemporaryDirectory();
  Directory(tempDir.path).delete(recursive: true);
}

Future<FireMedia?> importNodeMedia() async {
  final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: imageExtensions,
      allowMultiple: false,
      allowCompression: true,
      withData: true);
  if (result == null) return null;
  final bytes = result.files.single.bytes;
  final mediaID = deterministicMediaID(bytes!, g.self.id);
  final size = await decodeImageSize(bytes);
  final mime = lookupMimeType(result.files.single.path!)!;
  return FireMedia(mediaID,
      mime: mime,
      tinyThumbnail: makeTiny(bytes),
      isSquared: true,
      ownerID: g.self.id,
      timestamp: makeTimestamp(),
      width: size.width,
      height: size.height);
}

Uint8List resizeImage(Uint8List bytes, int width, [int? height]) {
  IMG.Image? img = IMG.decodeImage(bytes);
  IMG.Image resized = IMG.copyResize(img!, width: width, height: height);
  return Uint8List.fromList(IMG.encodePng(resized));
}

String makeTiny(Uint8List bytes) {
  IMG.Image? img = IMG.decodeImage(bytes);
  IMG.Image resized = IMG.copyResize(img!, width: 20);
  final d = Uint8List.fromList(IMG.encodeGif(resized));
  return base64Encode(d);
}

Future<void> importConsoleMedias({
  required bool images,
  required VoidCallback reload, // will reload console and show the media
}) async {
  if (images) {
    final results = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: imageExtensions,
        allowMultiple: true,
        allowCompression: true,
        withData: true);
    if (results == null) return;
    for (final image in results.files) {
      if (image.path == null || image.bytes == null) continue;
      final mediaID = deterministicMediaID(image.bytes!, g.self.id);
      final size = await decodeImageSize(image.bytes!);
      final mime = lookupMimeType(image.path!)!;
      final tiny = makeTiny(image.bytes!);
      final media = FireMedia(mediaID,
          isSaved: true,
          isSquared: false,
          isReversed: false,
          mime: mime,
          tinyThumbnail: tiny,
          timestamp: makeTimestamp(),
          ownerID: g.self.id,
          width: size.width,
          height: size.height);
      await media.write(imageData: image.bytes!);
      reload();
    }
  } else {
    final videos = await FilePicker.platform.pickFiles(
        allowedExtensions: videoExtensions,
        type: FileType.custom,
        withData: true,
        allowCompression: true,
        allowMultiple: true);
    if (videos == null) return;
    for (final video in videos.files) {
      if (video.path == null || video.bytes == null) continue;
      final videoInfoGetter = FlutterVideoInfo();
      final videoInfo = await videoInfoGetter.getVideoInfo(video.path!);
      final mediaID = deterministicMediaID(video.bytes!, g.self.id);
      final mime = lookupMimeType(video.path!)!;
      final tn = await VideoThumbnail.thumbnailData(
        video: video.path!,
        quality: 80,
      );
      final tiny = makeTiny(tn!);
      final media = FireMedia(mediaID,
          mime: mime,
          tinyThumbnail: tiny,
          isReversed: false,
          isSquared: false,
          isSaved: true,
          timestamp: makeTimestamp(),
          ownerID: g.self.id,
          width: videoInfo?.width?.toDouble() ?? 1.0,
          height: videoInfo?.height?.toDouble() ?? 1.0);
      await File(media.videoPath).writeAsBytes(video.bytes!);
      await media.write(imageData: tn);
      reload();
    }
  }
}
