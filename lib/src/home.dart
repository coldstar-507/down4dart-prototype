import 'dart:async';

import 'package:camera/camera.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:down4/src/pages/_page_utils.dart';
import 'package:down4/src/pages/map_page.dart';
import 'package:down4/src/pages/map_page2.dart';
import 'package:down4/src/pages/preview_page.dart';
import 'package:down4/src/themes.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'data_objects/couch.dart';
import 'data_objects/_data_utils.dart';
import 'data_objects/medias.dart';
import 'data_objects/messages.dart';
import 'data_objects/nodes.dart';
import 'globals.dart';
import 'web_requests.dart' as r;
import '_dart_utils.dart';
import 'bsv/types.dart';

import 'pages/chat_page.dart';
import 'pages/forwarding_page.dart';
import 'pages/group_page.dart';
import 'pages/home_page.dart';
import 'pages/hyperchat_page.dart';
import 'pages/loading_page.dart';
import 'pages/money_page.dart';
import 'pages/node_page.dart';
import 'pages/search_page.dart';
import 'pages/welcome_page.dart';
import 'pages/camera_page.dart';
import 'pages/snipview_page.dart';

import 'render_objects/palette.dart';
import 'render_objects/chat_message.dart';
import 'render_objects/_render_utils.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  late Down4PageWidget page = const LoadingPage2();
  ViewManager get viewManager => g.vm;

  // this will be used to not show toast when notification was received
  late int _lastLiveTimestamp;

  Set<Down4Object> get forwardingObjects => viewManager.forwardingObjects;
  List<String> get route => viewManager.route;
  ViewState get homeView => viewManager.home;
  PageState get homePageState => homeView.currentPage;
  ViewState get currentView => viewManager.currentView;

  // homestate getters
  Map<Down4ID, Palette<ChatN>> get _chats => homeView.pages[0].state.cast();
  Map<Down4ID, Palette> get _otherConns => homeView.pages[1].state.cast();

  Iterable<Palette<ChatN>> get chats => _chats.values.cast()..showing();
  Iterable<ConnectN> get homeConnection =>
      _chats.values.asNodes<ConnectN>().where((n) => n.isConnected);

  List<Palette> get formattedHome => chats.toList().formatted();
  Map<Down4ID, ChatMessage>? chatMessages(ComposedID nodeID) {
    return viewManager.views["chat@${nodeID.value}"]?.pages[0].state.cast();
  }

  void setPage(Down4PageWidget p) {
    if (page.id != p.id) {
      const raw = "UPDATE personals SET currentPage = ? WHERE id = 'single'";
      try {
        Down4Local().db.execute(raw, [p.id]);
      } catch (e) {
        print("\n\tERROR IN SETPAGE: $e\n");
      }
    }
    page = p;
    setState(() {});
  }

  void back() {
    if (page is HomePage) {
      return print("closing app");
    }
    final (ViewState poppedView, bool wasPopped) = viewManager.pop();
    final pID = poppedView.id.split('@');
    final pp0 = pID.first;
    final pp1 = pID.length > 1 ? pID[1] : null;
    final n = local<Down4Node>(Down4ID.fromString(pp1));
    if (pp0 == "chat" && n is ChatN && wasPopped) {
      writePalette(n, _chats, bGen, rfHome, home: true);
    }
    final pID_ = currentView.id.split('@');
    final pp0_ = pID_.first;
    final pp1_ = pID_.length > 1 ? pID_[1] : null;
    final n_ = local<Down4Node>(Down4ID.fromString(pp1_));
    switch (pp0_) {
      case 'home':
        print("backing to homepage");
        return setPage(homePage());
      case 'chat':
        print("backing to chat page");
        return setPage(chatPage(n_ as ChatN, isReload: true));
      case 'node':
        print("backing to node page");
        return setPage(nodePage(n_!));
      case 'money':
        print("backing to money page");
        return setPage(moneyPage());
      case 'search':
        print("backing to search page");
        return setPage(searchPage());
      case 'forward':
        print("backing to forward page");
        return setPage(forwardPage());
    }
  }

  void openPreview() async => setPage(await previewPage(isPush: true));

  StreamSubscription? _forgroundMessageListener, _notificationListener;

  final Map<ComposedID, StreamSubscription> _nodeConnections = {};

  void homeScrollToZero() => homePageState.scroll = 0;

  // ========================= INITIALIZATION ============================ //

  void connectToNodes() async {
    for (final n in homeConnection) {
      final conn = n.connection.listen((event) async {
        final (publicHash, blueHash, lastOnline) =
            Down4Node.parseConnection(event.snapshot.value as String);
        if (publicHash != n.publicHash) {
          n
            ..mergeWith(await n.remoteFetch())
            ..merge();
        }
        if (lastOnline != 0) (n as PersonN).updateLastOnline(lastOnline);
        if (n is ChatN) {
          writePalette<ChatN>(n as ChatN, _chats, bGen, rfHome, home: true);
        } else {
          writePalette(n, _otherConns, bGen2, rfHome, home: false);
        }
        if (page is HomePage) return setPage(homePage());
      });
      _nodeConnections[n.id] = conn;
    }
  }

  void rfHome() => setPage(homePage());

  void loadSavedMediasIDs() {
    for (final m in MediaType.values) {
      g.savedMediasIDs[m] = savedMediaIDs(m).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _lastLiveTimestamp = makeTimestamp();
    WidgetsBinding.instance.addObserver(this);
    final homeChats = PageState();
    final homeConns = PageState();
    g.vm.push(ViewState(id: "home", pages: [homeChats, homeConns]));
    // db.execute("""
    //   DELETE FROM messages
    //   WHERE type = 'snip'
    //   """);
    processChats(unsentMessages());
    messagesDeletingRoutine();
    mediasDeletingRoutine();
    localPalettesRoutine(init: true);
    connectToMessages3();
    connectToNodes();
    loadSavedMediasIDs();
    clearAppCache();
    g.wallet.walletRoutine(callback: afterPayment);
    g.wallet.printWalletInfo();
    updateExchangeRate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastLiveTimestamp = makeTimestamp();
      Down4Local()
          .db
          .execute("UPDATE personals SET currentPage = ?", [page.id]);
      connectToMessages3();
    } else {
      Down4Local().db.execute("UPDATE personals SET currentPage = ?", [null]);
      _forgroundMessageListener?.cancel();
    }
    switch (state) {
      case AppLifecycleState.resumed:
        print("app in resumed");
        break;
      case AppLifecycleState.inactive:
        print("app in inactive");
        break;
      case AppLifecycleState.paused:
        print("app in paused");
        break;
      case AppLifecycleState.detached:
        print("app in detached");
        break;
      case AppLifecycleState.hidden:
        print("app in hidden");
        break;
    }
  }

  @override
  void dispose() {
    print("\n\n=== DISPOSING OF HOME ===\n\n");
    _notificationListener?.cancel();
    _forgroundMessageListener?.cancel();
    for (final nConn in _nodeConnections.values) {
      nConn.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> localPalettesRoutine({bool init = false}) async {
    print("\n===LOCAL PALETTE ROUTINE===\n");
    final allHomeNodes = loadHome().followedBy([g.self]);
    final Iterable<GroupN> groups = allHomeNodes.whereType<GroupN>();
    final groupUserIDs =
        groups.map((e) => e.members).expand((id) => id).toSet();
    final Iterable<User> users = allHomeNodes.whereType<User>();

    final homeIDs = allHomeNodes.asIDs().toSet();
    final homeNodesMediaIDs =
        allHomeNodes.map((e) => e.mediaID).whereType<ComposedID>();

    // caches home node medias from local
    locall<Down4Media>(homeNodesMediaIDs);

    List<User> hiddenUsers = [];
    for (final u in users) {
      if (!u.isConnected && !u.hasMessages()) hiddenUsers.add(u);
    }

    final hiddenIDs = hiddenUsers.asIDs().toSet();

    // we dump hidden users that are not in groups
    final shouldDump = hiddenIDs.difference(groupUserIDs);
    final sbuf = StringBuffer("DELETE FROM nodes WHERE id IN (");
    sbuf.writeAll(shouldDump.map((id) {
      Down4Cache().unCache(id);
      return "?";
    }), ",");
    sbuf.write(")");
    final params = shouldDump.map((e) => e.sqlReady).toList();
    Down4Local().db.execute(sbuf.toString(), params);

    print("TO DUMP: ${shouldDump.map((id) => id.unik)}");
    for (final n in allHomeNodes) {
      if (n is Hyperchat && n.isEmptyChat) {
        n.expire();
      } else {
        writePalette(n, _chats, bGen, rfHome, home: true);
      }
    }

    if (init) {
      setPage(homePage());
    }

    // we fetch users in groups that are not in home
    final toFetch = groupUserIDs.difference(homeIDs);
    final fetchedNodes =
        await globall<PersonN>(toFetch, doFetch: true, doMergeIfFetch: true);
    print("TO FETCH: ${toFetch.map((id) => id.unik)}");

    final nodeMediasToFetch =
        fetchedNodes.map((n) => n.mediaID).whereType<ComposedID>();

    // we do homeNodesMedias aswell because it's possible we have nodes
    // but not the medias (in case of a offline add for example)
    await globall<Down4Media>(nodeMediasToFetch.followedBy(homeNodesMediaIDs),
        doFetch: true, doMergeIfFetch: true);

    for (final n in fetchedNodes) {
      writePalette(n, _chats, bGen, rfHome, home: true);
    }
  }

  List<ButtonsInfo2> bGen(ChatN n) {
    final snips = n.unreadSnipIDs();
    if (snips.isNotEmpty) {
      return [
        ButtonsInfo2(
          asset: Icon(Icons.arrow_forward_ios_rounded,
              color: g.theme.snipArrowColor), //  g.red,
          pressFunc: () => viewSnips2(n),
          longPressFunc: () => n is PersonN ? setPage(nodePage(n)) : null,
          rightMost: true,
        )
      ];
    } else {
      return [
        ButtonsInfo2(
            asset: Icon(Icons.arrow_forward_ios_rounded,
                color: n.lastChatFromOtherIsUnread()
                    ? g.theme.messageArrowColor
                    : g.theme.noMessageArrowColor),
            pressFunc: () => setPage(chatPage(n, isPush: true)),
            longPressFunc: () =>
                n is PersonN ? setPage(nodePage(n, isPush: true)) : null,
            rightMost: true)
      ];
    }
  }

  List<ButtonsInfo2> bGen2(Down4Node n) {
    return [
      ButtonsInfo2(
          asset: Icon(Icons.arrow_forward_ios_rounded,
              color: g.theme.noMessageArrowColor), // g.fifty,
          pressFunc: () => setPage(nodePage(n, isPush: true)),
          rightMost: true)
    ];
  }

  void connectToMessages3() async {
    _forgroundMessageListener =
        g.messageQueue.onChildAdded.listen((event) async {
      print("new message attached to the queue!");
      final snapshot = event.snapshot;
      print("key: ${snapshot.key}, value: ${snapshot.value}");
      final val = snapshot.value as String?;
      if (val == null) {
        snapshot.ref.remove();
        return print("no data on message!");
      }
      final vals = val.split("!"); // need a separator that's not '~'
      print("\nvals=$vals\n");
      // consume the message
      snapshot.ref.remove();
      switch (vals[0]) {
        case 'm': // 'm!msgID
          print("processing chat message");
          // basic chats and snips
          final msgID = ComposedID.fromString(vals[1])!;
          final msg = await global<Messages>(msgID,
              doFetch: true, doMergeIfFetch: true);
          if (msg == null) return print("msg is null");
          final rtID = idOfRoot(root: msg.root, selfID: g.self.id);
          final (rootNode, rootgt) =
              await globalgt<ChatN>(rtID, doFetch: true, doMergeIfFetch: true);

          if (rootNode == null) return;

          PersonN? senderNode = await global<PersonN>(msg.senderID,
              doFetch: true, doMergeIfFetch: true);
          Down4Media? msgMedia;

          if (senderNode != null && senderNode.isConnected) {
            // we predownload the media, else it's download on open
            msgMedia = await global<Down4Media>(msg.mediaID,
                doFetch: true, doMergeIfFetch: true, tempID: msg.tempMediaID);
          }

          // get the rootNode media
          await global<Down4Media>(rootNode.mediaID,
              doFetch: true, doMergeIfFetch: true);

          // msg medias references are dynamic and always get updated
          // this is because messages are not kept for ever on server
          if (msg.tempMediaID != null) {
            msgMedia?.updateTempReferences(msg.tempMediaID!, msg.tempMediaTS!);
          }

          // if there are users in the group that aren't in home,
          // localPaletteRoutine will take care of it
          final homeKeys = _chats.keys.toList();
          if (rootgt == GetType.fetch &&
              rootNode is GroupN &&
              !rootNode.members.every((uid) => homeKeys.contains(uid))) {
            localPalettesRoutine();
          }

          rootNode.updateActivity();
          writePalette(rootNode, _chats, bGen, rfHome, home: true);

          final viewID = "chat@${rootNode.id.value}";
          final currentlyInChat = page is ChatPage && currentView.id == viewID;
          final dontShowToast = currentlyInChat &&
              msg is Chat &&
              // we only show toast, if the message was created after last live
              msg.timestamp > _lastLiveTimestamp;

          if (msg is Chat) {
            final refView = viewManager.views[viewID];
            refView?.orderedChats = [msg.id, ...refView.orderedChats!];
            if (currentlyInChat) {
              setPage(chatPage(rootNode, isReload: true));
            }
          }

          if (page is HomePage) setPage(homePage());
          if (!dontShowToast && senderNode != null) {
            final firstName = senderNode.displayName.split(" ")[0];
            final isChat = msg is Chat;
            var tst = "${isChat ? 'Chat' : 'Snip'} from $firstName";
            if (rootNode is GroupN) tst += " in ${rootNode.displayName}";
            Fluttertoast.showToast(
                msg: tst,
                gravity: ToastGravity.TOP,
                backgroundColor: g.theme.inputColor,
                textColor: g.theme.inputTextStyle.color);
          }
          break;
        case 'r': // r!msgID!mediaID!tempMediaID!reactorID!reactionID!tempMediaTS
          print("processing reaction");
          final r = Reaction.fromStrings(vals);
          final msg = await global<Chat>(r.messageID,
              doFetch: true, doMergeIfFetch: true);
          if (msg == null) return print("cannot react to a null message");
          final media = await global<Down4Media>(r.mediaID,
              doFetch: true, doMergeIfFetch: true, tempID: r.tempMediaID);
          msg.addReaction(r);
          final rtID = idOfRoot(root: msg.root, selfID: g.self.id);
          reloadChatWithID(rtID, msgRe: msg);
          if (media != null && r.tempMediaID != null && r.tempMediaTS != null) {
            media.updateTempReferences(r.tempMediaID!, r.tempMediaTS!);
          }
          break;
        case 'i': // i!msgID!reactionID!reactorID
          print("processing reaction increment");
          final msgID = ComposedID.fromString(vals[1])!;
          final reactionID = Down4ID.fromString(vals[2])!;
          final reactorID = ComposedID.fromString(vals[3])!;

          final msg =
              await global<Chat>(msgID, doFetch: true, doMergeIfFetch: true);
          if (msg == null) return;

          msg
            ..reactions[reactionID]?.reactors.add(reactorID)
            ..mergeReactions();

          final rtID = idOfRoot(root: msg.root, selfID: g.self.id);
          reloadChatWithID(rtID, msgRe: msg);
          break;
        case 'p': // p!paymentID!tempPaymentID
          print("processing payment");
          final paymentID = Down4ID.fromString(vals[1])!;
          final tempPaymentID = ComposedID.fromString(vals[2])!;
          final payment = await global<Down4Payment>(paymentID,
              doFetch: true, doMergeIfFetch: true, tempID: tempPaymentID);
          if (payment == null) return print("no payment for download");
          print("compressed payment:\n${payment.compressed}");
          g.wallet.parsePayment3(g.self.id, payment, callback: () {
            afterPayment(payment);
            if (payment.timestamp < _lastLiveTimestamp) {
              Fluttertoast.showToast(
                  msg: "Payment received",
                  gravity: ToastGravity.TOP,
                  backgroundColor: g.theme.inputColor,
                  textColor: g.theme.inputTextStyle.color);
            }
          });

          break;
      }
    });
  }

  void rewriteHomePalettes() {
    for (final p in chats) {
      writePalette(p.node, _chats, bGen, rfHome, home: true);
    }
  }

  // =============================== UTILS ============================== //

  void openPay(Down4Payment payment) => setPage(paymentPage(payment));

  List<ButtonsInfo2> payBGen(PaymentNode p) => [
        ButtonsInfo2(
            asset: Icon(Icons.arrow_forward_ios_rounded,
                color: p.payment.spender == g.self.id
                    ? g.theme.messageArrowColor
                    : g.theme.noMessageArrowColor),
            pressFunc: () => openPay(p.payment)),
      ];

  void afterPayment([Down4Payment? p]) {
    print("""
      ////////////////////////////////////////////////////////
      // after payment got called, p == null = ${p == null} //
      ////////////////////////////////////////////////////////
      """);
    final ref = page;
    if (ref is MoneyPage) {
      final payState = currentView.pages[1].pals<PaymentNode>();
      if (p != null) {
        final newP = PaymentNode(payment: p, selfID: g.self.id);
        final ps = <Down4ID, Palette<PaymentNode>>{};
        for (final p in [newP].followedBy(payState.values.map((e) => e.node))) {
          writePalette(p, ps, payBGen, null);
        }
        currentView.pages[1].state = ps;
      } else {
        for (final m in payState.values) {
          writePalette(m.node, payState, payBGen, null);
        }
      }
      setPage(moneyPage());
    } else if (ref is PaymentPage) {
      setPage(paymentPage(p ?? ref.payment));
    }
  }

  void reloadChatWithID(Down4ID chatableNodeID, {Chat? msgRe}) {
    if (currentView.id == "chat@${chatableNodeID.value}") {
      setPage(chatPage(cache<ChatN>(chatableNodeID)!, msgRe: msgRe));
    }
  }

  Future<void> updateExchangeRate() async {
    final lastUpdate = g.exchangeRate.lastUpdate;
    final rightNow = makeTimestamp();
    if (rightNow - lastUpdate > const Duration(minutes: 10).inMilliseconds) {
      final rate = await r.getExchangeRate();
      if (rate != null) {
        g.exchangeRate.rate = rate;
        g.exchangeRate.lastUpdate = rightNow;
        g.exchangeRate.merge();
        if (currentView.id == 'money') setPage(moneyPage());
      }
    }
  }

  void unselectHomeSelection({bool updateActivity = true}) {
    for (final p in chats.selected()) {
      if (updateActivity) p.node.updateActivity();
      writePalette(p.node, _chats, bGen, rfHome, sel: false, home: true);
    }
  }

  List<Palette> forwardables(List<Palette> ps) {
    final idsInGroups = ps
        .asNodes<GroupN>()
        .map((e) => e.members)
        .expand((element) => element)
        .toSet();
    final forwardables = ps.whereNodeIs<BranchN>().asIDs();
    final all = forwardables.followedBy(idsInGroups).toSet();
    return all.map((id) => _chats[id]).whereType<Palette>().toList();
  }

  // =========================== PAGES FUNCTIONS ======================== //

  Future<void> processChats(Iterable<Chat> chats) async {
    g.vm.appending = false;
    g.vm.forwardingObjects.clear();

    if (chats.isEmpty) return;

    for (final root in chats.map((e) => e.root)) {
      final rtID = idOfRoot(root: root);
      final rt = local<ChatN>(rtID);
      if (rt == null) return;
      rt.updateActivity();
      writePalette(rt, _chats, bGen, rfHome, home: true);
    }
    if (page is HomePage) setPage(homePage());

    // these chats passed in parameter can also be forwarded chats
    Future<void> pc_(Chat c, [VoidCallback? cb]) async {
      final rtID = idOfRoot(root: c.root);
      final rt = local<ChatN>(rtID);
      if (rt == null) return;
      final fsuccess = r.push(rt.messageTargets, c, cb);
      final success = await fsuccess;
      if (success) c.markSent();
      reloadChatWithID(rtID, msgRe: c);
    }

    final (h, t) = chats.toList().headTail();
    pc_(h, () => t.map((e) => pc_(e)).toList());
  }

  Future<void> sendSnip({
    required Down4Media? backgroundMedia,
    required List<SnipStick> sticks,
    required Size ps,
    required String? text,
    required double? pdy,
  }) async {
    setPage(loadingPage());

    final selection = chats.selected().asNodes();
    if (selection.contains(g.self)) {
      await backgroundMedia?.writeFromCachedPath();
      backgroundMedia
        ?..cache()
        ..merge();
    }

    final sels = chats.selected().asNodes<ChatN>().toList();
    if (sels.isEmpty) return;

    Future<void> sendSnip_(ChatN n, [VoidCallback? cb]) async {
      final snip = Snip(ComposedID(),
          snipSize: ps,
          sticks: sticks,
          root: n.root_,
          senderID: g.self.id,
          txt: text,
          mediaID: backgroundMedia?.id);

      r.push(n.messageTargets, snip, cb);
      if (n.id == g.self.id) {
        snip
          ..cache()
          ..merge();
      }
    }

    // the reason for this strange arrangement is in the case of sending
    // the same snip to multiple target,
    final (head, tail) = sels.headTail();
    sendSnip_(head, () {
      for (final n in tail) {
        sendSnip_(n);
      }
      unselectHomeSelection();
      viewManager.popUntilHome();
      setPage(homePage(prompt: "SNIPED"));
    });
  }

  // ============================== PAGES ============================== //

  Down4PageWidget homePage({String? prompt}) {
    return HomePage(
      drawerOptions: [
        (() => setPage(mapPage(isPush: true)!), "Map"),
        (() => setPage(searchPage(isPush: true)), "Search"),
        (() => setPage(themePage(isPush: true)), "Themes"),
      ],
      openPreview: openPreview,
      forward: () {
        viewManager.forwardingObjects.addAll(chats.selected());
        setPage(forwardPage(isPush: true));
      },
      openChat: (n, f) => setPage(chatPage(n, isPush: true)),
      send: processChats,
      add: () async {
        final selectedPals = chats.selected().asNodes<PersonN>();
        for (final n in selectedPals) {
          if (n is User) n.updateConnectionStatus(true);
          writePalette(n, _chats, bGen, rfHome, home: true);
          (await global<Down4Image>(n.mediaID))?.downloadAndWriteIfNeeded();
        }
        rfHome();
        localPalettesRoutine();
      },
      hyperchat: () =>
          setPage(hyperchatPage(chats.formatted(), homePageState.scroll)),
      group: () => setPage(groupPage()),
      money: () => setPage(moneyPage(
          initPals: chats.formatted(),
          initScroll: homePageState.scroll,
          isPush: true)),
      ping: (text) => print("Deprecated"),
      snip: () => setPage(snipPage()),
      search: () => setPage(searchPage(isPush: true)),
      themes: () => setPage(themePage(isPush: true)),
      delete: () async {
        for (final p in List<Palette<ChatN>>.from(chats)) {
          if (p.selected && p.id != g.self.id) {
            _chats.remove(p.node.id);
            p.node.delete();
          }
        }
        setPage(homePage());
        await localPalettesRoutine();
      },
    );
  }

  Down4PageWidget loadingPage({String? seed}) {
    return LoadingPage2(seed: seed);
  }

  Future<Down4PageWidget> previewPage({required bool isPush}) async {
    Set<Down4Object> fo() => viewManager.forwardingObjects;

    Map<Down4ID, Down4SelectionWidget> s() => currentView.pages[0].state.cast();

    void rf() async => setPage(await previewPage(isPush: false));

    if (isPush) {
      // we put our self in default mode for preview
      // g.vm.mode = Modes.def;
      viewManager.push(ViewState(id: "preview", pages: [PageState()]));

      for (final n in fo().palettes().map((p) => p.node)) {
        writePalette(n, s(), null, rf, home: false, hidePreview: true);
      }

      final fs = fo()
          .chatMsgs()
          .map((m) => m.message.forwarded(g.self.id, Down4ID().unik));
      for (final m in fs) {
        await writePost(
            msg: m, refreshCallback: rf, state: s(), openNode: null);
      }
    }

    return PreviewPage(back: back);
  }

  Down4PageWidget forwardPage({bool isPush = false}) {
    PageState fPage() => currentView.currentPage;
    Map<Down4ID, Palette> fState() => fPage().state.cast();
    List<Palette> fs() => fState().values.toList();

    void rf() => setPage(forwardPage());
    List<ButtonsInfo2> fbGen(ChatN c) {
      return [
        ButtonsInfo2(
            asset: Icon(Icons.arrow_forward_ios_rounded,
                color: g.theme.noMessageArrowColor),
            rightMost: true,
            pressFunc: () => setPage(chatPage(c, isPush: true)))
      ];
    }

    if (isPush) {
      viewManager.popUntilHome();
      viewManager.push(ViewState(id: "forward", pages: [PageState()]));
      for (final c in formattedHome.asNodes<ChatN>()) {
        writePalette(c, fState(), fbGen, rf, home: true);
      }
    }

    return ForwardingPage(
        openPreview: openPreview,
        hyper: () => setPage(hyperchatPage(fs(), fPage().scroll)),
        forward: (chats) {
          processChats(chats);
          unselectHomeSelection(updateActivity: true);
          homeScrollToZero();
          viewManager.popUntilHome();
          setPage(homePage());
        },
        back: () {
          viewManager.forwardingObjects.clear();
          back();
        });
  }

  Down4PageWidget paymentPage(Down4Payment payment) {
    viewManager.push(ViewState(id: "payment", pages: []));
    return PaymentPage(
      ok: () {
        viewManager.popUntilHome();
        setPage(homePage());
      },
      sendPayment: (pay) async {
        final receivers = pay.txs.last.txsOut
            .map((utxo) => utxo.isGets ? utxo.receiver : null)
            .whereType<ComposedID>()
            .toList(growable: false);

        final ppl = await globall<PersonN>(receivers, doFetch: true);
        final payment = Payment(senderID: g.self.id, paymentID: pay.id);

        // TODO: this returns success, and should perhaps have something happen
        // depening on success or failure
        r.push(ppl, payment);

        viewManager.popUntilHome();
        setPage(homePage());
      },
      back: back,
      payment: payment,
    );
  }

  Down4PageWidget themePage({bool isPush = false}) {
    Map<Down4ID, Palette> themes() =>
        viewManager.at("themes").pages[0].state.cast();
    Iterable<Palette> paletteThemes() => themes().values.cast();
    void refresh() => setPage(themePage());

    List<ButtonsInfo2> tGen(NodeTheme t) {
      void swapTheme() {
        g.myTheme.changeTheme(t.displayName);
        for (final t in paletteThemes().asNodes<NodeTheme>()) {
          writePalette<NodeTheme>(t, themes(), tGen, refresh, home: false);
        }
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: g.theme.topStatusIconBrightness,
          systemNavigationBarColor: g.theme.bottomNavigationBarColor,
          systemNavigationBarIconBrightness:
              g.theme.bottonNavigationIconBrightness,
        ));
        // TODO, not waiting this future could be problematic
        g.theme.readMapStyle();
        setPage(themePage());
        rewriteHomePalettes();
      }

      return [ButtonsInfo2(asset: g.noMessageArrow, pressFunc: swapTheme)];
    }

    if (isPush) {
      viewManager.push(ViewState(id: "themes", pages: [PageState()]));
      for (final t in themesRegistry.entries) {
        writePalette(NodeTheme(t.value), themes(), tGen, refresh, home: false);
      }
    }

    return ThemePage(themes: themes(), onSwap: rewriteHomePalettes, back: back);
  }

  Down4PageWidget moneyPage({
    bool isPush = false,
    List<Palette>? initPals,
    double? initScroll,
    PersonN? single,
  }) {
    // Map<Down4ID, Palette> peopleState() => currentView.pages[0].state.cast();
    Map<Down4ID, Palette> paymentState() => currentView.pages[1].state.cast();
    void rf() => setPage(moneyPage());

    void scanOrReceivePayment(Down4Payment pay) {
      // this will put the payment at the begining of the list
      final p = PaymentNode(payment: pay, selfID: g.self.id);
      currentView.pages[1].state = {
        pay.id: Palette(node: p, key: Key(p.id.unik), buttonsInfo2: payBGen(p)),
        ...paymentState(),
      };
      rf();
    }

    if (isPush) {
      final ppl = PageState();
      final pay = PageState();
      viewManager.push(ViewState(id: "money", pages: [ppl, pay]));
      writePayments(paymentState(), openPay, 10);
    }

    return MoneyPage(
        single: single,
        initPalettes: initPals,
        initScroll: initScroll,
        // viewState: currentView,
        loadMorePayments: () async {
          writePayments(paymentState(), openPay, 10);
          setPage(moneyPage());
        },
        onScan: (payment) {
          final parsedPayment = g.wallet.parsePayment3(g.self.id, payment,
              callback: () => afterPayment(payment));
          if (parsedPayment != null) scanOrReceivePayment(parsedPayment);
        },
        makePayment: (payment) {
          final parsedPayment = g.wallet.parsePayment3(g.self.id, payment,
              callback: () => afterPayment(payment));
          unselectHomeSelection(updateActivity: true);
          viewManager.popUntilHome();
          if (parsedPayment != null) setPage(paymentPage(payment));
        },
        back: back);
  }

  Down4PageWidget hyperchatPage(List<Palette> initPals, double initScroll) {
    viewManager.push(ViewState(id: "hyperchat", pages: []));

    return HyperchatPage(
      initialPalettes: initPals,
      initialOffset: initScroll,
      openPreview: openPreview,
      makeHyperchat: (media, text, members) async {
        setPage(loadingPage());
        final prompts = await randomPrompts(10);
        final hc = await r.getHyperchat(prompts);
        if (hc == null) {
          viewManager.popUntilHome();
          unselectHomeSelection(updateActivity: false);
          setPage(homePage());
          return;
        }

        final hcMedia = Down4Image(ComposedID(),
            metadata: Down4MediaMetadata(
                ownerID: g.self.id,
                mime: "image/png",
                timestamp: makeTimestamp(),
                width: 512,
                height: 512));

        await hcMedia.write(hc.first);

        final hyper = Hyperchat(ComposedID(),
            isConnected: true,
            firstWord: hc.second.first,
            secondWord: hc.second.second,
            activity: makeTimestamp(),
            members: members,
            mediaID: hcMedia.id,
            ownerID: g.self.id);

        final uploads = [hyper.remoteMerge(), hcMedia.staticUpload()];

        final success = Future.wait(uploads).then((u) => u.every((b) => b));

        if (!await success) {
          hcMedia.delete();
          viewManager.popUntilHome();
          return setPage(homePage(prompt: "Failed to upload Hyperchat"));
        } else {
          hyper
            ..cache()
            ..merge();
          hcMedia
            ..cache()
            ..merge();

          var chats = makeChats(media: media, text: text, targets: [hyper]);
          processChats(chats);
        }

        unselectHomeSelection();
        viewManager.popUntilHome();
        setPage(chatPage(hyper, isPush: true));
        return;
      },
      back: back,
      ping: (text) => print("Deprecated"),
    );
  }

  Down4PageWidget groupPage() {
    viewManager.push(ViewState(id: "group", pages: []));
    return GroupPage(
      initialOffset: homePageState.scroll,
      initialPalettes: chats.formatted(),
      back: back,
      makeGroup: (group, groupMedia, chat) async {
        setPage(loadingPage());

        final uploads = [group.remoteMerge(), groupMedia.staticUpload()];
        final success = Future.wait(uploads).then((u) => u.every((b) => b));

        if (await success) {
          group
            ..cache()
            ..merge();

          groupMedia
            ..cache()
            ..merge();

          processChats([chat]);

          unselectHomeSelection();
          viewManager.popUntilHome();
          setPage(chatPage(group, isPush: true));
        } else {
          group.remoteDelete();
          groupMedia.staticDelete();
          viewManager.popUntilHome();
          setPage(homePage(prompt: "Failed to create group"));
        }
      },
    );
  }

  Down4PageWidget searchPage({bool isPush = false}) {
    if (isPush) {
      viewManager.push(ViewState(id: "search", pages: [PageState()]));
    }

    void rf() => setPage(searchPage());
    Map<Down4ID, Palette> searchs() => currentView.currentPage.state.cast();

    return AddFriendPage(
        openPreview: openPreview,
        search: (strIDs) async {
          final ids = strIDs.split(" ").toSet();
          final locals = searchLocalsByUnique(ids);
          final localIDs = locals.map((e) => e.id.unik).toSet();
          final toFetch = ids.difference(localIDs);
          final futureNodes = r.getUsers(toFetch);
          for (final local in locals) {
            writePalette(local, searchs(), bGen2, rf, home: false);
          }
          rf();
          final fetchedNodes = (await futureNodes) ?? [];
          for (final node in fetchedNodes) {
            writePalette(node..cache(), searchs(), bGen2, rf, home: false);
          }
          rf();
        },
        onScan: (n) {
          writePalette(n, searchs(), bGen2, rf, home: false);
          rf();
        },
        openNode: (node) => setPage(nodePage(node, isPush: true)),
        add: (selectedPals) async {
          for (final n in selectedPals) {
            if (n is User) n.updateConnectionStatus(true);
            writePalette(n, searchs(), bGen2, rf, sel: false, home: false);
            writePalette(n, _chats, bGen, rfHome, home: true);
            (await global<Down4Image>(n.mediaID))?.downloadAndWriteIfNeeded();
          }
          rf();
          localPalettesRoutine();
        },
        forwardNodes: (pals) {
          forwardingObjects.addAll(pals);
          setPage(forwardPage(isPush: true));
        },
        back: back);
  }

  Down4PageWidget snipPage({
    CameraController? ctrl,
    int camera = 0,
    ResolutionPreset res = ResolutionPreset.high,
    bool reload = false,
  }) {
    viewManager.push(ViewState(id: "snip", pages: []));
    return SnipCamera(
      cameraCallBack: sendSnip,
      cameraBack: () {
        ctrl?.dispose();
        back();
      },
    );
  }

  Down4PageWidget nodePage(Down4Node n, {bool isPush = false}) {
    String pageID() => "node@${n.id.value}";
    if (isPush) {
      final r = List<String>.from(route);
      if (r.contains(pageID())) {
        // if this state is already in route, which is possible
        // we allow cycles, we just add the id to the route
        // but we don't create a new state, we reuse the same state
        viewManager.route.add(pageID());
      } else {
        // TODO, there will be more possible viewStates for nodePage no doubt
        final ps = PageState();
        viewManager.push(ViewState(id: pageID(), pages: [ps]));
      }
    }

    return NodePage(
        id: pageID(),
        openPreview: openPreview,
        openChat: (p_) => setPage(chatPage(p_, isPush: true)),
        openNode: (p_) => setPage(nodePage(p_, isPush: true)),
        payNode: (p_) => setPage(moneyPage(single: p_, isPush: true)),
        forward: () => setPage(forwardPage(isPush: true)),
        back: back);
  }

  Down4PageWidget chatPage(ChatN c,
      {bool isPush = false,
      bool isReload = false,
      bool rewriteMsgWithNodes = false,
      Chat? msgRe,
      Chat? reactingTo}) {
    String chatID() => "chat@${c.id.value}";
    ViewState chat() => viewManager.at(chatID());

    List<Down4ID> orderedMsgsIDs() => chat().orderedChats ?? [];
    Map<Down4ID, ChatMessage> messages() => chat().pages[0].state.cast();
    Map<Down4ID, Palette> members() => chat().pages[1].state.cast();
    Set<Down4ID> msgsWithVideos() => chat().refs("messages_with_videos");
    Set<Down4ID> msgsWithNodes() => chat().refs("messages_with_nodes");

    bool forwarding() => viewManager.route.contains("forward");

    void opn(Down4Node n_) => setPage(nodePage(n_, isPush: true));
    void Function(Down4Node)? openNode() => forwarding() ? null : opn;
    List<ButtonsInfo2> Function(ChatN)? cbGen = forwarding() ? null : bGen2;

    void refreshChat({bool stopVid = false}) async {
      final pg = page;
      if (pg is! ChatPage || pg.nodeID != c.id) return;
      if (stopVid) {
        for (final v in msgsWithVideos()) {
          messages()[v] = messages()[v]!.onPageTransition();
        }
      }
      setPage(chatPage(c));
    }

    void writeGroupNodesIfGroup() {
      final Down4Node ref = c;
      if (ref is GroupN) {
        final gIDs = ref.members;
        final mems = _chats.those(gIDs).noNull().palettes();
        for (final n in mems.asNodes<PersonN>()) {
          writePalette(n, members(), cbGen, refreshChat, home: false);
        }
      }
    }

    void rf() => setPage(chatPage(c));

    Future<void> increment(Chat cht, Down4ID reactionID) async {
      final reactors = cht.reactions[reactionID]?.reactors;
      if (reactors == null) return;
      final curLen_ = reactors.length;
      reactors.add(g.self.id);
      if (reactors.length > curLen_) {
        final rinc = ReactionIncrement(
            senderID: g.self.id, messageID: cht.id, reactionID: reactionID);
        r.push(c.messageTargets, rinc);
        reloadChatWithID(c.id, msgRe: cht);
      }
    }

    void reactToMsg(Chat msg) => setPage(chatPage(c, reactingTo: msg));

    Future<void> loadMore([int i = 20]) async {
      await writeMessages(
          limit: i,
          ch: c,
          ordered: orderedMsgsIDs(),
          state: messages(),
          react: reactToMsg,
          increment: increment,
          withNodes: msgsWithNodes(),
          videos: msgsWithVideos(),
          refresh: refreshChat,
          openNode: openNode());
      refreshChat();
    }

    void reloadChat() {
      Future(() async {
        final pg = page;
        if (pg is! ChatPage || pg.nodeID != c.id) return;
        final loaded = messages().keys.toList()
          ..sort((a, b) => b.unik.compareTo(a.unik));

        List<Down4ID> toLoad = [];
        for (final id in orderedMsgsIDs()) {
          if (loaded.isEmpty) {
            toLoad.add(id);
            break;
          } else if (id == loaded.last) {
            break;
          } else if (!loaded.contains(id)) {
            toLoad.add(id);
          }
        }
        await writeMessages(
            limit: toLoad.length,
            ch: c,
            react: reactToMsg,
            increment: increment,
            ordered: orderedMsgsIDs(),
            videos: msgsWithVideos(),
            withNodes: msgsWithNodes(),
            state: messages(),
            refresh: refreshChat,
            openNode: openNode());
      }).then((_) => refreshChat());
    }

    void initChat() {
      Future(() async {
        chat().orderedChats = c.fullChatIDs().toList();
        writeGroupNodesIfGroup();
        await writeMessages(
          limit: 20,
          ordered: orderedMsgsIDs(),
          ch: c,
          increment: increment,
          state: messages(),
          videos: msgsWithVideos(),
          withNodes: msgsWithNodes(),
          refresh: refreshChat,
          openNode: openNode(),
          react: reactToMsg,
        );
        refreshChat();
      });
    }

    if (isPush) {
      final wasAlreadyOnRoute = route.contains(chatID());
      if (wasAlreadyOnRoute) {
        viewManager.route.add(chatID());
        reloadChat();
      } else {
        final ps1 = PageState();
        final ps2 = PageState();
        viewManager.push(ViewState(id: chatID(), pages: [ps1, ps2]));
        initChat();
      }
    }

    if (msgRe != null) {
      final ref = messages()[msgRe.id] as ChatMessage;
      messages()[msgRe.id] = ref.reloaded(msgRe);
    }

    if (isReload) reloadChat();

    if (rewriteMsgWithNodes) {
      for (final id in msgsWithNodes()) {
        final ref = messages()[id] as ChatMessage;
        messages()[id] = ref.withOpenNode(open: openNode());
      }
      writeGroupNodesIfGroup();
      refreshChat();
    }

    return ChatPage(
      id: chatID(),
      openPreview: openPreview,
      viewState: viewManager.at(chatID()),
      forward: () => setPage(forwardPage(isPush: true)),
      onPageChange: (ix) {
        refreshChat(stopVid: true);
        chat().currentIndex = ix;
      },
      loadMore: loadMore,
      reactingTo: reactingTo,
      react: (ComposedID mediaID, Chat msg) {
        final rct = Reaction(Down4ID(),
            senderID: g.self.id,
            mediaID: mediaID,
            messageID: msg.id,
            reactors: {g.self.id});
        msg.addReaction(rct);
        reloadChatWithID(c.id, msgRe: msg);
        r.push(c.messageTargets, rct);
      },
      openNode: opn,
      send: (chats) {
        final wasForwarding = viewManager.route.contains("forward");
        final curChats = viewManager.currentView.orderedChats!;
        final chats_ = chats;
        final or = chats_.map((c) => c.id).followedBy(curChats).toList();
        viewManager.currentView.orderedChats = or;
        // poping the forwarding page
        if (wasForwarding) viewManager.popInBetween();
        setPage(
            chatPage(c, isReload: true, rewriteMsgWithNodes: wasForwarding));
        processChats(chats);
      }, // TODO, will need future nodes
      back: back,
      add: () {
        final sel = members().values.selected();
        for (final n in sel.asNodes<PersonN>()) {
          if (n is User) n.updateConnectionStatus(true);
          writePalette(n, members(), bGen2, rf, sel: false, home: false);
          writePalette(n, _chats, bGen, rfHome, home: true);
        }
        rf();
        localPalettesRoutine();
      },
      money: () {
        final og = members().values.toList();
        return setPage(moneyPage(
            isPush: true,
            initPals: og.reversed.toList(),
            initScroll: chat().pages[1].scroll));
      },
      hyper: () {
        final og = members().values.toList().reversed.toList();
        final ogScroll = chat().pages[1].scroll;
        return setPage(hyperchatPage(og, ogScroll));
      },
    );
  }

  Down4PageWidget? mapPage({bool isPush = false}) {
    if (g.theme.mapStyle == null) {
      print("unavailable map style!");
      return null;
    }
    if (isPush) {
      viewManager.push(ViewState(id: "map", pages: []));
    }
    return MapPage(back: back);
  }

  void viewSnips2(ChatN node, [List<Down4ID>? l]) async {
    if (viewManager.route.last != "snipView") {
      viewManager.push(ViewState(id: "snipView", pages: []));
    }
    final unreadSnips = l ?? node.unreadSnipIDs().toList();

    void back_() {
      writePalette(node, _chats, bGen, rfHome, home: true);
      return back();
    }

    void next_() async {
      final sl = unreadSnips.sublist(1);
      if (sl.isEmpty) {
        return back_();
      } else {
        return viewSnips2(node, sl);
      }
    }

    if (unreadSnips.isEmpty) return back_();
    final snip = local<Snip>(unreadSnips.first);
    if (snip == null) return next_();

    setPage(SnipViewPage2(node: node, snip: snip, back: back_, next: next_));
  }

  @override
  Widget build(BuildContext context) {
    return page;
  }
}
