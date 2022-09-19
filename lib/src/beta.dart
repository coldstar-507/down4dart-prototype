import 'package:english_words/english_words.dart' as w;

void main() {
  final wp = w.WordPair.random();

  print("${wp.first} ${wp.second}");

  return;
}
