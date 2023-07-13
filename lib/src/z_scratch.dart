import 'dart:convert';
import 'dart:math' as math;

class Jeff {
  int i;
  Jeff(this.i);
}

void main() async {
  const n = 100000;
  final l = List<Jeff>.generate(n, (i) => Jeff(i));
  final m = l.asMap().map((k, e) => MapEntry(e.i, e));
  final s = Set<Jeff>.from(l);
  const k = 10000;
  List<int> lt = List<int>.filled(k, 0, growable: false);
  List<int> lm = List<int>.filled(k, 0, growable: false);
  List<int> ls = List<int>.filled(k, 0, growable: false);
  int r, t1, t2;
  Jeff j;
  for (int i = 0; i < 10000; i++) {
    r = math.Random().nextInt(100000);
    t1 = DateTime.now().microsecond;
    j = l.singleWhere((j) => j.i == r);
    t2 = DateTime.now().microsecond;
    lt[i] = t2 - t1;

    t1 = DateTime.now().microsecond;
    j = m[r]!;
    t2 = DateTime.now().microsecond;
    lm[i] = t2 - t1;

    t1 = DateTime.now().microsecond;
    j = s.singleWhere((j) => j.i == r);
    t2 = DateTime.now().microsecond;
    ls[i] = t2 - t1;
  }

  print("Sum list access time=${lt.reduce((p, e) => p + e)}");
  print("Sum map  access time=${lm.reduce((p, e) => p + e)}");
  print("Sum set  access time=${ls.reduce((p, e) => p + e)}");
}
