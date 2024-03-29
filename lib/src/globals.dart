import 'dart:async';
import 'dart:io';

import 'package:down4/src/render_objects/console.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:camera/camera.dart';
// import 'package:cbl/cbl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:down4/src/bsv/wallet.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:push/push.dart';

import 'pages/loading_page.dart';

import 'data_objects/couch.dart';
import 'data_objects/_data_utils.dart';
import 'data_objects/medias.dart';
import 'data_objects/messages.dart';
import 'data_objects/nodes.dart';

import 'render_objects/_render_utils.dart';
import 'render_objects/chat_message.dart';
import 'render_objects/palette.dart';

import 'themes.dart';
import 'bsv/types.dart';

final g = Singletons.instance;

Future<GeoLoc?> requestGeoloc({required bool askPermission}) async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied && !askPermission) {
    return null;
  } else {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return null;
  }

  try {
    final point = await Geolocator.getCurrentPosition();
    return GeoLoc(point.latitude, point.longitude);
  } catch (_) {
    return null;
  }
}

Future<String?> getDeviceID() async {
  var deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    var iosDeviceInfo = await deviceInfo.iosInfo;
    return iosDeviceInfo.identifierForVendor;
  } else if (Platform.isAndroid) {
    var androidDeviceInfo = await deviceInfo.androidInfo;
    return androidDeviceInfo.id;
  } else if (Platform.isFuchsia) {
  } else if (Platform.isIOS) {
  } else if (Platform.isMacOS) {
  } else if (Platform.isWindows) {}
  return null;
}

enum Modes { def, append, forward }

class ViewManager {
  // view IDs code
  // Homepage      -> 'home'
  // GroupPage     -> 'group'
  // HyperchatPage -> 'hyper'
  // SearchPage    -> 'search'
  // SnipPage      -> 'snip'
  // ChatPage      -> 'chat@{nodeID}'
  // NodePage      -> 'node@{nodeID}'
  // ForwardPage   -> 'forward'
  // MoneyPage     -> 'money'
  // LoadingPage   -> 'loading'
  List<String> route;
  Map<String, ViewState?> views;

  ViewManager()
      : route = [],
        views = {};

  ViewState at(String viewID) => views[viewID]!;

  ViewState get home => views[route.first]!;
  ViewState get currentView => views[route.last]!;

  Set<Down4Object> forwardingObjects = {};

  bool appending = false;
  // Modes mode = Modes.def;

  void push(ViewState view) {
    route.add(view.id);
    views[view.id] ??= view;
  }

  // returns the view we are popping
  // because of possible cycles, we don't actually remove a view
  // from the views if it's still in the route. The boolean
  // stands for "view was removed from views"
  (ViewState, bool) pop() {
    final popped = route.removeLast();
    if (!route.contains(popped)) {
      return (views.remove(popped)!, true);
    }
    return (views[popped]!, false);
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
  Map<Down4ID, Down4Object> state;
  // unsafe palettes get
  Map<Down4ID, Palette<T>> pals<T extends PaletteN>() => state.cast();
  // unsafe chats get
  Map<Down4ID, ChatMessage> chats() => state.cast();

  Iterable<Down4SelectionWidget> get pageSelection =>
      state.values.selectable().selected();

  PageState({double? scroll})
      : scroll = scroll ?? 0.0,
        state = {};
}

class ViewState {
  // Every view has an ID
  final String id;
  // A view has a least 1 page, limited to 3
  final List<PageState> pages;
  // A view has a current index of the page
  int currentIndex;
  // A view can have maps of special references, ex: messagesWithVideos
  Map<String, Set<Down4ID>> notableReferences;

  Set<Down4ID> refs(String name) {
    return notableReferences[name] ??= Set<Down4ID>.identity();
  }

  Set<Down4Widget> allPageSelection() {
    return pages.map((p) => p.pageSelection).expand((s) => s).toSet();
  }

  void unselectEverything() {
    for (final p in pages) {
      for (final e in p.state.values.selectable()) {
        if (e.selected) e.select?.call(false);
      }
    }
  }

  Iterable<ChatMessage> selectedChats() {
    if (id.length > 5 && id.substring(0, 4) == "chat") {
      return pages[0].chats().values.selected();
    } else {
      return [];
    }
  }

  List<ComposedID>? orderedChats;

  ViewState({
    required this.id,
    required this.pages,
    int? ix,
    this.orderedChats,
  })  : currentIndex = ix ?? 0,
        notableReferences = {};

  PageState get currentPage => pages[currentIndex];
}

class Sizes {
  Sizes({
    required this.h,
    required this.w,
    required this.fullHeight,
    required this.headerHeight,
    required this.statusBarHeight,
  });
  double h;
  double w;
  double statusBarHeight;
  double fullHeight;
  double headerHeight;
  Offset get middlePoint => Offset(w / 2, h / 2);
  Size get fullSize => Size(w, fullHeight);
  Size get snipSize => Size(w, fullHeight - Console.buttonHeight);
  Size get bodySize => Size(w, h - Console.buttonHeight);
  Size get paddedSize => Size(w, h);
  double get viewPaddingHeight => fullHeight - h;
  double get fullAspectRatio => w / fullHeight;
  double get paddedAspectRatio => w / h;
}

class Singletons {
  static final Singletons _instance = Singletons();
  static Singletons get instance => _instance;

  final ViewManager vm = ViewManager();

  late CurrentTheme myTheme;

  Down4Theme get theme => themesRegistry[myTheme.themeName]!;

  late Self self;
  late Wallet wallet;
  late Sizes sizes;
  late ExchangeRate exchangeRate;
  final Map<MediaType, List<Down4ID>> savedMediasIDs = {};
  late Image ph, d1, d2, d3, lg;
  late Uint8List background;
  late List<CameraDescription> cameras;

  bool get notYetInitialized {
    final self_ = Self.loadSelf();
    if (self_ != null) {
      self = self_;
      return false;
    } else {
      return true;
    }
  }

  DatabaseReference get messageQueue {
    return self.id.server.realtimeDB
        .ref("nodes/${g.self.id.unik}/queues/${g.self.deviceID}");
  }

  void loadExchangeRate(ExchangeRate er) => exchangeRate = er;

  void loadTheme(CurrentTheme theme) => myTheme = theme;

  void loadSizes(Sizes s) => sizes = s;

  void loadWallet() {
    final wallet_ = Wallet.load();
    if (wallet_ == null) return print("Wallet is null");
    wallet = wallet_;
  }

  void initWallet(Uint8List s1, Uint8List s2) {
    final keys = Down4Keys.fromRandom(s1, s2);
    wallet = Wallet(keys: keys, ix: null);
    wallet.merge();
  }

  void initSelf(Self s) {
    self = s;
  }

  Icon get snipArrow =>
      Icon(Icons.arrow_forward_ios_rounded, color: theme.snipArrowColor);

  Icon get noMessageArrow =>
      Icon(Icons.arrow_forward_ios_rounded, color: theme.noMessageArrowColor);

  Icon get messageArrow =>
      Icon(Icons.arrow_forward_ios_rounded, color: theme.messageArrowColor);
}

typedef BGen<T extends PaletteN> = List<ButtonsInfo2> Function(T n);

void writePalette<T extends PaletteN>(
  T c,
  Map<Down4ID, Down4Widget> s,
  List<ButtonsInfo2> Function(T n)? bGen,
  void Function()? refresh, {
  bool home = false,
  bool hidePreview = false,
  bool? sel,
}) {
  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  final Palette? pInState = s[c.id] as Palette?;
  final bool? selectionIfReload = pInState?.selected;
  final bool isSelected = sel ?? selectionIfReload ?? false;

  final node = c;

  final hide = home && node is User && !node.isConnected && !node.hasMessages();

  void Function(bool)? select;
  if (!(refresh == null || hide)) {
    select = (bool doRefresh) {
      writePalette(c, s, bGen, refresh,
          sel: !isSelected, home: home, hidePreview: hidePreview);
      if (doRefresh) refresh.call();
    };
  }

  s[c.id] = Palette(
      key: GlobalKey(),
      node: c,
      selected: isSelected,
      imPress: () => select?.call(true),
      hidePreview: hidePreview,
      show: !hide,
      select: select,
      bodyPress: () => select?.call(true),
      buttonsInfo2: hide ? [] : bGen?.call(c) ?? []);
}

Future<ChatMessage?> getChatMessage({
  required Map<Down4ID, Down4Widget> state,
  required ChatN ch,
  required Down4ID msgID,
  required Down4ID? prevMsgID,
  required Down4ID? nextMsgID,
  required bool isFirst,
  required void Function(Down4Node)? openNode,
  required void Function() refreshCallback,
  required void Function(Chat message) react,
  required Future<void> Function(Chat, Down4ID) increment,
}) async {
  final msg = await global<Chat>(msgID);
  if (msg == null) return null;
  Chat? prevMsg, nextMsg;
  final prevChatMessage = state[prevMsgID] as ChatMessage?;
  // If new message while in chat, we might want to remove the header of the
  // previous last message
  if (isFirst &&
      prevMsgID != null &&
      prevChatMessage != null &&
      prevChatMessage.hasHeader &&
      msg.senderID == prevChatMessage.message.senderID &&
      msg.senderID != g.self.id) {
    // we need to remove its header
    state[prevMsgID] = prevChatMessage.withHeader(hasHeader: false);
    // and update it's size
  }

  if (state[msgID] != null) {
    return state[msgID] as ChatMessage;
  }

  prevMsg = await global<Chat>(prevMsgID);
  nextMsg = await global<Chat>(nextMsgID);

  bool hasGap = false;
  if (prevMsg != null) hasGap = ChatMessage.displayGap(msg, prevMsg);

  // mark as read
  msg.markRead();

  final bool senderIsSelf = msg.senderID == g.self.id;
  final bool hasHeader =
      !senderIsSelf && ch is GroupN && nextMsg?.senderID != msg.senderID;

  final cm = ChatMessage(
      hasGap: hasGap,
      message: msg,
      nodeRef: ch.id,
      react: react,
      increment: increment,
      mediaInfo: await ChatMessage.generateMediaInfo(msg),
      nodes: null,
      repliesInfo: await ChatMessage.generateRepliesInfo(msg, (replyID) {
        print("TODO, GO TO REPLY ID = $replyID");
      }),
      hasHeader: hasHeader,
      openNode: openNode,
      myMessage: g.self.id == msg.senderID,
      select: (refresh) {
        final ref = state[msgID] as ChatMessage;
        state[msgID] = ref.invertedSelection();
        if (refresh) refreshCallback();
      });

  await globall<Down4Media>(msg.reactions.values.map((e) => e.mediaID));

  // Future for fetching the nodes attached to a message
  // It when done, it will callback and refresh the message with
  // the palettes showing properly
  Future.microtask(() async {
    if ((msg.nodes ?? {}).isNotEmpty) {
      final nodes = await globall<Down4Node>(msg.nodes!, doFetch: true);
      if (nodes.isNotEmpty) {
        final ref = state[msg.id] as ChatMessage;
        state[msg.id] = ref.withNodes(nodes);
        refreshCallback();
      }
    }
  });

  return cm;
}

Future<void> writePost({
  required Chat msg,
  required Map<Down4ID, Down4Widget> state,
  required void Function(Down4Node)? openNode,
  required void Function() refreshCallback,
}) async {
  final nodes = await globall<Down4Node>(msg.nodes);
  state[msg.id] = ChatMessage(
      hasGap: false,
      message: msg,
      nodeRef: ComposedID(),
      react: (_) async {},
      increment: (_, __) async {},
      mediaInfo: await ChatMessage.generateMediaInfo(msg),
      nodes: nodes.whereType<Down4Node>().toList(),
      repliesInfo: await ChatMessage.generateRepliesInfo(msg, (replyID) {
        print("TODO, GO TO REPLY ID = $replyID");
      }),
      hasHeader: false,
      openNode: openNode,
      myMessage: g.self.id == msg.senderID,
      select: (refresh) {
        final ref = state[msg.id] as ChatMessage;
        state[msg.id] = ref.invertedSelection();
        if (refresh) refreshCallback();
      });
}

Future<void> writeMessages({
  required ChatN ch,
  required List<Down4ID> ordered,
  required Map<Down4ID, Down4Widget> state,
  required Set<Down4ID> videos,
  required Set<Down4ID> withNodes,
  required void Function() refresh,
  required void Function(Down4Node)? openNode,
  int limit = 20,
  required void Function(Chat message) react,
  required Future<void> Function(Chat, Down4ID) increment,
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
        isFirst: isFirst,
        openNode: openNode,
        increment: increment,
        react: react,
        refreshCallback: refresh);
    if (m != null) {
      state[m.id] = m;
      if (m.mediaInfo?.media is Down4Video) videos.add(m.id);
      if ((m.message.nodes ?? {}).isNotEmpty) withNodes.add(m.id);
    }
  }
}

void writePayment(
  Map<Down4ID, Down4Widget> state,
  PaymentNode paymentNode,
  List<ButtonsInfo2> buttons,
) {
  state[paymentNode.id] = Palette(
    key: GlobalKey(),
    node: paymentNode,
    // messagePreview: paymentNode.payment.textNote,
    buttonsInfo2: buttons,
  );
}

void writePayments(
  Map<Down4ID, Down4Widget> state,
  void Function(Down4Payment) openPayment, [
  int limit = 5,
]) {
  final offset = state.length;
  for (final pay in Wallet.nPayments(limit: limit, offset: offset)) {
    final deyEqual = pay.spender == g.self.id;
    print("""
      pay.spender = ${pay.spender?.value}
      self        = ${g.self.id.value}
      deyEqual    = $deyEqual
      """);

    state[pay.id] = Palette(
      key: Key(pay.id.unik),
      node: PaymentNode(payment: pay, selfID: g.self.id),
      // messagePreview: pay.textNote,
      buttonsInfo2: [
        ButtonsInfo2(
            asset: Icon(Icons.arrow_forward_ios_rounded,
                color: pay.spender == g.self.id
                    ? g.theme.messageArrowColor
                    : g.theme.noMessageArrowColor),
            pressFunc: () => openPayment(pay),
            rightMost: true)
      ],
    );
  }
}

final topButtonsKey = [
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
];

final bottomButtonsKey = List.generate(1000, (index) => GlobalKey());
