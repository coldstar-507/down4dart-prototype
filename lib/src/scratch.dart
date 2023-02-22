import 'package:english_words/english_words.dart' as w;
import '_down4_dart_utils.dart' show randomPairs, timeStamp, randomPrompts;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

void main() async {
  var jeff = List<String>.generate(10000, (index) => index.toString());
  var scott = jeff.toSet();
  int t1, t2;
  t1 = timeStamp();
  var andrew = jeff.reversed.toList();
  t2 = timeStamp();
  print("REVERSING A MILLION STRINGS TOOK ${t2 - t1} MS");

  t1 = timeStamp();
  var david = scott.toList().reversed.toList();
  t2 = timeStamp();
  print("TO SET TO LIST REVERSED TO LIST TOOK ${t2 - t1} MS");

  // Map<int, String> andrew = jeff.asMap();
  // Map<String, String> scott =
  //     andrew.map((key, value) => MapEntry(key.toString(), value));

  // int t1, t2;
  // {
  //   t1 = timeStamp();
  //   print("jeff contains 194353 = ${jeff.contains("194353")}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("andrew contains 194353 = ${andrew[194353] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("scott contains 194353 = ${scott["194353"] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");
  // }

  // {
  //   t1 = timeStamp();
  //   print("jeff contains 594353 = ${jeff.contains("594353")}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("andrew contains 594353 = ${andrew[594353] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("scott contains 594353 = ${scott["594353"] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");
  // }

  // {
  //   t1 = timeStamp();
  //   print("jeff contains 994353 = ${jeff.contains("994353")}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("andrew contains 994353 = ${andrew[994353] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("scott contains 994353 = ${scott["994353"] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");
  // }

  // {
  //   t1 = timeStamp();
  //   print("jeff contains 1994353 = ${jeff.contains("1994353")}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("andrew contains 1994353 = ${andrew[1994353] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");

  //   t1 = timeStamp();
  //   print("scott contains 1994353 = ${scott["1994353"] != null}");
  //   t2 = timeStamp();
  //   print("took ${t2 - t1} MS");
  // }

  return;
}
