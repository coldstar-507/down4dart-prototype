import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:path/path.dart' as p;
import 'bsv/utils.dart';
import 'dart:typed_data';
import 'data_objects.dart';
import 'package:collection/collection.dart';
import 'dart:io';
import 'package:bs58/bs58.dart';
import 'dart:math' as math;
import 'package:english_words/english_words.dart' as w;

const golden = 1.618;

const videoExtensions = [".mp4", ".3gp", ".webm", ".mkv", ".m4a", ".mov"];

const imageExtensions = [
  ".jpeg",
  ".jpg",
  ".png",
  ".gif",
  ".bmp",
  ".webp",
  ".apng"
];

const animatedImageExtensions = [".apng", ".gif"];

String makePrefix(int ms) {
  const differ = 78364164096; // 36^6
  final inSeconds = ms ~/ 1000;
  final diffed = differ - inSeconds;
  return diffed.toRadixString(36);
}

extension TrimmedExtensions on List<String> {
  List<String> withoutDots() => map((e) => e.substring(1)).toList();
}

final listEqual = const ListEquality().equals;

class Pair<E, F> {
  final E first;
  final F second;
  const Pair(this.first, this.second);
}

class Triple<E, F, G> {
  final E first;
  final F second;
  final G third;
  Triple(this.first, this.second, this.third);
}

class Quadruple<E, F, G, H> {
  final E first;
  final F second;
  final G third;
  final H fourth;
  Quadruple(this.first, this.second, this.third, this.fourth);
}

class Quintuple<E, F, G, H, K> {
  final E first;
  final F second;
  final G third;
  final H fourth;
  final K fifth;
  Quintuple(this.first, this.second, this.third, this.fourth, this.fifth);
}

class Sixtuple<E, F, G, H, K, J> {
  final E first;
  final F second;
  final G third;
  final H fourth;
  final K fifth;
  final J sixth;
  Sixtuple(
    this.first,
    this.second,
    this.third,
    this.fourth,
    this.fifth,
    this.sixth,
  );
}

Future<bool> hasNetwork() async {
  try {
    final result = await InternetAddress.lookup('amazon.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

String deterministicHyperchatRoot(List<String> ids) {
  final sortedList = ids..sort();
  final asString = sortedList.join("");
  return sha1(utf8.encode(asString)).toBase64();
}

Iterable<Pair<String, String>> randomPairs(int count) {
  final random = math.Random();

  return Iterable.generate(
    count,
    (_) => Pair(
      w.adjectives[random.nextInt(w.adjectives.length)],
      w.nouns[random.nextInt(w.nouns.length)],
    ),
  );
}

String deterministicGroupRoot(List<String> ids) {
  final sortedList = ids..sort();
  final asString = sortedList.reversed.join("");
  return sha1(utf8.encode(asString)).toBase64();
}

String generateMessageID(String senderID, num timeStamp) {
  return sha1(utf8.encode(senderID + timeStamp.toString())).toBase58();
}

/// FNV-1a 64bit hash algorithm optimized for Dart Strings
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}

String deterministicMediaID(Uint8List mediaData, String selfID) {
  final selfData = utf8.encode(selfID);
  return sha1(mediaData + selfData).toBase58();
}

Uint8List randomBytes({int size = 16}) {
  return Uint8List.fromList(
    List<int>.generate(size, (_) => math.Random().nextInt(256)),
  );
}

String randomMediaID() {
  return randomBytes().toBase58();
}

int timeStamp() => DateTime.now().toUtc().millisecondsSinceEpoch;

extension IterableNodes on Iterable<BaseNode> {
  List<BaseNode> formatted() =>
      toList(growable: false)..sort((a, b) => b.activity.compareTo(a.activity));
  Iterable<String> asIds() => map((node) => node.id);
  Iterable<BaseNode> those(List<ID> ids) =>
      where((node) => ids.contains(node.id));
  Iterable<GroupNode> groups() => whereType<GroupNode>();
  Iterable<User> users() => whereType<User>();
}

extension IsTypes on BaseNode {
  bool get isFriendOrGroup => isFriendUser || this is GroupNode;
  bool get isUserOrGroup => this is User || this is GroupNode;
  bool get isFriendUser => this is User ? (this as User).isFriend : false;
  bool get isPublicGroup => this is Group ? !(this as Group).isPrivate : false;
}

extension AsUint8List on List<int> {
  Uint8List toUint8List() => Uint8List.fromList(this);
}

extension ByteEncoding on List<int> {
  String toHex() => hex.encode(this);
  String toBase58() => base58.encode(toUint8List());
  String toBase64() => base64Encode(this);
}

extension StringExtension on String {
  String capitalize() =>
      "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  String extension() => p.extension(this);
  bool isVideoExtension() => videoExtensions.contains(this);
  bool isImageExtension() => imageExtensions.contains(this);
}

extension Down4TimestampExpiration on int {
  bool get isExpired {
    final now = DateTime.now();
    final expirationDate =
        DateTime.fromMillisecondsSinceEpoch(this).add(const Duration(days: 4));
    return now.isAfter(expirationDate);
  }

  bool get shouldBeUpdated {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - this;
    final duration = Duration(minutes: diff);
    return duration.inHours > 80;
  }
}
