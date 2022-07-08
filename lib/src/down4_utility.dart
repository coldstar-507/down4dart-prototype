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

String generateMediaID(String uid, Uint8List mediaData) {
  final userCodeUnits = uid.codeUnits;
  if (mediaData.length > 100) {
    final footPrint = mediaData.reversed.toList().getRange(0, 100).toList();
    return HEX.encode(sv.sha1(userCodeUnits + footPrint));
  } else {
    final footPrint = mediaData.reversed.toList();
    return HEX.encode(sv.sha1(userCodeUnits + footPrint));
  }
}

int timeStamp() {
  return DateTime.now().millisecondsSinceEpoch;
}
