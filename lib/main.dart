import 'package:flutter/material.dart';
import 'src/kernel.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (err) {
    print(err.toString());
  }
  // for (var camera in cameras) {
  //   print(camera.toString());
  // }
  var dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  runApp(MaterialApp(
      home: Scaffold(body: SafeArea(child: Down4(cameras: cameras)))));
}
