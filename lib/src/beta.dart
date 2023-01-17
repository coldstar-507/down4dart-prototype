// import 'package:english_words/english_words.dart' as w;

import 'dart:convert';

void main() async {
  var jeff = <int>{1, 2, 3, 3};

  var jsonEncoded = jsonEncode({"caca": "caca", "set": jeff.toList()});

  print(jsonEncoded);
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
