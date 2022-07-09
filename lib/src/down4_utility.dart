import 'package:hex/hex.dart';
import 'package:dartsv/dartsv.dart' as sv;
import 'dart:typed_data';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}

String deterministicHyperchatRoot(List<String> ids) {
  final sortedList = ids..sort();
  final asString = sortedList.join("");
  return HEX.encode(sv.sha1(asString.codeUnits));
}

String deterministicGroupRoot(List<String> ids) {
  final sortedList = ids..sort();
  final asString = sortedList.reversed.join("");
  return HEX.encode(sv.sha1(asString.codeUnits));
}

String generateMessageID(String senderID, num timeStamp) {
  final senderCodeUnits = senderID.codeUnits;
  final tsCodeUnits = timeStamp.toString().codeUnits;
  return HEX.encode(sv.sha1(senderCodeUnits + tsCodeUnits));
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

String generateMediaID(Uint8List mediaData) {
  final n = mediaData.length;
  List<int> bytes = [];
  const prime = 97;
  for (int i = 1; i < 101; i++) {
    bytes.add(mediaData[(i * prime) % n]);
  }
  return HEX.encode(sv.sha1(bytes));
}

int timeStamp() {
  return DateTime.now().millisecondsSinceEpoch;
}
