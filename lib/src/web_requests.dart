import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'package:down4/src/data_objects/_data_utils.dart';
import 'package:down4/src/data_objects/couch.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '_dart_utils.dart';
import 'bsv/types.dart' show Down4TX;
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
  const headers = {"Content-Type": "application/json"};
  final body = jsonEncode(pairs);
  final imageGenRes = await http.post(url, body: body, headers: headers);
  if (imageGenRes.statusCode != 200) return null;
  final json = jsonDecode(imageGenRes.body);
  final image = base64Decode(json["image"]);
  final prompt = (json["prompt"] as String).split(" ");
  return Pair(image, Pair(prompt.first, prompt.last));
}

Future<void> broadcastTxs(List<Down4TX> txs, {VoidCallback? cb}) async {
  final url = Uri.parse("https://api.whatsonchain.com/v1/bsv/test/tx/raw");
  List<Future<http.Response>> responses = [];
  // we can do 3 txs per seconds // let's make it 4
  const fourSeconds = Duration(seconds: 4);
  var in4seconds = DateTime.now().add(fourSeconds);

  for (int i = 0; i < txs.length; i++) {
    if (i % 3 == 0) {
      final t = DateTime.now();
      if (t.isBefore(in4seconds)) {
        await Future.delayed(in4seconds.difference(t));
      }
    }
    final res = http.post(url, body: jsonEncode({"txhex": txs[i].fullRawHex}));
    responses.add(res);
  }

  for (int i = 0; i < responses.length; i++) {
    final ri = await responses[i];
    final code = ri.statusCode;
    if (code == 200 && txs[i].confirmations == -1) {
      txs[i].updateConfirmations(0); // accepted is 0, not-broadcasted is -1
    } else if (ri.body.contains("257: txn-already-known")) {
      txs[i].updateConfirmations(0);
    } else {
      print(
        "\n\tERROR BROADCASTING TX ID\n\t${txs[i].txID.asHex}\n\t${ri.body}\n",
      );
    }
  }
  cb?.call();
}

Future<Map<String, int?>> confirmations(List<String> txids) async {
  const url = "https://api.whatsonchain.com/v1/bsv/test/txs/status";
  final uri = Uri.parse(url);
  List<List<String>> twenties = [];
  for (int i = 0; i < txids.length; i++) {
    if (i % 20 == 0) twenties.add([]);
    twenties.last.add(txids[i]);
  }

  Map<String, int?> status = {};
  const twoSeconds = Duration(seconds: 4);
  var inTwoSeconds = DateTime.now().add(twoSeconds);
  for (int t = 0; t < twenties.length; t++) {
    final now = DateTime.now();
    // this is to respect the 3 request / second limit given by whatsonchain
    if (t % 3 == 0 && now.isBefore(inTwoSeconds)) {
      await Future.delayed(inTwoSeconds.difference(now));
      inTwoSeconds = DateTime.now().add(twoSeconds);
    }

    final ids = twenties[t];
    final body = jsonEncode({"txids": ids});
    final headers = {"Content-Type": "application/json"};
    print("requesting status for txids: $ids");
    final res = await http.post(uri, body: body, headers: headers);
    if (res.statusCode != 200) {
      status.addAll(ids.asMap().map((k, v) => MapEntry(v, null)));
      print("unsuccessful update status request");
    } else {
      print("successful update status request");
      prettyPrint(jsonDecode(res.body));
      final trf = List.from(jsonDecode(res.body)).asMap().map((_, e) {
        final String txid = e["txid"];
        final int? confs = e["confirmations"];
        return MapEntry(txid, confs);
      });
      status.addAll(trf);
    }
  }
  return status;
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

Future<bool> push(
  List<PersonN> targets,
  Down4Message msg, [
  VoidCallback? afterUploadRoutine,
]) async {
  final List<MT> ts = [];
  String header = "";
  String body = "";
  ChatN? rootNode;
  PersonN? sender;

  final push = await msg.uploadRoutine();
  afterUploadRoutine?.call();
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

  final noNeedToRequest = !ts.any((t) => t.doPush || t.showNotif);
  if (noNeedToRequest) {
    print("No need to request");
    return true;
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
