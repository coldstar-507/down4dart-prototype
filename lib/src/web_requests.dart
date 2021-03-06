import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'data_objects.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> usernameIsValid(String username) async {
  if (username.length < 3) {
    return false;
  }
  if (username.length > 15) {
    return false;
  }
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/IsValidUsername");
  final res = await http.post(uri, body: username);
  return res.statusCode == 200;
}

Future<String?> generateMnemonic() async {
  final uri = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/GenerateMnemonic");
  final res = await http.post(uri);
  if (res.statusCode == 200) {
    return res.body;
  }
  return null;
}

Future<bool> initUser(String encodedJson) async {
  final uri =
      Uri.parse("https://us-east1-down4-26ee1.cloudfunctions.net/InitUser");
  final res = await http.post(uri, body: encodedJson);
  return res.statusCode == 200;
}

Future<List<Node>?> getNodes(List<String> ids) async {
  final url =
      Uri.parse("https://us-east1-down4-26ee1.cloudfunctions.net/GetNodes");
  final res = await http.post(url, body: ids.join(" "));
  final jsonLists = List<Map<String, dynamic>>.from(jsonDecode(res.body));
  if (res.statusCode == 200) {
    return jsonLists.map((e) => Node.fromJson(e)).toList();
  }
  return null;
}

Future<MediaMetadata?> getMediaMetadata(String id) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/GetMediaMetadata",
  );
  final res = await http.post(url, body: id);
  if (res.statusCode != 200) {
    return null;
  }
  return MediaMetadata.fromJson(jsonDecode(res.body));
}

Future<Down4Media?> getMessageMedia(String id) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/GetMessageMedia",
  );
  final res = await http.post(url, body: id);
  if (res.statusCode == 200) {
    return Down4Media.fromJson(jsonDecode(res.body));
  }
  return null;
}

Future<bool> messageRequest(MessageRequest req, [retried = false]) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandleMessageRequest",
  );
  final res = await http.post(url, body: jsonEncode(req));
  if (res.statusCode == HttpStatus.noContent && retried == false) {
    return messageRequest(
      req
        ..withUpload = true
        ..msg.media?.metadata.timestamp = DateTime.now().millisecondsSinceEpoch,
      true,
    );
  }
  return res.statusCode == 200;
}

Future<int> refreshTokenRequest(String newToken) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/RefreshToken",
  );
  final res = await http.post(url, body: newToken);
  return res.statusCode;
}

Future<List<Down4Message>?> getPosts(List<String> ids) async {
  // TODO: getPosts
  return null;
}
