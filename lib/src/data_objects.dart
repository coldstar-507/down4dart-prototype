import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';

typedef Identifier = String;

class Down4MediaMetadata {
  final bool toReverse, shareable, payToView, payToOwn, isVideo;
  final Identifier owner;
  Down4MediaMetadata({
    required this.owner,
    required this.isVideo,
    this.toReverse = false,
    this.payToOwn = false,
    this.shareable = true,
    this.payToView = false,
  });

  Down4MediaMetadata.fromJson(Map<String, String> json)
      : owner = json['ownr'] as Identifier,
        toReverse = json['trv'] == 'true',
        shareable = json['shr'] == 'true',
        payToView = json['ptv'] == 'true',
        payToOwn = json['pto'] == 'true',
        isVideo = json['vid'] == 'true';

  Map<String, String> toJson() {
    return {
      "ownr": owner.toString(),
      "trv": toReverse.toString(),
      "shr": shareable.toString(),
      "ptv": payToView.toString(),
      "pto": payToOwn.toString(),
      "vid": isVideo.toString(),
    };
  }
}

class Down4Media {
  final Down4MediaMetadata metadata;
  final Identifier id;
  String? thumbnail;
  String? dbid;
  Uint8List? data;

  Down4Media(
      {required this.id,
      required this.metadata,
      this.data,
      this.dbid,
      this.thumbnail});

  Down4Media.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        metadata = Down4MediaMetadata.fromJson(json['md']);

  Map<String, dynamic> toJson() {
    return {'id': id, 'md': metadata.toJson()};
  }

  Future<void> downloadMedia() async {
    if (dbid != null) {
      var ref = FirebaseStorage.instance.ref(dbid);
      ref.getData().then((value) => data = value);
    }
  }

  Future<void> generateThumbnail() async {
    if (data != null) {
      FlutterImageCompress.compressWithList(data!,
              minWidth: 30, minHeight: 30, quality: 50)
          .then((value) => thumbnail = base64Encode(value.toList()));
    }
  }

  String get ownerid => metadata.owner;

  bool get isVideo => metadata.isVideo;

  bool get isImage => !metadata.isVideo;

  Down4MediaMetadata get down4metadata => metadata;

  Map<String, String> get jsonMetadata => metadata.toJson();

  bool get isLocal => data != null;

  bool get hasThumbnail => thumbnail != null;

  bool get isOnlyOnDatabase => !isLocal && dbid != null;
}

enum MessageTypes {
  fr, // friend request
  b, // bill
  p, // payment
  m, // message
}

enum NodeTypes {
  rt,
  usr,
  cht,
  mkt,
  cpt,
  jnl,
  itm,
  evt,
  tkt,
}

class Reaction {
  final Identifier id, target, sender; // target, sender
  final String base64image; // base64
  const Reaction({
    required this.id,
    required this.target,
    required this.sender,
    required this.base64image,
  });

  Reaction.fromJson(Map<String, dynamic> json)
      : id = json['id'] as Identifier,
        target = json['tg'] as Identifier,
        sender = json['sd'] as Identifier,
        base64image = json['bim'] as String;

  Map<String, dynamic> toJson() =>
      {'tg': target, 'sd': sender, 'bim': base64image, 'id': id};
}

class Down4Message {
  final Identifier id, sender, target;
  final String thumbnail;
  final String name; // sender name
  final String? text;
  final Down4Media? media;
  final int? timestamp;
  final bool isChat; // true is chat, false is post
  final List<Identifier>? reactions, nodes; // reactions, nodes
  const Down4Message(
      {required this.id,
      required this.thumbnail,
      required this.sender,
      required this.target,
      required this.name,
      required this.isChat,
      this.timestamp,
      this.text,
      this.media,
      this.reactions,
      this.nodes});

  Down4Message.fromJson(Map<String, dynamic> json)
      : id = json['id'] as Identifier,
        target = json['tgt'],
        sender = json['sd'] as Identifier,
        thumbnail = json['tn'] as String,
        name = json['nm'] as String,
        isChat = json['ch'] == 'true',
        text = json['txt'] as String?,
        timestamp = int.parse(json['ts']),
        media = Down4Media.fromJson(json['m']),
        reactions = jsonDecode(json['r']),
        nodes = jsonDecode(json['n']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'sd': sender,
        'tn': thumbnail,
        'nm': name,
        'txt': text,
        'ts': timestamp.toString(),
        'r': reactions.toString(),
        'n': nodes.toString(),
        'ch': isChat.toString()
      }..removeWhere((key, value) => value == null);
}

class Node {
  final NodeTypes t;
  final Identifier id;
  final String nm;
  final String im;
  final String? tn, ln;
  final List<Identifier>? adm, ch, pr; // admin, childs, parents
  List<Identifier>? msg; // messages / either post or chat
  Node({
    required this.t,
    required this.id,
    required this.nm,
    required this.im,
    this.ln,
    this.tn,
    this.msg,
    this.adm,
    this.ch,
    this.pr,
  });

  Node.fromJson(Map<String, dynamic> json)
      : t = NodeTypes.values.byName(json['t']),
        id = json['id'] as Identifier,
        nm = json['nm'] as String,
        ln = json['ln'] as String?,
        im = json['im'] as String,
        tn = json['tn'] as String,
        ch = json['ch'] as List<Identifier>?,
        pr = json['pr'] as List<Identifier>?,
        adm = json['adm'] as List<Identifier>?,
        msg = json['msg'] as List<Identifier>?;

  Map<String, dynamic> toJson() => {
        't': t.name,
        'id': id,
        'nm': nm,
        'ln': ln,
        'im': im,
        'tn': tn,
        'ch': ch,
        'pr': pr,
        'adm': adm,
        'msg': msg,
      }..removeWhere((key, value) => value == null);
}
