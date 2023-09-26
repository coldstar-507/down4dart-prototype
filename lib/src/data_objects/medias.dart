import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:down4/src/data_objects/couch.dart';
import 'package:down4/src/globals.dart';
import 'package:down4/src/pages/_page_utils.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/render_objects/console.dart';
import 'package:down4/src/utils/encrypted_file_image.dart';
import 'package:down4/src/utils/encryption_helper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../_dart_utils.dart';
import '../_dart_utils.dart' as u;

import '_data_utils.dart';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Down4MediaMetadata with Jsons {
  final bool isReversed, isSquared;
  final String mime;
  final bool isEncrypted;
  final ComposedID ownerID;
  final double width, height;
  final String? txt;
  final int timestamp;

  Size get size => Size(width, height);

  double get aspectRatio => size.aspectRatio;

  String get extension => extensionFromMime(mime);

  bool get isVideo => extension.isVideoExtension();

  Down4MediaMetadata({
    required this.ownerID,
    required this.timestamp,
    required this.width,
    required this.height,
    required this.mime,
    this.isEncrypted = false,
    this.isReversed = false,
    this.isSquared = false,
    this.txt,
  });

  Future<Down4MediaMetadata?> userInitRecalculation(
      ComposedID properOwnerID) async {
    final json = toJson();
    json["ownerID"] = properOwnerID.value;
    return Down4MediaMetadata.fromJson(json);
  }

  factory Down4MediaMetadata.fromJson(Map<String, String?> decodedJson) {
    return Down4MediaMetadata(
        ownerID: ComposedID.fromString(decodedJson["ownerID"])!,
        timestamp: int.parse(decodedJson["timestamp"] ?? "0"),
        mime: decodedJson["mime"]!,
        isReversed: decodedJson["isReversed"] == "true",
        isSquared: decodedJson["isSquared"] == "true",
        width: double.parse(decodedJson["width"]!),
        height: double.parse(decodedJson["height"]!),
        txt: decodedJson["txt"]);
  }

  @override
  Map<String, String> toJson() => {
        "ownerID": ownerID.value,
        "timestamp": timestamp.toString(),
        "mime": mime,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isEncrypted": isEncrypted.toString(),
        "width": width.toString(),
        "height": height.toString(),
        if (txt != null) "txt": txt!,
      };
}

abstract class Down4Media with Down4Object, Jsons, Locals, Temps {
  bool _isPaidToView, _isPaidToOwn, _isLocked;
  String? tinyThumbnail, _cachedUrl;
  int _lastUse;
  bool _isSaved;
  Down4MediaMetadata metadata;

  String? mainCachedPath;

  MediaType get type {
    final mime = metadata.mime;
    if (videoMimes.contains(mime)) {
      return MediaType.videos;
    } else if (imageMimes.contains(mime)) {
      return MediaType.images;
    } else if (animatedImageMimes.contains(mime)) {
      return MediaType.images;
    }
    throw "Invalid media type, mime=$mime";
  }

  set cachedUrl(String? u) => _cachedUrl = u;

  @override
  final ComposedID id;
  ComposedID? _tempID;
  int? _tempTS;

  @override
  ComposedID? get tempID => _tempID;

  @override
  int? get tempTS => _tempTS;

  @override
  void updateTempReferences(ComposedID newTempID, int newTempTS) {
    final currentTS = tempTS ?? 0;
    if (currentTS >= newTempTS) return;
    _tempTS = newTempTS;
    _tempID = newTempID;
    merge(vals: {
      "tempTS": _tempTS!.toString(),
      "tempID": _tempID!.value,
    });
  }

  Down4Media(
    this.id, {
    ComposedID? tempID,
    int? tempTS,
    required this.metadata,
    this.tinyThumbnail,
    this.mainCachedPath,
    int lastUse = 0,
    bool isSaved = false,
    bool isPaidToView = false,
    bool isPaidToOwn = false,
    bool isLocked = false,
  })  : _isSaved = isSaved,
        _lastUse = lastUse,
        _tempID = tempID,
        _tempTS = tempTS,
        _isPaidToView = isPaidToView,
        _isPaidToOwn = isPaidToOwn,
        _isLocked = isLocked;

  static Future<Down4Media> fromLocal2(
    ComposedID id, {
    required Down4MediaMetadata metadata,
    required writeFromCachedPath,
    ComposedID? tempID,
    int? tempTS,
    String? tinyThumbnail,
    String? mainCachedPath,
    int lastUse = 0,
    bool isSaved = false,
    bool isPaidToView = false,
    bool isPaidToOwn = false,
    bool isLocked = false,
  }) async {
    if (writeFromCachedPath && mainCachedPath == null) {
      throw ("error: Can't writeFromCache AND have mainCachedPath == null");
    }
    Down4Media media;
    if (metadata.isVideo) {
      media = Down4Video(id,
          metadata: metadata,
          tempTS: tempTS,
          tempID: tempID,
          tinyThumbnail: tinyThumbnail,
          lastUse: lastUse,
          isSaved: isSaved,
          mainCachedPath: mainCachedPath,
          isPaidToView: isPaidToView,
          isPaidToOwn: isPaidToOwn,
          isLocked: isLocked);
    } else {
      media = Down4Image(id,
          metadata: metadata,
          tempTS: tempTS,
          tempID: tempID,
          mainCachedPath: mainCachedPath,
          tinyThumbnail: tinyThumbnail,
          lastUse: lastUse,
          isSaved: isSaved,
          isPaidToView: isPaidToView,
          isPaidToOwn: isPaidToOwn,
          isLocked: isLocked);
    }
    if (writeFromCachedPath) {
      await media.writeFromCachedPath();
    }

    return media;
  }

  // factory Down4Media.fromLocal(
  //   ComposedID id, {
  //   required Down4MediaMetadata metadata,
  //   ComposedID? tempID,
  //   int? tempTS,
  //   String? tinyThumbnail,
  //   String? mainCachedPath,
  //   int lastUse = 0,
  //   bool isSaved = false,
  //   bool isPaidToView = false,
  //   bool isPaidToOwn = false,
  //   bool isLocked = false,
  // }) {
  //   if (metadata.isVideo) {
  //     return Down4Video(id,
  //         metadata: metadata,
  //         tempTS: tempTS,
  //         tempID: tempID,
  //         tinyThumbnail: tinyThumbnail,
  //         lastUse: lastUse,
  //         isSaved: isSaved,
  //         mainCachedPath: mainCachedPath,
  //         isPaidToView: isPaidToView,
  //         isPaidToOwn: isPaidToOwn,
  //         isLocked: isLocked);
  //   } else {
  //     return Down4Image(id,
  //         metadata: metadata,
  //         tempTS: tempTS,
  //         tempID: tempID,
  //         mainCachedPath: mainCachedPath,
  //         tinyThumbnail: tinyThumbnail,
  //         lastUse: lastUse,
  //         isSaved: isSaved,
  //         isPaidToView: isPaidToView,
  //         isPaidToOwn: isPaidToOwn,
  //         isLocked: isLocked);
  //   }
  // }

  bool get isSquared => metadata.isSquared;
  bool get isReversed => metadata.isReversed;
  double get aspectRatio => metadata.aspectRatio;
  Size get size => Size(metadata.width, metadata.height);

  // needs to be Map<String, String> for firebase bucket metadata...
  @override
  Map<String, String> toJson({bool includeLocal = true}) => {
        ...metadata.toJson(),
        "id": id.value,
        "isPaidToView": _isPaidToView.toString(),
        "isPaidToOwn": _isPaidToOwn.toString(),
        "isLocked": _isLocked.toString(),
        if (tinyThumbnail != null) "tinyThumbnail": tinyThumbnail!,
        if (includeLocal) "isSaved": _isSaved.toString(),
        if (includeLocal) "lastUse": _lastUse.toString(),
        if (includeLocal && tempID != null) "tempID": tempID!.value,
        if (includeLocal && tempTS != null) "tempTS": tempTS!.toString(),
      };

  factory Down4Media.fromJson(Map<String, String?> decodedJson) {
    final id = ComposedID.fromString(decodedJson["id"])!;
    final isPaidToView = decodedJson["isPaidToView"] == "true";
    final isPaidToOwn = decodedJson["isPaidToOwn"] == "true";
    final isLocked = decodedJson["isLocked"] == "true";
    final tinyThumbnail = decodedJson["tinyThumbnail"];
    final isSaved = decodedJson["isSaved"] == "true";
    final tempID = ComposedID.fromString(decodedJson["tempID"]);
    final tempTS = int.tryParse(decodedJson["tempTS"] ?? "");

    // metadata is in the same json of the rest, see toJson
    final metadata = Down4MediaMetadata.fromJson(decodedJson);

    if (metadata.isVideo) {
      return Down4Video(id,
          metadata: metadata,
          isSaved: isSaved,
          isLocked: isLocked,
          isPaidToOwn: isPaidToOwn,
          isPaidToView: isPaidToView,
          tinyThumbnail: tinyThumbnail,
          tempID: tempID,
          tempTS: tempTS);
    } else {
      return Down4Image(id,
          metadata: metadata,
          isSaved: isSaved,
          isLocked: isLocked,
          isPaidToOwn: isPaidToOwn,
          isPaidToView: isPaidToView,
          tinyThumbnail: tinyThumbnail,
          tempID: tempID,
          tempTS: tempTS);
    }
  }

  Image? tinyImage(Size s, {bool forceSquare = false}) {
    if (tinyThumbnail == null) return null;
    return Image.memory(base64Decode(tinyThumbnail!),
        fit: BoxFit.cover,
        cacheWidth: (s.width * golden).toInt(),
        cacheHeight: (s.height * golden).toInt());
  }

  String mainPath([String? appDir]) {
    return "${appDir ?? g.appDirPath}${Platform.pathSeparator}${id.unik}";
  }

  File? mainFile([String? appDir]) {
    final f = File(mainPath(appDir));
    if (!f.existsSync()) return null;
    return f;
  }

  File? get mainCachedFile {
    // print("main cached path: $mainCachedPath");
    File? f;
    if (mainCachedPath == null) return null;
    f = File(mainCachedPath!);
    if (!f.existsSync()) return null;
    return f;
  }

  void use() {
    _lastUse = u.makeTimestamp();
    merge(vals: {"lastUse": _lastUse.toString()});
    g.savedMediasIDs[type] = savedMediaIDs(type).toList();
  }

  Future<void> write(Uint8List mainData);

  Future<void> writeFromCachedPath() async {
    final File? f = mainCachedFile;
    if (f != null) {
      if (metadata.isSquared && !metadata.isVideo) {
        const idealSize = 512;
        final to = File(mainPath());
        await cropAndSaveToSquare(from: f, to: to, size: idealSize);
      } else {
        final Uint8List data = f.readAsBytesSync();
        await write(data);
      }
    }
  }

  // in medias, to follow json as Map<String,String> merge values are also str
  void updateSaveStatus(bool newSaveStatus) {
    _isSaved = newSaveStatus;
    merge(vals: {"isSaved": _isSaved.toString()});
    g.savedMediasIDs[type] = savedMediaIDs(type).toList();
  }

  Future<bool> staticUpload() async {
    final ref = id.staticStoreRef;
    final jsn = toJson(includeLocal: false);
    final setMetadata = SettableMetadata(customMetadata: jsn);
    try {
      File? f;
      if ((f = mainCachedFile ?? mainFile()) != null) {
        if (metadata.isEncrypted) {
          final d = f!.readAsBytesSync();
          final dec = Cy4.decrypt(d);
          await ref.putData(dec, setMetadata);
        } else {
          await ref.putFile(f!, setMetadata);
        }
      } else {
        print("PROBLEM: NO MEDIA TO UPLOAD BRO, RETURNING A FAILURE");
        return false;
      }
      return true;
    } catch (e) {
      print("ERROR UPLOADING MEDIA ID=${id.value}, ERR=$e");
      return false;
    }
  }

  Future<void> staticDelete() async {
    try {
      await id.staticStoreRef.delete();
    } catch (e) {
      print("error deleting media id=${id.value}, err=$e");
    }
  }

  Future<void> downloadAndWriteIfNeeded() async {
    if (mainFile() != null) return;
    final ref = tempID == null ? id.staticStoreRef : id.tempStoreRef;
    final data = await ref.getData();
    if (data != null) await write(data);
  }

  Future<String?> get tempUrl async {
    print("trying to get temp media url at ${tempID?.value}");
    try {
      return _cachedUrl = await tempID!.tempStoreRef.getDownloadURL();
    } catch (e) {
      print("error getting temp url: $e");
      return null;
    }
  }

  Future<String?> get url async {
    if (_cachedUrl != null) return _cachedUrl;
    if (!tempTS.isExpired && tempID != null) {
      // online time stamp is not expired, online id isn't null
      // good chances we will find the message media URL
      try {
        return _cachedUrl = await tempID!.tempStoreRef.getDownloadURL();
      } catch (e) {
        return null;
      }
      // else if can try to fetch a node image
    } else {
      try {
        return _cachedUrl = await id.staticStoreRef.getDownloadURL();
      } catch (e) {
        return null;
      }
    }
  }

  @override
  Map<String, String> get tempPayloadMetadata => toJson(includeLocal: false);

  @override
  Uint8List? get tempPayload {
    return mainFile()?.readAsBytesSync() ?? mainCachedFile?.readAsBytesSync();
  }

  @override
  String get table => "medias";
  // Database get dbb => mediasDB;

  Future<Down4Media> userInitRecalculation(ComposedID oid) async {
    final metadataJson = metadata.toJson();
    metadataJson["ownerID"] = oid.value;
    return Down4Media.fromLocal2(id,
        writeFromCachedPath: true,
        mainCachedPath: mainCachedPath,
        metadata: Down4MediaMetadata.fromJson(metadataJson),
        tinyThumbnail: tinyThumbnail);
  }
}

class Down4Image extends Down4Media {
  Down4Image(
    super.id, {
    required super.metadata,
    super.mainCachedPath,
    super.tinyThumbnail,
    super.lastUse,
    super.tempID,
    super.tempTS,
    super.isSaved = false,
    super.isPaidToView = false,
    super.isPaidToOwn = false,
    super.isLocked = false,
  });

  (double? w, double? h) ss(Size ds) {
    if (metadata.width > metadata.height) {
      return (ds.width * golden, null);
    } else {
      return (null, ds.height * golden);
    }
  }

  Image? readySnipImage() {
    File? f;
    if ((f = mainCachedFile ?? mainFile()) != null) {
      return Image(image: FileImage(f!), fit: BoxFit.cover);
    } else if (_cachedUrl != null) {
      return Image(image: NetworkImage(_cachedUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  Future<Image?> futureSnipImage() async {
    await tempUrl;
    if (_cachedUrl == null) {
      return null;
    }
    return Image(image: NetworkImage(_cachedUrl!), fit: BoxFit.cover);
  }

  String _profilePath([String? appDir]) => "${mainPath(appDir)}_prf";

  // returns or generate pofile image
  Future<String?> profilePath([String? appDir]) async {
    print("the app dir man g: $appDir");
    final File to = File(_profilePath(appDir));
    final File? from = mainFile(appDir);
    if (to.existsSync()) return _profilePath(appDir);
    if (from == null) return null;
    await cropAndSaveToSquare(from: from, to: to);
    return _profilePath(appDir);
  }

  ImageProvider? localImage(Size s, {bool forceSquare = false}) {
    File? f;
    int? w, h;

    // we want cached (w or h) to be (golden * longest diplaySize side)
    if (size.aspectRatio < 1) {
      w = (s.width * golden).toInt();
    } else {
      h = (s.height * golden).toInt();
    }

    f ??= (mainCachedFile ?? mainFile());
    if (f != null) {
      if (isEncrypted) {
        final enc = EncryptedFileImage(f);
        final res = ResizeImage(enc, width: w, height: h);
        return res;
      } else {
        final res = ResizeImage(FileImage(f), width: w, height: h);
        return res;
      }
    } else if (_cachedUrl != null) {
      print("cached url: $_cachedUrl");
      final res = ResizeImage(NetworkImage(_cachedUrl!), width: w, height: h);
    }
    return null;
  }

  Image? readyImage(Size s, {bool forceSquare = false}) {
    File? f;
    int? w, h;

    // we want cached (w or h) to be (golden * longest diplaySize side)
    if (size.aspectRatio < 1) {
      w = (s.width * golden).toInt();
    } else {
      h = (s.height * golden).toInt();
    }

    if ((f = mainCachedFile ?? mainFile()) != null) {
      if (isEncrypted) {
        final enc = EncryptedFileImage(f!);
        final res = ResizeImage(enc, width: w, height: h);
        return Image(image: res, fit: BoxFit.cover);
      } else {
        final res = ResizeImage(FileImage(f!), width: w, height: h);
        return Image(image: res, fit: BoxFit.cover);
      }
    } else if (_cachedUrl != null) {
      print("cached url: $_cachedUrl");
      final res = ResizeImage(NetworkImage(_cachedUrl!), width: w, height: h);
      return Image(image: res, fit: BoxFit.cover);
    }
    return null;
  }

  bool get isEncrypted => metadata.isEncrypted;

  Future<Image?> futureImage(Size s, {bool forceSquare = false}) async {
    await url;
    return readyImage(s, forceSquare: forceSquare);
  }

  @override
  String? delete({bool stmt = false}) {
    super.delete(stmt: stmt);
    try {
      mainFile()?.delete();
    } catch (_) {}
    try {
      File(_profilePath()).delete();
    } catch (_) {}
    return null;
  }

  @override
  Future<void> write(Uint8List mainData) async {
    tinyThumbnail ??= makeTiny(mainData);
    await File(mainPath()).writeAsBytes(mainData);
  }
}

class Down4Video extends Down4Media {
  Down4Video(
    super.id, {
    required super.metadata,
    super.mainCachedPath,
    super.tinyThumbnail,
    super.lastUse,
    super.tempID,
    super.tempTS,
    super.isSaved = false,
    super.isPaidToView = false,
    super.isPaidToOwn = false,
    super.isLocked = false,
  });

  Image? thumbnail(Size s, {bool forceSquare = false}) {
    if (thumbnailFile == null) return null;
    int? w, h;

    // we want cached (w or h) to be (golden * longest diplaySize side)
    if (size.aspectRatio < 1) {
      w = (s.width * golden).toInt();
    } else {
      h = (s.height * golden).toInt();
    }

    return Image.file(thumbnailFile!,
        fit: BoxFit.cover, cacheWidth: w, cacheHeight: h);
  }

  VideoPlayerController? newReadyController() {
    if ((mainCachedFile ?? mainFile()) != null) {
      return VideoPlayerController.file((mainCachedFile ?? mainFile())!);
    }
    if (_cachedUrl != null) {
      final uri = Uri.parse(_cachedUrl!);
      return VideoPlayerController.networkUrl(uri);
    }

    return null;
  }

  Future<VideoPlayerController?> futureController() async {
    final url_ = await url;
    if (url_ != null) {
      final uri = Uri.parse(url_);
      return VideoPlayerController.networkUrl(uri);
    }
    return null;
  }

  @override
  String? delete({bool stmt = false}) {
    super.delete(stmt: stmt);
    mainFile()?.delete();
    thumbnailFile?.delete();
    return null;
  }

  File? get thumbnailFile {
    File f;
    if (!(f = File(thumbnailPath)).existsSync()) return null;
    return f;
  }

  String get thumbnailPath => "$mainPath-tn";

  @override
  Future<void> write(Uint8List mainData) async {
    await File(mainPath()).writeAsBytes(mainData);
    final tn =
        await VideoThumbnail.thumbnailData(video: mainPath(), quality: 75);
    if (tn == null) return;
    tinyThumbnail = makeTiny(tn);
    await File(thumbnailPath).writeAsBytes(tn);
  }
}

// class CustomImage extends StatelessWidget {

//   @override
//   Widget build(BuildContext ctx) {
//     final cachedVal = ImageCacheManager().cachedImage(key);
//     if (cachedVal != null) {
//       print("image is cached bro, ez pz loading");
//       return cachedVal;
//       //return ImageRendererWidget(image: cachedVal, s: s);
//     }
//     print("image is not cached bro, need to load");
//     return FutureBuilder(
//         future: ImageCacheManager()
//             .loadImageFromFile(this as Down4Image, key: key, ds: s),
//         builder: (ctx, snp) {
//           final data = snp.data;
//           final state = snp.connectionState;
//           if (state != ConnectionState.done || data == null) {
//             return SizedBox.fromSize(size: s);
//           } else {
//             return data; //ImageRendererWidget(image: data, s: s);
//           }
//         });
//   }
// }

/// console medias cache manager, currently the only use
/// flutter image seems good enough for the rest

// class CustomImage extends RawImage {
//   final Down4Image im;
//   const CustomImage(this.im,
//       {super.image, super.fit, super.width, super.height, super.key});
// }

class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._();

  factory ImageCacheManager() => _instance;

  int _lastLoad = makeTimestamp();
  final int _loadingGap = 10;

  Stream<CustomImage> throttledImages(Iterable<(Down4ID, String?)> keys,
      {Size? size}) async* {
    for (final (id, prefix) in keys) {
      final key = (prefix ?? "") + id.unik;
      final rim = readyImage(key);
      if (rim != null) {
        yield rim;
      } else {
        final fim = await unReadyImage(id, prefix: prefix, size: size);
        if (fim != null) {
          yield fim;
        } else {
          continue;
        }
      }
    }
  }

  ImageCacheManager._();

  CustomImage? readyImage(String key) {
    print("testing ready image!");
    final wasBuilt = _imageCache[key]?.wasBuilt;
    if (wasBuilt ?? false) {
      print("image is ready, returing it right away!");
      return _imageCache[key]!;
    }
    return null;
  }

  Future<CustomImage?> unReadyImage(
    Down4ID id, {
    Size? size,
    String? prefix,
  }) async {
    print("image is not ready, loading that bad boy out!");
    final key = (prefix ?? "") + id.unik;
    CustomImage? fim = _imageCache[key];
    if (fim == null) {
      final image = await global<Down4Image>(id);
      if (image != null) {
        fim = await _loadImageFromFile(image, size: size, prefix: prefix);
      }
    }

    if (fim == null) return null;
    final now = makeTimestamp();
    final threshold = _lastLoad + _loadingGap;
    final diff = now - threshold;
    print("""
        now=$now
        threshold=$threshold
        diff=$diff
        """);
    if (!diff.isNegative) {
      _lastLoad = makeTimestamp();
      return fim;
    } else {
      print("waiting ${-diff} before loading next image!");
      return Future.delayed(Duration(milliseconds: -diff), () {
        _lastLoad = makeTimestamp();
        return fim;
      });
    }
    // -------10----------20--#-----T--30--N---------40---
    // threshold = # + G
    // diff = N - T
    // if diff is positive -> 'past threshold, return right away'
    // else -> wait (-diff)
  }

  final Map<String, CustomImage> _imageCache = {};

  Future<CustomImage?> _loadImageFromFile(Down4Image im,
      {Size? size, String? prefix}) async {
    print("cached len: ${_imageCache.length}");
    final f = im.mainCachedFile ?? im.mainFile();
    if (f == null) return null;
    final Uint8List imageBytes = await f.readAsBytes();
    final s = size ?? Size(im.metadata.width, im.metadata.height);
    final (ww, hh) = im.ss(size ?? s);

    final codec = await ui.instantiateImageCodec(imageBytes,
        targetHeight: hh?.toInt(), targetWidth: ww?.toInt());
    final frame = await codec.getNextFrame();
    final uiIm = frame.image;

    final k = (prefix ?? "") + im.id.unik;
    final rawImage =
        RawImage(image: uiIm, fit: BoxFit.cover, width: ww, height: hh);

    _imageCache[k] = CustomImage(rawImage, im);
    return unReadyImage(im.id, prefix: prefix);
  }

  void clearCache() {
    _imageCache.clear();
  }
}

class CustomImage extends StatelessWidget {
  bool wasBuilt = false;
  final Down4Image im;
  final RawImage image;
  CustomImage(this.image, this.im, {super.key});

  @override
  Widget build(BuildContext context) {
    print("drawing image: ${im.id.unik}");
    wasBuilt = true;
    return image;
  }
}

class StreamList<T> extends StatefulWidget {
  final Stream<T> stream;
  final Widget Function(int, T) makeObject;
  final Widget Function(int)? placeHolder;
  final int? maxN;
  const StreamList(this.stream, this.makeObject,
      {this.maxN, this.placeHolder, super.key});

  @override
  State<StreamList> createState() => _StreamListState<T>();
}

class _StreamListState<T> extends State<StreamList> {
  final sc = StreamController<T>.broadcast();
  List<T> list = [];

  @override
  void initState() {
    super.initState();
    sc.stream.listen((e) => setState(() => list.add(e)));
    widget.stream.pipe(sc);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.maxN ?? list.length,
      itemBuilder: (ctx, i) {
        if (i < list.length) {
          return widget.makeObject(i, list[i]);
        } else {
          return widget.placeHolder?.call(i) ?? const SizedBox.shrink();
        }
      },
    );
  }
}

class CustomList extends StatefulWidget {
  final void Function(Down4Media) mediaPressFunc;
  const CustomList(this.mediaPressFunc, {super.key});

  @override
  State<CustomList> createState() => _CustomListState();
}

class _CustomListState extends State<CustomList> {
  final _streamController = StreamController<CustomImage>.broadcast();
  List<CustomImage> list = [];
  final _mediasPerRow = 5;
  final mediaCelSize = Medias2.mediaCelSize;
  final mc = ImageCacheManager();

  @override
  void initState() {
    super.initState();
    _streamController.stream.listen((p) => setState(() => list.add(p)));
    load(_streamController);
  }

  List<Down4ID> mids(MediaType t) => g.savedMediasIDs[t]!;

  void load(StreamController<CustomImage> sc) async {
    final its = mids(MediaType.images).map((id) => (id, "console"));
    final celSize = Size.square(Medias2.mediaCelSize);
    final strm = mc.throttledImages(its, size: celSize);
    strm.pipe(sc);
  }

  @override
  void dispose() {
    print("XXXX DISPOSING OF CUSTOM LIST XXXX");
    super.dispose();
    _streamController.close();
  }

  @override
  Widget build(BuildContext context) {
    final nRows = (mids(MediaType.images).length / _mediasPerRow).ceil();
    return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Console.consoleRad)),
        ),
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: nRows * mediaCelSize, maxWidth: Console.trueWidth),
            child: ListView.builder(
                itemCount: nRows,
                itemBuilder: (ctx, index) {
                  Widget f(int i) {
                    if (i < list.length) {
                      final im = list[i];
                      return SizedBox.square(
                          dimension: mediaCelSize,
                          child: GestureDetector(
                              onTap: () => widget.mediaPressFunc(im.im),
                              child: im));
                    } else {
                      return SizedBox.square(dimension: mediaCelSize);
                    }
                  }

                  return Row(
                    key: Key(MediaType.images.name + index.toString()),
                    children: List.generate(
                      _mediasPerRow,
                      (j) => f((index * _mediasPerRow) + j),
                    ),
                  );
                })));
  }
}
