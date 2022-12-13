import 'dart:async';

import 'package:down4/src/down4_utility.dart';
import 'package:english_words/english_words.dart' as w;
import 'dart:math' as math;

Iterable<Pair<String, String>> randomPairs(int count) {
  final random = math.Random();

  return Iterable.generate(
    count,
    (_) => Pair(
      w.adjectives[random.nextInt(w.adjectives.length)],
      w.nouns[random.nextInt(w.nouns.length)],
    ),
  );
}

void main() async {
  // var noun = w.
  // var adjective = w.adjectives.take(1);
  print(w.adjectives.length);
  print(w.nouns.length);

  var randomPair = randomPairs(1).first;
  print("${randomPair.first} ${randomPair.second}");
  final randomWordPair = w.WordPair.random(safeOnly: false);
  print("${randomWordPair.first} ${randomWordPair.second}");

  return;
}
