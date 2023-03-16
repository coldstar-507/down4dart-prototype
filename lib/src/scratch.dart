import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

import 'dart:math' as math;

abstract class Jeff {
  void lol();
}

abstract class Scott {
  void fuckyou();
}

abstract class Helene {
  void jeff();
}

class Andrew implements Scott, Jeff {
  Andrew();
  @override
  void fuckyou() => print("FUCK YOU");
  void lol() => print("LOL");
}

void main() async {
  var andrew = Andrew();

  print(andrew is Scott);
  print(andrew is Jeff);
  print(andrew is Helene);

  return;
}
