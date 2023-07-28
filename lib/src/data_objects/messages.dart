import 'dart:async';
import 'dart:convert';

import 'package:cbl/cbl.dart';

import '../bsv/types.dart';
import '../_dart_utils.dart';
import '../web_requests.dart';
import '../globals.dart';

import '_data_utils.dart';
import 'couch.dart';
import 'medias.dart';
import 'nodes.dart';

enum MessageType { chat, snip, payment, bill, reaction, post, reactionInc }

abstract class Down4Message with Down4Object, Jsons {
  final String? _text;
  final int? _timestamp;
  final ComposedID? _mediaID, _forwardedFromID, _root;

  final Down4ID? _reactionID, _paymentID, _messageID;

  final Set<ComposedID>? _nodes, _reactors, _tips;
  final Set<Down4ID>? _messages, _replies;
  final Down4Payment? _payment;
  List<MessageTarget>? _targets;
  final List<Reaction>? _reactions;

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
    List<Reaction>? reactions,
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
        _reactions = reactions,
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

  MessageType get type;

  Future<List<MessageTarget>?> get targets;

  factory Down4Message.fromJson(Map<String, String?> decodedJson) {
    final type = MessageType.values.byName(decodedJson["type"]!);
    final id = Down4ID.fromString(decodedJson["id"])!;
    final senderID = ComposedID.fromString(decodedJson["senderID"])!;
    final root = ComposedID.fromString(decodedJson["root"]);

    final nodes = decodedJson["nodes"].toComposedIDs();

    // messages are down4IDs
    final replies = decodedJson["replies"].toDown4IDs();

    final reactors = decodedJson["reactors"].toComposedIDs();

    final reactionID = Down4ID.fromString(decodedJson["reactionID"]);
    // final tips = (decodedJson["tips"] ?)?.split(" ");

    final forwardedFromID =
        ComposedID.fromString(decodedJson["forwardedFromID"]);

    final payment = decodedJson["payment"] != null
        ? Down4Payment.fromYouKnow(decodedJson["payment"]!)
        : null;

    final timestamp = int.tryParse(decodedJson["timestamp"] ?? "");
    final text = decodedJson["text"];
    final mediaID = ComposedID.fromString(decodedJson["mediaID"]);
    final tempMediaTS = int.tryParse(decodedJson["tempMediaTS"] ?? "");
    final tempMediaID = ComposedID.fromString(decodedJson["tempMediaID"]);
    final tempPaymentTS = int.tryParse(decodedJson["tempPaymentTS"] ?? "");
    final tempPaymentID = ComposedID.fromString(decodedJson["tempPaymentID"]);
    final messageID = Down4ID.fromString(decodedJson["messageID"]);
    final paymentID = Down4ID.fromString(decodedJson["paymentID"]);
    final isSent = decodedJson["isSent"] == "true";
    final isRead = decodedJson["isRead"] == "true";

    List<Reaction>? reactions;
    final ykEncodedReactions = decodedJson["reactions"];
    if (ykEncodedReactions != null) {
      final yk = List.from(youKnowDecode(ykEncodedReactions));
      reactions = yk.map((m) {
        final jsn = Map<String, String?>.from(m as Map);
        return Down4Message.fromJson(jsn) as Reaction;
      }).toList();
    }

    List<MessageTarget>? targets;
    final ykEncodedTargets = decodedJson["targets"];
    if (ykEncodedTargets != null) {
      final yk = List.from(youKnowDecode(ykEncodedTargets));
      targets = yk.map((t) {
        final jsn = Map<String, String?>.from(t as Map);
        return MessageTarget.fromJson(jsn);
      }).toList();
    }

    switch (type) {
      case MessageType.chat:
        return Chat(id,
            root: root!,
            senderID: senderID,
            timestamp: timestamp!,
            text: text,
            mediaID: mediaID,
            reactions: reactions,
            tempMediaTS: tempMediaTS,
            tempMediaID: tempMediaID,
            isSent: isSent,
            isRead: isRead,
            replies: replies,
            nodes: nodes,
            forwardedFromID: forwardedFromID);
      case MessageType.snip:
        return Snip(id,
            root: root!,
            senderID: senderID,
            mediaID: mediaID!,
            tempMediaID: tempMediaID,
            tempMediaTS: tempMediaTS,
            isRead: isRead,
            text: text);
      case MessageType.reaction:
        return Reaction(id,
            root: root!,
            senderID: senderID,
            messageID: messageID!,
            reactors: reactors!,
            mediaID: mediaID!,
            tempMediaTS: tempMediaTS,
            tempMediaID: tempMediaID);
      case MessageType.payment:
        return Payment(
            paymentID: paymentID!,
            payment: payment,
            tempPaymentID: tempPaymentID,
            tempPaymentTS: tempPaymentTS,
            targets: targets ?? [],
            senderID: senderID);
      case MessageType.reactionInc:
        return ReactionIncrement(id,
            root: root!,
            messageID: messageID!,
            reactionID: reactionID!,
            senderID: senderID);
      // TODO: Handle this case.
      case MessageType.bill:
      // TODO: Handle this case.
      case MessageType.post:
      // TODO: Handle this case.
    }
    throw 'Unimplemented Sendable.fromJson type: $type';
  }

  @override
  Map<String, String> toJson({bool includeLocal = true}) {
    // objects are all strings, required by FCM notification data
    final rs = _reactions?.map((r) => r.toJson()).toList();
    final tg = _targets?.map((r) => r.toJson()).toList();

    return {
      if (includeLocal && _targets != null) "targets": youKnowEncode(tg),
      "id": id.value,
      "type": type.name,
      "senderID": senderID.value,
      if (_reactions != null) "reactions": youKnowEncode(rs),
      if (_root != null) "root": _root!.value,
      if (_isSent != null && includeLocal) "isSent": _isSent!.toString(),
      if (_isRead != null && includeLocal) "isRead": _isRead!.toString(),
      if (_payment != null) "payment": _payment!.toYouKnow(),
      if (_reactionID != null) "reactionID": _reactionID!.value,
      if (_forwardedFromID != null) "forwardedFromID": _forwardedFromID!.value,
      if (_paymentID != null) "paymentID": _paymentID!.value,
      if (_nodes != null) "nodes": _nodes!.values,
      if (_replies != null) "replies": _replies!.values,
      if (_tips != null) "tips": _tips!.values,
      if (_reactors != null) "reactors": _reactors!.values,
      if (_text != null) "text": _text!,
      if (_timestamp != null) "timestamp": _timestamp!.toString(),
      if (_mediaID != null) "mediaID": _mediaID!.value,
      if (_messageID != null) "messageID": _messageID!.value,
      if (_tempMediaID != null) "onlineMediaID": _tempMediaID!.value,
      if (_tempMediaTS != null) "tempMediaTS": _tempMediaTS!.toString(),
      if (_tempPaymentID != null) "tempPaymentID": _tempPaymentID!.value,
      if (_tempPaymentTS != null) "tempPaymentTS": _tempPaymentTS!.toString(),
    };
  }

  Future<void> processMessage({
    void Function()? onError,
    void Function()? onSent,
  });
}

mixin Reads on Down4Message, Locals {
  bool get isRead;
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
    final media = await global<Down4Media>(mediaID);
    final fullJson = preMsg ?? toJson();
    if (media != null) {
      final upload = await media.temporaryUpload();
      if (upload == null) return null;
      if (upload.freshID != null) {
        fullJson["tempMediaID"] = upload.freshID.toString();
        fullJson["tempMediaTS"] = upload.freshTS.toString();
      }
    }
    return fullJson;
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

  Future<Map<String, Object>?> _paymentUploadRoutine({
    Map<String, String>? preMsg,
  }) async {
    final fullJson = preMsg ?? toJson(includeLocal: false);
    final asData = jsonEncode(fullJson);
    // only way to have over 4kb in payload is to have a payment
    if (asData.length > 4000) {
      if (payment != null) {
        final upload = await payment!.temporaryUpload();
        if (upload == null) return null;
        if (upload.freshID != null) {
          fullJson["tempPaymentID"] = upload.freshID.toString();
          fullJson["tempPaymentTS"] = upload.freshTS.toString();
        }
        fullJson.remove("payment");
      }
    }
    return fullJson;
  }
}

mixin Roots on Down4Message {
  ComposedID get root;

  Future<ChatN?> get rootNode => global<ChatN>(root);

  @override
  Future<String> makeHeader() async {
    final rootNode = await global<ChatN>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupN) {
      return rootNode.displayName;
    } else {
      return g.self.displayName;
    }
  }

  @override
  Future<List<MessageTarget>?> get targets async {
    if (_targets != null) return _targets;
    return _targets = (await (await rootNode)?.allTargets());
  }
}

mixin Messages on Down4Message, Roots, Medias, Reads, Texts, Locals {
  Future<void> onReceipt(void Function(ChatN rootNode) callback) async {
    // get the rootNode
    final rootNode =
        await global<ChatN>(root, doFetch: true, doMergeIfFetch: true);
    if (rootNode == null) return;

    User? senderNode = await global<User>(senderID);
    Down4Media? msgMedia;

    if (senderNode != null && senderNode.isConnected) {
      // we predownload the media, else it's download on open
      msgMedia = await global<Down4Media>(mediaID,
          doFetch: true, doMergeIfFetch: true, tempID: tempMediaID);
    }

    // get the rootNode media
    await global<Down4Media>(rootNode.mediaID,
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
    void Function()? onSent,
  }) async {
    final allTargets = await (await rootNode)?.allTargets();
    if (allTargets == null) return onError?.call();

    final nonCurDev = allTargets.where((t) => t.device != g.self.deviceID);
    await MessageRequest(
            sender: g.self.id,
            tokens: nonCurDev.map((e) => e.token).toList(),
            header: await makeHeader(),
            body: await makeBody(),
            data: jsonEncode(toJson()))
        .process();
  }
}

class Reaction extends Down4Message with Roots, Medias {
  @override
  bool operator ==(Object other) => other is Reaction && other.id == id;

  @override
  int get hashCode => id.value.hashCode;

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
  MessageType get type => MessageType.reaction;

  @override
  Future<String> makeBody() async {
    final rootNode = await global<ChatN>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupN) {
      return "${g.self.firstName} reacted to your message!";
    } else {
      return "reacted to your message!";
    }
  }

  @override
  Future<void> processMessage({
    void Function()? onSent,
    void Function()? onError,
    Map<String, String>? specificData,
  }) async {
    final jsonData = await _mediableRoutine();
    final rMsg = await global<Chat>(messageID);
    if (jsonData == null || rMsg == null) return;
    // this is all the tokens, including all of the sender's devices
    final targets = await (await rootNode)?.allTargets();
    if (targets == null) return onError?.call();

    // targets for notifications are all except current device
    final targetsForData = targets
        .where((t) => t.device != g.self.deviceID)
        .map((e) => e.token)
        .toList();

    // targets for notification is the sender of the message we are reacting to
    // if that sender is not ourself
    final targetsForNotification = targets
        .where((t) => t.userID != g.self.id && t.userID == rMsg.senderID)
        .map((e) => e.token)
        .toList();

    final data = jsonEncode(jsonData);
    List<MessageRequest> reqs = [];
    if (targetsForNotification.isNotEmpty) {
      reqs.add(MessageRequest(
          sender: g.self.id,
          tokens: targetsForNotification,
          header: await makeHeader(),
          body: await makeBody(),
          data: ""));
    }

    if (targetsForData.isNotEmpty) {
      reqs.add(MessageRequest(
          sender: g.self.id,
          tokens: targetsForData,
          header: "",
          body: "",
          data: data));
    }

    await Future.wait(reqs.map((e) => e.process()));
  }
}

class Snip extends Down4Message
    with Down4Object, Locals, Roots, Medias, Reads, Texts, Messages {
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
    super.targets,
    super.tempMediaID,
    super.tempMediaTS,
    bool isRead = false,
  }) : super(isRead: isRead, root: root, mediaID: mediaID);

  @override
  MessageType get type => MessageType.snip;

  @override
  Future<String> makeBody() async {
    final rootNode = await global<ChatN>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupN) {
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
    void Function()? onSent,
    Map<String, String>? specificData,
  }) async {
    final jsonData = await _mediableRoutine();
    if (jsonData == null) return onError?.call();

    final targets = await (await rootNode)?.allTargets();
    if (targets == null) return onError?.call();

    final tokens = targets
        .where((t) => t.device != g.self.deviceID)
        .map((t) => t.token)
        .toList();

    MessageRequest(
      sender: g.self.id,
      tokens: tokens,
      header: await makeHeader(),
      body: await makeBody(),
      data: jsonEncode(jsonData),
    ).process();
  }

  @override
  bool get isRead => _isRead!;
}

class Chat extends Down4Message
    with Locals, Roots, Medias, Texts, Reads, Messages {
  @override
  ComposedID get root => _root!;

  Set<Down4ID>? get replies => _replies;
  Set<ComposedID>? get nodes => _nodes;

  int get timestamp => _timestamp!;

  ComposedID? get forwardedFromID => _forwardedFromID;

  bool get hadForwards => (_messages ?? _nodes ?? {}).isNotEmpty;

  Future<void> mergeReactions() async {
    final jsonRs = reactions.map((e) => e.toJson()).toList();
    await merge({"reactions": jsonEncode(jsonRs)});
  }

  Chat(
    super.id, {
    required super.senderID,
    required ComposedID root,
    required int timestamp,
    List<Reaction>? reactions,
    super.targets,
    super.messages,
    super.text,
    super.mediaID,
    super.tempMediaID,
    super.tempMediaTS,
    super.isSent = false,
    super.isRead = false,
    super.forwardedFromID,
    super.nodes,
    super.replies,
  }) : super(reactions: reactions ?? [], timestamp: timestamp, root: root);

  bool get isSent => _isSent!;

  String get messagePreview => forwardedFromID != null
      ? ">> forwarded message"
      : (text ?? "").isEmpty
          ? "&attachment"
          : text!;

  List<Reaction> get reactions => _reactions!;

  Future<void> addReaction(Reaction r) async {
    final elementIsAlreadyThere = _reactions!.contains(r);
    if (!elementIsAlreadyThere) {
      reactions.add(r);
      final jsonRs = reactions.map((r) => r.toJson()).toList();
      await merge({"reactions": youKnowEncode(jsonRs)});
    }
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
    final rootNode = await global<ChatN>(root);
    if (rootNode == null) return "";
    if (rootNode is GroupN) {
      return "${g.self.firstName}: $messagePreview";
    } else {
      return messagePreview;
    }
  }

  Future<void> _forwardMessagesRoutine({
    void Function()? onSent,
    void Function()? onError,
  }) async {
    for (final msgID in (_messages ?? {}).toList().reversed) {
      final msg = await global<Chat>(msgID);
      if (msg != null) {
        msg.copiedFor(root: root)
          ..cache()
          ..markRead()
          ..processMessage(onSent: onSent, onError: onError);
      }
    }
  }

  @override
  Database get dbb => messagesDB;

  Chat copiedFor({required ComposedID root}) {
    return Down4Message.fromJson(toJson(includeLocal: false)
      ..["id"] = ComposedID().value
      ..["timestamp"] = makeTimestamp().toString()
      ..["root"] = root.value) as Chat;
  }

  @override
  Future<void> processMessage({
    void Function()? onError,
    void Function()? onSent,
    Map<String, String>? specificData,
  }) async {
    _forwardMessagesRoutine(onError: onError, onSent: onSent);
    final data = await _mediableRoutine();
    final stringData = jsonEncode(data);
    final ts = await targets;
    if (ts == null) return onError?.call();

    List<Future<MessageBatchResponse>> requests = [];
    List<int> indexArr = [];
    List<MessageTarget> selfTargets = [];
    List<MessageTarget> otherTargets = [];
    for (final (i, t) in ts.indexed) {
      if (t.success) continue;
      if (t.userID == g.self.id && t.device != g.self.deviceID) {
        selfTargets.add(t);
        indexArr.add(i);
      } else {
        otherTargets.add(t);
        indexArr.add(i);
      }
    }

    if (selfTargets.isNotEmpty) {
      requests.add(MessageRequest(
              sender: g.self.id,
              tokens: selfTargets.map((e) => e.token).toList(),
              header: "",
              body: "",
              data: stringData)
          .process());
    }

    if (otherTargets.isNotEmpty) {
      requests.add(MessageRequest(
              sender: g.self.id,
              tokens: otherTargets.map((e) => e.token).toList(),
              header: await makeHeader(),
              body: await makeBody(),
              data: stringData)
          .process());
    }

    final res = await Future.wait(requests).then((value) => value
        .map((e) => e.sendResponses)
        .expand((element) => element)
        .toList());

    for (final (i, r) in res.indexed) {
      final fullIx = indexArr[i];
      ts[fullIx].success = r.success;
    }

    final fullySent = ts.every((t) => t.success);
    await merge({
      "isSent": fullySent.toString(),
      "targets": youKnowEncode(ts.map((e) => e.toJson()).toList()),
    });

    onSent?.call();
  }

  @override
  bool get isRead => _isRead!;
}

class Payment extends Down4Message with Cash, Locals {
  @override
  Down4ID get paymentID => _paymentID!;

  @override
  Database get dbb => messagesDB;

  Payment({
    required super.senderID,
    required Down4ID paymentID,
    required List<MessageTarget> targets,
    ComposedID? tempPaymentID,
    int? tempPaymentTS,
    super.payment,
  }) : super(paymentID,
            paymentID: paymentID,
            targets: targets,
            tempPaymentID: tempPaymentID,
            tempPaymentTS: tempPaymentTS);

  @override
  MessageType get type => MessageType.payment;

  @override
  Future<List<MessageTarget>> get targets async => _targets!;

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
    void Function()? onSent,
  }) async {
    final data = await _paymentUploadRoutine();
    if (data == null) return onError?.call();
    final String strData = jsonEncode(data);

    final ts = await targets;

    List<Future<MessageBatchResponse>> requests = [];
    List<int> indexArr = [];
    List<MessageTarget> selfTargets = [];
    List<MessageTarget> otherTargets = [];
    for (final (i, t) in ts.indexed) {
      if (t.success) continue;
      if (t.userID == g.self.id && t.device != g.self.deviceID) {
        selfTargets.add(t);
        indexArr.add(i);
      } else {
        otherTargets.add(t);
        indexArr.add(i);
      }
    }

    if (selfTargets.isNotEmpty) {
      requests.add(MessageRequest(
              sender: g.self.id,
              tokens: selfTargets.map((e) => e.token).toList(),
              header: "",
              body: "",
              data: strData)
          .process());
    }

    if (otherTargets.isNotEmpty) {
      requests.add(MessageRequest(
              sender: g.self.id,
              tokens: otherTargets.map((e) => e.token).toList(),
              header: await makeHeader(),
              body: await makeBody(),
              data: strData)
          .process());
    }

    final res = await Future.wait(requests).then((value) => value
        .map((e) => e.sendResponses)
        .expand((element) => element)
        .toList());

    for (final (i, r) in res.indexed) {
      final fullIx = indexArr[i];
      ts[fullIx].success = r.success;
    }

    final fullySent = ts.every((t) => t.success);
    await merge({
      "isSent": fullySent.toString(),
      "targets": youKnowEncode(ts.map((e) => e.toJson()).toList()),
    });

    onSent?.call();
  }
}
