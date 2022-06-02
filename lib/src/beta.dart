void main() {
  Map<String, Map<String, int>> jeff = {"Friends": {}, "Niggers": {}};

  var nig = {"a": 7, "b": 2, "c": 3};
  var j = {"k": 1, "h": 45};
  var caca = {"hh": 4, "bb": 99};
  var nig2 = nig.values.followedBy(j.values).toList()
    ..sort(((a, b) => a.compareTo(b)))
    ..addAll(caca.values);
  // var nig3 = nig2..addAll(caca.values);

  <String,int>{"jeff": 3}.values;

  print(nig);
  print(nig2);
}
