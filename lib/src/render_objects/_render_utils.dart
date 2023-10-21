import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;

// import 'package:down4/src/web_requests.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart' as exif;

import 'package:flutter/services.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';

import '../data_objects/couch.dart' show cache, savedMediaIDs;
import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../data_objects/nodes.dart';
import '../themes.dart';
import 'palette.dart';

import 'chat_message.dart' show ChatMessage;
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:file_picker/file_picker.dart';
import '../globals.dart';

import 'package:flutter/foundation.dart';

mixin Down4Widget on Down4Object, Widget {}

mixin Down4SelectionWidget on Down4Widget {
  bool get selected;
  void Function()? get select;
  Down4Widget invertedSelection();
}

extension InvertedSize on Size {
  Size get inverted => Size(height, width);
}

class ImageRendererWidget extends SingleChildRenderObjectWidget {
  final ui.Image image;
  final Size s;

  const ImageRendererWidget({
    required this.image,
    required this.s,
    Key? key,
  }) : super(key: key);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return ImageRendererObject(image, s.width, s.height);
  }
}

class ImageRendererObject extends RenderBox {
  final ui.Image _image;
  final double _width;
  final double _height;

  ImageRendererObject(this._image, this._width, this._height);

  @override
  void performLayout() {
    size = Size(_width, _height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final srcRect =
        Rect.fromLTWH(0, 0, _image.width.toDouble(), _image.height.toDouble());
    final destRect = Rect.fromLTWH(offset.dx, offset.dy, _width, _height);
    canvas.drawImageRect(_image, srcRect, destRect, Paint());
  }
}

extension MediaDisplay on Down4Media {
  // Widget displayImage_({
  //   required String key,
  //   required Size s,
  //   bool forceSquare = false,
  // }) {
  //   final cachedVal = ImageCacheManager().cachedImage(key);
  //   if (cachedVal != null) {
  //     print("image is cached bro, ez pz loading");
  //     return cachedVal;
  //     //return ImageRendererWidget(image: cachedVal, s: s);
  //   }
  //   print("image is not cached bro, need to load");
  //   return FutureBuilder(
  //       future: ImageCacheManager()
  //           .loadImageFromFile(this as Down4Image, key: key, ds: s),
  //       builder: (ctx, snp) {
  //         final data = snp.data;
  //         final state = snp.connectionState;
  //         if (state != ConnectionState.done || data == null) {
  //           return SizedBox.fromSize(size: s);
  //         } else {
  //           return data; //ImageRendererWidget(image: data, s: s);
  //         }
  //       });
  // }

  Widget display({
    required Size size,
    Key? key,
    bool forceSquare = false,
    VideoPlayerController? controller,
    bool autoPlay = false,
    RawImage? rawThumbnail,
  }) {
    if (this is Down4Video) {
      print("auto play video: $autoPlay");
      return _Down4VideoPlayer(
          key: key,
          videoController: controller,
          backgroundColor: Colors.black45,
          media: this as Down4Video,
          rawThumbnail: rawThumbnail,
          autoPlay: autoPlay,
          displaySize: size);
    } else {
      return Down4ImageViewer(this as Down4Image,
          key: key, displaySize: size, forceSquareAnyways: forceSquare);
    }
  }

  Future<Widget> displaySnip({
    required BuildContext context,
    VideoPlayerController? controller,
  }) async {
    double scale = g.sizes.fullAspectRatio / aspectRatio;
    if (this is Down4Video) {
      return _Down4VideoPlayer(
          videoController: controller,
          backgroundColor: g.theme.backGroundColor,
          media: this as Down4Video,
          autoPlay: true,
          displaySize: g.sizes.fullSize);
    } else {
      final image = this as Down4Image;
      final media = image.readySnipImage() ?? await image.futureSnipImage();
      if (media == null) return const SizedBox.shrink();
      await precacheImage(media.image, context);
      return Center(
          child: Transform.flip(
              flipX: image.isReversed,
              child: Transform.scale(
                  // I only really know if 1 of these works tbh
                  scale: scale > 1 ? scale : 1 / scale,
                  child: media)));
    }
  }
}

Widget down4Logo(double dimension, Color color) {
  return Center(
      child: SizedBox.square(
    dimension: dimension,
    child: FittedBox(child: Icon(Down4Icon.down4Inverted, color: color)),
  ));
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
  String get id;
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
  State<Down4Input> createState() => _Down4InputState();
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

class _Down4MediaViewer extends StatefulWidget {
  final ComposedID id;
  final Size displaySize;
  final bool forceSquareAnyways;
  const _Down4MediaViewer(this.id,
      {required this.displaySize, this.forceSquareAnyways = false, Key? key})
      : super(key: key);

  @override
  State<_Down4MediaViewer> createState() => _Down4MediaViewerState();
}

class _Down4MediaViewerState extends State<_Down4MediaViewer> {
  late Down4Media? m = cache<Down4Media>(widget.id);

  @override
  Widget build(BuildContext context) {
    if (m == null) return const SizedBox.shrink();
    if (m is Down4Video) {
      return _Down4VideoPlayer(
          videoController: null,
          backgroundColor: g.theme.backGroundColor,
          media: m as Down4Video,
          autoPlay: false,
          displaySize: widget.displaySize,
          forceSquareAnyways: widget.forceSquareAnyways);
    } else {
      return Down4ImageViewer(m as Down4Image,
          displaySize: widget.displaySize,
          forceSquareAnyways: widget.forceSquareAnyways);
    }
  }
}

class Down4RotatingLogo extends StatefulWidget {
  final double dimension;
  const Down4RotatingLogo(this.dimension, {super.key});

  @override
  State<Down4RotatingLogo> createState() => _Down4RotatingLogoState();
}

class _Down4RotatingLogoState extends State<Down4RotatingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (golden * 1000).toInt()),
  )..repeat();

  final twn = Tween<double>(begin: 0.0, end: 1.0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
        turns: twn.animate(_controller),
        child: down4Logo(
            widget.dimension, g.theme.down4IconForLoadingScreenColor));
  }
}

// class Down4RotatingLogo extends StatelessWidget {
//   final double dimension;
//   const Down4RotatingLogo(this.dimension, {super.key});
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedRotation(
//         turns: 0.1,
//         duration: const Duration(hours: 1),
//         child: down4Logo(dimension, g.theme.down4IconForLoadingScreenColor));
//   }
// }

class Down4ImageViewer extends StatefulWidget {
  final Down4Image image;
  final Size displaySize;
  final bool forceSquareAnyways;
  const Down4ImageViewer(
    this.image, {
    required this.displaySize,
    this.forceSquareAnyways = false,
    Key? key,
  }) : super(key: key);

  @override
  State<Down4ImageViewer> createState() => _Down4ImageViewerState();
}

class _Down4ImageViewerState extends State<Down4ImageViewer> {
  late Image? im = widget.image.readyImage(
    widget.displaySize,
    forceSquare: widget.forceSquareAnyways,
  );

  @override
  void initState() {
    super.initState();
    if (im == null) loadFutureImage();
  }

  Widget? transformed() {
    if (im == null) return null;
    return Transform.flip(flipX: widget.image.isReversed, child: im!);
  }

  Future<void> loadFutureImage() async {
    im = await widget.image.futureImage(widget.displaySize,
        forceSquare: widget.forceSquareAnyways);
    setState(() {});
  }

  double get w => widget.displaySize.width;
  double get h => widget.displaySize.height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: w,
        height: h,
        child: transformed() ?? Down4RotatingLogo(math.min(w, h) / 2.0));

    // Stack(
    //   fit: StackFit.expand,
    //   alignment: AlignmentDirectional.center,
    //   children: [
    //     widget.image.tinyImage(widget.displaySize,
    //             forceSquare: widget.forceSquareAnyways) ??
    //         const SizedBox.shrink(),
    //     AnimatedOpacity(
    //       curve: Curves.easeInExpo,
    //       duration: const Duration(milliseconds: 200),
    //       opacity: im == null ? 0 : 1,
    //       //|| !ImageCache().containsKey(im!.key!) ? 0 : 1,
    //       child: tranformed() ?? const SizedBox.shrink(),
    //     ),
    //   ],
    // ),
  }
}

class _Down4VideoPlayer extends StatefulWidget {
  final VideoPlayerController? videoController;
  final Down4Video media;
  final Color backgroundColor;
  final Size displaySize;
  final bool forceSquareAnyways, autoPlay;
  final RawImage? rawThumbnail;
  const _Down4VideoPlayer({
    required this.videoController,
    required this.backgroundColor,
    required this.media,
    required this.autoPlay,
    required this.displaySize,
    this.rawThumbnail,
    this.forceSquareAnyways = false,
    Key? key,
  }) : super(key: key);

  @override
  State<_Down4VideoPlayer> createState() => _Down4VideoPlayerState();
}

class _Down4VideoPlayerState extends State<_Down4VideoPlayer> {
  bool controllerCreatedOnThisState = false;
  double turns = 0.0;
  Timer? timer;
  late VideoPlayerController? ctrl = widget.videoController;

  bool get ctrlIsInitialized => ctrl?.value.isInitialized ?? false;

  bool get isPlaying => ctrl?.value.isPlaying ?? false;

  Future<void> loadControllerIfNull() async {
    if (ctrl == null) {
      ctrl = widget.media.newReadyController() ??
          (await widget.media.futureController());
      controllerCreatedOnThisState = true;
    }

    if (ctrlIsInitialized) ctrl?.addListener(_listenOnEnd);
    if (widget.autoPlay) {
      print("auto playing video");
      await ctrl?.initialize();
      await ctrl?.setLooping(true);
      await ctrl?.play();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadControllerIfNull();
  }

  @override
  void didUpdateWidget(_Down4VideoPlayer oldWidget) {
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

  // void startTurning() {
  //   timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
  //     setState(() {
  //       turns += 2 * math.pi / 10;
  //       turns = turns % (2 * math.pi);
  //     });
  //   });
  // }

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
      // startTurning();
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

  // Widget rotatingLogo(double dimension) {
  //   return Center(
  //       child: AnimatedRotation(
  //     duration: const Duration(seconds: 1),
  //     turns: turns,
  //     child: down4Logo(dimension, g.theme.messageSelectionBorderColor),
  //   ));
  // }

  Widget thumbnail() {
    if (widget.rawThumbnail != null) {
      return Transform.flip(
          flipX: widget.media.isReversed, child: widget.rawThumbnail!);
    } else if (widget.media.thumbnailFile != null) {
      return SizedBox(
          height: widget.displaySize.height,
          width: widget.displaySize.width,
          child: widget.media.thumbnail(widget.displaySize));
    } else {
      return const SizedBox.shrink();
    }
  }

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
                      color: g.theme.messageSelectionBorderColor)))));

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
    if (widget.rawThumbnail != null) {
      return thumbnail();
    } else if (!ctrlIsInitialized && widget.autoPlay) {
      return const SizedBox.shrink();
    } else if (!ctrlIsInitialized && !loading) {
      return Stack(children: [thumbnail(), playButton()]);
    } else if (!ctrlIsInitialized && loading) {
      return Stack(children: [
        thumbnail(),
        Down4RotatingLogo(properLogoDimension)
        // rotatingLogo(properLogoDimension),
      ]);
    } else if (isPlaying) {
      return video();
    } else {
      return Stack(children: [thumbnail(), playButton()]);
    }
  }
}

extension Down4ObjectExtension<T extends Down4Object> on Iterable<T> {
  Iterable<Down4ID> d4IDs() => map((e) => e.id);
  Iterable<ComposedID> cpIDs() => map((e) => e.id).whereType<ComposedID>();
  Iterable<T> ids() => map((e) => e.id).whereType<T>();
  Iterable<T> wType() => whereType<T>();
  Iterable<ChatMessage> chatMsgs() => whereType<ChatMessage>();
  Iterable<Palette> palettes() => whereType<Palette>();
  Iterable<E> selectable<E extends Down4SelectionWidget>() => whereType<E>();  
}


extension Down4ObjectSelectionExtension<T extends Down4SelectionWidget> on Iterable<T> {
  Iterable<T> selected() => where((e) => e.selected);
  Iterable<T> notSelected() => where((e) => !e.selected);
}

extension Down4WidgetIterables on Iterable<Down4Widget> {
  Iterable<ChatMessage> messages() => whereType<ChatMessage>();
  Iterable<Palette> palettes() => whereType<Palette>();
  Iterable<Down4ID> asIDs() => map((e) => e.id);
  Iterable<ComposedID> asComposedIDs() =>
      map((e) => e.id).whereType<ComposedID>();
}

extension MapHelpers on Map<Down4ID, Down4Widget> {
  Iterable<Down4Widget?> those(Iterable<Down4ID> ids) sync* {
    for (final id in ids) {
      yield this[id];
    }
  }
}

extension NonNullObjects on Iterable<Down4Widget?> {
  Iterable<Down4Widget> noNull() => whereType<Down4Widget>();
}

extension Palette2Extensions on Iterable<Palette> {
  List<Palette> formattedReverse() => toList(growable: false)
    ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  List<Palette> formatted() => toList(growable: false)
    ..sort((a, b) => a.node.activity.compareTo(b.node.activity));
}

extension IterablePalette2Extensions<E extends PaletteN> on Iterable<Palette<E>> {
  // Iterable<Palette> deactivated() => map((p) => p.deactivated());
  Iterable<Palette<E>> selected() => where((element) => element.selected);
  Iterable<Palette<E>> notSelected() => where((p) => !p.selected);
  Iterable<Palette<E>> whereNodeIsNot<T extends Down4Node>() =>
      where((p) => p.node is! T);
  Iterable<Palette<T>> whereNodeIs<T extends PaletteN>() =>
      where((p) => p.node is T).cast();

  Iterable<Palette> showing() => where((p) => p.show);
  Iterable<Palette> hidden() => where((p) => !p.show);
  // Iterable<Down4ID> asIDs() => map((e) => e.node.id);
  // Iterable<ComposedID> asComposedIDs() => asIDs().whereType<ComposedID>();

  Iterable<K> asNodes<K extends E>() => map((p) => p.node).whereType<K>();
  Iterable<K> asNodesCast<K extends PaletteN>() => map((p) => p.node).whereType<K>();  
  Iterable<Palette> those(Iterable<Down4ID> ids) =>
      where((p) => ids.contains(p.node.id));
  Iterable<Palette> notThose(Iterable<Down4ID> ids) =>
      where((p) => !ids.contains(p.node.id));
  List<Palette> inThatOrder(Iterable<Down4ID> ids) {
    var theList = <Palette>[];
    var palIds = asIDs();
    for (final id in ids) {
      if (palIds.contains(id)) {
        theList.add(firstWhere((p) => p.node.id == id));
      }
    }
    return theList;
  }

  List<Palette> inReversedOrder(Iterable<Down4ID> ids) {
    var theList = <Palette>[];
    var palIds = asIDs();
    for (final id in ids.toList(growable: false).reversed) {
      if (palIds.contains(id)) {
        theList.add(firstWhere((p) => p.node.id == id));
      }
    }
    return theList;
  }

  Set<Down4ID> allPeopleIds() {
    Set<Down4ID> ids = {};
    for (final node in asNodes()) {
      if (node is GroupN) {
        ids.addAll(node.members);
      } else if (node is PersonN) {
        ids.add(node.id);
      }
    }
    return ids;
  }
}

extension ImageOfNodes on PaletteN {
  Widget nodeImage([Size? s]) {
    if (mediaID == null) return defaultNodeImage(s);
    return _Down4MediaViewer(mediaID!,
        displaySize: s ?? Size.square(Palette.paletteHeight));
  }

  Widget? get iconPlaceHolder {
    if (this is NodeTheme) {
      return down4Logo(
        Palette.paletteHeight,
        g.theme.down4IconForPaletteColor,
      );
    }
    return null;
  }

  Widget defaultNodeImage([Size? s]) {
    final n = this;
    if (n is PersonN) {
      return Image.asset('assets/images/hashirama.jpg',
          fit: BoxFit.cover,
          cacheHeight: s?.height.toInt() ?? Palette.paletteHeight.toInt(),
          cacheWidth: s?.width.toInt() ?? Palette.paletteHeight.toInt());
    } else if (n is GroupN) {
      return Image.asset('assets/images/hashirama.jpg',
          fit: BoxFit.cover,
          cacheHeight: s?.height.toInt() ?? Palette.paletteHeight.toInt(),
          cacheWidth: s?.width.toInt() ?? Palette.paletteHeight.toInt());
    } else if (n is PaymentNode) {
      if (n.payment.independentGets < 2000000) {
        return g.d1;
      } else if (n.payment.independentGets < 10000000) {
        return g.d2;
      } else {
        return g.d3;
      }
    } else if (n is NodeTheme) {
      final double dim = s?.height ?? Palette.paletteHeight;
      return down4Logo(dim, g.theme.down4IconForPaletteColor);
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
  State<TouchableOpacity> createState() => _TouchableOpacityState();
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

Future<Down4Image?> importNodeMedia() async {
  final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: imageExtensions,
      allowMultiple: false,
      allowCompression: true,
      withData: true);
  if (result == null) return null;
  final bytes = result.files.single.bytes;
  final size = await decodeImageSize(bytes!);
  final mime = lookupMimeType(result.files.single.path!)!;
  return Down4Image(ComposedID(),
      metadata: Down4MediaMetadata(
          ownerID: g.self.id,
          timestamp: makeTimestamp(),
          width: size.width,
          height: size.height,
          isSquared: true,
          mime: mime));
  // tinyThumbnail: makeTiny(bytes));
}

Uint8List resizeImage(Uint8List bytes, int width, [int? height]) {
  img.Image? image = img.decodeImage(bytes);
  img.Image resized = img.copyResize(image!, width: width, height: height);
  return Uint8List.fromList(img.encodePng(resized));
}

String makeTiny(Uint8List bytes) {
  img.Image? image = img.decodeImage(bytes);
  img.Image resized = img.copyResize(image!, width: 20);
  final d = Uint8List.fromList(img.encodeGif(resized));
  return base64Encode(d);
}

Future<void> importConsoleMedias({required VoidCallback reload}) async {
  final results = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extMap.values.expand((l) => l).toList(),
      allowMultiple: true,
      allowCompression: true,
      withData: true);
  for (final r in results?.files ?? <PlatformFile>[]) {
    final mime = lookupMimeType(r.path!)!;
    final t = mimeMap.keyWhere((v) => v.contains(mime));
    if (t == null) {
      throw "ERROR: mime=$mime isn't valid!";
    } else {
      print("Found media with type=${t.name}, mime=$mime");
    }
    Size size;
    if ([MediaType.images, MediaType.gifs].contains(t)) {
      size = await decodeImageSize(r.bytes!);
    } else if (t == MediaType.videos) {
      final videoInfoGetter = FlutterVideoInfo();
      final videoInfo = await videoInfoGetter.getVideoInfo(r.path!);
      size = Size(videoInfo?.width?.toDouble() ?? 1.0,
          videoInfo?.height?.toDouble() ?? 1.0);
    } else {
      throw 'unsupported media type=$t';
    }

    final m = Down4Media.fromLocal(ComposedID(),
        mainCachedPath: r.path!,
        isSaved: true,
        metadata: Down4MediaMetadata(
            ownerID: g.self.id,
            timestamp: makeTimestamp(),
            width: size.width,
            height: size.height,
            mime: mime))
      ..cache()
      ..merge()
      ..writeFromCachedPath();

    g.savedMediasIDs[m.type] = savedMediaIDs(m.type).toList();
    reload();
  }
}

Future<void> cropAndSaveToSquare(
    {required File from, required File to, int size = 512}) async {
  img.Image? ogImage = img.decodeImage(await from.readAsBytes());
  print(
      "\n====================\nCROP AND SAVE TO SQUARE\n====================\n");
  if (ogImage == null) return;

  // get the exif metadata for orientation tag
  final xd = await exif.readExifFromFile(from);
  print("============EXIF PRE RESIZE============");
  for (final e in xd.entries) {
    print("${e.key} : ${e.value} (tag=${e.value.tag})");
  }

  final int idRot = xd["Image Orientation"]?.tag ?? 1;

  // do the resize of the image
  final minSize = math.min(ogImage.height, ogImage.width);
  final resize = size > minSize ? minSize : size;
  final cropRz = img.copyResizeCropSquare(ogImage, resize);

  // final rz = img.copyResize(ogImage);

  // img.Image res;
  // switch (idRot) {
  //   case 1:
  //     res = cropRz;
  //     print("straight");
  //     break;
  //   case 2:
  //     res = img.flipHorizontal(cropRz);
  //     print("straight mirrored");
  //     break;
  //   case 3:
  //     res = img.flipVertical(cropRz);
  //     print("flipped");
  //     break;
  //   case 4:
  //     res = img.flipHorizontal(img.flipVertical(cropRz));
  //     print("flipped mirrored");
  //     break;
  //   case 5:
  //     res = img.flipHorizontal(img.copyRotate(cropRz, 270));
  //     print("90-CW mirrored");
  //     break;
  //   case 6:
  //     res = img.copyRotate(cropRz, 270);
  //     print("90-CW");
  //     break;
  //   case 7:
  //     res = img.flipHorizontal(img.copyRotate(cropRz, 90));
  //     print("90 mirrored");
  //     break;
  //   case 8:
  //     res = img.copyRotate(cropRz, 90);
  //     print("90");
  //     break;
  //   default:
  //     throw "error: $idRot is not a valid Image Orientation tag";
  // }

  final xd_ = await exif.readExifFromBytes(cropRz.data);
  print("============EXIF POST RESIZE============");
  for (final e in xd_.entries) {
    print("${e.key} : ${e.value}");
  }
  await to.writeAsBytes(img.encodeJpg(cropRz));
}

// Future<ui.Image?> cropBitmapToSquare(Uint8List originalBytes) async {
//   try {
//     final ui.Codec codec = await ui.instantiateImageCodec(originalBytes);
//     final ui.Image image = (await codec.getNextFrame()).image;
//     final int size = image.width < image.height ? image.width : image.height;

//     final recorder = ui.PictureRecorder();
//     final canvas = Canvas(recorder);
//     canvas.drawImageRect(
//       image,
//       Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
//       Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
//       Paint(),
//     );

//     final picture = recorder.endRecording();
//     return picture.toImage(size, size);
//   } catch (e) {
//     print('Error while cropping bitmap: $e');
//     return null;
//   }
// }

Future<Uint8List?> applyCircularMask(ui.Image image) async {
  final byteData = await image.toByteData();
  final bytes = byteData?.buffer.asUint8List();

  try {
    final int size = image.width;

    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      paint,
    );

    final picture = recorder.endRecording();
    final pictureImage = await picture.toImage(size, size);
    final ByteData? byteData =
        await pictureImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  } catch (e) {
    print('Error while applying circular mask: $e');
    return null;
  }
}
