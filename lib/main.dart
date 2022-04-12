import 'package:flutter/material.dart';
import 'src/kernel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var localDatabase = await getLocalDatabase();
  runApp(MaterialApp(home: Down4(localDatabase: localDatabase)));
}
