import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_testproject/src/bsv/utils.dart';
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
  var _exchangeRate = ExchangeRate(lastUpdate: 0, rate: 0.0);

  List<r.Request> _requests = [];

  Map<Identifier, Map<Identifier, Palette>> _paletteMap = {
    "Home": {},
    "Search": {},
    "Forward": {},
    "Payments": {},
  };

  StreamSubscription? _messageListener;

  List<Location> _locations = [Location(id: "Home")];

  List<Palette> _forwardingPalettes = [];

  var _tec = TextEditingController();

  // ======================================================= INITIALIZATION ============================================================ //

  @override
  void initState() {
    super.initState();
    loadExchangeRate();
    loadLocalHomePalettes();
    loadPayments();
    connectToMessages();
    homePage();
  }

  @override
  void dispose() {
    _messageListener?.cancel();
    super.dispose();
  }

  void loadExchangeRate() async {
    _exchangeRate =
        b.loadExchangeRate() ?? ExchangeRate(lastUpdate: 0, rate: 0);
    updateExchangeRate();
  }

  void loadLocalHomePalettes() {
    final jsonEncodedHomeNodes = b.home.values;
    for (final jsonEncodedHomeNode in jsonEncodedHomeNodes) {
      final node = BaseNode.fromJson(jsonDecode(jsonEncodedHomeNode));
      writePalette(node);
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
              print("writing node to home");
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
    if (_page is MoneyPage) moneyPage();
  }

  void loadPayments() async {
    await widget.wallet.updateAllStatus();
    widget.wallet.settlementRoutine();
    widget.wallet.save();
    for (final payment in widget.wallet.payments) {
      print("Loading payment: ${payment.id}");
      writePalette(Payment(payment: payment), at: "Payments");
    }
    if (_page is MoneyPage) moneyPage();
  }

  // ======================================================= UTILS ============================================================ //

  Future<void> updateExchangeRate() async {
    final lastUpdate = _exchangeRate.lastUpdate;
    final rightNow = u.timeStamp();
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
      for (final p in palettes(at)) {
        if (p.selected) {
          p.node.updateActivity();
          selectPalette(p.node.id, at);
        }
      }
    } else {
      for (final p in palettes(at)) {
        if (p.selected) {
          selectPalette(p.node.id, at);
        }
      }
    }
  }

  Palette? nodeToPalette(BaseNode node, [String at = "Home"]) {
    if (node is User) {
      String? lastMessagePreview;
      if (node.messages.isNotEmpty) {
        var msg = b.loadMessage(node.messages.last);
        lastMessagePreview = msg?.text ?? "&attachment";
      }
      return Palette(
        node: node,
        at: at,
        messagePreview: lastMessagePreview,
        imPress: select,
        bodyPress: select,
        buttonsInfo: [
          ButtonsInfo(
            assetPath: at == "Home" && node.snips.isNotEmpty
                ? "lib/src/assets/rightRedArrow.png"
                : "lib/src/assets/rightBlackArrow.png",
            pressFunc: at == "Home"
                ? node.snips.isNotEmpty
                    ? checkSnips
                    : openChat
                : openNode,
            longPressFunc: openNode,
            rightMost: true,
          )
        ],
      );
    } else if (node is Hyperchat) {
      print("Trying to create a hyperchat!");
      String? lastMessagePreview;
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
            pressFunc: node.snips.isNotEmpty ? checkSnips : openChat,
            assetPath: node.snips.isNotEmpty
                ? "lib/src/assets/rightRedArrow.png"
                : "lib/src/assets/rightBlackArrow.png",
          )
        ],
      );
    } else if (node is Group) {
      print("are we getting some nodes to group or something?");
      String? lastMessagePreview;
      if (node.messages.isNotEmpty) {
        var msg = b.loadMessage(node.messages.last);
        lastMessagePreview = msg?.text ?? "&attachment";
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
            pressFunc: node.snips.isNotEmpty ? checkSnips : openChat,
            assetPath: node.snips.isNotEmpty
                ? "lib/src/assets/rightRedArrow.png"
                : "lib/src/assets/rightBlackArrow.png",
          )
        ],
      );
    } else if (node is Payment) {
      return Palette(
        node: node,
        at: "Payments",
        imPress: select,
        bodyPress: select,
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
    Future<bool> _processWebRequest(r.Request req) async {
      if (req is r.ChatRequest) {
        final targetNode = req.message.root ?? req.targets.first;
        var node = nodeAt(targetNode) as ChatableNode?;
        if (node == null) return false;
        node.messages.add(req.message.id);
        req.message.save();
        req.media?.save();
        if (_page is ChatPage && _locations.last.id == targetNode) {
          chatPage(node);
        }
        return r.chatRequest(req);
      } else if (req is r.GroupRequest) {
        var node = await r.groupRequest(req);
        if (node == null) return false;
        node.messages.add(req.message.id);
        req.message.save();
        req.media?.save();
        writePalette(node);
        chatPage(node);
        return true;
      } else if (req is r.HyperchatRequest) {
        var node = await r.hyperchatRequest(req);
        if (node == null) return false;
        node.messages.add(req.message.id);
        req.message.save();
        req.media?.save();
        writePalette(node);
        homePage();
        return true;
      } else if (req is r.PaymentRequest) {
        parsePayment(req.payment);
        return await r.paymentRequest(req);
      } else if (req is r.PingRequest) {
        final success = r.pingRequest(req);
        _tec.clear();
        return success;
      } else if (req is r.SnipRequest) {
        return r.snipRequest(req);
      }
      return false;
    }

    for (final req in List<r.Request>.from(_requests)) {
      final success = await _processWebRequest(req);
      if (success) _requests.remove(req);
    }
  }

  void handleWebRequest(r.Request req) {
    _requests.add(req);
    processWebRequests();
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
            targets: node.group
              ..removeWhere((userID) => widget.self.id == userID),
            media: media,
          );
          handleWebRequest(sr);
        } else {
          userTargets.add(node.id);
        }
      }

      final sr = r.SnipRequest(
        message: Down4Message(
          type: Messages.snip,
          id: messagePushId(),
          timestamp: timestamp,
          mediaID: media.id,
          senderID: widget.self.id,
        ),
        targets: selectedHomeUserPaletteDeactivated.asIds().toList(),
        media: media,
      );
      handleWebRequest(sr);
      unselectSelectedPalettes(updateActivity: true);
    }
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

  void delete([String at = "Home"]) {
    for (final p in palettes(at).selected()) {
      b.deleteNode(p.node.id);
      _paletteMap[at]?.remove(p.node.id);
    }
    // TODO for other places than home
    if (_page is HomePage) homePage();
  }

  Future<bool> search(List<String> ids) async {
    final friendIds = palettes_()
        .asNodes()
        .whereType<User>()
        .where((user) => user.isFriend)
        .asIds()
        .toList(growable: false);

    print(friendIds);

    final nodes = await r.getNodes(ids);
    print("ids: $ids\nnodes: ${nodes?.length}");
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
    final p = nodeToPalette(node, "Search");
    if (p != null) {
      _paletteMap["Search"]?.putIfAbsent(node.id, () => p);
      searchPage();
    }
  }

  void back([bool remove = true]) {
    if (remove) _locations.removeLast();
    if (_locations.last.id == "Home") {
      homePage();
    } else if (_locations.last.id == "Search") {
      searchPage();
    } else if (_locations.last.type == "Node") {
      nodePage(nodeAt(_locations.last.id, _locations.last.at!)!);
    } else if (_locations.last.type == "Chat") {
      chatPage(
        nodeAt(_locations.last.id, _locations.last.at!)! as ChatableNode,
      );
    } else if (_locations.last.id == "Money") {
      moneyPage();
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
      chatPage(nodeAt(at, prevLoc.id)! as ChatableNode);
    } else if (_page is NodePage) {
      nodePage(nodeAt(id, at)!);
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
  }) {
    if (_paletteMap[at] == null) _paletteMap[at] = {};
    final p = nodeToPalette(node, at);
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

  // List<Palette> get selectedFriendPalettesDeactivated {
  //   var idsInSelectedGroups = palettes()
  //       .where((p) => p.node is GroupNode && p.selected)
  //       .asIds()
  //       .toSet();
  //
  //   var palettes_ = <Palette>[];
  //   final selectedNonGroups = formattedHomePalettes
  //       .where((p) => p.node is User && p.selected)
  //       .asIds();
  //   for (final pal in selectedNonGroups) {
  //     if (!idsInSelGroups.contains(pal.node.id)) {
  //       palettes_.add(pal.deactivated());
  //     }
  //   }
  //
  //   return palettes_;
  // }

  List<Palette> get selectedHomeUserPaletteDeactivated {
    final selectedGroupIds = formattedHomePalettes
        .selected()
        .asNodes()
        .whereType<GroupNode>()
        .map((groupNode) => groupNode.group)
        .expand((id) => id)
        .toSet()
        .toList(growable: false);

    final selectedUserIds = formattedHomePalettes
        .selected()
        .asNodes()
        .whereType<User>()
        .asIds()
        .toList(growable: false);

    return (selectedGroupIds + selectedUserIds)
        .toSet()
        .map((id) => nodeToPalette(nodeAt(id)!)!.deactivated())
        .toList(growable: false);
  }

  Location get curLoc => _locations.last;

  List<Palette> palettes([String at = "Home"]) {
    return _paletteMap[at]?.values.toList(growable: false) ?? <Palette>[];
  }

  Iterable<Palette> palettes_({at = "Home"}) {
    return _paletteMap[at]?.values ?? const Iterable<Palette>.empty();
  }

  List<Palette> get formattedHomePalettes {
    return palettes()
      ..sort((a, b) => b.node.activity.compareTo(a.node.activity));
  }

  Location get prevLoc {
    if (_locations.length > 1) {
      return _locations[_locations.length - 2];
    }
    throw "Invalid previous location";
  }

  // ============================================================== BUILD ================================================================ //

  void homePage([bool extra = false]) {
    _page = HomePage(
      palettes: formattedHomePalettes,
      console: Console(
        inputs: [
          ConsoleInput(
            tec: _tec,
            placeHolder: ":)",
          ),
        ],
        topButtons: [
          ConsoleButton(name: "Hyperchat", onPress: hyperchatPage),
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
                  targets: selectedHomeUserPaletteDeactivated
                      .asIds()
                      .toList(growable: false),
                  senderID: widget.self.id,
                );
                handleWebRequest(pr);
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

  void forwardPage() {
    if (palettes("Forward").length !=
        formattedHomePalettes.chatables().length) {
      for (final p in formattedHomePalettes.chatables()) {
        writePalette(p.node, at: "Forward");
      }
    }

    _page = ForwardingPage(
      homeUsers: palettes("Forward"),
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
      back: back,
      payment: payment,
    );
    setState(() {});
  }

  void moneyPage() {
    updateExchangeRate();
    _page = MoneyPage(
      self: widget.self,
      wallet: widget.wallet,
      exchangeRate: _exchangeRate.rate,
      palettes: selectedHomeUserPaletteDeactivated,
      paymentAsPalettes: palettes("Payments").reversed.toList(),
      paymentRequest: handleWebRequest,
      parsePayment: parsePayment,
      back: back,
      pageIndex: curLoc.pageIndex,
      onPageChange: (idx) {
        curLoc.pageIndex = idx;
        moneyPage();
      },
    );
    setState(() {});
  }

  void hyperchatPage() {
    _page = HyperchatPage(
      self: widget.self,
      palettes: selectedHomeUserPaletteDeactivated,
      hyperchatRequest: handleWebRequest,
      cameras: widget.cameras,
      back: homePage,
      ping: handleWebRequest,
    );
    setState(() {});
  }

  void groupPage() {
    _page = GroupPage(
      self: widget.self,
      afterMessageCallback: (node) => writePalette(node),
      back: homePage,
      groupRequest: handleWebRequest,
      palettes: selectedHomeUserPaletteDeactivated,
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
      onPageChange: (pageIdx) {
        curLoc.pageIndex = pageIdx;
        nodePage(node);
      },
      cameras: widget.cameras,
      self: widget.self,
      openChat: openChat,
      palette: _paletteMap[_locations.last.at]![node.id]!,
      palettes: _paletteMap[node.id]?.values.toList() ?? <Palette>[],
      openNode: openNode,
      nodeToPalette: nodeToPalette,
      back: back,
    );
    setState(() {});
  }

  void chatPage(ChatableNode node) async {
    var senders = <Identifier, Palette>{};
    if (node is GroupNode) {
      final _cached = palettes(node.id);
      var toFetch = (node as GroupNode)
          .group
          .toSet()
          .difference(_cached.asIds().toSet())
          .toList();

      if (toFetch.isNotEmpty) {
        var fetchedNodes = await getNodesFromEverywhere(toFetch);
        for (var fetchedNode in fetchedNodes) {
          writePalette(fetchedNode, at: node.id);
        }
      }

      for (var palette in palettes(node.id)) {
        senders[palette.node.id] = palette;
      }
    } else {
      senders[widget.self.id] = nodeToPalette(widget.self)!;
      senders[node.id] = nodeToPalette(node)!;
    }
    _page = ChatPage(
      nodeToPalette: nodeToPalette,
      senders: senders,
      send: handleWebRequest,
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

  Future<void> snipView(ChatableNode node) async {
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
        _page = Stack(children: [
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
        _page = Stack(children: [
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
    print(widget.wallet.payments.length);
    return _page ?? const LoadingPage();
  }
}
