import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp, randomPrompts;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

import 'dart:math' as math;

double logBase(num x, num base) => math.log(x) / math.log(base);

void main() async {
  var t = timeStamp();
  final differ = math.pow(36, 9).toInt();
  final differ2 = math.pow(36, 8).toInt();

  print("""
  36^9 = $differ
  b36  = ${differ.toRadixString(36)}
  36^8 = $differ2
  b36  = ${differ2.toRadixString(36)}
  ts   = $t
""");

  // final diffed = (differ - t) ~/ 1000;

  // print(diffed);
  // print(diffed.toRadixString(36));

  return;
}
