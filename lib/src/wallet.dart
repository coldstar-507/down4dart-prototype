// import 'package:dartsv/dartsv.dart';


// enum PaymentMethods {
//   paymail,
//   adresse,
//   handle
// }

// bool isPaymail(String destination) {
//   destination.runes.forEach((element) {
//     print(String.fromCharCode(element));
//   });


//   return false;
// }

// bool isAlphaNumerical(int cc) {
//   bool isAlpha = false;
//   bool isNumerical = false;
//   if (cc >= 65 && cc <= 122) isAlpha = true;
//   if (cc >= 48 && cc <= 57) isNumerical = true;
//   return isAlpha || isNumerical;
// }

// class Payment {
//   double amount;
//   String destination;
//   String denomination;
//   PaymentMethods? method;
//   Payment(this.amount, this.destination, this.denomination);
// }

// abstract class Wallet {
//   Wallet.fromX(HDPrivateKey xpriv);
//   Wallet.fromMnemonic(String mnemonic);
//   int sats();
//   void pay(PaymentMethods pm, double amount, bool? split);
// }

// void main() async {
//   //final frenchMnemonicGen = Mnemonic(wordList: Wordlist.FRENCH);
//   //final mnemonic = await frenchMnemonicGen.generateMnemonic();
//   //print("This is the mnemonic: $mnemonic");
//   //final seed = frenchMnemonicGen.toSeedHex(mnemonic);
//   //print("This is the seed encoded in HEX: $seed");
//   //final HDPrivateKey xpriv = HDPrivateKey.fromSeed(seed, NetworkType.SCALINGTEST);
//   //print("xpriv: ${xpriv.xprivkey}\nxpub: ${xpriv.xpubkey}");
//   //isPaymail("Fucking niggers I hate them so much");
//   //"andrew24@Down4.com".runes.forEach((element) => print("${String.fromCharCode(element)}=$element"));
//   //"!@#%^&*()_+".runes.forEach((element) => print("${String.fromCharCode(element)}=$element"));
//   //"0123456789".runes.forEach((element) => print("${String.fromCharCode(element)}=$element"));
//   //print("0=${"0".codeUnits}\nA=${"A".runes}\na=${"a".runes}\nZ=${"Z".runes}\nz=${"z".runes}");
//   //final s = List<int>.generate(20, (index) => index + 50);
//   //s.forEach((element) {print("${String.fromCharCode(element)}=$element");});
//   //"andrew24@Down4.com".runes.forEach((element) {
//   //  print("${String.fromCharCode(element)} is AlphaNumerical?=${isAlphaNumerical(element)}");
//   //  });
  
//   //Iterable<int> jeff = Iterable<int>.generate(100, (x) => x%2);
//   //jeff.forEach(print);

// }

