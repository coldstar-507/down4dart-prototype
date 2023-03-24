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

Future<List<FireNode>?> getNodes(Iterable<String> ids) async {
  if (ids.isEmpty) return [];
  final url =
      Uri.parse("https://us-east1-down4-26ee1.cloudfunctions.net/GetNodes");
  final res = await http.post(url, body: ids.join(" "));
  final jsonLists = List<Map<String, dynamic>>.from(jsonDecode(res.body));
  if (res.statusCode == 200) {
    return jsonLists.map((e) => FireNode.fromJson(e)).toList();
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
  return FireMedia.fromJson(jsonDecode(res.body));
}

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

Future<List<FireMessage>?> getPosts(List<String> ids) async {
  // TODO: getPosts
  return null;
}

class MessageRequest {
  final List<ID> targets;
  final ID sender;
  final String header, body, data;
  final Uint8List? notifThumbnail;
  const MessageRequest({
    required this.sender,
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
        "s": sender,
        "t": targets,
        "h": header,
        "b": body,
        "d": data,
        if (notifThumbnail != null) "n": base64Encode(notifThumbnail!),
      };
}
