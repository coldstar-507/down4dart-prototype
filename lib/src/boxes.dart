import 'package:hive/hive.dart';

class Boxes {
  static Boxes? _instance;
  Box images,
      friends,
      user,
      reactions,
      others,
      friendRequests,
      messages,
      messageQueue,
      bills,
      payments,
      hyperchats;
  Boxes()
      : images = Hive.box("Images"),
        friends = Hive.box("Friends"),
        user = Hive.box("User"),
        reactions = Hive.box("Reactions"),
        others = Hive.box("Others"),
        friendRequests = Hive.box("FriendRequests"),
        messages = Hive.box("Messages"),
        messageQueue = Hive.box("MessageQueue"),
        bills = Hive.box("Bills"),
        payments = Hive.box("Payments"),
        hyperchats = Hive.box("Hyperchats");

  //static Boxes get instance => _instance ?? _instance = Boxes();
  static Boxes get instance =>
      _instance == null ? _instance = Boxes() : _instance!;
}
