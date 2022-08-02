class Jeff {
  final int a;
  bool b;
  int c;
  Jeff({
    required this.a,
    this.b = false,
    required this.c,
  });
}

void main() {
  var jeff = Jeff(a: 2, b: true, c: 98);
  jeff
    ..b = false
    ..c = 1;

  print("jeff.b: ${jeff.b}, jeff.c = ${jeff.c}");
}
