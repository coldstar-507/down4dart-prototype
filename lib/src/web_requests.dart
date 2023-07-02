import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'package:http/http.dart' as http;
import '_dart_utils.dart';
import 'bsv/types.dart' show Down4Payment, Down4TX;
import 'data_objects/_data_utils.dart';
import 'data_objects/medias.dart';
import 'data_objects/messages.dart';
import 'data_objects/nodes.dart';

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
  final uri = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/InitUser",
  );
  final res = await http.post(uri, body: encodedJson);
  return res.statusCode == 200;
}

Future<List<Pair<Down4Node, FireMedia?>>> fetchNodes<T extends Down4Node>(
    Iterable<String> ids) async {
  if (ids.isEmpty) return [];
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/GetNodes",
  );
  final res = await http.post(url, body: ids.join(" "));
  print("THE BODY: ${res.body}");
  final jsonList = List<Map<String, Object?>>.from(jsonDecode(res.body));
  if (res.statusCode == 200) {
    return jsonList.map((e) {
      final nodeJson = e["node"] as Map<String, Object?>;
      final mediaJson = e["media"] as Map<String, Object?>?;
      final node = Down4Node.fromJson(nodeJson);
      final media = mediaJson == null ? null : FireMedia.fromJson(mediaJson);
      return Pair(node, media);
    }).toList();
  }
  return [];
}

// Future<MediaMetadata?> getMediaMetadata(String id) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/GetMediaMetadata",
//   );
//   final res = await http.post(url, body: id);
//   if (res.statusCode != 200) {
//     return null;
//   }
//   return MediaMetadata.fromJson(jsonDecode(res.body));
// }

// Future<Media?> getMessageMedia(String id) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/GetMessageMedia",
//   );
//   final res = await http.post(url, body: id);
//   if (res.statusCode != 200) return null;
//   return FireMedia.fromJson(jsonDecode(res.body));
// }

Future<Pair<Uint8List, Pair<String, String>>?> getHyperchat(
  List<String> pairs,
) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/imageGenerationRequest",
  );
  print(pairs);
  final imageGenRes = await http.post(url,
      headers: {"Content-Type": "application/json"}, body: jsonEncode(pairs));
  if (imageGenRes.statusCode != 200) return null;
  final json = jsonDecode(imageGenRes.body);
  final image = base64Decode(json["image"]);
  final prompt = (json["prompt"] as String).split(" ");
  return Pair(image, Pair(prompt.first, prompt.last));
}

// TODO Might need adjustment for big batches
Future<List<Pair<int, String>>> broadcastTxs(List<Down4TX> txs) async {
  final url = Uri.parse("https://api.whatsonchain.com/v1/bsv/test/tx/raw");
  List<Future<http.Response>> responses = [];
  for (final tx in txs) {
    print("Full raw =============\n${tx.fullRawHex}\n==================");
    responses.add(http.post(url, body: jsonEncode({"txhex": tx.fullRawHex})));
  }

  var failedBroadcast = <Pair<int, String>>[];
  for (int i = 0; i < txs.length; i++) {
    var res = await responses[i];
    if (res.statusCode != 200) failedBroadcast.add(Pair(i, res.body));
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

Future<List<Chat>?> getPosts(List<String> ids) async {
  // TODO: getPosts
  return null;
}

Future<Iterable<PersonNode>?> getUsers(Iterable<String> uniques) async {
  final url = Uri.parse(
    "https://us-east1-down4-26ee1.cloudfunctions.net/GetNodes2",
  );
  final response = await http.post(url, body: uniques);
  if (response.statusCode != 200) return null;
  return List.from(jsonDecode(response.body)).map((e) {
    final person = Down4Node.fromJson(jsonDecode(e["node"]))..cache();
    final data = Uint8List.fromList(base64Decode((e["data"])));
    FireMedia.fromJson(jsonDecode(e["metadata"]))
      ..cache()
      ..cachedMemory = data;
    return person as PersonNode;
  });
}

class MessageRequest {
  final List<String> tokens;
  final ComposedID sender;
  final String header, body, data;
  final Uint8List? notifThumbnail;
  const MessageRequest({
    required this.sender,
    required this.tokens,
    required this.header,
    required this.body,
    required this.data,
    this.notifThumbnail,
  });

  Future<MessageBatchResponse> process() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleMessageRequest2",
    );

    final res = await http.post(url, body: jsonEncode(this));
    if (res.statusCode == 200) {
      return MessageBatchResponse.fromJson(jsonDecode(res.body));
    } else {
      return MessageBatchResponse(0, tokens.length,
          tokens.map((e) => SendResponse(false, "", "Unknown")).toList());
    }
  }

  Map toJson() => {
        "s": sender.value,
        "t": tokens,
        "h": header,
        "b": body,
        "d": data,
        if (notifThumbnail != null) "n": base64Encode(notifThumbnail!),
      };
}

class PushRequest {
// sender can be used to see if user is blocked
  final ComposedID sender;
  final List<String> targets;
  final String data;
  PushRequest(
      {required this.sender, required this.targets, required this.data});

  Future<bool> process() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandlePushRequest",
    );

    final res = await http.post(url, body: jsonEncode(this));
    if (res.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Map toJson() => {
        "s": sender.value,
        "t": targets,
        "d": data,
      };
}

class NotificationRequest {
// sender can be used to see if blocked
  final ComposedID sender;
  final String header, body;
  final String? thumbnail;
  final List<String> targets;
  NotificationRequest({
    required this.sender,
    required this.header,
    required this.body,
    required this.targets,
    this.thumbnail,
  });

  Future<bool> process() async {
    final url = Uri.parse(
      "https://us-east1-down4-26ee1.cloudfunctions.net/HandleNotificationRequest",
    );

    final res = await http.post(url, body: jsonEncode(this));
    if (res.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Map toJson() => {
        "s": sender.value,
        "t": targets,
        "h": header,
        "b": body,
        if (thumbnail != null) "n": thumbnail,
      };
}

class MessageBatchResponse {
  final int successCount;
  final int failureCount;
  final List<SendResponse> sendResponses;
  MessageBatchResponse(
      this.successCount, this.failureCount, this.sendResponses);

  factory MessageBatchResponse.fromJson(dynamic decodedJson) {
    return MessageBatchResponse(
      decodedJson["SuccessCount"],
      decodedJson["FailureCount"],
      List.from(decodedJson["SendResponses"])
          .map((e) => SendResponse.fromJson(e))
          .toList(),
    );
  }
}

class SendResponse {
  final bool success;
  final String messageID;
  final String error;
  SendResponse(this.success, this.messageID, this.error);
  factory SendResponse.fromJson(dynamic decodedJson) {
    return SendResponse(
      decodedJson["Success"],
      decodedJson["MessageID"],
      decodedJson["Error"],
    );
  }
}
