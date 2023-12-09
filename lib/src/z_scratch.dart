extension ListExtensions<T> on List<T> {
  void updateWhere(T k, bool Function(T) test) {
    for (final (i, e) in indexed) {
      if (test(e)) this[i] = k;
    }
  }
}

void main() async {
  final someText = [1, 2];

  print(someText..updateWhere(3, (p) => p == 2));
}
