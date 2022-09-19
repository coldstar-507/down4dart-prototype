import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:pointycastle/digests/sha1.dart' as sha1;
import 'data_objects.dart';
import 'render_objects.dart';

extension PaletteExtensions on List<Palette> {
  List<Node> asNodes() => map((e) => e.node).toList(growable: false);
  List<Palette> selected() => where((p) => p.selected).toList(growable: false);
  List<Identifier> asIds() => map((e) => e.node.id).toList(growable: false);
}

extension IsTypes on Node {
  bool get isFriendOrGroup => const [Nodes.friend, Nodes.group].contains(type);
  bool get isFriend => Nodes.friend == type;
  bool get isUser =>
      const [Nodes.nonFriend, Nodes.friend, Nodes.user].contains(type);
  bool get isGroup => const [Nodes.hyperchat, Nodes.group].contains(type);
}

extension AsUint8List on List<int> {
  Uint8List asUint8List() => Uint8List.fromList(this);
}

extension ByteEncoding on List<int> {
  String toHex() => hex.encode(this);
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
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
  return hex.encode(sha1.SHA1Digest().process(bytes.asUint8List()));
}

int timeStamp() {
  return DateTime.now().millisecondsSinceEpoch;
}
