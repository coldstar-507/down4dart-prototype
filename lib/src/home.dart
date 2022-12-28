import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:down4/src/bsv/utils.dart';
import 'package:down4/src/data_objects.dart';
import 'package:down4/src/render_objects/navigator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:video_player/video_player.dart';

import 'boxes.dart';
import 'web_requests.dart' as r;
import 'down4_utility.dart';
import 'bsv/wallet.dart';
import 'bsv/types.dart';
import 'themes.dart';

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
import 'render_objects/render_utils.dart';
import 'render_objects/console.dart';

class Home extends StatefulWidget {
  final List<CameraDescription> cameras;
  final User self;
  final Wallet wallet;

  const Home({
    required this.cameras,
    required this.self,
    required this.wallet,
    Key? key,
  }) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Widget? _page;
  var _exchangeRate = b.loadExchangeRate();

  List<r.Request> _requests = [];

  Map<Identifier, Map<Identifier, Palette>> _paletteMap = {
    "Home": {},
    "Search": {},
    "Forward": {},
    "Payments": {},
    "Hidden": {},
  };

  StreamSubscription? _messageListener;

  List<Location> _locations = [Location(id: "Home", scroll: 0.0)];

  late ScrollController _homeScrollController = ScrollController()
    ..addListener(() {
      print("Moved");
      _locations.first.scroll = _homeScrollController.offset;
    });

  List<Palette> _forwardingPalettes = [];

  var _tec = TextEditingController();

  // ======================================================= INITIALIZATION ============================================================ //

  @override
  void initState() {
    super.initState();
    loadExchangeRate();
    loadHomePalettes();
    loadPayments();
    connectToMessages();
    processWebRequests();
    homePage();
  }

  @override
  void dispose() {
    _messageListener?.cancel();
    super.dispose();
  }

  void loadExchangeRate() async {
    _exchangeRate = b.loadExchangeRate();
    updateExchangeRate();
  }

  Future<void> loadHomePalettes() async {
    writePalette(widget.self);

    final jsonEncodedHomeNodes = b.home.values;
    var groupPeopleIDs = Set<Identifier>.identity();
    for (final jsonEncodedHomeNode in jsonEncodedHomeNodes) {
      final node = BaseNode.fromJson(jsonDecode(jsonEncodedHomeNode));
      if (node is GroupNode) {
        groupPeopleIDs.addAll(node.group);
      }
      writePalette(node);
    }

    final homeUsers = palettes().users().asIds().toSet();
    final toFetchIDs = groupPeopleIDs.difference(homeUsers);
    final fetchedNodes = await r.getNodes(toFetchIDs);
    for (final fetchedNode in fetchedNodes ?? <BaseNode>[]) {
      writePalette(fetchedNode, fold: true, fade: true, at: "Hidden");
    }
  }

  void connectToMessages() {
    var msgQueue = db.child("Users").child(widget.self.id).child("M");
    var messagesRef = db.child("Messages");

    _messageListener = msgQueue.onChildAdded.listen((event) async {
      print("New message!");
      final msgID = event.snapshot.key;
      final payload = event.snapshot.value as String;
      if (msgID == null) return;
      msgQueue.child(msgID).remove(); // consume it

      if (payload == "p") {
        final payment = await r.getPayment(msgID);
        if (payment == null) return;
        widget.wallet.parsePayment(widget.self, payment);
        loadPayments();
        return;
      }

      final snapshot = await messagesRef.child(msgID).get();
      if (!snapshot.exists) return;
      final msgJson = Map<String, dynamic>.from(snapshot.value as Map);
      final msg = Down4Message.fromJson(msgJson);
      print("The message: $msgJson");
      switch (msg.type) {
        case Messages.chat:
          msg.save();
          final theRoot = msg.root ?? msg.senderID;
          print("Message is chat");
          if (msg.root != null) {
            print("There is a root in that message: ${msg.root}");
            var rootNode = nodeAt(msg.root!) as ChatableNode?;
            if (rootNode != null) {
              print("root is local, adding the message to it");
              rootNode.messages.add(msg.id);
              // if root is group of hyperchat, we download the media right away
              if (rootNode.isFriendOrGroup && msg.mediaID != null) {
                (await r.getMessageMedia(msg.mediaID!))?.save();
              }
              writePalette(rootNode
                ..updateActivity()
                ..save());
            } else {
              print("root is not local, downloading it");
              // root node is not in home
              // final newNode = await getSingleNode(msg.root!);
              final fetchedNodes = await r.getNodes([msg.root!]);
              if (fetchedNodes == null || fetchedNodes.length != 1) return;
              var newNode = fetchedNodes.first as ChatableNode;
              newNode.messages.add(msg.id);
              if (newNode is GroupNode) {
                // need to get the palettes from the guys who are not friends in this new group
                var idsToFetch = newNode.group
                    .toSet()
                    .difference(palettes().asIds().toSet());
                var newNodes = await r.getNodes(idsToFetch);
                for (var node in newNodes ?? []) {
                  writePalette(node, at: "Hidden", fold: true, fade: true);
                }
              }
              writePalette(newNode
                ..updateActivity()
                ..save());
            }
          } else {
            // msg.root == null
            var userNode = nodeAt(msg.senderID) as User?;
            if (userNode != null) {
              // user is in home
              userNode.messages.add(msg.id);
              // if is friend, we download the media right away
              if (userNode.isFriendOrGroup && msg.mediaID != null) {
                (await r.getMessageMedia(msg.mediaID!))?.save();
              }
              writePalette(userNode
                ..updateActivity()
                ..save());
            } else {
              // userNode is not in home
              final newUserNodes = await r.getNodes([msg.senderID]);
              if (newUserNodes == null || newUserNodes.length != 1) return;
              var newUserNode = newUserNodes.first as User;
              newUserNode.messages.add(msg.id);
              writePalette(newUserNode
                ..updateActivity()
                ..save());
            }
          }
          if (_page is HomePage) {
            homePage();
          } else if (_page is ChatPage && curLoc.id == theRoot) {
            var n = nodeAt(theRoot) as ChatableNode?;
            if (n != null) chatPage(n);
          }
          break;
        case Messages.payment:
          final paymentID = msg.paymentID;
          if (paymentID == null) return;
          final paymentData = await st.ref(paymentID).getData();
          if (paymentData == null) return;
          final paymentString = utf8.decode(paymentData);
          final paymentJson = jsonDecode(paymentString);
          final payment = Down4Payment.fromJson(paymentJson)..save();
          widget.wallet.parsePayment(widget.self, payment);
          if (_page is MoneyPage) moneyPage();
          break;
        case Messages.bill:
          // TODO: Handle this case.
          break;
        case Messages.snip:
          if (msg.root != null) {
            var nodeRoot = nodeAt(msg.root!) as ChatableNode?;
            if (nodeRoot == null) {
              // nodeRoot is not in home, need to download it
              // final newRootNode = await getSingleNode(msg.root!);
              final newRootNodes = await r.getNodes([msg.root!]);
              if (newRootNodes == null || newRootNodes.length != 1) return;
              var newRootNode = newRootNodes.first as ChatableNode;
              newRootNode.snips.add(msg.mediaID!);
              writePalette(newRootNode
                ..updateActivity()
                ..save());
            } else {
              // nodeRoot is in home
              nodeRoot.snips.add(msg.mediaID!);
              writePalette(nodeRoot
                ..updateActivity()
                ..save());
            }
          } else {
            // user snip
            final homeUserRoot = nodeAt(msg.senderID) as ChatableNode?;
            if (homeUserRoot != null) {
              // user is in home
              homeUserRoot.snips.add(msg.mediaID!);
              writePalette(homeUserRoot
                ..updateActivity()
                ..save());
            } else {
              // user is not in home
              // var userNode = await getSingleNode(msg.senderID);
              var userNodes = await r.getNodes([msg.senderID]);
              if (userNodes == null || userNodes.length != 1) return;
              var userNode = userNodes.first as ChatableNode;
              userNode.snips.add(msg.mediaID!);
              writePalette(userNode
                ..updateActivity()
                ..save());
            }
          }
          if (_page is HomePage) homePage();
          break;
      }
    });
  }

  void parsePayment(Down4Payment payment) async {
    widget.wallet.parsePayment(widget.self, payment);
    widget.wallet.save();
    writePalette(Payment(payment: payment), at: "Payments");
  }

  void loadPayments() async {
    await widget.wallet.updateAllStatus();
    widget.wallet.settlementRoutine();
    widget.wallet.save();
    for (final payment in widget.wallet.payments) {
      writePalette(Payment(payment: payment), at: "Payments");
    }
    if (_page is MoneyPage) moneyPage();
  }

  // ======================================================= UTILS ============================================================ //

  Future<void> updateExchangeRate() async {
    final lastUpdate = _exchangeRate.lastUpdate;
    final rightNow = timeStamp();
    if (rightNow - lastUpdate > const Duration(minutes: 10).inMilliseconds) {
      final rate = await r.getExchangeRate();
      if (rate != null) {
        _exchangeRate.rate = rate;
        _exchangeRate.lastUpdate = rightNow;
        b.saveExchangeRate(_exchangeRate);
        if (_page is MoneyPage) moneyPage();
      }
    }
  }

  void unselectSelectedPalettes({
    String at = "Home",
    bool updateActivity = false,
  }) {
    if (updateActivity) {
      for (final p in palettes(at: at)) {
        if (p.selected) {
          p.node.updateActivity();
          selectPalette(p.node.id, at);
        }
      }
    } else {
      for (final p in palettes(at: at)) {
        if (p.selected) {
          selectPalette(p.node.id, at);
        }
      }
    }
  }

  Palette? nodeToPalette(
    BaseNode node, {
    String at = "Home",
    bool fold = false,
    bool fade = false,
  }) {
    if (node is User) {
      String? lastMessagePreview;
      bool messagePreviewWasRead = true;
      if (node.messages.isNotEmpty) {
        var msg = b.loadMessage(node.messages.last);
        lastMessagePreview = msg?.text ?? "&attachment";
        messagePreviewWasRead = msg?.read ?? true;
      }
      return Palette(
          node: node,
          at: at,
          fold: fold,
          isSelf: widget.self.id == node.id,
          fade: fade,
          snipOrMessageToRead: node.snips.isNotEmpty || !messagePreviewWasRead,
          messagePreview: lastMessagePreview,
          messagePreviewWasRead: messagePreviewWasRead,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: at == "Home" && node.snips.isNotEmpty
                  ? "lib/src/assets/redArrow.png"
                  : messagePreviewWasRead
                      ? "lib/src/assets/50.png"
                      : "lib/src/assets/filled.png",
              pressFunc: at == "Home"
                  ? node.snips.isNotEmpty
                      ? checkSnips
                      : openChat
                  : openNode,
              longPressFunc: openNode,
              rightMost: true,
            )
          ]);
    } else if (node is Hyperchat) {
      String? lastMessagePreview;
      bool messagePreviewWasRead = false;
      if (node.messages.isEmpty) {
        return null;
      } else {
        final lastMessageID = node.messages.last;
        final msg = b.loadMessage(lastMessageID);
        if (msg?.timestamp.isExpired ?? true) {
          // put false for test
          print("Last message is expired, deleting hyperchat!");
          b.deleteNode(node.id);
          return null;
        }
        lastMessagePreview = msg?.text ?? "&attachment";
        messagePreviewWasRead = msg?.read ?? false;
      }
      return Palette(
        node: node,
        at: at,
        snipOrMessageToRead: node.snips.isNotEmpty || !messagePreviewWasRead,
        messagePreview: lastMessagePreview,
        messagePreviewWasRead: messagePreviewWasRead,
        imPress: select,
        bodyPress: select,
        buttonsInfo: [
          ButtonsInfo(
            rightMost: true,
            pressFunc: node.snips.isNotEmpty ? checkSnips : openChat,
            assetPath: at == "Home" && node.snips.isNotEmpty
                ? "lib/src/assets/redArrow.png"
                : messagePreviewWasRead
                    ? "lib/src/assets/50.png"
                    : "lib/src/assets/filled.png",
          )
        ],
      );
    } else if (node is Group) {
      String? lastMessagePreview;
      bool messagePreviewWasRead = false;
      if (node.messages.isNotEmpty) {
        var msg = b.loadMessage(node.messages.last);
        lastMessagePreview = msg?.text ?? "&attachment";
        messagePreviewWasRead = msg?.read ?? false;
      }
      return Palette(
        node: node,
        snipOrMessageToRead: node.snips.isNotEmpty || !messagePreviewWasRead,
        messagePreview: lastMessagePreview,
        messagePreviewWasRead: messagePreviewWasRead,
        at: at,
        imPress: select,
        bodyPress: select,
        buttonsInfo: [
          ButtonsInfo(
            rightMost: true,
            pressFunc: node.snips.isNotEmpty ? checkSnips : openChat,
            assetPath: at == "Home" && node.snips.isNotEmpty
                ? "lib/src/assets/redArrow.png"
                : messagePreviewWasRead
                    ? "lib/src/assets/50.png"
                    : "lib/src/assets/filled.png",
          )
        ],
      );
    } else if (node is Payment) {
      return Palette(
        node: node,
        at: "Payments",
        buttonsInfo: [
          ButtonsInfo(
            assetPath: 'lib/src/assets/rightBlackArrow.png',
            pressFunc: (id, at) {
              _locations.add(Location(id: "Payment"));
              paymentPage(node.payment);
            },
            rightMost: true,
          )
        ],
      );
    }
    return null;
  }

  Future<void> processWebRequests() async {
    Future<bool> processWebRequest(r.Request req) async {
      switch (req.type) {
        case r.RequestType.chat:
          req as r.ChatRequest;
          final targetNode = req.message.root ?? req.targets.first;
          var node = nodeAt(targetNode) as ChatableNode?;
          if (node == null) return false;
          await (req.message..read = true).save();
          req.media?.save();

          node
            ..messages.add(req.message.id)
            ..updateActivity()
            ..save(isSelf: widget.self.id == node.id);
          writePalette(node);

          if (_page is ChatPage && _locations.last.id == targetNode) {
            chatPage(node);
          }

          // we don't do the request if we are sending this message to ourself
          if (node.id != widget.self.id) {
            return r.chatRequest(req);
          }

          return false;

        case r.RequestType.ping:
          req as r.PingRequest;
          final success = r.pingRequest(req);
          _tec.clear();
          unselectSelectedPalettes(updateActivity: true);
          homePage();
          return success;

        case r.RequestType.snip:
          req as r.SnipRequest;
          final success = r.snipRequest(req);
          unselectSelectedPalettes(updateActivity: true);
          homePage();
          return success;

        case r.RequestType.hyperchat:
          loadingPage();
          req as r.HyperchatRequest;
          var node = await r.hyperchatRequest(req);
          if (node == null) {
            homePage();
            return false;
          }
          unselectSelectedPalettes();
          node
            ..messages.add(req.message.id)
            ..updateActivity()
            ..save();
          req
            ..message.save()
            ..media?.save();
          writePalette(node);
          openChat(node.id, "Home");
          return true;

        case r.RequestType.group:
          loadingPage();
          req as r.GroupRequest;
          var node = await r.groupRequest(req);
          if (node == null) {
            homePage();
            return false;
          }
          unselectSelectedPalettes();
          node
            ..messages.add(req.message.id)
            ..updateActivity()
            ..save();

          req
            ..message.save()
            ..media?.save();

          writePalette(node);
          openChat(node.id, "Home");
          return true;

        case r.RequestType.payment:
          req as r.PaymentRequest;
          parsePayment(req.payment);
          return await r.paymentRequest(req);
      }
    }

    for (final req in List<r.Request>.from(_requests)) {
      final success = await processWebRequest(req);
      if (success) _requests.remove(req);
    }
  }

  Future<void> sendSnip(
    String? path,
    bool? isVideo,
    bool? toReverse,
    String? text,
    double aspectRatio,
  ) async {
    if (path == null) return;
    final timestamp = timeStamp();

    var media = Down4Media.fromCamera(
      path,
      MediaMetadata(
        owner: widget.self.id,
        timestamp: timestamp,
        toReverse: toReverse ?? false,
        isVideo: isVideo ?? false,
        text: text,
        aspectRatio: aspectRatio,
      ),
    );

    var userTargets = <Identifier>[];
    var snipRequests = <r.SnipRequest>[];

    for (final node in palettes().selected().asNodes()) {
      if (node is GroupNode) {
        final sr = r.SnipRequest(
          message: Down4Message(
            type: Messages.snip,
            id: messagePushId(),
            root: node.id,
            timestamp: timestamp,
            mediaID: media.id,
            senderID: widget.self.id,
          ),
          targets: node.group..remove(widget.self.id),
          media: media,
        );
        snipRequests.add(sr);
      } else {
        userTargets.add(node.id);
      }
    }

    if (userTargets.isNotEmpty) {
      final sr = r.SnipRequest(
        message: Down4Message(
          type: Messages.snip,
          id: messagePushId(),
          timestamp: timestamp,
          mediaID: media.id,
          senderID: widget.self.id,
        ),
        targets: palettes().selected().users().asIds().toList(growable: false),
        media: media,
      );
      snipRequests.add(sr);
    }

    for (int i = 0; i < snipRequests.length; i++) {
      if (i != 0) snipRequests[i].media = null;
    }

    _requests.addAll(snipRequests);
    processWebRequests();
    unselectSelectedPalettes(updateActivity: true);
    homePage();
  }

  // ======================================================= CONSOLE ACTIONS ============================================================ //

  void addPalettes(List<Palette> palettes) {
    for (final node in palettes.asNodes()) {
      if (node is User) {
        node
          ..updateActivity()
          ..isFriend = true;
        writePalette(node, at: "Search");

        User? homeNode;
        if ((homeNode = nodeAt(node.id) as User?) == null) {
          writePalette(node);
          b.saveNode(node);
        } else {
          writePalette(homeNode!..isFriend = true);
          b.saveNode(homeNode);
        }
      } else {
        writePalette(node, at: "Search");
        writePalette(node, onlyIfAbsent: true);
      }
    }
    searchPage();
  }

  void delete({String at = "Home"}) {
    final nodeIDsToRemove = palettes(at: at).selected().asIds();
    for (final nodeID in List<Identifier>.from(nodeIDsToRemove)) {
      b.deleteNode(nodeID);
      paletteMap(at).remove(nodeID);
    }
    // TODO for other places than home
    if (_page is HomePage) homePage();
  }

  Future<bool> search(List<String> ids) async {
    final friendIds = palettes()
        .asNodes<User>()
        .where((user) => user.isFriend)
        .asIds()
        .toList(growable: false);

    final nodes = await r.getNodes(ids);
    if (nodes != null) {
      for (var node in nodes) {
        var node_ = nodeAt(node.id) ?? node;
        if (node_ is User) node_.isFriend = friendIds.contains(node_.id);
        writePalette(node_..updateActivity(), at: "Search");
        searchPage();
      }
      return true;
    }
    return false;
  }

  void putNodeOffLine(User node) {
    final p = nodeToPalette(node, at: "Search");
    if (p != null) {
      _paletteMap["Search"]?.putIfAbsent(node.id, () => p);
      searchPage();
    }
  }

  void back([bool remove = true]) {
    final prevLoc = curLoc.copy();
    if (remove) _locations.removeLast();
    if (curLoc.id == "Home") {
      if (prevLoc.type == "Chat") {
        print("fucking niggers!");
        final lastNode = nodeAt(prevLoc.id);
        if (lastNode != null) writePalette(lastNode);
      }
      _homeScrollController.dispose();
      _homeScrollController =
          ScrollController(initialScrollOffset: curLoc.scroll!)
            ..addListener(() {
              curLoc.scroll = _homeScrollController.offset;
            });
      homePage();
    } else if (curLoc.id == "Search") {
      searchPage();
    } else if (curLoc.type == "Node") {
      nodePage(nodeAt(curLoc.id, curLoc.at!)!);
    } else if (curLoc.type == "Chat") {
      chatPage(
        nodeAt(curLoc.id, curLoc.at!)! as ChatableNode,
      );
    } else if (curLoc.id == "Money") {
      // can't back to money from home, by default going into money checks
      // the homeScrollController for transition, we need an extra flag to
      // tell money page not to use homeScrollController, it would throw error
      moneyPage(fromHome: false);
    }
  }

  void forward(List<Palette> palettes) {
    _locations.add(Location(id: "Forward"));
    _forwardingPalettes = palettes;
    forwardPage();
  }

  // ======================================================== PALETTE ACTIONS ============================================================== //

  Future<void> openNode(String id, String at) async {
    if (_paletteMap[id] == null) {
      BaseNode node;
      if (at == "Home") {
        final nodes = await r.getNodes([id]);
        if (nodes == null) {
          return;
        }
        node = nodes.first;
      } else {
        node = nodeAt(id, at)!;
      }
      if (node is! BranchNode) return;
      final childNodes = await r.getNodes(node.children);
      if (childNodes != null) {
        for (final node in childNodes) {
          writePalette(node, at: id, onlyIfAbsent: true);
        }
      }
    }
    _locations.add(Location(type: "Node", id: id, at: at));
    nodePage(nodeAt(id, at)!);
  }

  void select(String id, String at) {
    selectPalette(id, at);
    if (_page is ForwardingPage) {
      forwardPage();
    } else if (_page is HomePage) {
      homePage();
    } else if (_page is ChatPage) {
      chatPage(nodeAt(at, prevLoc.id) as ChatableNode);
    } else if (_page is NodePage) {
      nodePage(nodeAt(id, at) as BaseNode);
    } else if (_page is AddFriendPage) {
      searchPage();
    } else if (_page is MoneyPage) {
      moneyPage();
    }
  }

  void openChat(String id, String at) {
    _locations.add(Location(at: at, id: id, type: "Chat"));
    chatPage(nodeAt(id, at)! as ChatableNode);
  }

  void checkSnips(String id, String at) {
    snipView(nodeAt(id, at)! as ChatableNode);
  }

  // ======================================================== COMPLEXITY REDUCING GETTERS ? =============================================== //

  Palette? palette(String id, [String at = "Home"]) {
    return _paletteMap[at]?[id];
  }

  Map<String, Palette> paletteMap([String at = "Home"]) {
    return _paletteMap[at]!;
  }

  BaseNode? nodeAt(String id, [String at = "Home"]) {
    return _paletteMap[at]?[id]?.node;
  }

  void writePalette(
    BaseNode node, {
    String at = "Home",
    bool onlyIfAbsent = false,
    bool fold = false,
    bool fade = false,
  }) {
    if (_paletteMap[at] == null) _paletteMap[at] = {};
    final p = nodeToPalette(node, at: at, fold: fold, fade: fade);
    if (p != null) {
      if (onlyIfAbsent) {
        _paletteMap[at]?.putIfAbsent(node.id, () => p);
      } else {
        _paletteMap[at]?[node.id] = p;
      }
    }
  }

  void selectPalette(String id, [String at = "Home"]) {
    _paletteMap[at]![id] = _paletteMap[at]![id]!.invertedSelection();
  }

  Pair<List<Palette>, Iterable<User>>
      homeToMoneyOrHyperchatOrGroupTransition() {
    final allHomePalettes = formattedHomePalettes;
    final originalOrder = allHomePalettes.asIds();
    final visibleHomePalettes = allHomePalettes.unfolded();
    final hidden = allHomePalettes.folded();
    final selected = visibleHomePalettes.selected();
    final unselected = visibleHomePalettes.notSelected();
    final idsInGroups = selected
        .asNodes<GroupNode>()
        .map((g) => g.group)
        .expand((id) => id)
        .toSet();
    final selectedUsers = selected.users();
    final selectedGroups = selected.groups();
    final unselectedGroups = unselected.groups();
    final unselectedUsers = unselected.users();
    final unHide = hidden.those(idsInGroups);
    final keepHiding = hidden.notThose(idsInGroups);
    final unselectedUsersNotInGroups = unselectedUsers.notThose(idsInGroups);
    final unselectedUserInGroups = unselectedUsers.those(idsInGroups);
    // groups are folded
    // unHide should get a left to right show transition
    // not selected should get a fold transition
    // selected are unselected
    // all are deactivated
    final pals = <Palette>{
      ...selectedUsers
          .map((e) => e.animated(selected: false, fadeButton: true)),
      ...unselectedUserInGroups.map((e) => e.animated(fadeButton: true)),
      ...unselectedGroups
          .map((e) => e.animated(fadeButton: true, fade: true, fold: true)),
      ...selectedGroups
          .map((e) => e.animated(fold: true, fadeButton: true, fade: true)),
      ...unselectedUsersNotInGroups
          .map((e) => e.animated(fold: true, fadeButton: true, fade: true)),
      ...unHide
          .map((e) => e.animated(fold: false, fade: false).withoutButton()),
      ...keepHiding
    };

    print("pals=${pals.map((e) => e.node.name).toList()}");
    return Pair(
      // pals.inReversedOrder(originalOrder),
      pals.inThatOrder(originalOrder),
      pals.unfolded().asNodes<User>(),
    );
  }

  Location get curLoc => _locations.last;

  Iterable<Palette> palettes({at = "Home"}) {
    return _paletteMap[at]?.values ?? const Iterable<Palette>.empty();
  }

  List<Palette> get formattedHomePalettes {
    return palettes().followedBy(palettes(at: "Hidden")).formattedReverse();
  }

  Location get prevLoc {
    if (_locations.length > 1) {
      return _locations[_locations.length - 2];
    }
    throw "Invalid previous location";
  }

  void homePage([bool extra = false]) {
    _page = HomePage(
      scrollController: _homeScrollController,
      palettes: formattedHomePalettes,
      console: Console(
        inputs: [
          ConsoleInput(
            tec: _tec,
            placeHolder: ":)",
          ),
        ],
        topButtons: [
          ConsoleButton(
            name: "Hyperchat",
            onPress: hyperchatPage,
          ),
          ConsoleButton(
              name: "Money",
              onPress: () {
                _locations.add(Location(id: "Money"));
                moneyPage();
              }),
        ],
        bottomButtons: [
          ConsoleButton(
              showExtra: extra,
              name: "Group",
              bottomEpsilon: -0.3,
              widthEpsilon: 0.7,
              heightEpsilon: -1.0,
              onPress: () => extra ? homePage(!extra) : groupPage(),
              isSpecial: true,
              onLongPress: () => homePage(!extra),
              extraButtons: [
                ConsoleButton(name: "Delete", onPress: delete),
                ConsoleButton(
                  name: "Forward",
                  onPress: () => forward(
                    formattedHomePalettes.selected().toList(growable: false),
                  ),
                ),
                ConsoleButton(name: "Shit", onPress: () => homePage(!extra)),
                ConsoleButton(name: "Wacko", onPress: () => homePage(!extra)),
              ]),
          ConsoleButton(
            name: "Search",
            onPress: () {
              _locations.add(Location(id: "Search"));
              searchPage();
            },
          ),
          ConsoleButton(
            name: "Ping",
            onPress: () {
              if (_tec.value.text.isNotEmpty) {
                final pr = r.PingRequest(
                  text: _tec.value.text,
                  targets: palettes().users().asIds().toList(growable: false),
                  senderID: widget.self.id,
                );
                _requests.add(pr);
                processWebRequests();
                _tec.clear();
              }
            },
            onLongPress: snipPage,
            isSpecial: true,
          ),
        ],
      ),
    );
    setState(() {});
  }

  void loadingPage({String? seed}) {
    _page = LoadingPage2(seed: seed);
    setState(() {});
  }

  void forwardPage() {
    final homeChatables = palettes().asNodes<ChatableNode>().formatted();

    if (palettes(at: "Forward").length != homeChatables.length) {
      for (final n in homeChatables) {
        writePalette(n, at: "Forward");
      }
    }

    _page = ForwardingPage(
      homeUsers: palettes(at: "Forward").toList(growable: false),
      console: Console(
        forwardingPalette: _forwardingPalettes,
        topButtons: [
          ConsoleButton(name: "Forward", onPress: () => print("TODO")),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: back),
          ConsoleButton(name: "Hyper", onPress: () => print("TODO")),
        ],
      ),
    );
    setState(() {});
  }

  void paymentPage(Down4Payment payment) {
    _page = PaymentPage(
      self: widget.self,
      ok: () {
        _locations.removeLast();
        _locations.removeLast();
        homePage();
      },
      paymentRequest: (pr) {
        _requests.add(pr);
        processWebRequests();
      },
      back: back,
      payment: payment,
    );
    setState(() {});
  }

  void moneyPage({bool fromHome = true}) {
    final transition = homeToMoneyOrHyperchatOrGroupTransition();
    // updateExchangeRate();
    _page = MoneyPage(
      initialOffset: fromHome ? _homeScrollController.offset : 0.0,
      self: widget.self,
      wallet: widget.wallet,
      transitioned: transition.first,
      trueTargets: transition.second,
      exchangeRate: _exchangeRate.rate,
      homePalettes: formattedHomePalettes,
      importMoney: (payment) {
        parsePayment(payment);
        moneyPage(fromHome: false);
      },
      paymentAsPalettes: palettes(at: "Payments")
          .toList(growable: false)
          .reversed
          .toList(growable: false),
      paymentRequest: (paymentRequest) {
        _requests.add(paymentRequest);
        processWebRequests();
      },
      makePayment: (payment) {
        parsePayment(payment);
        _locations.add(Location(id: "Payment"));
        unselectSelectedPalettes(updateActivity: true);
        paymentPage(payment);
      },
      back: back,
      pageIndex: curLoc.pageIndex,
      onPageChange: (idx) => curLoc.pageIndex = idx,
    );
    setState(() {});
  }

  void hyperchatPage() {
    final transition = homeToMoneyOrHyperchatOrGroupTransition();
    _page = HyperchatPage(
      initialOffset: _homeScrollController.offset,
      self: widget.self,
      palettes: formattedHomePalettes,
      transitioned: transition.first,
      userTargets: transition.second,
      hyperchatRequest: (hyperchatRequest) {
        _requests.add(hyperchatRequest);
        processWebRequests();
      },
      cameras: widget.cameras,
      back: homePage,
      ping: (pingRequest) {
        _requests.add(pingRequest);
        processWebRequests();
      },
    );
    setState(() {});
  }

  void groupPage() {
    final transition = homeToMoneyOrHyperchatOrGroupTransition();
    _page = GroupPage(
      initialOffset: _homeScrollController.offset,
      self: widget.self,
      // afterMessageCallback: (node) => writePalette(node),
      back: homePage,
      groupRequest: (groupRequest) {
        _requests.add(groupRequest);
        processWebRequests();
      },
      transitioned: transition.first,
      userTargets: transition.second,
      palettes: formattedHomePalettes,
      cameras: widget.cameras,
    );

    setState(() {});
  }

  void searchPage() {
    _page = AddFriendPage(
      forwardNodes: forward,
      putNodeOffline: putNodeOffLine,
      self: widget.self,
      search: search,
      palettes: _paletteMap["Search"]?.values.toList().reversed.toList() ?? [],
      addCallback: addPalettes,
      backCallback: () {
        _paletteMap["Search"]?.clear();
        back();
      },
    );
    setState(() {});
  }

  Future<void> snipPage({
    CameraController? ctrl,
    int camera = 0,
    ResolutionPreset res = ResolutionPreset.medium,
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

    void snip() async {
      _page = SnipCamera(
        maxZoom: await ctrl!.getMaxZoomLevel(),
        minZoom: await ctrl.getMinZoomLevel(),
        camNum: camera,
        cameraBack: homePage,
        cameraCallBack: sendSnip,
        ctrl: ctrl,
        nextRes: nextRes,
        flip: nextCam,
      );
      setState(() {});
    }

    if (ctrl == null || reload) {
      ctrl = CameraController(widget.cameras[camera], res);
      await ctrl.initialize();
      snip();
    }
  }

  void nodePage(BaseNode node) {
    _page = NodePage(
      pageIndex: curLoc.pageIndex,
      onPageChange: (pageIdx) => curLoc.pageIndex = pageIdx,
      cameras: widget.cameras,
      self: widget.self,
      openChat: (id, at) {
        if (at == "Home") {
          openChat(id, at);
        } else {
          var homeNode = nodeAt(id);
          // if the node is not in Home, we must add it before opening it
          if (homeNode == null) writePalette(node);
          openChat(id, at);
        }
      },
      palette: _paletteMap[_locations.last.at]![node.id]!,
      palettes: _paletteMap[node.id]?.values.toList() ?? <Palette>[],
      openNode: openNode,
      nodeToPalette: nodeToPalette,
      back: back,
    );
    setState(() {});
  }

  void chatPage(ChatableNode node) async {
    Map<Identifier, Palette> senders;
    if (node is GroupNode) {
      if (palettes(at: node.id).length != node.group.length) {
        for (final sender in node.group) {
          BaseNode? userNode;
          if (sender == widget.self.id) {
            userNode = widget.self;
          } else {
            userNode = nodeAt(sender);
            userNode ??= nodeAt(sender, "Hidden");
          }
          if (userNode != null) writePalette(userNode, at: node.id);
        }
      }
      senders = paletteMap(node.id);
    } else {
      senders = {
        widget.self.id: palette(widget.self.id)!,
        node.id: palette(node.id)!,
      };
    }
    _page = ChatPage(
      nodeToPalette: nodeToPalette,
      senders: senders,
      send: (messageRequest) {
        _requests.add(messageRequest);
        processWebRequests();
      },
      self: widget.self,
      node: node,
      cameras: widget.cameras,
      pageIndex: curLoc.pageIndex,
      onPageChange: (idx) => curLoc.pageIndex = idx,
      back: back,
    );
    setState(() {});
  }

  Future<void> snipView(ChatableNode node) async {
    if (node.snips.isEmpty) {
      writePalette(node);
      return homePage();
    }
    final snip = node.snips.first;
    node.snips.remove(snip); // consume it
    b.saveNode(node);
    Down4Media? media;
    dynamic jsonEncodedMedia;
    if ((jsonEncodedMedia = b.snips.get(snip)) == null) {
      media = await r.getMessageMedia(snip);
    } else {
      media = Down4Media.fromJson(jsonDecode(jsonEncodedMedia));
      b.snips.delete(snip); // consume it
    }
    if (media == null) {
      writePalette(node);
      return homePage();
    }
    final scale =
        1 / (media.metadata.aspectRatio ?? 1.0 * Sizes.fullAspectRatio);

    Widget displayMedia;
    String? text = media.metadata.text;
    void Function() back;
    void Function() next;
    if (media.metadata.isVideo) {
      var f = b.writeMediaToFile(media);
      var ctrl = VideoPlayerController.file(f);
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      displayMedia = Transform.scale(
        scaleX: 1 / scale,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
          child: VideoPlayer(ctrl),
        ),
      );

      back = () async {
        await ctrl.dispose();
        f.delete();
        writePalette(node);
        homePage();
      };

      next = () async {
        await ctrl.dispose();
        f.delete();
        snipView(node);
      };

      _page = Stack(children: [
        SizedBox(
          height: Sizes.fullHeight,
          width: Sizes.w,
          child: Transform.scale(
            scaleX: 1 / scale,
            child: Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
              child: VideoPlayer(ctrl),
            ),
          ),
        ),
        media.metadata.text != "" && media.metadata.text != null
            ? Center(
                child: Container(
                  width: Sizes.w,
                  decoration: const BoxDecoration(
                    // border: Border.symmetric(
                    //   horizontal: BorderSide(color: Colors.black38),
                    // ),
                    color: Colors.black38,
                    // color: PinkTheme.snipRibbon,
                  ),
                  constraints: BoxConstraints(
                    minHeight: 16,
                    maxHeight: Sizes.fullHeight,
                  ),
                  child: Text(
                    media.metadata.text!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        Positioned(
          bottom: 0,
          left: 0,
          child: Console(bottomButtons: [
            ConsoleButton(
              name: "Back",
              onPress: () async {
                await ctrl.dispose();
                f.delete();
                writePalette(node);
                homePage();
              },
            ),
            ConsoleButton(
              name: "Next",
              onPress: () async {
                await ctrl.dispose();
                f.delete();
                snipView(node);
              },
            ),
          ]),
        ),
      ]);
    } else {
      await precacheImage(MemoryImage(media.data), context);
      displayMedia = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
        child: Image.memory(
          media.data,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );

      back = () {
        writePalette(node);
        homePage();
      };

      next = () => snipView(node);
    }

    _page = SnipViewPage(
      displayMedia: displayMedia,
      text: text,
      back: back,
      next: next,
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _page!;

    // print(widget.wallet.payments.length);
    // return _page ?? const LoadingPage();
  }
}
