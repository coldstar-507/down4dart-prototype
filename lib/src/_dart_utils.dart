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

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

// extension QuoteQuote on String {
//   String get sqlReady {
//     final sbuf = StringBuffer("'");
//     sbuf.write(replaceAll("'", "''"));
//     sbuf.write("'");
//     return sbuf.toString();
//   }
// }

// extension SQLiteExtensions on Iterable<String> {
//   String get valuesInParenthesis {
//     final sbuf = StringBuffer("(");
//     sbuf.writeAll(map((e) => e.sqlReady), ",");
//     sbuf.write(")");
//     return sbuf.toString();
//   }

//   String get keysInParenthesis {
//     final sbuf = StringBuffer("(");
//     sbuf.writeAll(this, ",");
//     sbuf.write(")");
//     return sbuf.toString();
//   }

//   String get keysNoParenthesis {
//     final sbuf = StringBuffer();
//     sbuf.writeAll(this, ",");
//     return sbuf.toString();
//   }
// }

// mixin Sql on Map<String, String>, Down4Object, Locals {
//   String get sqlInsertStr {
//     return """
//     INSERT INTO $table
//     ${keys.keysInParenthesis}
//     VALUES ${values.valuesInParenthesis}
//     """;
//   }

//   String get updateKeyValueStr {
//     // key1 = 'val1', key2 = 'val2'
//     final buf = StringBuffer();
//     buf.writeAll(entries.map((e) => "${e.key} = ${e.value.sqlReady}"), ",");
//     return buf.toString();
//   }

//   String get sqlUpdateStr {
//     return """
//     UPDATE $table
//     SET $updateKeyValueStr
//     WHERE id = '$id';
//     """;
//   }
// }



const videoExtensions = ["mp4", "3gp", "webm", "mkv", "m4a", "mov"];
const videoMimes = [
  "video/mp4",
  "video/3pg",
  "video/webm",
  "video/mkv",
  "video/m4a",
  "video/mov"
];

const imageExtensions = ["jpeg", "jpg", "png", "gif", "bmp", "webp"];
const imageMimes = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/bmp",
  "image/webp"
];

const animatedImageExtensions = ["apng", "gif"];
const animatedImageMimes = ["image/apng", "image/gif"];

String youKnowEncode(dynamic j) {
  final valid = j is List || j is Map;
  if (!valid) throw '${j.runtimeType} is not valid type for youKnowEncoding';
  return base64Encode(utf8.encode(jsonEncode(j)));
}

dynamic youKnowDecode(String yk) {
  return jsonDecode(utf8.decode(base64Decode(yk)));
}

enum MediaType { images, gifs, videos }

const Map<MediaType, List<String>> extMap = {
  MediaType.videos: videoExtensions,
  MediaType.images: imageExtensions,
  MediaType.gifs: animatedImageExtensions,
};

const Map<MediaType, List<String>> mimeMap = {
  MediaType.videos: videoMimes,
  MediaType.images: imageMimes,
  MediaType.gifs: animatedImageMimes,
};

extension Caster on Object {
  T asType<T>() => this as T;
}

extension StringListFormattedForSQL on Iterable<String> {
  String get sqlFmt => map((e) => "'$e'").toString();
}

extension TrySingleWhere<T> on Iterable<T> {
  T? find(T e) {
    for (final e_ in this) {
      if (e == e_) return e_;
    }
    return null;
  }

  T? findWhere(bool Function(T) f) {
    for (final e in this) {
      if (f(e)) return e;
    }
    return null;
  }
}

double calcDistance(num x1, num y1, num x2, num y2) {
  return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
}

String makePrefix(int ms) {
  const differ = 78364164096; // 36^6
  final inSeconds = ms ~/ 1000;
  final diffed = differ - inSeconds;
  return diffed.toRadixString(36);
}

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
  Iterable<GroupN> groups() => whereType<GroupN>();
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
  List<int> toUtf8() => utf8.encode(this);
  List<int> toUtf16() => codeUnits;
  String capitalize() =>
      "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  String mime() => lookupMimeType(this)!;
  String extension() => extensionFromMime(mime());
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
