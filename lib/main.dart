import 'package:flutter/material.dart';
import 'src/kernel.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

// Test
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  runApp(const MaterialApp(home: Down4()));
}
