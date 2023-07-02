import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:mime/mime.dart';
import 'bsv/_bsv_utils.dart';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'dart:io';
import 'package:bs58/bs58.dart';
import 'dart:math' as math;

import 'data_objects/_data_utils.dart';
import 'data_objects/nodes.dart';

const golden = 1.618;

const videoExtensions = ["mp4", "3gp", "webm", "mkv", "m4a", "mov"];

const imageExtensions = ["jpeg", "jpg", "png", "gif", "bmp", "webp", "apng"];

const animatedImageExtensions = ["apng", "gif"];

double calcDistance(num x1, num y1, num x2, num y2) {
  return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
}

String makePrefix(int ms) {
  const differ = 78364164096; // 36^6
  final inSeconds = ms ~/ 1000;
  final diffed = differ - inSeconds;
  return diffed.toRadixString(36);
}

// extension TrimmedExtensions on List<String> {
//   List<String> withoutDots() => map((e) => e.substring(1)).toList();
// }

final listEqual = const ListEquality().equals;

class Pair<E, F> {
  final E first;
  final F second;
  const Pair(this.first, this.second);
}

Future<bool> hasNetwork() async {
  try {
    final result = await InternetAddress.lookup('amazon.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

String generateMessageID(String senderID, num timeStamp) {
  return sha1(utf8.encode(senderID + timeStamp.toString())).toBase58();
}

// ComposedID deterministicMediaID(Uint8List mediaData, Down4ID selfID) {
//   final selfData = utf8.encode(selfID.unique);
//   return ComposedID(sha1(mediaData + selfData).toBase58());
// }

Uint8List randomBytes({int size = 16}) {
  return Uint8List.fromList(
    List<int>.generate(size, (_) => math.Random().nextInt(256)),
  );
}

String randomMediaID() {
  return randomBytes().toBase58();
}

int makeTimestamp() => DateTime.now().toUtc().millisecondsSinceEpoch;

extension IterableNodes on Iterable<Down4Node> {
  List<Down4Node> formatted() =>
      toList(growable: false)..sort((a, b) => b.activity.compareTo(a.activity));
  Iterable<Down4ID> asIDs() => map((node) => node.id);
  Iterable<ComposedID> asComposedIDs() =>
      map((node) => node.id).whereType<ComposedID>();
  Iterable<Down4Node> those(List<Down4ID> ids) =>
      where((node) => ids.contains(node.id));
  Iterable<GroupNode> groups() => whereType<GroupNode>();
  Iterable<User> users() => whereType<User>();
}

extension ListExtensions on List {
  (T? previous, T? next) surroundings<T>(T element) {
    final index = indexOf(element);
    T? previous, next;
    if (index != 0) previous = this[index - 1];
    if (index != length - 1) next = this[index + 1];
    return (previous, next);
  }
}

extension AsUint8List on List<int> {
  Uint8List toUint8List() => Uint8List.fromList(this);
}

extension ByteEncoding on List<int> {
  String toHex() => hex.encode(this);
  String toBase58() => base58.encode(toUint8List());
  String toUtf16() => String.fromCharCodes(this);
  String toBase64() => base64Encode(this);
}

extension StringExtension on String {
  List<int> asUtf8() => utf8.encode(this);
  List<int> asUtf16() => codeUnits;
  String capitalize() =>
      "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  String mime() => lookupMimeType(this)!;
  String extension() => extensionFromMime(mime());
  // String extension() => p.extension(this);
  bool isVideoExtension() => videoExtensions.contains(this);
  bool isImageExtension() => imageExtensions.contains(this);
}

extension Down4TimestampExpiration on int? {
  bool get isExpired {
    if (this == null) return true;
    final now = DateTime.now();
    final expirationDate =
        DateTime.fromMillisecondsSinceEpoch(this!).add(const Duration(days: 4));
    return now.isAfter(expirationDate);
  }

  bool get shouldBeUpdated {
    if (this == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - this!;
    final duration = Duration(milliseconds: diff);
    return duration.inDays > 20;
  }
}
