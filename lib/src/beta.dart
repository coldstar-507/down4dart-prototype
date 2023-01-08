// import 'dart:async';
import 'dart:typed_data';

// import 'package:down4/src/down4_utility.dart';
// import 'package:english_words/english_words.dart' as w;
import 'dart:math' as math;

// import 'package:pointycastle/export.dart';

// import 'package:flutter/foundation.dart';

void main() async {
  var lol = [
    [1, 2, 3],
    [4, 5, 6]
  ];

  var jeff = [];
  for (var l in lol) {
    jeff.add(l);
  }

  var caca = lol.fold<List<int>>(<int>[], (p, e) => p + e);
  print(jeff);
  print(caca);

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
