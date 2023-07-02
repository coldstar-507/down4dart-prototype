import 'dart:async';
import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cbl/cbl.dart';

import '../bsv/types.dart';
import '../_dart_utils.dart';
import '../web_requests.dart';
import '../globals.dart';

import '_data_utils.dart';
import 'couch.dart';
import 'firebase.dart';
import 'medias.dart';
import 'nodes.dart';

enum MessageType { chat, snip, payment, bill, reaction, post, reactionInc }

abstract class Down4Message extends Down4Object with Jsons {
  final String? _text;
  final int? _timestamp;
  final ComposedID? _mediaID, _forwardedFromID, _root;

  final Down4ID? _reactionID, _paymentID, _messageID;

  final Set<ComposedID>? _nodes, _reactors, _tips;
  final Set<Down4ID>? _messages, _replies;
  final Down4Payment? _payment;
  final List<MessageTarget>? _targets;

  final ComposedID? _tempMediaID;
  final int? _tempMediaTS;

  final ComposedID? _tempPaymentID;
  final int? _tempPaymentTS;

  bool? _isSent, _isRead;

  @override
  final Down4ID id;
  final ComposedID senderID;

  Down4Message(
    this.id, {
    required this.senderID,
    int? timestamp,
    ComposedID? root,
    Down4ID? reactionID,
    Set<Down4ID>? replies,
    Set<Down4ID>? messages,
    Set<ComposedID>? nodes,
    Set<ComposedID>? reactors,
    Set<ComposedID>? tips,
    Down4Payment? payment,
    bool? isRead,
    bool? isSent,
    String? text,
    ComposedID? mediaID,
    Down4ID? messageID,
    ComposedID? forwardedFromID,
    Down4ID? paymentID,
    List<MessageTarget>? targets,
    int? tempMediaTS,
    ComposedID? tempMediaID,
    int? tempPaymentTS,
    ComposedID? tempPaymentID,
  })  : _reactionID = reactionID,
        _text = text,
        _root = root,
        _targets = targets,
        _isSent = isSent,
        _isRead = isRead,
        _tempPaymentTS = tempPaymentTS,
        _tempPaymentID = tempPaymentID,
        _mediaID = mediaID,
        _messages = messages,
        _paymentID = paymentID,
        _messageID = messageID,
        _payment = payment,
        _reactors = reactors,
        _timestamp = timestamp,
        _replies = replies,
        _forwardedFromID = forwardedFromID,
        _nodes = nodes,
        _tips = tips,
        _tempMediaTS = tempMediaTS,
        _tempMediaID = tempMediaID;

  Future<String> makeHeader();
  Future<String> makeBody();
  // Future<Map<ComposedID, Map<String, String>>?> getTokens();

  MessageType get type;

  factory Down4Message.fromJson(Map<String, Object?> decodedJson) {
    final type = MessageType.values.byName(decodedJson["type"] as String);
    final id = Down4ID.fromString(decodedJson["id"] as String);
    final senderID = ComposedID.fromString(decodedJson["senderID"] as String);
    final root = ComposedID.fromString(decodedJson["root"] as String?);

    final nodes = (decodedJson["nodes"] as String?).toComposedIDs();

    // messages are down4IDs
    final replies = (decodedJson["replies"] as String?).toDown4IDs();

    final reactors = (decodedJson["reactors"] as String?).toComposedIDs();

    final reactionID = Down4ID.fromString(decodedJson["reactionID"] as String?);
    // final tips = (decodedJson["tips"] as String?)?.split(" ");

    final forwardedFromID =
        ComposedID.fromString(decodedJson["forwardedFromID"] as String?);

    final payment = decodedJson["payment"] != null
        ? Down4Payment.fromJson(jsonDecode(decodedJson["payment"] as String))
        : null;

    final timestamp = int.tryParse(decodedJson["timestamp"] as String? ?? "");
    final text = decodedJson["text"] as String?;
    final mediaID = ComposedID.fromString(decodedJson["mediaID"] as String?);
    final tempMediaTS =
        int.tryParse(decodedJson["tempMediaTS"] as String? ?? "");
    final tempMediaID =
        ComposedID.fromString(decodedJson["tempMediaID"] as String?);
    final tempPaymentTS =
        int.tryParse(decodedJson["tempPaymentTS"] as String? ?? "");
    final tempPaymentID =
        ComposedID.fromString(decodedJson["tempPaymentID"] as String?);
    final messageID =
        ComposedID.fromString(decodedJson["messageID"] as String?);
    final paymentID = Down4ID.fromString(decodedJson["paymentID"] as String?);
    final isSent = decodedJson["isSent"] == "true";
    final isRead = decodedJson["isRead"] == "true";

    switch (type) {
      case MessageType.chat:
        return Chat(id!,
            root: root!,
            senderID: senderID!,
            timestamp: timestamp!,
            text: text,
            mediaID: mediaID,
            tempMediaTS: tempMediaTS,
            tempMediaID: tempMediaID,
            isSent: isSent,
            isRead: isRead,
            replies: replies,
            nodes: nodes,
            forwardedFromID: forwardedFromID);
      case MessageType.snip:
        return Snip(id!,
            root: root!,
            senderID: senderID!,
            mediaID: mediaID!,
            tempMediaID: tempMediaID,
            tempMediaTS: tempMediaTS,
            isRead: isRead,
            text: text);
      case MessageType.reaction:
        return Reaction(id!,
            root: root!,
            senderID: senderID!,
            messageID: messageID!,
            reactors: reactors!,
            mediaID: mediaID!,
            tempMediaTS: tempMediaTS,
            tempMediaID: tempMediaID);
      case MessageType.payment:
        return Payment(id!,
            paymentID: paymentID!,
            payment: payment,
            targets: [],
            senderID: senderID!);
      case MessageType.reactionInc:
        return ReactionIncrement(id!,
            root: root!,
            messageID: messageID!,
            reactionID: reactionID!,
            senderID: senderID!);
      // TODO: Handle this case.
      case MessageType.bill:
      // TODO: Handle this case.
      case MessageType.post:
      // TODO: Handle this case.
    }
    throw 'Unimplemented Sendable.fromJson type: $type';
  }

  @override
  Map<String, String> toJson({bool toLocal = false}) => {
        "id": id.value,
        "type": type.name,
        "senderID": senderID.value,
        if (_root != null) "root": _root!.value,
        if (_isSent != null && toLocal) "isSent": _isSent!.toString(),
        if (_isRead != null && toLocal) "isRead": _isRead!.toString(),
        if (_payment != null)
          "payment": jsonEncode(_payment!.toJson(toLocal: toLocal)),
        if (_reactionID != null) "reactionID": _reactionID!.value,
        if (_forwardedFromID != null)
          "forwardedFromID": _forwardedFromID!.value,
        if (_paymentID != null) "paymentID": _paymentID!.value,
        if (_nodes != null) "nodes": _nodes!.join(" "),
        if (_replies != null) "replies": _replies!.join(" "),
        if (_tips != null) "tips": _tips!.join(" "),
        if (_reactors != null) "reactors": _reactors!.join(" "),
        if (_text != null) "text": _text!,
        if (_timestamp != null) "timestamp": _timestamp!.toString(),
        if (_mediaID != null) "mediaID": _mediaID!.value,
        if (_messageID != null) "messageID": _messageID!.value,
        if (_tempMediaID != null) "onlineMediaID": _tempMediaID!.value,
        if (_tempMediaTS != null) "tempMediaTS": _tempMediaTS!.toString(),
        if (_tempPaymentID != null) "tempPaymentID": _tempPaymentID!.value,
        if (_tempPaymentTS != null) "tempPaymentTS": _tempPaymentTS!.toString(),
      };

  Future<void> processMessage({
    void Function()? onError,
    void Function(List<MessageTarget>)? onResponse,
  });
}

extension on Map {
  Map<K, V> those<K, V>(List<K> keys) {
    Map<K, V> m = {};
    for (final key in keys) {
      m[key] = this[key];
    }
    return m;
  }
}

mixin Reads on Down4Message, Locals {
  bool get isRead => _isRead!;
  Future<void> markRead() async {
    if (isRead) return;
    await merge({"isRead": (_isRead = true).toString()});
  }
}

mixin Medias on Down4Message {
  ComposedID? get mediaID => _mediaID;
  ComposedID? get tempMediaID => _tempMediaID;
  int? get tempMediaTS => _tempMediaTS;

  // returns the dataPayload if routine was successful
  Future<Map<String, String>?> _mediableRoutine({
    Map<String, String>? preMsg,
  }) async {
    final media = await global<FireMedia>(mediaID);
    final fullJson = preMsg ?? toJson();
    if (media != null) {
      return media.temporaryUpload(fullJson);
    } else {
      return fullJson;
    }

    // FireMedia? media;
    // int? freshTS;
    // ID? freshOnlineID;
    // try {
    //   media = await global<FireMedia>(mediaID);
    //   print("MEDIA ONLINE TIMESTAMP = ${media?.onlineTimestamp}");
    //
    //   final uploadMedia = media != null &&
    //       (media.onlineID == null || media.onlineTimestamp.shouldBeUpdated);
    //
    //   if (uploadMedia) {
    //     print("(RE)-uploading media!");
    //     freshOnlineID = messagePushId();
    //     freshTS = makeTimestamp();
    //
    //     final jsonMedia = media.toJson(toLocal: false);
    //     jsonMedia["onlineID"] = freshOnlineID;
    //     jsonMedia["onlineTimestamp"] = freshTS.toString();
    //
    //     final shard = Down4Server.instance.shardForUserObjectID(freshOnlineID);
    //
    //     final ref = shard.temporaryStore.ref(freshOnlineID);
    //     final setMetadata = SettableMetadata(customMetadata: jsonMedia);
    //
    //     if (media.cachedFile != null) {
    //       await ref.putFile(media.cachedFile!, setMetadata);
    //     } else if (media.isVideo && media.videoFile != null) {
    //       await ref.putFile(media.videoFile!, setMetadata);
    //     } else if ((await media.localImageData) != null) {
    //       await ref.putData((await media.localImageData)!, setMetadata);
    //     } else {
    //       print("PROBLEM: NO MEDIA TO UPLOAD BRO");
    //     }
    //   } else {
    //     print("OK: NO NEED TO UPDATE MEDIA");
    //   }
    //
    //   final msgJson = toJson(toLocal: false);
    //   if (media != null) {
    //     msgJson["onlineMediaID"] = freshOnlineID ?? media.onlineID!;
    //     msgJson["onlineMediaTimestamp"] =
    //         freshTS?.toString() ?? media.onlineTimestamp.toString();
    //   }
    //
    //   if (media != null && freshTS != null && freshOnlineID != null) {
    //     media
    //       ..updateTempReferences(freshOnlineID, freshTS)
    //       ..cache();
    //   }
    //
    //   return msgJson;
    // } catch (e) {
    //   print("ERROR uploadMessageMedia,  message id: $id, error: $e");
    //   return null;
    // }
  }
}

mixin Texts on Down4Message {
  String? get text => _text;
}

mixin Cash on Down4Message {
  Down4ID? get paymentID => _paymentID;
  Down4Payment? get payment => _payment;
  ComposedID? get tempPaymentID => payment?.tempID;
  int? get tempPaymentTS => payment?.tempTS;

  // Future<Map<String, String>?> _paymentUpload({
  //   Map<String, String>? preMsg,
  // }) async {
  //   Down4Payment? pay = payment;
  //   int? freshTS;
  //   ID? freshOnlineID;
  //   try {
  //     final uploadPayment = pay != null &&
  //         (pay.onlineID == null || pay.onlineTimestamp.shouldBeUpdated);
  //
  //     if (uploadPayment) {
  //       print("(RE)-uploading payment!");
  //       freshOnlineID = messagePushId();
  //       freshTS = makeTimestamp();
  //
  //       final server = Down4Server.instance.shardForUserObjectID(freshOnlineID);
  //
  //       final jsonPay = pay.toJson(toLocal: false);
  //       jsonPay["onlineID"] = freshOnlineID;
  //       jsonPay["onlineTimestamp"] = freshTS.toString();
  //
  //       await server.temporaryStore
  //           .ref(freshOnlineID)
  //           .putString(jsonEncode(jsonPay));
  //     } else {
  //       print("OK: NO NEED TO UPDATE PAYMENT");
  //     }
  //
  //     final msgJson = preMsg ?? toJson(toLocal: false);
  //     if (pay != null) {
  //       msgJson["onlinePaymentID"] = freshOnlineID ?? pay.onlineID!;
  //       msgJson["onlinePaymentTimestamp"] =
  //           freshTS?.toString() ?? pay.onlineTimestamp.toString();
  //     }
  //
  //     if (pay != null && freshTS != null && freshOnlineID != null) {
  //       pay
  //         ..updateTempReferences(freshOnlineID, freshTS)
  //         ..cache();
  //     }
  //
  //     return msgJson..remove("payment");
  //   } catch (e) {
  //     print("ERROR uploadMessageMedia,  message id: $id, error: $e");
  //     return null;
  //   }
  // }

  Future<Map<String, String>?> _paymentUploadRoutine({
    Map<String, String>? preMsg,
  }) async {
    final fullJson = preMsg ?? toJson(toLocal: false);
    final asData = jsonEncode(fullJson);
    // only way to have over 4kb in payload is to have a payment
    if (asData.length > 4000) {
      return payment!.temporaryUpload(fullJson);
    } else {
      return fullJson;
    }
  }
}

mixin Sents on Down4Message, Locals {
  Future<void> markSent() => merge({"isSent": (_isSent = true).toString()});
}

mixin Roots on Down4Message {
  ComposedID get root;

  Future<ChatNode?> get rootNode => global<ChatNode>(root);

  @override
  Future<String> makeHeader() async {
    final rootNode = await global<ChatNode>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupNode) {
      return rootNode.displayName;
    } else {
      return g.self.displayName;
    }
  }

  // @override
  // Future<Map<ComposedID, Map<String, String>>?> getTokens() async {
  //   return global<Chatable>(root).then((r) => r?.getAllMessagingTokens());
  // }
}

mixin Messages on Down4Message, Roots, Medias, Reads, Texts, Locals {
  Future<void> onReceipt(void Function(ChatNode rootNode) callback) async {
    // get the rootNode
    final rootNode =
        await global<ChatNode>(root, doFetch: true, doMergeIfFetch: true);
    if (rootNode == null) return;

    User? senderNode = await global<User>(senderID);
    FireMedia? msgMedia;

    if (senderNode != null && senderNode.isFriend) {
      // we predownload the media, else it's download on open
      msgMedia = await global<FireMedia>(mediaID,
          doFetch: true, doMergeIfFetch: true, tempID: tempMediaID);
    }

    // get the rootNode media
    await global<FireMedia>(rootNode.mediaID,
        doFetch: true, doMergeIfFetch: true);

    // msg medias references are dynamic and always get updated
    // this is because messages are not kept for ever on server
    if (tempMediaID != null) {
      await msgMedia?.updateTempReferences(tempMediaID!, tempMediaTS!);
    }
    await merge();

    return callback(rootNode);
  }
}

class ReactionIncrement extends Down4Message with Roots {
  @override
  ComposedID get root => _root!;
  Down4ID get messageID => _messageID!;
  Down4ID get reactionID => _reactionID!;

  ReactionIncrement(
    super.id, {
    required super.senderID,
    required ComposedID root,
    required Down4ID messageID,
    required Down4ID reactionID,
  }) : super(root: root, messageID: messageID, reactionID: reactionID);

  @override
  Future<String> makeBody() async => "";

  @override
  Future<String> makeHeader() async => "";

  @override
  MessageType get type => MessageType.reactionInc;

  @override
  Future<void> processMessage({
    void Function()? onError,
    void Function(List<MessageTarget>)? onResponse,
    Map<String, String>? specificData,
  }) async {
    final pertinentTargets = await (await rootNode)?.allTargets();
    if (pertinentTargets == null) return onError?.call();

    Future(() async {
      final response = await MessageRequest(
              sender: g.self.id,
              tokens: pertinentTargets.exceptMyCurrentDeviceToken.toList(),
              header: await makeHeader(),
              body: await makeBody(),
              data: jsonEncode(specificData ?? (toLocal: false)))
          .process();

      if (onResponse == null) return;
      for (int i = 0; i < response.sendResponses.length; i++) {
        pertinentTargets[i].success = response.sendResponses[i].success;
      }

      return onResponse.call(pertinentTargets);
    });
  }
}

class Reaction extends Down4Message with Roots, Medias, Locals {
  @override // override because non-nullable
  ComposedID get mediaID => _mediaID!;

  @override
  ComposedID get root => _root!;

  Down4ID get messageID => _messageID!;
  Set<ComposedID> get reactors => _reactors!;

  Reaction(
    super.id, {
    required super.senderID,
    required ComposedID root,
    required ComposedID mediaID,
    super.tempMediaID,
    super.tempMediaTS,
    required Down4ID messageID,
    required Set<ComposedID> reactors,
  }) : super(
            root: root,
            mediaID: mediaID,
            messageID: messageID,
            reactors: reactors);

  @override
  Database get dbb => reactionsDB;

  Future<void> addReactor(ComposedID reactor) async {
    reactors.add(reactor);
    await merge({"reactors": reactors.map((e) => e.value).join(" ")});
  }

  @override
  MessageType get type => MessageType.reaction;

  @override
  Future<String> makeBody() async {
    final rootNode = await global<ChatNode>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupNode) {
      return "${g.self.firstName} reacted to your message!";
    } else {
      return "reacted to your message!";
    }
  }

  @override
  Future<void> processMessage({
    void Function(List<MessageTarget>)? onResponse,
    void Function()? onError,
    Map<String, String>? specificData,
  }) async {
    final jsonData = await _mediableRoutine();
    final rMsg = await global<Chat>(messageID);
    if (jsonData == null || rMsg == null) return;
    // this is all the tokens, including all of the sender's devices
    final targets = await (await rootNode)?.allTargets();
    if (targets == null) return onError?.call();

    // We notif msgSender if he's not us
    final notifTs = targets.exceptSelf.where((e) => e.userID == rMsg.senderID);

    // all device except our own
    final dataTokens = targets.exceptMyCurrentDeviceToken;

    final data = jsonEncode(jsonData);
    List<MessageRequest> reqs = [];
    if (notifTs.isNotEmpty) {
      reqs.add(MessageRequest(
          sender: g.self.id,
          tokens: notifTs.allTokens.toList(),
          header: await makeHeader(),
          body: await makeBody(),
          data: data));
    }
    reqs.add(MessageRequest(
        sender: g.self.id,
        tokens: dataTokens.toList(),
        header: "",
        body: "",
        data: data));

    await Future.wait(reqs.map((e) => e.process()));
  }
}

class Snip extends Down4Message
    with Locals, Roots, Medias, Reads, Texts, Messages {
  @override
  ComposedID get mediaID => _mediaID!;

  @override
  ComposedID get root => _root!;

  Snip(
    super.id, {
    required super.senderID,
    required ComposedID root,
    required ComposedID mediaID,
    required super.text,
    super.tempMediaID,
    super.tempMediaTS,
    bool isRead = false,
  }) : super(isRead: isRead, root: root, mediaID: mediaID);

  @override
  MessageType get type => MessageType.snip;

  @override
  Future<String> makeBody() async {
    final rootNode = await global<ChatNode>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupNode) {
      return "${g.self.firstName} sniped!";
    } else {
      return "sniped!";
    }
  }

  @override
  Database get dbb => messagesDB;

  @override
  Future<void> processMessage({
    void Function()? onError,
    void Function(List<MessageTarget> p1)? onResponse,
    Map<String, String>? specificData,
  }) async {
    final jsonData = await _mediableRoutine();
    if (jsonData == null) return onError?.call();

    final targets = await (await rootNode)?.allTargets();
    if (targets == null) return onError?.call();

    MessageRequest(
      sender: g.self.id,
      tokens: targets.exceptSelf.allTokens.toList(),
      header: await makeHeader(),
      body: await makeBody(),
      data: jsonEncode(jsonData),
    ).process();
  }
}

class Chat extends Down4Message
    with Locals, Roots, Medias, Texts, Sents, Reads, Messages {
  @override
  ComposedID get root => _root!;

  Set<Down4ID>? get replies => _replies;
  Set<ComposedID>? get nodes => _nodes;

  int get timestamp => _timestamp!;

  ComposedID? get forwardedFromID => _forwardedFromID;

  bool get hadForwards => (_messages ?? _nodes ?? {}).isNotEmpty;

  Chat(
    super.id, {
    required super.senderID,
    required ComposedID root,
    required int timestamp,
    super.messages,
    super.text,
    super.mediaID,
    super.tempMediaID,
    super.tempMediaTS,
    super.isSent = false,
    super.isRead,
    super.forwardedFromID,
    super.nodes,
    super.replies,
  });

  bool get isSent => _isSent!;

  String get messagePreview => forwardedFromID != null
      ? ">> forwarded message"
      : (text ?? "").isEmpty
          ? "&attachment"
          : text!;

  Future<List<Reaction>> get reactions async {
    final raw = "SELECT * FROM _ WHERE messageID = '$id'";
    final q = await AsyncQuery.fromN1ql(reactionsDB, raw);
    final e = await q.execute();
    final r = await e.allResults();
    return r.map((e) {
      final json = e.toPlainMap()["_"] as Map<String, Object?>;
      print("CHAT REACTION JSON = $json");
      return Down4Message.fromJson(json) as Reaction;
    }).toList();
  }

  // Creates a new instance of a messages that will be uploaded
  // removes the replies and local data
  // puts a new timestamp and forwarderID as forwarder and a new ID
  Chat forwarded(ComposedID newSenderID, ComposedID newRoot) {
    return Chat(ComposedID(),
        root: newRoot,
        senderID: newSenderID,
        forwardedFromID: forwardedFromID ?? senderID,
        text: text,
        nodes: nodes,
        mediaID: mediaID,
        tempMediaID: tempMediaID,
        tempMediaTS: tempMediaTS,
        timestamp: makeTimestamp());
  }

  @override
  MessageType get type => MessageType.chat;

  @override
  Future<String> makeBody() async {
    final rootNode = await global<ChatNode>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupNode) {
      return "${g.self.firstName}: $messagePreview";
    } else {
      return messagePreview;
    }
  }

  Future<void> _forwardMessagesRoutine({
    void Function(List<MessageTarget> p1)? onResponse,
    void Function()? onError,
  }) async {
    for (final msgID in (_messages ?? {}).toList().reversed) {
      final msg = await global<Chat>(msgID);
      if (msg != null) {
        msg.copiedFor(root: root)
          ..cache()
          ..markRead()
          ..processMessage(onResponse: onResponse, onError: onError);
      }
    }
  }

  @override
  Database get dbb => messagesDB;

  Chat copiedFor({required ComposedID root}) {
    return Down4Message.fromJson(toJson(toLocal: false)
      ..["id"] = ComposedID().value
      ..["timestamp"] = makeTimestamp().toString()
      ..["root"] = root.value) as Chat;
  }

  @override
  Future<void> processMessage({
    void Function()? onError,
    void Function(List<MessageTarget> p1)? onResponse,
    Map<String, String>? specificData,
  }) async {
    _forwardMessagesRoutine(onError: onError, onResponse: onResponse);
    final data = await _mediableRoutine();
    final stringData = jsonEncode(data);
    final targets = await (await rootNode)?.allTargets();
    if (targets == null) return onError?.call();
    List<Future<MessageBatchResponse>> requests = [];

    if (targets.selfTargets.isNotEmpty) {
      requests.add(MessageRequest(
              sender: g.self.id,
              tokens: targets.exceptMyCurrentDeviceToken.toList(),
              header: "",
              body: "",
              data: stringData)
          .process());
    }

    requests.add(MessageRequest(
            sender: g.self.id,
            tokens: targets.exceptSelf.allTokens.toList(),
            header: await makeHeader(),
            body: await makeBody(),
            data: stringData)
        .process());

    final res = await Future.wait(requests).then((value) => value
        .map((e) => e.sendResponses)
        .expand((element) => element)
        .toList());

    for (final (i, mt) in targets.indexed) {
      mt.success = res[i].success;
    }

    onResponse?.call(targets);
  }
}

class Payment extends Down4Message with Cash {
  @override
  Down4ID get paymentID => _paymentID!;

  Payment(
    super.id, {
    required super.senderID,
    required Down4ID paymentID,
    required List<MessageTarget> targets,
    ComposedID? tempPaymentID,
    int? tempPaymentTS,
    super.payment,
  }) : super(
            paymentID: paymentID,
            targets: targets,
            tempPaymentID: tempPaymentID,
            tempPaymentTS: tempPaymentTS);

  @override
  MessageType get type => MessageType.payment;

  List<MessageTarget> get targets => _targets!;

  @override
  Future<String> makeBody() async {
    return "payed you!";
  }

  @override
  Future<String> makeHeader() async {
    return g.self.displayName;
  }

  @override
  Future<void> processMessage({
    void Function()? onError,
    void Function(List<MessageTarget> p1)? onResponse,
  }) async {
    final data = await _paymentUploadRoutine();
    if (data == null) return onError?.call();
    final res = await MessageRequest(
            sender: g.self.id,
            tokens: targets.allTokens.toList(),
            header: await makeHeader(),
            body: await makeBody(),
            data: jsonEncode(data))
        .process();

    if (onResponse == null) return;
    for (final (i, r) in res.sendResponses.indexed) {
      targets[i].success = r.success;
    }

    return onResponse.call(targets);
  }
}
