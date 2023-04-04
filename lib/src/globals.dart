import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:flutter/services.dart';
import 'render_objects/palette.dart';
import 'package:flutter/cupertino.dart';
import 'couch.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'render_objects/_render_utils.dart';
import 'render_objects/chat_message.dart';

import 'data_objects.dart';
import 'bsv/types.dart';
import 'bsv/wallet.dart';
import 'web_requests.dart' show fetchPalettes;

final g = Singletons.instance;
final db = FirebaseDatabase.instance.ref();
final _fs = FirebaseFirestore.instance;
final _st = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _st_node = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

Future<List<Palette2>> slowNodeIDsToPalettes(Iterable<ID> nodeIDs) async {
  var fNodes = nodeIDs.map((nodeID) => global<FireNode>(nodeID, doFetch: true));
  final theNodes = (await Future.wait(fNodes)).whereType<FireNode>();
  final fPalettes = theNodes.map((node) async {
    final nMedia = await global<FireMedia>(node.mediaID, withDataIfFetch: true);
    return Palette2(node: node, image: nMedia);
  });
  return Future.wait(fPalettes);
}

Future<bool> uploadPayment(Down4Payment pay) async {
  try {
    await _st.ref(pay.id).putData(pay.compressed.toUint8List());
    return true;
  } catch (e) {
    print("Error uploading payment: $e");
    return false;
  }
}

Future<bool> uploadNode(FireNode node) async {
  final body = node.toJson(toLocal: false);
  try {
    await _fs.collection("Nodes").doc(node.id).set(body);
    return true;
  } catch (e) {
    print("Failure uploading node: $e");
    return false;
  }
}

Future<bool> uploadPalette(Palette2 p) async {
  final nodeUpload = uploadNode(p.node);
  final mediaUpload = p.image == null
      ? Future.value(true)
      : uploadMedia(p.image!, isNode: true);

  final nSuccess = await nodeUpload;
  final mSuccess = await mediaUpload;
  return nSuccess && mSuccess;
  // if (nSuccess && !mSuccess) {
  //   print("uploadPalette: Successfullly uploaded node but not the media");
  //   await _fs.collection("Nodes").doc(p.node.id).delete();
  // } else if (mSuccess && !nSuccess && p.image != null) {
  //   print("uploadPalette: Successfullly uploaded node but not the media");
  //   await _st_node.ref(p.image!.id).delete();
  // }
}

String messagePushId() => db.child("Messages").push().key!;

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

Future<bool> uploadMedia(FireMedia media,
    {bool isNode = false, bool isSnip = false}) async {
  // if the media doesn't need update and is a message media, we are good
  if (!media.onlineTimestamp.shouldBeUpdated && !isNode) return true;
  // if it's a message media and needs an update, we update it
  final copy = media.copy();

  if (!isNode) {
    // we refresh onlineID and onlineTimestamp
    final newID = messagePushId();
    final newTs = makeTimestamp();
    media.updateOnlineReference(newID, newTs);
  }
  final ref = isNode ? _st_node.ref(media.id) : _st.ref(media.onlineID!);
  try {
    final data = await (media.isVideo ? media.videoData : media.imageData);
    if (data == null && media.cachePath == null) {
      print("No media data nor path, cannot upload anything...");
      return false;
    }
    final jsonMetadata = media.toJson(toLocal: false);
    final metadata = SettableMetadata(customMetadata: jsonMetadata);
    await (data == null && media.cachePath != null
        ? ref.putFile(File(media.cachePath!), metadata)
        : ref.putData(data!, metadata));
    print("Successfully uploaded media id: ${media.id}");
    return true;
  } catch (e) {
    // if it's not a node nor a snip and failed during upload, we set it back
    if (!isNode && !isSnip) gCache(copy..merge());
    print("Error uploading media id: ${media.id}, err: $e");
    return false;
  }
}

Future<bool> uploadMessage(FireMessage msg) async {
  final msgRef = db.child("Messages").child(msg.id);
  try {
    await msgRef.set(msg.toJson(toLocal: false));
    print("Success uploading message id: ${msg.id}");
    return true;
  } catch (e) {
    print("Error uploading message id: ${msg.id}, error: $e");
    return false;
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
  final List<Down4Object> forwardables;
  final List<ID> replies;
  final String text;
  final FireMedia? media;
  final bool isSnip;

  Set<ID> get nodesRef => forwardables.whereType<Palette2>().asIds().toSet();

  FireMessage? generateMessage({required ID root}) {
    if (text.isEmpty && media == null && nodesRef.isEmpty) return null;
    return FireMessage(messagePushId(),
        root: root,
        senderID: g.self.id,
        timestamp: makeTimestamp(),
        isSnip: isSnip,
        mediaID: media?.id,
        isSent: root == g.self.id,
        text: text,
        replies: replies.isEmpty ? null : replies.toSet(),
        nodes: nodesRef.isEmpty ? null : nodesRef.toSet());
  }

  Payload({
    required List<ID>? replies,
    required List<Down4Object>? forwards,
    required String? text,
    required this.media,
    required this.isSnip,
  })  : forwardables = forwards ?? [],
        replies = replies ?? [],
        text = text ?? "";
}

class Sizes {
  Sizes({
    required this.h,
    required this.w,
    required this.fullHeight,
    required this.headerHeight,
  });
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

  late Palette2<Self> self;
  late Wallet wallet;
  late Sizes sizes;
  late ExchangeRate exchangeRate;
  late Image fifty, black, red, ph, d1, d2, d3;
  late Uint8List background;
  late List<CameraDescription> cameras;

  ViewManager vm = ViewManager([
    V(id: 'home', pages: [P(), P()]) // left is homeState, right is hiddenState
  ]);

  Future<bool> get notYetInitialized async {
    final self_ = await Self.loadSelf;
    if (self_ != null) {
      self = self_;
      return false;
    } else {
      return true;
    }
  }

  void loadExchangeRate(ExchangeRate er) => exchangeRate = er;

  void loadSizes(Sizes s) => sizes = s;

  Future<void> loadWallet() async {
    final wallet_ = await WalletManager.load();
    if (wallet_ == null) return print("Wallet is null");
    wallet = wallet_;
  }

  Future<void> initWallet(Uint8List s1, Uint8List s2) async {
    final keys = Down4Keys.fromRandom(s1, s2);
    wallet = Wallet(keys: keys, ix: null);
    await wallet.merge();
  }

  Future<void> initSelf(
    ID id,
    FireMedia media,
    Down4Keys neuter,
    String name,
    String? lastName,
  ) async {
    final selfNode = Self(id,
        activity: 0,
        name: name,
        description: "",
        lastName: lastName,
        mediaID: media.id,
        publics: {},
        neuter: neuter,
        privates: {});
    await selfNode.merge();
    await media.merge();
    self = Palette2(node: selfNode, image: media);
  }
}

void unselectedSelectedPalettes(Map<ID, Palette2> state) {
  for (final p in state.values) {
    if (p.selected) state[p.id] = p.select();
  }
}

Future<void> writeHomePalette<T extends Chatable>(
  Palette2<T> p,
  Map<ID, Palette2<Chatable>> state,
  Future<List<ButtonsInfo2>> Function(Palette2<T>)? bGen,
  void Function()? onSel, {
  bool? sel,
}) async {
  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  bool? selectionIfReload;
  final Palette2? pInState = state[p.node.id];
  selectionIfReload = pInState?.selected;
  bool isSelected = sel ?? selectionIfReload ?? false;

  final lastMsg = await p.node.lastMessage();
  final preview = lastMsg == null
      ? null
      : (lastMsg.text ?? "").isNotEmpty
          ? lastMsg.text!
          : "&attachment";

  void Function()? onSelect = onSel == null
      ? null
      : () async {
          await writeHomePalette(p, state, bGen, onSel, sel: !isSelected);
          onSel.call();
        };

  state[p.node.id] = Palette2<Chatable>(
      node: p.node,
      image: p.image,
      selected: isSelected,
      messagePreview: preview,
      imPress: onSelect,
      bodyPress: onSelect,
      buttonsInfo2: await bGen?.call(p) ?? []);

  print("SUCCESS FULLY WROTE ${p.node.id} TO STATE = $state");
}

void writePalette3(
  Palette2 p,
  Map<ID, Down4Object> state,
  List<ButtonsInfo2> Function(Palette2)? bGen,
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
      buttonsInfo2: bGen?.call(p) ?? []);

  print("SUCCESS FULLY WROTE ${p.node.id} TO STATE = $state");
}

class Transition {
  final Iterable<Palette2<Personable>> trueTargets;
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
  // originalList.forEach((e) =>
  //     print("${e.node.runtimeType}, isPersonable: ${e.node is Personable}"));

  final ogOrder = originalList.asIds();
  final hidden = List<Palette2>.from(hiddenState.values);
  final selected = originalList.selected();
  final unselected = originalList.notSelected();

  // selected.forEach((element) {
  //   print ("""
  //   element node is Personable = ${element.node is Personable}
  //   element node runtimeType = ${element.node.runtimeType}
  //
  //   element is Palette2<Personable> = ${element is Palette2<Personable>}
  //   element runtimeType = ${element.runtimeType}
  //   """);
  // });

  final selectedPeople = selected.whereNodeIs<Personable>()..forEach((e) =>
      print("${e.node.runtimeType}, isPersonable: ${e.node is Personable}"));

  // selectedPeople.forEach((e) =>
  //     print("${e.node.runtimeType}, isPersonable: ${e.node is Personable}"));

  final selectedGroups = selected.whereNodeIs<Groupable>();

  final idsInGroups =
      selectedGroups.map((g) => g.node.group).expand((id) => id).toSet();

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
  final pals = <Palette2<FireNode>>{
    ...unHide,
    ...selectedPeople.map(
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
      trueTargets: pals.where((p) => !p.fold).whereNodeIs<Personable>(),
      preTransition: originalList,
      postTransition: pals.inThatOrder(ogOrder.followedBy(unHide.asIds())),
      state: state,
      nHidden: unHide.length,
      scroll: scrollOffset);
}

// Transition typeTransition<T extends FireNode>({
//   required Map<ID, Palette2> state,
//   required Map<ID, Palette2> hiddenState,
//   required double scrollOffset,
// }) {
//   final all = state.values;
//   final ogOrder = all.asIds();
//   final hidden = hiddenState.values;
//   final properType = all.whereNodeIs<T>();
//   final unProperType = all.whereNodeIsNot<T>();
//   final properTypeHidden = hidden.whereNodeIs<T>();
//   final pals = <Palette2>{
//     ...properType,
//     ...unProperType
//         .map((e) => e.animated(fold: true, fadeButton: true, fade: true)),
//     ...properTypeHidden,
//   };
//
//   print("pals=${pals.map((e) => e.node.displayName).toList()}");
//   return Transition<T>(
//       trueTargets: properType.followedBy(properTypeHidden),
//       preTransition: all.toList(),
//       postTransition:
//           pals.inThatOrder(ogOrder.followedBy(properTypeHidden.asIds())),
//       state: state,
//       nHidden: properTypeHidden.length,
//       scroll: scrollOffset);
// }

Future<ChatMessage?> getChatMessage({
  required Map<ID, ChatMessage> state,
  required Palette2<Chatable> palette,
  required ID msgID,
  required ID? prevMsgID,
  required ID? nextMsgID,
  required bool isLast,
  required void Function(Palette2<Branchable>)? openNode,
  required void Function() refreshCallback,
}) async {
  final msg = await global<FireMessage>(msgID);
  if (msg == null) return null;
  FireMessage? prevMsg, nextMsg;
  ChatMessage? prevChatMessage = state[prevMsgID];
  // If new message while in chat, we might want to remove the header of the
  // previous last message
  if (isLast &&
      prevMsgID != null &&
      prevChatMessage != null &&
      prevChatMessage.hasHeader &&
      msg.senderID == prevChatMessage.message.senderID &&
      msg.senderID != g.self.id) {
    // we need to remove its header
    state[prevMsgID] = prevChatMessage.withHeader(hasHeader: false);
    // and update it's size
  }

  if (state[msgID] != null) return state[msgID]!;

  prevMsg = await global<FireMessage>(prevMsgID);
  nextMsg = await global<FireMessage>(nextMsgID);

  bool hasGap = false;
  if (prevMsg != null) hasGap = ChatMessage.displayGap(msg, prevMsg);

  // mark as read
  msg.markRead();

  final bool senderIsSelf = msg.senderID == g.self.id;
  final bool hasHeader = !senderIsSelf &&
      palette is Groupable &&
      nextMsg?.senderID != msg.senderID;

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
      openPalette: openNode,
      myMessage: g.self.id == msg.senderID,
      select: (_) {
        state[msgID] = state[msgID]!.invertedSelection();
        refreshCallback();
      });

  // Future for fetching the nodes attached to a message
  // It when done, it will callback and refresh the message with
  // the palettes showing properly
  Future.microtask(() async {
    if ((msg.nodes ?? {}).isNotEmpty) {
      final ps = await slowNodeIDsToPalettes(msg.nodes!);
      if (ps.isNotEmpty) {
        state[msg.id] = state[msg.id]!.withPalettes(ps);
        refreshCallback();
      }
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
  required void Function(Palette2<Branchable>)? openNode,
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
      if (m.mediaInfo?.media.isVideo ?? false) videos[m.id] = EmptyObject();
      if ((m.nodes ?? []).isNotEmpty) withNodes[m.id] = EmptyObject();
    }
  }
}

Future<void> writePayments(
  Map<ID, Palette2> state,
  void Function(Down4Payment) openPayment, [
  int limit = 5,
]) async {
  await for (final p in g.wallet.payments) {
    state[p.id] = Palette2(
      node: Payment(p.id, payment: p, selfID: g.self.id),
      image: null,
      messagePreview: p.textNote,
      buttonsInfo2: p.isSpentBy(id: g.self.id)
          ? [
              ButtonsInfo2(
                  asset: g.fifty,
                  pressFunc: () => openPayment(p),
                  rightMost: true)
            ]
          : [],
    );
  }

  // final loaded = state.keys;
  // final all = g.boxes.payments.keys;
  //
  // List<Down4Payment> paymentsToLoad = [];
  // for (final id in all) {
  //   if (paymentsToLoad.length >= 5) break;
  //   if (!loaded.contains(id)) {
  //     final jsonEncodedPay = await g.boxes.payments.get(id);
  //     if (jsonEncodedPay == null) continue;
  //     final payment = Down4Payment.fromJson(jsonDecode(jsonEncodedPay));
  //     paymentsToLoad.add(payment);
  //   }
  // }
  //
  // for (final payment in paymentsToLoad) {
  //   state[payment.id] = Palette2(
  //     node: Payment(payment.id, payment: payment, selfID: g.self.id),
  //     image: null,
  //     messagePreview: payment.textNote,
  //     buttonsInfo2: payment.isSpentBy(id: g.self.id)
  //         ? [
  //             ButtonsInfo2(
  //                 asset: g.fifty,
  //                 pressFunc: () => openPayment(payment),
  //                 rightMost: true)
  //           ]
  //         : [],
  //   );
  // }
}

class EmptyObject extends Down4Object {
  @override
  ID get id => randomBytes(size: 8).toBase58();
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
