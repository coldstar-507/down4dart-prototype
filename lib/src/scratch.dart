import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

import 'dart:math' as math;

void main() async {
  final g = Iterable.generate(100, (i) => i).toList();

  while (g.isNotEmpty) {
    final i = g.removeLast();
    print(i);
  }

  return;
}
