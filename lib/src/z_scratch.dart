

void main() async {
  await Future.wait([
    Future.delayed(Duration(seconds: 2), () => print("LOL")),
    Future.delayed(Duration(seconds: 2), () => print("CACA")),
  ]);
}
