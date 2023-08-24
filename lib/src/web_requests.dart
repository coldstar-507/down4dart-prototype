import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'package:down4/src/data_objects/_data_utils.dart';
import 'package:down4/src/data_objects/couch.dart';
import 'package:http/http.dart' as http;
import '_dart_utils.dart';
import 'bsv/types.dart' show Down4Payment, Down4TX;
import 'globals.dart' show g;
import 'data_objects/medias.dart';
import 'data_objects/messages.dart';
import 'data_objects/nodes.dart';

// Future<bool> usernameIsValid(String username) async {
//   if (username.length < 3) {
//     return false;
//   }
//   if (username.length > 15) {
//     return false;
//   }
//   final uri = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/IsValidUsername",
//   );
//   final res = await http.post(uri, body: username);
//   return res.statusCode == 200;
// }

// Future<String?> generateMnemonic() async {
//   final uri = Uri.parse(
//       "https://us-east1-down4-26ee1.cloudfunctions.net/GenerateMnemonic");
//   final res = await http.post(uri);
//   if (res.statusCode == 200) {
//     return res.body;
//   }
//   return null;
// }

// Future<bool> initUser(String encodedJson) async {
//   final uri = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/InitUser",
//   );
//   final res = await http.post(uri, body: encodedJson);
//   return res.statusCode == 200;
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

// Future<Down4Payment?> getPayment(String paymentID) async {
//   final url = Uri.parse(
//     "https://us-east1-down4-26ee1.cloudfunctions.net/GetPayment",
//   );
//   final req = await http.post(url, body: paymentID);
//   if (req.statusCode != 200) {
//     print("error getting payment, id: $paymentID\n");
//     return null;
//   }
//   return Down4Payment.fromJson(jsonDecode(req.body));
// }

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

Future<Iterable<PersonN>?> getUsers(Iterable<String> uniques) async {
  const url = "https://us-central1-down4-26ee1.cloudfunctions.net/GetNodes";
  final response = await http.post(Uri.parse(url), body: uniques.join(" "));
  if (response.statusCode != 200) return null;
  return List.from(jsonDecode(response.body))
      .map((e) {
        final nodeJson = e["node"] as Map?;
        if (nodeJson == null) return null;

        final mediaJson = e["metadata"] as Map?;
        final link = e["link"] as String?;

        print("\nnode: $nodeJson\nmedia: $mediaJson\nlink: $link\n");

        if (mediaJson != null) {
          final mJsns = Map<String, String?>.from(mediaJson);
          Down4Media.fromJson(mJsns)
            ..cachedUrl = link
            ..cache();
        }

        final pJsns = Map<String, String?>.from(nodeJson);
        final person = Down4Node.fromJson(pJsns)..cache();
        return person as PersonN;
      })
      .nonNulls
      .toList();
}

class MT {
  ComposedID userID;
  String deviceID, token;
  bool showNotif, doPush;
  MT(this.userID,
      {required this.deviceID,
      required this.token,
      required this.showNotif,
      required this.doPush});

  Map toJson() => {
        "uid": userID.value,
        "dev": deviceID,
        "tkn": token,
        "ntf": showNotif,
        "psh": doPush,
      };
}

class MQ {
  List<MT> mts;
  String? push, header, body, root;
  ComposedID? senderID;
  MQ(this.mts, {this.push, this.header, this.body, this.senderID, this.root});

  Map<String, Object> toJson() => {
        if (push != null) "p": push!,
        if (header != null) "h": header!,
        if (body != null) "b": body!,
        if (senderID != null) "s": senderID!.value,
        if (root != null) "r": root!,
        "m": mts.map((e) => e.toJson()).toList(),
      };
}

Future<bool> push(List<PersonN> targets, Down4Message msg) async {
  final List<MT> ts = [];
  String header = "";
  String body = "";
  ChatN? rootNode;
  PersonN? sender;

  final push = await msg.uploadRoutine();
  if (push == null) return false;

  if (msg is ReactionIncrement) {
    for (final t in targets) {
      for (final v in t.messagingTokens.entries) {
        ts.add(MT(t.id,
            deviceID: v.key,
            token: v.value,
            showNotif: false,
            doPush: v.key != g.self.deviceID));
      }
    }
  } else if (msg is Reaction) {
    final mr = await global<Chat>(msg.messageID);
    if (mr == null) return false;
    sender = await global<PersonN>(msg.senderID);
    if (sender == null) return false;
    final rtID = idOfRoot(root: mr.root, selfID: g.self.id);
    rootNode = await global<ChatN>(rtID);
    if (rootNode == null) return false;
    if (rootNode is GroupN) {
      header = rootNode.displayName;
      body = "${sender.displayName} reacted to your message!";
    } else {
      header = g.self.displayName;
      body = "reacted to your message!";
    }
    for (final t in targets) {
      for (final v in t.messagingTokens.entries) {
        ts.add(MT(t.id,
            deviceID: v.key,
            token: v.value,
            showNotif: t.id == mr.senderID,
            doPush: v.key != g.self.deviceID));
      }
    }
  } else if (msg is Chat) {
    sender = await global<PersonN>(msg.senderID);
    if (sender == null) return false;
    final rtID = idOfRoot(root: msg.root, selfID: g.self.id);
    rootNode = await global<ChatN>(rtID);
    if (rootNode == null) return false;
    if (rootNode is GroupN) {
      header = rootNode.displayName;
      body = "${sender.displayName}: ${msg.messagePreview}";
    } else {
      header = g.self.displayName;
      body = msg.messagePreview;
    }
    for (final t in targets) {
      for (final v in t.messagingTokens.entries) {
        ts.add(MT(t.id,
            deviceID: v.key,
            token: v.value,
            showNotif: t.id != msg.senderID,
            doPush: v.key != g.self.deviceID));
      }
    }
  } else if (msg is Snip) {
    sender = await global<PersonN>(msg.senderID);
    if (sender == null) return false;
    final rtID = idOfRoot(root: msg.root, selfID: g.self.id);
    rootNode = await global<ChatN>(rtID);
    if (rootNode == null) return false;
    if (rootNode is GroupN) {
      header = rootNode.displayName;
      body = "${sender.displayName} sent a snip!";
    } else {
      header = g.self.displayName;
      body = "sent a snip!";
    }
    for (final t in targets) {
      for (final v in t.messagingTokens.entries) {
        ts.add(MT(t.id,
            deviceID: v.key,
            token: v.value,
            showNotif: t.id != msg.senderID,
            doPush: t.id != msg.senderID));
      }
    }
  } else if (msg is Payment) {
    sender = await global<PersonN>(msg.senderID);
    if (sender == null) return false;
    header = sender.displayName;
    body = "payed you!";
    for (final t in targets) {
      for (final v in t.messagingTokens.entries) {
        ts.add(MT(t.id,
            deviceID: v.key,
            token: v.value,
            showNotif: v.key == t.mainDeviceID && t.id != g.self.id,
            doPush: v.key == t.mainDeviceID && t.id != g.self.id));
      }
    }
  } else {
    throw 'invalid message type for push: ${msg.runtimeType}';
  }

  final mq = MQ(ts,
      push: push,
      header: header,
      body: body,
      senderID: sender?.id,
      root: rootNode?.root_);

  const u =
      "https://us-central1-down4-26ee1.cloudfunctions.net/HandleMessageRequest";
  final url = Uri.parse(u);

  print("MQ TO JSON:");
  const enc = JsonEncoder.withIndent('   ');
  final prettyjsn = enc.convert(mq);
  print(prettyjsn);

  final req = await http.post(url, body: jsonEncode(mq.toJson()));
  return req.statusCode == 200;
}

void prettyPrint(Object j) {
  const enc = JsonEncoder.withIndent('   ');
  final prettyjsn = enc.convert(j);
  print(prettyjsn);
}
