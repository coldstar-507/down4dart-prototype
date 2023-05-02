import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart' as s256;
import 'package:pointycastle/digests/ripemd160.dart' as r160;
import 'package:pointycastle/digests/md5.dart' as hash_md5;
import 'package:bs58/bs58.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

import 'package:collection/collection.dart';

import 'dart:io' as io;

final secp256k1 = ECCurve_secp256k1();

final listEqual_ = const ListEquality().equals;

extension on List<int> {
  Uint8List toUint8List() => Uint8List.fromList(this);
  String toBase58() => base58.encode(toUint8List());
  String toBase64() => base64.encode(this);
  String toHex() => hex.encode(this);
}

int randomSats() {
  return Random().nextInt(50);
}

Uint8List unsafeSeed(int len) {
  var random = Random();
  var seed = List<int>.generate(len, (_) => random.nextInt(256));
  return Uint8List.fromList(seed);
}

Uint8List safeSeed(int len) {
  var random = Random.secure();
  var seed = List<int>.generate(len, (_) => random.nextInt(256));
  return Uint8List.fromList(seed);
}

List<int> sha1(List<int> data) {
  return Digest('SHA-1').process(data.toUint8List());
}

List<int> sha256(List<int> data) {
  return s256.SHA256Digest().process(data.toUint8List());
}

List<int> md5(List<int> data) {
  return hash_md5.MD5Digest().process(data.toUint8List());
}

List<int> hash256(List<int> data) {
  return sha256(sha256(data));
}

List<int> ripemd160(List<int> data) {
  return r160.RIPEMD160Digest().process(data.toUint8List());
}

List<int> mainetAddress(List<int> pubKey) {
  final hash = ripemd160(sha256(pubKey));
  final extended = [0x00, ...hash];
  final checkSum = hash256(extended).sublist(0, 4);
  return [...extended, ...checkSum];
}

List<int> testnetAddress(List<int> pubKey) {
  final hash = ripemd160(sha256(pubKey));
  final extended = [0x6f, ...hash];
  final checkSum = hash256(extended).sublist(0, 4);
  return [...extended, ...checkSum];
}

List<int>? strippedCheck(List<int> checkAddress) {
  final check = checkAddress.sublist(checkAddress.length - 4);
  final pre = checkAddress.sublist(0, checkAddress.length - 4);
  final sum = hash256(pre).sublist(0, 4);
  if (!listEqual_(check, sum)) return null;
  return pre.sublist(1);
}

List<int> stripped(List<int> checkAddress) {
  final pre = checkAddress.sublist(0, checkAddress.length - 4);
  return pre.sublist(1);
}

List<int> hash160(List<int> pubKey) => ripemd160(sha256(pubKey));

List<int> makeUint32(int i) {
  return Uint8List(4)..buffer.asByteData().setUint32(0, i);
}

ECPublicKey uncompressPublicKey(Uint8List publicKey) {
  final bigX = BigInt.parse(publicKey.sublist(1).toHex(), radix: 16);
  final point = secp256k1.curve.decompressPoint(publicKey[0] & 1, bigX);
  return ECPublicKey(point, secp256k1);
}

class Down4Keys {
  ECPublicKey publicKey;
  ECPrivateKey? privateKey;
  Uint8List chainCode;

  Down4Keys._({
    required this.publicKey,
    this.privateKey,
    Uint8List? chainCode,
  }) : chainCode = chainCode ?? Uint8List(32);

  ECSignature? sha256Sign(Uint8List message) {
    if (privateKey == null) return null;
    var pkParam = PrivateKeyParameter(privateKey!);

    var signer = Signer('SHA-256/DET-ECDSA');
    signer.init(true, pkParam);

    var sig = signer.generateSignature(message.toUint8List()) as ECSignature;
    return sig.normalize(secp256k1);
  }

  bool verify(Uint8List message, ECSignature sig) {
    var pbParam = PublicKeyParameter(publicKey);

    var verifier = Signer('SHA-256/DET-ECDSA');
    verifier.init(false, pbParam);

    return verifier.verifySignature(message, sig);
  }

  Down4Keys? derive(List<int> secret) {
    var hmac = Mac('SHA-512/HMAC');
    hmac.init(KeyParameter(chainCode));

    var xString = publicKey.Q!.x!.toBigInteger()!.toRadixString(16);
    var yString = publicKey.Q!.y!.toBigInteger()!.toRadixString(16);
    if (xString.length % 2 != 0) xString = '0' + xString;
    if (yString.length % 2 != 0) yString = '0' + yString;

    final bigX = hex.decode(xString);
    final bigY = hex.decode(yString);

    final data = bigX + bigY + secret;

    final out = hmac.process(data.toUint8List());
    final left = out.sublist(0, 32);
    final right = out.sublist(32, 64);

    final big = BigInt.parse(right.toHex(), radix: 16);

    final bigPoint = secp256k1.G * big;
    if (bigPoint == null) return null;
    final newPoint = bigPoint + publicKey.Q!;
    final pub = ECPublicKey(newPoint, secp256k1);

    if (isNeutered) {
      return Down4Keys._(publicKey: pub, chainCode: left);
    } else {
      final newScalar = (privateKey!.d! + big) % secp256k1.n;
      final prv = ECPrivateKey(newScalar, secp256k1);
      return Down4Keys._(publicKey: pub, privateKey: prv, chainCode: left);
    }
  }

  List<int> get rawAddress => hash160(publicKey.Q!.getEncoded());

  String get checkAddressB58 => mainetAddress(rawCompressedPub).toBase58();

  bool get isNeutered => privateKey == null;

  String get compressedPubKeyHex => rawCompressedPub.toHex();

  Uint8List get rawCompressedPub => publicKey.Q!.getEncoded();

  String? get privKeyHex => privateKey?.d?.toRadixString(16);

  String get privKeyBase58 => privKeyHex!.length % 2 == 0
      ? hex.decode(privKeyHex!).toBase58()
      : hex.decode('0$privKeyHex').toBase58();

  Down4Keys neutered() =>
      Down4Keys._(publicKey: publicKey, chainCode: chainCode);

  Map<String, dynamic> toJson() => {
        if (!isNeutered) "prv": privKeyHex,
        "pub": compressedPubKeyHex,
        "cc": chainCode.toHex(),
      };

  String toYouKnow() => base64Encode(utf8.encode(jsonEncode(this)));

  factory Down4Keys.fromYouKnow(String youKnow) {
    return Down4Keys.fromJson(jsonDecode(utf8.decode(base64Decode(youKnow))));
  }

  factory Down4Keys.fromJson(dynamic decodedJson) {
    final chainCode = hex.decode(decodedJson["cc"]).toUint8List();
    ECPrivateKey? prv;
    if (decodedJson["prv"] != null) {
      var big = BigInt.parse(decodedJson["prv"], radix: 16);
      prv = ECPrivateKey(big, secp256k1);
    }

    final pubByte = hex.decode(decodedJson["pub"]).toUint8List();
    final pub = uncompressPublicKey(pubByte);

    return Down4Keys._(publicKey: pub, chainCode: chainCode, privateKey: prv);
  }

  factory Down4Keys.fromRandom(Uint8List keySeed, Uint8List chainCodeSeed) {
    var chainCode = sha256(chainCodeSeed).toUint8List();

    var keyParams = ECKeyGeneratorParameters(secp256k1);

    var random = FortunaRandom();
    random.seed(KeyParameter(keySeed));

    var generator = ECKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, random));

    final pair = generator.generateKeyPair();

    return Down4Keys._(
      publicKey: pair.publicKey as ECPublicKey,
      privateKey: pair.privateKey as ECPrivateKey,
      chainCode: chainCode,
    );
  }

  factory Down4Keys.fromPrivateKey(BigInt d, [Uint8List? cc]) {
    final pk = ECPrivateKey(d, secp256k1);
    final pubPoint = secp256k1.G * d;
    final pub = ECPublicKey(pubPoint, secp256k1);

    return Down4Keys._(publicKey: pub, privateKey: pk);
  }
}

void main() {
  // final seed1 = safeSeed(32);
  // final seed2 = safeSeed(32);

  // var pair0_ = Down4Keys.fromRandom(seed1, seed2);

  // io.File("/home/scott/jeff.txt").writeAsString(pair0_.privKeyHex!);

  // final pkHex = io.File("/home/scott/jeff.txt").readAsStringSync();
  final pkHex = io.File("C:/Users/coton/Desktop/jeff.txt").readAsStringSync();

  var pair0 = Down4Keys.fromPrivateKey(BigInt.parse(pkHex, radix: 16));
  var pair1 = pair0.derive(makeUint32(1))!;
  var pair2 = pair0.derive(makeUint32(2))!;
  var pair3 = pair0.derive(makeUint32(3))!;

  print("TEST0: ${testnetAddress(pair0.rawCompressedPub).toBase58()}");
  print("TEST1: ${testnetAddress(pair1.rawCompressedPub).toBase58()}");
  print("TEST2: ${testnetAddress(pair2.rawCompressedPub).toBase58()}");
  print("TEST3: ${testnetAddress(pair3.rawCompressedPub).toBase58()}");

  print("TEST0PK: ${pair0.privKeyBase58}");
  print("TEST1PK: ${pair1.privKeyBase58}");
  print("TEST2PK: ${pair2.privKeyBase58}");
  print("TEST3PK: ${pair3.privKeyBase58}");
}
