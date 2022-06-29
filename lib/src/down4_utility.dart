import 'package:hex/hex.dart';
import 'package:dartsv/dartsv.dart' as sv;
import 'dart:typed_data';

extension StringExtension on String {
  String makeLowerCase() {
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
  bool isExpired() {
    final now = DateTime.now();
    final expirationDate = DateTime.fromMillisecondsSinceEpoch(this).add(
      const Duration(days: 4),
    );
    return expirationDate.isAfter(now);
  }
}

extension Down4TimestampUnder16HoursLeft on int {
  bool shouldBeUpdated() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - this;
    final duration = Duration(minutes: diff);
    return duration.inHours > 80; // 4 days
  }
}

String generateBetterMediaID(String uid, Uint8List mediaData) {
  final userCodeUnits = uid.codeUnits;
  if (mediaData.length > 40) {
    final mediaFootPrint = mediaData.getRange(0, 40).toList();
    return HEX.encode(sv.sha1(userCodeUnits + mediaFootPrint));
  } else {
    final mediaFootPrint = mediaData.toList();
    return HEX.encode(sv.sha1(userCodeUnits + mediaFootPrint));
  }
}
