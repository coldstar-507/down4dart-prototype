import 'dart:math';

const golden = 1.618;

num goldenHat(int hat) {
  return pow(golden, hat);
}

num goldenHatRv(int hat) {
  return pow(golden - 1, hat);
}

void main() async {
  int i;
  for (i = 0; i < 10; i++) {
    print("GOLDEN HAT    $i = ${goldenHat(i)}");
    print("GOLDEN HAT RV $i = ${goldenHatRv(i)}");    
  }
}
