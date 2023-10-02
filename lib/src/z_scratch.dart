import 'dart:convert';
import 'dart:typed_data';

void main() async {
  final str = "hope~america~1";

  final a = utf8.encode(str);
  final b = str.codeUnits;

  final a_ = Uint8List.fromList(a);
  final b_ = Uint8List.fromList(b);

  print(String.fromCharCodes(a_));
  print(String.fromCharCodes(b_));

  print(a_);
  print(b_);
}
