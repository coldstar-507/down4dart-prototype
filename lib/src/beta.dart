// import 'dart:async';
import 'dart:typed_data';

// import 'package:down4/src/down4_utility.dart';
// import 'package:english_words/english_words.dart' as w;
import 'dart:math' as math;

// import 'package:pointycastle/export.dart';

// import 'package:flutter/foundation.dart';

mixin Lol {
  lol() => print("LOL");
}

class Jeff with Lol {
  String name;
  Jeff({required this.name});
}

void main() async {
  final jeff = Jeff(name: "jeff");

  jeff.lol();

  print(jeff is Jeff);

  print(jeff is Lol);

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
