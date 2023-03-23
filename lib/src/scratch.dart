import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;

class Jeff {
  int i = 0;
}

Future<void> modifyJeff(Jeff jeff) async {
  jeff.i = 1;
  await Future(() {
    jeff.i = 2;
  });
}

void main() async {
  var jeff = Jeff();
  modifyJeff(jeff);
  print(jeff.i);
}
