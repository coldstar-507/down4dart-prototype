import 'dart:async';

import 'package:camera/camera.dart';
import 'package:down4/src/bsv/_bsv_utils.dart';
import 'package:down4/src/data_objects/firebase.dart';
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
    ..push(ViewState(id: "home", pages: [PageState()]));
  Iterable<String> get route => viewManager.route;
  ViewState get homeView => viewManager.home;
  PageState get homePageState => homeView.currentPage;
  ViewState get currentView => viewManager.currentView;

  // homestate getters
  Map<Down4ID, Palette2> get _home => homeView.pages[0].objects.cast();
  Iterable<Palette2> get home => _home.values.showing();
  List<Palette2> get formattedHome => home.toList().formatted();
  Map<Down4ID, ChatMessage>? chatMessages(ComposedID nodeID) {
    return viewManager.views["chat-${nodeID.value}"]?.pages[0].objects.cast();
  }

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
    if (pID != null && pID.length > 1 && pp0 == "chat" && n is ChatNode) {
      popedView?.chat?.second.cancel();
      await writeHomePalette(n, _home, bGen, rfHome);
    }
    final id = currentView.id.split('-');
    final p0 = id.first;
    switch (p0) {
      case 'home':
        return setPage(homePage());
      case 'chat':
        final node = currentView.node as ChatNode;
        return setPage(chatPage(node, fo: f, isReload: true));
      case 'node':
        final node = currentView.node as Down4Node;
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
    print("HOME PRE $_home}");
    // print("HIDDEN PRE $_hiddenPalettes}");
    return selectionTransition(
        originalList: formattedHome,
        state: _home,
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

  StreamSubscription? _messageListener,
      _savedImageIDs,
      _savedVideoIDs,
      _forgroundMessageListener;

  void homeScrollToZero() => homePageState.scroll = 0;

  // ========================= INITIALIZATION ============================ //

  void rfHome() => setPage(homePage());

  void loadSavedMediasListeners() async {
    final imageIDs = await savedMediaIDs(isVideo: false);
    _savedImageIDs = imageIDs.listen((event) async {
      final ar = await event.results.allResults();
      final ids = ar.map((e) => Down4ID.fromString(e.string("id"))!).toList();
      g.savedImageIDs = ids;
    });

    final videoIDs = await savedMediaIDs(isVideo: true);
    _savedVideoIDs = videoIDs.listen((event) async {
      final ar = await event.results.allResults();
      final ids = ar.map((e) => Down4ID.fromString(e.string("id"))!).toList();
      g.savedVideoIDs = ids;
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
    // connectToMessages();
    processUnsentMessages();
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
    final Iterable<GroupNode> groups = allHomeNodes.whereType<GroupNode>();
    final groupUserIDs = groups.map((e) => e.group).expand((id) => id).toSet();
    final Iterable<User> users = allHomeNodes.whereType<User>();

    final homeIDs = allHomeNodes.asIDs().toSet();
    await globall<FireMedia>(allHomeNodes.mediaIDs,
        doFetch: true, doMergeIfFetch: true);

    List<User> hiddenUsers = [];
    for (final u in users) {
      if (!u.isFriend && !await u.hasMessages()) hiddenUsers.add(u);
    }

    final hiddenIDs = hiddenUsers.asIDs().toSet();

    // we dump hidden users that are not in groups
    final shouldDump = hiddenIDs.difference(groupUserIDs);
    for (final dump in shouldDump) {
      gdb<Down4Node>().purgeDocumentById(dump.value);
    }

    for (final n in allHomeNodes) {
      await writeHomePalette(n, _home, bGen, rfHome);
    }

    if (init) setPage(homePage());

    // we fetch users in groups that are not in home
    final toFetch = groupUserIDs.difference(homeIDs);
    final fetchedNodes =
        await globall<Down4Node>(toFetch, doFetch: true, doMergeIfFetch: true);

    await globall<FireMedia>(fetchedNodes.mediaIDs,
        doFetch: true, doMergeIfFetch: true);
  }

  Future<List<ButtonsInfo2>> bGen(ChatNode n,
      {(Chat?, Iterable<Down4ID>, bool)? chatInfo}) async {
    final (_, snips, hasUnread) = chatInfo ?? await n.homeChatInfo();
    if (snips.isNotEmpty) {
      return [
        ButtonsInfo2(
          asset: Icon(Icons.arrow_forward_ios_rounded,
              color: g.theme.snipArrowColor), //  g.red,
          pressFunc: () async => setPage(await snipView(n)),
          longPressFunc: () => n is PersonNode ? setPage(nodePage(n)) : null,
          rightMost: true,
        )
      ];
    } else {
      return [
        ButtonsInfo2(
            asset: Icon(Icons.arrow_forward_ios_rounded,
                color: !hasUnread
                    ? g.theme.noMessageArrowColor
                    : g.theme.messageArrowColor),
            pressFunc: () => setPage(chatPage(n, isPush: true)),
            longPressFunc: () =>
                n is PersonNode ? setPage(nodePage(n, isPush: true)) : null,
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

  void connectToMessages2() {
    _forgroundMessageListener =
        FirebaseMessaging.onMessage.listen((event) async {
      final msg = Down4Message.fromJson(event.data);
      if (msg is Messages) {
        // Chats and Snips implements Chatter which have a special function
        // on receipts that returns the rootnode that needs to be update
        msg.onReceipt((rootNode) async {
          rootNode.updateActivity();
          await writeHomePalette(rootNode, _home, bGen, rfHome);
          if (page is HomePage) setPage(homePage());
        });
      } else if (msg is ReactionIncrement) {
        final reactor = msg.senderID;
        final reaction = await global<Reaction>(msg.reactionID);
        if (reaction == null) return;
        await reaction.addReactor(reactor);
        reloadReactions(msg.root, msg.messageID, () {
          reloadChatWithID(msg.root);
        });
      } else if (msg is Payment) {
        Down4Payment? payment = msg.payment ??
            await global<Down4Payment>(msg.paymentID,
                doFetch: true, doMergeIfFetch: true);
        if (payment == null) return;
        await payment.merge();
        if (page is MoneyPage) return setPage(moneyPage(payUpdate: payment));
      } else if (msg is Reaction) {
        await msg.merge();
        reloadReactions(msg.root, msg.messageID, () {
          reloadChatWithID(msg.root);
        });
      } else {
        throw "connectToMessage has no implemented this type: ${msg.runtimeType}";
      }
    });
  }

  // void connectToMessages() {
  //   var msgQueue = db.child("Users").child(g.self.id).child("M");
  //
  //   _messageListener = msgQueue.onChildAdded.listen((event) async {
  //     print("New message!");
  //     final eventKey = event.snapshot.key;
  //     final eventPayload = (event.snapshot.value as String).split("%");
  //     msgQueue.child(eventKey!).remove(); // consume it
  //     print("KEY = $eventKey\nPAYLOAD = $eventPayload\n");
  //
  //     // if (eventPayload.first == "h") {
  //     //   // "h-${msg.id}-$hcID-${hyper.media.id}-${hyper.firstWord}-${hyper.secondWord}-${hyper.group.join(" ")}";
  //     //   // HYPERCHAT
  //     //   final msgID = eventPayload[1];
  //     //   final hcID = eventPayload[2];
  //     //   final mediaID = eventPayload[3];
  //     //   final firstWord = eventPayload[4];
  //     //   final secondWord = eventPayload[5];
  //     //   final members = eventPayload[6].split(" ");
  //     //
  //     //   final hcMedia = downloadMessageMediaAsNodeMedia(mediaID);
  //     //   final msg = downloadMessage(msgID);
  //     //
  //     //   Future.wait([hcMedia, msg]).then((value) async {
  //     //     if (value.first == null) return;
  //     //     await (value[1] as FireMessage?)?.onReceipt(root: hcID);
  //     //     final hyperchat = Hyperchat(
  //     //         id: hcID,
  //     //         firstWord: firstWord,
  //     //         secondWord: secondWord,
  //     //         group: members.toSet(),
  //     //         messages: {msgID},
  //     //         snips: {},
  //     //         media: value.first as FireMedia)
  //     //       ..save();
  //     //
  //     //     await writeHomePalette(hyperchat, _homePalettes, bGen, rfHome);
  //     //     await localPalettesRoutine();
  //     //     setPage(homePage());
  //     //   });
  //     // }
  //     switch (eventPayload.first) {
  //       case "p": // PAYMENT
  //         print("RECEIVED A PAYMENT");
  //         final paymentID = eventPayload[1];
  //         final payment = await downloadPayment(paymentID);
  //         if (payment == null) return;
  //         await g.wallet.parsePayment(g.self.id, payment);
  //         if (page is MoneyPage) setPage(moneyPage(payUpdate: payment));
  //         return;
  //       case "m": // MESSAGE
  //         print("RECEIVED A MESSAGE");
  //         final msgID = eventPayload[1];
  //         // get the message, we wait until we get the maybe associated media
  //         // before merging, the reason for that is merging would trigger
  //         // reload chat if we are in the chat, but we want to have the media
  //         // before reloading the chat
  //         final msg = await global<Chat>(msgID, doFetch: true);
  //         if (msg == null) return;
  //
  //         // get the rootNode
  //         final rootNode = await global<Chatable>(msg.root,
  //             doFetch: true, doMergeIfFetch: true);
  //         if (rootNode == null) return;
  //
  //         User? senderNode = await global<User>(msg.senderID);
  //         FireMedia? msgMedia;
  //
  //         if (senderNode != null && senderNode.isFriend) {
  //           msgMedia = await global<FireMedia>(msg.mediaID,
  //               doFetch: true,
  //               doMergeIfFetch: true,
  //               mediaInfo: (withData: true, onlineID: msg.onlineMediaID));
  //         }
  //
  //         // if is snip from a user that isn't a friend, we don't pre-download
  //         // if (msg.isSnip && rootNode is User && !rootNode.isFriend) {
  //         //   msgMedia = await global<FireMedia>(msg.mediaID,
  //         //       doFetch: true,
  //         //       doMergeIfFetch: true,
  //         //       mediaInfo: (withData: false, onlineID: msg.onlineMediaID));
  //         // } else {
  //         //   msgMedia = await global<FireMedia>(msg.mediaID,
  //         //       doFetch: true,
  //         //       doMergeIfFetch: true,
  //         //       mediaInfo: (withData: true, onlineID: msg.onlineMediaID));
  //         // }
  //         // get the rootNode media
  //         await global<FireMedia>(rootNode.mediaID,
  //             doFetch: true,
  //             doMergeIfFetch: true,
  //             mediaInfo: (withData: true, onlineID: null));
  //
  //         // msg medias references are dynamic and always get updated
  //         // this is because messages are not kept for ever on server
  //         if (msg.onlineMediaID != null) {
  //           await msgMedia?.updateOnlineReference(
  //               msg.onlineMediaID!, msg.onlineMediaTimestamp);
  //         }
  //         await msg.merge();
  //         await writeHomePalette(
  //             rootNode..updateActivity(), _home, bGen, rfHome);
  //
  //         if (page is HomePage) setPage(homePage());
  //         return;
  //       case "r": // REACTION
  //         print("RECEIVED A REACTION");
  //         final reactionID = eventPayload[1];
  //         final reaction = await global<Reaction>(reactionID,
  //             doFetch: true, doMergeIfFetch: true);
  //         if (reaction != null) {
  //           final m = await global<FireMedia>(
  //             reaction.mediaID,
  //             doFetch: true,
  //             doMergeIfFetch: true,
  //             mediaInfo: (onlineID: reaction.onlineMediaID, withData: true),
  //           );
  //           if (reaction.onlineMediaID != null && m != null) {
  //             await m.updateOnlineReference(
  //                 reaction.onlineMediaID!, reaction.onlineMediaTimestamp);
  //           }
  //           reloadReactions(reaction.root, reaction.messageID, () {
  //             reloadChatWithID(reaction.root);
  //           });
  //         }
  //         return;
  //       case "i": // INCREMENT REACTION
  //         print("RECEIVED A INCREMENT REACTION");
  //         final chatReactionID = eventPayload[1];
  //         final reactor = eventPayload[2];
  //         final chatReaction = await global<Reaction>(chatReactionID,
  //             doFetch: true, doMergeIfFetch: true);
  //         if (chatReaction != null) {
  //           await chatReaction.addReactor(reactor);
  //           reloadReactions(chatReaction.root, chatReaction.messageID, () {
  //             reloadChatWithID(chatReaction.root);
  //           });
  //         }
  //         return;
  //     }
  //
  //     // if (eventPayload.first == "p") {
  //     //   // PAYMENT!
  //     //   final paymentID = eventPayload[1];
  //     //   final payment = await downloadPayment(paymentID);
  //     //   if (payment == null) return;
  //     //   await g.wallet.parsePayment(g.self.id, payment);
  //     //   if (page is MoneyPage) setPage(moneyPage(payUpdate: payment));
  //     //   return;
  //     // } else if (eventPayload.first == "m") {
  //     //   // MESSAGE!
  //     //   final msgID = eventPayload[1];
  //     //   // get the message, we wait until we get the maybe associated media
  //     //   // before merging, the reason for that is merging would trigger
  //     //   // reload chat if we are in the chat, but we want to have the media
  //     //   // before reloading the chat
  //     //   final msg = await global<FireMessage>(msgID, doFetch: true);
  //     //   if (msg == null) return;
  //     //
  //     //   // get the rootNode
  //     //   final rootNode = await global<Chatable>(msg.root,
  //     //       doFetch: true, doMergeIfFetch: true);
  //     //   if (rootNode == null) return;
  //     //
  //     //   FireMedia? msgMedia;
  //     //
  //     //   // if is snip from a user that isn't a friend, we don't pre-download
  //     //   if (msg.isSnip && rootNode is User && !rootNode.isFriend) {
  //     //     msgMedia = await global<FireMedia>(msg.mediaID,
  //     //         doFetch: true,
  //     //         doMergeIfFetch: true,
  //     //         mediaInfo: (withData: false, onlineID: msg.onlineMediaID));
  //     //   } else {
  //     //     msgMedia = await global<FireMedia>(msg.mediaID,
  //     //         doFetch: true,
  //     //         doMergeIfFetch: true,
  //     //         mediaInfo: (withData: true, onlineID: msg.onlineMediaID));
  //     //   }
  //     //   // get the rootNode media
  //     //   await global<FireMedia>(rootNode.mediaID,
  //     //       doFetch: true,
  //     //       doMergeIfFetch: true,
  //     //       mediaInfo: (withData: true, onlineID: null));
  //     //
  //     //   // msg medias references are dynamic and always get updated
  //     //   // this is because messages are not kept for ever on server
  //     //   if (msg.onlineMediaID != null) {
  //     //     await msgMedia?.updateOnlineReference(
  //     //         msg.onlineMediaID!, msg.onlineMediaTimestamp);
  //     //   }
  //     //   await msg.merge();
  //     //   await writeHomePalette(rootNode..updateActivity(), _home, bGen, rfHome);
  //     //
  //     //   if (page is HomePage) setPage(homePage());
  //     // } else if (eventPayload.first == "r") {
  //     //   // chat reaction
  //     //   final reactionID = eventPayload[1];
  //     //   final reaction = await global<ChatReaction>(reactionID,
  //     //       doFetch: true, doMergeIfFetch: true);
  //     //   if (reaction != null) {
  //     //     reloadReactions(reaction.root, reaction.messageID, () {
  //     //       reloadChatWithID(reaction.root);
  //     //     });
  //     //   }
  //     // } else if (eventPayload.first == "i") {
  //     //   // chat reaction increment
  //     //   final reactionID = eventPayload[1];
  //     //   final reactor = eventPayload[2];
  //     //   final reaction = await global<ChatReaction>(reactionID,
  //     //       doFetch: true, doMergeIfFetch: true);
  //     //   if (reaction != null) {
  //     //     await reaction.addReactor(reactor);
  //     //     reloadReactions(reaction.root, reaction.messageID, () {
  //     //       reloadChatWithID(reaction.root);
  //     //     });
  //     //   }
  //     // }
  //     // else if (eventPayload.first == "s") {
  //     // final String mediaID = eventPayload[1];
  //     // final String root = eventPayload[2];
  //     //
  //     // final (snip, _) = await global<FireMedia>(mediaID,
  //     //     fetch: true, merge: true, mediaData: true);
  //     // if (snip == null) return;
  //     //
  //     // final (nodeRoot, gt) =
  //     //     await global<Chatable>(root, fetch: true, merge: true);
  //     // if (nodeRoot == null) return;
  //     // nodeRoot.addSnipRef(snip.id);
  //     // snip.addReference(nodeRoot.id);
  //     //
  //     // FireMedia? nodeMedia;
  //     // if (gt == GetType.fetch) {
  //     //   (nodeMedia, _) = await global<FireMedia>(nodeRoot.media,
  //     //       fetch: true, merge: true, mediaData: true, nodesMedia: true);
  //     //   nodeMedia?.addReference(nodeRoot.id);
  //     // }
  //     // final p = Palette2<Chatable>(rootNode: nodeRoot, image: nodeMedia);
  //     // await writeHomePalette(p, _homePalettes, bGen, rfHome);
  //     //
  //     // if (cv.id == 'home') setPage(homePage());
  //     // }
  //     // else if (eventPayload.first == "f") {
  //     //   // FORWARDED MESSAGE
  //     //   final msgID = eventPayload[1];
  //     //   final root = eventPayload[2];
  //     //   final forwardedFrom = eventPayload[3];
  //     //   final msg = await downloadMessage(msgID);
  //     //   if (msg == null) return;
  //     //   msg.forwarderID = forwardedFrom;
  //     //   return handleMessage(msg, root);
  //     // }
  //   });
  // }

  void rewriteHomePalettes() {
    for (final p in _home.values) {
      writeHomePalette(p.node as ChatNode, _home, bGen, rfHome);
    }
  }

  // =============================== UTILS ============================== //

  void reloadChatWithID(Down4ID chatableNodeID, {Chat? msgRe}) {
    if (currentView.id == "chat-$chatableNodeID") {
      setPage(chatPage(currentView.node as ChatNode, msgRe: msgRe));
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
    for (final p in List.of(home)) {
      if (p.selected) {
        await writeHomePalette(p.node as ChatNode, _home, bGen, rfHome,
            sel: false);
      }
    }
    return;
  }

  List<Palette2> forwardables(List<Palette2> ps) {
    final idsInGroups = ps
        .asNodes<GroupNode>()
        .map((e) => e.group)
        .expand((element) => element)
        .toSet();

    final forwardables = ps.whereNodeIs<BranchNode>().asIDs();

    final all = forwardables.followedBy(idsInGroups).toSet();

    return all.map((id) => _home[id]).whereType<Palette2>().toList();
  }

  // =========================== PAGES FUNCTIONS ======================== //

  Future<void> processUnsentMessages() async {
    final unsents = await unsentMessages();
    for (final u in unsents) {
      u.processMessage();
      // final root = await global<Chatable>(u.root);
      // if (root == null) continue;
      // await broadcastMessage(root, u);
    }
  }

  void processChats(Iterable<Chat> chats) async {
    for (final chat in chats) {
      chat.processMessage(onResponse: (r) {
        if (r.any((m) => m.success)) {
          chat.markSent();
          reloadChatWithID(chat.root, msgRe: chat);
        }
      });
    }
  }

  Future<void> reloadReactions(
    ComposedID nodeID,
    Down4ID messageID,
    VoidCallback refreshChat,
  ) async {
    final state = chatMessages(nodeID);
    print("state is null? $state");
    final msgRef = state?[messageID];
    print("msg ref is null? $msgRef");
    if (msgRef != null) {
      state![messageID] = msgRef.withReactions(await msgRef.message.reactions);
      refreshChat();
    } else {
      print("MESSAGE REF IS NULL");
    }
  }

  // Future<void> incrementReaction(
  //     Chatable c, Reaction cr, VoidCallback refreshChat) async {
  //   if (cr.reactors.contains(g.self.id)) return;
  //
  //   await cr.addReactor(g.self.id);
  //   reloadReactions(cr.root, cr.messageID, refreshChat);
  //
  //   // r.MessageRequest(
  //   //   sender: g.self.id,
  //   //   tokens:
  //   // )
  //
  //   r.PushRequest(
  //           sender: g.self.id,
  //           targets: c.targets(selfID: g.self.id),
  //           data: "i%${cr.id}%${g.self.id}")
  //       .process();
  // }

  // Future<void> react(
  //     Chatable node, ID mediaID, Chat message, VoidCallback refreshChat) async {
  //   final cr = Reaction(messagePushId(),
  //       mediaID: mediaID,
  //       root: node.id,
  //       messageID: message.id,
  //       reactors: {g.self.id},
  //       senderID: g.self.id,
  //       timestamp: makeTimestamp())
  //     ..cache();
  //   await cr.merge();
  //   await reloadReactions(node.id, message.id, refreshChat);
  //
  //   List<ID> pushReceipients;
  //   ID notifReceipient = message.senderID;
  //   String header, bodyPrefix;
  //
  //   final nodeRef = node;
  //   if (nodeRef is Groupable) {
  //     pushReceipients = List.from(nodeRef.group)..remove(g.self.id);
  //     header = node.displayName;
  //     bodyPrefix = "${g.self.firstName} ";
  //   } else {
  //     pushReceipients = [nodeRef.id];
  //     bodyPrefix = "";
  //     header = nodeRef.displayName;
  //   }
  //
  //   if (node.id == g.self.id) {
  //     await cr.markSent();
  //     await reloadReactions(node.id, message.id, refreshChat);
  //   } else {
  //     final successfulUpload = await uploadMessage(cr);
  //     if (successfulUpload) {
  //       final pushReq = r.PushRequest(
  //           sender: g.self.id, targets: pushReceipients, data: "r%${cr.id}");
  //       final notifReq = r.NotificationRequest(
  //         sender: g.self.id,
  //         targets: [notifReceipient],
  //         header: header,
  //         body: "${bodyPrefix}reacted to your message!",
  //       );
  //
  //       final p = await Future.wait([pushReq.process(), notifReq.process()]);
  //
  //       final successfulSent = p.every((element) => element);
  //       if (successfulSent) {
  //         await cr.markSent();
  //         await reloadReactions(node.id, message.id, refreshChat);
  //       }
  //     }
  //   }
  // }
  //
  // Future<r.MessageBatchResponse?> makeRequest(
  //     MessageData msg, Chatable nodeRef) async {
  //   final bool isSnip = msg is Snip;
  //   String header, bodyPrefix;
  //
  //   if (nodeRef is Groupable) {
  //     header = nodeRef.displayName;
  //     bodyPrefix = "${g.self.firstName}${isSnip ? " pinged" : ""}: ";
  //   } else {
  //     bodyPrefix = "";
  //     header = "${nodeRef.displayName}${isSnip ? " pinged" : ""}";
  //   }
  //
  //   final String body = bodyPrefix + msg.messagePreview;
  //   return sendTheMessage(
  //     msg: msg,
  //     tokens: await nodeRef.messagingTokens,
  //     header: header,
  //     body: body,
  //   );
  //
  //   // return r.MessageRequest(
  //   //     sender: g.self.id,
  //   //     tokens: tokens,
  //   //     // targets: receipients,
  //   //     header: header,
  //   //     body: bodyPrefix + msg.messagePreview,
  //   //     data: msg.toJson(toLocal: false));
  // }

  // Future<void> broadcastMessage(Chatable t, Chat msg) async {
  //   final successfulUpload = await uploadMessage(msg);
  //   // final uploads = <Future<bool>>[];
  //   // uploads.add(uploadMessage(msg));
  //   // final media = await global<FireMedia>(msg.mediaID);
  //   // if (media != null) uploads.add(uploadMedia(media, isSnip: msg.isSnip));
  //
  //   // final upSuccess = await Future.wait(uploads).then((u) => u.every((b) => b));
  //
  //   if (successfulUpload) {
  //     final broadcastSuccess = await generateRequest(msg, t).process();
  //     if (broadcastSuccess && !msg.isSnip) {
  //       await msg.markSent();
  //       if (page is ChatPage && currentView.node?.id == t.id) {
  //         setPage(chatPage(t, msgRe: msg, isReload: true));
  //       }
  //     }
  //   }
  // }

  // Future<void> sendToTargets(Payload p, Iterable<Chatable> targets) async {
  //   final messagesToForward =
  //       p.forwardables?.whereType<ChatMessage>().map((cm) => cm.message) ?? [];
  //
  //
  //
  // }

  // Future<void> metaSend(Payload p, Iterable<Chatable> targets) async {
  //   final messagesToForward =
  //       p.forwardables?.whereType<ChatMessage>().map((cm) => cm.message) ?? [];
  //
  //   List<Future<void> Function()> awaitingProcess = [];
  //   // Here, we will iterate over each target and each messages we are sending
  //   // We can be sending multiple messages to multiple chats
  //   // There are 2 types of messages, the normal and the forwarded
  //   // There can only be one normal and multiple forwarded
  //   // We still make a new message for every chat, in other words...
  //   // ...Chats don't share messages
  //   // Normal and Forwarded have different bodies for notification so...
  //   // Function has some redundant code, but we try make it minimal
  //   // We iterate over targets once, saving the messages locally and make...
  //   // ... the upload requests
  //   // Function then returns, but calls a future that will process sending...
  //   // ...only after the uploads are successful
  //   // After sending, each message will be marked as sent
  //
  //   // We start with uploading the payload media if there is one
  //   // If it's a snip, we can know because there's the media cached path
  //   // If it's not a snip, it should be pre-written
  //
  //   p.media?.cache();
  //   await p.media?.merge();
  //   for (final t in targets) {
  //     p.make()
  //
  //
  //     List<Chat> msgs = [];
  //     t.updateActivity();
  //     final ourMsg = p.makeMsg(root: t.id);
  //     if (ourMsg != null) {
  //       final bool doMarkRead = !(ourMsg.isSnip && t.id == g.self.id);
  //       if (doMarkRead) await ourMsg.markRead();
  //       msgs.add(ourMsg);
  //     }
  //
  //     final fMsgs = messagesToForward.map((m) => m.forwarded(g.self.id, t.id));
  //     for (final fMsg in fMsgs) {
  //       await fMsg.markRead();
  //     }
  //
  //     for (final m in msgs.followedBy(fMsgs)) {
  //       m.cache();
  //       if (t.id == g.self.id) {
  //         await m.markSent();
  //       } else {
  //         awaitingProcess.add(() => broadcastMessage(t, m));
  //       }
  //     }
  //     await writeHomePalette(t, _home, bGen, rfHome);
  //   }
  //
  //   // for (final t in targets) {
  //   //   t.updateActivity();
  //   //   final ourMsg = p.makeMsg(root: t.id)?..cache();
  //   //   final allMsgs = await ourMsg?.merge();
  //   //   // this way we can send snips to ourself
  //   //   final dontMarkRead = p.isSnip && t.id == g.self.id;
  //   //   if (!dontMarkRead) await ourMsg?.markRead();
  //   //
  //   //   if (t.id != g.self.id && ourMsg != null) {
  //   //     awaitingProcess.add(() => broadcastMessage(t, ourMsg));
  //   //   } else if (ourMsg != null) {
  //   //     await ourMsg.markSent();
  //   //   }
  //   //
  //   //   // if (ourMsg != null) {
  //   //   //   if (t.id != g.self.id) {
  //   //   //     u.add(uploadMessage(ourMsg));
  //   //   //     final req = generateRequest(ourMsg, t);
  //   //   //     awatingProcess.add(() => broadcastMessage(req, t, ourMsg));
  //   //   //   }
  //   //   // }
  //   //
  //   //   for (final m in messagesToForward) {
  //   //     final fMsg = m.message.forwarded(g.self.id, t.id)
  //   //       ..markRead()
  //   //       ..cache();
  //   //
  //   //     if (t.id != g.self.id) {
  //   //       awaitingProcess.add(() => broadcastMessage(t, fMsg));
  //   //     } else {
  //   //       await fMsg.markSent();
  //   //     }
  //   //
  //   //     await writeHomePalette(t, _home, bGen, rfHome);
  //   //
  //   //     // we don't send the message if the receipient is us
  //   //     // if (t.id != g.self.id) {
  //   //     //   u.add(uploadMessage(fMsg));
  //   //     //   if (fMedia != null) u.add(uploadMedia(fMedia));
  //   //     //   final req = generateRequest(fMsg, t);
  //   //     //   awatingProcess.add(() => broadcastMessage(req, t, fMsg));
  //   //     // }
  //   //   }
  //   // }
  //
  //   Future(() async {
  //     for (final ap in awaitingProcess) {
  //       await ap.call();
  //     }
  //   });
  //
  //   // Future(() async {
  //   //   final finishedUploads = await Future.wait(u);
  //   //   if (finishedUploads.every((success) => success)) {
  //   //     for (var req in awatingProcess) {
  //   //       req.call();
  //   //     }
  //   //   }
  //   // });
  //
  //   return;
  // }

  // Future<void> makeHyperchat({
  //   List<Down4Object>? fo,
  //   FireMedia? m,
  //   String? textInput,
  //   required Set<ID> group,
  // }) async {
  //   setPage(loadingPage());
  //   final prompts = await ru.randomPrompts(10);
  //   final hc = await r.getHyperchat(prompts);
  //   if (hc == null) {
  //     viewManager.popUntilHome();
  //     await unselectHomeSelection(updateActivity: false);
  //     setPage(homePage(prompt: "Failed to create hyperchat!"));
  //     return;
  //   }
  //
  //   final hcID = sha1(hc.first).toBase58();
  //   final hcMedia = FireMedia(deterministicMediaID(hc.first, g.self.id),
  //       tinyThumbnail: ru.makeTiny(hc.first),
  //       mime: "image/png",
  //       ownerID: g.self.id,
  //       timestamp: makeTimestamp(),
  //       width: 512,
  //       height: 512);
  //   await hcMedia.write(imageData: hc.first);
  //
  //   final hyper = Hyperchat(hcID,
  //       firstWord: hc.second.first,
  //       secondWord: hc.second.second,
  //       activity: makeTimestamp(),
  //       group: grp,
  //       mediaID: hcMedia.id);
  //
  //   final success = await uploadNode(hyper);
  //
  //   if (!success) {
  //     hcMedia.delete();
  //     viewManager.popUntilHome();
  //     return setPage(homePage(prompt: "Failed to upload Hyperchat"));
  //   } else {
  //     hyper.merge();
  //     gCache(hcMedia);
  //     gCache(hyper);
  //   }
  //
  //   p.makeMessage(root: hyper.id).processMessage();
  //
  //   unselectHomeSelection();
  //   viewManager.popUntilHome();
  //   setPage(chatPage(hyper, isPush: true));
  //   return;
  // }

  // Future<void> makeGroup(Group group, FireMedia m, Payload p) async {
  //   setPage(loadingPage());
  //   final success = await uploadNode(group);
  //
  //   if (success) {
  //     await group.merge();
  //     await m.merge();
  //     m.cache();
  //     group.cache();
  //     p.makeMessage(root: group.id).processMessage();
  //     await unselectHomeSelection();
  //     viewManager.popUntilHome();
  //     setPage(chatPage(group, isPush: true));
  //   } else {
  //     viewManager.popUntilHome();
  //     setPage(homePage(prompt: "Failed to create group"));
  //   }
  // }

  // Future<void> ping(String text, Iterable<Chatable> targets) async {
  //   for (final t in targets) {
  //     final FireNode nodeRef = t;
  //     if (nodeRef is Groupable) {
  //       r.MessageRequest(
  //         sender: g.self.id,
  //         data: "",
  //         targets: nodeRef.group.toList()..remove(g.self.id),
  //         header: "${g.self.displayName} pinged ${nodeRef.displayName}",
  //         body: text,
  //       ).process();
  //     } else {
  //       r.MessageRequest(
  //         sender: g.self.id,
  //         data: "",
  //         targets: [t.id],
  //         header: "${g.self.displayName} pinged you",
  //         body: text,
  //       ).process();
  //     }
  //   }
  //   await unselectHomeSelection(updateActivity: true);
  // }

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

    final media = FireMedia(ComposedID(),
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

    for (final sel in home.selected().asNodes<ChatNode>()) {
      final snip = Snip(ComposedID(),
          senderID: g.self.id, text: text, root: sel.id, mediaID: media.id)
        ..processMessage();
      if (sel.id == g.self.id) {
        snip
          ..cache()
          ..merge();
        media
          ..cache()
          ..merge();
      }
    }

    // await metaSend(payload, home.selected().asNodes<Chatable>());

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
    setPage(homePage(prompt: "SNIPED"));
  }

  // ============================== PAGES ============================== //

  ru.Down4PageWidget homePage({String? prompt}) {
    return HomePage(
      forward: (sel) => setPage(
        forwardPage(sel.whereNodeIs<BranchNode>().toList(), isPush: true),
      ),
      openChat: (n, f) => setPage(chatPage(n, isPush: true)),
      send: (chats) async {
        processChats(chats);
        await unselectHomeSelection(updateActivity: true);
      },
      homeState: homeView,
      hyperchat: () => setPage(hyperchatPage()),
      group: () => setPage(groupPage()),
      money: () =>
          setPage(moneyPage(transition: homeTransition(), isPush: true)),
      ping: (text) => print("Deprecated"),
      snip: () => setPage(snipPage()),
      search: () => setPage(searchPage(isPush: true)),
      themes: () => setPage(themePage()),
      delete: () async {
        for (final p in List<Palette2>.from(home)) {
          if (p.selected && p.id != g.self.id) {
            _home.remove(p.node.id);
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
    Map<Down4ID, Palette2> _fState() => currentView.currentPage.objects.cast();
    void rf() => setPage(forwardPage(fo));
    List<ButtonsInfo2> fbGen(ChatNode c) {
      return [
        ButtonsInfo2(
            asset: Icon(Icons.arrow_forward_ios_rounded,
                color: g.theme.noMessageArrowColor),
            rightMost: true,
            pressFunc: () => setPage(chatPage(c, fo: fo, isPush: true)))
      ];
    }

    if (isPush) {
      viewManager.popUntilHome();
      viewManager.push(ViewState(id: "forward", pages: [PageState()]));
      for (final c in formattedHome.asNodes<ChatNode>()) {
        writePalette3<ChatNode>(c, _fState(), fbGen, rf,
            pr: _home[c.id]?.messagePreview);
      }
    }

    return ForwardingPage(
        viewState: viewManager.currentView,
        fObjects: fo,
        openChat: (fObjects, node) =>
            setPage(chatPage(node, fo: fObjects, isPush: true)),
        hyper: (fObjects, transition) =>
            setPage(hyperchatPage(fObjects, transition)),
        forward: (chats) async {
          processChats(chats);
          await unselectHomeSelection();
          homeScrollToZero();
          viewManager.popUntilHome();
          setPage(homePage());
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
        final receivers = pay.txs.last.txsOut
            .map((utxo) => utxo.isGets ? utxo.receiver : null)
            .whereType<ComposedID>()
            .toList(growable: false);

        final targets = (await globall<PersonNode>(receivers, doFetch: true))
            .map((e) => MessageTarget(
                userID: e.id,
                device: e.mainDeviceID,
                token: e.messagingTokens[e.mainDeviceID]!));

        Payment(Down4ID(),
                senderID: g.self.id,
                paymentID: pay.id,
                payment: payment,
                targets: targets.toList())
            .processMessage();

        viewManager.popUntilHome();
        setPage(homePage());
      },
      back: () => back(withPop: false),
      payment: payment,
    );
  }

  ru.Down4PageWidget themePage() {
    return ThemePage(
      onSwap: rewriteHomePalettes,
      back: () => back(withPop: false),
    );
  }

  ru.Down4PageWidget moneyPage({
    bool isPush = false,
    bool isReload = false,
    Transition? transition,
    PersonNode? single,
    Down4Payment? payUpdate,
    // payment update is for when we are in money view, and
    // we receive an online payment, this let us update status with this new
    // payment, it would not be necessary if listeners work on lazy box, but
    // haven't found a way to make the listener work yet...
  }) {
    Map<ComposedID, Palette2> people() => currentView.pages[0].objects.cast();
    Map<Down4ID, Palette2> payments() => currentView.pages[1].objects.cast();
    void rf() => setPage(moneyPage());
    void openPay(Down4Payment payment) => setPage(paymentPage(payment));

    void scanOrReceivePayment(Down4Payment pay) {
      // this will put the payment at the begining of the list
      final p = PaymentNode(pay.id, payment: pay, selfID: g.self.id);
      currentView.pages[1].objects = {
        pay.id: Palette2(
            node: p,
            key: Key(p.id.unique),
            messagePreview: pay.textNote,
            buttonsInfo2: pay.isSpentBy(id: g.self.id)
                ? [
                    ButtonsInfo2(
                        asset: g.fifty,
                        pressFunc: () => openPay(pay),
                        rightMost: true)
                  ]
                : []),
        ...payments(),
      };
      rf();
    }

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

    if (payUpdate != null) scanOrReceivePayment(payUpdate);

    return MoneyPage(
        single: single,
        transition: transition,
        viewState: currentView,
        loadMorePayments: () async => loadSomePayments(8),
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
        back: () => back(withPop: true));
  }

  ru.Down4PageWidget hyperchatPage([
    List<Down4Object>? fObjects,
    Transition? transition,
  ]) {
    final transition_ = transition ?? homeTransition();
    return HyperchatPage(
      transition: transition_,
      fo: fObjects,
      makeHyperchat: (fo, media, text, group) async {
        setPage(loadingPage());
        final prompts = await ru.randomPrompts(10);
        final hc = await r.getHyperchat(prompts);
        if (hc == null) {
          viewManager.popUntilHome();
          await unselectHomeSelection(updateActivity: false);
          setPage(homePage());
          return;
        }

        final hcMedia = FireMedia(ComposedID(),
            tinyThumbnail: ru.makeTiny(hc.first),
            mime: "image/png",
            ownerID: g.self.id,
            timestamp: makeTimestamp(),
            width: 512,
            height: 512);
        await hcMedia.write(imageData: hc.first);

        final hyper = Hyperchat(ComposedID(),
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
              messages: fo?.whereType<ChatMessage>().asIDs().toSet(),
              nodes: fo?.whereType<Down4Node>().asComposedIDs().toSet())
            ..cache()
            ..merge();

          processChats([chat]);
        }

        unselectHomeSelection();
        viewManager.popUntilHome();
        setPage(chatPage(hyper, isPush: true));
        return;
      },
      back: () => back(withPop: false, f: fObjects),
      ping: (text) => print("Deprecated"),
    );
  }

  ru.Down4PageWidget groupPage() {
    final transition = homeTransition();
    return GroupPage(
        initialOffset: transition.scroll,
        back: () => back(withPop: false),
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
    Map<Down4ID, Palette2> searchs() => currentView.currentPage.objects.cast();

    return AddFriendPage(
        viewState: currentView,
        search: (strIDs) async {
          final ids = strIDs.split(" ").toSet();
          final locals = await searchLocalsByUnique(ids);
          final localIDs = locals.map((e) => e.id.unique).toSet();
          final toFetch = ids.difference(localIDs);
          final futureNodes = r.getUsers(toFetch);
          for (final local in locals) {
            writePalette3(local, searchs(), bGen2, rf);
          }
          final fetchedNodes = (await futureNodes) ?? [];
          for (final node in fetchedNodes) {
            writePalette3(node..cache(), searchs(), bGen2, rf);
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
            if (n is User) await n.updateFriendStatus(true);
            writePalette3(n, searchs(), bGen2, rf, sel: false);
            writeHomePalette(n, _home, bGen, rfHome);
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

  ru.Down4PageWidget nodePage(Down4Node n, {bool isPush = false}) {
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
    ChatNode c, {
    bool isPush = false,
    bool isReload = false,
    bool rewriteMsgWithNodes = false,
    Chat? msgRe,
    List<Down4Object>? fo,
    Chat? reactingTo,
  }) {
    String chatID() => "chat-${c.id.value}";
    ViewState chat() => viewManager.at(chatID());

    List<Down4ID> orderedMsgsIDs() => chat().chat?.first ?? [];
    Map<Down4ID, ChatMessage> messages() => chat().pages[0].objects.cast();
    Map<Down4ID, Palette2> members() => chat().pages[1].objects.cast();
    Set<Down4ID> msgsWithVideos() => chat().refs("messages_with_videos");
    Set<Down4ID> msgsWithNodes() => chat().refs("messages_with_nodes");

    bool forwarding() => fo != null;

    void opn(Down4Node n_) => setPage(nodePage(n_, isPush: true));
    void Function(Down4Node)? openNode() => forwarding() ? null : opn;
    List<ButtonsInfo2> Function(ChatNode)? cbGen = forwarding() ? null : bGen2;

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
      final Down4Node ref = c;
      if (ref is GroupNode) {
        for (final n in _home.those(ref.group).noNull().asNodes<PersonNode>()) {
          writePalette3(n, members(), cbGen, refreshChat);
        }
      }
    }

    void rf() => setPage(chatPage(c));

    Future<void> increment(Reaction cr) async {
      if (cr.reactors.contains(g.self.id)) return;
      cr.addReactor(g.self.id);
      ReactionIncrement(Down4ID(),
              root: c.id,
              messageID: cr.messageID,
              reactionID: cr.id,
              senderID: g.self.id)
          .processMessage();
      reloadReactions(c.id, cr.messageID, rf);
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
          if (id == loaded.last) {
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
      forward: (fo) => setPage(forwardPage(fo, isPush: true)),
      onPageChange: (ix) {
        refreshChat(stopVid: true);
        chat().currentIndex = ix;
      },
      loadMore: loadMore,
      viewState: viewManager.at(chatID()),
      fo: fo,
      reactingTo: reactingTo,
      react: (ComposedID mediaID, Chat msg) async {
        Reaction(Down4ID(),
            senderID: g.self.id,
            root: c.id,
            mediaID: mediaID,
            messageID: msg.id,
            reactors: {g.self.id})
          ..cache()
          ..merge()
          ..processMessage();
        reloadReactions(c.id, msg.id, () => reloadChatWithID(c.id, msgRe: msg));
      },
      openNode: opn,
      send: (chat) async {
        processChats([chat]);
        // poping the forwarding page
        if (forwarding()) viewManager.popInBetween();
        setPage(
          chatPage(c, isReload: true, rewriteMsgWithNodes: chat.hadForwards),
        );
      }, // TODO, will need future nodes
      back: () => back(withPop: true, f: fo),
      add: () async {
        for (final n in members().values.selected().asNodes<PersonNode>()) {
          if (n is User) await n.updateFriendStatus(true);
          writePalette3(n, members(), bGen2, rf, sel: false);
          writeHomePalette(n, _home, bGen, rfHome);
        }
        rf();
        localPalettesRoutine();
      },
      money: () {
        return setPage(moneyPage(
            isPush: true,
            transition: selectionTransition(
                originalList: members().values.toList().reversed.toList(),
                state: members(),
                scrollOffset: chat().pages[1].scroll)));
      },
      hyper: () {
        return setPage(hyperchatPage(
            fo,
            selectionTransition(
                originalList: members().values.toList().reversed.toList(),
                state: members(),
                scrollOffset: chat().pages[1].scroll)));
      },
    );
  }

  Future<ru.Down4PageWidget> snipView(ChatNode node, [List<Down4ID>? l]) async {
    final unreadSnips = l ?? (await node.unreadSnipIDs()).toList();
    VideoPlayerController? vpc;

    void back_() async {
      vpc?.dispose();
      await writeHomePalette(node, _home, bGen, rfHome);
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

    print("Unread snips=$unreadSnips");
    if (unreadSnips.isEmpty) {
      await writeHomePalette(node, _home, bGen, rfHome);
      setPage(homePage());
    }
    final s = await global<Chat>(unreadSnips.first, doCache: false);
    await s!.markRead();

    final m = await global<FireMedia>(s.mediaID,
        doCache: false, doFetch: true, tempID: s.tempMediaID);
    print("media JSON: \n${m?.toJson()}");

    if (m == null) return snipView(node);
    // this will preload it in memory if it's there
    // allowing it to be precached
    // if (!await m.cachedAndReady) return snipView(node);

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

    Future<Widget> Function(FireMedia m) displayBody;

    if (m.isVideo) {
      vpc = await m.videoController;
      if (vpc == null) return snipView(node);
      await vpc.initialize();
      await vpc.setLooping(true);
      await vpc.play();
      displayBody = (media) async => media.displaySnip(controller: vpc);
    } else {
      displayBody = (media) async {
        final image = media.displayCachedImage;
        if (image != null) {
          await precacheImage(image.image, context);
        }
        return media.displaySnip();
      };
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
