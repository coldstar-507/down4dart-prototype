import 'dart:async';

import 'package:camera/camera.dart';
import 'package:down4/main.dart';
import 'package:down4/src/pages/preview_page.dart';
import 'package:down4/src/themes.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

// import 'package:push/push.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

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
  // page managers has a stack(list) of ids of the place we navigate to in the
  // app, and a special getter *path* that will filter out doubles, so we don't
  // render the same page twice. The pages are all kept in memory (see build
  // function) so the states of each are kept and popped easily.
  // We might want to force a page to refresh from _HomeState be calling the
  // refresh function *refresh(page)*. Popping *pop()* a page will refresh
  // the page on top of the stack automatically.
  // To go to a page, we push it *push(page)*

  late Down4PageWidget page = g.initLoadingScreen!;
  ViewManager get viewManager => g.vm;

  Set<Down4Object> get forwardingObjects => viewManager.forwardingObjects;
  Iterable<String> get route => viewManager.route;
  ViewState get homeView => viewManager.home;
  PageState get homePageState => homeView.currentPage;
  ViewState get currentView => viewManager.currentView;

  // homestate getters
  Map<Down4ID, Palette> get _chats => homeView.pages[0].state.cast();
  Map<Down4ID, Palette> get _otherConns => homeView.pages[1].state.cast();

  Iterable<Palette> get chats => _chats.values.cast()..showing();
  Iterable<ConnectN> get homeConnection =>
      _chats.values.asNodes<ConnectN>().where((n) => n.isConnected);

  List<Palette> get formattedHome => chats.toList().formatted();
  Map<Down4ID, ChatMessage>? chatMessages(ComposedID nodeID) {
    return viewManager.views["chat-${nodeID.value}"]?.pages[0].state.cast();
  }

  void setPage(Down4PageWidget p) {
    page = p;
    setState(() {});
  }

  void back() async {
    if (page is HomePage) {
      return print("closing app");
    }
    final (ViewState poppedView, bool wasPopped) = viewManager.pop();
    final pID = poppedView.id.split('-');
    final pp0 = pID.first;
    final n = poppedView.node;
    if (pID.length > 1 && pp0 == "chat" && n is ChatN && wasPopped) {
      poppedView.chat?.second.cancel();
      await writePalette(n, _chats, bGen, rfHome, home: true);
    }
    final id = currentView.id.split('-');
    final p0 = id.first;
    switch (p0) {
      case 'home':
        return setPage(homePage());
      case 'chat':
        final node = currentView.node as ChatN;
        return setPage(chatPage(node, isReload: true));
      case 'node':
        final node = currentView.node as Down4Node;
        return setPage(nodePage(node));
      case 'money':
        return setPage(moneyPage());
      case 'search':
        return setPage(searchPage());
      case 'forward':
        return setPage(await forwardPage());
    }
  }

  void openPreview() async => setPage(await previewPage(isPush: true));

  final Map<MediaType, StreamSubscription> _mediasListeners = {};
  StreamSubscription? _forgroundMessageListener, _notificationListener;

  final Map<ComposedID, StreamSubscription> _nodeConnections = {};

  void homeScrollToZero() => homePageState.scroll = 0;

  // ========================= INITIALIZATION ============================ //

  void connectToNotifications() async {
    
    // _notificationListener = FirebaseMessaging.onMessage.listen((remoteMsg) {
    // _notificationListener = Push.instance.onMessage.listen((remoteMsg) {
    //   print("\n\nRECEIVED A FUCKING MESSAGE BRO\n\n");

    //   final ComposedID? currentRoot =
    //       viewManager.currentView.node?.id as ComposedID?;

    //   print("\n\nshowing notification from connectToNotifications\n\n");
    //   // showNotification(remoteMsg);
    //   // showMessageNotification(remoteMsg, currentRoot: currentRoot);
    // });
  }

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

  void loadSavedMediasListeners() async {
    for (final m in MediaType.values) {
      final idStream = await savedMediaIDs(m);
      _mediasListeners[m] = idStream.listen((event) async {
        final ar = await event.results.allResults();
        final ids = ar.map((e) => Down4ID.fromString(e.string("id"))!).toList();
        g.savedMediasIDs[m] = ids;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final homeChats = PageState();
    final homeConns = PageState();
    g.vm.push(ViewState(id: "home", pages: [homeChats, homeConns]));
    loadSavedMediasListeners();
    localPalettesRoutine(init: true);
    clearAppCache();
    g.wallet.walletRoutine();
    g.wallet.printWalletInfo();
    connectToNotifications();
    connectToMessages3();
    processUnsentMessages();
    updateExchangeRate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    for (final l in _mediasListeners.values) {
      l.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> localPalettesRoutine({bool init = false}) async {
    print("\n===LOCAL PALETTE ROUTINE===\n");
    final allHomeNodes = (await loadHome()).followedBy([g.self]);
    final Iterable<GroupN> groups = allHomeNodes.whereType<GroupN>();
    final groupUserIDs = groups.map((e) => e.group).expand((id) => id).toSet();
    final Iterable<User> users = allHomeNodes.whereType<User>();

    final homeIDs = allHomeNodes.asIDs().toSet();
    final homeNodesMediaIDs =
        allHomeNodes.map((e) => e.mediaID).whereType<ComposedID>();

    // caches home node medias from local
    await globall<Down4Media>(homeNodesMediaIDs);

    List<User> hiddenUsers = [];
    for (final u in users) {
      if (!u.isConnected && !await u.hasMessages()) hiddenUsers.add(u);
    }

    final hiddenIDs = hiddenUsers.asIDs().toSet();

    // we dump hidden users that are not in groups
    final shouldDump = hiddenIDs.difference(groupUserIDs);
    print("TO DUMP: ${shouldDump.map((id) => id.unique)}");
    for (final dump in shouldDump) {
      gdb<Down4Node>().purgeDocumentById(dump.value);
      unCache(dump);
    }

    for (final n in allHomeNodes) {
      await writePalette(n, _chats, bGen, rfHome, home: true);
    }

    if (init) {
      setPage(homePage());
      g.initLoadingScreen = null;
    }

    // we fetch users in groups that are not in home
    final toFetch = groupUserIDs.difference(homeIDs);
    final fetchedNodes =
        await globall<PersonN>(toFetch, doFetch: true, doMergeIfFetch: true);
    print("TO FETCH: ${toFetch.map((id) => id.unique)}");

    final nodeMediasToFetch =
        fetchedNodes.map((n) => n.mediaID).whereType<ComposedID>();

    // we do homeNodesMedias aswell because it's possible we have nodes
    // but not the medias (in case of a offline add for example)
    await globall<Down4Media>(nodeMediasToFetch.followedBy(homeNodesMediaIDs),
        doFetch: true, doMergeIfFetch: true);

    for (final n in fetchedNodes) {
      await writePalette(n, _chats, bGen, rfHome, home: true);
    }
  }

  Future<List<ButtonsInfo2>> bGen(ChatN n) async {
    final snips = await n.unreadSnipIDs();
    if (snips.isNotEmpty) {
      return [
        ButtonsInfo2(
          asset: Icon(Icons.arrow_forward_ios_rounded,
              color: g.theme.snipArrowColor), //  g.red,
          pressFunc: () async => setPage(await snipView(n)),
          longPressFunc: () => n is PersonN ? setPage(nodePage(n)) : null,
          rightMost: true,
        )
      ];
    } else {
      final hasUnread = await n.lastChatFromOtherIsUnread();
      return [
        ButtonsInfo2(
            asset: Icon(Icons.arrow_forward_ios_rounded,
                color: !hasUnread
                    ? g.theme.noMessageArrowColor
                    : g.theme.messageArrowColor),
            pressFunc: () => setPage(chatPage(n, isPush: true)),
            longPressFunc: () =>
                n is PersonN ? setPage(nodePage(n, isPush: true)) : null,
            rightMost: true)
      ];
    }
  }

  Future<List<ButtonsInfo2>> bGen2(Down4Node n) async {
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
            await msgMedia?.updateTempReferences(
                msg.tempMediaID!, msg.tempMediaTS!);
          }

          // if there are users in the group that aren't in home,
          // localPaletteRoutine will take care of it
          final homeKeys = _chats.keys.toList();
          if (rootgt == GetType.fetch &&
              rootNode is GroupN &&
              !rootNode.group.every((uid) => homeKeys.contains(uid))) {
            localPalettesRoutine();
          }

          await msg.merge();

          rootNode.updateActivity();
          await writePalette(rootNode, _chats, bGen, rfHome, home: true);
          if (page is HomePage) setPage(homePage());
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
          final paymentID = ComposedID.fromString(vals[1])!;
          final tempPaymentID = ComposedID.fromString(vals[2])!;
          final payment = await global<Down4Payment>(paymentID,
              doFetch: true, doMergeIfFetch: true, tempID: tempPaymentID);
          if (payment == null) return print("no payment for download");
          await g.wallet.parsePayment(g.self.id, payment);
          if (page is MoneyPage) setPage(moneyPage(payUpdate: payment));
          break;
      }
    });
  }

  void rewriteHomePalettes() {
    for (final p in chats) {
      writePalette(p.node as ChatN, _chats, bGen, rfHome, home: true);
    }
  }

  // =============================== UTILS ============================== //

  void reloadChatWithID(Down4ID chatableNodeID, {Chat? msgRe}) {
    if (currentView.id == "chat-${chatableNodeID.unique}") {
      setPage(chatPage(currentView.node as ChatN, msgRe: msgRe));
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

  Future<void> unselectHomeSelection({bool updateActivity = true}) async {
    for (final p in List.of(chats)) {
      if (p.selected) {
        await writePalette(p.node as ChatN, _chats, bGen, rfHome,
            sel: false, home: true);
      }
    }
    return;
  }

  List<Palette> forwardables(List<Palette> ps) {
    final idsInGroups = ps
        .asNodes<GroupN>()
        .map((e) => e.group)
        .expand((element) => element)
        .toSet();

    final forwardables = ps.whereNodeIs<BranchN>().asIDs();

    final all = forwardables.followedBy(idsInGroups).toSet();

    return all.map((id) => _chats[id]).whereType<Palette>().toList();
  }

  Future<void> processUnsentMessages() async {
    processChats(await unsentMessages());
  }

  // =========================== PAGES FUNCTIONS ======================== //

  Future<void> processChats(Iterable<Chat> chats) async {
    // these chats passed in parameter can also be forwarded chats
    for (final c in chats) {
      final rtID = idOfRoot(root: c.root);
      final rt = await global<ChatN>(rtID);
      if (rt == null) return;
      final targets = await rt.messageTargets;
      print("sending messages to ${targets.map((t) => t.id.unique)}");
      final success = await r.push(await rt.messageTargets, c);
      rt.updateActivity();
      await writePalette(rt, _chats, bGen, rfHome, home: true);
      if (success) c.markSent();
      reloadChatWithID(rtID, msgRe: c);
      if (page is HomePage) setPage(homePage());
    }
  }

  Future<void> sendSnip({
    required String path,
    required String mimetype,
    required bool isReversed,
    required Size size,
    String? text,
  }) async {
    // image from camera are cached files, so they are
    // automatically deleted on boot

    final timestamp = makeTimestamp();
    setPage(loadingPage());

    final selection = chats.selected().asNodes<ChatN>();

    final media = (await Down4Media.fromLocal2(ComposedID(),
        mainCachedPath: path,
        writeFromCachedPath: selection.contains(g.self),
        metadata: Down4MediaMetadata(
            isSquared: false,
            ownerID: g.self.id,
            mime: mimetype,
            timestamp: timestamp,
            isReversed: isReversed,
            text: text,
            width: size.width,
            height: size.height)))
      ..cache();

    for (final sel in chats.selected().asNodes<ChatN>()) {
      final snip = Snip(ComposedID(),
          root: sel.root_, senderID: g.self.id, text: text, mediaID: media.id);

      await r.push(await sel.messageTargets, snip);

      if (sel.id == g.self.id) {
        snip
          ..cache()
          ..merge();
        // media
        //   ..cache()
        //   ..merge()
        //   ..writeFromCachedPath();
      }
    }

    await unselectHomeSelection();
    viewManager.popUntilHome();
    setPage(homePage(prompt: "SNIPED"));
  }

  // ============================== PAGES ============================== //

  Down4PageWidget homePage({String? prompt}) {
    return HomePage(
      openPreview: openPreview,
      forward: () async => setPage(await forwardPage(isPush: true)),
      openChat: (n, f) => setPage(chatPage(n, isPush: true)),
      send: (chats) async {
        processChats(chats);
        await unselectHomeSelection(updateActivity: true);
        setPage(homePage());
      },
      add: () async {
        final selectedPals = chats.selected().asNodes<PersonN>();
        for (final n in selectedPals) {
          if (n is User) await n.updateConnectionStatus(true);
          await writePalette(n, _chats, bGen2, rfHome, sel: false, home: true);
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
        for (final p in List<Palette>.from(chats)) {
          if (p.selected && p.id != g.self.id) {
            _chats.remove(p.node.id);
            await (p.node as ChatN).delete();
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
      g.vm.mode = Modes.def;
      viewManager.push(ViewState(id: "preview", pages: [PageState()]));

      for (final n in fo().palettes().map((p) => p.node)) {
        await writePalette(n, s(), null, rf, home: false);
      }

      final fs = fo()
          .chatMsgs()
          .map((m) => m.message.forwarded(g.self.id, Down4ID().unique));
      for (final m in fs) {
        await writePost(
            msg: m, refreshCallback: rf, state: s(), openNode: null);
      }
    }

    return PreviewPage(back: () {
      final wasForwarding = g.vm.route.contains("forward");
      g.vm.mode = wasForwarding ? Modes.forward : Modes.append;
      back();
    });
  }

  Future<Down4PageWidget> forwardPage({bool isPush = false}) async {
    PageState _fPage() => currentView.currentPage;
    Map<Down4ID, Palette> _fState() => _fPage().state.cast();
    List<Palette> _fs() => _fState().values.toList();

    void rf() async => setPage(await forwardPage());
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
        await writePalette<ChatN>(c, _fState(), fbGen, rf, home: false);
      }
    }

    return ForwardingPage(
        openPreview: openPreview,
        hyper: () => setPage(hyperchatPage(_fs(), _fPage().scroll)),
        forward: (chats) async {
          processChats(chats);
          await unselectHomeSelection(updateActivity: true);
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

        final ppl = await globall<PersonN>(receivers, doFetch: true); //).map(
        final payment = Payment(senderID: g.self.id, paymentID: pay.id);

        // TODO this returns success, and should perhaps have something happen
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
      void swapTheme() async {
        g.myTheme.changeTheme(t.displayName);
        for (final t in paletteThemes().asNodes<NodeTheme>()) {
          await writePalette<NodeTheme>(t, themes(), tGen, refresh,
              home: false);
        }
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: g.theme.topStatusIconBrightness,
          systemNavigationBarColor: g.theme.bottomNavigationBarColor,
          systemNavigationBarIconBrightness:
              g.theme.bottonNavigationIconBrightness,
        ));

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

    return ThemePage(
      themes: themes(),
      onSwap: rewriteHomePalettes,
      back: back,
    );
  }

  Down4PageWidget moneyPage({
    bool isPush = false,
    bool isReload = false,
    List<Palette>? initPals,
    double? initScroll,
    PersonN? single,
    Down4Payment? payUpdate,
  }) {
    // Map<Down4ID, Palette> peopleState() => currentView.pages[0].state.cast();
    Map<Down4ID, Palette> paymentState() => currentView.pages[1].state.cast();
    void rf() => setPage(moneyPage());
    void openPay(Down4Payment payment) => setPage(paymentPage(payment));
    List<ButtonsInfo2> payBGen(Down4Payment p) {
      if (p.isSpentBy(id: g.self.id)) {
        return [
          ButtonsInfo2(
              asset: Icon(Icons.arrow_forward_ios_rounded,
                  color: g.theme.noMessageArrowColor),
              pressFunc: () => openPay(p))
        ];
      } else {
        return [];
      }
    }

    void scanOrReceivePayment(Down4Payment pay) {
      // this will put the payment at the begining of the list
      final p = PaymentNode(payment: pay, selfID: g.self.id);
      currentView.pages[1].state = {
        pay.id: Palette(
            node: p,
            key: Key(p.id.unique),
            messagePreview: pay.textNote,
            buttonsInfo2: payBGen(pay)),
        ...paymentState(),
      };
      rf();
    }

    void loadSomePayments(int limit, [int ms = 0]) =>
        Future.delayed(Duration(milliseconds: ms), () async {
          await writePayments(paymentState(), openPay, limit);
          rf();
        });

    if (isPush) {
      final ppl = PageState();
      final pay = PageState();
      viewManager.push(ViewState(id: "money", pages: [ppl, pay]));
      loadSomePayments(5, 633);
    }

    if (payUpdate != null) scanOrReceivePayment(payUpdate);

    return MoneyPage(
        single: single,
        initPalettes: initPals,
        initScroll: initScroll,
        viewState: currentView,
        loadMorePayments: () async => loadSomePayments(20),
        onScan: (payment) async {
          await g.wallet.parsePayment(g.self.id, payment);
          scanOrReceivePayment(payment);
        },
        makePayment: (payment) async {
          await g.wallet.parsePayment(g.self.id, payment);
          unselectHomeSelection(updateActivity: true);
          viewManager.popUntilHome();
          setPage(paymentPage(payment));
        },
        back: back);
  }

  Down4PageWidget hyperchatPage(List<Palette> initPals, double initScroll) {
    viewManager.push(ViewState(id: "hyperchat", pages: []));

    return HyperchatPage(
      initialPalettes: initPals,
      initialOffset: initScroll,
      openPreview: openPreview,
      makeHyperchat: (media, text, group) async {
        setPage(loadingPage());
        final prompts = await randomPrompts(10);
        final hc = await r.getHyperchat(prompts);
        if (hc == null) {
          viewManager.popUntilHome();
          await unselectHomeSelection(updateActivity: false);
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
            group: group,
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

          var chats = <Chat>[];

          final fmsgs = forwardingObjects
              .chatMsgs()
              .toList()
              .reversed
              .map((cm) => cm.message)
              .map((fm) => fm.forwarded(g.self.id, hyper.root_)
                ..cache()
                ..merge());

          chats.addAll(fmsgs);

          if (media != null || (text ?? "").isNotEmpty) {
            final chat = Chat(ComposedID(),
                senderID: g.self.id,
                root: hyper.root_,
                text: text,
                mediaID: media?.id,
                timestamp: makeTimestamp(),
                nodes: forwardingObjects.palettes().asComposedIDs().toSet())
              ..cache()
              ..merge();

            chats.add(chat);
          }

          g.vm.mode = Modes.def;
          g.vm.forwardingObjects.clear();
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

          await unselectHomeSelection();
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
          final locals = await searchLocalsByUnique(ids);
          final localIDs = locals.map((e) => e.id.unique).toSet();
          final toFetch = ids.difference(localIDs);
          final futureNodes = r.getUsers(toFetch);
          for (final local in locals) {
            await writePalette(local, searchs(), bGen2, rf, home: false);
          }
          final fetchedNodes = (await futureNodes) ?? [];
          for (final node in fetchedNodes) {
            await writePalette(node..cache(), searchs(), bGen2, rf,
                home: false);
          }
          rf();
        },
        onScan: (n) async {
          await writePalette(n, searchs(), bGen2, rf, home: false);
          rf();
        },
        openNode: (node) => setPage(nodePage(node, isPush: true)),
        add: (selectedPals) async {
          for (final n in selectedPals) {
            if (n is User) await n.updateConnectionStatus(true);
            await writePalette(n, searchs(), bGen2, rf,
                sel: false, home: false);
            writePalette(n, _chats, bGen, rfHome, home: true);
            (await global<Down4Image>(n.mediaID))?.downloadAndWriteIfNeeded();
          }
          rf();
          localPalettesRoutine();
        },
        forwardNodes: (pals) async {
          forwardingObjects.addAll(pals);
          setPage(await forwardPage(isPush: true));
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
    String pageID() => "node-${n.id.unique}";
    if (isPush) {
      final r = List<String>.from(route);
      if (r.contains(pageID())) {
        // if this state is already in route, which is possible
        // we allow cycles, we just add the id to the route
        // but we don't create a new state, we reuse the same sate
        viewManager.route.add(pageID());
      } else {
        // TODO, there will be more possible states for nodePage no doubt
        final ps = PageState();
        viewManager.push(ViewState(id: "node-${n.id}", pages: [ps], node: n));
      }
    }

    return NodePage(
        openPreview: openPreview,
        openChat: (p_) => setPage(chatPage(p_, isPush: true)),
        openNode: (p_) => setPage(nodePage(p_, isPush: true)),
        payNode: (p_) => setPage(moneyPage(single: p_, isPush: true)),
        forward: () async => setPage(await forwardPage(isPush: true)),
        back: back);
  }

  Down4PageWidget chatPage(
    ChatN c, {
    bool isPush = false,
    bool isReload = false,
    bool rewriteMsgWithNodes = false,
    Chat? msgRe,
    Chat? reactingTo,
  }) {
    String chatID() => "chat-${c.id.unique}";
    ViewState chat() => viewManager.at(chatID());

    List<Down4ID> orderedMsgsIDs() => chat().chat?.first ?? [];
    Map<Down4ID, ChatMessage> messages() => chat().pages[0].state.cast();
    Map<Down4ID, Palette> members() => chat().pages[1].state.cast();
    Set<Down4ID> msgsWithVideos() => chat().refs("messages_with_videos");
    Set<Down4ID> msgsWithNodes() => chat().refs("messages_with_nodes");

    bool forwarding() => viewManager.mode == Modes.forward;

    void opn(Down4Node n_) => setPage(nodePage(n_, isPush: true));
    void Function(Down4Node)? openNode() => forwarding() ? null : opn;
    FutureOr<List<ButtonsInfo2>> Function(ChatN)? cbGen =
        forwarding() ? null : bGen2;

    void refreshChat({bool stopVid = false}) async {
      final pg = page;
      if (pg is! ChatPage || pg.viewState.node!.id != c.id) return;
      if (stopVid) {
        for (final v in msgsWithVideos()) {
          messages()[v] = messages()[v]!.onPageTransition();
        }
      }
      setPage(chatPage(c));
    }

    void writeGroupNodesIfGroup() async {
      final Down4Node ref = c;
      if (ref is GroupN) {
        final gIDs = ref.group;
        final mems = _chats.those(gIDs).noNull().palettes();
        for (final n in mems.asNodes<PersonN>()) {
          await writePalette(n, members(), cbGen, refreshChat, home: false);
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
        // push the message;
        final rinc = ReactionIncrement(
            senderID: g.self.id, messageID: cht.id, reactionID: reactionID);
        r.push(await c.messageTargets, rinc);
        reloadChatWithID(c.id, msgRe: cht);
      }
    }

    Future<void> reactToMsg(Chat msg) async =>
        setPage(chatPage(c, reactingTo: msg));

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
        // is a reload, load all NEW messages, hence the break;
        final pg = page;
        if (pg is! ChatPage || pg.viewState.node?.id != c.id) return;
        final loaded = messages().keys.toList()
          ..sort((a, b) => b.unique.compareTo(a.unique));

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
        final theChat = await c.getTheChat();
        final currentMessages = theChat.first.toList();
        chat().chat = Pair(
          theChat.first.toList(),
          theChat.second.listen((event) async {
            final r = await event.results.allResults();
            chat().chat = Pair(
              r.map((e) => Down4ID.fromString(e.string("id"))!).toList(),
              chat().chat!.second,
            );
            reloadChat();
          }),
        );

        print("THE MESSAGES = ${theChat.first}");

        // if is group, write members
        writeGroupNodesIfGroup();
        // write the messages
        await writeMessages(
          limit: 20,
          ordered: currentMessages,
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
        viewManager.push(ViewState(id: chatID(), pages: [ps1, ps2], node: c));
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
      openPreview: openPreview,
      forward: () async => setPage(await forwardPage(isPush: true)),
      onPageChange: (ix) {
        refreshChat(stopVid: true);
        chat().currentIndex = ix;
      },
      loadMore: loadMore,
      reactingTo: reactingTo,
      react: (ComposedID mediaID, Chat msg) async {
        final rct = Reaction(Down4ID(),
            senderID: g.self.id,
            mediaID: mediaID,
            messageID: msg.id,
            reactors: {g.self.id});
        msg.addReaction(rct);
        reloadChatWithID(c.id, msgRe: msg);
        r.push(await c.messageTargets, rct);
      },
      openNode: opn,
      send: (chats) {
        final wasForwarding = viewManager.mode == Modes.forward;
        processChats(chats);
        // poping the forwarding page
        if (wasForwarding) viewManager.popInBetween();
        setPage(
            chatPage(c, isReload: true, rewriteMsgWithNodes: wasForwarding));
      }, // TODO, will need future nodes
      back: back,
      add: () async {
        final sel = members().values.selected();
        for (final n in sel.asNodes<PersonN>()) {
          if (n is User) await n.updateConnectionStatus(true);
          await writePalette(n, members(), bGen2, rf, sel: false, home: false);
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

  // this page doesn't work in theory, but it works in practice
  Future<Down4PageWidget> snipView(ChatN node, [List<Down4ID>? l]) async {
    // snip view can calls it self, so we do this for the universal back func
    if (viewManager.route.last != "snipView") {
      viewManager.push(ViewState(id: "snipView", pages: []));
    }

    final unreadSnips = l ?? (await node.unreadSnipIDs()).toList();
    VideoPlayerController? vpc;

    void back_() async {
      vpc?.dispose();
      await writePalette(node, _chats, bGen, rfHome, home: true);
      back();
    }

    void next_() async {
      vpc?.dispose();
      if (unreadSnips.sublist(1).isEmpty) {
        back_();
      } else {
        setPage(await snipView(node, unreadSnips.sublist(1)));
      }
    }

    print("Unread snips=$unreadSnips");
    if (unreadSnips.isEmpty) {
      await writePalette(node, _chats, bGen, rfHome, home: true);
      setPage(homePage());
    }
    final s = await global<Snip>(unreadSnips.first, doCache: false);
    await s!.markRead();

    final m = await global<Down4Media>(s.mediaID,
        doCache: false, doFetch: true, tempID: s.tempMediaID);
    if (m == null) return snipView(node);

    m.updateTempReferences(s.tempMediaID!, s.tempMediaTS!);

    if (m is Down4Video) {
      vpc = m.newReadyController() ?? await m.futureController();
      if (vpc == null) return snipView(node, unreadSnips.sublist(1));
      await vpc.initialize();
      await vpc.setLooping(true);
      await vpc.play();
    }

    final displayMedia = await m.displaySnip(context: context, controller: vpc);

    return SnipViewPage(
        displayMedia: displayMedia,
        text: m.metadata.text,
        back: back_,
        next: next_);
  }

  @override
  Widget build(BuildContext context) {
    print("CURRENT IMAGE CACHE SIZE = ${ImageCache().currentSize}");
    print("REBUILDING HOME");
    return page;
  }
}
