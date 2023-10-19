import 'dart:convert';
import 'dart:typed_data';

import 'package:down4/src/utils/encryption_helper.dart';

void main() async {
  final jeff = [4, 3, 4, 5];

  print(DateTime.now());
  final l = await Future.wait(jeff.map((e) async {
    return await Future.delayed(const Duration(seconds: 1), () => e);
  }));
  print(DateTime.now());
  print("if it works, should return 1 second later!");
}
