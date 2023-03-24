import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:down4/src/data_objects.dart';
import 'package:video_player/video_player.dart';

import 'globals.dart';
import 'web_requests.dart' as r;
import '_down4_dart_utils.dart';
import 'bsv/wallet.dart';
import 'bsv/types.dart';

import 'pages/chat_page.dart';
import 'pages/forwarding_page.dart';
import 'pages/group_page.dart';
import 'pages/home_page.dart';
import 'pages/hyperchat_page.dart';
import 'pages/init_page.dart';
import 'pages/loading_page.dart';
import 'pages/maker_page.dart';
import 'pages/money_page.dart';
import 'pages/node_page.dart';
import 'pages/search_page.dart';
import 'pages/welcome_page.dart';
import 'pages/camera_page.dart';
import 'pages/snipview_page.dart';

import 'render_objects/palette.dart';
import 'render_objects/chat_message.dart';
import 'render_objects/_down4_flutter_utils.dart' as ru;
import 'render_objects/console.dart';

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

  ru.Down4PageWidget page = const LoadingPage2();

  ViewManager get vm => g.vm;

  Iterable<String> get route => vm.views.map((e) => e.id);

  V get cv => vm.cv;

  void setPage(ru.Down4PageWidget p) {
    page = p;
    setState(() {});
  }

  void back({required bool withPop, List<Down4Object>? f}) async {
    V? popedView;
    if (withPop) popedView = vm.pop();
    final pID = popedView?.id.split('-');
    final pp0 = pID?.first;
    if (pID != null && pID.length > 1 && pp0 == "chat") {
      await writeHomePalette(popedView!.node!, _homePalettes, bGen, rfHome);
    }
    final id = cv.id.split('-');
    final p0 = id.first;
    switch (p0) {
      case 'home':
        return setPage(homePage());
      case 'chat':
        return setPage(chatPage(cv.node as Chatable, fo: f));
      case 'node':
        return setPage(nodePage(cv.node as FireNode));
      case 'money':
        return setPage(moneyPage());
      case 'search':
        return setPage(searchPage());
      case 'forward':
        return setPage(forwardPage(f ?? []));
    }
  }

  Transition homeTransition() {
    return selectionTransition(
      originalList: formattedHomePalettes,
      state: _homePalettes,
      hiddenState: _hiddenPalettes,
      scrollOffset: vm.home.pages[0].scroll,
    );
  }

  Map<ID, Palette2> get _homePalettes => vm.home.pages[0].objects.cast();
  Map<ID, Palette2> get _hiddenPalettes => vm.home.pages[1].objects.cast();
  Map<ID, Palette2> get _all => {..._homePalettes, ..._hiddenPalettes};

  FireNode? homeNode(ID id) => _homePalettes[id]?.node;
  FireNode? hiddenNode(ID id) => _hiddenPalettes[id]?.node;
  FireNode? localNode(ID id) => hiddenNode(id) ?? hiddenNode(id);

  Iterable<Palette2> get homePalettes => _homePalettes.values;
  Iterable<Palette2> get hiddenPalettes => _homePalettes.values;
  Iterable<Palette2> get allPalettes => homePalettes.followedBy(hiddenPalettes);
  Iterable<ID> get allIDs => allPalettes.map((p) => p.id);
  List<Palette2> get formattedHomePalettes =>
      homePalettes.toList().formattedReverse();

  StreamSubscription? _messageListener;

  double get homeScroll => vm.home.pages[0].scroll;

  void homeScrollToZero() => vm.home.pages[0].scroll = 0;

  var _tec = TextEditingController();

  // ======================================================= INITIALIZATION ============================================================ //

  void rfHome() => setPage(homePage());

  @override
  void initState() {
    super.initState();
    localPalettesRoutine(init: true);
    ru.clearAppCache();
    g.wallet.walletRoutine();
    g.wallet.printWalletInfo();
    connectToMessages();
    updateExchangeRate();
  }

  @override
  void dispose() {
    _messageListener?.cancel();
    super.dispose();
  }

  Future<void> localPalettesRoutine({bool init = false}) async {
    final homes = Set<ID>.from(g.boxes.nodes.keys.followedBy([g.self.id]));
    final hiddens = Set<ID>.from(g.boxes.hidden.keys);
    final shouldDump = hiddens.intersection(homes);
    final allLocal = homes.followedBy(hiddens).toSet();

    final nodes = await Future.wait(homes.map((e) => e.getLocalNode()));
    final groupNodes = nodes.whereType<Groupable>();
    final groupIds = groupNodes.map((e) => e.group).expand((id) => id).toSet();
    final calcHidden = groupIds.difference(homes);

    final stayHidden = hiddens.intersection(calcHidden);

    final hiddenToDump = hiddens.difference(stayHidden);
    final hiddenToFetch = calcHidden.difference(allLocal);

    for (final dump in hiddenToDump.followedBy(shouldDump)) {
      g.boxes.hidden.delete(dump);
    }

    for (final node in nodes.whereType<FireNode>().followedBy([g.self])) {
      await writeHomePalette(node, _homePalettes, bGen, rfHome);
    }

    if (init) setPage(homePage());

    final lHidden = await Future.wait(stayHidden.map((e) => e.getHiddenNode()));
    for (final n in lHidden.whereType<FireNode>()) {
      await writeHomePalette(n, _hiddenPalettes, null, null);
    }

    final fetched = await r.getNodes(hiddenToFetch);
    for (final n in fetched ?? <FireNode>[]) {
      n.save(hidden: true);
      await writeHomePalette(n, _hiddenPalettes, null, null);
    }

    print("HIDDEN = ${_hiddenPalettes.keys.toList()}");
    print("HOMES = ${_homePalettes.keys.toList()}");
  }

  Future<List<ButtonsInfo2>> bGen(FireNode node) async {
    if (node is! Chatable) return [];
    if (node.snips.isNotEmpty) {
      return [
        ButtonsInfo2(
            asset: g.red,
            pressFunc: () async => setPage(await snipView(node)),
            longPressFunc: () =>
                node is Personable ? setPage(nodePage(node)) : null,
            rightMost: true)
      ];
    } else {
      FireMessage? lastMsg = node.messages.isEmpty
          ? null
          : await node.messages.last.getLocalMessage();
      return [
        ButtonsInfo2(
            asset: lastMsg?.reads[node.id] ?? true ? g.fifty : g.black,
            pressFunc: () => setPage(chatPage(node, isPush: true)),
            longPressFunc: () => node is Personable
                ? setPage(nodePage(node, isPush: true))
                : null,
            rightMost: true)
      ];
    }
  }

  List<ButtonsInfo2> bGen2(FireNode node) {
    return [
      ButtonsInfo2(
          asset: g.fifty,
          pressFunc: () => setPage(nodePage(node, isPush: true)),
          rightMost: true)
    ];
  }

  void connectToMessages() {
    var msgQueue = db.child("Users").child(g.self.id).child("M");
    var messagesRef = db.child("Messages");

    Future<void> handleMessage(FireMessage msg, ID root) async {
      Chatable? rootNode = homeNode(root) as Chatable?;
      if (rootNode == null) {
        // need to download it
        final singleNodeList = await r.getNodes([root]);
        if (singleNodeList == null || singleNodeList.length != 1) return;
        rootNode = singleNodeList.first as Chatable;
        rootNode.updateActivity();
        if (rootNode is Groupable) {
          await rootNode.save();
          await localPalettesRoutine();
        }
      }

      await msg.onReceipt(root: root);

      rootNode.messages.add(msg.id);
      rootNode.updateActivity();
      await rootNode.save();

      await writeHomePalette(rootNode, _homePalettes, bGen, rfHome);

      final pg = page;
      if (pg is HomePage) {
        setPage(homePage());
      } else if (pg is ChatPage && pg.node.id == root) {
        setPage(chatPage(rootNode, isReload: true, fo: pg.fo));
      }
    }

    _messageListener = msgQueue.onChildAdded.listen((event) async {
      print("New message!");
      final eventKey = event.snapshot.key;
      final eventPayload = (event.snapshot.value as String).split("%");
      msgQueue.child(eventKey!).remove(); // consume it
      print("KEY = $eventKey\nPAYLOAD = $eventPayload\n");

      if (eventPayload.first == "h") {
        // "h-${msg.id}-$hcID-${hyper.media.id}-${hyper.firstWord}-${hyper.secondWord}-${hyper.group.join(" ")}";
        // HYPERCHAT
        final msgID = eventPayload[1];
        final hcID = eventPayload[2];
        final mediaID = eventPayload[3];
        final firstWord = eventPayload[4];
        final secondWord = eventPayload[5];
        final members = eventPayload[6].split(" ");

        final hcMedia = downloadMessageMediaAsNodeMedia(mediaID);
        final msg = downloadMessage(msgID);

        Future.wait([hcMedia, msg]).then((value) async {
          if (value.first == null) return;
          await (value[1] as FireMessage?)?.onReceipt(root: hcID);
          final hyperchat = Hyperchat(
              id: hcID,
              firstWord: firstWord,
              secondWord: secondWord,
              group: members.toSet(),
              messages: {msgID},
              snips: {},
              media: value.first as FireMedia)
            ..save();

          await writeHomePalette(hyperchat, _homePalettes, bGen, rfHome);
          await localPalettesRoutine();
          setPage(homePage());
        });
      } else if (eventPayload.first == "p") {
        // PAYMENT!
        final paymentID = eventPayload[1];
        final payment = await downloadPayment(paymentID);
        if (payment == null) return;
        await g.wallet.parsePayment(g.self.id, payment);
        if (page is MoneyPage) setPage(moneyPage(paymentUpdate: payment));
        return;
      } else if (eventPayload.first == "m") {
        // MESSAGE!
        final msgID = eventPayload[1];
        final root = eventPayload[2];
        final msg = await downloadMessage(msgID);
        if (msg == null) return;
        return await handleMessage(msg, root);
      } else if (eventPayload.first == "s") {
        final String mediaID = eventPayload[1];
        final String root = eventPayload[2];

        Chatable? nodeRoot;
        nodeRoot = homeNode(root) as Chatable?;
        if (nodeRoot == null) {
          // nodeRoot is not in home, need to download it
          final newRootNodes = await r.getNodes([root]);
          if (newRootNodes == null || newRootNodes.length != 1) return;
          nodeRoot = newRootNodes.first as Chatable;
        }

        Future<void> getOrUpdateMedia(String refID) async {
          (await mediaID.getLocalMessageMedia() ??
              await downloadAndWriteMedia(mediaID))
            ?..references.add(refID)
            ..save();
        }

        if (nodeRoot is User && nodeRoot.isFriend) {
          await getOrUpdateMedia(nodeRoot.id);
        } else if (nodeRoot is Self) {
          await getOrUpdateMedia(nodeRoot.id);
        } else if (nodeRoot is Groupable) {
          await getOrUpdateMedia(nodeRoot.id);
        }

        nodeRoot
          ..snips.add(mediaID)
          ..updateActivity()
          ..save();

        await writeHomePalette(nodeRoot, _homePalettes, bGen, rfHome);

        if (cv.id == 'home') setPage(homePage());
      } else if (eventPayload.first == "f") {
        // FORWARDED MESSAGE
        final msgID = eventPayload[1];
        final root = eventPayload[2];
        final forwardedFrom = eventPayload[3];
        final msg = await downloadMessage(msgID);
        if (msg == null) return;
        msg.forwarderID = forwardedFrom;
        return handleMessage(msg, root);
      }
    });
  }

  // =============================== UTILS ============================== //

  Future<void> updateExchangeRate() async {
    final lastUpdate = g.exchangeRate.lastUpdate;
    final rightNow = timeStamp();
    if (rightNow - lastUpdate > const Duration(minutes: 10).inMilliseconds) {
      final rate = await r.getExchangeRate();
      if (rate != null) {
        g.exchangeRate.rate = rate;
        g.exchangeRate.lastUpdate = rightNow;
        g.exchangeRate.save();
        if (cv.id == 'money') setPage(moneyPage());
      }
    }
  }

  Future<void> unselectHomeSelection({bool updateActivity = true}) async {
    for (final p in List.of(homePalettes)) {
      if (p.selected) {
        await writeHomePalette(p.node, _homePalettes, bGen, rfHome, sel: false);
      }
    }
    return;
  }

  List<Palette2> forwardables(List<Palette2> ps) {
    final idsInGroups = ps
        .asNodes<Groupable>()
        .map((e) => e.group)
        .expand((element) => element)
        .toSet();

    final forwardables = ps.whereNodeIs<Branchable>().asIds();

    final all = forwardables.followedBy(idsInGroups).toSet();

    return all.map((id) => _all[id]).whereType<Palette2>().toList();
  }

  // =========================== PAGES FUNCTIONS ======================== //

  Future<void> metaSend(Payload p, List<Chatable> targets) async {
    FireMessage? msg = p.message;
    await p.media?.save();
    final targetIDs = targets.asIds();
    print("Target IDs = $targetIDs");
    final onlySendingToSelf = targetIDs.every((id) => id == g.self.id);

    final messagesToForward =
        p.forwardables.whereType<ChatMessage>().map((cm) => cm.message);

    for (final t in targets) {
      for (final m in messagesToForward.followedBy(msg == null ? [] : [msg])) {
        m.reads[t.id] = true;
        await m.save();
        t.messages.add(m.id);
        t.updateActivity();
        await t.save();
        await writeHomePalette(t, _homePalettes, bGen, rfHome);
      }
    }

    // proceed to send
    Future(() async {
      List<Future<bool>> ss = [];
      if (!onlySendingToSelf) {
        if (msg != null) ss.add(uploadMessage(msg, skipCheck: true));
        if (p.media != null) ss.add(uploadMedia(p.media!));
        for (final m in messagesToForward) {
          m.refresh();
          await m.save();
          ss.add(uploadMessage(m, skipCheck: false));
        }
      }

      bool success;
      if (ss.isEmpty) {
        success = true;
      } else {
        success = await Future.wait(ss).then((s) => s.every((b) => b));
      }

      print("nUploads = ${ss.length}, success = $success");
      if (!success) return;
      Map<ID, Future<bool>> reqs = {};
      Map<ID, FireMessage> msgs = messagesToForward
          .followedBy(msg == null ? [] : [msg])
          .toList()
          .asMap()
          .map((key, value) => MapEntry(value.id, value));

      for (final m in messagesToForward) {
        for (final node in targets) {
          final reqKey = "${node.id}%${m.id}";
          if (node is Groupable) {
            final t = List<ID>.from(node.group)..remove(g.self.id);
            final req = r.MessageRequest(
                sender: g.self.id,
                targets: t,
                header: "${g.self.name} in ${node.name}",
                body: ">> forwarded message >>",
                data: "f%${m.id}%${node.id}%${g.self.id}");
            reqs[reqKey] = req.process();
          } else if (node.id == g.self.id) {
            reqs[reqKey] = Future.value(true);
          } else {
            final req = r.MessageRequest(
                sender: g.self.id,
                targets: [node.id],
                header: g.self.name,
                body: ">> forwarded message >>",
                data: "f%${m.id}%${g.self.id}%${g.self.id}");
            reqs[reqKey] = req.process();
          }
        }
      }

      if (msg != null) {
        for (final node in targets) {
          final reqKey = "${node.id}%${msg.id}";
          final b = (msg.text ?? "").isNotEmpty ? msg.text! : "&attachment";
          if (node is Groupable) {
            final t = List<ID>.from(node.group)..remove(g.self.id);
            final req = r.MessageRequest(
                sender: g.self.id,
                targets: t,
                header: "${g.self.name} in ${node.name}",
                body: b,
                data: "m%${msg.id}%${node.id}");
            reqs[reqKey] = req.process();
          } else if (node.id == g.self.id) {
            reqs[reqKey] = Future.value(true);
          } else {
            final req = r.MessageRequest(
                sender: g.self.id,
                targets: [node.id],
                header: g.self.name,
                body: b,
                data: "m%${msg.id}%${g.self.id}");
            reqs[reqKey] = req.process();
          }
        }
      }

      if (page is HomePage) setPage(homePage(prompt: "Sent!"));

      Future(() => reqs.forEach((key, value) async {
            final d = key.split("%");
            final nodeID = d[0];
            final msgID = d[1];
            final msg = msgs[msgID]!;
            msg.sents[nodeID] = await value;
            await msg.save();

            // update chat
            final pRef = page;
            if (pRef is ChatPage && pRef.node.id == nodeID) {
              setPage(chatPage(pRef.node, msgRe: msg));
            }
          }));
    });

    return;
  }

  Future<void> makeHyperchat(Payload p, Set<ID> grp) async {
    setPage(loadingPage());
    final prompts = await ru.randomPrompts(10);
    final hc = await r.getHyperchat(prompts);
    if (hc == null) {
      vm.popUntilHome();
      await unselectHomeSelection(updateActivity: false);
      setPage(homePage(prompt: "Failed to create hyperchat!"));
      return;
    }

    final hcID = sha1(hc.first).toBase58();
    final hcMedia = FireMedia(
        data: hc.first,
        id: sha1(utf8.encode(hcID)).toBase58(),
        metadata: MediaMetadata(
            owner: g.self.id,
            timestamp: timeStamp(),
            elementAspectRatio: 1.0,
            canSkipCheck: true,
            extension: ".png"));

    final hyper = Hyperchat(
        id: hcID,
        firstWord: hc.second.first,
        secondWord: hc.second.second,
        activity: timeStamp(),
        group: grp,
        messages: {},
        snips: {},
        media: hcMedia);

    final success = await uploadNode(hyper);
    if (!success) {
      _homePalettes.remove(hyper.id);
      hyper.delete();
      vm.popUntilHome();
      return setPage(homePage(prompt: "Failed to upload Hyperchat"));
    }

    await metaSend(p, [hyper]);
    unselectHomeSelection();
    vm.popUntilHome();
    setPage(chatPage(hyper, isPush: true));
    return;
  }

  Future<void> makeGroup(Group group, Payload p) async {
    setPage(loadingPage());
    final success = await uploadNode(group);
    if (success) {
      await metaSend(p, [group]);
      await writeHomePalette(group, _homePalettes, bGen, rfHome);
      await unselectHomeSelection();
      vm.popUntilHome();
      setPage(chatPage(group, isPush: true));
    } else {
      vm.popUntilHome();
      setPage(homePage(prompt: "Failed to create group"));
    }
  }

  Future<void> ping(String text, List<ID> targets) async {
    final b = text;
    final h = "${g.self.name} pinged you";
    r.MessageRequest(
      sender: g.self.id,
      data: "",
      targets: targets,
      header: h,
      body: b,
    ).process();
  }

  Future<void> sendSnip({
    required String path,
    required bool isReversed,
    required double aspectRatio,
    String? text,
  }) async {
    // image from camera are cached files, so they are
    // automatically deleted on boot

    final timestamp = timeStamp();
    setPage(loadingPage());

    print("The ASPECT RATIO = $aspectRatio");

    final media = FireMedia(
        id: randomMediaID(),
        path: path,
        metadata: MediaMetadata(
            isSquared: false,
            owner: g.self.id,
            extension: path.extension(),
            timestamp: timestamp,
            isReversed: isReversed,
            text: text,
            canSkipCheck: true,
            elementAspectRatio: aspectRatio));

    final success = await uploadMedia(media);
    if (!success) return print("Snip media upload unsucessful!");

    var personTargets = <ID>[];
    List<Future<bool>> successes = [];

    final selectedPalettes = homePalettes.selected();
    for (final node in selectedPalettes.asNodes()) {
      if (node is Groupable) {
        final targets = homePalettes.those(node.group).whereNodeIs<User>();
        successes.add(r.MessageRequest(
          sender: g.self.id,
          targets: targets.asIds().toList(),
          header: "${g.self.name} pinged ${node.name}",
          body: "&attachment",
          data: "s%${media.id}%${node.id}",
        ).process());
      } else {
        personTargets.add(node.id);
      }
    }

    if (personTargets.isNotEmpty) {
      successes.add(r.MessageRequest(
        sender: g.self.id,
        targets: personTargets,
        header: "${g.self.name} pinged you",
        body: "&attachment",
        data: "s%${media.id}%${g.self.id}",
      ).process());
    }

    await unselectHomeSelection();
    vm.popUntilHome();
    setPage(homePage(prompt: "Sent ping"));
  }

  // ============================== PAGES ============================== //

  ru.Down4PageWidget homePage({String? prompt}) {
    return HomePage(
      forward: (sel) => setPage(forwardPage(forwardables(sel), isPush: true)),
      openNode: (n, f) => setPage(chatPage(n, isPush: true)),
      send: (p, t) async {
        await metaSend(p, t);
        await unselectHomeSelection(updateActivity: true);
        vm.popUntilHome();
        setPage(homePage(prompt: "Sent messages!"));
      },
      palettes: formattedHomePalettes,
      hyperchat: () => setPage(hyperchatPage()),
      group: () => setPage(groupPage()),
      money: () =>
          setPage(moneyPage(transition: homeTransition(), isPush: true)),
      ping: (text) {
        // Ping group nodes
        homePalettes.selected().asNodes<Groupable>().forEach((gn) {
          final targets = List<ID>.from(gn.group)..remove(g.self.id);
          r.MessageRequest(
            sender: g.self.id,
            targets: targets,
            header: "${g.self.name} pinged ${gn.name}",
            body: text,
            data: "",
          ).process();
        });
        // Ping user nodes
        homePalettes.selected().asNodes<Personable>().forEach((pn) {
          r.MessageRequest(
            sender: g.self.id,
            targets: [pn.id],
            header: "${g.self.name} pinged you",
            body: text,
            data: "",
          ).process();
        });
      },
      snip: () async => setPage(await snipPage()),
      search: () => setPage(searchPage(isPush: true)),
      delete: () async {
        for (final p in List<Palette2>.from(homePalettes)) {
          if (p.selected) {
            _homePalettes.remove(p.node.id);
            await g.boxes.nodes.delete(p.node.id);
          }
        }
        setPage(homePage());
        await localPalettesRoutine();
      },
    );
  }

  ru.Down4PageWidget loadingPage({String? seed}) {
    return LoadingPage2(seed: seed);
  }

  ru.Down4PageWidget forwardPage(List<Down4Object> fo, {bool isPush = false}) {
    void rf() => setPage(forwardPage(fo));
    List<ButtonsInfo2> fbGen(FireNode node) {
      return [
        ButtonsInfo2(
            asset: g.fifty,
            rightMost: true,
            pressFunc: () =>
                setPage(chatPage(node as Chatable, fo: fo, isPush: true)))
      ];
    }

    if (isPush) {
      vm.popUntilHome();
      vm.push(V(id: "forward", pages: [P()]));
      for (final p in formattedHomePalettes) {
        writePalette3(p.node, cv.cp.objects, fbGen, rf, pr: p.messagePreview);
      }
    }

    return ForwardingPage(
        fObjects: fo,
        openNode: (fObjects, node) =>
            setPage(chatPage(node, fo: fObjects, isPush: true)),
        hyper: (fObjects, transition) =>
            setPage(hyperchatPage(fObjects, transition)),
        forward: (p, t) async {
          await metaSend(p, t);
          await unselectHomeSelection();
          homeScrollToZero();
          vm.popUntilHome();
          setPage(homePage(prompt: "Forwarded messages"));
        },
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget paymentPage(Down4Payment payment) {
    return PaymentPage(
      ok: () {
        vm.popUntilHome();
        setPage(homePage());
      },
      sendPayment: (pay) async {
        final targets = pay.txs.last.txsOut
            .map((utxo) => utxo.isGets ? utxo.receiver : null)
            .whereType<String>()
            .toList(growable: false);
        final success = await uploadPayment(pay);
        if (success) {
          r.MessageRequest(
            sender: g.self.id,
            targets: targets,
            data: "p%${payment.id}",
            header: "${g.self.name} payed you",
            body: pay.textNote,
          ).process();
          vm.popUntilHome();
          setPage(homePage(prompt: "Sent payment"));
        }
      },
      back: () => back(withPop: false),
      payment: payment,
    );
  }

  ru.Down4PageWidget moneyPage({
    bool isPush = false,
    bool isReload = false,
    Transition? transition,
    Personable? node,
    Down4Payment? paymentUpdate,
    // payment update is for when we are in money view, and
    // we receive an online payment, this let us update status with this new
    // payment, it would not be necessary if listeners work on lazy box, but
    // haven't found a way to make the listener work yet...
  }) {
    Map<ID, Palette2> people() => cv.pages[0].objects.cast();
    Map<ID, Palette2> payments() => cv.pages[1].objects.cast();
    void rf() => setPage(moneyPage());
    void openPay(Down4Payment payment) => setPage(paymentPage(payment));

    void loadSomePayments(int limit, [int ms = 0]) =>
        Future.delayed(Duration(milliseconds: ms), () async {
          await writePayments(payments(), openPay, limit);
          rf();
        });

    if (isPush) {
      vm.push(V(id: "money", pages: [P(), P()]));
      final users = transition?.trueTargets ?? (node != null ? [node] : []);
      for (final u in users) {
        writePalette3(u, people(), null, null);
      }
      loadSomePayments(5, 633);
    }

    if (paymentUpdate != null) loadSomePayments(1, 633);

    return MoneyPage(
        single: node != null ? Palette2(node: node) : null,
        transition: transition,
        payments: payments().values.toList().formatted(),
        loadMorePayments: () async => loadSomePayments(8),
        onScan: (payment) async {
          await g.wallet.parsePayment(g.self.id, payment);
          loadSomePayments(1);
        },
        makePayment: (payment) async {
          await g.wallet.parsePayment(g.self.id, payment);
          unselectHomeSelection(updateActivity: true);
          vm.popUntilHome();
          setPage(paymentPage(payment));
        },
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget hyperchatPage(
      [List<Down4Object>? fObjects, Transition? transition]) {
    final transition_ = transition ?? homeTransition();
    // final hyperchatGroup = Set<ID>.from(transition_.trueTargets.asIds())
    //   ..add(g.self.id); // everyone, including self
    final pingGroup = transition_.trueTargets.asIds().toList(); // simply
    return HyperchatPage(
      transition: transition_,
      fo: fObjects,
      makeHyperchat: makeHyperchat,
      back: () => back(withPop: false, f: fObjects),
      ping: (text) => ping(text, pingGroup),
    );
  }

  ru.Down4PageWidget groupPage() {
    final transition = homeTransition();
    return GroupPage(
        initialOffset: transition.scroll,
        back: () => back(withPop: false),
        makeGroup: makeGroup,
        palettesForTransition: transition.postTransition,
        people: transition.trueTargets,
        nHidden: transition.nHidden,
        homePalettes: formattedHomePalettes);
  }

  ru.Down4PageWidget searchPage({bool isPush = false}) {
    if (isPush) {
      vm.push(V(id: "search", pages: [P()]));
    }

    void rf() => setPage(searchPage());
    Map<ID, Palette2> searchs() => cv.cp.objects.cast();

    return AddFriendPage(
        search: (strIDs) async {
          final ids = strIDs.split(" ").toSet();
          final toFetch = ids.difference(allIDs.toSet());
          final inHome = ids.map((id) => localNode(id)).whereType<FireNode>();
          final nodes = await r.getNodes(toFetch);
          for (final node in inHome.followedBy(nodes ?? [])) {
            writePalette3(node, searchs(), bGen2, rf);
          }
          rf();
        },
        onScan: (n) {
          writePalette3(homeNode(n.id) ?? n, searchs(), bGen2, rf);
          rf();
        },
        openNode: (node) => setPage(nodePage(node, isPush: true)),
        add: (selectedPals) async {
          for (final p in selectedPals) {
            var node = homeNode(p.id) ?? p.node;
            if (node is User) {
              node.isFriend = true;
              await node.save();
              writePalette3(node, searchs(), bGen2, rf, sel: false);
              await writeHomePalette(node, _homePalettes, bGen, rfHome);
            }
          }
          rf();
          localPalettesRoutine();
        },
        forwardNodes: (pals) => setPage(forwardPage(pals, isPush: true)),
        back: () => back(withPop: true));
  }

  Future<ru.Down4PageWidget> snipPage({
    CameraController? ctrl,
    int camera = 0,
    ResolutionPreset res = ResolutionPreset.high,
    bool reload = false,
  }) async {
    void nextRes() {
      snipPage(
        ctrl: ctrl,
        camera: camera,
        reload: true,
        res: res == ResolutionPreset.low
            ? ResolutionPreset.medium
            : res == ResolutionPreset.medium
                ? ResolutionPreset.high
                : ResolutionPreset.low,
      );
    }

    Future<void> nextCam() async {
      setPage(await snipPage(
          ctrl: ctrl, camera: (camera + 1) % 2, reload: true, res: res));
    }

    Future<ru.Down4PageWidget> snip() async {
      return SnipCamera(
        maxZoom: await ctrl!.getMaxZoomLevel(),
        minZoom: await ctrl.getMinZoomLevel(),
        camNum: camera,
        cameraCallBack: sendSnip,
        ctrl: ctrl,
        nextRes: nextRes,
        flip: nextCam,
        cameraBack: () {
          ctrl?.dispose();
          back(withPop: false);
        },
      );
    }

    if (ctrl == null || reload) {
      await ctrl?.dispose();
      ctrl = CameraController(g.cameras[camera], res);
      await ctrl.initialize();
    }

    return snip();
  }

  ru.Down4PageWidget nodePage(FireNode node, {bool isPush = false}) {
    if (isPush) {
      final id = "node-${node.id}";
      final r = List<String>.from(route);
      if (r.contains(id)) {
        // we don't allow cycles
        while (route.last != id) {
          final v = vm.pop();
          final l = r.removeLast();
          print("ROUTE = $route");
          print("POPPED VIEW ${v.id}");
          print("POPPED $l");
        }
      } else {
        vm.push(V(id: "node-${node.id}", pages: [P()], node: node));
      }
    }

    return NodePage(
        palette: node,
        openChat: (node_) => setPage(chatPage(node_ as Chatable, isPush: true)),
        openNode: (node_) => setPage(nodePage(node_, isPush: true)),
        payNode: (node) =>
            setPage(moneyPage(node: node as Personable, isPush: true)),
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget chatPage(
    Chatable node, {
    bool isPush = false,
    bool isReload = false,
    bool rewriteMsgWithNodes = false,
    FireMessage? msgRe,
    List<Down4Object>? fo,
  }) {
    bool forwarding() => fo != null;
    ID chatID() => "chat-${node.id}";
    Map<ID, ChatMessage> messages() => vm.cv.pages[0].objects.cast();
    Map<ID, Palette2> members() => vm.cv.pages[1].objects.cast();
    Map<ID, EmptyObject> msgWithVideos() => vm.cv.pages[2].objects.cast();
    Map<ID, EmptyObject> msgWithNodes() => vm.cv.pages[3].objects.cast();
    List<ID> orderedMessages() => node.messages.toList().reversed.toList();
    void opn(FireNode n) => setPage(nodePage(n, isPush: true));
    void Function(FireNode)? openNode() => forwarding() ? null : opn;

    List<ButtonsInfo2> Function(FireNode)? cbGen = forwarding() ? null : bGen2;

    void refreshChat({bool stopVid = false}) {
      final pg = page;
      if (pg is! ChatPage || pg.node.id != node.id) return;

      if (stopVid) {
        for (final v in msgWithVideos().keys) {
          messages()[v] = messages()[v]!.onPageTransition();
        }
      }

      setPage(chatPage(node, fo: pg.fo));
    }

    void writeGroupNodes() {
      if (node is Groupable) {
        for (final n in allPalettes.those(node.group).asNodes()) {
          writePalette3(n, members(), cbGen, refreshChat);
        }
      }
    }

    Future<void> loadMore([int i = 20]) async {
      await writeMessages(
          limit: i,
          node: node,
          ordered: orderedMessages(),
          state: messages(),
          withNodes: msgWithNodes(),
          videos: msgWithVideos(),
          refresh: refreshChat,
          openNode: openNode());
      refreshChat();
    }

    void reloadChat() {
      Future(() async {
        // is a reload, load all new messages
        final pg = page;
        if (pg is! ChatPage || pg.node.id != node.id) return;
        final loaded = messages().keys;
        final ordered = node.messages.toList().reversed.toList();
        List<ID> toLoad = [];
        for (final id in ordered) {
          if (!loaded.contains(id)) {
            toLoad.add(id);
          } else {
            break;
          }
        }
        await writeMessages(
            limit: toLoad.length,
            node: node,
            ordered: toLoad,
            videos: msgWithVideos(),
            withNodes: msgWithNodes(),
            state: messages(),
            refresh: refreshChat,
            openNode: openNode());
      }).then((_) => refreshChat());
    }

    void initChat() {
      Future(() async {
        // if is group, write members
        writeGroupNodes();
        // write the messages
        await writeMessages(
            limit: 20,
            ordered: node.messages.toList().reversed.toList(),
            node: node,
            state: messages(),
            videos: msgWithVideos(),
            withNodes: msgWithNodes(),
            refresh: () => refreshChat(),
            openNode: openNode());
      }).then((_) => refreshChat());
    }

    if (isPush) {
      final id = chatID();
      final r = List<String>.from(route);
      if (r.contains(id)) {
        // we don't allow cycles
        while (route.last != id) {
          print("ROUTE BEFORE POP = $route");
          final v = vm.pop();
          final l = r.removeLast();
          print("ROUTE = $route");
          print("POPPED AFTER POP ${v.id}");
          print("POPPED $l");
        }
        reloadChat();
      } else {
        vm.push(V(id: id, pages: [P(), P(), P(), P()], node: node));
        initChat();
      }
    }

    if (msgRe != null) {
      messages()[msgRe.id] = messages()[msgRe.id]!.reloaded(msgRe);
    }

    if (isReload) {
      final loaded = messages().keys;
      final last = node.messages.last;
      if (!loaded.contains(last)) reloadChat();
    }

    if (rewriteMsgWithNodes) {
      for (final id in msgWithNodes().keys) {
        messages()[id] = messages()[id]!.withOpenNode(open: openNode());
      }
      writeGroupNodes();
      refreshChat();
    }

    return ChatPage(
        onPageChange: (_) => refreshChat(stopVid: true),
        messages: messages(),
        ordered: node.messages.toList().reversed.toList(),
        members: members(),
        loadMore: loadMore,
        node: node,
        fo: fo,
        openNode: opn,
        send: (payload) async {
          await metaSend(payload, [node]);
          if (forwarding()) vm.popInBetween(); // poping the forwarding page
          setPage(chatPage(node,
              isReload: true,
              rewriteMsgWithNodes: payload.forwardables.isNotEmpty));
        }, // TODO, will need future nodes
        back: () => back(withPop: true, f: fo));
  }

  Future<ru.Down4PageWidget> snipView(Chatable node) async {
    if (node.snips.isEmpty) {
      await writeHomePalette(node, _homePalettes, bGen, rfHome);
      setPage(homePage());
    }
    final snip = node.snips.first;
    // consume the snip on the node
    node
      ..snips.remove(snip)
      ..save();

    FireMedia? media = await snip.getLocalMessageMedia();
    media ??= await downloadAndWriteMedia(snip);
    if (media == null) return snipView(node);

    final scale = media.metadata.elementAspectRatio * g.sizes.fullAspectRatio;
    Widget displayMediaBody(Widget child) => Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(
              media!.metadata.isReversed ? math.pi : 0,
            ),
            child: Transform.scale(
              scale: scale > 1 ? scale : 1 / scale,
              child: SizedBox(
                  height: media.metadata.elementAspectRatio * g.sizes.w,
                  width: g.sizes.w,
                  child: child),
            ),
          ),
        );

    Widget displayMedia;
    String? text = media.metadata.text;
    Future<void> Function() back_;
    Future<void> Function() next_;
    if (media.isVideo) {
      var ctrl = VideoPlayerController.file(media.file!);
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      displayMedia = displayMediaBody(VideoPlayer(ctrl));

      back_ = () async {
        await ctrl.dispose();
        await writeHomePalette(node, _homePalettes, bGen, rfHome);
        back(withPop: false);
        media
          ?..references.remove(node.id)
          ..delete();
      };
      next_ = () async {
        if (node.snips.isEmpty) {
          back_();
        } else {
          await ctrl.dispose();
          setPage(await snipView(node));
          media
            ?..references.remove(node.id)
            ..delete();
        }
      };
    } else {
      await precacheImage(FileImage(media.file!), context);
      displayMedia = displayMediaBody(Image.file(media.file!));

      back_ = () async {
        await writeHomePalette(node, _homePalettes, bGen, rfHome);
        back(withPop: false);
        media
          ?..references.remove(node.id)
          ..delete();
      };
      next_ = () async {
        if (node.snips.isEmpty) {
          back_();
        } else {
          setPage(await snipView(node));
          media
            ?..references.remove(node.id)
            ..delete();
        }
      };
    }

    return SnipViewPage(
      displayMedia: displayMedia,
      text: text,
      back: back_,
      next: next_,
    );
  }

  @override
  Widget build(BuildContext context) {
    print("REBUILDING HOME");
    return page;
  }
}
