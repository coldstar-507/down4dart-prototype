import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:convert/convert.dart';
import 'data_objects.dart';
import 'package:pointycastle/digests/sha256.dart' as s256;
import 'package:pointycastle/digests/ripemd160.dart' as r160;
import 'package:bip32/bip32.dart';
import 'down4_utility.dart';
import 'web_requests.dart' as r;
import 'package:http/http.dart' as http;
// import 'package:bip39/bip39.dart' as bip39;
import 'package:fast_base58/fast_base58.dart' as b58;
// import 'package:elliptic/elliptic.dart' as ell;
// import 'package:ecdsa/ecdsa.dart' as ecdsa;
import 'package:dart_ecpair/dart_ecpair.dart' as ec;
// import 'dart:io' as io;

const SATS_PER_BYTE = 0.05;

final DOWN4_NEUTER = BIP32.fromBase58(
  "xpub6DTufsTvxdAJaPhAMcowwgNWghwUXw8fexqjY5rEdBdBiVAJiKCY7SQzVwBb7JXgMLFcoNqAxwJZUEEVnGFjj8ngbu2HGwTDBhPfVvHcGYs",
);

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

List<int> _d4out(List<int> address, int walletIndex) {
  var wIdxBuf = Uint8List(4)..buffer.asByteData().setUint32(0, walletIndex);
  return [..._p2pkh(address), 0x6a, 0x4c, 0x04, ...wIdxBuf];
}

List<int> _p2pkh(List<int> address) => [0x76, 0xa9, ...address, 0x88, 0xac];

Uint8List sha256(Uint8List data) => s256.SHA256Digest().process(data);

Uint8List sha256sha256(Uint8List data) => sha256(sha256(data));

Uint8List ripemd160(Uint8List data) => r160.RIPEMD160Digest().process(data);

Uint8List _makeAddress(Uint8List pubKey) {
  final hash = ripemd160(sha256(pubKey));
  final extended = [0x00, ...hash].asUint8List();
  final checkSum = sha256sha256(extended).sublist(0, 4);
  return [...extended, ...checkSum].asUint8List();
}

int _randomWalletIndex() {
  final maxUint32 = int.parse("FFFFFFFF", radix: 16);
  return Random().nextInt(maxUint32);
}

// need deterministicWalletIndex to be able to crawl back transactions and
// utxos on a recovery, the only problem is that it is based on the mobile
// clock. Most mobiles will be fine, some clock might be off, so might need to
// add a mechanism and save mobile start time on user creation
int _deterministicWalletIndex() {
  // The divisor is the time required to be sending to different addresses
  // const oneDayInMilliseconds = 86400000;
  const fourHoursInMilliseconds = 14400000;
  final number = timeStamp() / fourHoursInMilliseconds;
  return number.ceil();
}

class Down4InternetPayment {
  List<String> targets;
  String sender;
  Down4Payment pay;
  Down4InternetPayment(this.targets, this.sender, this.pay);

  Map<String, dynamic> toJson() => {
        "trgts": targets,
        "sdrid": sender,
        "pay": pay.toJson(),
      };
}

class Down4Payment {
  List<Down4TX> txs;
  bool safe;
  Down4Payment(this.txs, this.safe);

  String get id => sha256(txs.fold<List<int>>(
          [], (prev, tx) => prev + tx.txID!.data).asUint8List())
      .toHex();

  Map<String, dynamic> toJsoni(int i) => {
        "tx": txs[i].toJson(),
        "len": txs.length,
        "safe": safe,
      };

  Map<String, dynamic> toJson() => {
        "tx": txs.map((tx) => tx.toJson()).toList(),
        "len": txs.length,
        "safe": safe,
      };
  factory Down4Payment.fromJson(dynamic decodedJson) {
    return Down4Payment(
      List<dynamic>.from(decodedJson["tx"])
          .map((e) => Down4TX.fromJson(e))
          .toList(),
      decodedJson["safe"],
    );
  }
}

class Wallet {
  final String _mnemonic;
  BIP32 bip;
  List<Down4TXOUT> utxos;
  List<Down4TX> unsettledTxs;

  String get mnemonic => _mnemonic;
  int get balance => utxos.fold(0, (bal, tx) => bal + tx.sats.asInt);
  List<TXID> get uTXID => unsettledTxs.map((e) => e.txID!).toList();

  Future<BatchResponse?> trySettlement([List<Down4TX>? txs]) async {
    return await r.broadcastTxs(txs ?? unsettledTxs);
  }

  Wallet({
    required this.utxos,
    required this.bip,
    required this.unsettledTxs,
    required String mnemonic,
  }) : _mnemonic = mnemonic;

  factory Wallet.fromJson(dynamic decodedJson) {
    return Wallet(
      mnemonic: decodedJson["m"],
      bip: BIP32.fromBase58(decodedJson["bip"]),
      utxos: List<dynamic>.from(decodedJson["utxos"])
          .map((jsonUtxo) => Down4TXOUT.fromJson(jsonUtxo))
          .toList(),
      unsettledTxs: List<dynamic>.from(decodedJson["txs"])
          .map((jsonTx) => Down4TX.fromJson(jsonTx))
          .toList(),
    );
  }

  Future<Down4Payment?> importFromWif(String wif, Node self) async {
    var pair = ec.ECPair.fromWIF(wif);

    final wIdx = _deterministicWalletIndex();
    final down4Address = _makeAddress(DOWN4_NEUTER.derive(wIdx).publicKey);
    final myAddress = _makeAddress(self.neuter!.derive(wIdx).publicKey);

    final importAddress = _makeAddress(pair.publicKey).toBase58();

    var utxos = await getUtxos(importAddress);
    if (utxos == null) return null;

    final inSats = utxos.fold<Sats>(Sats(0), (s, u) => s + u.sats);
    final inLen = utxos.length;
    final txSize = 4 + 4 + 9 + 9 + (148 * inLen) + (34 * 2);
    final minerFees = (txSize * SATS_PER_BYTE).ceil();
    final down4Fees = (minerFees / 2).ceil();
    final totalFees = down4Fees + minerFees;

    final myGets = inSats - Sats(totalFees);

    var txsIn = <Down4TXIN>[];
    for (final utxo in utxos) {
      txsIn.add(Down4TXIN.fromP2PKH(utxo));
    }

    var txsOut = <Down4TXOUT>[
      Down4TXOUT(
        sats: Sats(down4Fees),
        scriptPubKey: _p2pkh(down4Address),
        outIndex: 0,
      ),
      Down4TXOUT(
        receiver: self.id,
        sats: myGets,
        scriptPubKey: _p2pkh(myAddress),
        outIndex: 1,
      ),
    ];

    var tx = Down4TX(txsIn: txsIn, txsOut: txsOut);
    final txid = tx.txid();
    final txdata = tx.sigAllRawData;

    for (var txin in tx.txsIn) {
      final Uint8List sig = pair.sign(txdata.asUint8List());
      final r = sig.sublist(0, 32);
      final s = sig.sublist(32, 64);
      const len = 1 + 1 + 32 + 1 + 1 + 32;
      final der = [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
      final unlockScript = [...der, 0x41, ...pair.publicKey];

      txin.script = unlockScript;
    }

    return Down4Payment([tx], true);
  }

  Map<String, dynamic> toJson() => {
        "m": mnemonic,
        "bip": bip.toBase58(),
        "utxos": utxos.map((e) => e.toJson()).toList(),
        "txs": unsettledTxs.map((e) => e.toJson()).toList(),
      };

  void parsePayment(Node self, Down4Payment pay) {
    var sortedTxs = _topologicalSort(pay.txs);
    // if I'm right, we only care about utxos of the last TX
    var lastTx = sortedTxs.last;
    if (pay.safe) {
      for (final utxo in lastTx.txsOut) {
        if (utxo.receiver == self.id && !utxos.contains(utxo)) {
          utxos.add(utxo);
        }
      }
    } else {
      // TODO
    }
  }

  List<Down4TX> _chainedTxs(List<Down4TX> deps) {
    var newDeps = deps
        .map((tx) => tx.txidDeps..add(tx.txID!))
        .expand((txid) => txid)
        .toSet()
        .map((txid) => unsettledTxs.singleWhere((tx) => tx.txID == txid))
        .toList();

    if (newDeps.length == deps.length) return deps;
    return _chainedTxs(newDeps);
  }

  List<Down4TXOUT> _reqOuts(List<Node> tgrts, Node self, Sats sats, int wIdx) {
    List<Down4TXOUT> outs = [];
    Sats satsPerTarget = Sats((sats.asInt / tgrts.length).floor());
    for (int i = 0; i < tgrts.length; i++) {
      final targetNeuter = tgrts[i].neuter!.deriveHardened(wIdx);
      final address = _makeAddress(targetNeuter.publicKey);
      outs.add(Down4TXOUT(
        receiver: tgrts[i].id,
        walletIndex: wIdx,
        outIndex: i,
        sats: satsPerTarget,
        scriptPubKey: _d4out(address, wIdx),
      ));
    }
    return outs;
  }

  List<dynamic>? _unsignedIns(Node self, Sats pay, int nOuts) {
    List<Down4TXIN> ins = [];
    var minerFees =
        Sats((((nOuts * 34) + 4 + 4 + 9 + 9) * SATS_PER_BYTE).ceil());
    var down4Fees = Sats((minerFees.asInt / 2).ceil());
    var sats = Sats(0);
    for (int i = 0; i < utxos.length; i++) {
      ins.add(Down4TXIN(
          spender: self.id,
          walletIndex: utxos[i].walletIndex,
          sats: utxos[i].sats,
          spentFrom: utxos[i].txid!,
          outIndex: utxos[i].outIndex!,
          sequenceNo: 0,
          dependance: uTXID.contains(utxos[i].txid!) ? utxos[i].txid : null));

      sats = sats + utxos[i].sats;
      minerFees = Sats(minerFees.asInt + (148 * SATS_PER_BYTE).ceil());
      down4Fees = Sats((minerFees.asInt / 2).ceil());

      if (sats > minerFees + pay + down4Fees) {
        return [ins, minerFees, down4Fees];
      }
    }
    return null;
  }

  Down4Payment? payUsers(List<Node> targets, Node self, Sats amount) {
    final walletIndex = _randomWalletIndex();
    var outs = _reqOuts(targets, self, amount, walletIndex);
    var inInfo = _unsignedIns(self, amount, targets.length + 2);
    if (inInfo == null) return null;
    List<Down4TXIN> txsIn = inInfo[0];
    Sats minerFees = inInfo[1];
    Sats down4Fees = inInfo[2];
    final inAmount = txsIn.fold<Sats>(Sats(0), (tot, tx) => tot + tx.sats!);

    // add the change
    final changeAmount = inAmount - amount - minerFees - down4Fees;
    if (changeAmount.asInt > 0) {
      final changePubKey = self.neuter!.derive(walletIndex).publicKey;
      final changeAddress = _makeAddress(changePubKey);
      outs.add(Down4TXOUT(
        sats: changeAmount,
        scriptPubKey: _d4out(changeAddress, walletIndex),
        walletIndex: walletIndex,
        receiver: self.id,
        outIndex: outs.length,
      ));
    }

    // add the relay tax
    final relayPubKey = DOWN4_NEUTER.derive(walletIndex).publicKey;
    final relayChangeAddress = _makeAddress(relayPubKey);
    outs.add(Down4TXOUT(
      sats: down4Fees,
      scriptPubKey: _d4out(relayChangeAddress, walletIndex),
      walletIndex: walletIndex,
      outIndex: outs.length,
    ));

    // here we should have all the tx data necessary for signing
    var tx = Down4TX(txsIn: txsIn, maker: self.id, txsOut: outs);
    final txdata = tx.sigAllRawData.asUint8List();
    for (var txin in tx.txsIn) {
      final derived = bip.derive(txin.walletIndex!);
      final Uint8List sig = derived.sign(txdata);
      final r = sig.sublist(0, 32);
      final s = sig.sublist(32, 64);
      const len = 1 + 1 + 32 + 1 + 1 + 32;
      final der = [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
      final unlockScript = [...der, 0x41, ...derived.publicKey];

      txin.script = unlockScript;
    }
    final txid = tx.txid();
    for (var txout in tx.txsOut) {
      txout.txid = txid;
      if (txout.receiver == self.id) utxos.add(txout);
    }
    unsettledTxs.add(tx);
    final chain = _chainedTxs([tx]);
    return Down4Payment(chain, true);
  }

  List<Down4TX> _topologicalSort(List<Down4TX> txs) {
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

  Down4Payment? payToAnyone(Node self, Sats amount) {
    if (amount.asInt > balance) return null;
    // for payToAnyone, we need a perfect input Amount for the tx we are giving
    // because we can't use change, since we can't know what the transaction ID will be.
    // Using change would require the unknown receiver to calculate the TXID and send back
    // the tx to us, which we don't want. We simply want to give the utxos and be done with.
    // The solution is to first make a tx that will output the perfect amount, and use that output
    Down4TX firstTx;
    var firstTxsIn = <Down4TXIN>[];
    var firstTxsOut = <Down4TXOUT>[];
    final wIdx = _randomWalletIndex();
    // we want our utxo to be amount + minerfees + down4fees
    // our final tx should be exactly 1 input and 2 outputs of p2pkh script
    const lastTxSize = 4 + 1 + 148 + 1 + 34 + 34 + 4;
    final lastTxMinerFees = Sats((SATS_PER_BYTE * lastTxSize).ceil());
    final lastTxDown4Fees = Sats((lastTxMinerFees.asInt / 2).ceil());
    final desiredUtxoAmount = amount + lastTxMinerFees + lastTxDown4Fees;

    // the true amount needed is the first TX fees + desiredUtxoAmount
    // so firstTXMinerFees + firstTXDown4Fees + desiredUtxoAmount
    // the first two elements need to be calculated dynamically
    // first tx is expect 3 outputs (change, down4fees, desiredUtxo)
    // and can have n inputs

    // _sortUtxos(); // feel like not doing this would yield me more money
    var count = Sats(0);
    // three outs (34 * 3), vNo (4), nLock (4), outCount (1), inCount(1 to 9)
    var firstTxMinerFees =
        Sats((SATS_PER_BYTE * (34 * 3)).ceil() + 4 + 4 + 1 + 9);
    var firstTxDown4Fees = Sats((firstTxMinerFees.asInt / 2).ceil());
    var firstTxTotalReqs =
        firstTxMinerFees + firstTxDown4Fees + desiredUtxoAmount;
    for (int i = 0; i < utxos.length; i++) {
      firstTxsIn.add(
        Down4TXIN(
          spender: self.id,
          walletIndex: utxos[i].walletIndex,
          sats: utxos[i].sats,
          spentFrom: utxos[i].txid!,
          outIndex: utxos[i].outIndex!,
          sequenceNo: 0,
          dependance: uTXID.contains(utxos[i].txid!) ? utxos[i].txid : null,
        ),
      );

      firstTxMinerFees += Sats((SATS_PER_BYTE * 148).ceil());
      firstTxDown4Fees = Sats((firstTxMinerFees.asInt / 2).ceil());
      firstTxTotalReqs =
          firstTxMinerFees + firstTxDown4Fees + desiredUtxoAmount;
      count += utxos[i].sats;

      if (count >= firstTxTotalReqs) {
        break;
      } else if (i == utxos.length - 1) {
        return null;
      }
    }

    // First tx change out
    final changeAmount = count - firstTxMinerFees;
    final changeAddr = _makeAddress(self.neuter!.derive(wIdx).publicKey);
    var changeOut = Down4TXOUT(
      receiver: self.id,
      sats: changeAmount,
      scriptPubKey: _d4out(changeAddr, wIdx),
      walletIndex: wIdx,
      outIndex: 0,
    );
    firstTxsOut.add(changeOut);

    // First tx down4fees
    final down4feeAddr = _makeAddress(DOWN4_NEUTER.derive(wIdx).publicKey);
    var taxOut = Down4TXOUT(
      sats: firstTxDown4Fees,
      scriptPubKey: _d4out(down4feeAddr, wIdx),
      walletIndex: wIdx,
      outIndex: 1,
    );
    firstTxsOut.add(taxOut);

    // finally, the desired output we want to spend in the first place
    // can re-use the changeAddr for that one
    var desiredOut = Down4TXOUT(
      receiver: self.id,
      sats: desiredUtxoAmount,
      scriptPubKey: _d4out(changeAddr, wIdx),
      walletIndex: wIdx,
      outIndex: 2,
    );
    firstTxsOut.add(desiredOut);

    // now we must sign and terminate this tx
    // we use SIG_HASH_ALL for this one, it's immutable
    firstTx = Down4TX(txsIn: firstTxsIn, txsOut: firstTxsOut, maker: self.id);
    final txdata = firstTx.sigAllRawData.asUint8List();
    for (var txin in firstTx.txsIn) {
      final derived = bip.derive(txin.walletIndex!);
      final Uint8List sig = derived.sign(txdata);
      final r = sig.sublist(0, 32);
      final s = sig.sublist(32, 64);
      const len = 1 + 1 + 32 + 1 + 1 + 32;
      final der = [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
      final unlockScript = [...der, 0x41, ...derived.publicKey];

      txin.script = unlockScript;
    }
    final firstTxID = firstTx.txid();
    for (var txout in firstTx.txsOut) {
      txout.txid = firstTxID;
      if (txout.receiver == self.id && txout.walletIndex != 2) {
        utxos.add(txout);
      }
    }

    Down4TX lastTx;
    // so as we already know, this lastTx has 1 perfect input and 2 outputs
    var lastOuts = <Down4TXOUT>[];
    var lastIns = <Down4TXIN>[];

    var lastTaxOut = Down4TXOUT(
      sats: lastTxDown4Fees,
      scriptPubKey: _d4out(down4feeAddr, wIdx),
      walletIndex: wIdx,
      outIndex: 0,
    );
    lastOuts.add(lastTaxOut);

    var incompleteOut = Down4TXOUT(
      sats: amount,
      walletIndex: wIdx,
      outIndex: 1,
    );
    lastOuts.add(incompleteOut);

    var lastPerfectIn = Down4TXIN(
      spentFrom: desiredOut.txid!,
      walletIndex: desiredOut.walletIndex,
      outIndex: desiredOut.outIndex!,
      sequenceNo: 0,
      dependance: desiredOut.txid,
      sats: desiredOut.sats,
    );
    lastIns.add(lastPerfectIn);

    lastTx = Down4TX(txsIn: lastIns, txsOut: lastOuts, maker: self.id);

    // now we sign with either SIGHASH_SINGLE or SIGHASH_SINGLE|ANYONECANPAY
    final derived = bip.derive(lastPerfectIn.walletIndex!);
    final Uint8List sig = derived.sign(lastTx.sigSingleData(0).asUint8List());
    final r = sig.sublist(0, 32);
    final s = sig.sublist(32, 64);
    const len = 1 + 1 + 32 + 1 + 1 + 32;
    final der = [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
    final unlockScript = [...der, 0x43, ...derived.publicKey];

    lastTx.txsIn.first.script = unlockScript;
    unsettledTxs.add(firstTx);

    final chain = _chainedTxs([firstTx]);
    return Down4Payment([...chain, lastTx], false);
  }
}

class VarInt {
  final List<int> data;
  final int asInt;

  const VarInt._(this.data, this.asInt);

  factory VarInt.fromInt(int n) {
    Uint8List data;
    if (n >= 0 && n <= 252) {
      data = Uint8List(1)..buffer.asByteData().setUint8(0, n);
    } else if (n >= 253 && n <= 65535) {
      data = Uint8List(3)
        ..buffer.asByteData().setUint8(0, 0xFD)
        ..buffer.asByteData().setUint16(1, n, Endian.little);
    } else if (n >= 65536 && n <= 4294967295) {
      data = Uint8List(5)
        ..buffer.asByteData().setUint8(0, 0xFE)
        ..buffer.asByteData().setUint32(1, n, Endian.little);
    } else {
      data = Uint8List(9)
        ..buffer.asByteData().setUint8(0, 0xFF)
        ..buffer.asByteData().setUint64(1, n, Endian.little);
    }
    return VarInt._(data, n);
  }

  String toHex() => hex.encode(data);
}

class FourByteInt {
  final List<int> data;
  final int asInt;

  FourByteInt(int n)
      : data = Uint8List(4)..buffer.asByteData().setUint32(0, n, Endian.little),
        asInt = n;
}

class TXID {
  final List<int> data;

  TXID(this.data);

  factory TXID.fromHex(String h) => TXID(hex.decode(h));

  factory TXID.fromBigEndian(List<int> be) => TXID(be.reversed.toList());

  factory TXID.fromBigEndianHex(String beh) =>
      TXID(hex.decode(beh).reversed.toList());

  List<int> get asBigEndian => data.reversed.toList();

  String get asHex => data.toHex();

  String get asHexBigEndian => data.reversed.toList().toHex();

  bool equals(TXID other) => data == other.data;

  @override
  int get hashCode => BigInt.parse(asHexBigEndian, radix: 16).hashCode;

  @override
  bool operator ==(other) => other is TXID && listEqual(other.data, data);
}

class Sats {
  final List<int> data;
  final int asInt;

  Sats(int sats)
      : data = Uint8List(8)
          ..buffer.asByteData().setInt64(0, sats, Endian.little),
        asInt = sats;

  Sats operator +(Sats s) => Sats(asInt + s.asInt);

  Sats operator -(Sats s) => Sats(asInt - s.asInt);

  Sats operator *(Sats s) => Sats(asInt * s.asInt);

  Sats operator /(Sats s) => Sats((asInt / s.asInt).floor());

  bool operator >(Sats s) => asInt > s.asInt;

  bool operator >=(Sats s) => asInt >= s.asInt;

  bool operator <(Sats s) => asInt < s.asInt;

  bool operator <=(Sats s) => asInt <= s.asInt;
}

class Down4TXIN {
  Identifier? spender;
  int? walletIndex;
  Sats? sats;
  TXID spentFrom;
  FourByteInt outIndex, sequenceNo;
  VarInt? scriptSigLen;
  List<int>? scriptSig;
  TXID? dependance;

  Down4TXIN({
    this.spender,
    this.walletIndex,
    this.sats,
    required this.spentFrom,
    this.scriptSig,
    required int outIndex,
    int? sequenceNo,
    this.scriptSigLen,
    this.dependance,
  })  : outIndex = FourByteInt(outIndex),
        sequenceNo = FourByteInt(sequenceNo ?? 0);

  factory Down4TXIN.fromP2PKH(Down4TXOUT txout) {
    return Down4TXIN(
      spender: txout.receiver,
      spentFrom: txout.txid!,
      outIndex: txout.outIndex!,
      sequenceNo: 0,
    );
  }

  factory Down4TXIN.fromJson(dynamic decodedJson) => Down4TXIN(
        spender: decodedJson["sp"],
        walletIndex: decodedJson["wi"],
        sats: Sats(decodedJson["s"]),
        spentFrom: TXID.fromHex(decodedJson["id"]),
        outIndex: decodedJson["oi"],
        sequenceNo: decodedJson["sn"],
        scriptSigLen: VarInt.fromInt(decodedJson["sl"]),
        scriptSig: hex.decode(decodedJson["sc"]),
        dependance:
            decodedJson["dp"] != null ? TXID.fromHex(decodedJson["dp"]) : null,
      );

  List<int> get asData => [
        ...spentFrom.data,
        ...outIndex.data,
        ...scriptSigLen!.data,
        ...scriptSig!,
        ...sequenceNo.data,
      ];

  List<int> get sigData => [
        ...spentFrom.data,
        ...outIndex.data,
      ];

  set script(List<int> script) {
    scriptSig = script;
    scriptSigLen = VarInt.fromInt(script.length);
  }

  Map<String, dynamic> toJson() => {
        "sp": spender,
        "wi": walletIndex,
        "s": sats?.asInt,
        "id": spentFrom.asHex,
        "oi": outIndex.asInt,
        "sn": sequenceNo.asInt,
        "sl": scriptSigLen?.asInt,
        "sc": scriptSig!.toHex(),
        "dp": dependance?.asHex,
      };
}

class Down4TXOUT {
  Identifier? receiver;
  int? walletIndex, outIndex;
  TXID? txid;
  Sats sats;
  VarInt? scriptPubKeyLen;
  List<int>? scriptPubKey;

  Down4TXOUT({
    this.receiver,
    this.walletIndex,
    this.txid,
    this.outIndex,
    required this.sats,
    this.scriptPubKey,
  }) : scriptPubKeyLen = VarInt.fromInt(scriptPubKey?.length ?? 0);

  factory Down4TXOUT.fromJson(dynamic decodedJson) => Down4TXOUT(
        receiver: decodedJson["rc"],
        walletIndex: decodedJson["wi"],
        outIndex: decodedJson["oi"],
        txid: TXID.fromHex(decodedJson["id"]),
        sats: Sats(decodedJson["s"]),
        scriptPubKey: hex.decode(decodedJson["sc"]),
      );

  set scriptLen(int n) => scriptPubKeyLen = VarInt.fromInt(n);

  @override
  int get hashCode {
    final uniqueData = txid!.data + FourByteInt(outIndex!).data;
    return BigInt.parse(hex.encode(uniqueData), radix: 16).hashCode;
  }

  @override
  bool operator ==(other) =>
      other is Down4TXOUT && other.txid == txid && other.outIndex == outIndex;

  List<int> get asData => [
        ...sats.data,
        ...scriptPubKeyLen!.data,
        ...scriptPubKey!,
      ];

  Map<String, dynamic> toJson() => {
        "rc": receiver,
        "wi": walletIndex,
        "oi": outIndex,
        "id": txid!.asHex,
        "s": sats.asInt,
        if (scriptPubKey != null) "sc": hex.encode(scriptPubKey!),
      };
}

class Down4TX {
  Identifier? maker;
  FourByteInt versionNo, nLockTime;
  List<Down4TXIN> txsIn;
  List<Down4TXOUT> txsOut;
  VarInt inCounter, outCounter;
  TXID? txID;

  Down4TX({
    this.maker,
    int? versionNo,
    int? nLockTime,
    required this.txsIn,
    required this.txsOut,
    this.txID,
  })  : versionNo = FourByteInt(versionNo ?? 2),
        nLockTime = FourByteInt(nLockTime ?? 0),
        inCounter = VarInt.fromInt(txsIn.length),
        outCounter = VarInt.fromInt(txsOut.length);

  factory Down4TX.fromJson(dynamic decodedJson) => Down4TX(
        maker: decodedJson["mk"],
        versionNo: decodedJson["vn"],
        nLockTime: decodedJson["nl"],
        txID: TXID.fromHex(decodedJson["id"]),
        txsIn: List<dynamic>.from(decodedJson["ti"])
            .map((encodedIn) => Down4TXIN.fromJson(jsonDecode(encodedIn)))
            .toList(),
        txsOut: List<dynamic>.from(decodedJson["ti"])
            .map((encodedOut) => Down4TXOUT.fromJson(jsonDecode(encodedOut)))
            .toList(),
      );

  List<int> get fullRawData => [
        ...versionNo.data,
        ...inCounter.data,
        ...txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
        ...outCounter.data,
        ...txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
        ...nLockTime.data,
      ];

  List<int> get sigAllRawData => [
        ...versionNo.data,
        ...inCounter.data,
        ...txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.sigData]),
        ...outCounter.data,
        ...txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
        ...nLockTime.data,
      ];

  List<int> sigSingleData(int nIn) => [
        ...versionNo.data,
        ...inCounter.data,
        ...txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.sigData]),
        ...outCounter.data,
        ...txsOut[nIn].asData,
        ...nLockTime.data,
      ];

  List<TXID> get txidDeps => txsIn.fold(<TXID>[], (deps, txin) {
        if (txin.dependance != null) {
          return deps..add(txin.dependance!);
        } else {
          return deps;
        }
      });

  TXID txid() =>
      txID = TXID.fromBigEndian(sha256sha256(fullRawData.asUint8List()));

  String get fullRawHex => hex.encode(fullRawData);

  Map<String, dynamic> toJson() => {
        "mk": maker,
        "vn": versionNo.asInt,
        "nl": nLockTime.asInt,
        "id": txID!.asHex,
        "ti": txsIn.map((txin) => txin.toJson()).toList(),
        "to": txsOut.map((txout) => txout.toJson()).toList(),
      };

  String get asQrData => jsonEncode(toJson());

  @override
  int get hashCode => BigInt.parse(txID!.asHex, radix: 16).hashCode;

  @override
  bool operator ==(other) => other is Down4TX && other.txID == txID;
}

class TxResponse {
  final TXID id;
  final bool success;
  final String description;

  TxResponse({
    required String pID,
    required String pSuccess,
    required this.description,
  })  : id = TXID.fromBigEndianHex(pID),
        success = pSuccess == "success";

  factory TxResponse.fromJson(dynamic json) {
    return TxResponse(
      pID: json["txid"],
      pSuccess: json["returnResult"],
      description: json["resultDescription"],
    );
  }
}

class BatchResponse {
  List<TxResponse> responses;
  num failureCount;

  BatchResponse({required this.responses, required this.failureCount});

  factory BatchResponse.fromJson(dynamic json) {
    return BatchResponse(
      failureCount: json["failureCount"],
      responses: List<dynamic>.from(json["txs"])
          .map((txr) => TxResponse.fromJson(txr))
          .toList(),
    );
  }
}

void main() async {
  Future<List<Down4TXOUT>?> getUtxos(
    String b58Address, [
    String network = "main",
  ]) async {
    final url = Uri.parse(
      "https://api.whatsonchain.com/v1/bsv/$network/address/$b58Address/unspent",
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

  var pair = ec.ECPair.fromWIF(
    "L5ki3jzwFDiz8MjExqAFnEa4cvv3BHwJdCe84QLpcDnMaMzkLcuM",
  );

  var address = _makeAddress(pair.publicKey).toBase58();

  var utxos = await getUtxos(address);
  if (utxos == null) return;

  final inSats = utxos.fold<Sats>(Sats(0), (s, u) => s + u.sats);
  final inLen = utxos.length;
  final txSize = 4 + 4 + 9 + 9 + (148 * inLen) + (34 + 7);
  final minerFees = (txSize * SATS_PER_BYTE).ceil();
  final down4Fees = (minerFees / 2).ceil();
  final totalFees = down4Fees + minerFees;

  // Import from wif
}
