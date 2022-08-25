void main() {
  print(43.compareTo(2));

  final day = DateTime.now();
  final daysSinceEpoch = day.millisecondsSinceEpoch / 86400000;

  print(daysSinceEpoch);
}
