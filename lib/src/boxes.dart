import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:down4/src/_down4_dart_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'data_objects.dart';
import 'web_requests.dart' as r;
import 'bsv/types.dart';
import 'bsv/wallet.dart';

import '../main.dart' as main;

var b = Boxes.instance;
var db = FirebaseDatabase.instance.ref();
var fs = FirebaseFirestore.instance;
var st = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
var st_node = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

class ButtonKeys {
  final List<GlobalKey> topButtonKeys;
  final List<GlobalKey> bottomButtonKeys;
  ButtonKeys._()
      : topButtonKeys = [
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
        ],
        bottomButtonKeys = [
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
          GlobalKey(),
        ];

  static ButtonKeys? _instance;
  static ButtonKeys get instance => _instance ??= ButtonKeys._();
}

String mediaPath(String mediaID, {bool isThumbnail = false}) =>
    "${b.docPath}/$mediaID${isThumbnail ? "-TN" : ""}";

Future<void> deleteMediaFile(String path) async {
  try {
    await File(path).delete();
  } on PathNotFoundException catch (e) {
    print("Cannot delete, this file is external: $e");
  } catch (e) {
    print("Cannot delete this file for this reason: $e");
  }
}

String messagePushId() => db.child("Messages").push().key!;

Future<MessageMedia?> downloadAndWriteMedia(
  String mediaID, {
  bool isNodeMedia = false,
}) async {
  final mediaRef = isNodeMedia ? st_node.ref(mediaID) : st.ref(mediaID);
  try {
    final futureMediaData = mediaRef.getData(31457280); // 30mib
    final fullMetadata = await mediaRef.getMetadata();
    final customMetadata = fullMetadata.customMetadata as Map<String, String>;
    final mediaMetadata = MediaMetadata.fromJson(customMetadata);
    final path = "${b.docPath}/$mediaID";
    final mediaData = await futureMediaData;
    if (mediaData != null) {
      await File(path).writeAsBytes(mediaData);
    }
    return MessageMedia(id: mediaID, path: path, metadata: mediaMetadata);
  } catch (e) {
    print("Error downloading mediaID: $mediaID, isNode: $isNodeMedia\n$e");
    return null;
  }
}

Future<MediaMetadata?> downloadMediaMetadata(String mediaID) async {
  try {
    final fullMetadata = await st.ref(mediaID).getMetadata();
    final jsonMetadata = fullMetadata.customMetadata as Map<String, String>;
    return MediaMetadata.fromJson(jsonMetadata);
  } catch (e) {
    return null;
  }
}

Future<bool> uploadOrUpdateMedia(
  MessageMedia media, {
  bool skipCheck = false, // usually for camera uploads
}) async {
  if (media.file == null) return false;
  final mediaRef = st.ref(media.id);
  if (skipCheck) {
    try {
      await mediaRef.putFile(
        media.file!,
        SettableMetadata(customMetadata: media.metadata.toJson()),
      );
      return true;
    } on FirebaseException catch (e) {
      print("Error uploading file $e");
      return false;
    }
  } else {
    try {
      print("Checking if media ${media.id} is already on firebase!");
      final metadata = (await mediaRef.getMetadata());
      final down4Metadata = MediaMetadata.fromJson(metadata.customMetadata!);
      if (down4Metadata.timestamp.shouldBeUpdated) {
        final newTimeStamp = timeStamp();
        if (newTimeStamp > down4Metadata.timestamp) {
          down4Metadata.timestamp = newTimeStamp;
          await mediaRef.updateMetadata(
            SettableMetadata(customMetadata: down4Metadata.toJson()),
          );
          print("Updated the metadata");
          return true;
        }
      }
      print("No need to update the metadata right away!");
      return true;
    } catch (e) {
      // TODO, find the actual exception we are looking for, docs aren't clear
      // If there's an exception, it should mean that there is no media, so we
      // do the full upload
      try {
        media.metadata.timestamp = timeStamp();
        await mediaRef.putFile(media.file!,
            SettableMetadata(customMetadata: media.metadata.toJson()));
        return true;
      } on FirebaseException catch (e) {
        print("Error uploading file $e");
        return false;
      }
    }
  }
}

Future<File> writeMedia({
  required Uint8List mediaData,
  required String mediaID,
  bool isThumbnail = false,
}) async =>
    File(mediaPath(mediaID, isThumbnail: isThumbnail)).writeAsBytes(mediaData);

Future<File> copyMedia({
  required String fromPath,
  required String mediaID,
  bool isThumbnail = false,
}) async =>
    File(fromPath).copy(mediaPath(mediaID, isThumbnail: isThumbnail));

Future<File?> makeThumbnail({
  required String videoPath,
  required String mediaID,
}) async {
  final tn = await VideoThumbnail.thumbnailData(video: videoPath, quality: 90);
  if (tn != null) {
    return writeMedia(mediaData: tn, mediaID: mediaID, isThumbnail: true);
  }
  return null;
}

extension Saver on ExchangeRate {
  Future<void> save() async {
    return b.personal.put("exchangeRate", jsonEncode(this));
  }
}

extension Getters on Identifier {
  MessageMedia? getLocalMessageMedia() {
    final String? jsonEncoded = b.medias.get(this);
    if (jsonEncoded == null) return null;
    return MessageMedia.fromJson(jsonDecode(jsonEncoded));
  }

  Message? getLocalMessage() {
    final String? jsonEncoded = b.messages.get(this);
    if (jsonEncoded == null) return null;
    return Message.fromJson(jsonDecode(jsonEncoded));
  }

  BaseNode? getLocalNode() {
    final String? jsonEncoded = b.nodes.get(this);
    if (jsonEncoded == null) return null;
    return BaseNode.fromJson(jsonDecode(jsonEncoded));
  }

  Future<void> deleteLocalNode() async {
    return b.nodes.delete(this);
  }
}

extension MessageSave on Message {
  Future<void> onReceipt() async {
    await save();
    if (mediaID != null) {
      MessageMedia? media = mediaID?.getLocalMessageMedia();
      media ??= await downloadAndWriteMedia(mediaID!);
      if (media != null && media.extension.isVideoExtension()) {
        // we generate a thumbnail
        final tn =
            await VideoThumbnail.thumbnailData(video: media.path, quality: 90);
        if (tn != null) {
          final f = await writeMedia(
              mediaData: tn, mediaID: mediaID!, isThumbnail: true);
          media.thumbnail = f.path;
        }
      }

      media
        ?..references.add(id)
        ..save();
    }
    return;
  }

  Future<void> save() async {
    return b.messages.put(id, jsonEncode(toJson(toLocal: true)));
  }

  Future<void> delete() async {
    final MessageMedia? media = mediaID?.getLocalMessageMedia();
    if (media != null) {
      media.references.remove(id);
      media.delete();
    }
    await b.messages.delete(id);
    return;
  }
}

extension NodeSave on BaseNode {
  void save() {
    if (this is Self) {
      b.personal.put("self", jsonEncode(toJson(toLocal: true)));
    } else {
      b.nodes.put(id, jsonEncode(toJson(toLocal: true)));
    }
  }

  void delete() {
    var node = this;
    if (node is ChatableNode && node is! Self) {
      for (var messageID in node.messages) {
        var msg = messageID.getLocalMessage();
        if (msg != null && !msg.isSaved) msg.delete();
      }
      b.nodes.delete(id);
    }
  }
}

extension MediaSave on MessageMedia {
  Future<void> save() async {
    return b.medias.put(id, jsonEncode(toJson(toLocal: true)));
  }

  Future<void> delete() async {
    if (references.isEmpty && !isSaved) {
      print("References are empty, deleting the file!");
      b.medias.delete(id);
      deleteMediaFile(path);
      if (thumbnail != null) {
        deleteMediaFile(thumbnail!);
      }
    }
    return;
  }
}

extension PaymentSave on Down4Payment {
  Future<void> save() =>
      b.payments.put(id, jsonEncode(toJson(withImages: true)));
}

extension WalletSave on Wallet {
  Future<void> save() => b.personal.put("wallet", jsonEncode(toJson()));
}

class Boxes {
  static Boxes? _instance;
  static Self? _self;
  String docPath, tempPath;
  Box personal, nodes, messages, medias, messageQueue, bills, payments;
  Boxes()
      : docPath = main.docDirPath,
        tempPath = main.tempDirPath,
        medias = Hive.box("Medias"),
        personal = Hive.box("Personal"),
        nodes = Hive.box("Nodes"),
        messages = Hive.box("Messages"),
        messageQueue = Hive.box("MessageQueue"),
        bills = Hive.box("Bills"),
        payments = Hive.box("Payments");

  static Boxes get instance => _instance ??= Boxes();

  static Self get self => _self ??= loadSelf()!;
}

class Sizes {
  static double h = 0;
  static double w = 0;
  static double fullHeight = 0;
  static double headerHeight = 0;
  static Size get fullSize => Size(w, fullAspectRatio);
  static Size get paddedSize => Size(w, h);
  static double get viewPaddingHeight => fullHeight - h;
  static double get fullAspectRatio => w / fullHeight;
  static double get paddedAspectRatio => w / h;
}

class Sizes2 {
  Sizes2._()
      : w = 0,
        h = 0;
  double w, h;
  static Sizes2? _instance;
  Sizes2 get instance => _instance ??= Sizes2._();
}

Self? loadSelf() {
  final String? jsonEncodedSelf = b.personal.get("self");
  if (jsonEncodedSelf == null) return null;
  return BaseNode.fromJson(jsonDecode(jsonEncodedSelf)) as Self;
}

Wallet? loadWallet() {
  final String? jsonEncodedWallet = b.personal.get("wallet");
  if (jsonEncodedWallet == null) return null;
  return Wallet.fromJson(jsonDecode(jsonEncodedWallet));
}

ExchangeRate loadExchangeRate() {
  final String? jsonEncodedExchangeRate = b.personal.get("exchangeRate");
  if (jsonEncodedExchangeRate != null) {
    return ExchangeRate.fromJson(jsonDecode(jsonEncodedExchangeRate));
  } else {
    return ExchangeRate(lastUpdate: 0, rate: 0.0);
  }
}
