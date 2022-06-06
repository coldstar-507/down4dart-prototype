import 'dart:convert';
import 'package:http/http.dart' as http;
import 'data_objects.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> usernameIsValid(String username) async {
  if (username.length < 3) {
    return false;
  }
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/IsValidUsername");
  final res = await http.post(uri, body: username);
  return res.statusCode == 200;
}

Future<MoneyInfo> initUserMoney(String username) async {
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/InitUserMoney");
  final res = await http.post(uri, body: username);
  final data = MoneyInfo.fromJson(json.decode(res.body));
  return data;
}

Future<bool> initUser(String encodedJson) async {
  final uri =
      Uri.parse("https://us-east1-down4-26ee1.cloudfunctions.net/InitUser");
  final res = await http.post(uri, body: encodedJson);
  return res.statusCode == 200;
}

// Future<Node?> getUserNode(String username) async {
//   var ref = FirebaseDatabase.instance.ref("Users/" + username);
//   final snapshot = await ref.get();
//   if (snapshot.exists) {
//     final data =
//         Map<String, dynamic>.from(snapshot.value as Map<String, dynamic>);
//     var node = Node.fromJson(data);
//     await node.image.downloadData();
//     return node;
//   }
//   return null;
// }

Future<List<Node>?> getNodes(List<String> ids) async {
  final uri =
      Uri.parse("https://us-east1-down4-26ee1.cloudfunctions.net/GetNodes");
  final res = await http.post(uri, body: ids.join(" "));
  final jsonLists = List<Map<String, dynamic>>.from(jsonDecode(res.body));
  if (res.statusCode == 200) {
    return jsonLists.map((e) => Node.fromJson(e)).toList();
  }
  return null;
}

Future<Down4Image?> getMessageMedia(String id) async {
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/GetMessageMedia");
  final res = await http.post(uri, body: id);
  if (res.statusCode == 200) {
    return Down4Image(id: id, data: res.bodyBytes);
  }
  return null;
}

Future<String?> getMessageMediaURL(String id) async {
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/GetMessageMediaURL");
  final res = await http.post(uri, body: id);
  if (res.statusCode == 200) {
    return res.body;
  }
  return null;
}

Future<int> refreshTokenRequest(String newToken) async {
  final uri =
      Uri.parse("https://us-east1-down4-26ee1.cloudfunctions.net/RefreshToken");
  final res = await http.post(uri, body: newToken);
  return res.statusCode;
}

Future<String> getMessagingToken(String username) async {
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/GetMessagingToken");
  final res = await http.post(uri, body: username);
  return res.body;
}

Future<bool> messageRequest(MessageRequest mr) async {
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleMessageRequest");
  final res = await http.post(uri, body: jsonEncode(mr.toGoogle()));
  if (res.statusCode == 200) {
    return true;
  }
  return false;
}
