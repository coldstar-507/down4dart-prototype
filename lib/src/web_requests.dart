import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'down4_utility.dart';
import 'data_objects.dart';
import 'bsv/types.dart' show Down4Payment, Down4TX;
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

Future<List<BaseNode>?> getNodes(Iterable<String> ids) async {
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

Future<Media?> getMessageMedia(String id) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/GetMessageMedia",
  );
  final res = await http.post(url, body: id);
  if (res.statusCode != 200) return null;
  return MessageMedia.fromJson(jsonDecode(res.body));
}

// TODO Might need adjustment for big batches
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
    // print("Response: ${jsonDecode(res.body)}");
  }
  return failedBroadcast;
}

Future<List<int>?> confirmations(List<String> txsID) async {
  List<List<String>> twentyTxsLists =
      List.generate((txsID.length / 20).ceil(), (index) => <String>[]);
  for (int i = 0; i < txsID.length; i++) {
    final curIndex = (i / 20).floor();
    twentyTxsLists[curIndex].add(txsID[i]);
  }

  List<List<int>> status = [];

  // single threading it for now
  for (final txids in twentyTxsLists) {
    if (txsID.isEmpty) return null;
    final url =
        Uri.parse("https://api.whatsonchain.com/v1/bsv/test/txs/status");
    var res = await http.post(url, body: jsonEncode({"txids": txids}));
    if (res.statusCode != 200) {
      print("Error getting status of transactions");
    } else {
      var answers = jsonDecode(res.body);
      final iStatus = List.from(answers)
          .map((e) => (e["confirmations"] ?? 0) as int)
          .toList();
      status.add(iStatus);
    }
  }

  return status.expand((element) => element).toList(growable: false);
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
  return Down4Payment.fromJson(jsonDecode(req.body));
}

Future<double?> getExchangeRate() async {
  final url = Uri.parse(
    "https://api.whatsonchain.com/v1/bsv/main/exchangerate",
  );
  final res = await http.get(url);
  if (res.statusCode != 200) return null;
  return jsonDecode(res.body)["rate"];
}

// Future<bool> pingRequest(PingRequest req) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePingRequest",
//   );
//   final res = await http.post(url, body: jsonEncode(req));
//   return res.statusCode == 200;
// }
//
// Future<bool> snipRequest(SnipRequest req) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/HandleSnipRequest",
//   );
//   final res = await http.post(url, body: jsonEncode(req));
//   return res.statusCode == 200;
// }
//
// Future<Group?> groupRequest(GroupRequest req, [withMedia = false]) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/HandleGroupRequest",
//   );
//   final res = await http.post(url, body: jsonEncode(req.toJson(withMedia)));
//   if (res.statusCode == HttpStatus.noContent) {
//     return groupRequest(req, true);
//   }
//   if (res.statusCode == 200) {
//     return BaseNode.fromJson(jsonDecode(res.body)) as Group;
//   } else {
//     return null;
//   }
// }
//
// Future<Hyperchat?> hyperchatRequest(
//   HyperchatRequest req, [
//   bool withMedia = false,
// ]) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/HandleHyperchatRequest",
//   );
//   final res = await http.post(url, body: jsonEncode(req.toJson(withMedia)));
//   if (res.statusCode == HttpStatus.noContent) {
//     return hyperchatRequest(req, true);
//   }
//   if (res.statusCode == 200) {
//     return BaseNode.fromJson(jsonDecode(res.body)) as Hyperchat;
//   } else {
//     return null;
//   }
// }
//
// Future<bool> paymentRequest(PaymentRequest req) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePaymentRequest",
//   );
//   final res = await http.post(url, body: jsonEncode(req));
//   return res.statusCode == 200;
// }
//
// Future<bool> chatRequest(ChatRequest req, [withMedia = false]) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/HandleChatRequest",
//   );
//   final res = await http.post(url, body: jsonEncode(req.toJson(withMedia)));
//   if (res.statusCode == HttpStatus.noContent) {
//     return chatRequest(req, true);
//   }
//   return res.statusCode == 200;
// }

Future<int> refreshTokenRequest(String newToken) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/RefreshToken",
  );
  final res = await http.post(url, body: newToken);
  return res.statusCode;
}

Future<List<Message>?> getPosts(List<String> ids) async {
  // TODO: getPosts
  return null;
}

abstract class Request {
  final List<Identifier> targets;
  const Request({required this.targets});
  Map<String, dynamic> toJson();
  send();
}

abstract class MessageRequest extends Request {
  final Message message;
  final MessageMedia? media;
  MessageRequest({
    required List<Identifier> targets,
    required this.message,
    this.media,
  }) : super(targets: targets);
}

class ChatRequest extends MessageRequest {
  final String? groupName;
  ChatRequest({
    MessageMedia? media,
    required Message message,
    required List<Identifier> targets,
    this.groupName,
  }) : super(targets: targets, message: message, media: media);

  @override
  Future<bool> send() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleChatRequest",
    );
    final res = await http.post(url, body: jsonEncode(this));
    return res.statusCode == 200;
  }

  @override
  Map<String, dynamic> toJson() => {
        if (groupName != null) "gn": groupName,
        "msg": message.toJson(),
        "tr": targets,
      };
}

class PingRequest extends Request {
  final String senderID, text;
  PingRequest({
    required this.senderID,
    required this.text,
    required List<Identifier> targets,
  }) : super(targets: targets);

  @override
  Map<String, dynamic> toJson() => {
        "s": senderID,
        "txt": text,
        "tr": targets,
      };

  @override
  Future<bool> send() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePingRequest",
    );
    final res = await http.post(url, body: jsonEncode(this));
    return res.statusCode == 200;
  }
}

class SnipRequest extends Request {
  String senderID, mediaID;
  String? groupName, root;
  SnipRequest({
    required this.mediaID,
    required this.senderID,
    this.root,
    this.groupName,
    required List<Identifier> targets,
  }) : super(targets: targets);

  @override
  Map<String, dynamic> toJson() => {
        "m": mediaID,
        "rt": root,
        "s": senderID,
        "tr": targets,
        if (groupName != null) "gn": groupName,
      };

  @override
  Future<bool> send() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleSnipRequest",
    );
    final res = await http.post(url, body: jsonEncode(this));
    return res.statusCode == 200;
  }
}

class HyperchatRequest extends MessageRequest {
  List<String> wordPairs;

  HyperchatRequest({
    required Message message,
    MessageMedia? media,
    required List<Identifier> targets,
    required this.wordPairs,
  }) : super(targets: targets, message: message, media: media);

  @override
  Future<Hyperchat?> send() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleHyperchatRequest",
    );
    final res = await http.post(url, body: jsonEncode(this));
    if (res.statusCode == 200) {
      return BaseNode.fromJson(jsonDecode(res.body)) as Hyperchat;
    } else {
      return null;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        "msg": message.toJson(),
        "wp": wordPairs,
        "tr": targets,
      };
}

class GroupRequest extends MessageRequest {
  final Identifier groupID;
  final String name;
  final bool private;
  final NodeMedia groupMedia;
  GroupRequest({
    required this.groupID,
    required this.private,
    required this.name,
    required this.groupMedia,
    required Message message,
    MessageMedia? media,
    required List<Identifier> targets,
  }) : super(targets: targets, message: message, media: media);

  @override
  Future<Group?> send() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleGroupRequest",
    );
    final res = await http.post(url, body: jsonEncode(this));
    if (res.statusCode == 200) {
      return BaseNode.fromJson(jsonDecode(res.body)) as Group;
    } else {
      return null;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        "id": groupID,
        "msg": message.toJson(),
        "pv": private,
        "gn": name,
        "gm": groupMedia.toJson(),
        "tr": targets,
      };
}

class PaymentRequest extends Request {
  final Down4Payment payment;
  final String sender;
  final String? textNote;
  String get id => payment.id;

  PaymentRequest({
    required List<Identifier> targets,
    required this.payment,
    required this.sender,
    this.textNote,
  }) : super(targets: targets);

  @override
  Future<bool> send() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePaymentRequest",
    );
    final res = await http.post(url, body: jsonEncode(this));
    return res.statusCode == 200;
  }

  @override
  Map<String, dynamic> toJson() => {
        "s": sender,
        "id": id,
        "tr": targets,
        "pay": payment.toYouKnow(),
        if (payment.textNote.isNotEmpty) "txt": payment.textNote,
      };
}
