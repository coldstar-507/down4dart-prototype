import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'package:http/http.dart' as http;
import 'data_objects.dart';
import '_down4_dart_utils.dart' show Pair;
import 'bsv/types.dart' show Down4Payment, Down4TX;

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

Future<Pair<Uint8List, Pair<String, String>>?> getHyperchat(
  List<String> pairs,
) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/imageGenerationRequest",
  );
  final imageGenRes = await http.post(url, body: jsonEncode(pairs));
  if (imageGenRes.statusCode != 200) return null;
  final json = jsonDecode(imageGenRes.body);
  final image = base64Decode(json["image"]);
  final prompt = (json["prompt"] as String).split(" ");
  return Pair(image, Pair(prompt.first, prompt.last));
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

class MessageRequest {
  final List<ID> targets;
  final String header, body, data;
  final Uint8List? notifThumbnail;
  const MessageRequest({
    required this.targets,
    required this.header,
    required this.body,
    required this.data,
    this.notifThumbnail,
  });

  Future<bool> process() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleMessageRequest",
    );

    final res = await http.post(url, body: jsonEncode(this));
    if (res.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Map toJson() => {
        "tr": targets,
        "hd": header,
        "bd": body,
        "d": data,
        if (notifThumbnail != null) "tn": base64Encode(notifThumbnail!),
      };
}

// abstract class Request {
//   final RequestData reqData;
//   const Request({required this.reqData});
//   Future<dynamic> send();
//   Map toJson();
// }

// class PingRequest extends Request {
//   const PingRequest({required RequestData reqData}) : super(reqData: reqData);

//   @override
//   Map<String, dynamic> toJson() => {
//         "rd": reqData.toJson(),
//       };

//   @override
//   Future<bool> send() async {
//     final url = Uri.parse(
//       "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePingRequest",
//     );
//     final res = await http.post(url, body: jsonEncode(this));
//     return res.statusCode == 200;
//   }
// }

// class ChatRequest extends Request {
//   final ID messageID, root;
//   const ChatRequest({
//     required RequestData reqData,
//     required this.root,
//     required this.messageID,
//   }) : super(reqData: reqData);

//   @override
//   Future<bool> send() async {
//     final url = Uri.parse(
//       "https://us-east1-down4-26ee1.cloudfunctions.net/HandleChatRequest",
//     );
//     final res = await http.post(url, body: jsonEncode(this));
//     return res.statusCode == 200;
//   }

//   @override
//   Map<String, dynamic> toJson() => {
//         "rt": root,
//         "msg": messageID,
//         "rd": reqData.toJson(),
//       };
// }

// class SnipRequest extends Request {
//   final ID mediaID, root;
//   const SnipRequest({
//     required RequestData reqData,
//     required this.mediaID,
//     required this.root,
//   }) : super(reqData: reqData);

//   @override
//   Map<String, dynamic> toJson() => {
//         "m": mediaID,
//         "rt": root,
//         "rd": reqData.toJson(),
//       };

//   @override
//   Future<bool> send() async {
//     final url = Uri.parse(
//       "https://us-east1-down4-26ee1.cloudfunctions.net/HandleSnipRequest",
//     );
//     final res = await http.post(url, body: jsonEncode(this));
//     return res.statusCode == 200;
//   }
// }

// class HyperchatRequest extends Request {
//   final List<String> wordPairs;
//   final ID root, msgID;

//   const HyperchatRequest({
//     required RequestData reqData,
//     required this.root,
//     required this.msgID,
//     required this.wordPairs,
//   }) : super(reqData: reqData);

//   @override
//   Future<Hyperchat?> send() async {
//     final url = Uri.parse(
//       "https://us-east1-down4-26ee1.cloudfunctions.net/HandleHyperchatRequest",
//     );
//     final res = await http.post(url, body: jsonEncode(this));
//     if (res.statusCode == 200) {
//       return BaseNode.fromJson(jsonDecode(res.body)) as Hyperchat;
//     } else {
//       return null;
//     }
//   }

//   @override
//   Map<String, dynamic> toJson() => {
//         "msg": msgID,
//         "rt": root,
//         "wp": wordPairs,
//         "rd": reqData.toJson(),
//       };
// }

// class GroupRequest extends Request {
//   final ID groupID, root, msgID;
//   final String name;
//   final bool private;
//   final NodeMedia groupMedia;
//   const GroupRequest({
//     required RequestData reqData,
//     required this.root,
//     required this.msgID,
//     required this.groupID,
//     required this.private,
//     required this.name,
//     required this.groupMedia,
//   }) : super(reqData: reqData);

//   @override
//   Future<Group?> send() async {
//     final url = Uri.parse(
//       "https://us-east1-down4-26ee1.cloudfunctions.net/HandleGroupRequest",
//     );
//     final res = await http.post(url, body: jsonEncode(this));
//     if (res.statusCode == 200) {
//       final jsonDecodedBody = jsonDecode(res.body) as Map;
//       print("JSON KEYS = ${jsonDecodedBody.keys.toList()}");
//       print("JSON DATA IMAGE DATA = ${jsonDecodedBody["d"]}");
//       return BaseNode.fromJson(jsonDecodedBody) as Group;
//     } else {
//       return null;
//     }
//   }

//   @override
//   Map<String, dynamic> toJson() => {
//         "gid": groupID,
//         "rt": root,
//         "msg": msgID,
//         "pv": private,
//         "gn": name,
//         "gm": groupMedia.toJson(),
//         "rd": reqData.toJson(),
//       };
// }

// class PaymentRequest extends Request {
//   final Down4Payment payment;
//   String get id => payment.id;

//   PaymentRequest({
//     required RequestData reqData,
//     required this.payment,
//   }) : super(reqData: reqData);

//   @override
//   Future<bool> send() async {
//     final url = Uri.parse(
//       "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePaymentRequest",
//     );
//     final res = await http.post(url, body: jsonEncode(this));
//     return res.statusCode == 200;
//   }

//   @override
//   Map<String, dynamic> toJson() => {
//         "id": id,
//         "pay": payment.toYouKnow(),
//         "rd": reqData.toJson(),
//       };
// }
