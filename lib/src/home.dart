import 'dart:async';

import 'package:camera/camera.dart';
import 'package:down4/src/pages/preview_page.dart';
import 'package:down4/src/themes.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

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

class _HomeState extends State<Home> {
  // page managers has a stack(list) of ids of the place we navigate to in the
  // app, and a special getter *path* that will filter out doubles, so we don't
  // render the same page twice. The pages are all kept in memory (see build
  // function) so the states of each are kept and popped easily.
  // We might want to force a page to refresh from _HomeState be calling the
  // refresh function *refresh(page)*. Popping *pop()* a page will refresh
  // the page on top of the stack automatically.
  // To go to a page, we push it *push(page)*

  Down4PageWidget page = const LoadingPage2();
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

  void back({List<Down4Object>? f}) async {
    if (page is HomePage) return print("Can't pop home");
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
  StreamSubscription? _messageListener, _forgroundMessageListener;

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
    final homeChats = PageState();
    final homeConns = PageState();
    g.vm.push(ViewState(id: "home", pages: [homeChats, homeConns]));
    loadSavedMediasListeners();
    localPalettesRoutine(init: true);
    processBackgroundMessages();
    clearAppCache();
    g.wallet.walletRoutine();
    g.wallet.printWalletInfo();
    connectToMessages2();
    processUnsentMessages();
    updateExchangeRate();
  }

  @override
  void dispose() {
    _messageListener?.cancel();
    _forgroundMessageListener?.cancel();
    for (final nConn in _nodeConnections.values) {
      nConn.cancel();
    }
    for (final l in _mediasListeners.values) {
      l.cancel();
    }
    super.dispose();
  }

  Future<void> localPalettesRoutine({bool init = false}) async {
    final allHomeNodes = (await loadHome()).followedBy([g.self]);
    final Iterable<GroupN> groups = allHomeNodes.whereType<GroupN>();
    final groupUserIDs = groups.map((e) => e.group).expand((id) => id).toSet();
    final Iterable<User> users = allHomeNodes.whereType<User>();

    final homeIDs = allHomeNodes.asIDs().toSet();
    await globall<Down4Media>(allHomeNodes.mediaIDs,
        doFetch: true, doMergeIfFetch: true);

    List<User> hiddenUsers = [];
    for (final u in users) {
      if (!u.isConnected && !await u.hasMessages()) hiddenUsers.add(u);
    }

    final hiddenIDs = hiddenUsers.asIDs().toSet();

    // we dump hidden users that are not in groups
    final shouldDump = hiddenIDs.difference(groupUserIDs);
    for (final dump in shouldDump) {
      gdb<Down4Node>().purgeDocumentById(dump.value);
    }

    for (final n in allHomeNodes) {
      await writePalette(n, _chats, bGen, rfHome, home: true);
    }

    if (init) setPage(homePage());

    // we fetch users in groups that are not in home
    final toFetch = groupUserIDs.difference(homeIDs);
    final fetchedNodes =
        await globall<Down4Node>(toFetch, doFetch: true, doMergeIfFetch: true);

    await globall<Down4Media>(fetchedNodes.mediaIDs,
        doFetch: true, doMergeIfFetch: true);
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

  void _handleDown4Message(Down4Message msg) async {
    if (msg is Messages) {
      // Chats and Snips implements Messages which have a special function
      // on receipts that returns the rootnode that needs to be update
      msg.onReceipt((rootNode) async {
        rootNode.updateActivity();
        await writePalette(rootNode, _chats, bGen, rfHome, home: true);
        if (page is HomePage) setPage(homePage());
      });
    } else if (msg is ReactionIncrement) {
      final reactor = msg.senderID;
      final targetMsg = await global<Chat>(msg.messageID);
      final reactions = targetMsg?.reactions;
      final reaction = reactions?.findWhere((r) => r.id == msg.reactionID);
      reaction?.reactors.add(reactor);
      if (reactions != null) {
        targetMsg?.mergeReactions();
        reloadChatWithID(msg.root, msgRe: targetMsg);
      }
    } else if (msg is Payment) {
      Down4Payment? payment = msg.payment ??
          await global<Down4Payment>(msg.paymentID,
              doFetch: true, doMergeIfFetch: true, tempID: msg.tempPaymentID);
      if (payment == null) return;
      await payment.merge();
      if (page is MoneyPage) return setPage(moneyPage(payUpdate: payment));
    } else if (msg is Reaction) {
      final cht = await global<Chat>(msg.messageID);
      if (cht == null) return;
      cht.addReaction(msg);
      reloadChatWithID(msg.root, msgRe: cht);
    } else {
      throw "connectToMessage has no implemented this type: ${msg.runtimeType}";
    }
  }

  void processBackgroundMessages() async {
    final backgroundMessages = await getBackgroundMessages();
    for (final msg in backgroundMessages) {
      _handleDown4Message(msg);
    }
  }

  void connectToMessages2() {
    _forgroundMessageListener =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      showMessageNotification(message);
      if (message.data.isEmpty) return print("Message but not data!");
      final jsn = Map<String, String?>.from(message.data);
      final msg = Down4Message.fromJson(jsn);
      return _handleDown4Message(msg);
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
    final unsents = await unsentMessages();
    for (final u in unsents) {
      u.processMessage();
    }
  }

  // =========================== PAGES FUNCTIONS ======================== //

  Future<void> processChats(Iterable<Chat> chats) async {
    viewManager.forwardingObjects.clear();
    await Future.wait(chats.map((c) => c.processMessage(onSent: () {
          reloadChatWithID(c.root, msgRe: c);
        })));
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

    final media = Down4Media.fromLocal(ComposedID(),
        mainCachedPath: path,
        metadata: Down4MediaMetadata(
            isSquared: false,
            ownerID: g.self.id,
            mime: mimetype,
            timestamp: timestamp,
            isReversed: isReversed,
            text: text,
            width: size.width,
            height: size.height));

    for (final sel in chats.selected().asNodes<ChatN>()) {
      final snip = Snip(ComposedID(),
          senderID: g.self.id, text: text, root: sel.id, mediaID: media.id)
        ..processMessage();
      if (sel.id == g.self.id) {
        snip
          ..cache()
          ..merge();
        media
          ..cache()
          ..merge()
          ..writeFromCachedPath();
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
            (p.node as Down4Node).delete();
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
          .map((m) => m.message.forwarded(g.self.id, ComposedID()));
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

        final targets = (await globall<PersonN>(receivers, doFetch: true)).map(
            (e) => MessageTarget(
                userID: e.id,
                device: e.mainDeviceID,
                token: e.messagingTokens[e.mainDeviceID]!));

        Payment(
                senderID: g.self.id,
                paymentID: pay.id,
                payment: payment,
                targets: targets.toList())
            .processMessage();

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
    Map<Down4ID, Palette> peopleState() => currentView.pages[0].state.cast();
    Map<Down4ID, Palette> paymentState() => currentView.pages[1].state.cast();
    void rf() => setPage(moneyPage());
    void openPay(Down4Payment payment) => setPage(paymentPage(payment));
    List<ButtonsInfo2> payBGen(Down4Payment p) {
      if (p.isSpentBy(id: g.self.id)) {
        return [ButtonsInfo2(asset: g.fifty, pressFunc: () => openPay(p))];
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

        final hcMedia = Down4Media.fromLocal(ComposedID(),
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

          final chat = Chat(Down4ID(),
              senderID: g.self.id,
              root: hyper.id,
              text: text,
              mediaID: media?.id,
              timestamp: makeTimestamp(),
              messages: forwardingObjects.chatMsgs().asIDs().toSet(),
              nodes: forwardingObjects.palettes().asComposedIDs().toSet())
            ..cache()
            ..merge();

          processChats([chat]);
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

        // we don't allow cycles
        // while (route.last != id) {
        //   final v = viewManager.pop();
        //   final l = r.removeLast();
        //   print("ROUTE = $route");
        //   print("POPPED VIEW ${v?.id}");
        //   print("POPPED $l");
        // }
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
      final reaction = cht.reactions.findWhere((r) => r.id == reactionID);
      if (reaction == null) return;
      if (reaction.reactors.contains(g.self.id)) return;
      reaction.reactors.add(g.self.id);
      cht.mergeReactions();
      ReactionIncrement(Down4ID(),
              root: c.id,
              messageID: cht.id,
              reactionID: reaction.id,
              senderID: g.self.id)
          .processMessage();
      reloadChatWithID(c.id, msgRe: cht);
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
      react: (ComposedID mediaID, Chat msg) {
        final r = Reaction(Down4ID(),
            senderID: g.self.id,
            root: c.id,
            mediaID: mediaID,
            messageID: msg.id,
            reactors: {g.self.id})
          ..processMessage();
        msg.addReaction(r);
        reloadChatWithID(c.id, msgRe: msg);
      },
      openNode: opn,
      send: (chat) {
        processChats([chat]);
        // poping the forwarding page
        if (forwarding()) viewManager.popInBetween();
        setPage(
          chatPage(c, isReload: true, rewriteMsgWithNodes: chat.hadForwards),
        );
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
