import 'dart:convert';

import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:pointycastle/digests/sha1.dart' as sha1;
import 'data_objects.dart';
import 'package:collection/collection.dart';
import 'dart:io';
import 'package:bs58/bs58.dart';
import 'dart:math' as math;
import 'package:english_words/english_words.dart' as w;

final listEqual = const ListEquality().equals;

// class XList<E> {
//   List<E> list;
//   XList(this.list);
//   E? operator [](int position) {
//     try {
//       return list[position];
//     } on RangeError {
//       return null;
//     }
//   }
// }

class Pair<E, F> {
  final E first;
  final F second;
  Pair(this.first, this.second);
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

  final hash = sha1.SHA1Digest().process(asString.codeUnits.toUint8List());
  return hex.encode(hash);
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
  final hash = sha1.SHA1Digest().process(asString.codeUnits.toUint8List());
  return hex.encode(hash);
}

String generateMessageID(String senderID, num timeStamp) {
  final senderCodeUnits = senderID.codeUnits;
  final tsCodeUnits = timeStamp.toString().codeUnits;
  final data = (senderCodeUnits + tsCodeUnits).toUint8List();
  final hash = sha1.SHA1Digest().process(data);
  return hex.encode(hash);
}

String generateMediaID(Uint8List mediaData) {
  final n = mediaData.length;
  List<int> bytes = [];
  const prime = 97;
  for (int i = 1; i < 101; i++) {
    bytes.add(mediaData[(i * prime) % n]);
  }
  return hex.encode(sha1.SHA1Digest().process(bytes.toUint8List()));
}

int timeStamp() => DateTime.now().millisecondsSinceEpoch;

extension StringIterables on List<String> {
  Iterable<String> noDuplicates() {
    List<String> singles = [];
    for (final s in this) {
      if (!singles.contains(s)) singles.add(s);
    }
    return singles;
  }
}

extension IterableNodes on Iterable<BaseNode> {
  List<BaseNode> formatted() =>
      toList(growable: false)..sort((a, b) => b.activity.compareTo(a.activity));
  Iterable<String> asIds() => map((node) => node.id);
  Iterable<BaseNode> those(List<Identifier> ids) =>
      where((node) => ids.contains(node.id));
  Iterable<GroupNode> groups() => whereType<GroupNode>();
  Iterable<User> users() => whereType<User>();
  // Iterable<BaseNode> hiddenUsers(List<Identifier> friendIds) {
  //       var usersInGroupsIds = groups()
  //           .map((group) => group.group)
  //           .flattened
  //           .toSet()
  //           .where((element) => false)
  //           .toList(growable: false);
  //
  //       return those(usersInGroupsIds);
  //     }
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
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

extension Down4TimestampExpiration on int {
  bool get isExpired {
    final now = DateTime.now();
    final expirationDate = DateTime.fromMillisecondsSinceEpoch(this).add(
      const Duration(days: 4),
    );
    return now.isAfter(expirationDate);
  }
}

extension Down4TimestampUnder16HoursLeft on int {
  bool get shouldBeUpdated {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - this;
    final duration = Duration(minutes: diff);
    return duration.inHours > 80;
  }
}
