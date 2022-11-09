import 'dart:convert';
import 'dart:io';
import 'package:flutter_testproject/src/down4_utility.dart';
import 'bsv/utils.dart' show sha256;
import 'package:http/http.dart' as http;
import 'data_objects.dart';
import 'bsv/types.dart' show Down4Payment, Down4TX, Down4InternetPayment;
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

Future<List<BaseNode>?> getNodes(List<String> ids) async {
  final url =
      Uri.parse("https://us-east1-down4-26ee1.cloudfunctions.net/GetNodes");
  final res = await http.post(url, body: ids.join(" "));
  final jsonLists = List<Map<String, dynamic>>.from(jsonDecode(res.body));
  if (res.statusCode == 200) {
    return jsonLists.map((e) => BaseNode.fromJson(e)).toList();
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

Future<List<int>> broadcastTxs(List<Down4TX> txs) async {
  final url = Uri.parse("https://api.whatsonchain.com/v1/bsv/test/tx/raw");
  List<Future<http.Response>> responses = [];
  for (final tx in txs) {
    print("Full raw =============\n${tx.fullRawHex}\n==================");
    responses.add(http.post(url, body: jsonEncode({"txhex": tx.fullRawHex})));
  }

  var failedBroadcast = <int>[];
  for (int i = 0; i < txs.length; i++) {
    var res = await responses[i];
    if (res.statusCode != 200) failedBroadcast.add(i);
    print("Response: ${jsonDecode(res.body)}");
  }
  return failedBroadcast;
}

Future<List<int>?> confirmations(List<String> txsID) async {
  if (txsID.isEmpty) return null;
  final url = Uri.parse("https://api.whatsonchain.com/v1/bsv/test/txs/status");
  var res = await http.post(url, body: jsonEncode({"txids": txsID}));
  if (res.statusCode != 200) {
    print("Error getting status of transactions");
    return null;
  }
  var answers = jsonDecode(res.body);
  return List.from(answers)
      .map((e) => (e["confirmations"] ?? 0) as int)
      .toList();
}

Future<Down4Payment?> getPayment(String paymentID) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/GetPayment",
  );
  final req = await http.post(url, body: paymentID);
  if (req.statusCode != 200) {
    print("error getting payment, id: $paymentID\n");
    return null;
  }
  return Down4Payment.fromYouKnow(req.body);
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

Future<Group?> groupRequest(GroupRequest req, [withMedia = false]) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/HandleGroupRequest",
  );
  final res = await http.post(url, body: jsonEncode(req.toJson(withMedia)));
  if (res.statusCode == HttpStatus.noContent) {
    return groupRequest(req, true);
  }
  if (res.statusCode == 200) {
    return BaseNode.fromJson(jsonDecode(res.body)) as Group;
  } else {
    return null;
  }
}

Future<Hyperchat?> hyperchatRequest(
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
    return BaseNode.fromJson(jsonDecode(res.body)) as Hyperchat;
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

abstract class Request {
  final List<Identifier> targets;
  Request({required this.targets});
  Map<String, dynamic> toJson();
}

class ChatRequest implements Request {
  final Down4Message message;
  final Down4Media? media;
  ChatRequest({
    required this.message,
    required this.targets,
    this.media,
  });
  @override
  final List<Identifier> targets;

  @override
  Map<String, dynamic> toJson([bool withMedia = false]) => {
        "msg": message.toJson(),
        "tr": targets,
        if (withMedia && media != null) "m": media!.toJson(),
      };
}

class PingRequest implements Request {
  final String senderID, text;
  PingRequest({
    required this.senderID,
    required this.text,
    required this.targets,
  });

  @override
  final List<Identifier> targets;

  @override
  Map<String, dynamic> toJson() => {
        "s": senderID,
        "txt": text,
        "tr": targets,
      };
}

class SnipRequest extends ChatRequest {
  SnipRequest({
    required Down4Media media,
    required Down4Message message,
    required List<Identifier> targets,
  }) : super(targets: targets, message: message, media: media);

  @override
  Map<String, dynamic> toJson([bool withMedia = true]) => {
        "msg": message.toJson(),
        "tr": targets,
        "m": media!.toJson(),
      };
}

class HyperchatRequest extends ChatRequest {
  List<String> wordPairs;
  HyperchatRequest({
    required Down4Message message,
    required List<Identifier> targets,
    Down4Media? media,
    required this.wordPairs,
  }) : super(message: message, targets: targets, media: media);

  @override
  Map<String, dynamic> toJson([bool withMedia = false]) => {
        "msg": message.toJson(),
        "wp": wordPairs,
        "tr": targets,
        if (withMedia && media != null) "m": media!.toJson(),
      };
}

class GroupRequest extends ChatRequest {
  String name;
  bool private;
  Down4Media groupImage;
  GroupRequest({
    required this.private,
    required this.name,
    required this.groupImage,
    required Down4Message message,
    Down4Media? media,
    required List<Identifier> targets,
  }) : super(targets: targets, message: message, media: media);

  @override
  Map<String, dynamic> toJson([bool withMedia = false]) => {
        "msg": message.toJson(),
        "pv": private,
        "gn": name,
        "gm": groupImage.toJson(),
        "tr": targets,
        if (withMedia && media != null) "m": media!.toJson(),
      };
}

class PaymentRequest implements Request {
  final Down4Payment payment;
  final String sender;
  String get id => payment.id;

  PaymentRequest({
    required this.targets,
    required this.payment,
    required this.sender,
  });

  @override
  final List<Identifier> targets;

  @override
  Map<String, dynamic> toJson() => {
        "s": sender,
        "id": id,
        "tr": targets,
        "pay": payment.toYouKnow(),
      };
}
