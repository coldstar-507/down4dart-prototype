import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cbl/cbl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:down4/src/_dart_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'data_objects/couch.dart';
import 'data_objects/_data_utils.dart';
import 'data_objects/medias.dart';
import 'data_objects/messages.dart';
import 'data_objects/nodes.dart';

import 'package:geolocator/geolocator.dart';

import 'render_objects/_render_utils.dart';
import 'render_objects/chat_message.dart';
import 'render_objects/palette.dart';

import 'themes.dart';
import 'bsv/types.dart';
import 'bsv/wallet.dart';

final g = Singletons.instance;

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<GeoLoc?> requestGeoloc({required bool askPermission}) async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return null;
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied && !askPermission) {
    return null;
  } else {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return null;
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  try {
    final point = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.lowest,
        timeLimit: const Duration(seconds: 2));
    return GeoLoc(point.latitude, point.longitude);
  } catch (_) {
    return null;
  }
}

// Future<List<Down4Node>> nodesFetchWithCachedMedias(
//   Iterable<ID> nodeIDs, {
//   required bool doFetch,
//   required bool doMerge,
// }) async {
//   final nodes = await globall<Down4Node>(nodeIDs,
//       doFetch: doFetch, doMergeIfFetch: doMerge);
//   print(nodes);
//   await globall<FireMedia>(nodes.map((e) => e.mediaID).whereType(),
//       doFetch: doFetch,
//       doMergeIfFetch: doMerge,
//       mediaInfo: (withData: true, onlineID: null));
//   return nodes;
// }
//
// Future<bool> uploadPayment(Down4Payment pay) async {
//   try {
//     await _st.ref(pay.id).putData(pay.compressed.toUint8List());
//     return true;
//   } catch (e) {
//     print("Error uploading payment: $e");
//     return false;
//   }
// }
//
// Future<bool> uploadNodeMedia(FireMedia media) async {
//   try {
//     final mediaData = await media.localImageData;
//     if (mediaData == null) {
//       print("No image data for node image id ${media.id}, returning success");
//       return true;
//     }
//     final mediaMetadata = media.toJson(toLocal: false);
//     await _st_node
//         .ref(media.id)
//         .putData(mediaData, SettableMetadata(customMetadata: mediaMetadata));
//     return true;
//   } catch (e) {
//     print("ERROR uploading node media id: ${media.id}");
//     return false;
//   }
// }
//
// Future<bool> uploadNode(Down4Node node) async {
//   final nodeMedia = await global<FireMedia>(node.mediaID);
//   final body = node.toJson(toLocal: false);
//   List<Future<dynamic>> uploads = [];
//   try {
//     if (nodeMedia != null) uploads.add(uploadNodeMedia(nodeMedia));
//     uploads.add(_fs.collection("Nodes").doc(node.id).set(body));
//     await Future.wait(uploads);
//     print("Success uploading node: ${node.id} ${node.displayName}");
//     return true;
//   } catch (e) {
//     print("Failure uploading node: $e");
//     return false;
//   }
// }

// Future<Down4Payment?> downloadPayment(ID paymentID) async {
//   final payRef = _st.ref(paymentID);
//   try {
//     final compressed = await payRef.getData();
//     if (compressed == null) {
//       print("Error, no data at payment id: $paymentID");
//       return null;
//     }
//     print("Success downloading payment id: $paymentID");
//     return Down4Payment.fromCompressed(compressed);
//   } catch (e) {
//     print("Error downloading payment id: $paymentID, err: $e");
//     return null;
//   }
// }

Future<String?> getDeviceID() async {
  var deviceInfo = DeviceInfoPlugin();
  if (Platform.isIOS) {
    var iosDeviceInfo = await deviceInfo.iosInfo;
    return iosDeviceInfo.identifierForVendor;
  } else if (Platform.isAndroid) {
    var androidDeviceInfo = await deviceInfo.androidInfo;
    return androidDeviceInfo.id;
  } else if (Platform.isFuchsia) {
  } else if (Platform.isIOS) {
  } else if (Platform.isMacOS) {
  } else if (Platform.isWindows) {}
  return null;
}

// Future<bool> uploadMedia(
//   FireMedia media, {
//   bool isNode = false,
//   bool isSnip = false,
// }) async {
//   final bool mediaShouldBeUpdated = !media.onlineTimestamp.shouldBeUpdated;
//   print("""
//           MEDIA SHOULD BE UPDATED = $mediaShouldBeUpdated
//           MEDIA IS NODE = $isNode
//           NO NEED TO UPDATE MEDIA = ${!mediaShouldBeUpdated && !isNode}
//         """);
//   // if the media doesn't need update and is a message media, we are good
//   if (!media.onlineTimestamp.shouldBeUpdated && !isNode) return true;
//   print("UPLOADING mediaID: ${media.id}");
//   // if it's a message media and needs an update, we update it
//   ID? newID;
//   int? newTs;
//   if (!isNode) {
//     // we refresh onlineID and onlineTimestamp
//     newID = messagePushId();
//     newTs = makeTimestamp();
//   }
//   final ref = isNode ? _st_node.ref(media.id) : _st.ref(newID);
//   File? cachedFile, videoFile;
//   Uint8List? imageData;
//   try {
//     final jsonMetadata = media.toJson(toLocal: false);
//     final metadata = SettableMetadata(customMetadata: jsonMetadata);
//     if ((cachedFile = await media.cachedFile) != null) {
//       await ref.putFile(cachedFile!, metadata);
//     } else {
//       if (media.isVideo) {
//         videoFile = media.videoFile;
//         if (videoFile == null) {
//           print("ERROR UPLOADING MEDIA: Can't find video file!");
//           return false;
//         }
//         await ref.putFile(videoFile, metadata);
//       } else {
//         imageData = await media.imageData;
//         if (imageData == null) {
//           print("ERROR UPLOADING MEDIA: Can't find image data!");
//           return false;
//         }
//         await ref.putData(imageData, metadata);
//       }
//     }
//     print("SUCCESS UPLOADING MEDIA");
//     if (newID != null) await media.updateOnlineReference(newID, newTs!);
//     return true;
//   } catch (e) {
//     print("ERROR UPLOADING MEDIA: $e");
//     return false;
//   }
// }

// Future<bool> uploadReaction(ChatReaction reaction) async {
//   final msgRef = db.child("Messages").child(reaction.id);
//   try {
//     List<Future<dynamic>> uploads = [];
//
//     final media = await global<FireMedia>(reaction.mediaID);
//     // final msgCopy = msg.copy();
//     print("MEDIA ONLINE TIMESTAMP = ${media?.onlineTimestamp}");
//     int? freshTS;
//     ID? freshOnlineID;
//     if (media?.onlineTimestamp.shouldBeUpdated ?? false) {
//       print("(RE)-uploading media!");
//       freshOnlineID = messagePushId();
//       freshTS = makeTimestamp();
//
//       final jsonMedia = media!.toJson(toLocal: false);
//       jsonMedia["onlineID"] = freshOnlineID;
//       jsonMedia["onlineTimestamp"] = freshTS.toString();
//
//       final ref = _st.ref(freshOnlineID);
//       final setMetadata = SettableMetadata(customMetadata: jsonMedia);
//
//       if (media.cachePath != null) {
//         uploads.add(ref.putFile(File(media.cachePath!), setMetadata));
//       } else if (media.isVideo && media.videoFile != null) {
//         uploads.add(ref.putFile(media.videoFile!, setMetadata));
//       } else if ((await media.imageData) != null) {
//         uploads.add(ref.putData((await media.imageData)!, setMetadata));
//       } else {
//         print("NO MEDIA TO UPLOAD BRO");
//       }
//     } else {
//       print("NO NEED TO UPDATE MEDIA");
//     }
//
//
//   }
// }

// Future<bool> uploadMessage(Sendable msg) async {
//   final msgRef = db.child("Messages").child(msg.id);
//   try {
//     List<Future<dynamic>> uploads = [];
//
//     final media = await global<FireMedia>(msg.mediaID);
//     // final msgCopy = msg.copy();
//     print("MEDIA ONLINE TIMESTAMP = ${media?.onlineTimestamp}");
//     int? freshTS;
//     ID? freshOnlineID;
//
//     final uploadMedia = media != null &&
//         (media.onlineID == null || media.onlineTimestamp.shouldBeUpdated);
//
//     if (uploadMedia) {
//       print("(RE)-uploading media!");
//       freshOnlineID = messagePushId();
//       freshTS = makeTimestamp();
//
//       final jsonMedia = media.toJson(toLocal: false);
//       jsonMedia["onlineID"] = freshOnlineID;
//       jsonMedia["onlineTimestamp"] = freshTS.toString();
//
//       final ref = _st.ref(freshOnlineID);
//       final setMetadata = SettableMetadata(customMetadata: jsonMedia);
//
//       if (media.cachedFile != null) {
//         uploads.add(ref.putFile(media.cachedFile!, setMetadata));
//       } else if (media.isVideo && media.videoFile != null) {
//         uploads.add(ref.putFile(media.videoFile!, setMetadata));
//       } else if ((await media.localImageData) != null) {
//         uploads.add(ref.putData((await media.localImageData)!, setMetadata));
//       } else {
//         print("NO MEDIA TO UPLOAD BRO");
//       }
//     } else {
//       print("NO NEED TO UPDATE MEDIA");
//     }
//
//     final msgJson = msg.toJson(toLocal: false);
//     if (media != null) {
//       msgJson["onlineMediaID"] = freshOnlineID ?? media.onlineID!;
//       msgJson["onlineMediaTimestamp"] =
//           freshTS?.toString() ?? media.onlineTimestamp.toString();
//     }
//
//     // add the messageUpload
//     uploads.add(msgRef.set(msgJson));
//     // await the uploads, a failure will throw
//     await Future.wait(uploads);
//
//     if (media != null && freshTS != null && freshOnlineID != null) {
//       await media.updateOnlineReference(freshOnlineID, freshTS);
//     }
//
//     print("Success uploading message id: ${msg.id}");
//     return true;
//   } catch (e) {
//     print("Error uploading message id: ${msg.id}, error: $e");
//     return false;
//   }
// }
//
// Future<MessageBatchResponse?> sendTheMessage({
//   required Sendable msg,
//   required List<ID> tokens,
//   required String header,
//   required String body,
// }) async {
//   FireMedia? media;
//   int? freshTS;
//   ID? freshOnlineID;
//   try {
//     if (msg is Mediable) {
//       media = await global<FireMedia>(msg.mediaID);
//       print("MEDIA ONLINE TIMESTAMP = ${media?.onlineTimestamp}");
//
//       final uploadMedia = media != null &&
//           (media.onlineID == null || media.onlineTimestamp.shouldBeUpdated);
//
//       if (uploadMedia) {
//         print("(RE)-uploading media!");
//         freshOnlineID = messagePushId();
//         freshTS = makeTimestamp();
//
//         final jsonMedia = media.toJson(toLocal: false);
//         jsonMedia["onlineID"] = freshOnlineID;
//         jsonMedia["onlineTimestamp"] = freshTS.toString();
//
//         final ref = _st.ref(freshOnlineID);
//         final setMetadata = SettableMetadata(customMetadata: jsonMedia);
//
//         if (media.cachedFile != null) {
//           await ref.putFile(media.cachedFile!, setMetadata);
//         } else if (media.isVideo && media.videoFile != null) {
//           await ref.putFile(media.videoFile!, setMetadata);
//         } else if ((await media.localImageData) != null) {
//           await ref.putData((await media.localImageData)!, setMetadata);
//         } else {
//           print("PROBLEM: NO MEDIA TO UPLOAD BRO");
//         }
//       } else {
//         print("OK: NO NEED TO UPDATE MEDIA");
//       }
//     }
//
//     final msgJson = msg.toJson(toLocal: false);
//     if (media != null) {
//       msgJson["onlineMediaID"] = freshOnlineID ?? media.onlineID!;
//       msgJson["onlineMediaTimestamp"] =
//           freshTS?.toString() ?? media.onlineTimestamp.toString();
//     }
//
//     if (media != null && freshTS != null && freshOnlineID != null) {
//       await media.updateOnlineReference(freshOnlineID, freshTS);
//     }
//
//     return MessageRequest(
//       sender: msg.senderID,
//       tokens: tokens,
//       header: header,
//       body: body,
//       data: jsonEncode(msgJson),
//     ).process();
//   } catch (e) {
//     print("ERROR uploadMessageMedia,  message id: ${msg.id}, error: $e");
//     return null;
//   }
// }

class ViewManager {
  // view IDs code
  // Homepage      -> 'home'
  // GroupPage     -> 'group'
  // HyperchatPage -> 'hyper'
  // SearchPage    -> 'search'
  // SnipPage      -> 'snip'
  // ChatPage      -> 'c-{nodeID}'
  // NodePage      -> 'n-{nodeID}'
  // ForwardPage   -> 'forward'
  // MoneyPage     -> 'money'
  // LoadingPage   -> 'loading'
  List<String> route;
  Map<String, ViewState?> views;

  ViewManager()
      : route = [],
        views = {};

  ViewState at(String viewID) => views[viewID]!;

  ViewState get home => views[route.first]!;
  ViewState get currentView => views[route.last]!;

  void push(ViewState view) {
    route.add(view.id);
    views[view.id] ??= view;
  }

  // returns the view we are popping
  // because of possible cycles, we don't actually remove a view
  // from the views if it's still in the route. The boolean
  // stands for "view was removed from views"
  (ViewState, bool) pop() {
    final popped = route.removeLast();
    if (!route.contains(popped)) {
      return (views.remove(popped)!, true);
//      return views.remove(popped)!;
    }
    return (views[popped]!, false);
  }

  void popUntilHome() {
    for (final viewID in route.sublist(1)) {
      views.remove(viewID);
    }
    route = [route[0]];
  }

  // can be useful after forwarding, creating a group, hyperchat, etc
  void popInBetween() {
    final newRoute = [route.first, route.last];
    for (final viewID in route.sublist(1, route.length - 1)) {
      if (viewID != newRoute.last) views.remove(viewID);
    }
    route = newRoute;
  }
}

class PageState {
  // a page has a scroll state
  double scroll;
  // a page has a state of objects
  Map<Down4ID, Down4Object> objects;
  PageState({double? scroll, Map<Down4ID, Down4Object>? objects})
      : scroll = scroll ?? 0.0,
        objects = objects ?? {};
}

class ViewState {
  // A view can have a single chat
  // A chat is a List<ID> of every messages and a stream subscription that
  // listens to changes
  Pair<List<Down4ID>, StreamSubscription<QueryChange<ResultSet>>>? chat;
  // A view can be from a single node (chatPage, nodePage) both require a node
  final Down4Node? node;
  // Every view has an ID
  final String id;
  // A view has a least 1 page, limited to 3
  final List<PageState> pages;
  // A view has a current index of the page
  int currentIndex;
  // A view can have maps of special references, ex: messagesWithVideos
  Map<String, Set<Down4ID>> notableReferences;

  List<Down4Object> _forwardingObjects;

  List<Down4Object> get fo => _forwardingObjects;

  Set<Down4ID> refs(String name) =>
      notableReferences[name] ??= Set<Down4ID>.identity();

  ViewState({
    required this.id,
    required this.pages,
    List<Down4Object>? fo,
    int? ix,
    this.node,
    this.chat,
  })  : _forwardingObjects = fo ?? [],
        currentIndex = ix ?? 0,
        notableReferences = {};

  PageState get currentPage => pages[currentIndex];
}

class Sizes {
  Sizes({
    required this.h,
    required this.w,
    required this.fullHeight,
    required this.headerHeight,
  });
  double h;
  double w;
  double fullHeight;
  double headerHeight;
  Size get fullSize => Size(w, fullHeight);
  Size get paddedSize => Size(w, h);
  double get viewPaddingHeight => fullHeight - h;
  double get fullAspectRatio => w / fullHeight;
  double get paddedAspectRatio => w / h;
}

class Singletons {
  static final Singletons _instance = Singletons();
  static Singletons get instance => _instance;

  late FireTheme myTheme;

  Down4Theme get theme => themesRegistry[myTheme.themeName]!;
  late String appDirPath;
  late Self self;
  late Wallet wallet;
  late Sizes sizes;
  late ExchangeRate exchangeRate;
  List<Down4ID> savedImageIDs = [];
  List<Down4ID> savedVideoIDs = [];
  late Image fifty, black, red, ph, d1, d2, d3, lg;
  late Uint8List background;
  late List<CameraDescription> cameras;

  Future<bool> get notYetInitialized async {
    final self_ = await Self.loadSelf();
    if (self_ != null) {
      self = self_;
      return false;
    } else {
      return true;
    }
  }

  // List<TextInputConnection> connections = [];
  // TextInputConnection get multiLine => connections[0];
  // TextInputConnection get singleLine => connections[1];
  // TextInputConnection get numberPad => connections[2];

  void loadExchangeRate(ExchangeRate er) => exchangeRate = er;

  void loadTheme(FireTheme theme) => myTheme = theme;

  void loadSizes(Sizes s) => sizes = s;

  Future<void> loadAppDirPath() async {
    appDirPath = (await getApplicationDocumentsDirectory()).path;
  }

  Future<void> loadWallet() async {
    final wallet_ = await WalletManager.load();
    if (wallet_ == null) return print("Wallet is null");
    wallet = wallet_;
  }

  Future<void> initWallet(Uint8List s1, Uint8List s2) async {
    final keys = Down4Keys.fromRandom(s1, s2);
    wallet = Wallet(keys: keys, ix: null);
    await wallet.merge();
  }

  void initSelf(Self s) {
    self = s;
  }

  Icon get snipArrow =>
      Icon(Icons.arrow_forward_ios_rounded, color: theme.snipArrowColor);

  Icon get noMessageArrow =>
      Icon(Icons.arrow_forward_ios_rounded, color: theme.noMessageArrowColor);

  Icon get messageArrow =>
      Icon(Icons.arrow_forward_ios_rounded, color: theme.messageArrowColor);
}

void unselectedSelectedPalettes(Map<Down4ID, Palette2> state) {
  for (final p in state.values) {
    if (p.selected) state[p.id] = p.select();
  }
}

// typedef BGEN<T extends Down4Node> = Future<List<ButtonsInfo2>> Function(
//   T n, {
//   (Chat?, Iterable<Down4ID>, bool)? chatInfo,
// })?;

FutureOr<void> writePalette<T extends PaletteN>(
  T c,
  Map<Down4ID, Palette2> state,
  FutureOr<List<ButtonsInfo2>> Function(T n)? bGen,
  void Function()? onSel, {
  bool? sel,
}) async {
  // isSelected will check first if it's an argument, else it will check
  // if the palette is a reload and use it's current status, or else it will
  // default to false
  final Palette2? pInState = state[c.id];
  final bool? selectionIfReload = pInState?.selected;
  final bool isSelected = sel ?? selectionIfReload ?? false;

  final node = c;

  final lastChat = node is ChatN ? await node.lastChatMessage() : null;

  final hide = node is User && !node.isConnected && !await node.hasMessages();

  void Function()? onSelect = onSel == null || hide
      ? null
      : () async {
          await writePalette(c, state, bGen, onSel, sel: !isSelected);
          onSel.call();
        };

  state[c.id] = Palette2(
      key: Key(c.id.unique),
      node: c,
      selected: isSelected,
      messagePreview: lastChat?.messagePreview,
      imPress: onSelect,
      show: !hide,
      bodyPress: onSelect,
      buttonsInfo2: hide ? [] : await bGen?.call(c) ?? []);
  //, chatInfo: chatInfo) ?? []);
}

// void writePalette3<T extends Down4Node>(
//   T n,
//   Map<Down4ID, Palette2> state,
//   Future<List<ButtonsInfo2>> Function(T n)? bGen,
//   void Function()? onSel, {
//   bool? sel,
//   String? pr,
// }) async {
//   // isSelected will check first if it's an argument, else it will check
//   // if the palette is a reload and use it's current status, or else it will
//   // default to false
//   bool? selectionIfReload;
//   final Palette2? pInState = state[n.id];
//   selectionIfReload = pInState?.selected;
//   bool isSelected = sel ?? selectionIfReload ?? false;
//
//   void Function()? onSelect = onSel == null
//       ? null
//       : () {
//           writePalette3(n, state, bGen, onSel, sel: !isSelected, pr: pr);
//           onSel.call();
//         };
//
//   state[n.id] = Palette2(
//       key: Key(n.id.unique),
//       node: n,
//       selected: isSelected,
//       imPress: onSelect,
//       bodyPress: onSelect,
//       messagePreview: pr,
//       buttonsInfo2: await bGen?.call(n) ?? []);
// }

class Transition {
  final Iterable<PersonN> trueTargets;
  final List<Palette2> preTransition, postTransition;
  final Map<Down4ID, Palette2> state;
  final int nHidden;
  final double scroll;

  const Transition({
    required this.trueTargets,
    required this.preTransition,
    required this.postTransition,
    required this.state,
    required this.nHidden,
    required this.scroll,
  });
}

Transition selectionTransition({
  required List<Palette2> originalList,
  required Map<Down4ID, Palette2> state,
  required double scrollOffset,
}) {
  final hidden = state.values.hidden();

  final ogOrder = originalList.asIDs();
  final selected = originalList.selected();
  final unselected = originalList.notSelected();

  final selectedPeople = selected.whereNodeIs<PersonN>();

  final selectedGroups = selected.whereNodeIs<GroupN>();

  final idsInGroups = selectedGroups
      .asNodes<GroupN>()
      .map((g) => g.group)
      .expand((id) => id)
      .toSet();

  final unselectedGroups = unselected.whereNodeIs<GroupN>();
  final unselectedUsers = unselected.whereNodeIs<PersonN>();
  final unHide = hidden.those(idsInGroups);
  final unselectedUsersNotInGroups = unselectedUsers.notThose(idsInGroups);
  final unselectedUserInGroups = unselectedUsers.those(idsInGroups);

  // groups are folded
  // unHide should get a left to right show transition
  // not selected should get a fold transition
  // selected are unselected
  // all are deactivated

  print("unhidding ${unHide.map((e) => e.node.displayName)}");

  final pals = <Palette2>{
    ...unHide.map((e) => e.showing(true)),
    ...selectedPeople.map(
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

  print("pals=${pals.map((e) => e.node.displayName).toList()}");
  return Transition(
      trueTargets: pals.where((p) => !p.fold && p.show).asNodes<PersonN>(),
      preTransition: originalList,
      postTransition: pals.inThatOrder(ogOrder.followedBy(unHide.asIDs())),
      state: state,
      nHidden: unHide.length,
      scroll: scrollOffset);
}

// Transition typeTransition<T extends FireNode>({
//   required Map<ID, Palette2> state,
//   required Map<ID, Palette2> hiddenState,
//   required double scrollOffset,
// }) {
//   final all = state.values;
//   final ogOrder = all.asIds();
//   final hidden = hiddenState.values;
//   final properType = all.whereNodeIs<T>();
//   final unProperType = all.whereNodeIsNot<T>();
//   final properTypeHidden = hidden.whereNodeIs<T>();
//   final pals = <Palette2>{
//     ...properType,
//     ...unProperType
//         .map((e) => e.animated(fold: true, fadeButton: true, fade: true)),
//     ...properTypeHidden,
//   };
//
//   print("pals=${pals.map((e) => e.node.displayName).toList()}");
//   return Transition<T>(
//       trueTargets: properType.followedBy(properTypeHidden),
//       preTransition: all.toList(),
//       postTransition:
//           pals.inThatOrder(ogOrder.followedBy(properTypeHidden.asIds())),
//       state: state,
//       nHidden: properTypeHidden.length,
//       scroll: scrollOffset);
// }

Future<ChatMessage?> getChatMessage({
  required Map<Down4ID, ChatMessage> state,
  required ChatN ch,
  required Down4ID msgID,
  required Down4ID? prevMsgID,
  required Down4ID? nextMsgID,
  required bool isFirst,
  required void Function(Down4Node)? openNode,
  required void Function() refreshCallback,
  required Future<void> Function(Chat message) react,
  required Future<void> Function(Chat, Down4ID) increment,
}) async {
  final msg = await global<Chat>(msgID);
  if (msg == null) return null;
  Chat? prevMsg, nextMsg;
  ChatMessage? prevChatMessage = state[prevMsgID];
  // If new message while in chat, we might want to remove the header of the
  // previous last message
  if (isFirst &&
      prevMsgID != null &&
      prevChatMessage != null &&
      prevChatMessage.hasHeader &&
      msg.senderID == prevChatMessage.message.senderID &&
      msg.senderID != g.self.id) {
    // we need to remove its header
    state[prevMsgID] = prevChatMessage.withHeader(hasHeader: false);
    // and update it's size
  }

  if (state[msgID] != null) return state[msgID]!;

  prevMsg = await global<Chat>(prevMsgID);
  nextMsg = await global<Chat>(nextMsgID);

  bool hasGap = false;
  if (prevMsg != null) hasGap = ChatMessage.displayGap(msg, prevMsg);

  // mark as read
  msg.markRead();

  final bool senderIsSelf = msg.senderID == g.self.id;
  final bool hasHeader =
      !senderIsSelf && ch is GroupN && nextMsg?.senderID != msg.senderID;

  final cm = ChatMessage(
      key: GlobalKey(),
      hasGap: hasGap,
      message: msg,
      nodeRef: ch.id,
      react: react,
      increment: increment,
      mediaInfo: await ChatMessage.generateMediaInfo(msg),
      nodes: null,
      repliesInfo: await ChatMessage.generateRepliesInfo(msg, (replyID) {
        print("TODO, GO TO REPLY ID = $replyID");
      }),
      hasHeader: hasHeader,
      openNode: openNode,
      myMessage: g.self.id == msg.senderID,
      select: (_) {
        state[msgID] = state[msgID]!.invertedSelection();
        refreshCallback();
      });

  // Future for fetching the nodes attached to a message
  // It when done, it will callback and refresh the message with
  // the palettes showing properly
  Future.microtask(() async {
    if ((msg.nodes ?? {}).isNotEmpty) {
      final nodes = await globall<Down4Node>(msg.nodes!, doFetch: true);
      if (nodes.isNotEmpty) {
        state[msg.id] = state[msg.id]!.withNodes(nodes);
        refreshCallback();
      }
    }
  });

  return cm;
}

// Future<void> updatedMessageReactions({required Map<ID, ChatMessage> state}) {
//
// }

Future<void> writeMessages({
  required ChatN ch,
  required List<Down4ID> ordered,
  required Map<Down4ID, ChatMessage> state,
  required Set<Down4ID> videos,
  required Set<Down4ID> withNodes,
  required void Function() refresh,
  required void Function(Down4Node)? openNode,
  int limit = 20,
  required Future<void> Function(Chat message) react,
  required Future<void> Function(Chat, Down4ID) increment,
}) async {
  final orderedSet = ordered.toSet();
  final loadedSet = state.keys.toSet();
  final toLoad = orderedSet.difference(loadedSet).toList();
  if (toLoad.isEmpty) return;
  final allN = ordered.length;
  final nLoad = toLoad.length > limit ? limit : toLoad.length;
  final ixOfFirst = orderedSet.toList().indexOf(toLoad.first);
  for (int i = 0; i < nLoad; i++) {
    final ixInFull = ixOfFirst + i;
    final msgID = toLoad[i];
    final nxt = ixInFull == 0 ? null : ordered[ixInFull - 1];
    final prv = ixInFull < allN - 1 ? ordered[ixInFull + 1] : null;
    final isFirst = msgID == orderedSet.first;
    final m = await getChatMessage(
        state: state,
        ch: ch,
        msgID: msgID,
        prevMsgID: prv,
        nextMsgID: nxt,
        isFirst: isFirst,
        openNode: openNode,
        increment: increment,
        react: react,
        refreshCallback: refresh);
    if (m != null) {
      state[m.id] = m;
      if (m.mediaInfo?.media is Down4Video) videos.add(m.id);
      if ((m.message.nodes ?? {}).isNotEmpty) withNodes.add(m.id);
    }
  }
}

Future<void> writePayments(
  Map<Down4ID, Palette2> state,
  void Function(Down4Payment) openPayment, [
  int limit = 5,
]) async {
  final offset = state.length;
  await for (final pay in g.wallet.nPayments(limit: limit, offset: offset)) {
    state[pay.id] = Palette2(
      key: Key(pay.id.unique),
      node: PaymentNode(payment: pay, selfID: g.self.id),
      messagePreview: pay.textNote,
      buttonsInfo2: pay.isSpentBy(id: g.self.id)
          ? [
              ButtonsInfo2(
                  asset: Icon(Icons.arrow_forward_ios_rounded,
                      color: g.theme.noMessageArrowColor),
                  pressFunc: () => openPayment(pay),
                  rightMost: true)
            ]
          : [],
    );
  }
}

// class EmptyObject extends Down4Object {
//   @override
//   ID get id => randomBytes(size: 8).toBase58();
// }

final topButtonsKey = [
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
  GlobalKey(),
];

final bottomButtonsKey = List.generate(1000, (index) => GlobalKey());
