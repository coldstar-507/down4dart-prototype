void main() {
  final day = DateTime.now();
  final daysSinceEpoch = day.millisecondsSinceEpoch / 86400000;

  print(daysSinceEpoch);
}
