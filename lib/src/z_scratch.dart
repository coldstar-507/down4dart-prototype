import 'dart:convert';
import 'dart:math' as math;

String randomBase64() => base64Encode(randomBytes());

List<int> randomBytes() =>
    List<int>.generate(16, (index) => math.Random().nextInt(256));

int calculateShard(String s) => s.codeUnits.fold(0, (p, e) => p + e) % 3;

class Down4ID {
  late final String unique;
  Down4ID({String? unique}) : unique = unique ?? randomBase64();
  String get value => unique;

  static Down4ID? fromString(String? s) {
    if (s == null) return null;
    final splits = s.split("%");
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
  late final String region;
  late final int shard;
  ComposedID({String? unique, String? region, int? shard})
      : super(unique: unique) {
    this.region = region ?? randomBase64();
    this.shard = calculateShard(super.unique);
  }

  @override
  String get value => "$unique%$region%${shard.toString()}";

  static ComposedID? fromString(String? s) {
    if (s == null) return null;
    final elems = s.split("%");
    if (elems.length != 3) return null;
    return ComposedID(
        unique: elems[0], region: elems[1], shard: int.parse(elems[2]));
  }
}

final uniques = <String>["jeff", "andrew", "scott"];

final niggas =
    '{ "jeff": [4325, 432], "andrew": {"helene": true, "david": "david"}}';
final nigga = <String, dynamic>{
  "jeff": [4325, 432],
  "andrew": {"helene": true, "david": "david"}
};

void main() async {
  // print(jsonEncode(niggas));

  final nigga_ = jsonDecode(niggas);

  print(List.from(nigga["jeff"]).map((e) => e + e));

  print(nigga["jeff"][0]);
  print(nigga_["jeff"][0]);

  // final raw = """
  //   SELECT * FROM _ as n
  //   WHERE n.unique IN ${uniques.map((e) => "'$e'").toList().toString()}
  // """;
  //
  // print(raw);
}
