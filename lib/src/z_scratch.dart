Future<void> jefff() async {
  print("hello, I am Jefff");
  await Future(() {
    print("hello, I am jeffffff");
  });
}

void jeff() {
  print("hello, I am Jeff");
}

void main() {
  jefff();
  jeff();
}
