import 'package:english_words/english_words.dart' as w;
import 'down4_utility.dart' show randomPairs, timeStamp;

import 'dart:convert';

class Andrew {
  int scott;
  Andrew({required this.scott});
}

class Jeff {
  final Andrew andrew;
  Jeff({required this.andrew});
}

void main() async {
  final andrew = Andrew(scott: 4);
  print(andrew.scott);
  andrew.scott = 6;
  print(andrew.scott);

  final Jeff jeff = Jeff(andrew: andrew);

  jeff.andrew.scott = 7;
  print(jeff.andrew.scott);

  // print(timeStamp());
  //
  // var randomPair = randomPairs(1).first;
  // print("${randomPair.first} ${randomPair.second}");
  // final randomWordPair = w.generateWordPairs(safeOnly: false).take(10);
  // print("${randomWordPair.first} ${randomWordPair.second}");

  // print(randomWordPair.map((e) => "${e.first} ${e.second}\n").toList());

  return;
}
