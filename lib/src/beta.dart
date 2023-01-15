// import 'dart:async';
import 'dart:typed_data';

// import 'package:down4/src/down4_utility.dart';
// import 'package:english_words/english_words.dart' as w;
import 'dart:math' as math;

// import 'package:pointycastle/export.dart';

// import 'package:flutter/foundation.dart';

void main() async {
  final maxInt = 1 << 32;
  final maxIntBuf = Uint8List(4).buffer.asByteData()
    ..setUint32(0, (1 << 32) - 1);

  final unsafeBuf = Uint8List(4).buffer.asByteData()
    ..setUint32(0, math.Random().nextInt(1 << 32));

  print("MAX INT = $maxInt");
  print("MAX INT BUF = ${maxIntBuf.buffer.asUint8List()}");
  print("UNSAFE BUF = ${unsafeBuf.buffer.asUint8List()}");

  // var noun = w.
  // var adjective = w.adjectives.take(1);
  // print(w.adjectives.length);
  // print(w.nouns.length);
  //
  // var randomPair = randomPairs(1).first;
  // print("${randomPair.first} ${randomPair.second}");
  // final randomWordPair = w.WordPair.random(safeOnly: false);
  // print("${randomWordPair.first} ${randomWordPair.second}");

  return;
}
