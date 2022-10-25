import 'package:english_words/english_words.dart' as w;
import 'web_requests.dart' as r;

import 'bsv/utils.dart';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'down4_utility.dart';
import 'bsv/types.dart';
import 'dart:io' as io;

void main() async {
  var inv =
      "02762e617c2e2f5e90cff0f0528d0bef82f6df96fbf7843eda55e3c16434aa1e2b";
  var ha = "aecca0a192e28a372a7b98a45401c7b09ceb691c";
  var aha = hash160(hex.decode(inv)).toHex();
  print(ha);
  print(aha);



  print("What the fuck is going on");
  var f = io.File("C:\\Users\\coton\\Desktop\\jeff.txt");

  var pkHex = f.readAsStringSync();
  var pair0 = Down4Keys.fromPrivateKey(BigInt.parse(pkHex, radix: 16));
  var pair1 = pair0.derive(makeUint32(1))!;
  var pair2 = pair0.derive(makeUint32(2))!;
  var pair3 = pair0.derive(makeUint32(3))!;

  print("TEST0: ${testnetAddress(pair0.rawCompressedPub).toBase58()}");
  print("TEST1: ${testnetAddress(pair1.rawCompressedPub).toBase58()}");
  print("TEST2: ${testnetAddress(pair2.rawCompressedPub).toBase58()}");
  print("TEST3: ${testnetAddress(pair3.rawCompressedPub).toBase58()}");

  print("TEST0PK: ${pair0.privKeyBase58}");
  print("TEST1PK: ${pair1.privKeyBase58}");
  print("TEST2PK: ${pair2.privKeyBase58}");
  print("TEST3PK: ${pair3.privKeyBase58}");

  var invalid =
      "028a46da101c0650f838492b408e4f193f2b78120f2b81838b67929352040d5fe3";
  var invalidHash = "4656febb085352028cfe492d527b7ebf18d36e3b";
  var ashHash = hash160(hex.decode(invalid)).toHex();
  print(invalidHash);
  print(ashHash);

  // print("hello planet");
  // var valide = "02146e26a4bd92a50bd2fef0f88bdab71650424992340f326d34c1fdde9c408247";
  // var hash = "724ba24e0f1402dbdc52fd978d0acac48e2f6df3";
  // var asHash = hash160(hex.decode(valide)).toHex();
  // print(hash);
  // print(asHash);

  // var pubkey = "028a46da101c0650f838492b408e4f193f2b78120f2b81838b67929352040d5fe3";
  //
  //
  //
  // var raw = hex.decode(pubkey);
  // var address = hash160(raw).toHex();
  //
  // var toCheck = "724ba24e0f1402dbdc52fd978d0acac48e2f6df3";
  //
  // print(address);
  // print(toCheck);
  //
  // return;

  // final wp = w.WordPair.random();
  //
  // print("${wp.first} ${wp.second}");

  return;
}
