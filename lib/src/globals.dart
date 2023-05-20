import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cbl/cbl.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/pages/_page_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'render_objects/palette.dart';
import 'package:flutter/cupertino.dart';
import 'couch.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'render_objects/_render_utils.dart';
import 'render_objects/chat_message.dart';

import 'themes.dart';
import 'data_objects.dart';
import 'bsv/types.dart';
import 'bsv/wallet.dart';
import 'web_requests.dart' show fetchNodes;

final g = Singletons.instance;
final db = FirebaseDatabase.instance.ref();
final _fs = FirebaseFirestore.instance;
final _st = FirebaseStorage.instanceFor(bucket: "down4-26ee1-messages");
final _st_node = FirebaseStorage.instanceFor(bucket: "down4-26ee1-nodes");

Future<List<FireNode>> nodesFetchWithCachedMedias(Iterable<ID> nodeIDs) async {
  final nodes = await globall<FireNode>(nodeIDs);
  await globall<FireMedia>(nodes.map((e) => e.mediaID).whereType());
  return nodes;
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

Future<bool> uploadMedia(
  FireMedia media, {
  bool isNode = false,
  bool isSnip = false,
}) async {
  final bool mediaShouldBeUpdated = !media.onlineTimestamp.shouldBeUpdated;
  print("""
          MEDIA SHOULD BE UPDATED = $mediaShouldBeUpdated
          MEDIA IS NODE = $isNode
          NO NEED TO UPDATE MEDIA = ${!mediaShouldBeUpdated && !isNode}
        """);
  // if the media doesn't need update and is a message media, we are good
  if (!media.onlineTimestamp.shouldBeUpdated && !isNode) return true;
  print("UPLOADING mediaID: ${media.id}");
  // if it's a message media and needs an update, we update it
  ID? newID;
  int? newTs;
  if (!isNode) {
    // we refresh onlineID and onlineTimestamp
    newID = messagePushId();
    newTs = makeTimestamp();
  }
  final ref = isNode ? _st_node.ref(media.id) : _st.ref(newID);
  File? cachedFile, videoFile;
  Uint8List? imageData;
  try {
    final jsonMetadata = media.toJson(toLocal: false);
    final metadata = SettableMetadata(customMetadata: jsonMetadata);
    if ((cachedFile = await media.cachedFile) != null) {
      await ref.putFile(cachedFile!, metadata);
    } else {
      if (media.isVideo) {
        videoFile = media.videoFile;
        if (videoFile == null) {
          print("ERROR UPLOADING MEDIA: Can't find video file!");
          return false;
        }
        await ref.putFile(videoFile, metadata);
      } else {
        imageData = await media.imageData;
        if (imageData == null) {
          print("ERROR UPLOADING MEDIA: Can't find image data!");
          return false;
        }
        await ref.putData(imageData, metadata);
      }
    }
    print("SUCCESS UPLOADING MEDIA");
    if (newID != null) await media.updateOnlineReference(newID, newTs!);
    return true;
  } catch (e) {
    print("ERROR UPLOADING MEDIA: $e");
    return false;
  }
}

Future<bool> uploadMessage(FireMessage msg) async {
  final msgRef = db.child("Messages").child(msg.id);
  try {
    List<Future<dynamic>> uploads = [];

    final mediaCopy = (await global<FireMedia>(msg.mediaID))?.copy();
    final msgCopy = msg.copy();
    if (mediaCopy?.onlineTimestamp.shouldBeUpdated ?? false) {
      // upload info, onlineTimestamp and ID
      final ID newID = messagePushId();
      final int newTS = makeTimestamp();
      // update the message with the onlineMediaID
      await msg.setOnlineMediaID(newID);
      // update the media
      await mediaCopy!.updateOnlineReference(newID, newTS);

      final ref = _st.ref(mediaCopy.onlineID!);
      final metadata = mediaCopy.toJson(toLocal: false);
      final setMetadata = SettableMetadata(customMetadata: metadata);

      if (mediaCopy.cachePath != null) {
        uploads.add(ref.putFile(File(mediaCopy.cachePath!), setMetadata));
      } else if (mediaCopy.isVideo && mediaCopy.videoFile != null) {
        uploads.add(ref.putFile(mediaCopy.videoFile!, setMetadata));
      } else if ((await mediaCopy.imageData) != null) {
        uploads.add(ref.putData((await mediaCopy.imageData)!, setMetadata));
      } else {
        print("NO MEDIA TO UPLOAD BRO");
      }
    }
    // add the messageUpload
    uploads.add(msgRef.set(msgCopy.toJson(toLocal: false)));
    // await the uploads, a failure will throw
    await Future.wait(uploads);

    // we merge if the message is NOT a snip OR root is self
    final doSave = !msg.isSnip || msg.root == g.self.id;
    if (doSave) {
      await Future.wait(
        [msgCopy.merge(), mediaCopy?.merge() ?? Future.value(1)],
      );
    }
    msgCopy.cache();
    mediaCopy?.cache();

    print("Success uploading message id: ${msg.id}");
    return true;
  } catch (e) {
    print("Error uploading message id: ${msg.id}, error: $e");
    return false;
  }
}

class ViewManager {
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
  List<ID> route;
  Map<ID, ViewState?> views;

  ViewManager()
      : route = [],
        views = {};

  ViewState at(ID viewID) => views[viewID]!;

  ViewState get home => views[route.first]!;
  ViewState get currentView => views[route.last]!;

  void push(ViewState view) {
    route.add(view.id);
    views[view.id] ??= view;
  }

  ViewState? pop() {
    final popped = route.removeLast();
    if (!route.contains(popped)) {
      return views.remove(popped);
    }
    return null;
  }

  void popUntilHome() {
    for (final viewID in route.sublist(1)) {
      views.remove(viewID);
    }
    route = [route[0]];
  }

  // can be useful after forwarding, creating a group, hyperchat, etc
  void popInBetween() {
    final newRoute = [route.first, route.last];
    for (final viewID in route.sublist(1, route.length - 1)) {
      if (viewID != newRoute.last) views.remove(viewID);
    }
    route = newRoute;
  }
}

class PageState {
  // a page has a scroll state
  double scroll;
  // a page has a state of objects
  Map<ID, Down4Object> objects;
  PageState({double? scroll, Map<ID, Down4Object>? objects})
      : scroll = scroll ?? 0.0,
        objects = objects ?? {};
}

class ViewState {
  // A view can have a single chat
  Pair<List<ID>, StreamSubscription<QueryChange<ResultSet>>>? chat;
  // A view can be from a single node (chatPage, nodePage) both require a node
  final FireNode? node;
  // Every view has an ID
  final ID id;
  // A view has a least 1 page, limited to 3
  final List<PageState> pages;
  // A view has a current index of the page
  int currentIndex;
  // A view can have maps of special references, ex: messagesWithVideos
  Map<String, Set<ID>> notableReferences;

  Set<ID> refs(String name) => notableReferences[name] ??= Set<ID>.identity();

  ViewState({
    required this.id,
    required this.pages,
    int? ix,
    this.node,
    this.chat,
  })  : currentIndex = ix ?? 0,
        notableReferences = {};

  PageState get currentPage => pages[currentIndex];
}

class Payload {
  final List<Down4Object> forwardables;
  final List<ID> replies;
  final String text;
  final FireMedia? media;
  final bool isSnip;

  Set<ID> get nodesRef => forwardables.whereType<Palette2>().asIds().toSet();

  FireMessage? makeMsg({required ID root}) {
    if (text.isEmpty && media == null && nodesRef.isEmpty) return null;
    return FireMessage(messagePushId(),
        root: root,
        senderID: g.self.id,
        timestamp: makeTimestamp(),
        isSnip: isSnip,
        mediaID: media?.id,
        onlineMediaID: media?.onlineID,
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
  })  : forwardables = forwards?.reversed.toList(growable: false) ?? [],
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
  Size get fullSize => Size(w, fullHeight);
  Size get paddedSize => Size(w, h);
  double get viewPaddingHeight => fullHeight - h;
  double get fullAspectRatio => w / fullHeight;
  double get paddedAspectRatio => w / h;
}

class Singletons {
  static final Singletons _instance = Singletons();
  static Singletons get instance => _instance;

  Down4Theme theme = BlackTheme(); //PinkTheme();
  late String appDirPath;
  late Self self;
  late Wallet wallet;
  late Sizes sizes;
  late ExchangeRate exchangeRate;
  List<ID> savedImageIDs = [];
  List<ID> savedVideoIDs = [];
  late Image fifty, black, red, ph, d1, d2, d3, lg;
  late Uint8List background;
  late List<CameraDescription> cameras;

  Future<bool> get notYetInitialized async {
    final self_ = await Self.loadSelf();
    if (self_ != null) {
      self = self_;
      return false;
    } else {
      return true;
    }
  }

  // List<TextInputConnection> connections = [];
  // TextInputConnection get multiLine => connections[0];
  // TextInputConnection get singleLine => connections[1];
  // TextInputConnection get numberPad => connections[2];

  void loadExchangeRate(ExchangeRate er) => exchangeRate = er;

  void loadSizes(Sizes s) => sizes = s;

  Future<void> loadAppDirPath() async {
    appDirPath = (await getApplicationDocumentsDirectory()).path;
  }

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
        privates: {})
      ..cache()
      ..merge();
    media
      ..cache
      ..merge();
    self = selfNode;
  }
}

void unselectedSelectedPalettes(Map<ID, Palette2> state) {
  for (final p in state.values) {
    if (p.selected) state[p.id] = p.select();
  }
}

Future<void> writeHomePalette(
  Chatable c,
  Map<ID, Palette2> state,
  Future<List<ButtonsInfo2>> Function(Chatable n,
          {(FireMessage?, Iterable<ID>, bool)? chatInfo})?
      bGen,
  void Function()? onSel, {
  bool? sel,
}) async {
  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  final Palette2? pInState = state[c.id];
  final bool? selectionIfReload = pInState?.selected;
  final bool isSelected = sel ?? selectionIfReload ?? false;

  final chatInfo = await c.homeChatInfo();
  final (lastMsg, _, _) = chatInfo;

  final node = c;
  final hide = node is User && !node.isFriend && !await node.hasMessages();

  void Function()? onSelect = onSel == null || hide
      ? null
      : () async {
          await writeHomePalette(c, state, bGen, onSel, sel: !isSelected);
          onSel.call();
        };

  state[c.id] = Palette2(
      key: Key(c.id),
      node: c,
      selected: isSelected,
      messagePreview: lastMsg?.messagePreview,
      imPress: onSelect,
      show: !hide,
      bodyPress: onSelect,
      buttonsInfo2: hide ? [] : await bGen?.call(c, chatInfo: chatInfo) ?? []);
}

void writePalette3<T extends FireNode>(
  T n,
  Map<ID, Palette2> state,
  List<ButtonsInfo2> Function(T)? bGen,
  void Function()? onSel, {
  bool? sel,
  String? pr,
}) {
  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  bool? selectionIfReload;
  final Palette2? pInState = state[n.id];
  selectionIfReload = pInState?.selected;
  bool isSelected = sel ?? selectionIfReload ?? false;

  void Function()? onSelect = onSel == null
      ? null
      : () {
          writePalette3(n, state, bGen, onSel, sel: !isSelected, pr: pr);
          onSel.call();
        };

  state[n.id] = Palette2(
      key: Key(n.id),
      node: n,
      selected: isSelected,
      imPress: onSelect,
      bodyPress: onSelect,
      messagePreview: pr,
      buttonsInfo2: bGen?.call(n) ?? []);
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
  required double scrollOffset,
}) {
  final hidden = state.values.hidden();

  final ogOrder = originalList.asIds();
  final selected = originalList.selected();
  final unselected = originalList.notSelected();

  final selectedPeople = selected.whereNodeIs<Personable>();

  final selectedGroups = selected.whereNodeIs<Groupable>();

  final idsInGroups = selectedGroups
      .asNodes<Groupable>()
      .map((g) => g.group)
      .expand((id) => id)
      .toSet();

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

  print("unhidding ${unHide.map((e) => e.node.displayName)}");

  final pals = <Palette2>{
    ...unHide.map((e) => e.showing(true)),
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
      trueTargets: pals.where((p) => !p.fold && p.show).asNodes<Personable>(),
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
  required Chatable ch,
  required ID msgID,
  required ID? prevMsgID,
  required ID? nextMsgID,
  required bool isLast,
  required void Function(FireNode)? openNode,
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
  final bool hasHeader =
      !senderIsSelf && ch is Groupable && nextMsg?.senderID != msg.senderID;

  final cm = ChatMessage(
      key: GlobalKey(),
      hasGap: hasGap,
      message: msg,
      nodeRef: ch.id,
      mediaInfo: await ChatMessage.generateMediaInfo(msg),
      nodes: null,
      repliesInfo: await ChatMessage.generateRepliesInfo(msg, (replyID) {
        print("TODO, GO TO REPLY ID = $replyID");
      }),
      hasHeader: hasHeader,
      openNode: openNode,
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
      final nodes = await nodesFetchWithCachedMedias(msg.nodes!);
      if (nodes.isNotEmpty) {
        state[msg.id] = state[msg.id]!.withNodes(nodes);
        refreshCallback();
      }
    }
  });

  return cm;
}

Future<void> writeMessages({
  required Chatable ch,
  required List<ID> ordered,
  required Map<ID, ChatMessage> state,
  required Set<ID> videos,
  required Set<ID> withNodes,
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
        ch: ch,
        msgID: msgID,
        prevMsgID: prv,
        nextMsgID: nxt,
        isLast: isFirst,
        openNode: openNode,
        refreshCallback: refresh);
    if (m != null) {
      state[m.id] = m;
      if (m.mediaInfo?.media.isVideo ?? false) videos.add(m.id);
      if ((m.message.nodes ?? {}).isNotEmpty) withNodes.add(m.id);
    }
  }
}

Future<void> writePayments(
  Map<ID, Palette2> state,
  void Function(Down4Payment) openPayment, [
  int limit = 5,
]) async {
  final offset = state.length;
  await for (final pay in g.wallet.nPayments(limit: limit, offset: offset)) {
    state[pay.id] = Palette2(
      key: Key(pay.id),
      node: Payment(pay.id, payment: pay, selfID: g.self.id),
      messagePreview: pay.textNote,
      buttonsInfo2: pay.isSpentBy(id: g.self.id)
          ? [
              ButtonsInfo2(
                  asset: Icon(Icons.arrow_forward_ios_rounded,
                      color: g.theme.noMessageArrowColor),
                  pressFunc: () => openPayment(pay),
                  rightMost: true)
            ]
          : [],
    );
  }
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

final bottomButtonsKey = List.generate(1000, (index) => GlobalKey());
//
// final bottomButtonsKey = [
//   GlobalKey(),
//   GlobalKey(),
//   GlobalKey(),
//   GlobalKey(),
//   GlobalKey(),
// ];
