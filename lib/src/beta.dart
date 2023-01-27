import 'package:english_words/english_words.dart' as w;
import 'down4_utility.dart' show randomPairs, timeStamp, randomPrompts;


class Jeff {
  int i;
  String asString;
  Jeff(this.i) : asString = i.toString();
}

void main() async {
  final n = 1000;

  var it = Iterable.generate(n, (i) => Jeff(i));
  var l = List.generate(n, (i) => Jeff(i));

  var t1 = timeStamp();
  for (int i = 0; i < n; i++) {
    var lol = l[i];
  }
  var t2 = timeStamp();

  var dt1 = DateTime.fromMillisecondsSinceEpoch(t1);
  var dt2 = DateTime.fromMillisecondsSinceEpoch(t2);

  print("LIST TOOK ${dt2.difference(dt1).inMicroseconds}");

  t1 = timeStamp();
  for (int i = 0; i < n; i++) {
    var lol = it.elementAt(i);
  }
  t2 = timeStamp();

  dt1 = DateTime.fromMillisecondsSinceEpoch(t1);
  dt2 = DateTime.fromMillisecondsSinceEpoch(t2);

  print("ITERABLE TOOK ${dt2.difference(dt1).inMicroseconds}");

  // var randomPair = randomPairs(1).first;
  // print("${randomPair.first} ${randomPair.second}");
  // final randomWordPair = w.generateWordPairs(safeOnly: false).take(10);
  // print("${randomWordPair.first} ${randomWordPair.second}");

  // print(randomWordPair.map((e) => "${e.first} ${e.second}\n").toList());

  // print(jeff is List);
  // print(andrew is List);
  //
  // for (int i = 0; i < 5; i = i + 2) {
  //   print(andrew.skip(i).take(2));
  // }

  // print(prompts);

  // for (int i = 0; i < prompts.length; i++) {
  //   if (i % 2 == 0) continue;
  //   print(prompts[i]);
  // }

  return;
}
