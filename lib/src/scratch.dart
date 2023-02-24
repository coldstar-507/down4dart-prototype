import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp, randomPrompts;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

import 'dart:math' as math;

double logBase(num x, num base) => math.log(x) / math.log(base);

// we need x = differ - t | x >= 36^k AND x < 36^k+1
// so if we need around seconds time,
// lets find differ where differ - t (in seconds) is close to it 36^k

// so differ could be anything between
// 36^6 + t and 36^7 + t - 1
// so best would be highest since we remove t from it and t grows.

// since differ is so big, we can decide not to add t to it
// this leaves us with ascending order string prefix that
// will put the latest payments first which will work for thousands of years
String makePrefix(int ms) {
  const differ = 78364164096; // 36^6
  final inSeconds = ms ~/ 1000;
  final diffed = differ - inSeconds;
  return diffed.toRadixString(36);
}

void main() async {
  var t = timeStamp();
  t = t ~/ 1000;

  print("t = $t, tLen = ${t.toString().length}");
  for (int i = 0; i < 9; i++) {
    var pow = math.pow(34, i);
    print("pow = $pow, powLen = ${pow.toString().length}");
  }

  return;
}
