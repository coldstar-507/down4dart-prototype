import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:pointycastle/digests/sha1.dart' as sha1;
import 'data_objects.dart';
import 'package:collection/collection.dart';
import 'dart:io';
import 'package:bs58/bs58.dart';

final listEqual = const ListEquality().equals;

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

  final hash = sha1.SHA1Digest().process(asString.codeUnits.asUint8List());
  return hex.encode(hash);
}

String deterministicGroupRoot(List<String> ids) {
  final sortedList = ids..sort();
  final asString = sortedList.reversed.join("");
  final hash = sha1.SHA1Digest().process(asString.codeUnits.asUint8List());
  return hex.encode(hash);
}

String generateMessageID(String senderID, num timeStamp) {
  final senderCodeUnits = senderID.codeUnits;
  final tsCodeUnits = timeStamp.toString().codeUnits;
  final data = (senderCodeUnits + tsCodeUnits).asUint8List();
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
  return hex.encode(sha1.SHA1Digest().process(bytes.asUint8List()));
}

int timeStamp() => DateTime.now().millisecondsSinceEpoch;

extension IterableNodes on Iterable<BaseNode> {
  Iterable<String> asIds() => map((node) => node.id);
}

extension IsTypes on BaseNode {
  bool get isFriendOrGroup => isFriendUser || this is GroupNode;
  bool get isUserOrGroup => this is User || this is GroupNode;
  bool get isFriendUser => this is User ? (this as User).isFriend : false;
  bool get isPublicGroup => this is Group ? !(this as Group).isPrivate : false;
}

extension AsUint8List on List<int> {
  Uint8List asUint8List() => Uint8List.fromList(this);
}

extension ByteEncoding on List<int> {
  String toHex() => hex.encode(this);
  String toBase58() => base58.encode(asUint8List());
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
