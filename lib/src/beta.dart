import 'package:english_words/english_words.dart' as w;
import 'down4_utility.dart' show randomPairs, timeStamp, randomPrompts;
import 'bsv/utils.dart' as u;
import 'dart:typed_data';
import 'dart:convert';

var nigger = Iterable.generate(10, (i) => i);

void main() async {
  var jeff2 = List<String>.generate(
    2000,
    (index) => base64.encode(u.sha1(u.makeUint32(index))),
  );

  var ts1 = timeStamp();
  jeff2.reversed.toList();
  var ts2 = timeStamp();

  var dt = DateTime.fromMillisecondsSinceEpoch(ts2)
      .difference(DateTime.fromMillisecondsSinceEpoch(ts1));

  // print("REVERSING 2000 ELEMENT STRING LIST TOOK = ${dt.inMicroseconds} MS");

  return;
}
