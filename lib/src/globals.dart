import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:down4/src/_down4_dart_utils.dart';
import 'package:flutter/services.dart';
import 'render_objects/palette.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'render_objects/_down4_flutter_utils.dart';
import 'data_objects.dart';
import 'bsv/types.dart';
import 'bsv/wallet.dart';
import 'web_requests.dart' show getNodes;

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

Future<bool> uploadNode(BaseNode node) async {
  Future<bool> uploadImage() async {
    final media = node.media;
    if (media == null) return true;
    try {
      await _st_node.ref(media.id).putData(media.data,
          SettableMetadata(customMetadata: media.metadata.toJson()));
      return true;
    } catch (e) {
      print("Error uploading node image: $e");
      return false;
    }
  }

  Future<bool> uploadNode() async {
    final body = node.toJson(toLocal: false);
    try {
      await _fs.collection("Nodes").doc(node.id).set(body);
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

String _mediaPath(String mediaID, {bool isThumbnail = false}) =>
    "${g.boxes.docPath}/$mediaID${isThumbnail ? "-TN" : ""}";

Future<void> _deleteMediaFile(String path) async {
  try {
    await File(path).delete();
  } on PathNotFoundException catch (e) {
    print("Cannot delete, this file is external: $e");
  } catch (e) {
    print("Cannot delete this file for this reason: $e");
  }
}

String messagePushId() => db.child("Messages").push().key!;

Future<NodeMedia?> downloadMessageMediaAsNodeMedia(ID mediaID) async {
  final ref = _st.ref(mediaID);
  try {
    final md = await ref.getMetadata();
    final data = await ref.getData();
    if (data == null) return null;
    final d4md = MediaMetadata.fromJson(md.customMetadata!);
    return NodeMedia(data: data, id: mediaID, metadata: d4md);
  } catch (e) {
    print("Error downloading media: $e");
    return null;
  }
}

Future<Message?> downloadMessage(ID msgID) async {
  final s = await db.child("Messages").child(msgID).get();
  if (!s.exists) return null;
  print("MESSAGE VALUE = ${s.value}");
  final json = Map<String, dynamic>.from(s.value as Map);
  return Message.fromJson(json);
}

Future<MessageMedia?> downloadAndWriteMedia(
  String mediaID, {
  bool isNodeMedia = false,
}) async {
  final mediaRef = isNodeMedia ? _st_node.ref(mediaID) : _st.ref(mediaID);
  try {
    final futureMediaData = mediaRef.getData(31457280); // 30mib
    final fullMetadata = await mediaRef.getMetadata();
    final customMetadata = fullMetadata.customMetadata as Map<String, String>;
    final mediaMetadata = MediaMetadata.fromJson(customMetadata);
    final path = "${g.boxes.docPath}/$mediaID";
    final mediaData = await futureMediaData;
    if (mediaData != null) {
      await File(path).writeAsBytes(mediaData);
    }
    return MessageMedia(id: mediaID, path: path, metadata: mediaMetadata);
  } catch (e) {
    print("Error downloading mediaID: $mediaID, isNode: $isNodeMedia\n$e");
    return null;
  }
}

Future<bool> uploadHyperchatMedia(NodeMedia media) async {
  var mediaRef = _st.ref(media.id);
  try {
    await mediaRef.putData(
        media.data, SettableMetadata(customMetadata: media.metadata.toJson()));
    return true;
  } catch (e) {
    print("Error uploading temporary node media: $e");
    return false;
  }
}

Future<bool> uploadOrUpdateMedia(
  MessageMedia media, {
  bool skipCheck = false, // usually for camera uploads
}) async {
  if (media.file == null) return false;
  final mediaRef = _st.ref(media.id);
  if (skipCheck) {
    try {
      await mediaRef.putFile(
        media.file!,
        SettableMetadata(customMetadata: media.metadata.toJson()),
      );
      return true;
    } on FirebaseException catch (e) {
      print("Error uploading file $e");
      return false;
    }
  } else {
    try {
      print("Checking if media ${media.id} is already on firebase!");
      final metadata = (await mediaRef.getMetadata());
      final down4Metadata = MediaMetadata.fromJson(metadata.customMetadata!);
      if (down4Metadata.timestamp.shouldBeUpdated) {
        final newTimeStamp = timeStamp();
        if (newTimeStamp > down4Metadata.timestamp) {
          down4Metadata.timestamp = newTimeStamp;
          await mediaRef.updateMetadata(
            SettableMetadata(customMetadata: down4Metadata.toJson()),
          );
          print("Updated the metadata");
          return true;
        }
      }
      print("No need to update the metadata right away!");
      return true;
    } catch (e) {
      // TODO, find the actual exception we are looking for, docs aren't clear
      // If there's an exception, it should mean that there is no media, so we
      // do the full upload
      try {
        media.metadata.timestamp = timeStamp();
        await mediaRef.putFile(media.file!,
            SettableMetadata(customMetadata: media.metadata.toJson()));
        return true;
      } on FirebaseException catch (e) {
        print("Error uploading file $e");
        return false;
      }
    }
  }
}

Future<bool> uploadMessage(Message msg, {required bool skipCheck}) async {
  if (msg.timestamp.shouldBeUpdated || skipCheck) {
    try {
      final msgRef = db.child("Messages").child(msg.id);
      final getTs = await msgRef.child("ts").get();
      if (!getTs.exists) {
        msgRef.set(msg.toJson());
      } else {
        msgRef.child("ts").set(msg.timestamp);
      }
      return true;
    } catch (e) {
      print("Error uploading messageID: ${msg.id}, error: $e");
      return false;
    }
  } else {
    return true;
  }
}

Future<File> writeMedia({
  required Uint8List mediaData,
  required String mediaID,
  bool isThumbnail = false,
}) async =>
    File(_mediaPath(mediaID, isThumbnail: isThumbnail)).writeAsBytes(mediaData);

Future<File> copyMedia({
  required String fromPath,
  required String mediaID,
  bool isThumbnail = false,
}) async =>
    File(fromPath).copy(_mediaPath(mediaID, isThumbnail: isThumbnail));

Future<File?> makeThumbnail({
  required String videoPath,
  required String mediaID,
}) async {
  final tn = await VideoThumbnail.thumbnailData(video: videoPath, quality: 90);
  if (tn != null) {
    return writeMedia(mediaData: tn, mediaID: mediaID, isThumbnail: true);
  }
  return null;
}

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

extension Getters on ID {
  Future<MessageMedia?> getLocalMessageMedia() async {
    final String? jsonEncoded = await g.boxes.medias.get(this);
    if (jsonEncoded == null) return null;
    return MessageMedia.fromJson(jsonDecode(jsonEncoded));
  }

  Future<Message?> getLocalMessage() async {
    final String? jsonEncoded = await g.boxes.messages.get(this);
    if (jsonEncoded == null) return null;
    return Message.fromJson(jsonDecode(jsonEncoded));
  }

  Future<BaseNode?> getLocalNode() async {
    final String? jsonEncoded = await g.boxes.nodes.get(this);
    if (jsonEncoded == null) return null;
    return BaseNode.fromJson(jsonDecode(jsonEncoded));
  }

  Future<BaseNode?> getHiddenNode() async {
    final String? jsonEncoded = await g.boxes.hidden.get(this);
    if (jsonEncoded == null) return null;
    return BaseNode.fromJson(jsonDecode(jsonEncoded));
  }

  Future<void> deleteLocalNode() async {
    return await g.boxes.nodes.delete(this);
  }
}

extension MessageSave on Message {
  Future<void> onReceipt() async {
    await save();
    if (mediaID != null) {
      MessageMedia? media = await mediaID?.getLocalMessageMedia();
      media ??= await downloadAndWriteMedia(mediaID!);
      if (media != null && media.extension.isVideoExtension()) {
        // we generate a thumbnail
        final tn =
            await VideoThumbnail.thumbnailData(video: media.path, quality: 90);
        if (tn != null) {
          final f = await writeMedia(
              mediaData: tn, mediaID: mediaID!, isThumbnail: true);
          media.thumbnail = f.path;
        }
      }

      media
        ?..references.add(id)
        ..save();
    }
    return;
  }

  Future<void> save() async {
    return g.boxes.messages.put(id, jsonEncode(toJson(toLocal: true)));
  }

  Future<void> deleteFrom(ChatableNode node) async {
    sents.remove(node.id);
    node.messages.remove(id);
    if (sents.isEmpty) return delete();
    return;
  }

  Future<void> delete() async {
    final MessageMedia? media = await mediaID?.getLocalMessageMedia();
    if (media != null) {
      media.references.remove(id);
      media.delete();
    }
    await g.boxes.messages.delete(id);
    return;
  }
}

extension NodeSave on BaseNode {
  Future<void> save({bool hidden = false}) async {
    if (hidden) {
      await g.boxes.hidden.put(id, jsonEncode(toJson(toLocal: true)));
    } else {
      if (this is Self) {
        await g.boxes.personal.put("self", jsonEncode(toJson(toLocal: true)));
      } else {
        await g.boxes.nodes.put(id, jsonEncode(toJson(toLocal: true)));
      }
    }
  }

  Future<void> delete({bool hidden = false}) async {
    var node = this;
    if (node is ChatableNode && node is! Self) {
      for (var messageID in node.messages) {
        var msg = await messageID.getLocalMessage();
        if (msg != null && !msg.isSaved) msg.delete();
      }
      g.boxes.nodes.delete(id);
    }
  }
}

extension ChatableNodeExtensions on ChatableNode {
  Future<Pair<String, bool>> previewInfo() async {
    String? lastMessagePreview;
    bool? lastMessageWasRead;
    if (messages.isNotEmpty) {
      final lastMessage = await messages.last.getLocalMessage();
      lastMessageWasRead = lastMessage?.isRead ?? true;
      if ((lastMessage?.text ?? "").isEmpty) {
        lastMessagePreview = "&attachment";
      } else {
        lastMessagePreview = lastMessage!.text!;
      }
    }
    return Pair(lastMessagePreview ?? "", lastMessageWasRead ?? true);
  }
}

extension MediaSave on MessageMedia {
  Future<void> save() async {
    return g.boxes.medias.put(id, jsonEncode(toJson(toLocal: true)));
  }

  Future<void> delete() async {
    if (references.isEmpty && !isSaved) {
      print("References are empty, deleting the file!");
      g.boxes.medias.delete(id);
      _deleteMediaFile(path);
      if (thumbnail != null) {
        _deleteMediaFile(thumbnail!);
      }
    }
    return;
  }
}

extension PaymentSave on Down4Payment {
  Future<void> save() => g.boxes.payments.put(id, jsonEncode(this));
}

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
    return BaseNode.fromJson(asJson) as Self;
  }

  static bool notYetInitialized() {
    return g.boxes.personal.get("self") == null;
  }
}

class Payload {
  final List<Down4Object> forwardables;
  final List<ID> replies;
  final String text;
  final MessageMedia? media;
  final Message? message;
  Payload({
    required List<ID>? r,
    required List<Down4Object>? f,
    required String? t,
    required MessageMedia? m,
  })  : forwardables = f ?? const <Down4Object>[],
        replies = r ?? const <ID>[],
        media = m,
        text = t ?? "",
        message = (t ?? "").isNotEmpty ||
                m != null ||
                (f ?? const []).whereType<Palette2>().isNotEmpty
            ? Message(
                senderID: g.self.id,
                timestamp: timeStamp(),
                id: messagePushId(),
                mediaID: m?.id,
                text: t,
                replies: r,
                nodes: (f ?? []).whereType<Palette2>().asIds().toList())
            : null;
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

  late Image fifty, black, red;

  late List<CameraDescription> cameras;
  Self get self => _self ??= SelfSave.load();
  Wallet get wallet => _wallet ??= WalletManager.load();
  Boxes get boxes => _boxes ??= Boxes._();
  Sizes get sizes => _sizes ??= Sizes._();
  ExchangeRate get exchangeRate => _exchangeRate ??= ExchangeRateSave.load();

  Map<ID, MessageMedia> cachedConsoleMedias = {};

  bool get notYetInitialized => SelfSave.notYetInitialized();

  void initWallet(Uint8List s1, Uint8List s2) {
    final keys = Down4Keys.fromRandom(s1, s2);
    g.boxes.personal.put("ix", -1);
    g.boxes.personal.put("keys", jsonEncode(keys));
    _wallet = Wallet(keys: keys, ix: null);
  }

  void initSelf(
      ID id, NodeMedia media, Down4Keys neuter, String name, String? lastName) {
    _self = Self(
      id: id,
      media: media,
      firstName: name,
      lastName: lastName,
      neuter: neuter,
      images: {},
      videos: {},
      nfts: {},
      children: {},
      messages: {},
      snips: {},
    )..save();
  }
}

Future<List<BaseNode>> getNodesFromEverywhere(Set<ID> ids) async {
  bool hasSelf;
  if (hasSelf = ids.contains(g.self.id)) {
    ids.remove(g.self.id);
  }

  final toFetch = ids.difference(g.boxes.nodes.keys.toSet());
  final local = ids.difference(toFetch);

  final onlineFetch = getNodes(toFetch);
  final localFetch = local.map((e) => e.getLocalNode()).toList();

  final locals = await Future.wait(localFetch);
  final onlines = await onlineFetch;
  return locals
      .whereType<BaseNode>()
      .followedBy(onlines ?? [])
      .followedBy(hasSelf ? [g.self] : [])
      .toList();
}

void unselectedSelectedPalettes(Map<ID, Palette2> state) {
  for (final p in state.values) {
    if (p.selected) state[p.id] = p.select();
  }
}

Future<void> writePalette2<T>(
  T node,
  Map<ID, Down4Object> state,
  Future<List<ButtonsInfo2>> Function(T)? bGen,
  void Function()? onSel, {
  bool h = false,
  bool? sel,
}) async {
  // return right away if not a BaseNode
  if (node is! BaseNode) {
    return print("SORRY BRO, BUT ISN'T BASE NODE LOL");
  }

  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  bool? selectionIfReload;
  final Palette2? pInState = state[node.id] as Palette2?;
  selectionIfReload = pInState?.selected;
  bool isSelected = sel ?? selectionIfReload ?? false;

  // if node is chatable, we want to load previews
  Pair<String, bool>? previewInfo;
  if (h && node is ChatableNode) {
    previewInfo = await node.previewInfo();
  }

  void Function()? onSelect = onSel == null
      ? null
      : () async {
          await writePalette2(node, state, bGen, onSel, h: h, sel: !isSelected);
          onSel.call();
        };

  state[node.id] = Palette2(
      node: node,
      selected: isSelected,
      messagePreview: previewInfo?.first,
      imPress: onSelect,
      bodyPress: onSelect,
      buttonsInfo2: await bGen?.call(node) ?? []);

  print("SUCCESS FULLY WROTE ${node.id} TO STATE = $state");
}

class Transition {
  final Iterable<Person> trueTargets;
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
      .whereType<GroupNode>()
      .map((g) => g.group)
      .expand((id) => id)
      .toSet();
  final selectedUsers = selected.whereNodeIs<Person>();
  final selectedGroups = selected.whereNodeIs<GroupNode>();
  final unselectedGroups = unselected.whereNodeIs<GroupNode>();
  final unselectedUsers = unselected.whereNodeIs<Person>();
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

  print("pals=${pals.map((e) => e.node.name).toList()}");
  return Transition(
      trueTargets: pals.where((p) => !p.fold).asNodes<Person>(),
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
  if (T is! BaseNode) throw 'T needs to be a BaseNode type';
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

  print("pals=${pals.map((e) => e.node.name).toList()}");
  return Transition(
      trueTargets: pals.where((p) => !p.fold).asNodes<Person>(),
      preTransition: all.toList(),
      postTransition:
          pals.inThatOrder(ogOrder.followedBy(properTypeHidden.asIds())),
      state: state,
      nHidden: properTypeHidden.length,
      scroll: scrollOffset);
}
