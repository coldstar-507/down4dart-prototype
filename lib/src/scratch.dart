import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp, randomPrompts;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

class Jeff {
  int i;
  String s;
  Jeff(this.i) : s = i.toRadixString(2);
}

class GlobalJeff {
  static Jeff? _jeff;
  static Jeff get jeff => _jeff ??= Jeff(2);
}

void main() async {
  var jeff = -10000;

  print("$jeff sat");

  return;
}
