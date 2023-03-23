import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;

void main() async {
  final jeff = Iterable.generate(10, (i) => Future.value(i));

  final caca = await Future.wait(jeff);

  print(caca);

  return;
}
