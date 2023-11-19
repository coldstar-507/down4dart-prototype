import 'dart:async';
import 'dart:io';

import 'package:down4/src/data_objects/couch.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:down4/src/globals.dart';
import 'package:down4/src/pages/_page_utils.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/utils/encrypted_file_image.dart';
import 'package:down4/src/utils/encryption_helper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
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
  // String? tinyThumbnail,
  String? _cachedUrl;
  int _lastUse;
  bool _isSaved;
  Down4MediaMetadata metadata;

  String? mainCachedPath;

  int get sizeInBytes;

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

  Offset get middlePoint => Offset(size.width / 2, size.height / 2);

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
    // this.tinyThumbnail,
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

  factory Down4Media.fromLocal(
    ComposedID id, {
    required Down4MediaMetadata metadata,
    ComposedID? tempID,
    int? tempTS,
    String? tinyThumbnail,
    String? mainCachedPath,
    int lastUse = 0,
    bool isSaved = false,
    bool isPaidToView = false,
    bool isPaidToOwn = false,
    bool isLocked = false,
  }) {
    if (metadata.isVideo) {
      return Down4Video(id,
          metadata: metadata,
          tempTS: tempTS,
          tempID: tempID,
          // tinyThumbnail: tinyThumbnail,
          lastUse: lastUse,
          isSaved: isSaved,
          mainCachedPath: mainCachedPath,
          isPaidToView: isPaidToView,
          isPaidToOwn: isPaidToOwn,
          isLocked: isLocked);
    } else {
      return Down4Image(id,
          metadata: metadata,
          tempTS: tempTS,
          tempID: tempID,
          mainCachedPath: mainCachedPath,
          // tinyThumbnail: tinyThumbnail,
          lastUse: lastUse,
          isSaved: isSaved,
          isPaidToView: isPaidToView,
          isPaidToOwn: isPaidToOwn,
          isLocked: isLocked);
    }
  }

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
        // if (tinyThumbnail != null) "tinyThumbnail": tinyThumbnail!,
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
    // final tinyThumbnail = decodedJson["tinyThumbnail"];
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
          // tinyThumbnail: tinyThumbnail,
          tempID: tempID,
          tempTS: tempTS);
    } else {
      return Down4Image(id,
          metadata: metadata,
          isSaved: isSaved,
          isLocked: isLocked,
          isPaidToOwn: isPaidToOwn,
          isPaidToView: isPaidToView,
          tempID: tempID,
          tempTS: tempTS);
    }
  }

  String get mainPath {
    return "${Down4Local().appDirPath}${Platform.pathSeparator}${id.unik}";
  }

  static String mainPath_(Down4ID id) {
    return "${Down4Local().appDirPath}${Platform.pathSeparator}${id.unik}";
  }

  static String cachePath_(Down4ID id) {
    return "${Down4Local().cacheDirPath}${Platform.pathSeparator}${id.unik}";
  }

  File? get mainFile {
    final f = File(mainPath);
    if (!f.existsSync()) return null;
    return f;
  }

  File? get mainCachedFile {
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
        print("CROPPING IMAGE BRO");
        const idealSize = 512;
        final to = File(mainPath);

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
      File? f = mainCachedFile ?? mainFile;
      if (f != null) {
        if (metadata.isEncrypted) {
          final d = f.readAsBytesSync();
          final dec = Cy4.decrypt(d);
          await ref.putData(dec, setMetadata);
        } else {
          await ref.putFile(f, setMetadata);
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
    if (mainFile != null) return;
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
    File? f = mainFile;
    if (f == null) {
      print("mainfile is null, checking cached file.");
    } else {
      return f.readAsBytesSync();
    }
    f = mainCachedFile;
    if (f == null) print("cached file is null also");
    return f?.readAsBytesSync();
  }

  @override
  String get table => "medias";

  Future<Down4Media> userInitRecalculation(ComposedID oid) async {
    return Down4Media.fromLocal(id,
        mainCachedPath: mainCachedPath,
        metadata: Down4MediaMetadata(
            ownerID: oid,
            timestamp: makeTimestamp(),
            width: metadata.width,
            height: metadata.height,
            isReversed: metadata.isReversed,
            mime: metadata.mime));
  }
}

class Down4Image extends Down4Media {
  Down4Image(
    super.id, {
    required super.metadata,
    super.mainCachedPath,
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

  @override
  int get sizeInBytes {
    Uint8List? mainBytes, profBytes;
    try {
      mainBytes = mainCachedFile?.readAsBytesSync();
    } catch (_) {
      print("error reading main bytes");
    }
    try {
      profBytes = profileFile?.readAsBytesSync();
    } catch (_) {
      print("error reading prof bytes");
    }
    return (mainBytes?.length ?? 0) + (profBytes?.length ?? 0);
  }

  File? get profileFile {
    final f = File(_profilePath);
    if (!f.existsSync()) return null;
    return f;
  }

  Image? readySnipImage() {
    File? f = mainCachedFile ?? mainFile;
    if (f != null) {
      return Image(image: FileImage(f), fit: BoxFit.cover);
    } else if (_cachedUrl != null) {
      return Image(image: NetworkImage(_cachedUrl!), fit: BoxFit.cover);
    }
    return null;
  }

  Image? basicImage() {
    File? f = mainCachedFile ?? mainFile;
    if (f != null) {
      return Image(image: FileImage(f));
    } else if (_cachedUrl != null) {
      return Image(image: NetworkImage(_cachedUrl!));
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

  String get _profilePath => "${mainPath}_prf";

  // returns or generate pofile image
  Future<String?> get profilePath async {
    final File to = File(_profilePath);
    final File? from = mainFile;
    if (to.existsSync()) return _profilePath;
    if (from == null) return null;
    await cropAndSaveToSquare(from: from, to: to, size: 200);
    return _profilePath;
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

    f ??= (mainCachedFile ?? mainFile);
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
      return res;
    }
    return null;
  }

  Image? readyImage(Size s, {bool forceSquare = false}) {
    File? f = mainFile ?? mainCachedFile;
    int? w, h;

    // we want cached (w or h) to be (golden * longest diplaySize side)
    if (size.aspectRatio < 1) {
      w = (s.width * golden).toInt();
    } else {
      h = (s.height * golden).toInt();
    }

    if (f != null) {
      if (isEncrypted) {
        final enc = EncryptedFileImage(f);
        final res = ResizeImage(enc, width: w, height: h);
        return Image(image: res, fit: BoxFit.cover);
      } else {
        final res = ResizeImage(FileImage(f), width: w, height: h);
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
    print("deleting media=${id.unik}");
    super.delete(stmt: stmt);
    try {
      mainFile?.delete();
    } catch (_) {
      print("error deleting main file");
    }
    try {
      profileFile?.delete();
    } catch (_) {
      print("error deleting profile file");
    }
    return null;
  }

  @override
  Future<void> write(Uint8List mainData) async {
    await File(mainPath).writeAsBytes(mainData);
  }
}

class Down4Video extends Down4Media {
  Down4Video(
    super.id, {
    required super.metadata,
    super.mainCachedPath,
    super.lastUse,
    super.tempID,
    super.tempTS,
    super.isSaved = false,
    super.isPaidToView = false,
    super.isPaidToOwn = false,
    super.isLocked = false,
  });

  @override
  int get sizeInBytes {
    Uint8List? mainBytes, thumBytes;
    try {
      mainBytes = mainCachedFile?.readAsBytesSync();
    } catch (_) {
      print("error reading main bytes");
    }
    try {
      thumBytes = thumbnailFile?.readAsBytesSync();
    } catch (_) {
      print("error reading thum bytes");
    }
    return (mainBytes?.length ?? 0) + (thumBytes?.length ?? 0);
  }

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

  Future<RawImage?> rawThumbnail(Size s, {bool forceSquare = false}) async {
    if (thumbnailFile == null) return null;
    int? w, h;

    // we want cached (w or h) to be (golden * longest diplaySize side)
    if (size.aspectRatio < 1) {
      w = (s.width * golden).toInt();
    } else {
      h = (s.height * golden).toInt();
    }

    final bytes = thumbnailFile!.readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes,
        targetHeight: h?.toInt(), targetWidth: w?.toInt());
    final frame = await codec.getNextFrame();
    final uiIm = frame.image;

    final rawImage = RawImage(
        image: uiIm,
        fit: BoxFit.cover,
        width: w?.toDouble(),
        height: h?.toDouble());

    return rawImage;
  }

  VideoPlayerController? newReadyController() {
    final f = mainCachedFile ?? mainFile;
    if (f != null) {
      print("returning video player from file!");
      return VideoPlayerController.file(f);
    }
    if (_cachedUrl != null) {
      print("returning videoplayer from cached url");
      final uri = Uri.parse(_cachedUrl!);
      return VideoPlayerController.networkUrl(uri);
    }
    return null;
  }

  Future<VideoPlayerController?> futureController() async {
    final url_ = await url;
    if (url_ != null) {
      final uri = Uri.parse(url_);
      print("returning future videoplayer from network");
      return VideoPlayerController.networkUrl(uri);
    }
    print("no videoplayer found");
    return null;
  }

  @override
  String? delete({bool stmt = false}) {
    super.delete(stmt: stmt);
    try {
      mainFile?.delete();
    } catch (_) {
      print("error deleting main file");
    }
    try {
      thumbnailFile?.delete();
    } catch (_) {
      print("error deleting thumnail file");
    }
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
    await File(mainPath).writeAsBytes(mainData);
    final d = await VideoThumbnail.thumbnailData(video: mainPath, quality: 80);
    if (d != null) await File(thumbnailPath).writeAsBytes(d);
  }
}

class ConsoleMedias {
  static final ConsoleMedias _instance = ConsoleMedias._();

  factory ConsoleMedias() => _instance;

  int _lastLoad = makeTimestamp();
  final int _loadingGap = 0;

  Stream<CustomMedia> throttledImages(Iterable<(Down4ID, String?)> keys,
      {Size? size}) async* {
    for (final (id, prefix) in keys) {
      final key = (prefix ?? "") + id.unik;
      final rim = readyMedia(key);
      if (rim != null) {
        yield rim;
      } else {
        final fim = await unReadyMedia(id, prefix: prefix, size: size);
        if (fim != null) {
          yield fim;
        } else {
          continue;
        }
      }
    }
  }

  ConsoleMedias._();

  CustomMedia? readyMedia(String key) {
    print("testing ready image!");
    final wasBuilt = _consoleMediaCache[key]?.wasBuilt ?? false;
    if (wasBuilt) {
      print("image is ready, returing it right away!");
      return _consoleMediaCache[key]!;
    }
    return null;
  }

  Future<CustomMedia?> unReadyMedia(
    Down4ID id, {
    Size? size,
    String? prefix,
  }) async {
    print("image is not ready, loading that bad boy out!");
    final key = (prefix ?? "") + id.unik;
    CustomMedia? fim = _consoleMediaCache[key];
    if (fim == null) {
      final media = await global<Down4Media>(id);
      if (media != null) {
        switch (media.type) {
          case MediaType.images:
            fim = await _loadImageFromFile(media as Down4Image,
                size: size, prefix: prefix);
            break;
          case MediaType.gifs:
            fim = await _loadGifFromFile(media as Down4Image,
                size: size, prefix: prefix);
            break;
          case MediaType.videos:
            fim = await _loadVideoFromFile(media as Down4Video,
                size: size, prefix: prefix);
            break;
        }
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
      print("not waiting");
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

  final Map<String, CustomMedia> _consoleMediaCache = {};

  Future<CustomMedia?> loadMediaFromFile(Down4Media m,
      {Size? size, String? prefix}) async {
    final t = m.type;
    switch (t) {
      case MediaType.images:
        return ConsoleMedias()
            ._loadImageFromFile(m as Down4Image, size: size, prefix: prefix);
      case MediaType.videos:
        return ConsoleMedias()
            ._loadVideoFromFile(m as Down4Video, size: size, prefix: prefix);
      case MediaType.gifs:
        return ConsoleMedias()
            ._loadGifFromFile(m as Down4Image, size: size, prefix: prefix);
    }
  }

  Future<CustomMedia?> _loadVideoFromFile(Down4Video vid,
      {Size? size, String? prefix}) async {
    final f = vid.mainFile;
    if (f == null) return null;
    final s = size ?? vid.size;
    final thumbnail = await vid.rawThumbnail(s, forceSquare: true);

    final k = (prefix ?? "") + vid.id.unik;
    return _consoleMediaCache[k] =
        CustomMedia(vid, vid.display(size: s, rawThumbnail: thumbnail));
  }

  Future<CustomMedia?> _loadGifFromFile(Down4Image gif,
      {Size? size, String? prefix}) async {
    final f = gif.mainFile;
    if (f == null) return null;
    final Uint8List bytes = f.readAsBytesSync();
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, completer.complete);
    final ui.Image image = await completer.future;

    final s = size ?? Size(gif.metadata.width, gif.metadata.height);
    final (ww, hh) = gif.ss(size ?? s);

    final k = (prefix ?? "") + gif.id.unik;
    final rawImage =
        RawImage(image: image, fit: BoxFit.cover, width: ww, height: hh);

    return _consoleMediaCache[k] = CustomMedia(gif, rawImage);
  }

  Future<CustomMedia?> _loadImageFromFile(Down4Image im,
      {Size? size, String? prefix}) async {
    print("cached len: ${_consoleMediaCache.length}");
    final f = im.mainCachedFile ?? im.mainFile;
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

    _consoleMediaCache[k] = CustomMedia(im, rawImage);
    return unReadyMedia(im.id, prefix: prefix);
  }

  void clearCache() {
    _consoleMediaCache.clear();
  }
}

class CustomMedia extends StatefulWidget {
  bool wasBuilt = false;
  final Down4Media media;
  final Widget renderMedia;
  CustomMedia(this.media, this.renderMedia, {super.key});

  @override
  State<CustomMedia> createState() => _CustomMedia2State();
}

class _CustomMedia2State extends State<CustomMedia> {
  Widget get renderWidget {
    if (widget.renderMedia is RawImage && widget.media.isReversed) {
      return Transform.flip(flipX: true, child: widget.renderMedia);
    } else {
      return widget.renderMedia;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.wasBuilt) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        widget.wasBuilt = true;
        setState(() {});
      });
    }

    return AnimatedOpacity(
      opacity: widget.wasBuilt ? 1 : 0,
      duration: const Duration(milliseconds: 100),
      child: renderWidget,
    );
  }
}

class CustomList extends StatefulWidget {
  final void Function(Down4Media) mediaPressFunc;
  final MediaType t;
  final Down4Media? toLoad;
  const CustomList(this.mediaPressFunc, this.t, {this.toLoad, super.key});

  @override
  State<CustomList> createState() => _CustomListState();
}

class _CustomListState extends State<CustomList> {
  Map<MediaType, List<CustomMedia>> _medias = {
    MediaType.images: [],
    MediaType.videos: [],
    MediaType.gifs: [],
  };

  MediaType get currentType => widget.t;

  final _mediasPerRow = 5;
  final mediaCelSize = Medias2.mediaCelSize;
  final celSize = Size.square(Medias2.mediaCelSize);
  final Map<MediaType, StreamController<CustomMedia>> _streams = {};

  List<CustomMedia> get currentMedias => _medias[currentType]!;

  void loadStream(MediaType t) {
    if (_streams[t] != null) return;
    final s = _streams[t] = StreamController.broadcast();
    s.stream.listen((e) => setState(() => _medias[t]!.add(e)));
    load(s, t);
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    final m = widget.toLoad;
    if (oldWidget.t != widget.t) {
      loadStream(widget.t);
    } else if (m != null) {
      final t = widget.toLoad!.type;
      if (_medias[t]!.containsWhere((e) => e.media == m)) {
        Medias2.toLoad = null;
        return print("media already here dog");
      }
      Future(() async {
        print("got extra media toLoad -> ${m.id.value}");
        final cm = await ConsoleMedias()
            .loadMediaFromFile(m, size: celSize, prefix: "console");
        if (cm != null) {
          print("adding media of type ${t.name} to console");
          _medias[t]!.add(cm);
          setState(() {});
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadStream(currentType);
  }

  List<Down4ID> mids(MediaType t) => g.savedMediasIDs[t]!;

  void load(StreamController<CustomMedia> sc, MediaType t) async {
    final its = mids(t).map((id) => (id, "console"));
    print("there are ${its.length} medias to load of type=${t.name}");
    final strm = ConsoleMedias().throttledImages(its, size: celSize);
    strm.pipe(sc);
  }

  @override
  void dispose() {
    print("XXXX DISPOSING OF CUSTOM LIST XXXX");
    super.dispose();
    for (final stream in _streams.values) {
      stream.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nRows = (mids(currentType).length / _mediasPerRow).ceil();
    return ScrollConfiguration(
      behavior: NoGlow(),
      child: ListView.builder(
        padding: const EdgeInsets.all(0),
        itemCount: nRows,
        itemBuilder: (ctx, index) {
          Widget f(int i) {
            if (i < currentMedias.length) {
              final im = currentMedias[i];
              return SizedBox.square(
                dimension: mediaCelSize,
                child: GestureDetector(
                  onTap: () => widget.mediaPressFunc(im.media),
                  child: im,
                ),
              );
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
        },
      ),
    );
  }
}
