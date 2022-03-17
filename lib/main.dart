import 'package:flutter/material.dart';
import 'src/kernel.dart';

void main() async {
  var localDatabase = await getLocalDatabase();
  runApp(MaterialApp(home: Down4(localDatabase: localDatabase)));
}
