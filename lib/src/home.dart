import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cbl/cbl.dart';
import 'package:down4/src/bsv/_bsv_utils.dart';
import 'package:flutter/material.dart';
import 'package:down4/src/data_objects.dart';
import 'package:video_player/video_player.dart';

import 'couch.dart';
import 'globals.dart';
import 'web_requests.dart' as r;
import '_dart_utils.dart';
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
import 'render_objects/_render_utils.dart' as ru;
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

  // view manager getters
  ViewManager viewManager = ViewManager()
    ..push(ViewState(id: "home", pages: [PageState(), PageState()]));
  Iterable<String> get route => viewManager.route;
  ViewState get homeView => viewManager.home;
  PageState get homePageState => homeView.currentPage;
  ViewState get currentView => viewManager.currentView;

  // homestate getters
  Map<ID, Palette2> get _homePalettes => homeView.pages[0].objects.cast();
  Map<ID, Palette2> get _hiddenPalettes => homeView.pages[1].objects.cast();
  Map<ID, Palette2> get _all => {..._homePalettes, ..._hiddenPalettes};
  Iterable<Palette2> get homePalettes => _homePalettes.values;
  Iterable<Palette2> get selectedHome => homePalettes.selected();
  List<Palette2> get formattedHome => homePalettes.toList().formatted();

  void setPage(ru.Down4PageWidget p) {
    page = p;
    setState(() {});
  }

  void back({required bool withPop, List<Down4Object>? f}) async {
    ViewState? popedView;
    if (withPop) popedView = viewManager.pop();
    final pID = popedView?.id.split('-');
    final pp0 = pID?.first;
    final n = popedView?.node;
    if (pID != null && pID.length > 1 && pp0 == "chat" && n is Chatable) {
      popedView?.chat?.second.cancel();
      await writeHomePalette(n, _homePalettes, bGen, rfHome);
    }
    final id = currentView.id.split('-');
    final p0 = id.first;
    switch (p0) {
      case 'home':
        return setPage(homePage());
      case 'chat':
        final node = currentView.node as Chatable;
        return setPage(chatPage(node, fo: f, isReload: true));
      case 'node':
        final node = currentView.node as FireNode;
        return setPage(nodePage(node));
      case 'money':
        return setPage(moneyPage());
      case 'search':
        return setPage(searchPage());
      case 'forward':
        return setPage(forwardPage(f ?? []));
    }
  }

  Transition homeTransition() {
    print("HOME PRE $_homePalettes}");
    print("HIDDEN PRE $_hiddenPalettes}");
    return selectionTransition(
        originalList: formattedHome,
        state: _homePalettes,
        hiddenState: _hiddenPalettes,
        scrollOffset: homePageState.scroll);
  }

  // Iterable<Palette2> get homePalettes => _homePalettes.values;
  // Iterable<Palette2> get selectedHome => homePalettes.where((p) => p.selected);
  // Iterable<Palette2> get hiddenPalettes => _hiddenPalettes.values;
  // Iterable<Palette2> get allPalettes => homePalettes.followedBy(hiddenPalettes);
  // Iterable<ID> get allIDs => allPalettes.map((p) => p.id);
  // List<Palette2> get formattedHomePalettes => homePalettes.toList()
  //   ..sort((p1, p2) => p1.node.activity.compareTo(p2.node.activity));

  // Pair<List<ID>, StreamSubscription<QueryChange<ResultSet>>>? currentChat;

  StreamSubscription? _messageListener, _savedImageIDs, _savedVideoIDs;

  void homeScrollToZero() => homePageState.scroll = 0;

  // ======================================================= INITIALIZATION ============================================================ //

  void rfHome() => setPage(homePage());

  void loadSavedMediasListeners() async {
    final imageIDs = await savedMediaIDs(isVideo: false);
    _savedImageIDs = imageIDs.listen((event) async {
      final ar = await event.results.allResults();
      g.savedImageIDs = ar.map((e) => e.string("id")!).toList();
    });

    final videoIDs = await savedMediaIDs(isVideo: true);
    _savedVideoIDs = videoIDs.listen((event) async {
      final ar = await event.results.allResults();
      g.savedVideoIDs = ar.map((e) => e.string("id")!).toList();
      // ids.forEach((id) async {
      //   final m = await global<FireMedia>(id);
      //   try {
      //     File(m!.videoPath).delete();
      //     m.delete();
      //   } catch (e) {
      //     print("Error $e");
      //   }
      // });
    });
  }

  @override
  void initState() {
    super.initState();
    loadSavedMediasListeners();
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
    _savedImageIDs?.cancel();
    _savedVideoIDs?.cancel();
    super.dispose();
  }

  Future<void> localPalettesRoutine({bool init = false}) async {
    final allHomeNodes = (await loadHome()).followedBy([g.self]);
    final Iterable<Groupable> groups = allHomeNodes.whereType<Groupable>();
    final Iterable<User> users = allHomeNodes.whereType<User>();
    final Iterable<User> hiddenUsers = users.where((u) => u.isHidden);

    final homeIDs = allHomeNodes.asIDs().toSet();
    await globall<FireMedia>(allHomeNodes.map((e) => e.mediaID).whereType(),
        doFetch: true, doMergeIfFetch: true, mediaInfo: const Pair(true, null));
    globall<FireMedia>(hiddenUsers.map((e) => e.mediaID).whereType(),
        doFetch: true, doMergeIfFetch: true, mediaInfo: const Pair(true, null));

    final hiddenIDs = hiddenUsers.asIDs().toSet();
    final shouldDump = hiddenIDs.intersection(homeIDs);
    final allLocal = homeIDs.followedBy(hiddenIDs).toSet();

    final groupIds = groups.map((e) => e.group).expand((id) => id).toSet();
    final calcHidden = groupIds.difference(homeIDs);

    final stayHidden = hiddenIDs.intersection(calcHidden);

    final hiddenToDump = hiddenIDs.difference(stayHidden);
    final hiddenToFetch = calcHidden.difference(allLocal);

    for (final dump in hiddenToDump.followedBy(shouldDump)) {
      gdb<FireNode>().purgeDocumentById(dump);
    }

    for (final n in allHomeNodes) {
      if (n is User && n.isHidden) {
        await writeHomePalette(n, _hiddenPalettes, null, null);
      } else {
        await writeHomePalette(n, _homePalettes, bGen, rfHome);
      }
    }

    if (init) setPage(homePage());

    final fetchedNodes = await globall<Chatable>(hiddenToFetch,
        doFetch: true, doMergeIfFetch: true, doHideIfFetch: true);
    for (final n in fetchedNodes) {
      writeHomePalette(n, _hiddenPalettes, null, null);
    }

    print("HIDDEN = ${_hiddenPalettes.keys.toList()}");
    print("HOMES = ${_homePalettes.keys.toList()}");
  }

  Future<List<ButtonsInfo2>> bGen(Chatable n,
      {Pair<FireMessage?, Iterable<ID>>? chatInfo}) async {
    final ci = chatInfo ?? await n.homeChatInfo();
    final lastMsg = ci.first;
    final snips = ci.second;
    if (snips.isNotEmpty) {
      return [
        ButtonsInfo2(
            asset: g.red,
            pressFunc: () async => setPage(await snipView(n)),
            longPressFunc: () => n is Personable ? setPage(nodePage(n)) : null,
            rightMost: true)
      ];
    } else {
      return [
        ButtonsInfo2(
            asset: lastMsg?.isRead ?? true ? g.fifty : g.black,
            pressFunc: () => setPage(chatPage(n, isPush: true)),
            longPressFunc: () =>
                n is Personable ? setPage(nodePage(n, isPush: true)) : null,
            rightMost: true)
      ];
    }
  }

  List<ButtonsInfo2> bGen2(FireNode n) {
    return [
      ButtonsInfo2(
          asset: g.fifty,
          pressFunc: () => setPage(nodePage(n, isPush: true)),
          rightMost: true)
    ];
  }

  void connectToMessages() {
    var msgQueue = db.child("Users").child(g.self.id).child("M");

    _messageListener = msgQueue.onChildAdded.listen((event) async {
      print("New message!");
      final eventKey = event.snapshot.key;
      final eventPayload = (event.snapshot.value as String).split("%");
      msgQueue.child(eventKey!).remove(); // consume it
      print("KEY = $eventKey\nPAYLOAD = $eventPayload\n");

      // if (eventPayload.first == "h") {
      //   // "h-${msg.id}-$hcID-${hyper.media.id}-${hyper.firstWord}-${hyper.secondWord}-${hyper.group.join(" ")}";
      //   // HYPERCHAT
      //   final msgID = eventPayload[1];
      //   final hcID = eventPayload[2];
      //   final mediaID = eventPayload[3];
      //   final firstWord = eventPayload[4];
      //   final secondWord = eventPayload[5];
      //   final members = eventPayload[6].split(" ");
      //
      //   final hcMedia = downloadMessageMediaAsNodeMedia(mediaID);
      //   final msg = downloadMessage(msgID);
      //
      //   Future.wait([hcMedia, msg]).then((value) async {
      //     if (value.first == null) return;
      //     await (value[1] as FireMessage?)?.onReceipt(root: hcID);
      //     final hyperchat = Hyperchat(
      //         id: hcID,
      //         firstWord: firstWord,
      //         secondWord: secondWord,
      //         group: members.toSet(),
      //         messages: {msgID},
      //         snips: {},
      //         media: value.first as FireMedia)
      //       ..save();
      //
      //     await writeHomePalette(hyperchat, _homePalettes, bGen, rfHome);
      //     await localPalettesRoutine();
      //     setPage(homePage());
      //   });
      // }
      if (eventPayload.first == "p") {
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
        // get the message, we wait until we get the maybe associated media
        // before merging, the reason for that is merging would trigger
        // reload chat if we are in the chat, but we want to have the media
        // before reloading the chat
        final msg = await global<FireMessage>(msgID, doFetch: true);
        if (msg == null) return;

        // get the node
        final node = await global<Chatable>(msg.root,
            doFetch: true, doMergeIfFetch: true);
        if (node == null) return;

        // if is snip from a user that isn't a friend, we don't predownload
        if (msg.isSnip && node is User && !node.isFriend) {
          await global<FireMedia>(node.mediaID,
              doFetch: true,
              doMergeIfFetch: true,
              mediaInfo: Pair(false, msg.onlineMediaID));
        } else {
          await global<FireMedia>(node.mediaID,
              doFetch: true,
              doMergeIfFetch: true,
              mediaInfo: Pair(true, msg.onlineMediaID));
        }
        // get the node media
        await global<FireMedia>(node.mediaID,
            doFetch: true,
            doMergeIfFetch: true,
            mediaInfo: const Pair(true, null));

        // get the msgMedia
        await global<FireMedia>(msg.mediaID,
            doFetch: true,
            doMergeIfFetch: true,
            mediaInfo: Pair(true, msg.onlineMediaID));

        await msg.merge();

        await writeHomePalette(
            node..updateActivity(), _homePalettes, bGen, rfHome);

        if (page is HomePage) setPage(homePage());
      }
      // else if (eventPayload.first == "s") {
      // final String mediaID = eventPayload[1];
      // final String root = eventPayload[2];
      //
      // final (snip, _) = await global<FireMedia>(mediaID,
      //     fetch: true, merge: true, mediaData: true);
      // if (snip == null) return;
      //
      // final (nodeRoot, gt) =
      //     await global<Chatable>(root, fetch: true, merge: true);
      // if (nodeRoot == null) return;
      // nodeRoot.addSnipRef(snip.id);
      // snip.addReference(nodeRoot.id);
      //
      // FireMedia? nodeMedia;
      // if (gt == GetType.fetch) {
      //   (nodeMedia, _) = await global<FireMedia>(nodeRoot.media,
      //       fetch: true, merge: true, mediaData: true, nodesMedia: true);
      //   nodeMedia?.addReference(nodeRoot.id);
      // }
      // final p = Palette2<Chatable>(node: nodeRoot, image: nodeMedia);
      // await writeHomePalette(p, _homePalettes, bGen, rfHome);
      //
      // if (cv.id == 'home') setPage(homePage());
      // }
      // else if (eventPayload.first == "f") {
      //   // FORWARDED MESSAGE
      //   final msgID = eventPayload[1];
      //   final root = eventPayload[2];
      //   final forwardedFrom = eventPayload[3];
      //   final msg = await downloadMessage(msgID);
      //   if (msg == null) return;
      //   msg.forwarderID = forwardedFrom;
      //   return handleMessage(msg, root);
      // }
    });
  }

  // =============================== UTILS ============================== //

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
    for (final p in List.of(homePalettes)) {
      if (p.selected) {
        await writeHomePalette(p.node as Chatable, _homePalettes, bGen, rfHome,
            sel: false);
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

  Future<void> metaSend(Payload p, Iterable<Chatable> targets) async {
    final targetIDs = targets.asIDs();
    final selfInTargets = targetIDs.contains(g.self.id);
    print("Target IDs = $targetIDs");

    final messagesToForward = p.forwardables.whereType<ChatMessage>();

    // helper that will send the messages only after the successful uploads
    void s(r.MessageRequest req, Chatable t, FireMessage msg) async {
      final success = await req.process();
      if (success) {
        await writeHomePalette(t, _homePalettes, bGen, rfHome);
        if (!msg.isSnip) {
          await msg.markSent();
          if (page is ChatPage && currentView.node?.id == t.id) {
            print("RELOADING CHAT");
            setPage(chatPage(t, msgRe: msg, isReload: true));
          }
        }
      }
      if (page is HomePage) setPage(homePage(prompt: "Sent!"));
    }

    List<Future<bool>> u = [];
    List<void Function()> awatingProcess = [];
    // Here, we will iterate over each target and each messages we are sending
    // We can be sending multiple messages to multiple chats
    // There are 2 types of messages, the normal and the forwarded
    // There can only be one normal and multiple forwarded
    // We still make a new message for every chat, in other words...
    // ...Chats don't share messages
    // Normal and Forwarded have different bodies for notification so...
    // Function has some redundant code, but we try make it minimal
    // We iterate over targets once, saving the messages locally and make...
    // ... the upload requests
    // Function then returns, but calls a future that will process sending...
    // ...only after the uploads are successful
    // After sending, each message will be marked as sent

    // We start with uploading the payload media if there is one
    // If it's a snip, we can know because there's the media cached path
    // If it's not a snip, it should be pre-written
    final bool isSnip = p.isSnip;
    final bool doSave = !isSnip || selfInTargets;
    if (p.media != null) {
      u.add(uploadMedia(p.media!..cache(), isSnip: isSnip));
      if (doSave && p.media?.cachePath != null) p.media!.writeFromCachedPath();
    }
    for (final t in targets) {
      t.updateActivity();
      final ourMsg = p.makeMsg(root: t.id, onlineMediaID: p.media?.onlineID)
        ?..cache();
      print("OUR MESSAGE = ${ourMsg?.toJson()}");

      if (doSave) await ourMsg?.merge();
      // this way we can send snips to ourself
      final dontMarkRead = isSnip && t.id == g.self.id;
      if (!dontMarkRead) await ourMsg?.markRead();

      FireNode nodeRef = t;
      List<ID> receipients;
      String h;
      if (nodeRef is Groupable) {
        receipients = List<ID>.from(nodeRef.group)..remove(g.self.id);
        h = "${g.self.displayName} ${isSnip ? 'pinged' : 'in'} ${nodeRef.displayName}";
      } else {
        receipients = [nodeRef.id];
        h = "${g.self.displayName}${isSnip ? ' pinged you' : ''}";
      }

      if (ourMsg != null) {
        if (t.id != g.self.id) {
          u.add(uploadMessage(ourMsg));

          final req = r.MessageRequest(
              sender: g.self.id,
              targets: receipients,
              header: h,
              body: (ourMsg.text ?? "").isEmpty ? "&attachment" : ourMsg.text!,
              data: "m%${ourMsg.id}");

          awatingProcess.add(() => s(req, t, ourMsg));
        }
      }

      for (final m in messagesToForward) {
        // markRead will save the message locally
        // we mark read every new forwarded messages, no exceptions
        final fMedia = m.mediaInfo?.media;
        final fMsg = m.message.forwarded(g.self.id, t.id)
          ..cache()
          ..markRead();
        // we don't send the message if the receipient is us
        if (t.id != g.self.id) {
          u.add(uploadMessage(fMsg));
          if (fMedia != null) u.add(uploadMedia(fMedia));

          final req = r.MessageRequest(
              sender: g.self.id,
              targets: receipients,
              header: h,
              body: ">> forwarded message >>",
              data: "m%${fMsg.id}");

          awatingProcess.add(() => s(req, t, fMsg));
        }
      }
    }

    Future(() async {
      final finishedUploads = await Future.wait(u);
      if (finishedUploads.every((success) => success)) {
        for (var req in awatingProcess) {
          req.call();
        }
      }
    });

    // // proceed to send
    // Future(() async {
    //   List<Future<bool>> ss = [];
    //   if (!onlySendingToSelf) {
    //     if (msg != null) ss.add(uploadMessage(msg, skipCheck: true));
    //     if (p.media != null) ss.add(uploadMedia(p.media!));
    //     for (final m in messagesToForward) {
    //       m.refresh();
    //       await m.save();
    //       ss.add(uploadMessage(m, skipCheck: false));
    //     }
    //   }
    //
    //   bool success;
    //   if (ss.isEmpty) {
    //     success = true;
    //   } else {
    //     success = await Future.wait(ss).then((s) => s.every((b) => b));
    //   }
    //
    //   print("nUploads = ${ss.length}, success = $success");
    //   if (!success) return;
    //   Map<ID, Future<bool>> reqs = {};
    //   Map<ID, FireMessage> msgs = messagesToForward
    //       .followedBy(msg == null ? [] : [msg])
    //       .toList()
    //       .asMap()
    //       .map((key, value) => MapEntry(value.id, value));
    //
    //   for (final m in messagesToForward) {
    //     for (final node in targets) {
    //       final reqKey = "${node.id}%${m.id}";
    //       if (node is Groupable) {
    //         final t = List<ID>.from(node.group)..remove(g.self.id);
    //         final req = r.MessageRequest(
    //             sender: g.self.id,
    //             targets: t,
    //             header: "${g.self.name} in ${node.name}",
    //             body: ">> forwarded message >>",
    //             data: "f%${m.id}%${node.id}%${g.self.id}");
    //         reqs[reqKey] = req.process();
    //       } else if (node.id == g.self.id) {
    //         reqs[reqKey] = Future.value(true);
    //       } else {
    //         final req = r.MessageRequest(
    //             sender: g.self.id,
    //             targets: [node.id],
    //             header: g.self.name,
    //             body: ">> forwarded message >>",
    //             data: "f%${m.id}%${g.self.id}%${g.self.id}");
    //         reqs[reqKey] = req.process();
    //       }
    //     }
    //   }
    //
    //   if (msg != null) {
    //     for (final node in targets) {
    //       final reqKey = "${node.id}%${msg.id}";
    //       final b = (msg.text ?? "").isNotEmpty ? msg.text! : "&attachment";
    //       if (node is Groupable) {
    //         final t = List<ID>.from(node.group)..remove(g.self.id);
    //         final req = r.MessageRequest(
    //             sender: g.self.id,
    //             targets: t,
    //             header: "${g.self.name} in ${node.name}",
    //             body: b,
    //             data: "m%${msg.id}%${node.id}");
    //         reqs[reqKey] = req.process();
    //       } else if (node.id == g.self.id) {
    //         reqs[reqKey] = Future.value(true);
    //       } else {
    //         final req = r.MessageRequest(
    //             sender: g.self.id,
    //             targets: [node.id],
    //             header: g.self.name,
    //             body: b,
    //             data: "m%${msg.id}%${g.self.id}");
    //         reqs[reqKey] = req.process();
    //       }
    //     }
    //   }
    //
    //   if (page is HomePage) setPage(homePage(prompt: "Sent!"));
    //
    //   Future(() => reqs.forEach((key, value) async {
    //         final d = key.split("%");
    //         final nodeID = d[0];
    //         final msgID = d[1];
    //         final msg = msgs[msgID]!;
    //         msg.sents[nodeID] = await value;
    //         await msg.save();
    //
    //         // update chat
    //         final pRef = page;
    //         if (pRef is ChatPage && pRef.node.id == nodeID) {
    //           setPage(chatPage(pRef.node, msgRe: msg));
    //         }
    //       }));
    // });

    return;
  }

  Future<void> makeHyperchat(Payload p, Set<ID> grp) async {
    setPage(loadingPage());
    final prompts = await ru.randomPrompts(10);
    final hc = await r.getHyperchat(prompts);
    if (hc == null) {
      viewManager.popUntilHome();
      await unselectHomeSelection(updateActivity: false);
      setPage(homePage(prompt: "Failed to create hyperchat!"));
      return;
    }

    final hcID = sha1(hc.first).toBase58();
    final hcMedia = FireMedia(deterministicMediaID(hc.first, g.self.id),
        tinyThumbnail: ru.makeTiny(hc.first),
        mime: "image/png",
        ownerID: g.self.id,
        timestamp: makeTimestamp(),
        width: 512,
        height: 512);
    await hcMedia.write(imageData: hc.first);

    final hyper = Hyperchat(hcID,
        firstWord: hc.second.first,
        secondWord: hc.second.second,
        activity: makeTimestamp(),
        group: grp,
        mediaID: hcMedia.id);
    final uploads = [uploadMedia(hcMedia, isNode: true), uploadNode(hyper)];
    final success = (await Future.wait(uploads)).every((u) => u);

    if (!success) {
      hcMedia.delete();
      viewManager.popUntilHome();
      return setPage(homePage(prompt: "Failed to upload Hyperchat"));
    } else {
      hyper.merge();
      gCache(hcMedia);
      gCache(hyper);
    }

    await metaSend(p, [hyper]);
    unselectHomeSelection();
    viewManager.popUntilHome();
    setPage(chatPage(hyper, isPush: true));
    return;
  }

  Future<void> makeGroup(Group group, FireMedia m, Payload p) async {
    setPage(loadingPage());
    final uploads = [uploadMedia(m, isNode: true), uploadNode(group)];
    final success = (await Future.wait(uploads)).every((u) => u);

    if (success) {
      await group.merge();
      await m.merge();
      m.cache();
      group.cache();
      await metaSend(p, [group]);
      // await writeHomePalette(group, _homePalettes, bGen, rfHome);
      await unselectHomeSelection();
      viewManager.popUntilHome();
      setPage(chatPage(group, isPush: true));
    } else {
      viewManager.popUntilHome();
      setPage(homePage(prompt: "Failed to create group"));
    }
  }

  Future<void> ping(String text, Iterable<Chatable> targets) async {
    for (final t in targets) {
      final FireNode nodeRef = t;
      if (nodeRef is Groupable) {
        r.MessageRequest(
          sender: g.self.id,
          data: "",
          targets: nodeRef.group.toList()..remove(g.self.id),
          header: "${g.self.displayName} pinged ${nodeRef.displayName}",
          body: text,
        ).process();
      } else {
        r.MessageRequest(
          sender: g.self.id,
          data: "",
          targets: [t.id],
          header: "${g.self.displayName} pinged you",
          body: text,
        ).process();
      }
    }
    await unselectHomeSelection(updateActivity: true);
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

    final media = FireMedia(messagePushId(),
        tinyThumbnail: "",
        isSquared: false,
        ownerID: g.self.id,
        mime: mimetype,
        timestamp: timestamp,
        cachePath: path,
        isReversed: isReversed,
        text: text,
        width: size.width,
        height: size.height);
    // payload could potentially have forwards in a snip...
    final payload = Payload(
        isSnip: true, replies: null, forwards: null, text: null, media: media);
    await metaSend(payload, selectedHome.asNodes<Chatable>());

    // final success = await uploadMedia(media, isSnip: true);
    // if (!success) return print("Snip media upload unsucessful!");

    // var personTargets = <ID>[];
    // List<Future<bool>> successes = [];

    // final selectedPalettes = homePalettes.selected();
    // for (final node in selectedPalettes.asNodes()) {
    //   if (node is Groupable) {
    //     final targets = homePalettes.those(node.group).whereNodeIs<User>();
    //     successes.add(r.MessageRequest(
    //       sender: g.self.id,
    //       targets: targets.asIds().toList(),
    //       header: "${g.self.displayName} pinged ${node.displayName}",
    //       body: "&attachment",
    //       data: "s%${media.id}%${node.id}",
    //     ).process());
    //   } else {
    //     personTargets.add(node.id);
    //   }
    // }

    // if (personTargets.isNotEmpty) {
    //   successes.add(r.MessageRequest(
    //     sender: g.self.id,
    //     targets: personTargets,
    //     header: "${g.self.displayName} pinged you",
    //     body: "&attachment",
    //     data: "s%${media.id}%${g.self.id}",
    //   ).process());
    // }

    await unselectHomeSelection();
    viewManager.popUntilHome();
    setPage(homePage(prompt: "Pinged &attachment"));
  }

  // ============================== PAGES ============================== //

  ru.Down4PageWidget homePage({String? prompt}) {
    return HomePage(
      forward: (sel) => setPage(
        forwardPage(sel.whereNodeIs<Branchable>().toList(), isPush: true),
      ),
      openChat: (n, f) => setPage(chatPage(n, isPush: true)),
      send: (p, t) async {
        await metaSend(p, t);
        await unselectHomeSelection(updateActivity: true);
        viewManager.popUntilHome();
        setPage(homePage(prompt: "Sent messages!"));
      },
      homeState: homeView,
      hyperchat: () => setPage(hyperchatPage()),
      group: () => setPage(groupPage()),
      money: () => setPage(
        moneyPage(transition: homeTransition(), isPush: true),
      ),
      ping: (text) => ping(text, selectedHome.asNodes<Chatable>()),
      snip: () => setPage(snipPage()),
      search: () => setPage(searchPage(isPush: true)),
      delete: () async {
        for (final p in List<Palette2>.from(homePalettes)) {
          if (p.selected && p.id != g.self.id) {
            _homePalettes.remove(p.node.id);
            p.node.delete();
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
    Map<ID, Palette2> _fState() => currentView.currentPage.objects.cast();
    void rf() => setPage(forwardPage(fo));
    List<ButtonsInfo2> fbGen(Chatable c) {
      return [
        ButtonsInfo2(
            asset: g.fifty,
            rightMost: true,
            pressFunc: () => setPage(chatPage(c, fo: fo, isPush: true)))
      ];
    }

    if (isPush) {
      viewManager.popUntilHome();
      viewManager.push(ViewState(id: "forward", pages: [PageState()]));
      for (final c in formattedHome.asNodes<Chatable>()) {
        writePalette3<Chatable>(c, _fState(), fbGen, rf,
            pr: _homePalettes[c.id]?.messagePreview);
      }
    }

    return ForwardingPage(
        hiddenHomeState: _hiddenPalettes,
        viewState: viewManager.currentView,
        fObjects: fo,
        openChat: (fObjects, node) =>
            setPage(chatPage(node, fo: fObjects, isPush: true)),
        hyper: (fObjects, transition) =>
            setPage(hyperchatPage(fObjects, transition)),
        forward: (p, t) async {
          await metaSend(p, t);
          await unselectHomeSelection();
          homeScrollToZero();
          viewManager.popUntilHome();
          setPage(homePage(prompt: "Forwarded messages"));
        },
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget paymentPage(Down4Payment payment) {
    return PaymentPage(
      ok: () {
        viewManager.popUntilHome();
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
            header: "${g.self.displayName} payed you",
            body: pay.textNote,
          ).process();
          viewManager.popUntilHome();
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
    Personable? single,
    Down4Payment? paymentUpdate,
    // payment update is for when we are in money view, and
    // we receive an online payment, this let us update status with this new
    // payment, it would not be necessary if listeners work on lazy box, but
    // haven't found a way to make the listener work yet...
  }) {
    Map<ID, Palette2> people() => currentView.pages[0].objects.cast();
    Map<ID, Palette2> payments() => currentView.pages[1].objects.cast();
    void rf() => setPage(moneyPage());
    void openPay(Down4Payment payment) => setPage(paymentPage(payment));

    void loadSomePayments(int limit, [int ms = 0]) =>
        Future.delayed(Duration(milliseconds: ms), () async {
          await writePayments(payments(), openPay, limit);
          rf();
        });

    if (isPush) {
      viewManager.push(
        ViewState(id: "money", pages: [PageState(), PageState()]),
      );
      final users = transition?.trueTargets ?? (single != null ? [single] : []);
      for (final u in users) {
        writePalette3(u, people(), null, null);
      }
      loadSomePayments(5, 633);
    }

    if (paymentUpdate != null) loadSomePayments(1, 633);

    return MoneyPage(
        single: single,
        transition: transition,
        viewState: currentView,
        loadMorePayments: () async => loadSomePayments(8),
        onScan: (payment) async {
          await g.wallet.parsePayment(g.self.id, payment);
          loadSomePayments(1);
        },
        makePayment: (payment) async {
          await g.wallet.parsePayment(g.self.id, payment);
          unselectHomeSelection(updateActivity: true);
          viewManager.popUntilHome();
          setPage(paymentPage(payment));
        },
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget hyperchatPage([
    List<Down4Object>? fObjects,
    Transition? transition,
  ]) {
    final transition_ = transition ?? homeTransition();
    final pingGroup = transition_.trueTargets; // simply
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
        homePalettes: formattedHome);
  }

  ru.Down4PageWidget searchPage({bool isPush = false}) {
    if (isPush) {
      viewManager.push(ViewState(id: "search", pages: [PageState()]));
    }

    void rf() => setPage(searchPage());
    Map<ID, Palette2> searchs() => currentView.currentPage.objects.cast();

    return AddFriendPage(
        viewState: currentView,
        search: (strIDs) async {
          final ids = strIDs.split(" ").toSet();
          final inHome = _all.those(ids).noNull().whereNodeIs<Personable>();
          final toFetch = ids.difference(inHome.asIds().toSet());

          final fetchedNodes = await r.fetchNodes(toFetch);
          for (final fn in fetchedNodes) {
            fn.second?.cache();
            writePalette3(fn.first..cache(), searchs(), bGen2, rf);
          }
          rf();
        },
        onScan: (n) async {
          writePalette3(n, searchs(), bGen2, rf);
          rf();
        },
        openNode: (node) => setPage(nodePage(node, isPush: true)),
        add: (selectedPals) async {
          for (final n in selectedPals) {
            if (n is User) n.updateFriendStatus(true);
            writePalette3(n, searchs(), bGen2, rf, sel: false);
            writeHomePalette(n, _homePalettes, bGen, rfHome);
          }
          rf();
          localPalettesRoutine();
        },
        forwardNodes: (pals) => setPage(forwardPage(pals, isPush: true)),
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget snipPage({
    CameraController? ctrl,
    int camera = 0,
    ResolutionPreset res = ResolutionPreset.high,
    bool reload = false,
  }) {
    // void nextRes() {
    //   snipPage(
    //     ctrl: ctrl,
    //     camera: camera,
    //     reload: true,
    //     res: res == ResolutionPreset.low
    //         ? ResolutionPreset.medium
    //         : res == ResolutionPreset.medium
    //             ? ResolutionPreset.high
    //             : ResolutionPreset.low,
    //   );
    // }

    // Future<void> nextCam() async {
    //   setPage(await snipPage(
    //       ctrl: ctrl, camera: (camera + 1) % 2, reload: true, res: res));
    // }
    return SnipCamera(
      // maxZoom: await ctrl!.getMaxZoomLevel(),
      // minZoom: await ctrl.getMinZoomLevel(),
      // camNum: camera,
      cameraCallBack: sendSnip,
      // ctrl: ctrl,
      // nextRes: nextRes,
      // flip: nextCam,
      cameraBack: () {
        ctrl?.dispose();
        back(withPop: false);
      },
    );

    Future<ru.Down4PageWidget> snip() async {
      return SnipCamera(
        // maxZoom: await ctrl!.getMaxZoomLevel(),
        // minZoom: await ctrl.getMinZoomLevel(),
        // camNum: camera,
        cameraCallBack: sendSnip,
        // ctrl: ctrl,
        // nextRes: nextRes,
        // flip: nextCam,
        cameraBack: () {
          ctrl?.dispose();
          back(withPop: false);
        },
      );
    }

    // if (ctrl == null || reload) {
    //   await ctrl?.dispose();
    //   ctrl = CameraController(g.cameras[camera], res);
    //   await ctrl.initialize();
    // }
    //
    // return snip();
  }

  ru.Down4PageWidget nodePage(FireNode n, {bool isPush = false}) {
    if (isPush) {
      final id = "node-${n.id}";
      final r = List<String>.from(route);
      if (r.contains(id)) {
        // we don't allow cycles
        while (route.last != id) {
          final v = viewManager.pop();
          final l = r.removeLast();
          print("ROUTE = $route");
          print("POPPED VIEW ${v?.id}");
          print("POPPED $l");
        }
      } else {
        viewManager.push(
          ViewState(id: "node-${n.id}", pages: [PageState()], node: n),
        );
      }
    }

    return NodePage(
        viewState: currentView,
        openChat: (p_) => setPage(chatPage(p_, isPush: true)),
        openNode: (p_) => setPage(nodePage(p_, isPush: true)),
        payNode: (p_) => setPage(moneyPage(single: p_, isPush: true)),
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget chatPage(
    Chatable c, {
    bool isPush = false,
    bool isReload = false,
    bool rewriteMsgWithNodes = false,
    FireMessage? msgRe,
    List<Down4Object>? fo,
  }) {
    ID chatID() => "chat-${c.id}";
    ViewState chat() => viewManager.at(chatID());

    List<ID> orderedMsgsIDs() => chat().chat?.first ?? [];
    Map<ID, ChatMessage> messages() => chat().pages[0].objects.cast();
    Map<ID, Palette2> members() => chat().pages[1].objects.cast();
    Set<ID> msgsWithVideos() => chat().refs("messages_with_videos");
    Set<ID> msgsWithNodes() => chat().refs("messages_with_nodes");

    bool forwarding() => fo != null;

    void opn(FireNode n_) => setPage(nodePage(n_, isPush: true));
    void Function(FireNode)? openNode() => forwarding() ? null : opn;
    List<ButtonsInfo2> Function(Chatable)? cbGen = forwarding() ? null : bGen2;

    void refreshChat({bool stopVid = false}) async {
      final pg = page;
      if (pg is! ChatPage || pg.viewState.node!.id != c.id) return;

      if (stopVid) {
        for (final v in msgsWithVideos()) {
          messages()[v] = messages()[v]!.onPageTransition();
        }
      }

      setPage(chatPage(c, fo: pg.fo));
    }

    void writeGroupNodesIfGroup() {
      final FireNode ref = c;
      if (ref is Groupable) {
        for (final n in _all.those(ref.group).noNull().asNodes<Personable>()) {
          writePalette3(n, members(), cbGen, refreshChat);
        }
      }
    }

    Future<void> loadMore([int i = 20]) async {
      await writeMessages(
          limit: i,
          ch: c,
          ordered: orderedMsgsIDs(),
          state: messages(),
          withNodes: msgsWithNodes(),
          videos: msgsWithVideos(),
          refresh: refreshChat,
          openNode: openNode());
      refreshChat();
    }

    void reloadChat() {
      Future(() async {
        // is a reload, load all new messages
        final pg = page;
        if (pg is! ChatPage || pg.viewState.node?.id != c.id) return;
        final loaded = messages().keys;
        List<ID> toLoad = [];
        for (final id in orderedMsgsIDs()) {
          if (!loaded.contains(id)) {
            toLoad.add(id);
          } else {
            break;
          }
        }
        await writeMessages(
            limit: toLoad.length,
            ch: c,
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
              r.map((e) => e.string("id")!).toList(),
              chat().chat!.second,
            );
            reloadChat();
          }),
        );

        // if is group, write members
        writeGroupNodesIfGroup();
        // write the messages
        await writeMessages(
            limit: 20,
            ordered: currentMessages,
            ch: c,
            state: messages(),
            videos: msgsWithVideos(),
            withNodes: msgsWithNodes(),
            refresh: refreshChat,
            openNode: openNode());

        refreshChat();
      });
    }

    if (isPush) {
      final wasAlreadyOnRoute = route.contains(chatID());
      viewManager.push(
        ViewState(id: chatID(), pages: [PageState(), PageState()], node: c),
      );
      if (wasAlreadyOnRoute) {
        reloadChat();
      } else {
        initChat();
      }
    }

    if (msgRe != null) {
      messages()[msgRe.id] = messages()[msgRe.id]!.reloaded(msgRe);
    }

    if (isReload) reloadChat();

    if (rewriteMsgWithNodes) {
      for (final id in msgsWithNodes()) {
        messages()[id] = messages()[id]!.withOpenNode(open: openNode());
      }
      writeGroupNodesIfGroup();
      refreshChat();
    }

    return ChatPage(
        onPageChange: (ix) {
          refreshChat(stopVid: true);
          chat().currentIndex = ix;
        },
        loadMore: loadMore,
        viewState: viewManager.at(chatID()),
        fo: fo,
        openNode: opn,
        send: (payload) async {
          await metaSend(payload, [c]);
          // poping the forwarding page
          if (forwarding()) viewManager.popInBetween();
          setPage(chatPage(c,
              isReload: true,
              rewriteMsgWithNodes: payload.forwardables.isNotEmpty));
        }, // TODO, will need future nodes
        back: () => back(withPop: true, f: fo));
  }

  Future<ru.Down4PageWidget> snipView(Chatable node, [List<ID>? l]) async {
    final unreadSnips = l ?? (await node.unreadSnipIDs()).toList();
    print("Unread snips=$unreadSnips");
    if (unreadSnips.isEmpty) {
      await writeHomePalette(node, _homePalettes, bGen, rfHome);
      setPage(homePage());
    }
    final s = await global<FireMessage>(unreadSnips.first, doCache: false);
    s!.markRead();

    final m = await global<FireMedia>(s.mediaID,
        doCache: false, doFetch: true, mediaInfo: Pair(false, s.onlineMediaID));

    if (m == null) return snipView(node);

    // final scale = m.aspectRatio * g.sizes.fullAspectRatio;
    // Widget displayMediaBody(Widget child) => Center(
    //       child: Transform(
    //         alignment: Alignment.center,
    //         transform: Matrix4.rotationY(m.isReversed ? math.pi : 0),
    //         child: Transform.scale(
    //           scale: scale > 1 ? scale : 1 / scale,
    //           child: SizedBox(
    //               height: m.aspectRatio * g.sizes.w,
    //               width: g.sizes.w,
    //               child: child),
    //         ),
    //       ),
    //     );

    VideoPlayerController? vpc;
    Future<Widget> Function(FireMedia m) displayBody;

    if (m.isVideo) {
      vpc = await m.videoController;
      if (vpc == null) return snipView(node);
      await vpc.initialize();
      await vpc.setLooping(true);
      await vpc.play();
      displayBody = (media) async => ru.Down4VideoTransform(
          displaySize: g.sizes.fullSize,
          videoAspectRatio: media.aspectRatio,
          video: VideoPlayer(vpc!),
          isReversed: media.isReversed,
          isSquared: false);
    } else {
      displayBody = (media) async => media.displayImage(size: g.sizes.fullSize);
    }

    void back_() async {
      vpc?.dispose();
      await writeHomePalette(node, _homePalettes, bGen, rfHome);
      back(withPop: false);
    }

    void next_() async {
      vpc?.dispose();
      if (unreadSnips.sublist(1).isEmpty) {
        back_();
      } else {
        setPage(await snipView(node, unreadSnips.sublist(1)));
      }
    }

    print("FULL SIZE = ${g.sizes.fullSize}");

    return SnipViewPage(
        displayMedia: await displayBody(m),
        text: m.text,
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
