import 'dart:async';
import 'dart:math';

import 'package:cbl/cbl.dart';
import 'package:down4/src/data_objects/firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../_dart_utils.dart';
import '../data_objects/couch.dart';

import '../globals.dart';
import '../themes.dart';
import 'nodes.dart';

String XORedStrings(List<String> strings) {
  if (strings.isEmpty) return "";
  final nStrings = strings.length;
  final singleLen = strings.first.length;
  if (!(strings.every((element) => element.length == singleLen))) {
    throw "XORedStrings: all strings must be of same length";
  }
  List<int> hash = List<int>.generate(singleLen, (_) => 0);
  for (int i = 0; i < singleLen; i++) {
    for (int j = 0; j < nStrings; j++) {
      hash[i] = hash[i] ^ strings[j].codeUnitAt(i);
    }
  }
  return String.fromCharCodes(hash);

}

class Down4ID {
  late final String unique;
  Down4ID({String? unique}) : unique = unique ?? pushKey();
  String get value => unique;

  static Down4ID? fromString(String? s) {
    if (s == null) return null;
    final splits = s.split("~");
    if (splits.length > 1) {
      return ComposedID.fromString(s);
    } else {
      return Down4ID(unique: s);
    }
  }

  @override
  bool operator ==(Object other) => other is Down4ID && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class ComposedID extends Down4ID {
  late final Region region;
  late final int shard;
  ComposedID({String? unique, Region? region, int? shard})
      : super(unique: unique) {
    this.region = region ?? g.self.id.region;
    this.shard = calculateShard(super.unique);
  }

  Down4ServerShard get server => Down4Server.instance.shards[region]![shard];

  DatabaseReference get userRef => server.realtimeDB.ref('users/$value');

  Reference get tempStoreRef => server.temporaryStore.ref(value);

  Reference get staticStoreRef => server.staticStore.ref(value);

  @override
  String get value => "$unique~${region.name}~${shard.toString()}";

  static ComposedID? fromString(String? s) {
    if (s == null) return null;
    final elements = s.split("~");
    return ComposedID(
        unique: elements[0],
        region: Region.values.byName(elements[1]),
        shard: int.parse(elements[2]));
  }
}

extension Down4NodeIterables on Iterable<Down4Node> {
  Iterable<Down4ID> get mediaIDs => map((e) => e.mediaID).whereType();
}

extension MessageTargets on Iterable<MessageTarget> {
  Iterable<String> get allTokens => map((e) => e.token);
  Iterable<String> get exceptMyTokens =>
      where((e) => e.userID != g.self.id).map((e) => e.token);
  Iterable<String> get exceptMyCurrentDeviceToken =>
      where((e) => e.userID == g.self.id).map((e) => e.token);

  Iterable<MessageTarget> get exceptSelf => where((e) => e.userID != g.self.id);

  Iterable<MessageTarget> get selfTargets =>
      where((e) => e.userID == g.self.id);

  Map<String, bool> get successTree {
    final map = <String, bool>{};
    forEach((element) {
      map[element.messageSuccessKey] = element.success;
    });
    return map;
  }
}

extension IterableDown4IDs on Iterable<Down4ID> {
  String get values => map((e) => e.value).toList().join(" ");
}

extension ToDown4IDs on String? {
  Set<ComposedID>? toComposedIDs() => this
      ?.split(" ")
      .where((s) => s != "")
      .map((e) => ComposedID.fromString(e)!)
      .toSet();

  Set<Down4ID>? toDown4IDs() => this
      ?.split(" ")
      .where((s) => s != "")
      .map((e) => Down4ID.fromString(e)!)
      .toSet();
}

abstract mixin class Down4Object {
  Down4ID get id;

  @override
  bool operator ==(Object other) =>
      other is Down4Object && other.id.value == id.value;

  @override
  int get hashCode => id.hashCode;
}

abstract mixin class Jsons {
  Map<String, Object> toJson();
}

abstract mixin class Locals implements Down4Object, Jsons {
  Database get dbb;

  void cache({bool ifAbsent = false}) => gCache(this, ifAbsent: ifAbsent);
  // Future<void> reload<T extends Locals>() async {
  //   local<T>(id).then((value) => value?.cache());
  // }

  Future<void> delete() async {
    print("Deleting $runtimeType from dbb: ${dbb.name}");
    unCache(id);
    await dbb.purgeDocumentById(id.value);
    // final ref = this;
    // if (ref is Down4MediaMetadata && ref.isVideo) {
    //   final f = ref.file;
    //   f?.delete();
    // }
  }

  @override
  Map<String, Object> toJson({bool includeLocal = false});

  Future<void> merge([Map<String, Object>? values]) async {
    print("DBB NAME=${dbb.name}");
    // first, we get the current doc in the db
    var document = (await dbb.document(id.value))?.toMutable();
    bool wasLocal = (document != null);
    // if it wasn't local, we create it
    if (!wasLocal) document = MutableDocument.withId(id.value);

    Map<String, Object> toMerge;
    if (!wasLocal) {
      // then we need to merge the whole thing with the parameter values
      toMerge = {...toJson(includeLocal: true), ...?values};
    } else {
      // we merge given values, or the values from the probably freshly
      // fetched object without the local values to not overwrite them
      toMerge = values ?? toJson();
    }

    toMerge.forEach((key, value) {
      document!.setValue(value, key: key);
    });

    await dbb.saveDocument(document);
  }
}

enum Region { america, europe, asia }

abstract class Temps extends Locals {
  int? _tempTS;
  ComposedID? _tempID;

  int? get tempTS => _tempTS;
  ComposedID? get tempID => _tempID;

  Temps({
    int? tempTS,
    ComposedID? tempID,
  })  : _tempTS = tempTS,
        _tempID = tempID;

  Future<Map<String, Object>?> temporaryUpload(Map<String, Object> msg);

  Future<void> updateTempReferences(
    ComposedID newTempID,
    int newTempTS,
  ) async {
    // we only update the references if it's in the same region
    // else that would create unnecessary latency
    if (newTempTS < (tempTS ?? 0) || newTempID.region != g.self.id.region) {
      return;
    }

    _tempID = newTempID;
    _tempTS = newTempTS;
    await merge({
      "tempTS": newTempTS,
      "tempID": newTempID.value,
    });
  }
}

class FireTheme extends Locals {
  String _themeName;
  FireTheme(String themeName) : _themeName = themeName;

  String get themeName => _themeName;

  @override
  Database get dbb => personalDB;

  @override
  Down4ID get id => Down4ID(unique: "theme");

  Future<void> changeTheme(String newThemeName) async {
    if (themesRegistry[newThemeName] == null) return;
    _themeName = newThemeName;
    await merge();
  }

  static Future<FireTheme> get currentTheme async {
    final doc = await personalDB.document("theme");
    if (doc != null) return FireTheme(doc.string("themeName")!);
    return FireTheme(themesRegistry.keys.first)..merge();
  }

  @override
  Map<String, Object> toJson({bool includeLocal = true}) => {
        "themeName": _themeName,
      };
}

abstract mixin class Geo {
  double? get latitude;
  double? get longitude;

  bool get validLoc => latitude != null && longitude != null;

  static Region? closestRegion(GeoLoc? loc) {
    if (!(loc?.validLoc ?? false)) return null;
    final dists = regionsMap.values.map((e) => sDistance(loc!, e)!).toList();
    final minDist = dists.fold(double.infinity, min);
    final indexOfMin = dists.indexOf(minDist);
    return regionsMap.keys.elementAt(indexOfMin);
  }

  static double? sDistance(Geo loc1, Geo loc2) {
    if (!(loc1.validLoc && loc2.validLoc)) return null;
    return calcDistance(
        loc2.latitude!, loc1.latitude!, loc2.longitude!, loc1.longitude!);
  }

  double? distance(Geo geo) {
    return sDistance(geo, this);
  }
}

class GeoLoc extends Geo {
  @override
  final double latitude, longitude;
  GeoLoc(this.latitude, this.longitude);
}

final Map<Region, GeoLoc> regionsMap = {
  Region.america: GeoLoc(41.259273, -95.845858),
  Region.europe: GeoLoc(50.447294, 3.820384),
  Region.asia: GeoLoc(1.354700, 103.718600),
};

class ExchangeRate extends Locals {
  @override
  Database get dbb => personalDB;

  @override
  Down4ID get id => Down4ID(unique: "exchangeRate");

  int lastUpdate;
  double rate;

  ExchangeRate({required this.lastUpdate, required this.rate});

  static Future<ExchangeRate> get exchangeRate async {
    final doc = await personalDB.document("exchangeRate");
    if (doc == null) return ExchangeRate(lastUpdate: 0, rate: 0)..merge();
    return ExchangeRate.fromJson(Map<String, String?>.from(doc.toPlainMap()));
  }

  factory ExchangeRate.fromJson(dynamic decodedJson) {
    final lastUpdate = decodedJson["lastUpdate"] ?? 0;
    final rate = decodedJson["rate"] ?? 0.0;
    return ExchangeRate(lastUpdate: lastUpdate, rate: rate);
  }

  @override
  Map<String, Object> toJson({bool includeLocal = true}) => {
        "rate": rate,
        "lastUpdate": lastUpdate,
      };
}
