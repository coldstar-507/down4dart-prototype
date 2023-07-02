import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:down4/src/globals.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart' show Color, Image;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../_dart_utils.dart';
import '../_dart_utils.dart' as u;
import 'dart:typed_data' show Uint8List;
import 'package:cbl/cbl.dart';

import '_data_utils.dart';
import 'couch.dart';
import 'firebase.dart';

final _messageStore =
    FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _nodesStore = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

class FireMedia extends Locals with Temps {
  @override
  Database get dbb => mediasDB;

  @override
  final ComposedID id;

  final bool isReversed, isLocked, isPaidToView, isPaidToOwn, isSquared;
  String? cachePath, cachedUrl;
  String? tinyThumbnail;
  bool _isSaved;
  final ComposedID ownerID;
  int _lastUse;
  final String mime;
  final double width, height;
  final String? text;
  final int timestamp;
  Uint8List? cachedMemory;

  ComposedID? _tempID;
  int? _tempTS;

  @override
  ComposedID? get tempID => _tempID;

  @override
  int? get tempTS => _tempTS;

  Size get size => Size(width, height);

  double get aspectRatio => size.aspectRatio;

  String get extension => extensionFromMime(mime);

  bool get isVideo => extension.isVideoExtension();

  Future<VideoPlayerController?> get videoController async {
    if (!isVideo) throw 'Media needs to be a video';
    final f = (cachedFile) ?? videoFile;
    if (f != null) return VideoPlayerController.file(f);
    final url_ = await url;
    if (url_ != null) return VideoPlayerController.network(url_);
    return null;
  }

  String get videoPath => "${g.appDirPath}/$id";

  File? get cachedFile {
    if (cachePath == null) return null;
    if (!File(cachePath!).existsSync()) return null;
    return File(cachePath!);
  }

  File? get videoFile {
    if (!File(videoPath).existsSync()) return null;
    return File(videoPath);
  }

  Future<String?> get url async {
    if (cachedUrl != null) return cachedUrl;
    if (!tempTS.isExpired && tempID != null) {
      // online time stamp is not expired, online id isn't null
      // good chances we will find the message media URL
      try {
        return cachedUrl =
            await _messageStore.ref(tempID!.value).getDownloadURL();
      } catch (e) {
        return null;
      }
      // else if can try to fetch a node image
    } else {
      try {
        return cachedUrl = await _nodesStore.ref(id.value).getDownloadURL();
      } catch (e) {
        return null;
      }
    }
  }

  Future<Uint8List?> get localImageData async {
    final blob = (await dbb.document(id.value))?.blob("image");
    return cachedMemory = await blob?.content();
  }

  Future<bool> get cachedAndReady async {
    if (cachedFile != null) return true;
    if (await localImageData != null) return true;
    if (await url != null) return true;
    return false;
  }

  Image? get displayCachedImage {
    if (cachedMemory != null) return Image.memory(cachedMemory!);
    if (cachedFile != null) return Image.file(cachedFile!);
    if (cachedUrl != null) return Image.network(cachedUrl!);
    return null;
  }

  FireMedia(
    this.id, {
    required this.ownerID,
    required this.timestamp,
    required this.width,
    required this.height,
    required this.mime,
    this.cachePath,
    this.tinyThumbnail,
    int? tempTS,
    ComposedID? tempID,
    int lastUse = 0,
    bool isSaved = false,
    this.isLocked = false,
    this.isPaidToView = false,
    this.isReversed = false,
    this.isPaidToOwn = false,
    this.isSquared = false,
    this.text,
  })  : _lastUse = lastUse,
        _isSaved = isSaved,
        _tempID = tempID,
        _tempTS = tempTS;

  // FireMedia copy() {
  //   return FireMedia.fromJson(toJson(toLocal: true));
  // }

  FireMedia updated({required ComposedID newTempID, required int newTempTS}) {
    final json = toJson(toLocal: true);
    json["onlineID"] = newTempID.value;
    json["onlineTimestamp"] = newTempTS.toString();
    return FireMedia.fromJson(json);
  }

  // special function upon user intialization
  Future<FireMedia?> userInitRecalculation(ComposedID properOwnerID) async {
    final json = toJson(toLocal: true);
    // final data = File(cachePath!).readAsBytesSync();
    json["ownerID"] = properOwnerID.value;
    // json["id"] = u.deterministicMediaID(data, properID).value;
    return FireMedia.fromJson(json)..cachePath = cachePath;
  }

  Future<void> use() async {
    _lastUse = u.makeTimestamp();
    print("USING MEDIA ID = $id");
    await merge({"lastUse": _lastUse.toString()});
  }

  Future<void> updateSaveStatus(bool newSaveStatus) async {
    _isSaved = newSaveStatus;
    await merge({"isSaved": _isSaved.toString()});
  }

  Future<void> writeFromCachedPath() async {
    if (cachePath == null) return;
    final d = File(cachePath!).readAsBytesSync();
    Uint8List? tn;
    if (isVideo) {
      tn = await VideoThumbnail.thumbnailData(video: cachePath!, quality: 80);
      await File(videoPath).writeAsBytes(d);
    }
    await write(imageData: tn ?? d);
  }

  Future<void> write({required Uint8List imageData}) async {
    tinyThumbnail ??= makeTiny(imageData);
    final imageMime = isVideo ? "image/png" : mime;
    final imageBlob = Blob.fromData(imageMime, imageData);
    await merge({"image": imageBlob});
  }

  factory FireMedia.fromJson(Map<String, Object?> decodedJson) {
    final tempID = decodedJson["tempID"] as String?;
    return FireMedia(ComposedID.fromString(decodedJson["id"] as String)!,
        ownerID: ComposedID.fromString(decodedJson["ownerID"] as String)!,
        timestamp: int.parse(decodedJson["timestamp"] as String),
        mime: decodedJson["mime"] as String,
        cachePath: decodedJson["cachePath"] as String?,
        lastUse: int.parse(decodedJson["lastUse"] as String? ?? "0"),
        tinyThumbnail: decodedJson["tinyThumbnail"] as String?,
        tempID: tempID != null ? ComposedID.fromString(tempID) : null,
        tempTS: int.tryParse(decodedJson["tempTS"] as String? ?? ""),
        isSaved: decodedJson["isSaved"] == "true",
        isReversed: decodedJson["isReversed"] == "true",
        isSquared: decodedJson["isSquared"] == "true",
        isLocked: decodedJson["isLocked"] == "true",
        isPaidToOwn: decodedJson["isPaidToView"] == "true",
        isPaidToView: decodedJson["isPaidToOwn"] == "true",
        width: double.parse(decodedJson["width"] as String),
        height: double.parse(decodedJson["height"] as String),
        text: decodedJson["text"] as String?);
  }

  @override
  Map<String, String> toJson({bool toLocal = true}) => {
        "id": id.value,
        "ownerID": ownerID.value,
        "timestamp": timestamp.toString(),
        "mime": mime,
        if (_tempID != null) "tempID": _tempID!.value,
        if (_tempTS != null) "tempTS": _tempTS!.toString(),
        if (tinyThumbnail != null) "tinyThumbnail": tinyThumbnail!,
        if (text != null) "text": text!,
        "isReversed": isReversed.toString(),
        "isSquared": isSquared.toString(),
        "isLocked": isLocked.toString(),
        "isPaidToView": isPaidToView.toString(),
        "isPaidToOwn": isPaidToOwn.toString(),
        "width": width.toString(),
        "height": height.toString(),
        if (toLocal) "lastUse": _lastUse.toString(),
        if (toLocal) "isVideo": isVideo.toString(),
        if (toLocal) "isSaved": _isSaved.toString(),
      };

  @override // Temporary uploads are always part of a message
  Future<Map<String, String>?> temporaryUpload(Map<String, String> msg) async {
    int? freshTS;
    ComposedID? freshID;
    try {
      print("MEDIA TEMP TIMESTAMP = $tempTS");

      final uploadMedia = tempID == null || tempTS.shouldBeUpdated;

      if (uploadMedia) {
        print("(RE)-uploading media!");
        freshID = ComposedID();
        freshTS = makeTimestamp();

        final jsonMedia = toJson(toLocal: false);
        jsonMedia["tempID"] = freshID.value;
        jsonMedia["tempTS"] = freshTS.toString();

        final ref = freshID.server.temporaryStore.ref(freshID.value);
        final setMetadata = SettableMetadata(customMetadata: jsonMedia);

        if (cachedFile != null) {
          await ref.putFile(cachedFile!, setMetadata);
        } else if (isVideo && videoFile != null) {
          await ref.putFile(videoFile!, setMetadata);
        } else if ((await localImageData) != null) {
          await ref.putData((await localImageData)!, setMetadata);
        } else {
          print("PROBLEM: NO MEDIA TO UPLOAD BRO");
        }
      } else {
        print("OK: NO NEED TO UPDATE MEDIA");
      }

      msg["tempMediaID"] = freshID?.value ?? tempID!.value;
      msg["tempMediaTS"] = freshTS?.toString() ?? tempTS!.toString();

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
    final metadata = SettableMetadata(customMetadata: toJson(toLocal: false));
    try {
      if (cachedFile != null) {
        await ref.putFile(cachedFile!, metadata);
      } else if (isVideo && videoFile != null) {
        await ref.putFile(videoFile!, metadata);
      } else if ((await localImageData) != null) {
        await ref.putData((await localImageData)!, metadata);
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
}
