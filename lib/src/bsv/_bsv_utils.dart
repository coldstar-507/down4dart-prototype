import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'dart:convert';

import 'package:down4/src/_dart_utils.dart';

import '../data_objects/_data_utils.dart';
import 'types.dart';

import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart' as s256;
import 'package:pointycastle/digests/ripemd160.dart' as r160;
import 'package:pointycastle/digests/md5.dart' as hash_md5;
import 'package:bs58/bs58.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

import 'package:collection/collection.dart';

import 'dart:io' as io;

final listEqual_ = const ListEquality().equals;

// extension on List<int> {
//   Uint8List toUint8List() => Uint8List.fromList(this);
//   String toBase58() => base58.encode(toUint8List());
//   String toBase64() => base64.encode(this);
//   String toHex() => hex.encode(this);
// }

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

List<int>? sigData({
  required List<Down4TXIN> txsIn,
  required List<Down4TXOUT> txsOut,
  required int nIn,
  required Down4TXOUT utxo,
  int versionNo = 1,
  int nLockTime = 0,
  int sigHashType = SIG.ALL,
}) {
  switch (sigHashType) {
    case SIG.ALL:
      return [
        ...FourByteInt(versionNo).data,
        ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.prevOut])),
        ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.seqNo])),
        ...txsIn[nIn].prevOut,
        ...utxo.scriptLength.data,
        ...utxo.script,
        ...utxo.sats.data,
        ...txsIn[nIn].sequenceNo.data,
        ...hash256(txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.raw])),
        ...FourByteInt(nLockTime).data,
        ...FourByteInt(sigHashType).data,
      ];
    case SIG.SINGLE:
      return [
        ...FourByteInt(versionNo).data,
        ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.prevOut])),
        ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.seqNo])),
        ...txsIn[nIn].prevOut,
        ...utxo.scriptLength.data,
        ...utxo.script,
        ...utxo.sats.data,
        ...txsIn[nIn].sequenceNo.data,
        ...hash256(txsOut[nIn].raw),
        ...FourByteInt(nLockTime).data,
        ...FourByteInt(sigHashType).data,
      ];
    case SIG.NONE:
      return [
        ...FourByteInt(versionNo).data,
        ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.prevOut])),
        ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.seqNo])),
        ...txsIn[nIn].prevOut,
        ...utxo.scriptLength.data,
        ...utxo.script,
        ...utxo.sats.data,
        ...txsIn[nIn].sequenceNo.data,
        ...Uint8List(32),
        ...FourByteInt(nLockTime).data,
        ...FourByteInt(sigHashType).data,
      ];
    case SIG.ALL_ANYONECANPAY:
      return [
        ...FourByteInt(versionNo).data,
        ...Uint8List(32),
        ...Uint8List(32),
        ...txsIn[nIn].prevOut,
        ...utxo.scriptLength.data,
        ...utxo.script,
        ...utxo.sats.data,
        ...txsIn[nIn].sequenceNo.data,
        ...hash256(txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.raw])),
        ...FourByteInt(nLockTime).data,
        ...FourByteInt(sigHashType).data,
      ];
    case SIG.SINGLE_ANYONECANPAY:
      return [
        ...FourByteInt(versionNo).data,
        ...Uint8List(32),
        ...Uint8List(32),
        ...txsIn[nIn].prevOut,
        ...utxo.scriptLength.data,
        ...utxo.script,
        ...utxo.sats.data,
        ...txsIn[nIn].sequenceNo.data,
        ...hash256(txsOut[nIn].raw),
        ...FourByteInt(nLockTime).data,
        ...FourByteInt(sigHashType).data,
      ];
    case SIG.NONE_ANYONECANPAY:
      return [
        ...FourByteInt(versionNo).data,
        ...Uint8List(32),
        ...Uint8List(32),
        ...txsIn[nIn].prevOut,
        ...utxo.scriptLength.data,
        ...utxo.script,
        ...utxo.sats.data,
        ...txsIn[nIn].sequenceNo.data,
        ...Uint8List(32),
        ...FourByteInt(nLockTime).data,
        ...FourByteInt(sigHashType).data,
      ];
  }
  return null;
}

Future<Map<Down4ID, Down4TXOUT>?> getUtxos(String checkAddress) async {
  final url = Uri.parse(
    "https://api.whatsonchain.com/v1/bsv/test/address/$checkAddress/unspent",
  );

  final decodedAddress = base58.decode(checkAddress);
  final rawAddress = strippedCheck(decodedAddress);
  if (rawAddress == null) {
    print("Address doesn't pass check");
    return null;
  }

  final res = await http.get(url);

  if (res.statusCode != 200) return null;

  final utxos = List.from(jsonDecode(res.body));

  var d4utxos = <Down4ID, Down4TXOUT>{};
  for (final utxo in utxos) {
    var d4txout = Down4TXOUT(
      type: UtxoType.gets,
      txid: TXID.fromHex(utxo["tx_hash"]),
      sats: Sats(utxo["value"]),
      outIndex: utxo["tx_pos"],
      script: p2pkh(rawAddress),
    );
    d4utxos[d4txout.id] = d4txout;
  }
  return d4utxos;
}

Down4ID down4UtxoID(TXID txid, FourByteInt ix) {
  return Down4ID(unik: sha1(txid.data + ix.data).toBase58());
}

Future<Map<Down4ID, Down4TXOUT>?> checkPrivateKey(
    String base58PrivateKey) async {
  final asByte = base58.decode(base58PrivateKey);
  final big = BigInt.parse(asByte.toHex(), radix: 16);

  final pub = secp256k1.G * big;
  if (pub == null) return null;

  final address = testnetAddress(pub.getEncoded());

  return getUtxos(address.toBase58());
}

List<int> d4out(List<int> address, List<int> userID, List<int> secret) => [
      ...p2pkh(address),
      OP.RETURN,
      ...OP.PUSHDATA(userID),
      ...OP.PUSHDATA(secret),
    ];

List<int> p2pkh(List<int> rawAddress) => [
      OP.DUP,
      OP.HASH160,
      ...OP.PUSHDATA(rawAddress),
      OP.EQUALVERIFY,
      OP.CHECKSIG,
    ];

List<int> makeDER2(ECSignature sig, int sh) {
  var rString = sig.r.toRadixString(16);
  if (rString.length % 2 != 0) rString = '0' + rString;
  var rBuf = hex.decode(rString);
  var sString = sig.s.toRadixString(16);
  if (sString.length % 2 != 0) sString = '0' + sString;
  var sBuf = hex.decode(sString);
  if (rBuf[0] > 0x7f) rBuf = [0x00, ...rBuf];
  if (sBuf[0] > 0x7f) sBuf = [0x00, ...sBuf];

  final rLen = rBuf.length;
  final sLen = sBuf.length;
  final len = 4 + rLen + sLen;

  return [0x30, len, 0x02, rLen, ...rBuf, 0x02, sLen, ...sBuf, sh];
}

List<int>? p2pkhSig({
  required Down4Keys keys,
  required List<int> sigData,
  int sigHashType = SIG.ALL,
}) {
  final sig = keys.sha256Sign(sha256(sigData).toUint8List());
  if (sig == null) return null;
  return [
    ...OP.PUSHDATA(makeDER2(sig, sigHashType)),
    ...OP.PUSHDATA(keys.publicKey.Q!.getEncoded()),
  ];
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
