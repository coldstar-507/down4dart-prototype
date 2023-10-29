import 'dart:math';

const golden = 1.618;

num goldenHat(int hat) {
  return pow(golden, hat);
}

num goldenHatRv(int hat) {
  return pow(golden - 1, hat);
}

bool isPrime(int number) {
  if (number <= 1) {
    return false; // 0 and 1 are not prime numbers
  }
  if (number <= 3) {
    return true; // 2 and 3 are prime numbers
  }
  if (number % 2 == 0 || number % 3 == 0) {
    return false; // Numbers divisible by 2 or 3 are not prime
  }

  // Check for prime numbers using 6k +/- 1 rule
  for (int i = 5; i * i <= number; i += 6) {
    if (number % i == 0 || number % (i + 2) == 0) {
      return false;
    }
  }

  return true;
}

void main() async {
  var (bc, jc, nc) = (0, 0, 0);
  int n = 500;

  int i, j;
  for (i = 0; i < n; i++) {
    double k = 0;
    var m = goldenHat(i);
    for (j = 0; j <= i; j++) {
      k += goldenHat(j);
    }
    final baseIsPrime = isPrime(m.round());
    final jeffIsPrime = isPrime(k.round());
    if (isPrime(i)) nc++;
    if (baseIsPrime) bc++;
    if (jeffIsPrime) jc++;
  }

  print("njeff=$jc, nbase=$bc, nname=$nc");
}
