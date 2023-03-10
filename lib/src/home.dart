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
  ru.PageManager pm = ru.PageManager()..put(const LoadingPage2());

  void push(ru.Down4PageWidget page) {
    print("PUSHED PAGE = $page");
    pm.put(page);
    setState(() {});
  }

  void pop() async {
    // first we pop
    final popedPage = pm.currentPage;
    print("POPPED PAGE = $popedPage");
    pm.pop();
    // reloading currentPage is a smart thing to do
    final cp = pm.currentPage;
    print("CURRENT PAGE = $cp");
    if (cp is HomePage) {
      // if we are going in home page and
      // the poped page has a node, we want to refresh that palette
      // because it might have changed (example: last message preview)
      if (popedPage is ChatPage) {
        await writePalette2(popedPage.node, _palettes, bGen, refreshHome,
            h: true);
      } else if (popedPage is SnipViewPage) {
        // Already taking care of this else where
      }
      pm.refresh(homePage());
    } else if (cp is MoneyPage) {
      final pp = pm.prevPage;
      if (pp is HomePage) {
        pm.refresh(moneyPage(transition: homeTransition()));
      } else if (pp is NodePage) {
        pm.refresh(moneyPage(node: pp.node as Person));
      }
    } else if (cp is PaymentPage) {
      pm.refresh(moneyPage());
    } else if (cp is AddFriendPage) {
      pm.refresh(searchPage());
    } else if (cp is NodePage) {
      pm.refresh(nodePage(cp.node));
    } else if (cp is ChatPage) {
      pm.refresh(chatPage(cp.node, cp.fObjects));
    } else if (cp is ForwardingPage) {
      pm.refresh(forwardPage(cp.fObjects));
    }
    setState(() {});
  }

  void refresh(ru.Down4PageWidget page) {
    pm.refresh(page);
    setState(() {});
  }

  void goHome() {
    pm.popUntilHome();
    refresh(homePage());
  }

  void popAll() {
    final n = pm.nPages;
    for (int i = 0; i < n; i++) {
      pm.pop();
    }
  }

  Transition homeTransition() => selectionTransition(
      originalList: formattedHomePalettes,
      state: _palettes,
      hiddenState: _hiddenPalettes,
      scrollOffset: _homeScrollController.offset);

  Map<ID, Palette2> _palettes = {};
  Map<ID, Palette2> _hiddenPalettes = {};

  BaseNode? homeNode(ID id) => _palettes[id]?.node;
  BaseNode? hiddenNode(ID id) => _hiddenPalettes[id]?.node;

  Iterable<Palette2> get homePalettes => _palettes.values;
  List<Palette2> get formattedHomePalettes =>
      homePalettes.toList().formattedReverse();

  StreamSubscription? _messageListener;

  late final ScrollController _homeScrollController = ScrollController();
  double get homeScroll => _homeScrollController.offset;

  var _tec = TextEditingController();

  // ======================================================= INITIALIZATION ============================================================ //

  void refreshHome() => refresh(homePage());

  @override
  void initState() {
    super.initState();
    localPalettesRoutine(init: true);
    // loadHomePalettes2();
    ru.clearAppCache();
    g.wallet.walletRoutine();
    g.wallet.printWalletInfo();
    connectToMessages();
    // processWebRequests();
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
    final groupNodes = nodes.whereType<GroupNode>();
    final groupIds = groupNodes.map((e) => e.group).expand((id) => id).toSet();
    final calcHidden = groupIds.difference(homes);

    final stayHidden = hiddens.intersection(calcHidden);

    final hiddenToDump = hiddens.difference(stayHidden);
    final hiddenToFetch = calcHidden.difference(allLocal);

    for (final dump in hiddenToDump.followedBy(shouldDump)) {
      g.boxes.hidden.delete(dump);
    }

    for (final node in nodes.whereType<BaseNode>().followedBy([g.self])) {
      await writePalette2(node, _palettes, bGen, refreshHome, h: true);
    }

    if (init) {
      pm.pop();
      push(homePage());
    }

    final lHidden = await Future.wait(stayHidden.map((e) => e.getHiddenNode()));
    for (final n in lHidden.whereType<BaseNode>()) {
      await writePalette2(n, _hiddenPalettes, null, null);
    }

    final fetched = await r.getNodes(hiddenToFetch);
    for (final n in fetched ?? <BaseNode>[]) {
      n.save(hidden: true);
      await writePalette2(n, _hiddenPalettes, null, null);
    }

    print("HIDDEN = ${_hiddenPalettes.keys.toList()}");
    print("HOMES = ${_palettes.keys.toList()}");
  }

  Future<List<ButtonsInfo2>> bGen(BaseNode node) async {
    if (node is! ChatableNode) return [];
    if (node.snips.isNotEmpty) {
      return [
        ButtonsInfo2(
            asset: g.red,
            pressFunc: () async => push(await snipView(node)),
            longPressFunc: () => node is Person ? push(nodePage(node)) : null,
            rightMost: true)
      ];
    } else {
      Message? lastMsg = node.messages.isEmpty
          ? null
          : await node.messages.last.getLocalMessage();
      return [
        ButtonsInfo2(
            asset: lastMsg?.isRead ?? true ? g.fifty : g.black,
            pressFunc: () => push(chatPage(node)),
            longPressFunc: () => node is Person ? push(nodePage(node)) : null,
            rightMost: true)
      ];
    }
  }

  void connectToMessages() {
    var msgQueue = db.child("Users").child(g.self.id).child("M");
    var messagesRef = db.child("Messages");

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
          await (value[1] as Message?)?.onReceipt();
          final hyperchat = Hyperchat(
              id: hcID,
              firstWord: firstWord,
              secondWord: secondWord,
              group: members.toSet(),
              messages: {msgID},
              snips: {},
              media: value.first as NodeMedia)
            ..save();

          await writePalette2(hyperchat, _palettes, bGen, refreshHome);
          await localPalettesRoutine();
          refresh(homePage());
        });
      } else if (eventPayload.first == "p") {
        // PAYMENT!
        final paymentID = eventPayload[1];
        final payment = await r.getPayment(paymentID);
        if (payment == null) return;
        await g.wallet.parsePayment(g.self.id, payment);
        if (pm.currentPage is MoneyPage) {
          final pv = pm.prevPage;
          if (pv is NodePage) {
            refresh(moneyPage(node: pv.node as Person, paymentUpdate: payment));
          } else if (pv is HomePage) {
            refresh(moneyPage(
              transition: homeTransition(),
              paymentUpdate: payment,
            ));
          }
        }
        return;
      } else if (eventPayload.first == "m") {
        // MESSAGE!
        final msgID = eventPayload[1];
        final root = eventPayload[2];
        final msg = await downloadMessage(msgID);
        if (msg == null) return;
        ChatableNode? rootNode = homeNode(root) as ChatableNode?;
        if (rootNode == null) {
          // need to download it
          final singleNodeList = await r.getNodes([root]);
          if (singleNodeList == null || singleNodeList.length != 1) return;
          rootNode = singleNodeList.first as ChatableNode;
          if (rootNode is GroupNode) {
            await rootNode.save();
            await localPalettesRoutine();
          }
        }

        await msg.onReceipt();

        rootNode
          ..messages.add(msg.id)
          ..updateActivity()
          ..save();

        await writePalette2(rootNode, _palettes, bGen, refreshHome, h: true);

        final cp = pm.currentPage;
        if (cp is HomePage) {
          refresh(homePage());
        } else if (cp is ChatPage && cp.node.id == root) {
          refresh(chatPage(rootNode));
        }
      } else if (eventPayload.first == "s") {
        final String mediaID = eventPayload[1];
        final String root = eventPayload[2];

        ChatableNode? nodeRoot;
        nodeRoot = homeNode(root) as ChatableNode?;
        if (nodeRoot == null) {
          // nodeRoot is not in home, need to download it
          final newRootNodes = await r.getNodes([root]);
          if (newRootNodes == null || newRootNodes.length != 1) return;
          nodeRoot = newRootNodes.first as ChatableNode;
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
        } else if (nodeRoot is GroupNode) {
          await getOrUpdateMedia(nodeRoot.id);
        }

        nodeRoot
          ..snips.add(mediaID)
          ..updateActivity()
          ..save();

        await writePalette2(nodeRoot, _palettes, bGen, refreshHome, h: true);

        if (pm.currentPage is HomePage) refresh(homePage());
      }
    });
  }

  // ======================================================= UTILS ============================================================ //

  Future<void> updateExchangeRate() async {
    final lastUpdate = g.exchangeRate.lastUpdate;
    final rightNow = timeStamp();
    if (rightNow - lastUpdate > const Duration(minutes: 10).inMilliseconds) {
      final rate = await r.getExchangeRate();
      if (rate != null) {
        g.exchangeRate.rate = rate;
        g.exchangeRate.lastUpdate = rightNow;
        g.exchangeRate.save();
        if (pm.currentPage is MoneyPage) refresh(moneyPage());
      }
    }
  }

  Future<void> unselectSelection({bool updateActivity = true}) async {
    for (final p in homePalettes) {
      if (p.selected) {
        await writePalette2(p.node, _palettes, bGen, refreshHome,
            h: true, sel: false);
      }
    }
  }

  // =========================== PAGES FUNCTIONS ======================== //

  Future<void> metaSend(Payload p, List<ChatableNode> targets) async {
    Message? msg = p.message;
    final targetIDs = targets.asIds();
    final selfInTargets = targetIDs.contains(g.self.id);
    final onlySendingToSelf = targetIDs.any((id) => id != g.self.id);

    final messagesToForward =
        p.forwardables.whereType<ChatMessage>().map((cm) => cm.message);

    List<Future<bool>> ss = [];
    if (!onlySendingToSelf) {
      if (msg != null) ss.add(uploadMessage(msg, skipCheck: true));
      if (p.media != null) ss.add(uploadOrUpdateMedia(p.media!));
      for (final m in messagesToForward) {
        m
          ..refresh()
          ..isSaved = selfInTargets
          ..isRead = true
          ..save();
        ss.add(uploadMessage(m, skipCheck: false));
      }
    }

    bool successfulUploads;
    if (ss.isEmpty) {
      successfulUploads = true;
    } else {
      successfulUploads = await Future.wait(ss).then((s) => s.every((b) => b));
    }

    if (!successfulUploads) return;
    Map<ID, Future<bool>> reqs = {};
    Map<ID, Message> msgs = messagesToForward
        .followedBy(msg == null ? [] : [msg])
        .toList()
        .asMap()
        .map((key, value) => MapEntry(value.id, value));

    for (final m in messagesToForward) {
      for (final node in targets) {
        node
          ..messages.add(m.id)
          ..updateActivity()
          ..save();
        await writePalette2(node, _palettes, bGen, refreshHome);

        final reqKey = "${node.id}%${m.id}";

        if (node is GroupNode) {
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
        node
          ..messages.add(msg.id)
          ..updateActivity()
          ..save();
        await writePalette2(node, _palettes, bGen, refreshHome);

        final reqKey = "${node.id}%${msg.id}";
        final b = (msg.text ?? "").isNotEmpty ? msg.text! : "&attachment";
        if (node is GroupNode) {
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

    refreshHome();

    Future(() => reqs.forEach((key, value) async {
          final d = key.split("%");
          final nodeID = d[0];
          final msgID = d[1];
          msgs[msgID]!
            ..sents[nodeID] = false
            ..sents[nodeID] = await value
            ..save(); // sents is also used as a reference
          // counter, so we put it at false initialy to add the reference, then we
          // put the real sent value afterwards
        }));

    return;
  }

  Future<void> makeHyperchat(Payload p, Set<ID> grp) async {
    push(loadingPage());
    final prompts = await ru.randomPrompts(10);
    final hc = await r.getHyperchat(prompts);
    if (hc == null) {
      popAll();
      await unselectSelection(updateActivity: false);
      return push(homePage(prompt: "Failed to create hyperchat!"));
    }

    final hcID = sha1(hc.first).toBase58();
    final hcMedia = NodeMedia(
        data: hc.first,
        id: sha1(utf8.encode(hcID)).toBase58(),
        metadata: MediaMetadata(
            owner: g.self.id,
            timestamp: timeStamp(),
            elementAspectRatio: 1.0,
            extension: ".png"));

    final msg = p.message!
      ..isRead = true
      ..save();

    final hyper = Hyperchat(
        id: hcID,
        firstWord: hc.second.first,
        secondWord: hc.second.second,
        group: grp,
        messages: {msg.id},
        snips: {},
        media: hcMedia)
      ..save();

    unselectSelection();
    popAll();
    pm.put(homePage());
    push(chatPage(hyper));

    await writePalette2(hyper, _palettes, bGen, refreshHome);

    final success = await uploadHyperchatMedia(hcMedia);
    if (!success) {
      print("Failed to upload hyperchat, canceling and deleting");
      _palettes.remove(hyper.id);
      hyper.delete();
      popAll();
      return push(
        homePage(prompt: "Failed to upload Hyperchat. Please retry."),
      );
    }

    await metaSend(p, [hyper]);
    refresh(chatPage(hyper));
    return;
  }

  Future<void> makeGroup(Group group, Payload p) async {
    push(loadingPage());
    final success = await uploadNode(group);
    if (success) {
      await metaSend(p, [group]);
      await writePalette2(group, _palettes, bGen, refreshHome);
      await unselectSelection();
      popAll();
      pm.put(homePage());
      push(nodePage(group));
    } else {
      popAll();
      push(homePage(prompt: "Failed to create group"));
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
    pm.pop();
    push(loadingPage());

    print("The ASPECT RATIO = $aspectRatio");

    final media = MessageMedia(
        id: randomMediaID(),
        path: path,
        metadata: MediaMetadata(
          isSquared: false,
          owner: g.self.id,
          extension: path.extension(),
          timestamp: timestamp,
          isReversed: isReversed,
          text: text,
          elementAspectRatio: aspectRatio,
        ));

    final success = await uploadOrUpdateMedia(media, skipCheck: true);
    if (!success) return print("Snip media upload unsucessful!");

    var personTargets = <ID>[];
    List<Future<bool>> successes = [];

    final selectedPalettes = homePalettes.selected();
    for (final node in selectedPalettes.asNodes()) {
      if (node is GroupNode) {
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

    await unselectSelection();
    pop();
  }

  // ============================== PAGES ============================== //

  ru.Down4PageWidget homePage({String? prompt}) {
    return HomePage(
      openNode: (n, f) => push(chatPage(n, f)),
      send: (p, t) async {
        await metaSend(p, t);
        unselectSelection(updateActivity: true);
        popAll();
        push(homePage(prompt: "Sent messages!"));
      },
      scrollController: _homeScrollController,
      palettes: formattedHomePalettes,
      hyperchat: (fo) => push(hyperchatPage(fo)),
      group: () => push(groupPage()),
      money: () => push(moneyPage(transition: homeTransition())),
      ping: (text) {
        // Ping group nodes
        homePalettes.selected().asNodes<GroupNode>().forEach((gn) {
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
        homePalettes.selected().asNodes<Person>().forEach((pn) {
          r.MessageRequest(
            sender: g.self.id,
            targets: [pn.id],
            header: "${g.self.name} pinged you",
            body: text,
            data: "",
          ).process();
        });
      },
      snip: () async => push(await snipPage()),
      search: () => push(searchPage()),
      delete: () async {
        for (final p in List<Palette2>.from(homePalettes)) {
          if (p.selected) {
            _palettes.remove(p.node.id);
            await g.boxes.nodes.delete(p.node.id);
          }
        }
        refresh(homePage());
        await localPalettesRoutine();
      },
    );
  }

  ru.Down4PageWidget loadingPage({String? seed}) {
    return LoadingPage2(seed: seed);
  }

  ru.Down4PageWidget forwardPage(List<Down4Object> forwardingObjects) {
    return ForwardingPage(
        hiddenState: _hiddenPalettes,
        possibleTargets:
            formattedHomePalettes.reversed.asNodes<ChatableNode>().toList(),
        fObjects: forwardingObjects,
        openNode: (fObjects, node) => push(chatPage(node, fObjects)),
        hyper: (fObjects, transition) =>
            push(hyperchatPage(fObjects, transition)),
        forward: (p, t) async {
          await metaSend(p, t);
          popAll();
          push(homePage());
        },
        back: pop);
  }

  ru.Down4PageWidget paymentPage(Down4Payment payment) {
    return PaymentPage(
      ok: () {
        popAll();
        push(homePage());
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
            data: "p-${payment.id}",
            header: "${g.self.id} payed you",
            body: pay.textNote,
          ).process();
          popAll();
          push(homePage());
        }
      },
      back: pop,
      payment: payment,
    );
  }

  ru.Down4PageWidget moneyPage(
      {Transition? transition, Person? node, Down4Payment? paymentUpdate
      // payment update is for when we are in money view, and
      // we receive an online payment, this let us update status with this new
      // payment, it would not be necessary if listeners work on lazy box, but
      // haven't found a way to make the listener work yet...
      }) {
    return MoneyPage(
        initialOffset: transition?.scroll ?? 0,
        palettesAfterTransition:
            transition?.postTransition ?? [Palette2(node: node!)],
        people: transition?.trueTargets ?? [node!],
        nHidden: transition?.nHidden ?? 0,
        openPayment: (payment) => push(paymentPage(payment)),
        palettesBeforeTransition:
            transition?.preTransition ?? [Palette2(node: node!)],
        paymentUpdate: paymentUpdate,
        makePayment: (payment) async {
          await g.wallet.parsePayment(g.self.id, payment);
          popAll();
          pm.put(homePage());
          push(paymentPage(payment));
        },
        back: pop);
  }

  ru.Down4PageWidget hyperchatPage(
      [List<Down4Object>? fObjects, Transition? transition]) {
    final transition_ = transition ?? homeTransition();
    final hyperchatGroup = Set<ID>.from(transition_.trueTargets.asIds())
      ..add(g.self.id); // everyone, including self
    final pingGroup = transition_.trueTargets.asIds().toList(); // simply
    return HyperchatPage(
      initialOffset: homeScroll,
      palettesForTransition: transition_.postTransition,
      people: transition_.trueTargets,
      nHidden: transition_.nHidden,
      homePalettes: transition_.preTransition,
      makeHyperchat: makeHyperchat,
      back: pop,
      ping: (text) => ping(text, pingGroup),
    );
  }

  ru.Down4PageWidget groupPage() {
    final transition = homeTransition();
    return GroupPage(
        initialOffset: homeScroll,
        back: pop,
        makeGroup: makeGroup,
        palettesForTransition: transition.postTransition,
        people: transition.trueTargets,
        nHidden: transition.nHidden,
        homePalettes: formattedHomePalettes);
  }

  ru.Down4PageWidget searchPage() {
    return AddFriendPage(
        openNode: (node) => push(nodePage(node)),
        add: (selectedPals) async {
          for (final p in selectedPals) {
            var node = homeNode(p.id) ?? p.node;
            if (node is User) {
              node.isFriend = true;
              node.save();
              await writePalette2(node, _palettes, bGen, refreshHome, h: true);
            }
          }
          await localPalettesRoutine();
        },
        forwardNodes: (pals) => push(forwardPage(pals)),
        back: pop);
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
      pm.pop();
      push(await snipPage(
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
          pop();
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

  ru.Down4PageWidget nodePage(BaseNode node) {
    return NodePage(
        node: node,
        openChat: (node_) => push(chatPage(node_ as ChatableNode)),
        openNode: (node_) => push(nodePage(node_)),
        payNode: (node) => push(moneyPage(node: node as Person)),
        back: pop);
  }

  ru.Down4PageWidget chatPage(ChatableNode node, [List<Down4Object>? fObjs]) {
    if (!_palettes.values.asIds().contains(node.id)) {
      writePalette2(node..save(), _palettes, bGen, refreshHome, h: true);
      localPalettesRoutine();
    }

    return ChatPage(
        node: node,
        fObjects: fObjs,
        openNode: (node_) => push(nodePage(node_)),
        send: (payload) async {
          await metaSend(payload, [node]);
          pm.popInBetween();
          refresh(chatPage(node));
        },
        subNodes: node is GroupNode
            ? node.group
                .map((e) => homeNode(e) ?? hiddenNode(e))
                .whereType<ChatableNode>()
                .toList()
            : null, // TODO, will need future nodes
        back: pop);
  }

  Future<ru.Down4PageWidget> snipView(ChatableNode node) async {
    if (node.snips.isEmpty) {
      await writePalette2(node, _palettes, bGen, refreshHome, h: true);
      pop();
    }
    final snip = node.snips.first;
    // consume the snip on the node
    node
      ..snips.remove(snip)
      ..save();

    MessageMedia? media = await snip.getLocalMessageMedia();
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
    Future<void> Function() back;
    Future<void> Function() next;
    if (media.isVideo) {
      var ctrl = VideoPlayerController.file(media.file!);
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      displayMedia = displayMediaBody(VideoPlayer(ctrl));

      back = () async {
        await ctrl.dispose();
        await writePalette2(node, _palettes, bGen, refreshHome, h: true);
        pop();
        media
          ?..references.remove(node.id)
          ..delete();
      };
      next = () async {
        if (node.snips.isEmpty) {
          await back();
        } else {
          await ctrl.dispose();
          refresh(await snipView(node));
          media
            ?..references.remove(node.id)
            ..delete();
        }
      };
    } else {
      await precacheImage(FileImage(media.file!), context);
      displayMedia = displayMediaBody(Image.file(media.file!));

      back = () async {
        await writePalette2(node, _palettes, bGen, refreshHome, h: true);
        pop();
        media
          ?..references.remove(node.id)
          ..delete();
      };
      next = () async {
        if (node.snips.isEmpty) {
          await back();
        } else {
          refresh(await snipView(node));
          media
            ?..references.remove(node.id)
            ..delete();
        }
      };
    }

    return SnipViewPage(
      displayMedia: displayMedia,
      text: text,
      back: back,
      next: next,
    );
  }

  @override
  Widget build(BuildContext context) {
    print("REBUILDING HOME");
    return Stack(children: pm.path.map((e) => pm.pages[e]!).toList());
  }
}
