import 'dart:async';

import 'package:english_words/english_words.dart' as w;


void main() async {



  final randomWordPair = w.WordPair.random(safeOnly: false);
  print("${randomWordPair.first} ${randomWordPair.second}");

  return;
}
