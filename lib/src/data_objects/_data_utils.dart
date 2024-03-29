import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:down4/src/data_objects/firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:sqlite3/sqlite3.dart' as sql;

import '../_dart_utils.dart';
// import '../data_objects/couch.dart';

import '../globals.dart';
import '../themes.dart';

class Down4ID {
  late final String unik;
  Down4ID({String? unik}) : unik = unik ?? pushKey();
  String get value => unik;

  String get sqlReady => value.sqlReady;

  static Down4ID? fromString(String? s) {
    if (s == null) return null;
    final splits = s.split("~");
    if (splits.length > 1) {
      return ComposedID.fromString(s);
    } else {
      return Down4ID(unik: s);
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
  ComposedID({String? unik, Region? region, int? shard}) : super(unik: unik) {
    this.region = region ?? g.self.id.region;
    this.shard = calculateShard(super.unik);
  }

  Down4ServerShard get server => Down4Server().shards[region]![shard];

  DatabaseReference get nodeRef => server.realtimeDB.ref('nodes/$unik/node');

  DatabaseReference get messageRef => server.realtimeDB.ref('messages/$unik');

  Reference get tempStoreRef => server.temporaryStore.ref(value);

  Reference get staticStoreRef => server.staticStore.ref(value);

  @override
  String get value => "$unik~${region.name}~${shard.toString()}";

  static ComposedID? fromString(String? s) {
    if (s == null) return null;
    final elements = s.split("~");
    return ComposedID(
        unik: elements[0],
        region: Region.values.byName(elements[1]),
        shard: int.parse(elements[2]));
  }
}

extension IterableDown4IDs on Iterable<Down4ID> {
  String get values => map((e) => e.value).join(" ");
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

extension Down4Objects<T extends Down4Object> on List<T> {
  Iterable<T> specificOrder(Iterable<Down4ID> ids) sync* {
    final m = asMap().map((k, v) => MapEntry(v.id, v));
    for (final id in ids) {
      final e = m[id];
      if (e != null) {
        yield e;
      } else {
        continue;
        // throw "$this doesn't contain element of id=${id.value}";
      }
    }
  }
}

mixin Down4Object {
  Down4ID get id;

  @override
  bool operator ==(Object other) =>
      other is Down4Object && other.id.value == id.value;

  @override
  int get hashCode => id.hashCode;
}

mixin Jsons {
  Map<String, String> toJson();
}

extension QuoteQuote on String {
  String get sqlReady {
    final sbuf = StringBuffer("'");
    sbuf.write(replaceAll("'", "''"));
    sbuf.write("'");
    return sbuf.toString();
  }
}

extension SQLStatements on Map<String, String> {
  String get sqlUpdateFmtParams {
    // key1 = 'val1', key2 = 'val2'
    final buf = StringBuffer();
    buf.writeAll(entries.map((e) => "${e.key} = ?"), ",");
    return buf.toString();
  }

  String get sqlUpdateFmt {
    // key1 = 'val1', key2 = 'val2'
    final buf = StringBuffer();
    buf.writeAll(entries.map((e) => "${e.key} = ${e.value.sqlReady}"), ",");
    return buf.toString();
  }

  String get sqlInsertValues {
    final buf = StringBuffer("(");
    buf.writeAll(values.map((e) => e.sqlReady), ",");
    buf.write(")");
    return buf.toString();
  }

  String get sqlInsertValuesParams {
    final buf = StringBuffer("(");
    buf.writeAll(values.map((_) => "?"), ",");
    buf.write(")");
    return buf.toString();
  }

  String get sqlInsertKeys {
    final buf = StringBuffer("(");
    buf.writeAll(keys, ",");
    buf.write(")");
    return buf.toString();
  }

  String sqlInsertStr(String table) {
    return """
    INSERT INTO $table
    $sqlInsertKeys
    VALUES $sqlInsertValues;
    """;
  }

  String sqlUpdateStr(String table, String id) {
    return """
    UPDATE $table
    SET $sqlUpdateFmt
    WHERE id = ${id.sqlReady};
    """;
  }
}

mixin Locals on Down4Object, Jsons {
  String get table;

  void cache({bool ifAbsent = false}) =>
      Down4Cache().cache(this, ifAbsent: ifAbsent);

  String? delete({bool stmt = false}) {
    final q = "DELETE FROM $table WHERE id = ${id.value.sqlReady};";
    if (stmt) return q;
    try {
      Down4Local().db.execute(q);
    } catch (e) {
      print("error deleting $runtimeType ${id.value}: $e");
    }
    Down4Cache().unCache(id);
    return null;
  }

  bool existsLocally() {
    final q = "SELECT id FROM $table WHERE id = ${id.sqlReady}";
    return Down4Local().db.select(q).isNotEmpty;
  }

  @override
  Map<String, String> toJson({bool includeLocal = false});

  String? merge({
    Map<String, String>? vals,
    bool stmt = false,
    bool ifNotPresent = false,
  }) {

    print("TABLE NAME=$table");
    final bool isLocal = existsLocally();
    if (isLocal && ifNotPresent) return null;

    Map<String, String> toMerge;
    String qStr;
    if (!isLocal) {
      // then we need to merge the whole thing with the parameter values
      toMerge = {...toJson(includeLocal: true), ...?vals};
      qStr = toMerge.sqlInsertStr(table);
    } else {
      // we merge given values, or the values from the probably freshly
      // fetched object without the local values to not overwrite them
      toMerge = vals ?? toJson(includeLocal: false);
      qStr = toMerge.sqlUpdateStr(table, id.value);
    }

    print("merge statement:\n$qStr");
    if (stmt) return qStr;

    Down4Local().db.execute(qStr);
    return null;
  }
}

enum Region { america, europe, asia }

mixin Temps on Locals {
  
  ComposedID? get tempID;
  int? get tempTS;

  Uint8List? get tempPayload;
  Map<String, String>? get tempPayloadMetadata;

  // return null if error, (null, null) if no upload needed
  Future<({ComposedID? freshID, int? freshTS})?> temporaryUpload() async {
    if (tempPayload == null) return null;
    int? freshTS;
    ComposedID? freshID;
    try {
      final doUpload = tempID == null || tempTS.shouldBeUpdated;
      if (doUpload) {
        print("(RE)-uploading $runtimeType, id: ${id.value}");
        freshID = ComposedID();
        freshTS = makeTimestamp();

        final ref = freshID.tempStoreRef;
        tempPayloadMetadata?["tempID"] = freshID.value;
        tempPayloadMetadata?["tempTS"] = freshTS.toString();

        final cm = SettableMetadata(customMetadata: tempPayloadMetadata);
        await ref.putData(tempPayload!, cm);
      } else {
        print("OK: no need to make temporary upload");
        return (freshID: null, freshTS: null);
      }

      this
        ..updateTempReferences(freshID, freshTS)
        ..cache();

      return (freshID: freshID, freshTS: freshTS);
    } catch (e) {
      print("ERROR uploadMessageMedia,  message id: $id, error: $e");
      return null;
    }
  }

  void updateTempReferences(ComposedID newTempID, int newTempTS);
}

class CurrentTheme with Down4Object, Jsons, Locals {
  String _themeName;
  CurrentTheme(String themeName) : _themeName = themeName;

  String get themeName => _themeName;

  @override
  Down4ID get id => Down4ID(unik: "single");

  @override
  String get table => "personals";

  void changeTheme(String newThemeName) {
    if (themesRegistry[newThemeName] == null) return;
    _themeName = newThemeName;
    merge();
  }

  static Future<CurrentTheme> get currentTheme async {
    const q = "SELECT themeName FROM personals WHERE id = 'single'";
    final r = Down4Local().db.select(q);
    return CurrentTheme(r.single['themeName'] ?? themesRegistry.keys.first)
      ..merge();
  }

  @override
  Map<String, String> toJson({bool includeLocal = true}) => {
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

// TODO: could keep exchanges rates stats to a point locally
// to draw a chart
class ExchangeRate with Down4Object, Jsons, Locals {
  @override
  String get table => "personals";

  int lastUpdate;
  double rate;

  @override
  Down4ID get id => Down4ID(unik: "single");

  ExchangeRate({required this.lastUpdate, required this.rate});

  static ExchangeRate get exchangeRate {
    const q = "SELECT * FROM personals WHERE id = 'single'";
    final r = Down4Local().db.select(q);
    if (r.isEmpty) return ExchangeRate(lastUpdate: 0, rate: 0);
    return ExchangeRate.fromJson(Map<String, String?>.from(r.single));
  }

  factory ExchangeRate.fromJson(Map<String, String?> decodedJson) {
    final lastUpdate = int.parse(decodedJson["lastUpdate"] ?? "0");
    final rate = double.parse(decodedJson["rate"] ?? "0.0");
    return ExchangeRate(lastUpdate: lastUpdate, rate: rate);
  }

  @override
  Map<String, String> toJson({bool includeLocal = true}) => {
        "rate": rate.toString(),
        "lastUpdate": lastUpdate.toString(),
      };
}
