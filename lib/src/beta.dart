import 'package:english_words/english_words.dart' as w;
import 'down4_utility.dart' show randomPairs, timeStamp, randomPrompts;

import 'dart:convert';

var jeff = {1, 2, 3};

var andrew = Iterable.castFrom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

void main() async {
  // var randomPair = randomPairs(1).first;
  // print("${randomPair.first} ${randomPair.second}");
  // final randomWordPair = w.generateWordPairs(safeOnly: false).take(10);
  // print("${randomWordPair.first} ${randomWordPair.second}");

  // print(randomWordPair.map((e) => "${e.first} ${e.second}\n").toList());

  // print(jeff is List);
  // print(andrew is List);


  for (int i = 0; i < 5; i = i + 2) {
    print(andrew.skip(i).take(2));
  }




  // print(prompts);

  // for (int i = 0; i < prompts.length; i++) {
  //   if (i % 2 == 0) continue;
  //   print(prompts[i]);
  // }

  return;
}
