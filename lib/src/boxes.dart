import 'package:hive/hive.dart';
import '../main.dart' as main;

class Boxes {
  static Boxes? _instance;
  String dirPath;
  Box images,
      videos,
      user,
      reactions,
      home,
      messages,
      messageQueue,
      bills,
      payments,
      savedMessages;
  Boxes()
      : dirPath = main.docDirPath,
        user = Hive.box("User"),
        images = Hive.box("Images"),
        videos = Hive.box("Videos"),
        home = Hive.box("Home"),
        reactions = Hive.box("Reactions"),
        messages = Hive.box("Messages"),
        messageQueue = Hive.box("MessageQueue"),
        bills = Hive.box("Bills"),
        payments = Hive.box("Payments"),
        savedMessages = Hive.box("SavedMessages");

  //static Boxes get instance => _instance ?? _instance = Boxes();
  static Boxes get instance =>
      _instance == null ? _instance = Boxes() : _instance!;
}
