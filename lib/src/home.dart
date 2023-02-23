import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
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
    pm.put(page);
    setState(() {});
  }

  void pop() async {
    // first we pop
    final popedPage = pm.currentPage;
    pm.pop();
    // reloading currentPage is a smart thing to do
    final cp = pm.currentPage;
    if (cp is HomePage) {
      // if we are going in home page and
      // the poped page has a node, we want to refresh that palette
      // because it might have changed (example: last message preview)
      if (popedPage is ChatPage) {
        await writePalette2(popedPage.node, _palettes, bGen, refreshHome,
            h: true);
      } else if (popedPage is SnipViewPage) {
        // TODO this fucking shit right here dog
      }
      pm.refresh(homePage());
    } else if (cp is MoneyPage) {
      pm.refresh(moneyPage());
    } else if (cp is PaymentPage) {
      pm.refresh(moneyPage());
    } else if (cp is AddFriendPage) {
      pm.refresh(searchPage());
    } else if (cp is NodePage) {
      pm.refresh(nodePage(cp.node));
    } else if (cp is ChatPage) {
      pm.refresh(chatPage(cp.node));
    } else if (cp is ForwardingPage) {
      pm.refresh(forwardPage(cp.forwardingObjects));
    }
    setState(() {});
  }

  void refresh(ru.Down4PageWidget page) {
    pm.refresh(page);
    setState(() {});
  }

  List<r.Request> _requests = [];

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
    processWebRequests();
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
            assetPath: 'assets/images/redArrow.png',
            pressFunc: () async => push(await snipView(node)),
            rightMost: true)
      ];
    } else {
      Message? lastMsg = node.messages.isEmpty
          ? null
          : await node.messages.last.getLocalMessage();
      return [
        ButtonsInfo2(
            assetPath: lastMsg?.isRead ?? true
                ? 'assets/images/50.png'
                : 'assets/images/filled.png',
            pressFunc: () => push(chatPage(node)),
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
      final eventPayload = event.snapshot.value as String;
      if (eventKey == null) return;
      msgQueue.child(eventKey).remove(); // consume it

      if (eventPayload == "p") {
        // PAYMENT!
        final payment = await r.getPayment(eventKey);
        if (payment == null) return;
        await g.wallet.parsePayment(g.self.id, payment);
        if (pm.currentPage is MoneyPage) refresh(moneyPage());
        return;
      } else if (eventPayload == "m") {
        // MESSAGE!
        final snapshot = await messagesRef.child(eventKey).get();
        if (!snapshot.exists) return;
        final msgJson = Map<String, dynamic>.from(snapshot.value as Map);
        final msg = Message.fromJson(msgJson);
        final theRoot = msg.root ?? msg.senderID;
        ChatableNode? rootNode = homeNode(theRoot) as ChatableNode?;
        if (rootNode == null) {
          // need to download it
          final singleNodeList = await r.getNodes([theRoot]);
          if (singleNodeList == null || singleNodeList.length != 1) return;
          rootNode = singleNodeList.first as ChatableNode;
          if (rootNode is GroupNode) {
            await rootNode.save();
            await localPalettesRoutine();
            // TODO should we await this?

            // final userIDs = homePalettes.whereNodeIs<Person>().asIds().toSet();
            // final toFetch = rootNode.group.difference(userIDs);
            // if (toFetch.isNotEmpty) {
            //   final fetchNodes = await r.getNodes(toFetch);
            //   if (fetchNodes != null) {
            //     for (var fNode in fetchNodes) {
            //       await writePalette2(fNode, _palettes, bGen, refreshHome,
            //           h: true);
            //     }
            //   }
            // }
          }
        }

        await msg.onReceipt();

        rootNode
          ..messages.add(msg.id)
          ..updateActivity()
          ..save();

        await writePalette2(rootNode, _palettes, bGen, refreshHome, h: true);

        if (pm.currentPage is HomePage) {
          refresh(homePage());
        } else if (pm.currentPage is ChatPage && pm.currentID == theRoot) {
          refresh(chatPage(rootNode));
        }
      } else {
        // SNIP! The payload is senderID OR senderID@root
        final String root = eventPayload;
        final String mediaID = eventKey;

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

  Future<void> processWebRequests() async {
    Future<bool> processWebRequest(r.Request req) async {
      if (req is r.ChatRequest) {
        final root = req.message.root ?? req.targets.first;
        var node = homeNode(root) as ChatableNode;

        final bool sendingToSelf = node.id == g.self.id;
        // first, save the message, if we are sending it to self,
        // it's a saved message, hence isSaved will be true
        req.message
          ..isRead = true
          ..isSaved = sendingToSelf
          ..save();

        // if there is a media, we need to save it and add
        // the reference of the message to it
        req.media
          ?..references.add(req.message.id)
          ..save();

        node
          ..messages.add(req.message.id)
          ..updateActivity()
          ..save();

        if (pm.currentPage is ChatPage && pm.currentID == root) {
          refresh(chatPage(node));
        }

        // // we refresh or write the home palette
        // // the current state after a pop is always refresh, hence we will
        // // see the changes when we go back home
        // await writePalette2(node, _palettes, bGen, refreshHome, h: true);
        // We don't need to do this anymore.

        // we don't do the request if we are sending this message to self
        if (!sendingToSelf) {
          if (req.media != null) {
            await uploadOrUpdateMedia(
              req.media!,
              skipCheck: req.media!.metadata.canSkipCheck,
            );
          }
          return req.send();
        }

        return true;
      } else if (req is r.PingRequest) {
        final success = req.send();
        _tec.clear();
        unselectSelection();
        refresh(homePage());
        return success;
      } else if (req is r.SnipRequest) {
        final success = req.send();
        await unselectSelection();
        refreshHome();
        return success;
      } else if (req is r.HyperchatRequest) {
        push(loadingPage());

        if (req.media != null) {
          await uploadOrUpdateMedia(
            req.media!,
            skipCheck: req.media!.metadata.canSkipCheck,
          );
        }

        var node = await req.send();
        if (node == null) {
          refreshHome();
          return false;
        }
        await unselectSelection();
        node
          ..messages.add(req.message.id)
          ..updateActivity()
          ..save();
        req.message
          ..isRead = true
          ..save();
        await writePalette2(node, _palettes, bGen, refreshHome, h: true);

        pm
          ..pop()
          ..pop()
          ..put(chatPage(node));
        setState(() {});

        return true;
      } else if (req is r.GroupRequest) {
        push(loadingPage());

        if (req.media != null) {
          await uploadOrUpdateMedia(
            req.media!,
            skipCheck: req.media!.metadata.canSkipCheck,
          );
        }

        var node = await req.send();
        if (node == null) {
          refreshHome();
          return false;
        }
        await unselectSelection();

        req.message.save();

        node
          ..messages.add(req.message.id)
          ..updateActivity()
          ..save();

        await writePalette2(node, _palettes, bGen, refreshHome, h: true);

        pm
          ..pop()
          ..pop()
          ..put(chatPage(node));

        setState(() {});

        return true;
      } else if (req is r.PaymentRequest) {
        g.wallet.parsePayment(g.self.id, req.payment);
        return await req.send();
      } else {
        return false;
      }
    }

    final requestsToProcess = List<r.Request>.from(_requests);
    print("There are ${requestsToProcess.length} requests to process!");
    for (final req in requestsToProcess) {
      final success = await processWebRequest(req);
      if (success) _requests.remove(req);
    }
    print("There are now ${_requests.length} requests to process!");
  }

  Future<void> sendSnip({
    required String path,
    required bool isReversed,
    required double aspectRatio,
    String? text,
  }) async {
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
    var snipRequests = <r.SnipRequest>[];

    final selectedPalettes = homePalettes.selected();
    for (final node in selectedPalettes.asNodes()) {
      if (node is GroupNode) {
        final targets = homePalettes.those(node.group).whereNodeIs<User>();
        final sr = r.SnipRequest(
            mediaID: media.id,
            root: node.id,
            groupName: node.name,
            senderID: g.self.id,
            targets: targets.asIds().toList(growable: false));
        snipRequests.add(sr);
      } else {
        personTargets.add(node.id);
      }
    }

    if (personTargets.isNotEmpty) {
      final targets = selectedPalettes.asNodes().whereType<Person>().asIds();
      final sr = r.SnipRequest(
          mediaID: media.id,
          senderID: g.self.id,
          targets: targets.toList(growable: false));
      snipRequests.add(sr);
    }

    _requests.addAll(snipRequests);
    processWebRequests();
    await unselectSelection();
    pop();
  }

  Triple<List<Palette2>, Iterable<Person>, int> homeTransition() {
    final allHomePalettes = formattedHomePalettes;
    final originalOrder = allHomePalettes.asIds();
    final visibleHomePalettes = allHomePalettes;
    final hidden = _hiddenPalettes.values;
    final selected = visibleHomePalettes.selected();
    final unselected = visibleHomePalettes.notSelected();
    final idsInGroups = selected
        .asNodes()
        .whereType<GroupNode>()
        .map((g) => g.group)
        .expand((id) => id)
        .toSet();
    final selectedUsers = selected.whereNodeIs<Person>();
    final selectedGroups = selected.whereNodeIs<GroupNode>();
    final unselectedGroups = unselected.whereNodeIs<GroupNode>();
    final unselectedUsers = unselected.whereNodeIs<Person>();
    final unHide = hidden.those(idsInGroups);
    // final keepHiding = hidden.notThose(idsInGroups);
    final unselectedUsersNotInGroups = unselectedUsers.notThose(idsInGroups);
    final unselectedUserInGroups = unselectedUsers.those(idsInGroups);
    // groups are folded
    // unHide should get a left to right show transition
    // not selected should get a fold transition
    // selected are unselected
    // all are deactivated
    final pals = <Palette2>{
      ...unHide, //.deactivated().map((e) => e.withoutButton()),
      ...selectedUsers.map(
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

    print("pals=${pals.map((e) => e.node.name).toList()}");
    return Triple(
      pals.inThatOrder(originalOrder.followedBy(unHide.asIds())),
      pals.where((p) => !p.fold).asNodes<Person>(),
      unHide.length,
    );
  }

  // ============================== PAGES ============================== //

  ru.Down4PageWidget homePage() {
    return HomePage(
      scrollController: _homeScrollController,
      palettes: formattedHomePalettes,
      hyperchat: () => push(hyperchatPage()),
      group: () => push(groupPage()),
      money: () => push(moneyPage()),
      ping: (pingRequest) {
        _requests.add(pingRequest);
        processWebRequests();
      },
      snip: () async => push(await snipPage()),
      search: () => push(searchPage()),
      delete: () {
        for (final p in List<Palette2>.from(homePalettes)) {
          if (p.selected) {
            _palettes.remove(p.node.id);
            g.boxes.nodes.delete(p.node.id);
          }
        }
        refresh(homePage());
        localPalettesRoutine();
      },
      forward: () => push(forwardPage(homePalettes.selected().toList())),
    );
  }

  ru.Down4PageWidget loadingPage({String? seed}) {
    return LoadingPage2(seed: seed);
  }

  ru.Down4PageWidget forwardPage(List<Down4Object> forwardingObjects) {
    return ForwardingPage(
        possibleTargets: formattedHomePalettes.reversed.asNodes<ChatableNode>(),
        singleForward: (objects, single) {
          for (var object in objects) {
            // TODO FORWARDING MULTIPLE OBJECTS
          }
        },
        forwardingObjects: forwardingObjects,
        forward: (objects, targets) {
          // TODO FORWARDING MULTIPLE OBJECTS TO MULTIPLE TARGETS
        },
        hyperForward: (objects, targets) {
          // TODO FORWARDING MULTIPLE OBJECTS IN HYPERCHAT
        },
        back: pop);
  }

  ru.Down4PageWidget paymentPage(Down4Payment payment) {
    return PaymentPage(
      ok: () => setState(() {
        pm.pop();
        pm.pop();
        refresh(homePage());
      }),
      paymentRequest: (pr) {
        _requests.add(pr);
        processWebRequests();
      },
      back: pop,
      payment: payment,
    );
  }

  ru.Down4PageWidget moneyPage() {
    final transition = homeTransition();
    return MoneyPage(
        initialOffset: homeScroll,
        palettesForTransition: transition.first,
        people: transition.second,
        nHidden: transition.third,
        openPayment: (payment) => push(paymentPage(payment)),
        homePalettes: formattedHomePalettes,
        makePayment: (payment) {
          push(paymentPage(payment));
          g.wallet.parsePayment(g.self.id, payment);
          unselectSelection();
        },
        back: pop);
  }

  ru.Down4PageWidget hyperchatPage() {
    final transition = homeTransition();
    return HyperchatPage(
      initialOffset: homeScroll,
      palettesForTransition: transition.first,
      people: transition.second,
      nHidden: transition.third,
      homePalettes: formattedHomePalettes,
      hyperchatRequest: (hyperchatRequest) {
        _requests.add(hyperchatRequest);
        processWebRequests();
      },
      back: pop,
      ping: (pingRequest) {
        _requests.add(pingRequest);
        processWebRequests();
      },
    );
  }

  ru.Down4PageWidget groupPage() {
    final transition = homeTransition();
    return GroupPage(
        initialOffset: homeScroll,
        back: pop,
        groupRequest: (groupRequest) {
          _requests.add(groupRequest);
          processWebRequests();
        },
        palettesForTransition: transition.first,
        people: transition.second,
        nHidden: transition.third,
        homePalettes: formattedHomePalettes);
  }

  ru.Down4PageWidget searchPage() {
    return AddFriendPage(
        openNode: (node) => push(chatPage(node as ChatableNode)),
        add: (pals) async {
          for (final p in pals) {
            if (!p.selected) continue;
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

    void nextCam() {
      snipPage(ctrl: ctrl, camera: (camera + 1) % 2, reload: true, res: res);
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
        payNode: (node) => print("TODO PAY NODE"),
        back: pop);
  }

  ru.Down4PageWidget chatPage(ChatableNode node) {
    return ChatPage(
        node: node,
        openNode: (node_) => push(chatPage(node_ as ChatableNode)),
        subNodes: node is GroupNode
            ? node.group
                .map((e) => homeNode(e) ?? hiddenNode(e))
                .whereType<ChatableNode>()
            : null, // TODO, will need future nodes
        send: (messageRequest) {
          _requests.add(messageRequest);
          processWebRequests();
        },
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
