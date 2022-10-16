import 'dart:convert';
import 'dart:io';
import 'package:flutter_testproject/src/down4_utility.dart';
import 'package:http/http.dart' as http;
import 'data_objects.dart';
import 'bsv/types.dart';
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
    "https://us-east1-down4-26ee1.cloudfunctions.net/IsValidUsername",
  );
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

Future<BatchResponse?> broadcastTxs(List<Down4TX> txs) async {
  final uri = Uri.parse("https://api.taal.com/api/v1/batchBroadcast");
  var rawTxs = [];
  for (final tx in txs) {
    rawTxs.add({"rawTx": tx.fullRawHex});
  }
  final res = await http.post(
    uri,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "mainnet_ea21eb661e59bc5733cbbfe945de3a7b",
    },
    body: jsonEncode(rawTxs),
  );
  if (res.statusCode == 200) {
    final decodedJson = jsonDecode(res.body);
    return BatchResponse.fromJson(decodedJson);
  }
  return null;
}

Future<double?> getExchangeRate() async {
  final url = Uri.parse(
    "https://api.whatsonchain.com/v1/bsv/main/exchangerate",
  );
  final res = await http.get(url);
  if (res.statusCode != 200) return null;
  return jsonDecode(res.body)["rate"];
}

Future<bool> pingRequest(PingRequest req) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePingRequest",
  );
  final res = await http.post(url, body: jsonEncode(req));
  return res.statusCode == 200;
}

Future<bool> snipRequest(SnipRequest req) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandleSnipRequest",
  );
  final res = await http.post(url, body: jsonEncode(req));
  return res.statusCode == 200;
}

Future<Node?> groupRequest(GroupRequest req, [withMedia = false]) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandleGroupRequest",
  );
  final res = await http.post(url, body: jsonEncode(req.toJson(withMedia)));
  if (res.statusCode == HttpStatus.noContent) {
    return groupRequest(req, true);
  }
  if (res.statusCode == 200) {
    return Node.fromJson(jsonDecode(res.body));
  } else {
    return null;
  }
}

Future<Node?> hyperchatRequest(
  HyperchatRequest req, [
  bool withMedia = false,
]) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandleHyperchatRequest",
  );
  final res = await http.post(url, body: jsonEncode(req.toJson(withMedia)));
  if (res.statusCode == HttpStatus.noContent) {
    return hyperchatRequest(req, true);
  }
  if (res.statusCode == 200) {
    return Node.fromJson(jsonDecode(res.body));
  } else {
    return null;
  }
}

Future<bool> paymentRequest(PaymentRequest req) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePaymentRequest",
  );
  final res = await http.post(url, body: jsonEncode(req));
  return res.statusCode == 200;
}

Future<bool> chatRequest(ChatRequest req, [withMedia = false]) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandleChatRequest",
  );
  final res = await http.post(url, body: jsonEncode(req.toJson(withMedia)));
  if (res.statusCode == HttpStatus.noContent) {
    return chatRequest(req, true);
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

Future<bool> sendInternetPayment(Down4InternetPayment payment) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePayment",
  );
  final res = await http.post(url, body: jsonEncode(payment));
  return res.statusCode == 200;
}

// Future<bool> messageRequest(MessageRequest req, [retried = false]) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/HandleMessageRequest",
//   );
//   final res = await http.post(url, body: jsonEncode(req));
//   if (res.statusCode == HttpStatus.noContent && retried == false) {
//     return messageRequest(
//       req
//         ..withUpload = true
//         ..msg.media?.metadata.timestamp = DateTime.now().millisecondsSinceEpoch,
//       true,
//     );
//   }
//   return res.statusCode == 200;
// }
