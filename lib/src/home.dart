import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/data_objects.dart';
import 'package:video_player/video_player.dart';

import 'boxes.dart';
import 'web_requests.dart' as r;
import 'down4_utility.dart' as u;
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

import 'render_objects/palette.dart';
import 'render_objects/chat_message.dart';
import 'render_objects/utils.dart';
import 'render_objects/console.dart';

class Home extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Node self;
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
  Widget? page;
  var exchangeRate = ExchangeRate(lastUpdate: 0, rate: 0.0);

  // The base location is Home with the home palettes
  // You can traverse palettes which will be cached
  // Home -> home palettes
  // paletteID -> child palettes

  Map<Identifier, Map<Identifier, Palette>> paletteMap = {
    "Home": {},
    "Search": {},
    "Forward": {},
  };

  // similar to the palettes, used for local data and caching messages
  Map<String, Map<String, ChatMessage>> messageMap = {
    "Saved": {},
    "MyPosts": {},
  };

  StreamSubscription? messageListener;

  List<Location> locations = [Location(id: "Home")];

  Location get curLoc => locations.last;

  // we pop it when backing in node views
  // when it's empty we should be on home view
  // if _currentLocation is not "Home", it should be _node.id
  List<Node> forwardingNodes = [];

  var tec = TextEditingController();

  // ======================================================= INITIALIZATION ============================================================ //

  @override
  void initState() {
    super.initState();
    updateExchangeRate();
    loadLocalHomePalettes();
    connectToMessages();
    homePage();
  }

  @override
  void dispose() {
    messageListener?.cancel();
    super.dispose();
  }

  Future<void> updateExchangeRate() async {
    final lastUpdate = exchangeRate.lastUpdate;
    final rightNow = u.timeStamp();
    if (rightNow - lastUpdate > const Duration(minutes: 10).inMilliseconds) {
      final rate = await r.getExchangeRate();
      if (rate != null) {
        exchangeRate.rate = rate;
        exchangeRate.lastUpdate = rightNow;
        b.saveExchangeRate(exchangeRate);
        if (page is MoneyPage) moneyPage();
      }
    }
  }

  void loadLocalHomePalettes() {
    final jsonEncodedHomeNodes = b.home.values;
    for (final jsonEncodedHomeNode in jsonEncodedHomeNodes) {
      final node = Node.fromJson(jsonDecode(jsonEncodedHomeNode));
      writePalette(node);
    }
  }

  void connectToMessages() {
    var msgQueue = db.child("Users").child(widget.self.id).child("M");
    var messagesRef = db.child("Messages");

    messageListener = msgQueue.onChildAdded.listen((event) async {
      print("New message!");
      var msgID = event.snapshot.key;
      if (msgID == null) return;
      msgQueue.child(msgID).remove(); // consume it

      final snapshot = await messagesRef.child(msgID).get();
      if (!snapshot.exists) return;
      final msgJson = Map<String, dynamic>.from(snapshot.value as Map);
      final msg = Down4Message.fromJson(msgJson);
      print("The message: $msgJson");
      switch (msg.type) {
        case Messages.chat:
          msg.save();
          print("Message is chat");
          if (msg.root != null) {
            print("There is a root in that message: ${msg.root}");
            var rootNode = nodeAt(msg.root!);
            if (rootNode != null) {
              print("root is local, adding the message to it");
              (rootNode.messages ??= []).add(msg.id);
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
              final newNode = await r.getNodes([msg.root!]);
              if (newNode == null || newNode.length != 1) return;
              (newNode.first.messages ??= <Identifier>[]).add(msg.id);
              print("writing node to home");
              writePalette(newNode.first
                ..updateActivity()
                ..save());
            }
          } else {
            // msg.root == null
            var userNode = nodeAt(msg.senderID);
            if (userNode != null) {
              // user is in home
              (userNode.messages ??= []).add(msg.id);
              // if is friend, we download the media right away
              if (userNode.isFriendOrGroup && msg.mediaID != null) {
                (await r.getMessageMedia(msg.mediaID!))?.save();
              }
              writePalette(userNode
                ..updateActivity()
                ..save());
            } else {
              // userNode is not in home
              final newUserNode = await r.getNodes([msg.senderID]);
              // final newUserNode = await getSingleNode(msg.senderID);
              if (newUserNode == null || newUserNode.length != 1) return;
              (newUserNode.first.messages ??= []).add(msg.id);
              writePalette(newUserNode.first
                ..updateActivity()
                ..save());
            }
          }
          if (page is HomePage) {
            homePage();
          } else if (page is ChatPage &&
              locations.last == (msg.root ?? msg.senderID)) {
            var n = nodeAt(msg.root ?? msg.senderID);
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
          if (page is MoneyPage) moneyPage();
          break;
        case Messages.bill:
          // TODO: Handle this case.
          break;
        case Messages.snip:
          if (msg.root != null) {
            var nodeRoot = nodeAt(msg.root!);
            if (nodeRoot == null) {
              // nodeRoot is not in home, need to download it
              // final newRootNode = await getSingleNode(msg.root!);
              final newRootNode = await r.getNodes([msg.root!]);
              if (newRootNode == null || newRootNode.length != 1) return;
              (newRootNode.first.snips ??= []).add(msg.mediaID!);
              writePalette(newRootNode.first
                ..updateActivity()
                ..save());
            } else {
              // nodeRoot is in home
              (nodeRoot.snips ??= []).add(msg.mediaID!);
              writePalette(nodeRoot
                ..updateActivity()
                ..save());
            }
          } else {
            // user snip
            final homeUserRoot = nodeAt(msg.senderID);
            if (homeUserRoot != null) {
              // user is in home
              (homeUserRoot.snips ??= []).add(msg.mediaID!);
              writePalette(homeUserRoot
                ..updateActivity()
                ..save());
            } else {
              // user is not in home
              // var userNode = await getSingleNode(msg.senderID);
              var userNode = await r.getNodes([msg.senderID]);
              if (userNode == null || userNode.length != 1) return;
              (userNode.first.snips ??= []).add(msg.mediaID!);
              writePalette(userNode.first
                ..updateActivity()
                ..save());
            }
          }
          if (page is HomePage) homePage();
          break;
      }
    });
  }

  // ======================================================= UTILS ============================================================ //

  void unselectSelectedPalettes([
    String at = "Home",
    bool updateActivity = false,
  ]) {
    if (updateActivity) {
      for (final p in palettes(at)) {
        if (p.selected) {
          paletteMap[at]
              ?[p.node.id] = paletteMap[at]![p.node.id]!.invertedSelection()
            ..node.updateActivity();
        }
      }
    } else {
      for (final p in palettes(at)) {
        if (p.selected) {
          paletteMap[at]?[p.node.id] =
              paletteMap[at]![p.node.id]!.invertedSelection();
        }
      }
    }
  }

  Palette? nodeToPalette(Node node, [String at = "Home"]) {
    switch (node.type) {
      case Nodes.user:
        final friendIDs = palettes()
            .where((p) => p.node.type == Nodes.friend)
            .map((e) => e.node.id)
            .toList();
        return friendIDs.contains(node.id)
            ? nodeToPalette(node..mutateType(Nodes.friend), at)
            : nodeToPalette(node..mutateType(Nodes.nonFriend), at);

      case Nodes.root:
        return Palette(
          node: node,
          at: at,
          // todo
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: openNode,
              rightMost: true,
            )
          ],
        );

      case Nodes.friend:
        String? lastMessagePreview;
        if ((node.messages ??= []).isNotEmpty) {
          var msg = b.loadMessage(node.messages!.last);
          lastMessagePreview = msg.text ?? "&attachment";
        }
        return Palette(
          node: node,
          at: at,
          messagePreview: lastMessagePreview,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: at == "Home" && (node.snips ?? <String>[]).isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
              pressFunc: at == "Home"
                  ? (node.snips ?? <String>[]).isNotEmpty
                      ? checkSnips
                      : openChat
                  : openNode,
              longPressFunc: openNode,
              rightMost: true,
            )
          ],
        );
      case Nodes.market:
        break;
      case Nodes.hyperchat:
        print("Trying to create a hyperchat!");
        String? lastMessagePreview;
        if ((node.messages ??= []).isEmpty) {
          return null;
        } else {
          final lastMessageID = node.messages!.last;
          final msg = b.loadMessage(lastMessageID);
          if (msg.timestamp.isExpired) {
            // put false for test
            print("Last message is expired, deleting hyperchat!");
            b.deleteNode(node.id);
            return null;
          }
          lastMessagePreview = msg.text ?? "&attachment";
        }
        return Palette(
          node: node,
          at: at,
          messagePreview: lastMessagePreview,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              rightMost: true,
              pressFunc: (node.snips ??= []).isNotEmpty ? checkSnips : openChat,
              assetPath: (node.snips ??= []).isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
            )
          ],
        );
      case Nodes.event:
        break;
      case Nodes.checkpoint:
        return Palette(
          node: node,
          at: at,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: "lib/src/assets/rightBlackArrow.png",
              pressFunc: openNode,
              rightMost: true,
            )
          ],
        );

      case Nodes.item:
        break;

      case Nodes.journal:
        break;

      case Nodes.ticket:
        break;

      case Nodes.nonFriend:
        if (node.activity.isExpired) {
          return null;
        }
        String? lastMessagePreview;
        if ((node.messages ??= []).isNotEmpty) {
          var msg = b.loadMessage(node.messages!.last);
          lastMessagePreview = msg.text ?? "&attachment";
        }
        return Palette(
          messagePreview: lastMessagePreview,
          node: node,
          at: at,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              assetPath: at == "Home" && (node.snips ??= <String>[]).isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
              pressFunc: at == "Home"
                  ? (node.snips ??= <String>[]).isNotEmpty
                      ? checkSnips
                      : openChat
                  : openNode,
              longPressFunc: openNode,
              rightMost: true,
            )
          ],
        );

      case Nodes.group:
        print("are we getting some nodes to group or something?");
        String? lastMessagePreview;
        if ((node.messages ??= []).isNotEmpty) {
          var msg = b.loadMessage(node.messages!.last);
          lastMessagePreview = msg.text ?? "&attachment";
        }
        return Palette(
          node: node,
          messagePreview: lastMessagePreview,
          at: at,
          imPress: select,
          bodyPress: select,
          buttonsInfo: [
            ButtonsInfo(
              rightMost: true,
              pressFunc: (node.snips ??= []).isNotEmpty ? checkSnips : openChat,
              assetPath: (node.snips ??= []).isNotEmpty
                  ? "lib/src/assets/rightRedArrow.png"
                  : "lib/src/assets/rightBlackArrow.png",
            )
          ],
        );
    }
    return null;
  }

  Future<void> sendSnip(
    String? path,
    bool? isVideo,
    bool? toReverse,
    String? text,
    double aspectRatio,
  ) async {
    if (path != null) {
      final timestamp = u.timeStamp();

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

      for (final p in palettes().selected()) {
        if (p.node.isGroup) {
          final sr = SnipRequest(
            msg: Down4Message(
              type: Messages.snip,
              id: messagePushId(),
              root: p.node.id,
              timestamp: timestamp,
              mediaID: media.id,
              senderID: widget.self.id,
            ),
            targets: (p.node.group ??= [])
              ..removeWhere((userID) => widget.self.id == userID),
            media: media,
          );

          r.snipRequest(sr);
        } else {
          userTargets.add(p.node.id);
        }
      }
      r.snipRequest(SnipRequest(
        msg: Down4Message(
          type: Messages.snip,
          id: messagePushId(),
          timestamp: timestamp,
          mediaID: media.id,
          senderID: widget.self.id,
        ),
        targets: selectedHomeUserPaletteDeactivated.asIds(),
        media: media,
      ));
      unselectSelectedPalettes("Home", true);
    }
    homePage();
  }

  // ======================================================= CONSOLE ACTIONS ============================================================ //

  void addUsers(List<Node> friends) {
    for (final friend in friends) {
      friend
        ..mutateType(Nodes.friend)
        ..updateActivity();
      writePalette(friend, at: "Search");

      Node? homeNode;
      if ((homeNode = nodeAt(friend.id)) == null) {
        writePalette(friend);
        b.saveNode(friend);
      } else {
        writePalette(homeNode!..mutateType(Nodes.friend));
        b.saveNode(homeNode);
      }
    }
    searchPage();
  }

  Future<bool> ping(ChatRequest request) async {
    // TODO
    return true;
  }

  void delete([String at = "Home"]) {
    for (final p in palettes(at).selected()) {
      b.deleteNode(p.node.id);
      paletteMap[at]?.remove(p.node.id);
    }
    // TODO for other places than home
    if (page is HomePage) homePage();
  }

  Future<bool> search(List<String> ids) async {
    final nodes = await r.getNodes(ids);
    print("ids: $ids\nnodes: ${nodes?.length}");
    if (nodes != null) {
      for (var node in nodes) {
        writePalette(node..updateActivity(), at: "Search");
        searchPage();
      }
      return true;
    }
    return false;
  }

  void putNodeOffLine(Node node) {
    final p = nodeToPalette(node, "Search");
    if (p != null) {
      paletteMap["Search"]?.putIfAbsent(node.id, () => p);
      searchPage();
    }
  }

  Future<bool> pingRequest() async {
    if (tec.value.text.isEmpty) return false;
    final targets = palettes().selected().asIds();
    final pr = PingRequest(
      text: tec.value.text,
      targets: targets,
      senderID: widget.self.id,
    );
    final success = r.pingRequest(pr);
    tec.clear();
    if (await success) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> chatRequest(ChatRequest req) async {
    final targetNode = req.msg.root ?? req.targets.first;
    var node = nodeAt(targetNode);
    if (node == null) return false;
    (node.messages ??= []).add(req.msg.id);
    req.msg.save();
    req.media?.save();
    if (page is ChatPage && locations.last.id == targetNode) {
      chatPage(node);
    }
    return r.chatRequest(req);
  }

  Future<bool> hyperchatRequest(HyperchatRequest req) async {
    var node = await r.hyperchatRequest(req);
    if (node == null) return false;
    (node.messages ??= []).add(req.msg.id);
    req.msg.save();
    req.media?.save();
    writePalette(node);
    homePage();
    return true;
  }

  Future<bool> groupRequest(GroupRequest req) async {
    var node = await r.groupRequest(req);
    if (node == null) return false;
    (node.messages ??= []).add(req.msg.id);
    req.msg.save();
    req.media?.save();
    writePalette(node);
    chatPage(node);
    return true;
  }

  Future<bool> paymentRequest(PaymentRequest req) async {
    return await r.paymentRequest(req);
  }

  void back([bool remove = true]) {
    if (remove) locations.removeLast();
    if (locations.last.id == "Home") {
      homePage();
    } else if (locations.last.id == "Search") {
      searchPage();
    } else if (locations.last.type == "Node") {
      nodePage(nodeAt(locations.last.id, locations.last.at!)!);
    } else if (locations.last.type == "Chat") {
      chatPage(nodeAt(locations.last.id, locations.last.at!)!);
    }
  }

  void forward(List<Node> nodes) {
    forwardingNodes = nodes;
    forwardPage();
  }

  // ======================================================== NODE ACTIONS ============================================================== //

  Future<void> openNode(String id, String at) async {
    if (paletteMap[id] == null) {
      Node node;
      if (at == "Home") {
        final nodes = await r.getNodes([id]);
        if (nodes == null) {
          return;
        }
        node = nodes.first;
      } else {
        node = nodeAt(id, at)!;
      }
      final childNodes = await r.getNodes(node.childs ?? []);
      if (childNodes != null) {
        for (final node in childNodes) {
          var p = nodeToPalette(node, id);
          if (p != null) paletteMap[id]!.putIfAbsent(node.id, () => p);
        }
      }
    }
    locations.add(Location(type: "Node", id: id, at: at));
    nodePage(nodeAt(id, at)!);
  }

  void select(String id, String at) {
    selectPalette(id, at);
    if (page is ForwardingPage) {
      forwardPage();
    } else if (page is HomePage) {
      homePage();
    } else if (page is ChatPage) {
      chatPage(nodeAt(at, prevLoc.id)!);
    } else if (page is NodePage) {
      nodePage(nodeAt(id, at)!);
    } else if (page is AddFriendPage) {
      searchPage();
    }
  }

  void openChat(String id, String at) {
    locations.add(Location(at: at, id: id, type: "Chat"));
    chatPage(nodeAt(id, at)!);
  }

  void checkSnips(String id, String at) {
    snipView(nodeAt(id, at)!);
  }

  // ======================================================== COMPLEXITY REDUCING GETTERS ? =============================================== //

  Palette? palette(String id, [String at = "Home"]) {
    return paletteMap[at]?[id];
  }

  Node? nodeAt(String id, [String at = "Home"]) {
    return paletteMap[at]?[id]?.node;
  }

  void writePalette(
    Node node, {
    String at = "Home",
    bool onlyIfAbsent = false,
  }) {
    if (paletteMap[at] == null) paletteMap[at] = {};
    final p = nodeToPalette(node, at);
    if (p != null) {
      if (onlyIfAbsent) {
        paletteMap[at]?.putIfAbsent(node.id, () => p);
      } else {
        paletteMap[at]?[node.id] = p;
      }
    }
  }

  void selectPalette(String id, [String at = "Home"]) {
    paletteMap[at]![id] = paletteMap[at]![id]!.invertedSelection();
  }

  List<Palette> get selectedFriendPalettesDeactivated {
    var selectedGroups = palettes().where(
      (p) =>
          (p.node.type == Nodes.hyperchat || p.node.type == Nodes.group) &&
          p.selected,
    );
    var idsInSelGroups = [];
    for (final shc in selectedGroups) {
      for (final uid in shc.node.group!) {
        if (!idsInSelGroups.contains(uid)) {
          idsInSelGroups.add(uid);
        }
      }
    }

    var palettes_ = <Palette>[];
    final selectedNonGroups = formattedHomePalettes.where(
      (p) => (p.node.type == Nodes.friend) && p.selected,
    );
    for (final pal in selectedNonGroups) {
      if (!idsInSelGroups.contains(pal.node.id)) {
        palettes_.add(pal.deactivated());
      }
    }

    return palettes_;
  }

  List<Palette> get selectedHomeUserPaletteDeactivated {
    var selectedGroups = formattedHomePalettes.where(
      (p) =>
          (p.node.type == Nodes.hyperchat || p.node.type == Nodes.group) &&
          p.selected,
    );
    var idsInSelGroups = <Identifier>[];
    for (final shc in selectedGroups) {
      for (final uid in shc.node.group!) {
        if (!idsInSelGroups.contains(uid)) {
          idsInSelGroups.add(uid);
        }
      }
    }

    var palettes = <Palette>[];
    for (final id in idsInSelGroups) {
      if (palette(id) != null) {
        palettes.add(palette(id)!.deactivated());
      }
    }

    final selectedNonGroups = formattedHomePalettes.where(
      (p) =>
          (p.node.type == Nodes.friend || p.node.type == Nodes.nonFriend) &&
          p.selected,
    );
    for (final pal in selectedNonGroups) {
      if (!idsInSelGroups.contains(pal.node.id)) {
        palettes.add(pal.deactivated());
      }
    }

    return palettes;
  }

  List<Palette> palettes([String at = "Home"]) {
    return paletteMap[at]?.values.toList(growable: false) ?? <Palette>[];
  }

  List<Palette> get formattedHomePalettes {
    return palettes()
      ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  }

  Location get prevLoc {
    if (locations.length > 1) {
      return locations[locations.length - 2];
    }
    throw "Invalid previous location";
  }

  // ============================================================== BUILD ================================================================ //

  void homePage([bool extra = false]) {
    page = HomePage(
      palettes: formattedHomePalettes,
      console: Console(
        inputs: [
          ConsoleInput(
            tec: tec,
            placeHolder: ":)",
          ),
        ],
        topButtons: [
          ConsoleButton(name: "Hyperchat", onPress: hyperchatPage),
          ConsoleButton(name: "Money", onPress: moneyPage),
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
                ConsoleButton(name: "Shit", onPress: () => homePage(!extra)),
                ConsoleButton(name: "Wacko", onPress: () => homePage(!extra)),
              ]),
          ConsoleButton(
            name: "Search",
            onPress: () {
              locations.add(Location(id: "Search"));
              searchPage();
            },
          ),
          ConsoleButton(
            name: "Ping",
            onPress: pingRequest,
            onLongPress: snipPage,
            isSpecial: true,
          ),
        ],
      ),
    );
    setState(() {});
  }

  void forwardPage() {
    for (final p in palettes().chatables()) {
      writePalette(p.node, at: "Forward");
    }

    page = ForwardingPage(
      homeUsers: paletteMap["Forward"]!.values.toList(),
      console: Console(
        forwardingNodes: forwardingNodes,
        topButtons: [
          ConsoleButton(name: "Forward", onPress: () => print("TODO")),
        ],
        bottomButtons: [
          ConsoleButton(name: "Back", onPress: () => back(false)),
          ConsoleButton(name: "Hyper", onPress: () => print("TODO")),
        ],
      ),
    );
    setState(() {});
  }

  void moneyPage() {
    updateExchangeRate();
    print(exchangeRate);
    page = MoneyPage(
      self: widget.self,
      wallet: widget.wallet,
      exchangeRate: exchangeRate.rate,
      palettes: selectedHomeUserPaletteDeactivated,
      back: homePage,
    );
    setState(() {});
  }

  void hyperchatPage() {
    page = HyperchatPage(
      self: widget.self,
      palettes: selectedHomeUserPaletteDeactivated,
      hyperchatRequest: hyperchatRequest,
      cameras: widget.cameras,
      back: homePage,
      ping: ping,
    );
    setState(() {});
  }

  void groupPage() {
    page = GroupPage(
      self: widget.self,
      afterMessageCallback: (node) => writePalette(node),
      back: homePage,
      groupRequest: groupRequest,
      palettes: selectedHomeUserPaletteDeactivated,
      cameras: widget.cameras,
    );

    setState(() {});
  }

  void searchPage() {
    page = AddFriendPage(
      forwardNodes: forward,
      putNodeOffline: putNodeOffLine,
      self: widget.self,
      search: search,
      palettes: paletteMap["Search"]?.values.toList().reversed.toList() ?? [],
      addCallback: addUsers,
      backCallback: () {
        paletteMap["Search"]?.clear();
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
      page = SnipCamera(
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

  void nodePage(Node node) {
    page = NodePage(
      pageIndex: curLoc.pageIndex,
      onPageChange: (pageIdx) {
        curLoc.pageIndex = pageIdx;
        nodePage(node);
      },
      cameras: widget.cameras,
      self: widget.self,
      openChat: openChat,
      palette: paletteMap[locations.last.at]![node.id]!,
      palettes: paletteMap[node.id]?.values.toList() ?? <Palette>[],
      openNode: openNode,
      nodeToPalette: nodeToPalette,
      back: back,
    );
    setState(() {});
  }

  void chatPage(Node node) async {
    var senders = <Identifier, Node>{};
    if (node.isGroup) {
      final _cached = palettes(node.id);
      var toFetch = (node.group ?? [])
          .toSet()
          .difference(_cached.asIds().toSet())
          .toList();

      if (toFetch.isNotEmpty) {
        var fetchedNodes = await getNodesFromEverywhere(toFetch);
        for (var fetchedNode in fetchedNodes) {
          writePalette(fetchedNode, at: node.id);
        }
      }

      for (var node in palettes(node.id).asNodes()) {
        senders[node.id] = node;
      }
    } else {
      senders[widget.self.id] = widget.self;
      senders[node.id] = node;
    }
    page = ChatPage(
      nodeToPalette: nodeToPalette,
      senders: senders,
      send: chatRequest,
      self: widget.self,
      group: palettes(node.id),
      node: node,
      cameras: widget.cameras,
      pageIndex: curLoc.pageIndex,
      onPageChange: (idx) {
        curLoc.pageIndex = idx;
        chatPage(node);
      },
      back: back,
    );
    setState(() {});
  }

  Future<void> snipView(Node node) async {
    final mediaSize = MediaQuery.of(context).size; // full screen
    if (node.snips!.isEmpty) {
      writePalette(node);
      homePage();
    } else {
      final snip = node.snips!.first;
      node.snips!.remove(snip); // consume it
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
        homePage();
      }
      final scale =
          1 / (media!.metadata.aspectRatio ?? 1.0 * mediaSize.aspectRatio);
      if (media.metadata.isVideo) {
        var f = b.writeMediaToFile(media);
        var ctrl = VideoPlayerController.file(f);
        await ctrl.initialize();
        await ctrl.setLooping(true);
        await ctrl.play();
        page = Stack(children: [
          SizedBox(
            height: mediaSize.height,
            width: mediaSize.width,
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
                    width: mediaSize.width,
                    decoration: const BoxDecoration(
                      // border: Border.symmetric(
                      //   horizontal: BorderSide(color: Colors.black38),
                      // ),
                      color: Colors.black38,
                      // color: PinkTheme.snipRibbon,
                    ),
                    constraints: BoxConstraints(
                      minHeight: 16,
                      maxHeight: mediaSize.height,
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
        page = Stack(children: [
          SizedBox(
            height: mediaSize.height,
            width: mediaSize.width,
            child: Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
              child: Image.memory(
                media.data,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          media.metadata.text != "" && media.metadata.text != null
              ? Center(
                  child: Container(
                    width: mediaSize.width,
                    decoration: const BoxDecoration(
                      // border: Border.symmetric(
                      //   horizontal: BorderSide(color: Colors.black38),
                      // ),
                      color: Colors.black38,
                      // color: PinkTheme.snipRibbon,
                    ),
                    constraints: BoxConstraints(
                      minHeight: 16,
                      maxHeight: mediaSize.height,
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
                    onPress: () {
                      writePalette(node);
                      homePage();
                    }),
                ConsoleButton(name: "Next", onPress: () => snipView(node)),
              ]))
        ]);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return page ?? const LoadingPage();
  }
}

