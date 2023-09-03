// import 'package:cbl/cbl.dart';
import 'package:firebase_database/firebase_database.dart';

import '../bsv/types.dart';
import '../_dart_utils.dart';
import '../globals.dart';

import '_data_utils.dart';
import 'couch.dart';
import 'medias.dart';
import 'nodes.dart';

enum MessageType { chat, snip, payment, bill, reaction, post, reactionInc }

abstract class Down4Message with Jsons {
  final String? _txt;
  final int? _timestamp;
  final ComposedID? _mediaID, _forwardedFromID;

  final String? _root;
  final Down4ID? _reactionID, _paymentID, _messageID;

  final Set<ComposedID>? _nodes, _reactors, _tips;
  final Set<Down4ID>? _replies;
  final Map<Down4ID, Reaction>? _reactions;

  final ComposedID? _tempMediaID;
  final int? _tempMediaTS;

  final ComposedID? _tempPaymentID;
  final int? _tempPaymentTS;

  bool? _isSent, _isRead;

  final ComposedID senderID;

  Down4ID? get id => null;

  Down4Message({
    required this.senderID,
    int? timestamp,
    Down4ID? reactionID,
    Set<Down4ID>? replies,
    Set<ComposedID>? nodes,
    Set<ComposedID>? reactors,
    Set<ComposedID>? tips,
    Map<Down4ID, Reaction>? reactions,
    bool? isRead,
    bool? isSent,
    String? txt,
    ComposedID? mediaID,
    String? root,
    Down4ID? messageID,
    ComposedID? forwardedFromID,
    Down4ID? paymentID,
    int? tempMediaTS,
    ComposedID? tempMediaID,
    int? tempPaymentTS,
    ComposedID? tempPaymentID,
  })  : _reactionID = reactionID,
        _txt = txt,
        _root = root,
        _isSent = isSent,
        _isRead = isRead,
        _tempPaymentTS = tempPaymentTS,
        _tempPaymentID = tempPaymentID,
        _reactions = reactions,
        _mediaID = mediaID,
        _paymentID = paymentID,
        _messageID = messageID,
        _reactors = reactors,
        _timestamp = timestamp,
        _replies = replies,
        _forwardedFromID = forwardedFromID,
        _nodes = nodes,
        _tips = tips,
        _tempMediaTS = tempMediaTS,
        _tempMediaID = tempMediaID;

  MessageType get type;

  // Future<String> get pushString;

  factory Down4Message.fromJson(Map<String, String?> decodedJson) {
    final type = MessageType.values.byName(decodedJson["type"]!);
    final id = Down4ID.fromString(decodedJson["id"])!;
    final senderID = ComposedID.fromString(decodedJson["senderID"])!;

    final root = decodedJson["root"];

    final nodes = decodedJson["nodes"].toComposedIDs();

    // messages are down4IDs
    final replies = decodedJson["replies"].toDown4IDs();

    final reactors = decodedJson["reactors"].toComposedIDs();

    final reactionID = Down4ID.fromString(decodedJson["reactionID"]);
    // final tips = (decodedJson["tips"] ?)?.split(" ");

    final forwardedFromID =
        ComposedID.fromString(decodedJson["forwardedFromID"]);

    final timestamp = int.tryParse(decodedJson["timestamp"] ?? "");
    final txt = decodedJson["txt"];
    final mediaID = ComposedID.fromString(decodedJson["mediaID"]);
    final tempMediaTS = int.tryParse(decodedJson["tempMediaTS"] ?? "");
    final tempMediaID = ComposedID.fromString(decodedJson["tempMediaID"]);
    final tempPaymentTS = int.tryParse(decodedJson["tempPaymentTS"] ?? "");
    final tempPaymentID = ComposedID.fromString(decodedJson["tempPaymentID"]);
    final messageID = Down4ID.fromString(decodedJson["messageID"]);
    final paymentID = Down4ID.fromString(decodedJson["paymentID"]);
    final isSent = decodedJson["isSent"] == "true";
    final isRead = decodedJson["isRead"] == "true";

    Map<Down4ID, Reaction>? reactions;
    final ykEncodedReactions = decodedJson["reactions"];
    if (ykEncodedReactions != null) {
      final yk = Map.from(youKnowDecode(ykEncodedReactions));
      reactions = yk.map((k, m) {
        final jsn = Map<String, String?>.from(m as Map);
        final r = Down4Message.fromJson(jsn) as Reaction;
        final rid = Down4ID.fromString(k)!;
        return MapEntry(rid, r);
      });
    }

    switch (type) {
      case MessageType.chat:
        return Chat(id as ComposedID,
            root: root!,
            senderID: senderID,
            timestamp: timestamp!,
            txt: txt,
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
        return Snip(id as ComposedID,
            root: root!,
            senderID: senderID,
            mediaID: mediaID!,
            tempMediaID: tempMediaID,
            tempMediaTS: tempMediaTS,
            isRead: isRead,
            txt: txt);
      case MessageType.reaction:
        return Reaction(id,
            senderID: senderID,
            messageID: messageID!,
            reactors: reactors!,
            mediaID: mediaID!,
            tempMediaTS: tempMediaTS,
            tempMediaID: tempMediaID);
      case MessageType.payment:
        return Payment(
            paymentID: paymentID!,
            tempPaymentID: tempPaymentID,
            tempPaymentTS: tempPaymentTS,
            senderID: senderID);
      case MessageType.reactionInc:
        return ReactionIncrement(
            messageID: messageID!, reactionID: reactionID!, senderID: senderID);
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
    final rs = _reactions?.map((k, r) => MapEntry(k.value, r.toJson()));

    return {
      if (id != null) "id": id!.value,
      "type": type.name,
      "senderID": senderID.value,
      if (_root != null) "root": _root!,
      if (_reactions != null && includeLocal) "reactions": youKnowEncode(rs),
      if (_isSent != null && includeLocal) "isSent": _isSent!.toString(),
      if (_isRead != null && includeLocal) "isRead": _isRead!.toString(),
      if (_reactionID != null) "reactionID": _reactionID!.value,
      if (_forwardedFromID != null) "forwardedFromID": _forwardedFromID!.value,
      if (_paymentID != null) "paymentID": _paymentID!.value,
      if (_nodes != null) "nodes": _nodes!.values,
      if (_replies != null) "replies": _replies!.values,
      if (_tips != null) "tips": _tips!.values,
      if (_reactors != null) "reactors": _reactors!.values,
      if (_txt != null) "txt": _txt!,
      if (_timestamp != null) "timestamp": _timestamp!.toString(),
      if (_mediaID != null) "mediaID": _mediaID!.value,
      if (_messageID != null) "messageID": _messageID!.value,
      if (_tempMediaID != null) "tempMediaID": _tempMediaID!.value,
      if (_tempMediaTS != null) "tempMediaTS": _tempMediaTS!.toString(),
      if (_tempPaymentID != null) "tempPaymentID": _tempPaymentID!.value,
      if (_tempPaymentTS != null) "tempPaymentTS": _tempPaymentTS!.toString(),
    };
  }

  Future<String?> uploadRoutine();
}

mixin Reads on Down4Message, Locals {
  bool get isRead;
  void markRead() {
    if (isRead) return;
    merge({"isRead": (_isRead = true).toString()});
  }
}

mixin Medias on Down4Message {
  ComposedID? get mediaID => _mediaID;
  ComposedID? get tempMediaID => _tempMediaID;
  int? get tempMediaTS => _tempMediaTS;

  // // returns the dataPayload if routine was successful
  // Future<Map<String, String>?> _mediableRoutine({
  //   Map<String, String>? preMsg,
  // }) async {
  //   final media = await global<Down4Media>(mediaID);
  //   final fullJson = preMsg ?? toJson(includeLocal: false);
  //   if (media != null) {
  //     final upload = await media.temporaryUpload();
  //     if (upload == null) return null;
  //     if (upload.freshID != null) {
  //       fullJson["tempMediaID"] = upload.freshID!.value;
  //       fullJson["tempMediaTS"] = upload.freshTS!.toString();
  //     } else {
  //       fullJson["tempMediaID"] = media.tempID!.value;
  //       fullJson["tempMediaTS"] = media.tempTS!.toString();
  //     }
  //   }
  //   return fullJson;
  // }
}

mixin Texts on Down4Message {
  String? get txt => _txt;
}

mixin Cash on Down4Message {
  Down4ID? get paymentID => _paymentID;

  Future<ComposedID?> get tempPaymentID async {
    final payment = await global<Down4Payment>(paymentID);
    return payment?.tempID;
  }

  Future<int?> get tempPaymentTS async {
    final payment = await global<Down4Payment>(paymentID);
    return payment?.tempTS;
  }

  // Future<Map<String, String>?> _paymentUploadRoutine({
  //   Map<String, String>? preMsg,
  // }) async {
  //   final fullJson = preMsg ?? toJson(includeLocal: false);
  //   final payment = await global<Down4Payment>(paymentID);
  //   if (payment != null) {
  //     final upload = await payment.temporaryUpload();
  //     if (upload == null) return null;
  //     if (upload.freshID != null) {
  //       fullJson["tempPaymentID"] = upload.freshID!.value;
  //       fullJson["tempPaymentTS"] = upload.freshTS!.toString();
  //     } else {
  //       fullJson["tempPaymentID"] = payment.tempID!.value;
  //       fullJson["tempPaymentTS"] = payment.tempTS!.toString();
  //     }
  //   }
  //   return fullJson;
  // }
}

mixin Roots on Down4Message {
  String get root => _root!;

  Future<ChatN?> rootNode(ComposedID selfID) async {
    return global<ChatN>(idOfRoot(root: root, selfID: selfID));
  }

  ComposedID get idOfRoot_ => idOfRoot(root: root, selfID: g.self.id);
}

mixin Messages on Down4Message, Roots, Medias, Reads, Texts, Locals {
  // Future<void> onReceipt(void Function(ChatN rootNode) callback) async {
  //   // get the rootNode
  //   final rootID = idOfRoot(root: root, selfID: g.self.id);

  //   final rootNode =
  //       await global<ChatN>(rootID, doFetch: true, doMergeIfFetch: true);
  //   if (rootNode == null) return;

  //   PersonN? senderNode = await global<User>(senderID);
  //   Down4Media? msgMedia;

  //   if (senderNode != null && senderNode.isConnected) {
  //     // we predownload the media, else it's download on open
  //     msgMedia = await global<Down4Media>(mediaID,
  //         doFetch: true, doMergeIfFetch: true, tempID: tempMediaID);
  //   }

  //   // get the rootNode media
  //   await global<Down4Media>(rootNode.mediaID,
  //       doFetch: true, doMergeIfFetch: true);

  //   // msg medias references are dynamic and always get updated
  //   // this is because messages are not kept for ever on server
  //   if (tempMediaID != null) {
  //     await msgMedia?.updateTempReferences(tempMediaID!, tempMediaTS!);
  //   }
  //   merge();

  //   return callback(rootNode);
  // }

  @override
  Future<String?> uploadRoutine() async {
    final Map<String, String> msgData = toJson(includeLocal: false);
    final media = await global<Down4Media>(mediaID);
    if (media != null) {
      final upld = await media.temporaryUpload();
      if (upld == null) return null;
      msgData["tempMediaID"] = media.tempID!.value;
      msgData["tempMediaTS"] = media.tempTS!.toString();
    }
    final successfulMsgUpload = await uploadMessageData(msgData);
    if (!successfulMsgUpload) return null;
    return "m!${id.value}";
  }

  @override
  ComposedID get id;

  DatabaseReference get ref =>
      id.server.realtimeDB.ref("messages/${id.unik}");

  Future<bool> uploadMessageData(Map<String, String?> data) async {
    try {
      await ref.set(data);
      return true;
    } catch (e) {
      print("error uploading message data: $e\n");
      return false;
    }
  }
}

class ReactionIncrement extends Down4Message {
  Down4ID get messageID => _messageID!;
  Down4ID get reactionID => _reactionID!;

  ReactionIncrement({
    required super.senderID,
    required Down4ID messageID,
    required Down4ID reactionID,
  }) : super(messageID: messageID, reactionID: reactionID);

  @override
  MessageType get type => MessageType.reactionInc;

  @override
  Future<String> uploadRoutine() async {
    return "i!${messageID.value}!${reactionID.value}!${senderID.value}";
  }
}

class Reaction extends Down4Message with Medias {
  @override
  Down4ID id;

  @override
  bool operator ==(Object other) => other is Reaction && other.id == id;

  @override
  int get hashCode => id.value.hashCode;

  @override // override because non-nullable
  ComposedID get mediaID => _mediaID!;

  Down4ID get messageID => _messageID!;
  Set<ComposedID> get reactors => _reactors!;

  factory Reaction.fromStrings(List<String> strs) {
    // 0   1      2          3         4        5          6
    // r!msgID!mediaID!tempMediaID!reactorID!reactionID!tempMediaTS
    return Reaction(Down4ID.fromString(strs[5])!,
        senderID: ComposedID.fromString(strs[4])!,
        mediaID: ComposedID.fromString(strs[2])!,
        messageID: ComposedID.fromString(strs[1])!,
        tempMediaID: ComposedID.fromString(strs[3]),
        tempMediaTS: int.tryParse(strs[6]),
        reactors: {ComposedID.fromString(strs[4])!});
  }

  Reaction(
    this.id, {
    required super.senderID,
    required ComposedID mediaID,
    super.tempMediaID,
    super.tempMediaTS,
    required Down4ID messageID,
    required Set<ComposedID> reactors,
  }) : super(mediaID: mediaID, messageID: messageID, reactors: reactors);

  @override
  MessageType get type => MessageType.reaction;

  @override
  Future<String?> uploadRoutine() async {
    final media = await global<Down4Image>(mediaID);
    if (media == null) return null;
    final upld = await media.temporaryUpload();
    if (upld == null) return null;

    final String msgID = messageID.value;
    final String mID = mediaID.value;
    final String tmpID = media.tempID!.value;
    final String tmpTS = media.tempTS!.toString();
    final String sender = senderID.value;
    final String sid = id.value;
    return "r!$msgID!$mID!$tmpID!$sender!$sid!$tmpTS";
  }
}

class Snip extends Down4Message
    with Down4Object, Locals, Roots, Medias, Reads, Texts, Messages {
  @override
  ComposedID id;

  @override
  ComposedID get mediaID => _mediaID!;

  Snip(
    this.id, {
    required super.senderID,
    required String root,
    required ComposedID mediaID,
    required super.txt,
    super.tempMediaID,
    super.tempMediaTS,
    bool isRead = false,
  }) : super(isRead: isRead, root: root, mediaID: mediaID);

  @override
  MessageType get type => MessageType.snip;

  @override
  String get table => "messages";
  // Database get dbb => messagesDB;

  // @override
  // Future<String?> uploadRoutine() async {
  //   final r = await _mediableRoutine();
  //   if (r == null) return null;
  //   final successfulUpload = await uploadMessageData(r);
  //   if (!successfulUpload) return null;
  //   return "s!${mediaID.value}!${r["tempMediaID"]}";
  // }

  @override
  bool get isRead => _isRead!;
}

class Chat extends Down4Message
    with Down4Object, Locals, Roots, Medias, Texts, Reads, Messages {
  @override
  ComposedID id;

  Set<Down4ID>? get replies => _replies;
  Set<ComposedID>? get nodes => _nodes;

  int get timestamp => _timestamp!;

  ComposedID? get forwardedFromID => _forwardedFromID;

  void mergeReactions() {
    final jsonRs = reactions.map((k, e) => MapEntry(k.value, e.toJson()));
    merge({"reactions": youKnowEncode(jsonRs)});
  }

  Chat(
    this.id, {
    required super.senderID,
    required String root,
    required int timestamp,
    Map<Down4ID, Reaction>? reactions,
    super.txt,
    super.mediaID,
    super.tempMediaID,
    super.tempMediaTS,
    super.isSent = false,
    super.isRead = false,
    super.forwardedFromID,
    super.nodes,
    super.replies,
  }) : super(root: root, reactions: reactions ?? {}, timestamp: timestamp);

  bool get isSent => _isSent!;

  String get messagePreview => forwardedFromID != null
      ? ">> forwarded message"
      : (txt ?? "").isEmpty
          ? "&attachment"
          : txt!;

  Map<Down4ID, Reaction> get reactions => _reactions!;

  void addReaction(Reaction r) {
    if (reactions[r.id] != null) return;
    reactions[r.id] = r;
    mergeReactions();
  }

  void markSent() {
    _isSent = true;
    merge({"isSent": _isSent.toString()});
  }

  // Creates a new instance of a messages that will be uploaded
  // removes the replies and local data
  // puts a new timestamp and forwarderID as forwarder and a new ID
  Chat forwarded(ComposedID newSenderID, String newRoot) {
    return Chat(ComposedID(),
        root: root,
        senderID: newSenderID,
        forwardedFromID: forwardedFromID ?? senderID,
        txt: txt,
        nodes: nodes,
        mediaID: mediaID,
        tempMediaID: tempMediaID,
        tempMediaTS: tempMediaTS,
        timestamp: makeTimestamp());
  }

  @override
  MessageType get type => MessageType.chat;

  @override
  String get table => "messages";
  // Database get dbb => messagesDB;

  Chat copiedFor(String root) {
    final map = Map<String, String?>.from(toJson(includeLocal: false));
    return Down4Message.fromJson(map
      ..["replies"] = null
      ..["id"] = ComposedID().value
      ..["timestamp"] = makeTimestamp().toString()
      ..["root"] = root) as Chat;
  }

  @override
  bool get isRead => _isRead!;
}

class Payment extends Down4Message with Cash {
  @override
  Down4ID get paymentID => _paymentID!;

  Payment({
    required super.senderID,
    required Down4ID paymentID,
    ComposedID? tempPaymentID,
    int? tempPaymentTS,
  }) : super(
            paymentID: paymentID,
            tempPaymentID: tempPaymentID,
            tempPaymentTS: tempPaymentTS);

  @override
  MessageType get type => MessageType.payment;

  @override
  Future<String?> uploadRoutine() async {
    final payment = await global<Down4Payment>(paymentID);
    if (payment == null) return null;
    final upload = await payment.temporaryUpload();
    if (upload == null) return null;
    if (upload.freshID != null) {
      final String freshID = upload.freshID!.value;
      final String freshTS = upload.freshTS!.toString();
      return "p!${paymentID.value}!$freshID!$freshTS";
    } else {
      final String tmpID = payment.tempID!.value;
      final String tmpTS = payment.tempTS!.toString();
      return "p!${paymentID.value}!$tmpID!$tmpTS";
    }
  }
}
