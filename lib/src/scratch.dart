import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

import 'dart:math' as math;

int jeff() {
  return 123;
}

void main() async {
  print(jeff());

  final g = Iterable.generate(100, (i) => i);

  Future(() => g.forEach(print));

  print(jeff());

  return;
}
