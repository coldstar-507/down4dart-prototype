import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp, randomPrompts;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

// var caca = (1, "1");

class Jeff {
  String s;
  int i;
  Jeff(this.i) : s = i.toString();
}

var jeff = Iterable.generate(1000000, (int i) => Jeff(i));

void main() async {
  var t1 = timeStamp();
  var val = jeff.take(500000).toList();
  var t2 = timeStamp();

  print("First iteration took ${t2 - t1} ms");

  t1 = timeStamp();
  var val2 = jeff.take(500000).toList();
  t2 = timeStamp();

  print("Second iteration took ${t2 - t1} ms");

  return;
}
