import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:flutter/services.dart';
import 'render_objects/palette.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'render_objects/_down4_flutter_utils.dart';
import 'render_objects/chat_message.dart';

import 'data_objects.dart';
import 'bsv/types.dart';
import 'bsv/wallet.dart';
import 'web_requests.dart' show fetchPalettes;

final g = Singletons.instance;
final db = FirebaseDatabase.instance.ref();
var _fs = FirebaseFirestore.instance;
final _st = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _st_node = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

Future<bool> uploadPayment(Down4Payment pay) async {
  try {
    await _st.ref(pay.id).putData(pay.compressed.toUint8List());
    return true;
  } catch (e) {
    print("Error uploading payment: $e");
    return false;
  }
}

Future<bool> uploadPalette(Palette2 p) async {
  Future<bool> uploadImage() async {
    final media = p.image;
    if (media == null) return true;
    final data = await (media.isVideo ? media.videoData : media.imageData);
    if (data == null) return true;
    try {
      final metadata = media.toJson(withLocalValues: true);
      final settableMetadata = SettableMetadata(customMetadata: metadata);
      await _st_node.ref(media.id).putData(data, settableMetadata);
      return true;
    } catch (e) {
      print("Error uploading node image: $e");
      return false;
    }
  }

  Future<bool> uploadNode() async {
    final body = p.node.toJson(withLocalValues: false);
    try {
      await _fs.collection("Nodes").doc(p.id).set(body);
      return true;
    } catch (e) {
      print("Failure uploading node: $e");
      return false;
    }
  }

  List<Future<bool>> successes = [uploadImage(), uploadNode()];

  final success = Future.wait(successes).then((s) => s.every((e) => e));
  return success;
}

// String _mediaPath(String mediaID, {bool isThumbnail = false}) =>
//     "${g.boxes.docPath}/$mediaID${isThumbnail ? "-TN" : ""}";

// Future<void> _deleteMediaFile(String path) async {
//   try {
//     await File(path).delete();
//   } on PathNotFoundException catch (e) {
//     print("Cannot delete, this file is external: $e");
//   } catch (e) {
//     print("Cannot delete this file for this reason: $e");
//   }
// }

String messagePushId() => db.child("Messages").push().key!;

// Future<FireMedia?> downloadMessageMediaAsNodeMedia(ID mediaID) async {
//   final ref = _st.ref(mediaID);
//   try {
//     final md = await ref.getMetadata();
//     final data = await ref.getData();
//     if (data == null) return null;
//     final d4md = MediaMetadata.fromJson(md.customMetadata!);
//     return FireMedia(data: data, id: mediaID, metadata: d4md);
//   } catch (e) {
//     print("Error downloading media: $e");
//     return null;
//   }
// }

// Future<FireMessage?> downloadMessage(ID msgID) async {
//   final s = await db.child("Messages").child(msgID).get();
//   if (!s.exists) return null;
//   print("MESSAGE VALUE = ${s.value}");
//   final json = Map<String, dynamic>.from(s.value as Map);
//   return FireMessage.fromJson(json);
// }

Future<Down4Payment?> downloadPayment(ID paymentID) async {
  final payRef = _st.ref(paymentID);
  try {
    final compressed = await payRef.getData();
    if (compressed == null) {
      print("Error, no data at payment id: $paymentID");
      return null;
    }
    print("Success downloading payment id: $paymentID");
    return Down4Payment.fromCompressed(compressed);
  } catch (e) {
    print("Error downloading payment id: $paymentID, err: $e");
    return null;
  }
}

// Future<FireMedia?> downloadAndWriteMedia(
//   String mediaID, {
//   bool isNodeMedia = false,
// }) async {
//   final mediaRef = isNodeMedia ? _st_node.ref(mediaID) : _st.ref(mediaID);
//   try {
//     final futureMediaData = mediaRef.getData(31457280); // 30mib
//     final fullMetadata = await mediaRef.getMetadata();
//     final customMetadata = fullMetadata.customMetadata as Map<String, String>;
//     final mediaMetadata = MediaMetadata.fromJson(customMetadata);
//     final path = "${g.boxes.docPath}/$mediaID";
//     final mediaData = await futureMediaData;
//     if (mediaData != null) {
//       await File(path).writeAsBytes(mediaData);
//     }
//     return FireMedia(id: mediaID, path: path, metadata: mediaMetadata);
//   } catch (e) {
//     print("Error downloading mediaID: $mediaID, isNode: $isNodeMedia\n$e");
//     return null;
//   }
// }

// Future<bool> uploadHyperchatMedia(FireMedia media) async {
//   if (!media.onlineTimestamp.shouldBeUpdated) return true;
//   var mediaRef = _st.ref(media.id);
//   try {
//     await mediaRef.putData(
//         media.data, SettableMetadata(customMetadata: media.metadata.toJson()));
//     return true;
//   } catch (e) {
//     print("Error uploading temporary node media: $e");
//     return false;
//   }
// }

// Future<bool> uploadMedia(FireMedia media) async {
//   if (media.file == null) {
//     print("Error, media id: ${media.id} doesn't have a file");
//     return false;
//   }
//   final mediaRef = _st.ref(media.id);
//   if (media.metadata.canSkipCheck) {
//     media.metadata.canSkipCheck = false;
//     await media.save();
//     try {
//       await mediaRef.putFile(
//         media.file!,
//         SettableMetadata(customMetadata: media.metadata.toJson()),
//       );
//       print("Success uploading the media id: ${media.id}");
//       return true;
//     } on FirebaseException catch (e) {
//       print("Error uploading media id: ${media.id}, err: $e");
//       return false;
//     }
//   } else {
//     try {
//       final metadata = (await mediaRef.getMetadata());
//       final down4Metadata = MediaMetadata.fromJson(metadata.customMetadata!);
//       if (down4Metadata.timestamp.shouldBeUpdated) {
//         final newTimeStamp = timeStamp();
//         if (newTimeStamp > down4Metadata.timestamp) {
//           down4Metadata.timestamp = newTimeStamp;
//           await mediaRef.updateMetadata(
//             SettableMetadata(customMetadata: down4Metadata.toJson()),
//           );
//         }
//         print("Success updating media metadata id: ${media.id}");
//         return true;
//       }
//       print("Success, no need to update the media id: ${media.id} metadata");
//       return true;
//     } catch (e) {
//       // TODO, find the actual exception we are looking for, docs aren't clear
//       // If there's an exception, it should mean that there is no media, so we
//       // do the full upload
//       try {
//         media.metadata.timestamp = timeStamp();
//         await mediaRef.putFile(media.file!,
//             SettableMetadata(customMetadata: media.metadata.toJson()));
//         print("Success uploading media id: ${media.id} after check failed");
//         return true;
//       } on FirebaseException catch (e) {
//         print("Error uploading media id: ${media.id}, err: $e");
//         return false;
//       }
//     }
//   }
// }

// Future<bool> uploadMessage(FireMessage msg, {required bool skipCheck}) async {
//   final msgRef = db.child("Messages").child(msg.id);
//   if (skipCheck) {
//     try {
//       await msgRef.set(msg.toJson());
//       print("Success uploading message id: ${msg.id}");
//       return true;
//     } catch (e) {
//       print("Error uploading message id: ${msg.id}, error: $e");
//       return false;
//     }
//   } else if (msg.timestamp.shouldBeUpdated) {
//     try {
//       final tsRef = msgRef.child("ts");
//       final newTs = timeStamp();
//       final currentTs = await tsRef.get();
//       if (!currentTs.exists) {
//         msg.timestamp = newTs;
//         return uploadMessage(msg, skipCheck: true);
//       } else {
//         final ts = currentTs.value as int;
//         if (newTs > ts) await tsRef.set(newTs);
//         print("Success updating the timestamp of message id: ${msg.id}");
//         return true;
//       }
//     } catch (e) {
//       print("Error updating message id: ${msg.id}, error: $e");
//       return false;
//     }
//   } else {
//     print("Success, message id: ${msg.id} doesn't need to be updated");
//     return true;
//   }
// }

// Future<File> writeMedia({
//   required Uint8List mediaData,
//   required String mediaID,
//   bool isThumbnail = false,
// }) async =>
//     File(_mediaPath(mediaID, isThumbnail: isThumbnail)).writeAsBytes(mediaData);

// Future<File> copyMedia({
//   required String fromPath,
//   required String mediaID,
//   bool isThumbnail = false,
// }) async =>
//     File(fromPath).copy(_mediaPath(mediaID, isThumbnail: isThumbnail));

// Future<File?> makeThumbnail({
//   required String videoPath,
//   required String mediaID,
// }) async {
//   final tn = await VideoThumbnail.thumbnailData(video: videoPath, quality: 90);
//   if (tn != null) {
//     return writeMedia(mediaData: tn, mediaID: mediaID, isThumbnail: true);
//   }
//   return null;
// }

extension ExchangeRateSave on ExchangeRate {
  void save() {
    g.boxes.personal.put("exchangeRate", jsonEncode(this));
  }

  static ExchangeRate load() {
    final jsonEncoded = g.boxes.personal.get("exchangeRate");
    if (jsonEncoded == null) return ExchangeRate(lastUpdate: 0, rate: 0);
    return ExchangeRate.fromJson(jsonDecode(jsonEncoded));
  }
}

// extension Getters on ID {
//   Future<FireMedia?> getLocalMessageMedia() async {
//     final String? jsonEncoded = await g.boxes.medias.get(this);
//     if (jsonEncoded == null) return null;
//     return FireMedia.fromJson(jsonDecode(jsonEncoded));
//   }

//   Future<FireMessage?> getLocalMessage() async {
//     final String? jsonEncoded = await g.boxes.messages.get(this);
//     if (jsonEncoded == null) return null;
//     return FireMessage.fromJson(jsonDecode(jsonEncoded));
//   }

//   Future<FireNode?> getLocalNode() async {
//     final String? jsonEncoded = await g.boxes.nodes.get(this);
//     if (jsonEncoded == null) return null;
//     return FireNode.fromJson(jsonDecode(jsonEncoded));
//   }

//   Future<FireNode?> getHiddenNode() async {
//     final String? jsonEncoded = await g.boxes.hidden.get(this);
//     if (jsonEncoded == null) return null;
//     return FireNode.fromJson(jsonDecode(jsonEncoded));
//   }

//   Future<void> deleteLocalNode() async {
//     return await g.boxes.nodes.delete(this);
//   }
// }

// extension MessageSave on FireMessage {
//   Future<void> onReceipt({required ID root}) async {
//     reads[root] = false;
//     await save();
//     if (mediaID != null) {
//       FireMedia? media = await mediaID?.getLocalMessageMedia();
//       media ??= await downloadAndWriteMedia(mediaID!);
//       if (media != null && media.extension.isVideoExtension()) {
//         // we generate a thumbnail
//         final tn = await VideoThumbnail.thumbnailData(
//           video: media.path,
//           quality: 90,
//         );
//         if (tn != null) {
//           final f = await writeMedia(
//               mediaData: tn, mediaID: mediaID!, isThumbnail: true);
//           media.thumbnail = f.path;
//         }
//       }
//       media?.references.add(id);
//       await media?.save();
//     }
//     return;
//   }

//   Future<void> save() async {
//     return g.boxes.messages.put(id, jsonEncode(toJson(toLocal: true)));
//   }

//   Future<void> deleteFrom(Chatable node) async {
//     reads.remove(node.id);
//     node.messages.remove(id);
//     if (reads.isEmpty) return delete();
//     return;
//   }

//   Future<void> delete() async {
//     final FireMedia? media = await mediaID?.getLocalMessageMedia();
//     if (media != null) {
//       media.references.remove(id);
//       media.delete();
//     }
//     await g.boxes.messages.delete(id);
//     return;
//   }
// }

// extension NodeSave on FireNode {
//   Future<void> save({bool hidden = false}) async {
//     if (hidden) {
//       await g.boxes.hidden.put(id, jsonEncode(toJson(toLocal: true)));
//     } else {
//       if (this is Self) {
//         await g.boxes.personal.put("self", jsonEncode(toJson(toLocal: true)));
//       } else {
//         await g.boxes.nodes.put(id, jsonEncode(toJson(toLocal: true)));
//       }
//     }
//   }

//   Future<void> delete({bool hidden = false}) async {
//     var node = this;
//     if (node is Chatable && node is! Self) {
//       final msgToDelete = List<ID>.from(node.messages);
//       for (var messageID in msgToDelete) {
//         var msg = await messageID.getLocalMessage();
//         await msg?.deleteFrom(node);
//       }
//       await g.boxes.nodes.delete(id);
//     }
//   }
// }

// extension ChatableNodeExtensions on Chatable {
//   Future<Pair<String, bool>> previewInfo() async {
//     String? lastMessagePreview;
//     bool? lastMessageWasRead;
//     if (messages.isNotEmpty) {
//       final lastMessage = await messages.last.getLocalMessage();
//       lastMessageWasRead = lastMessage?.reads[id] ??= false;
//       if ((lastMessage?.text ?? "").isEmpty) {
//         lastMessagePreview = "&attachment";
//       } else {
//         lastMessagePreview = lastMessage!.text!;
//       }
//     }
//     return Pair(lastMessagePreview ?? "", lastMessageWasRead ?? true);
//   }
// }

// extension MediaSave on FireMedia {
//   Future<void> save() async {
//     return g.boxes.medias.put(id, jsonEncode(toJson(toLocal: true)));
//   }

//   Future<void> delete() async {
//     if (references.isEmpty && !isSaved) {
//       print("References are empty, deleting the file!");
//       g.boxes.medias.delete(id);
//       _deleteMediaFile(path);
//       if (thumbnail != null) {
//         _deleteMediaFile(thumbnail!);
//       }
//     }
//     return;
//   }
// }

// extension PaymentSave on Down4Payment {
//   Future<void> save() => g.boxes.payments.put(id, jsonEncode(this));
// }

extension WalletManager on Wallet {
  void setIx(int ix) => g.boxes.personal.put("ix", ix);

  static int get ix => g.boxes.personal.get("ix");

  static Down4Keys get keys =>
      Down4Keys.fromJson(jsonDecode(g.boxes.personal.get("keys")));

  Stream<Down4Payment> get payments async* {
    for (final paymentID in g.boxes.payments.keys) {
      final json = await g.boxes.payments.get(paymentID);
      if (json != null) {
        yield Down4Payment.fromJson(jsonDecode(json));
      }
    }
  }

  Stream<Down4TXOUT> get utxos async* {
    for (final utxoID in g.boxes.utxos.keys) {
      final json = await g.boxes.utxos.get(utxoID);
      if (json != null) {
        yield Down4TXOUT.fromJson(jsonDecode(json));
      }
    }
  }

  Future<Down4TXOUT?> getUtxo(ID id) async {
    final json = await g.boxes.utxos.get(id);
    if (json == null) return null;
    return Down4TXOUT.fromJson(jsonDecode(json));
  }

  Future<void> removeUtxo(ID id) async {
    await g.boxes.utxos.delete(id);
    return;
  }

  Future<Down4Payment?> getPayment(ID id) async {
    final json = await g.boxes.payments.get(id);
    if (json == null) return null;
    return Down4Payment.fromJson(jsonDecode(json));
  }

  void removePayment(ID id) {
    g.boxes.payments.delete(id);
  }

  Future<void> setPayment(Down4Payment payment) async {
    await g.boxes.payments.put(payment.id, jsonEncode(payment));
    return;
  }

  Future<void> setUtxo(Down4TXOUT utxo) async {
    await g.boxes.utxos.put(utxo.id, jsonEncode(utxo));
    return;
  }

  Future<bool> isSpent(ID utxoID) async {
    final bool? spent = await g.boxes.spents.get(utxoID);
    return spent ?? false;
  }

  Future<void> setSpent(ID id, bool spent) async {
    await g.boxes.spents.put(id, spent);
    return;
  }

  static Wallet load() {
    return Wallet(
        keys: keys,
        // payments: payments,
        // utxos: utxos,
        // getUtxo: getUtxo,
        // getPayment: getPayment,
        // removeUtxo: removeUtxo,
        // removePayment: removePayment,
        // setIx: setIx,
        // setSpent: setSpent,
        // isSpent: isSpent,
        // setPayment: setPayment,
        // setUtxo: setUtxo,
        ix: ix);
  }
}

extension SelfSave on Self {
  void save() {
    // this will be split so we don't save the whole thing everytime
    g.boxes.personal.put("self", jsonEncode(toJson(toLocal: true)));
  }

  static Self load() {
    // this will be remade so we load many different parts to make the self
    final asJson = jsonDecode(g.boxes.personal.get("self"));
    return FireNode.fromJson(asJson) as Self;
  }

  static bool notYetInitialized() {
    return g.boxes.personal.get("self") == null;
  }
}

class P {
  double scroll;
  Map<ID, Down4Object> objects;
  P({double? scroll, Map<ID, Down4Object>? objects})
      : scroll = scroll ?? 0.0,
        objects = objects ?? {};
}

class V {
  final Palette2? p;
  final ID id;
  final List<P> pages;
  int ci;

  V({required this.id, required this.pages, int? ix, this.p}) : ci = ix ?? 0;

  P get cp => pages[ci];
}

// view IDs code
// Homepage      -> 'home'
// GroupPage     -> 'group'
// HyperchatPage -> 'hyper'
// SearchPage    -> 'search'
// SnipPage      -> 'snip'
// ChatPage      -> 'c-{nodeID}'
// NodePage      -> 'n-{nodeID}'
// ForwardPage   -> 'forward'
// MoneyPage     -> 'money'
// LoadingPage   -> 'loading'
class ViewManager {
  List<V> views;
  ViewManager(this.views);
  V get cv => views.last;
  V get pv => views[views.length - 2];

  V get home => views.first;

  void push(V v) => views.add(v);
  V pop() => views.removeLast();
  void popUntilHome() {
    final nv = views.length;
    for (int i = 0; i < nv - 1; i++) {
      pop();
    }
  }

  void popInBetween() {
    final last = pop();
    popUntilHome();
    push(last);
  }
}

class Payload {
  final List<Down4Object>? forwardables;
  final List<ID>? replies;
  final String? text;
  final FireMedia? media;

  Set<ID>? get nodesRef => forwardables?.whereType<Palette2>().asIds().toSet();

  FireMessage? generateMessage() {
    if (text == null && media == null && (nodesRef ?? {}).isEmpty) return null;
    return FireMessage(
      messagePushId(),
      sender: g.self.id,
      timestamp: timeStamp(),
      media: media?.id,
      text: text,
      replies: replies?.toSet(),
      nodes: forwardables?.whereType<Palette2>().asIds().toSet(),
    );
  }

  Payload({
    required List<ID>? r,
    required List<Down4Object>? f,
    required String? t,
    required FireMedia? m,
  })  : forwardables = f,
        replies = r,
        text = t,
        media = m;
}

class Boxes {
  late String docPath, tempPath;
  LazyBox payments, medias, messages, bills, nodes, utxos, spents, hidden;
  Box personal, messageQueue;
  Boxes._()
      : utxos = Hive.lazyBox("Utxos"),
        spents = Hive.lazyBox("Spents"),
        medias = Hive.lazyBox("Medias"),
        hidden = Hive.lazyBox("Hidden"),
        personal = Hive.box("Personal"),
        nodes = Hive.lazyBox("Nodes"),
        messages = Hive.lazyBox("Messages"),
        messageQueue = Hive.box("MessageQueue"),
        bills = Hive.lazyBox("Bills"),
        payments = Hive.lazyBox("Payments");
}

class Sizes {
  Sizes._()
      : h = 0,
        w = 0,
        fullHeight = 0,
        headerHeight = 0;
  double h;
  double w;
  double fullHeight;
  double headerHeight;
  Size get fullSize => Size(w, fullAspectRatio);
  Size get paddedSize => Size(w, h);
  double get viewPaddingHeight => fullHeight - h;
  double get fullAspectRatio => w / fullHeight;
  double get paddedAspectRatio => w / h;
}

class Singletons {
  static final Singletons _instance = Singletons();
  static Singletons get instance => _instance;

  Self? _self;
  Wallet? _wallet;
  Sizes? _sizes;
  Boxes? _boxes;
  ExchangeRate? _exchangeRate;

  ViewManager vm = ViewManager([
    V(id: 'home', pages: [P(), P()]) // left is homeState, right is hiddenState
  ]);

  List<Down4Object> fo = [];

  late Image fifty, black, red, ph, d1, d2, d3;
  late Uint8List background;

  late List<CameraDescription> cameras;
  Self get self => _self ??= SelfSave.load();
  Wallet get wallet => _wallet ??= WalletManager.load();
  Boxes get boxes => _boxes ??= Boxes._();
  Sizes get sizes => _sizes ??= Sizes._();
  ExchangeRate get exchangeRate => _exchangeRate ??= ExchangeRateSave.load();

  Map<ID, FireMedia> cachedConsoleMedias = {};

  bool get notYetInitialized => SelfSave.notYetInitialized();

  void initWallet(Uint8List s1, Uint8List s2) {
    final keys = Down4Keys.fromRandom(s1, s2);
    g.boxes.personal.put("ix", -1);
    g.boxes.personal.put("keys", jsonEncode(keys));
    _wallet = Wallet(keys: keys, ix: null);
  }

  void initSelf(
      ID id, FireMedia media, Down4Keys neuter, String name, String? lastName) {
    _self = Self(
      id: id,
      media: media,
      firstName: name,
      lastName: lastName,
      neuter: neuter,
      images: {},
      videos: {},
      nfts: {},
      publics: {},
      messages: {},
      snips: {},
    )..save();
  }
}
//
// Future<List<FireNode>> getNodesFromEverywhere(Set<ID> ids) async {
//   bool hasSelf;
//   if (hasSelf = ids.contains(g.self.id)) {
//     ids.remove(g.self.id);
//   }
//
//   final toFetch = ids.difference(g.boxes.nodes.keys.toSet());
//   final local = ids.difference(toFetch);
//
//   final onlineFetch = fetchPalettes(toFetch);
//   final localFetch = local.map((e) => e.getLocalNode()).toList();
//
//   final locals = await Future.wait(localFetch);
//   final onlines = await onlineFetch;
//   return locals
//       .whereType<FireNode>()
//       .followedBy(onlines ?? [])
//       .followedBy(hasSelf ? [g.self] : [])
//       .toList();
// }

void unselectedSelectedPalettes(Map<ID, Palette2> state) {
  for (final p in state.values) {
    if (p.selected) state[p.id] = p.select();
  }
}

Future<void> writeHomePalette<T extends Chatable>(
  Palette2<T> p,
  Map<ID, Down4Object> state,
  Future<List<ButtonsInfo2>> Function(Palette2<T>)? bGen,
  void Function()? onSel, {
  bool? sel,
}) async {
  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  bool? selectionIfReload;
  final Palette2? pInState = state[p.node.id] as Palette2?;
  selectionIfReload = pInState?.selected;
  bool isSelected = sel ?? selectionIfReload ?? false;

  final previewInfo = await p.node.messagingPreview();

  void Function()? onSelect = onSel == null
      ? null
      : () async {
          await writeHomePalette(p, state, bGen, onSel, sel: !isSelected);
          onSel.call();
        };

  state[p.node.id] = Palette2(
      node: p.node,
      image: p.image,
      selected: isSelected,
      messagePreview: previewInfo.second,
      imPress: onSelect,
      bodyPress: onSelect,
      buttonsInfo2: await bGen?.call(p) ?? []);

  print("SUCCESS FULLY WROTE ${p.node.id} TO STATE = $state");
}

void writePalette3(
  Palette2 p,
  Map<ID, Down4Object> state,
  List<ButtonsInfo2> Function(FireNode)? bGen,
  void Function()? onSel, {
  bool? sel,
  String? pr,
}) {
  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  bool? selectionIfReload;
  final Palette2? pInState = state[p.node.id] as Palette2?;
  selectionIfReload = pInState?.selected;
  bool isSelected = sel ?? selectionIfReload ?? false;

  void Function()? onSelect = onSel == null
      ? null
      : () {
          writePalette3(p, state, bGen, onSel, sel: !isSelected, pr: pr);
          onSel.call();
        };

  state[p.node.id] = Palette2(
      node: p.node,
      image: p.image,
      selected: isSelected,
      imPress: onSelect,
      bodyPress: onSelect,
      messagePreview: pr,
      buttonsInfo2: bGen?.call(p.node) ?? []);

  print("SUCCESS FULLY WROTE ${p.node.id} TO STATE = $state");
}

class Transition {
  final Iterable<Personable> trueTargets;
  final List<Palette2> preTransition, postTransition;
  final Map<ID, Palette2> state;
  final int nHidden;
  final double scroll;

  const Transition({
    required this.trueTargets,
    required this.preTransition,
    required this.postTransition,
    required this.state,
    required this.nHidden,
    required this.scroll,
  });
}

Transition selectionTransition({
  required List<Palette2> originalList,
  required Map<ID, Palette2> state,
  required Map<ID, Palette2> hiddenState,
  required double scrollOffset,
}) {
  final ogOrder = originalList.asIds();
  final hidden = List<Palette2>.from(hiddenState.values);
  final selected = originalList.selected();
  final unselected = originalList.notSelected();
  final idsInGroups = selected
      .asNodes()
      .whereType<Groupable>()
      .map((g) => g.group)
      .expand((id) => id)
      .toSet();
  final selectedUsers = selected.whereNodeIs<Personable>();
  final selectedGroups = selected.whereNodeIs<Groupable>();
  final unselectedGroups = unselected.whereNodeIs<Groupable>();
  final unselectedUsers = unselected.whereNodeIs<Personable>();
  final unHide = hidden.those(idsInGroups);
  final unselectedUsersNotInGroups = unselectedUsers.notThose(idsInGroups);
  final unselectedUserInGroups = unselectedUsers.those(idsInGroups);
  // groups are folded
  // unHide should get a left to right show transition
  // not selected should get a fold transition
  // selected are unselected
  // all are deactivated
  final pals = <Palette2>{
    ...unHide,
    ...selectedUsers.map(
        (e) => e.deactivated().animated(selected: false, fadeButton: true)),
    ...unselectedUserInGroups
        .deactivated()
        .map((e) => e.animated(fadeButton: true)),
    ...unselectedGroups
        .map((e) => e.animated(fadeButton: true, fade: true, fold: true)),
    ...selectedGroups
        .map((e) => e.animated(fold: true, fadeButton: true, fade: true)),
    ...unselectedUsersNotInGroups
        .map((e) => e.animated(fold: true, fadeButton: true, fade: true)),
  };

  print("pals=${pals.map((e) => e.node.displayName).toList()}");
  return Transition(
      trueTargets: pals.where((p) => !p.fold).asNodes<Personable>(),
      preTransition: originalList,
      postTransition: pals.inThatOrder(ogOrder.followedBy(unHide.asIds())),
      state: state,
      nHidden: unHide.length,
      scroll: scrollOffset);
}

Transition typeTransition<T>({
  required Map<ID, Palette2> state,
  required Map<ID, Palette2> hiddenState,
  required double scrollOffset,
}) {
  if (T is! FireNode) throw 'T needs to be a BaseNode type';
  final all = state.values;
  final ogOrder = all.asIds();
  final hidden = hiddenState.values;
  final properType = all.whereNodeIs<T>();
  final unProperType = all.whereNodeIsNot<T>();
  final properTypeHidden = hidden.whereNodeIs<T>();
  final pals = <Palette2>{
    ...properType,
    ...unProperType
        .map((e) => e.animated(fold: true, fadeButton: true, fade: true)),
    ...properTypeHidden,
  };

  print("pals=${pals.map((e) => e.node.displayName).toList()}");
  return Transition(
      trueTargets: pals.where((p) => !p.fold).asNodes<Personable>(),
      preTransition: all.toList(),
      postTransition:
          pals.inThatOrder(ogOrder.followedBy(properTypeHidden.asIds())),
      state: state,
      nHidden: properTypeHidden.length,
      scroll: scrollOffset);
}

Future<ChatMessage?> getChatMessage({
  required Map<ID, ChatMessage> state,
  required Palette2<Chatable> palette,
  required ID msgID,
  required ID? prevMsgID,
  required ID? nextMsgID,
  required bool isLast,
  required void Function(FireNode)? openNode,
  required void Function() refreshCallback,
}) async {
  final (msg, _) = await global<FireMessage>(msgID);
  if (msg == null) return null;
  FireMessage? prevMsg, nextMsg;
  ChatMessage? prevChatMessage = state[prevMsgID];
  // If new message while in chat, we might want to remove the header of the
  // previous last message
  if (isLast &&
      prevMsgID != null &&
      prevChatMessage != null &&
      prevChatMessage.hasHeader &&
      msg.sender == prevChatMessage.message.sender &&
      msg.sender != g.self.id) {
    // we need to remove its header
    state[prevMsgID] = prevChatMessage.withHeader(hasHeader: false);
    // and update it's size
  }

  if (state[msgID] != null) return state[msgID]!;

  (prevMsg, _) = await global<FireMessage>(prevMsgID);
  (nextMsg, _) = await global<FireMessage>(nextMsgID);

  bool hasGap = false;
  if (prevMsg != null) hasGap = ChatMessage.displayGap(msg, prevMsg);

  // mark as read
  msg.markRead();

  final bool senderIsSelf = msg.sender == g.self.id;
  final bool hasHeader =
      !senderIsSelf && palette is Groupable && nextMsg?.sender != msg.sender;

  final cm = ChatMessage(
      key: GlobalKey(),
      hasGap: hasGap,
      message: msg,
      nodeRef: palette.id,
      mediaInfo: await ChatMessage.generateMediaInfo(msg),
      nodes: null,
      repliesInfo: await ChatMessage.generateRepliesInfo(msg, (replyID) {
        print("TODO, GO TO REPLY ID = $replyID");
      }),
      hasHeader: hasHeader,
      openNode: openNode,
      myMessage: g.self.id == msg.sender,
      select: (_) {
        state[msgID] = state[msgID]!.invertedSelection();
        refreshCallback();
      });

  Future.microtask(() {
    if ((msg.nodes ?? {}).isNotEmpty) {
      getNodesFromEverywhere(msg.nodes!.toSet()).then((nodes) {
        if (nodes.isNotEmpty) {
          state[msg.id] = state[msg.id]!.withNodes(nodes);
          refreshCallback();
        }
      });
    }
  });

  return cm;
}

Future<void> writeMessages({
  required Palette2<Chatable> palette,
  required List<ID> ordered,
  required Map<ID, ChatMessage> state,
  required Map<ID, EmptyObject> videos,
  required Map<ID, EmptyObject> withNodes,
  required void Function() refresh,
  required void Function(FireNode)? openNode,
  int limit = 20,
}) async {
  final orderedSet = ordered.toSet();
  final loadedSet = state.keys.toSet();
  final toLoad = orderedSet.difference(loadedSet).toList();
  if (toLoad.isEmpty) return;
  final allN = ordered.length;
  final nLoad = toLoad.length > limit ? limit : toLoad.length;
  final ixOfFirst = orderedSet.toList().indexOf(toLoad.first);
  for (int i = 0; i < nLoad; i++) {
    final ixInFull = ixOfFirst + i;
    final msgID = toLoad[i];
    final nxt = ixInFull == 0 ? null : ordered[ixInFull - 1];
    final prv = ixInFull < allN - 1 ? ordered[ixInFull + 1] : null;
    final isFirst = msgID == orderedSet.first;
    final m = await getChatMessage(
        state: state,
        palette: palette,
        msgID: msgID,
        prevMsgID: prv,
        nextMsgID: nxt,
        isLast: isFirst,
        openNode: openNode,
        refreshCallback: refresh);
    if (m != null) {
      state[m.id] = m;
      if (m.mediaInfo?.media.isVideo ?? false) videos[m.id] = EmptyObject("");
      if ((m.nodes ?? []).isNotEmpty) withNodes[m.id] = EmptyObject("");
    }
  }
}

Future<void> writePayments(
  Map<ID, Palette2> state,
  void Function(Down4Payment) openPayment, [
  int limit = 5,
]) async {
  final loaded = state.keys;
  final all = g.boxes.payments.keys;

  List<Down4Payment> paymentsToLoad = [];
  for (final id in all) {
    if (paymentsToLoad.length >= 5) break;
    if (!loaded.contains(id)) {
      final jsonEncodedPay = await g.boxes.payments.get(id);
      if (jsonEncodedPay == null) continue;
      final payment = Down4Payment.fromJson(jsonDecode(jsonEncodedPay));
      paymentsToLoad.add(payment);
    }
  }

  for (final payment in paymentsToLoad) {
    state[payment.id] = Palette2(
      node: Payment(payment.id, payment: payment, selfID: g.self.id),
      image: null,
      messagePreview: payment.textNote,
      buttonsInfo2: payment.isSpentBy(id: g.self.id)
          ? [
              ButtonsInfo2(
                  asset: g.fifty,
                  pressFunc: () => openPayment(payment),
                  rightMost: true)
            ]
          : [],
    );
  }
}

class EmptyObject extends Down4Object {
  EmptyObject(super.id);
}

final topButtonsKey = [
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
];

final bottomButtonsKey = [
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
];
