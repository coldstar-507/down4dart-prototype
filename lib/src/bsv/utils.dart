import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:convert/convert.dart';

import 'package:dart_bs58check/dart_bs58check.dart';
import 'package:pointycastle/export.dart';

import 'types.dart';

import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart' as s256;
import 'package:pointycastle/digests/ripemd160.dart' as r160;

import 'package:bs58check/bs58check.dart';

import '../down4_utility.dart';
import '../data_objects.dart';

List<Down4TX> topologicalSort(List<Down4TX> txs) {
  var sorted = <Down4TX>[];
  var prevSortIDs = <TXID>[];
  sorted.addAll(txs.where((tx) => tx.txidDeps.isEmpty));
  do {
    prevSortIDs = sorted.map((e) => e.txID!).toList();
    final unSorted = txs.where((tx) => !prevSortIDs.contains(tx.txID));
    for (final unsortedTx in unSorted) {
      final deps = unsortedTx.txidDeps;
      if (deps.every((dep) => prevSortIDs.contains(dep))) {
        sorted.add(unsortedTx);
      }
    }
  } while (sorted.length != prevSortIDs.length);
  return sorted;
}

Future<List<Down4TXOUT>?> getUtxos(String address) async {
  final url = Uri.parse(
    "https://api.whatsonchain.com/v1/bsv/main/address/$address/unspent",
  );

  final res = await http.get(url);

  if (res.statusCode != 200) return null;

  final utxos = List<dynamic>.from(jsonDecode(res.body));

  var d4utxos = <Down4TXOUT>[];
  for (final utxo in utxos) {
    var d4txout = Down4TXOUT(
      txid: TXID.fromHex(utxo["tx_hash"]),
      sats: Sats(utxo["value"]),
      outIndex: utxo["tx_pos"],
    );
    d4utxos.add(d4txout);
  }
  return d4utxos;
}

Future<List<Down4TXOUT>?> checkPrivateKey(String base58PrivateKey) async {
  List<int> raw;
  final asByte = bs58check.decode(base58PrivateKey);
  if (asByte.lengthInBytes > 32) {
    final check = asByte.sublist(asByte.length - 4);
    final trimmed = asByte.sublist(0, asByte.length - 4);
    raw = trimmed.sublist(1);

    final hash = hash256(trimmed);
    final check_ = hash.sublist(0, 4);
    if (check != check_) return null;
  } else {
    raw = asByte;
  }

  final big = BigInt.parse(raw.toHex(), radix: 16);

  final pub = secp256k1.G * big;
  if (pub == null) return null;

  final address = checkAddress(pub.getEncoded());

  return getUtxos(address.toBase58());
}

List<int> d4out(List<int> address, int walletIndex) {
  final wIdxBuf = Uint8List(4)..buffer.asByteData().setUint32(0, walletIndex);
  return [
    ...p2pkh(address),
    OP.RETURN,
    ...OP.PUSHDATA(wIdxBuf),
  ];
}

List<int> p2pkh(List<int> rawAddress) => [
      OP.DUP,
      OP.HASH160,
      ...OP.PUSHDATA(rawAddress),
      OP.EQUALVERIFY,
      OP.CHECKSIG,
    ];

List<int> makeDER2(ECSignature sig) {
  var rBuf = hex.decode(sig.r.toRadixString(16));
  var sBuf = hex.decode(sig.s.toRadixString(16));
  if (rBuf[0] > 0x7f) rBuf = [0x00, ...rBuf];
  if (sBuf[0] > 0x7f) sBuf = [0x00, ...sBuf];

  final rLen = rBuf.length;
  final sLen = sBuf.length;
  final len = 4 + rLen + sLen;

  return [0x30, len, 0x02, rLen, ...rBuf, 0x02, sLen, ...sBuf];
}

List<int> makeDER(Uint8List r, Uint8List s) {
  const len = 1 + 1 + 32 + 1 + 1 + 32;
  return [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
}

List<int>? p2pkhSig(Down4Keys keys, Down4TX tx, int nIn, [int sh = SIG.ALL]) {
  final sigData = tx.sigData(nIn, sh);
  if (sigData == null) return null;
  final sig = keys.sha256Sign(sha256(sigData).asUint8List());
  if (sig == null) return null;
  return [...makeDER2(sig), sh, ...keys.publicKey.Q!.getEncoded()];
}

List<int> sha256(List<int> data) {
  return s256.SHA256Digest().process(data.asUint8List());
}

List<int> hash256(List<int> data) {
  return sha256(sha256(data));
}

List<int> ripemd160(List<int> data) {
  return r160.RIPEMD160Digest().process(data.asUint8List());
}

List<int> checkAddress(List<int> pubKey) {
  final hash = ripemd160(sha256(pubKey));
  final extended = [0x00, ...hash];
  final checkSum = hash256(extended).sublist(0, 4);
  return [...extended, ...checkSum];
}

List<int>? strippedAddress(List<int> checkAddress) {
  final check = checkAddress.sublist(checkAddress.length - 4);
  final pre = checkAddress.sublist(0, checkAddress.length - 4);
  final sum = hash256(pre).sublist(0, 4);
  if (!listEqual(check, sum)) return null;
  return pre.sublist(1);
}

List<int> hash160(List<int> pubKey) => ripemd160(sha256(pubKey));

int randomWalletIndex() {
  final maxUint32 = int.parse("FFFFFFFF", radix: 16);
  return Random().nextInt(maxUint32);
}

List<int> makeUint32(int i) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, i);

ECPublicKey uncompressPublicKey(Uint8List publicKey) {
  final bigX = BigInt.parse(publicKey.sublist(1).toHex(), radix: 16);
  final point = secp256k1.curve.decompressPoint(publicKey[0] & 1, bigX);
  return ECPublicKey(point, secp256k1);
}

// need deterministicWalletIndex to be able to crawl back transactions and
// utxos on a recovery, the only problem is that it is based on the mobile
// clock. Most mobiles will be fine, some clock might be off, so might need to
// add a mechanism and save mobile start time on user creation
int deterministicWalletIndex() {
  // The divisor is the time required to be sending to different addresses
  // const oneDayInMilliseconds = 86400000;
  const fourHoursInMilliseconds = 14400000;
  final number = timeStamp() / fourHoursInMilliseconds;
  return number.ceil();
}

List<int>? down4FeeAddress(Node self, int ix) {
  final down4Pub = DOWN4_NEUTER.derive(makeUint32(ix))?.publicKey;
  if (down4Pub == null) return null;

  final selfData = utf8.encode(self.id).asUint8List();
  final hash = ripemd160(sha256(down4Pub.Q!.getEncoded() + selfData));
  final extended = [0x00, ...hash];
  final checkSum = hash256(extended).sublist(0, 4);
  return [...extended, ...checkSum];
}
