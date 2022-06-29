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
  final jeff = Jeff(a: 2, b: false, c: 83);
  print(jeff.c);
  print((jeff..c = 5).c);
}
