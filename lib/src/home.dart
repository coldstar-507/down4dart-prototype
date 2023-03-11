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

  V get cv => vm.cv;

  void refresh(ru.Down4PageWidget p) {
    page = p;
    setState(() {});
  }

  void pop() async {
    vm.pop();
    final id = cv.id.split('-');
    final p0 = id[0];
    switch (p0) {
      case 'home':
        page = homePage();
        break;
      case 'chat':
        page = await chatPage(cv.node as ChatableNode);
        break;
      case 'node':
        page = nodePage(cv.node as BaseNode);
        break;
      case 'money':
        page = moneyPage();
        break;
      case 'search':
        page = searchPage();
        break;
      case 'forward':
        page = forwardPage(g.fo);
        break;
    }

    setState(() {});
  }

  Future<void> push(ru.Down4PageWidget p) async {
    if (p is NodePage || p is ChatPage) {
      // is this place on stack? we don't allow cycles
      var route = vm.views.map((e) => e.id).toList();
      if (route.contains(p.id)) {
        // is on stack, we pop all until we reach it
        while (route.last != p.id) {
          vm.pop();
          route.removeLast();
        }
        if (p is NodePage) {
          return refresh(nodePage(p.node));
        } else if (p is ChatPage) {
          return refresh(await chatPage(p.node));
        }
      }
    }

    if (p is HomePage) {
      page = p;
      vm.push(V(id: p.id, pages: [P(), P()]));
    } else if (p is LoadingPage2) {
      page = p;
      vm.push(V(id: p.id, pages: [P()]));
    } else if (p is MoneyPage) {
      page = p;
      vm.push(V(id: p.id, pages: [P(), P()]));
    } else if (p is ChatPage) {
      page = p;
      final node = p.node;
      if (node is GroupNode) {
        vm.push(V(id: p.id, pages: [P(), P()], node: node));
        for (final pal in allPalettes.those(node.group)) {
          await writePalette2(pal.node, vm.cv.pages[1].objects, bGen2,
              () async => refresh(await chatPage(node, p.fObjects)));
        }
      } else {
        vm.push(V(id: p.id, pages: [P()], node: p.node));
      }
      final ordered = node.messages.toList().reversed.toList();
      await writeMessages(
          limit: 20,
          ordered: ordered,
          node: node,
          state: vm.cv.pages[0].objects.cast(),
          refresh: () async => refresh(await chatPage(node, p.fObjects)),
          openNode: (node_) => push(nodePage(node_)));
    } else if (p is NodePage) {
      page = p;
      vm.push(V(id: p.id, pages: [P()], node: p.node));
    } else if (p is HyperchatPage) {
      page = p;
      vm.push(V(id: p.id, pages: [P()]));
    } else if (p is GroupPage) {
      page = p;
      vm.push(V(id: p.id, pages: [P()]));
    } else if (p is ForwardingPage) {
      page = p;
      vm.push(V(id: p.id, pages: [P()]));
    } else if (p is SnipViewPage) {
      page = p;
      g.vm.push(V(id: p.id, pages: [P()]));
    } else if (p is AddFriendPage) {
      page = p;
      vm.push(V(id: p.id, pages: [P()]));
    } else if (p is SnipCamera) {
      page = p;
      vm.push(V(id: p.id, pages: [P()]));
    }

    setState(() {});
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

  BaseNode? homeNode(ID id) => _homePalettes[id]?.node;
  BaseNode? hiddenNode(ID id) => _hiddenPalettes[id]?.node;

  Iterable<Palette2> get homePalettes => _homePalettes.values;
  Iterable<Palette2> get hiddenPalettes => _homePalettes.values;
  Iterable<Palette2> get allPalettes => homePalettes.followedBy(hiddenPalettes);
  List<Palette2> get formattedHomePalettes =>
      homePalettes.toList().formattedReverse();

  StreamSubscription? _messageListener;

  double get homeScroll => vm.home.pages[0].scroll;

  var _tec = TextEditingController();

  // ======================================================= INITIALIZATION ============================================================ //

  void refreshHome() => refresh(homePage());

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
      await writePalette2(node, _homePalettes, bGen, refreshHome, h: true);
    }

    if (init) refresh(homePage());

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
    print("HOMES = ${_homePalettes.keys.toList()}");
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
            asset: lastMsg?.reads[node.id] ?? true ? g.fifty : g.black,
            pressFunc: () async => push(await chatPage(node)),
            longPressFunc: () => node is Person ? push(nodePage(node)) : null,
            rightMost: true)
      ];
    }
  }

  Future<List<ButtonsInfo2>> bGen2(BaseNode node) async {
    return [
      ButtonsInfo2(
          asset: g.fifty,
          pressFunc: () => push(nodePage(node)),
          rightMost: true)
    ];
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
          await (value[1] as Message?)?.onReceipt(root: hcID);
          final hyperchat = Hyperchat(
              id: hcID,
              firstWord: firstWord,
              secondWord: secondWord,
              group: members.toSet(),
              messages: {msgID},
              snips: {},
              media: value.first as NodeMedia)
            ..save();

          await writePalette2(hyperchat, _homePalettes, bGen, refreshHome);
          await localPalettesRoutine();
          refresh(homePage());
        });
      } else if (eventPayload.first == "p") {
        // PAYMENT!
        final paymentID = eventPayload[1];
        final payment = await r.getPayment(paymentID);
        if (payment == null) return;
        await g.wallet.parsePayment(g.self.id, payment);
        if (page is MoneyPage) refresh(moneyPage(paymentUpdate: payment));
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

        await msg.onReceipt(root: root);

        rootNode
          ..messages.add(msg.id)
          ..updateActivity()
          ..save();

        await writePalette2(rootNode, _homePalettes, bGen, refreshHome,
            h: true);

        if (cv.id == 'home') {
          refresh(homePage());
        } else if (cv.id == 'chat' && cv.node!.id == root) {
          refresh(await chatPage(rootNode));
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

        await writePalette2(nodeRoot, _homePalettes, bGen, refreshHome,
            h: true);

        if (cv.id == 'home') refresh(homePage());
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
        if (cv.id == 'money') refresh(moneyPage());
      }
    }
  }

  Future<void> unselectSelection({bool updateActivity = true}) async {
    for (final p in List.of(homePalettes)) {
      if (p.selected) {
        await writePalette2(p.node, _homePalettes, bGen, refreshHome,
            h: true, sel: false);
      }
    }
    return;
  }

  // =========================== PAGES FUNCTIONS ======================== //

  Future<void> metaSend(Payload p, List<ChatableNode> targets) async {
    Message? msg = p.message;
    final targetIDs = targets.asIds();
    final selfInTargets = targetIDs.contains(g.self.id);
    final onlySendingToSelf = targetIDs.any((id) => id != g.self.id);

    final messagesToForward =
        p.forwardables.whereType<ChatMessage>().map((cm) => cm.message);

    for (final t in targets) {
      for (final m in messagesToForward.followedBy(msg == null ? [] : [msg])) {
        m.reads[t.id] = true;
        await m.save();
        t.messages.add(m.id);
        t.updateActivity();
        await t.save();
        await writePalette2(t, _homePalettes, bGen, refreshHome, h: true);
      }
    }

    // final pg = page;
    // if (pg is ChatPage && targets.single.id == pg.id) {
    //   if (messagesToForward.isNotEmpty || (msg?.nodes ?? []).isNotEmpty) {
    //     // means we were in forward view, so we pop the forwading view like this
    //     vm.popInBetween();
    //   }
    //   refresh(await chatPage(pg.node));
    // } else if (pg is HomePage) {
    //   refresh(homePage(prompt: "Sending messages"));
    // }

    // proceed to send
    Future(() async {
      List<Future<bool>> ss = [];
      if (!onlySendingToSelf) {
        if (msg != null) {
          ss.add(uploadMessage(msg, skipCheck: true));
        }
        if (p.media != null) ss.add(uploadOrUpdateMedia(p.media!));
        for (final m in messagesToForward) {
          m.refresh();
          await m.save();
          ss.add(uploadMessage(m, skipCheck: false));
        }
      }

      bool successfulUploads;
      if (ss.isEmpty) {
        successfulUploads = true;
      } else {
        successfulUploads =
            await Future.wait(ss).then((s) => s.every((b) => b));
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

      if (page is HomePage) refresh(homePage());

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
    });

    return;
  }

  Future<void> makeHyperchat(Payload p, Set<ID> grp) async {
    push(loadingPage());
    final prompts = await ru.randomPrompts(10);
    final hc = await r.getHyperchat(prompts);
    if (hc == null) {
      vm.popUntilHome();
      await unselectSelection(updateActivity: false);
      refresh(homePage(prompt: "Failed to create hyperchat!"));
      return;
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

    final msg = p.message;
    final msgs = p.forwardables
        .whereType<ChatMessage>()
        .map((cm) => cm.message)
        .followedBy(msg == null ? [] : [msg]);

    for (final m in msgs) {
      m.reads[hcID] = true;
      await m.save();
    }

    final hyper = Hyperchat(
        id: hcID,
        firstWord: hc.second.first,
        secondWord: hc.second.second,
        group: grp,
        messages: Set<ID>.from(msgs.map((m) => m.id)),
        snips: {},
        media: hcMedia)
      ..save();

    unselectSelection();
    vm.popUntilHome();
    push(await chatPage(hyper));

    await writePalette2(hyper, _homePalettes, bGen, refreshHome);

    final success = await uploadHyperchatMedia(hcMedia);
    if (!success) {
      _homePalettes.remove(hyper.id);
      hyper.delete();
      vm.popUntilHome();
      return refresh(homePage(prompt: "Failed to upload Hyperchat"));
    }

    await metaSend(p, [hyper]);
    refresh(await chatPage(hyper));
    return;
  }

  Future<void> makeGroup(Group group, Payload p) async {
    push(loadingPage());
    final success = await uploadNode(group);
    if (success) {
      await metaSend(p, [group]);
      await writePalette2(group, _homePalettes, bGen, refreshHome);
      await unselectSelection();
      vm.popUntilHome();
      push(nodePage(group));
    } else {
      vm.popUntilHome();
      refresh(homePage(prompt: "Failed to create group"));
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
    vm.popUntilHome();
    refresh(homePage(prompt: "Sent ping"));
  }

  // ============================== PAGES ============================== //

  ru.Down4PageWidget homePage({String? prompt, List<Down4Object>? fObjs}) {
    return HomePage(
      forward: (f) => push(forwardPage(f)),
      openNode: (n, f) async => push(await chatPage(n, f)),
      send: (p, t) async {
        await metaSend(p, t);
        await unselectSelection(updateActivity: true);
        vm.popUntilHome();
        refresh(homePage(prompt: "Sent messages!"));
      },
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
            _homePalettes.remove(p.node.id);
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
        homePalettes: formattedHomePalettes.reversed.toList(),
        fObjects: forwardingObjects,
        openNode: (fObjects, node) async =>
            push(await chatPage(node, fObjects)),
        hyper: (fObjects, transition) =>
            push(hyperchatPage(fObjects, transition)),
        forward: (p, t) async {
          await metaSend(p, t);
          await unselectSelection();
          vm.popUntilHome();
          refresh(homePage(prompt: "Forwarded messages"));
        },
        back: pop);
  }

  ru.Down4PageWidget paymentPage(Down4Payment payment) {
    return PaymentPage(
      ok: () {
        vm.popUntilHome();
        refresh(homePage());
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
          vm.popUntilHome();
          refresh(homePage(prompt: "Sent payment"));
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
          unselectSelection(updateActivity: true);
          vm.popUntilHome();
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
        initialOffset: transition.scroll,
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
              await writePalette2(node, _homePalettes, bGen, refreshHome,
                  h: true);
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
      pop();
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
        openChat: (node_) async => push(await chatPage(node_ as ChatableNode)),
        openNode: (node_) => push(nodePage(node_)),
        payNode: (node) => push(moneyPage(node: node as Person)),
        back: pop);
  }

  Future<ru.Down4PageWidget> chatPage(ChatableNode node,
      [List<Down4Object>? fObjs]) async {
    final cp = page;
    if (cp is ChatPage && cp.node.id == node.id) {
      // is a reload, load all new messages
      final state = cv.pages[0].objects.cast<ID, ChatMessage>();
      final loaded = state.keys.toSet();
      final ordered = node.messages.toList().reversed.toList();
      List<ID> toLoad = [];
      for (final id in ordered) {
        if (!loaded.contains(id)) toLoad.add(id);
      }
      await writeMessages(
          limit: toLoad.length,
          node: node,
          ordered: toLoad,
          state: state,
          refresh: () async => refresh(await chatPage(node, fObjs)),
          openNode: (node_) => push(nodePage(node_)));
    }

    return ChatPage(
        onPageChange: (i) => print("TODO $i"),
        messages: vm.cv.pages[0].objects.cast(),
        ordered: node.messages.toList().reversed.toList(),
        members: node is GroupNode
            ? vm.cv.pages[1].objects.cast<ID, Palette2>().values.toList()
            : null,
        loadMore: ({limit}) async {
          await writeMessages(
              limit: limit ?? 20,
              ordered: node.messages.toList().reversed.toList(),
              node: node,
              state: vm.cv.pages[0].objects.cast(),
              refresh: () async => refresh(await chatPage(node, fObjs)),
              openNode: (node_) => push(nodePage(node_)));
          refresh(await chatPage(node, fObjs));
        },
        node: node,
        fObjects: fObjs,
        openNode: (node_) => push(nodePage(node_)),
        send: (payload) async {
          await metaSend(payload, [node]);
          refresh(await chatPage(node, fObjs));
        }, // TODO, will need future nodes
        back: pop);
  }

  Future<ru.Down4PageWidget> snipView(ChatableNode node) async {
    if (node.snips.isEmpty) {
      await writePalette2(node, _homePalettes, bGen, refreshHome, h: true);
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
        await writePalette2(node, _homePalettes, bGen, refreshHome, h: true);
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
        await writePalette2(node, _homePalettes, bGen, refreshHome, h: true);
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
    return page;
  }
}
