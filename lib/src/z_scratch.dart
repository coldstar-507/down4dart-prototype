import 'dart:convert';
import 'dart:typed_data';

import 'package:down4/src/utils/encryption_helper.dart';


final jeff = [159, 109, 222, 178, 209, 115, 109, 106, 44, 2, 31, 84, 115, 23, 14, 185, 158, 6, 46, 30, 108, 72, 194, 30, 88, 201, 15, 237, 175, 235, 3, 94, 216, 32, 77, 91, 135, 13, 41, 42, 114, 166, 65, 33, 3];

void main() async {
  final str = "user~america~1";
  print("""
    str     = $str
    btyes   = ${str.codeUnits}
    hex     = ${bin2hex(Uint8List.fromList(str.codeUnits))}

    jeff    = $jeff
    jeffstr = ${String.fromCharCodes(jeff)}
""");
}
