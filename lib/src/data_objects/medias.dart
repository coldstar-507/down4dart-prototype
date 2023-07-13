import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:down4/src/globals.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/utils/encrypted_file_image.dart';
import 'package:down4/src/utils/encryption_helper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart' show Color, Image, Widget;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../_dart_utils.dart';
import '../_dart_utils.dart' as u;
import 'dart:typed_data' show Uint8List;
import 'package:cbl/cbl.dart';

import '_data_utils.dart';
import 'couch.dart';

class Down4MediaMetadata implements Jsons {
  final bool isReversed, isSquared;
  final String mime;
  final bool isEncrypted;
  final ComposedID ownerID;
  final double width, height;
  final String? text;
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
    this.text,
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
        timestamp: int.parse(decodedJson["timestamp"]!),
        mime: decodedJson["mime"]!,
        isReversed: decodedJson["isReversed"] == "true",
        isSquared: decodedJson["isSquared"] == "true",
        width: double.parse(decodedJson["width"]!),
        height: double.parse(decodedJson["height"]!),
        text: decodedJson["text"]);
  }

  @override
  Map<String, String> toJson() => {
        "ownerID": ownerID.value,
        "timestamp": timestamp.toString(),
        "mime": mime,
        if (text != null) "text": text!,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isEncrypted": isEncrypted.toString(),
        "width": width.toString(),
        "height": height.toString(),
      };
}

abstract class Down4Media extends Temps {
  @override
  ComposedID id;

  bool _isPaidToView, _isPaidToOwn, _isLocked;

  String? tinyThumbnail, _cachedUrl;
  int? _lastUse;
  bool _isSaved;
  Down4MediaMetadata metadata;

  String? mainCachedPath;

  Down4Media(
    this.id, {
    required this.metadata,
    super.tempID,
    super.tempTS,
    this.tinyThumbnail,
    this.mainCachedPath,
    int? lastUse,
    bool isSaved = false,
    bool isPaidToView = false,
    bool isPaidToOwn = false,
    bool isLocked = false,
  })  : _isSaved = isSaved,
        _lastUse = lastUse,
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
    int? lastUse,
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
          tinyThumbnail: tinyThumbnail,
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
          tinyThumbnail: tinyThumbnail,
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
        if (tinyThumbnail != null) "tinyThumbnail": tinyThumbnail!,
        if (_lastUse != null) "lastUse": _lastUse!.toString(),
        "isSaved": _isSaved.toString(),
        if (tempID != null) "tempID": tempID!.value,
        if (tempTS != null) "tempTS": tempTS!.toString(),
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

  String get mainPath => "${g.appDirPath}${Platform.pathSeparator}${id.value}";

  File? get mainFile {
    if (!File(mainPath).existsSync()) return null;
    return File(mainPath);
  }

  File? get mainCachedFile {
    print("main cached path: $mainCachedPath");
    File? f;
    if (mainCachedPath == null) return null;
    if (!(f = File(mainCachedPath!)).existsSync()) return null;
    return f;
  }


  // in medias, to follow json as Map<String,String> merge values are also str
  Future<void> use() async {
    _lastUse = u.makeTimestamp();
    await merge({"lastUse": _lastUse.toString()});
  }

  Future<void> write(Uint8List mainData);

  Future<void> writeFromCachedPath() async {
    File? f;
    if ((f = mainCachedFile) != null) {
      final Uint8List data = f!.readAsBytesSync();
      await write(data);
    }
  }

  // in medias, to follow json as Map<String,String> merge values are also str
  Future<void> updateSaveStatus(bool newSaveStatus) async {
    _isSaved = newSaveStatus;
    await merge({"isSaved": _isSaved.toString()});
  }

  // Down4MediaMetadata updated({
  //   required ComposedID newTempID,
  //   required int newTempTS,
  // }) {
  //   final json = toJson(includeLocal: true);
  //   json["onlineID"] = newTempID.value;
  //   json["onlineTimestamp"] = newTempTS.toString();
  //   return Down4MediaMetadata.fromJson(json);
  //  }

  @override // Temporary uploads are always part of a message
  Future<Map<String, Object>?> temporaryUpload(Map<String, Object> msg) async {
    int? freshTS;
    ComposedID? freshID;
    try {
      print("MEDIA TEMP TIMESTAMP = $tempTS");

      final uploadMedia = tempID == null || tempTS.shouldBeUpdated;

      if (uploadMedia) {
        print("(RE)-uploading media!");
        freshID = ComposedID();
        freshTS = makeTimestamp();

        final jsonMedia = toJson(includeLocal: false);
        jsonMedia["tempID"] = freshID.value;
        jsonMedia["tempTS"] = freshTS.toString();

        final ref = freshID.server.temporaryStore.ref(freshID.value);
        final setMetadata = SettableMetadata(customMetadata: jsonMedia);

        File? f;
        if ((f = mainCachedFile ?? mainFile) != null) {
          if (metadata.isEncrypted) {
            final d = f!.readAsBytesSync();
            final dec = Cy4.decrypt(d);
            await ref.putData(dec, setMetadata);
          } else {
            await ref.putFile(f!, setMetadata);
          }
        } else {
          print("PROBLEM: NO MEDIA TO UPLOAD BRO");
        }
      } else {
        print("OK: NO NEED TO UPDATE MEDIA");
      }

      msg["tempMediaID"] = freshID?.value ?? tempID!.value;
      msg["tempMediaTS"] = freshTS ?? tempTS!;

      if (freshTS != null && freshID != null) {
        this
          ..updateTempReferences(freshID, freshTS)
          ..cache();
      }

      return msg;
    } catch (e) {
      print("ERROR uploadMessageMedia,  message id: $id, error: $e");
      return null;
    }
  }

  Future<bool> staticUpload() async {
    final ref = id.staticStoreRef;
    final setMetadata =
        SettableMetadata(customMetadata: toJson(includeLocal: false));
    try {
      File? f;
      if ((f = mainCachedFile ?? mainFile) != null) {
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
  Database get dbb => mediasDB;

  // TODO, pretty sure this shit is broken
  Down4Media userInitRecalculation(ComposedID oid) {
    final metadataJson = metadata.toJson();
    metadataJson["ownerID"] = oid.value;
    return Down4Media.fromLocal(id,
        metadata: metadata, tinyThumbnail: tinyThumbnail)
      ..mainCachedPath = mainCachedPath;
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

  Image? readyImage(Size s, {bool forceSquare = false}) {
    File? f;
    int? w, h;

    // final int w = (s.width * golden).toInt();
    // final int h = (s.height * golden).toInt();

    if (size.aspectRatio < 1) {
      w = (s.width * golden).toInt();
    } else {
      h = (s.height * golden).toInt();
    }

    return Image.file(mainCachedFile ?? mainFile!,
        fit: BoxFit.cover, cacheHeight: h, cacheWidth: w);

    // return Image.file(mainCachedFile ?? mainFile!,
    //     cacheWidth: w, cacheHeight: h, fit: BoxFit.cover);
    if ((f = mainCachedFile ?? mainFile) != null) {
      if (isEncrypted) {
        final enc = EncryptedFileImage(f!);
        final res = ResizeImage(enc, width: w, height: h);
        return Image(image: res, fit: BoxFit.cover);
      } else {
        final res = ResizeImage(FileImage(f!), width: w, height: h);
        return Image(image: res, fit: BoxFit.cover);
      }
    } else if (_cachedUrl != null) {
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
  Future<void> delete() async {
    await super.delete();
    await mainFile?.delete();
  }

  @override
  Future<void> write(Uint8List mainData) async {
    tinyThumbnail ??= makeTiny(mainData);
    await File(mainPath).writeAsBytes(mainData);
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
    return Image.file(thumbnailFile!,
        fit: BoxFit.cover,
        cacheWidth: (s.width * golden).toInt(),
        cacheHeight: (s.height * golden).toInt());
  }

  VideoPlayerController? newReadyController() {
    if ((mainCachedFile ?? mainFile) != null) {
      return VideoPlayerController.file((mainCachedFile ?? mainFile)!);
    }
    if (_cachedUrl != null) return VideoPlayerController.network(_cachedUrl!);
    return null;
  }

  Future<VideoPlayerController?> futureController() async {
    final url_ = await url;
    if (url_ != null) return VideoPlayerController.network(url_);
    return null;
  }

  @override
  Future<void> delete() async {
    await super.delete();
    await mainFile?.delete();
    await thumbnailFile?.delete();
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
    final tn = await VideoThumbnail.thumbnailData(video: mainPath, quality: 75);
    if (tn == null) return;
    tinyThumbnail = makeTiny(tn);
    await File(thumbnailPath).writeAsBytes(tn);
  }
}
