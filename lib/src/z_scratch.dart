import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:base85/base85.dart';
import 'package:image/image.dart' as IMG;

class Jeff {
  Map<String, Set<String>> notableReferences = {};
  Set<String> refs(String name) => notableReferences[name] ??= Set.identity();
}

void main() async {
  final cacaJeff = 'jeffCaca';
  final caca = "jeff is a '$cacaJeff'";
  print(caca);
}
