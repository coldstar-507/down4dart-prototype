import 'package:english_words/english_words.dart' as w;
import 'down4_utility.dart' show randomPairs, timeStamp, randomPrompts;

import 'dart:convert';

void main() async {
  // var randomPair = randomPairs(1).first;
  // print("${randomPair.first} ${randomPair.second}");
  // final randomWordPair = w.generateWordPairs(safeOnly: false).take(10);
  // print("${randomWordPair.first} ${randomWordPair.second}");

  // print(randomWordPair.map((e) => "${e.first} ${e.second}\n").toList());

  var prompts = randomPrompts(10);
  prompts.forEach(print);
  return;
}
