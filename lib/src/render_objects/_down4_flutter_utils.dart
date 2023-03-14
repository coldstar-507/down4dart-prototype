import 'dart:io';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'palette.dart';

import '../data_objects.dart';
import 'chat_message.dart' show ChatMessage;
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../globals.dart';

Image down4Logo(double dimension) {
  return Image.asset(
    "assets/images/down4_inverted.png",
    height: dimension,
    width: dimension,
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
    final ts = TextSpan(text: text, style: ChatMessage.textStyle);
    final ds = TextSpan(text: dateText, style: ChatMessage.globalDateStyle);

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
  // final AnimationController animationController;
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
  double turns = 0.0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (widget.videoController.value.isInitialized) {
      widget.videoController.addListener(_listenOnEnd);
      print("LISTENING ON END OF VIDEO ID ${widget.media.id}");
    }
  }

  @override
  void didUpdateWidget(Down4VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("DID UPDATE WIDGET OF VIDEO ID ${widget.media.id}");
  }

  @override
  void dispose() {
    print("DISPOSING STATE OF VIDEO ID ${widget.media.id}");
    if (widget.videoController.value.isInitialized) {
      print("REMOVING LISTEN ON END OF VIDEO ID ${widget.media.id}");
      widget.videoController.removeListener(_listenOnEnd);
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
    await widget.videoController.initialize();
    widget.videoController.addListener(_listenOnEnd);
    if (widget.autoPlay) {
      widget.videoController
        ..setLooping(true)
        ..play();
    }
    setState(() {
      loading = false;
      timer?.cancel();
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
      startTurning();
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

  // Widget rotatingLogo(double dimension) {
  //   return AnimatedRotation(
  //       turns: math.pi * 2,
  //       duration: const Duration(seconds: 2),
  //       child: down4Logo(dimension));
  // }

  Widget rotatingLogo(double dimension) {
    return AnimatedRotation(
      duration: const Duration(seconds: 1),
      turns: turns,
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
                    child: Image.asset("assets/images/filled.png",
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
      //                             "assets/images/filled.png",
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
                          child: Image.asset("assets/images/filled.png",
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
    print("ar: $imageAspectRatio, ds = $displaySize, squared = $isSquared");
    return ClipRect(
      // clipper: MediaSizeClipper(displaySize),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isReversed ? math.pi : 0),
        child: Transform.scale(
          scaleY: isSquared && imageAspectRatio < 1 ? imageAspectRatio : null,
          scaleX:
              isSquared && imageAspectRatio > 1 ? 1 / imageAspectRatio : null,
          scale: !isSquared || imageAspectRatio == 1 ? 1.0 : null,
          child: Transform.scale(
              scale: isSquared
                  ? imageAspectRatio > 1
                      ? imageAspectRatio
                      : 1 / imageAspectRatio
                  : 1.0,
              child: SizedBox.fromSize(size: displaySize, child: image)),
        ),
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
    final isSquared = media.metadata.isSquared || forceSquareAnyways;
    final isReversed = media.metadata.isReversed;
    final aspectRatio = media.metadata.elementAspectRatio;
    final theImage = media.file != null
        ? Image.file(media.file!,
            gaplessPlayback: true,
            cacheHeight: displaySize.height.toInt() * (isSquared ? 1 : 2),
            cacheWidth: displaySize.width.toInt() * (isSquared ? 1 : 2),
            fit: BoxFit.cover)
        : Image.network(media.url,
            gaplessPlayback: true,
            cacheHeight: displaySize.height.toInt() * (isSquared ? 1 : 2),
            cacheWidth: displaySize.width.toInt() * (isSquared ? 1 : 2),
            fit: BoxFit.cover);
    return Down4ImageTransform(
      displaySize: displaySize,
      isSquared: isSquared,
      imageAspectRatio: aspectRatio,
      isReversed: isReversed,
      image: theImage,
    );
  }
}

extension ChatMessageExtension on Iterable<ChatMessage> {
  Iterable<ChatMessage> selected() => where((e) => e.selected);
  Iterable<ID> asIDs() => map((e) => e.id);
}

extension PaletteExtensionsMap on Map<ID, Palette> {
  Map<ID, Palette> those(List<ID> ids) {
    var map = <ID, Palette>{};
    for (final id in ids) {
      map[id] = this[id]!;
    }
    return map;
  }
}

extension PaletteExtensions on Iterable<Palette> {
  List<Palette> inThatOrder(Iterable<ID> ids) {
    var theList = <Palette>[];
    var palIds = asIds();
    for (final id in ids) {
      if (palIds.contains(id)) {
        theList.add(firstWhere((p) => p.node.id == id));
      }
    }
    return theList;
  }

  List<Palette> inReversedOrder(Iterable<ID> ids) {
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
  Iterable<ID> asIds() => map((e) => e.node.id);
  Iterable<Palette> chatables() => where((p) => p.node is ChatableNode);
  Iterable<Palette> users() => where((p) => p.node is User);
  Iterable<Palette> people() => where((p) => p.node is Person);
  Iterable<Palette> groups() => where((p) => p.node is GroupNode);
  Iterable<Palette> those(Iterable<ID> ids) =>
      where((p) => ids.contains(p.node.id));
  Iterable<Palette> notThose(Iterable<ID> ids) =>
      where((p) => !ids.contains(p.node.id));
  Iterable<Palette> forwardables() =>
      where((p) => p.node.isPublicGroup || p.node is User);
}

extension Palette2Extensions on List<Palette2> {
  List<Palette2> formatted() => toList(growable: false)
    ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  List<Palette2> formattedReverse() => toList(growable: false)
    ..sort((a, b) => a.node.activity.compareTo(b.node.activity));
}

extension IterablePalette2Extensions on Iterable<Palette2> {
  Iterable<Palette2> deactivated() => map((p) => p.deactivated());
  Iterable<Palette2> selected() => where((element) => element.selected);
  Iterable<Palette2> notSelected() => where((p) => !p.selected);
  Iterable<Palette2> whereNodeIsNot<T>() => where((p) => p.node is! T);
  Iterable<Palette2> whereNodeIs<T>() => where((p) => p.node is T);
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
      if (node is GroupNode) {
        ids.addAll(node.group);
      } else if (node is Person) {
        ids.add(node.id);
      }
    }
    return ids;
  }
}

extension ImageOfNodes on BaseNode {
  Widget get transformedImage {
    if (media != null) {
      return Down4ImageTransform(
          image: nodeImage,
          imageAspectRatio: media!.metadata.elementAspectRatio,
          displaySize: Size.square(Palette.paletteHeight),
          isSquared: true,
          isReversed: media!.metadata.isReversed);
    } else {
      return nodeImage;
    }
  }

  Image get nodeImage {
    final n = this;
    if (n is User) {
      return n.media != null
          ? Image.memory(n.media!.data,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheHeight: (Palette.paletteHeight * 3).toInt(),
              cacheWidth: (Palette.paletteHeight * 3).toInt())
          : Image.asset('assets/images/hashirama.jpg',
              fit: BoxFit.cover,
              cacheHeight: Palette.paletteHeight.toInt(),
              cacheWidth: Palette.paletteHeight.toInt());
    } else if (n is GroupNode) {
      return Image.memory(n.media.data,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheHeight: Palette.paletteHeight.toInt() * 3,
          cacheWidth: Palette.paletteHeight.toInt() * 3);
    } else if (n is Payment) {
      return n.payment.independentGets < 2000000
          ? Image.asset('assets/images/Dollar_Sign_1.png',
              fit: BoxFit.cover,
              cacheHeight: Palette.paletteHeight.toInt(),
              cacheWidth: Palette.paletteHeight.toInt())
          : n.payment.independentGets < 10000000
              ? Image.asset('assets/images/Dollar_Sign_2.png',
                  fit: BoxFit.cover,
                  cacheHeight: Palette.paletteHeight.toInt(),
                  cacheWidth: Palette.paletteHeight.toInt())
              : Image.asset('assets/images/Dollar_Sign_3.png',
                  fit: BoxFit.cover,
                  cacheHeight: Palette.paletteHeight.toInt(),
                  cacheWidth: Palette.paletteHeight.toInt());
    } else if (n is Self) {
      return Image.memory(
        n.media.data,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheHeight: Palette.paletteHeight.toInt() * 3,
        cacheWidth: Palette.paletteHeight.toInt() * 3,
      );
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

Future<NodeMedia?> importNodeMedia() async {
  final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: imageExtensions.withoutDots(),
      allowMultiple: false,
      allowCompression: true,
      withData: true);

  if (result == null) return null;
  final bytes = result.files.single.bytes;
  final mediaID = deterministicMediaID(bytes!, g.self.id);
  final size = await decodeImageSize(bytes);
  return NodeMedia(
      data: bytes,
      id: mediaID,
      metadata: MediaMetadata(
          isSquared: true,
          owner: g.self.id,
          timestamp: timeStamp(),
          elementAspectRatio: 1.0 / size.aspectRatio,
          extension: result.files.single.path!.extension()));
}

Future<void> importConsoleMedias({required bool images}) async {
  if (images) {
    final results = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: imageExtensions.withoutDots(),
        allowMultiple: true,
        allowCompression: true,
        withData: true);
    if (results == null) return;
    for (final file in results.files) {
      if (file.path == null && file.bytes != null) continue;
      final mediaID = deterministicMediaID(file.bytes!, g.self.id);
      final size = await decodeImageSize(file.bytes!);
      final f = await writeMedia(mediaData: file.bytes!, mediaID: mediaID);
      MessageMedia(
          id: mediaID,
          isSaved: true,
          path: f.path,
          metadata: MediaMetadata(
              isSquared: false,
              isReversed: false,
              extension: file.path!.extension(),
              timestamp: timeStamp(),
              owner: g.self.id,
              elementAspectRatio: 1.0 / size.aspectRatio))
        ..isSaved = true
        ..save();

      g.self.images.add(mediaID);
    }
  } else {
    final videos = await FilePicker.platform.pickFiles(
        allowedExtensions: videoExtensions.withoutDots(),
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
      final f = await writeMedia(mediaData: video.bytes!, mediaID: mediaID);
      final tn = await VideoThumbnail.thumbnailData(video: f.path, quality: 90);
      String? thumbnailPath;
      if (tn != null) {
        final f = await writeMedia(
            mediaData: tn, mediaID: mediaID, isThumbnail: true);
        thumbnailPath = f.path;
      }

      MessageMedia(
          id: mediaID,
          path: f.path,
          thumbnail: thumbnailPath,
          metadata: MediaMetadata(
              isReversed: false,
              isSquared: false,
              extension: video.path!.extension(),
              timestamp: timeStamp(),
              owner: g.self.id,
              elementAspectRatio:
                  (videoInfo?.width ?? 1.0) / (videoInfo?.height ?? 1.0)))
        ..isSaved = true
        ..save();

      g.self.videos.add(mediaID);
    }
  }
  g.self.save();
}
