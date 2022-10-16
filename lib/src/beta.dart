import 'package:english_words/english_words.dart' as w;

void main() {
  // var cached = [1, 2, 3, 4, 5];
  // var all = [1, 2, 3, 4, 5, 6, 7];

  // var toFecth = all.toSet().difference(cached.toSet());

  // print(toFecth);

  final wp = w.WordPair.random();

  print("${wp.first} ${wp.second}");

  return;
}
