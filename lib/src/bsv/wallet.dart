import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:flutter_testproject/src/boxes.dart';
import '../data_objects.dart';
import '../down4_utility.dart';
import '../web_requests.dart' as r;
import 'dart:io' as io;
import 'utils.dart';
import 'types.dart';
import 'package:bs58/bs58.dart';

class Wallet {
  final Down4Keys _keys;
  Map<Identifier, Down4TXOUT> _utxos;
  Map<Identifier, Down4Payment> _payments;
  int _ix;

  Down4Keys get keys => _keys;

  int get balance => _utxos.values.fold(0, (bal, tx) => bal + tx.sats.asInt);

  Set<Down4Payment> get payments => _payments.values.toSet();

  Set<TXID> get uTXID => _payments.values
      .map((pay) => pay.txs.map((tx) => tx.txID!))
      .expand((txid) => txid)
      .toSet();

  Set<Down4TX> get unsettledTxs =>
      _payments.values.map((pay) => pay.txs).expand((tx) => tx).toSet();

  void settlementRoutine() {
    for (final payment in payments) {
      if (payment.lastConfirmations == 0) _trySettlement(payment);
    }
  }

  Future<void> _trySettlement(Down4Payment payment) async {
    final txsToSettle = payment.txs
        .where((tx) => tx.confirmations == 0)
        .toList(growable: false);

    final failedIndices = await r.broadcastTxs(txsToSettle);
    for (final i in failedIndices) {
      print("Failed to broadcast tx ID: ${payment.txs[i]}");
    }
  }

  Future<void> updateAllStatus() async {
    for (final payment in payments) {
      _updateStatus(payment);
    }
  }

  Future<void> _updateStatus(Down4Payment payment) async {
    final ids = payment.txs.map((e) => e.txID!.asHex).toList();

    final confirmations = await r.confirmations(ids);
    if (confirmations == null || confirmations.length != ids.length) {
      return null;
    }

    for (int i = 0; i < confirmations.length; i++) {
      _payments[payment.id]!.txs[i].confirmations = confirmations[i];
    }
    save();
  }

  // void paymentRoutine() {
  //   // clears space and make other routines faster
  //   // we can remove payment after the last tx has over 60 confirmations
  //   for (final payment in payments) {
  //     final confirmations = payment.txs.last.confirmations ?? 0;
  //     if (confirmations > 100) {
  //       _payments.remove(payment.id);
  //     } else if (confirmations == 0) {
  //       _trySettlement(payment);
  //     }
  //   }
  //   save();
  // }

  Wallet._({
    int? ix,
    Map<Identifier, Down4TXOUT>? utxos,
    Map<Identifier, Down4Payment>? payments,
    required Down4Keys keys,
  })  : _utxos = utxos ?? <Identifier, Down4TXOUT>{},
        _payments = payments ?? <Identifier, Down4Payment>{},
        _keys = keys,
        _ix = ix ?? -1;

  factory Wallet.fromSeed(Uint8List seed1, Uint8List seed2) {
    if (seed1.lengthInBytes < 32) throw 'invalid seed1 length';
    if (seed2.lengthInBytes < 32) throw 'invalid seed2 length';
    return Wallet._(keys: Down4Keys.fromRandom(seed1, seed2));
  }

  factory Wallet.fromJson(dynamic decodedJson) {
    return Wallet._(
      utxos: Map.from(decodedJson["utxos"])
          .map((key, value) => MapEntry(key, Down4TXOUT.fromJson(value))),
      payments: Map.from(decodedJson["payments"])
          .map((key, value) => MapEntry(key, Down4Payment.fromJson(value))),
      keys: Down4Keys.fromJson(decodedJson["keys"]),
      ix: decodedJson["ix"],
    );
  }

  Map<String, dynamic> toJson() => {
        "utxos": _utxos.map((key, val) => MapEntry(key, val.toJson())),
        "payments": _payments.map((key, val) => MapEntry(key, val.toJson())),
        "keys": _keys.toJson(),
        "ix": _ix,
      };

  Down4Payment? payUsers(List<Node> users, Node self, Sats amount) {
    final nUsers = users.length;
    final payPerUser = Sats((amount.asInt / nUsers).floor());

    // outs being script(25) + scriptLen(1) + sats(8) == 34
    final nOuts = nUsers + 2;
    final varOutSize = VarInt.fromInt(nOuts).data.length;
    // know size = nOuts(var) + outs(nOuts * 34) + version(4) + nSeq(4)
    var knownTxSize = varOutSize + (nOuts * 34) + 8;

    final inInfos = _unsignedIns(self, amount, knownTxSize);
    if (inInfos == null) return null;
    List<Down4TXIN> ins = inInfos[0];
    Sats minerFees = inInfos[1];
    Sats down4Fees = inInfos[2];
    Sats inSats = ins.fold(Sats(0), (tot, txin) => tot + txin.utxo.sats);

    // at this point, there is no reason for the payment to fail
    // except if a key derivation returns, and in that case, calling the
    // function again should solve the problem
    List<Down4TXOUT> outs = [];
    _ix = _ix + 1;
    final d4Secret = makeUint32(_ix) + utf8.encode(self.id);
    final d4Keys = DOWN4_NEUTER.derive(d4Secret);
    // except for here possibly? must be fucking rare tho
    if (d4Keys == null) return null;
    var d4out = Down4TXOUT(
      sats: down4Fees,
      secret: d4Secret,
      outIndex: outs.length,
      scriptPubKey: p2pkh(d4Keys.rawAddress),
    );
    outs.add(d4out);

    for (int i = 0; i < users.length; i++) {
      final userSecret = makeUint32(_ix) + utf8.encode(users[i].id);
      final userKeys = users[i].neuter!.derive(userSecret);
      if (userKeys == null) return null;
      var uOut = Down4TXOUT(
        sats: payPerUser,
        secret: userSecret,
        outIndex: outs.length,
        scriptPubKey: p2pkh(userKeys.rawAddress),
        receiver: users[i].id,
      );
      outs.add(uOut);
    }

    // change
    final change = inSats - down4Fees - minerFees - amount;
    if (change.asInt > 0) {
      final selfSecret = makeUint32(_ix);
      final selfKeys = keys.derive(selfSecret);
      if (selfKeys == null) return null;
      var changeOut = Down4TXOUT(
        sats: change,
        secret: selfSecret,
        outIndex: outs.length,
        scriptPubKey: p2pkh(selfKeys.rawAddress),
        receiver: self.id,
      );
      outs.add(changeOut);
    }

    var theTx = Down4TX(txsIn: ins, txsOut: outs);
    for (var i = 0; i < theTx.txsIn.length; i++) {
      final secret = theTx.txsIn[i].utxo.secret;
      if (secret == null) return null;

      final keysForSig = keys.derive(secret);
      if (keysForSig == null) return null;

      final scriptSig = p2pkhSig(keysForSig, theTx, i);
      if (scriptSig == null) return null;

      theTx.txsIn[i].script = scriptSig;
    }

    final theTxID = theTx.txid();
    for (var txout in theTx.txsOut) {
      txout.txid = theTxID;
    }

    return Down4Payment(_chainedTxs(theTx), true);
  }

  void parsePayment(Node self, Down4Payment pay) {
    final sortedTxs = topologicalSort(pay.txs);
    // if I'm right, we only care about utxos of the last TX
    var releventTx = sortedTxs.last;
    for (final utxo in releventTx.txsOut) {
      if (utxo.receiver == self.id) _utxos[utxo.id] = utxo;
    }
    for (final txin in releventTx.txsIn) {
      if (txin.spender == self.id) _utxos.remove(txin.utxo.id);
    }
    _payments[pay.id] = pay;
    _trySettlement(pay);
    save();
  }

  List<Down4TX> _chainedTxs(Down4TX from) {
    final unsettledIDs = uTXID;
    Set<Down4TX> deps = {from};
    List<Down4TX> cop;
    do {
      cop = List<Down4TX>.from(deps);
      var depIDs = cop.map((tx) => tx.txidDeps).expand((dep) => dep).toSet();
      for (final depID in depIDs) {
        if (unsettledIDs.contains(depID)) {
          deps.add(unsettledTxs.singleWhere((tx) => tx.txID == depID));
        }
      }
    } while (deps.length != cop.length);

    return cop.reversed.toList(growable: false);
  }

  Future<Down4Payment?> importMoney(String pkBase68, Node self) async {
    final rawKey = BigInt.parse(base58.decode(pkBase68).toHex(), radix: 16);

    final keys = Down4Keys.fromPrivateKey(rawKey);
    final address = testnetAddress(keys.rawCompressedPub).toBase58();
    final utxos = await getUtxos(address);
    if (utxos == null) return null;

    final availSats = utxos.fold<Sats>(Sats(0), (tot, utxo) => tot + utxo.sats);

    // outs(34*2) + nOut(1) + version(4) + nSeq(4) + nIn(var) + ins(148*nIn)
    final nIn = VarInt.fromInt(utxos.length);
    final txSize = (34 * 2) + 9 + (148 * utxos.length) + nIn.data.length;

    final minerFees = Sats((SATS_PER_BYTE * txSize).ceil());
    final down4Fees = Sats((minerFees.asInt * 1.2).ceil() + randomSats());
    final encaissement = availSats - minerFees - down4Fees;

    if (encaissement.asInt <= 0) return null;

    _ix = _ix + 1;
    final down4Secret = makeUint32(_ix) + utf8.encode(self.id);
    final down4Keys = DOWN4_NEUTER.derive(down4Secret);
    if (down4Keys == null) return null;
    var down4Out = Down4TXOUT(
      sats: down4Fees,
      secret: down4Secret,
      scriptPubKey: p2pkh(down4Keys.rawAddress),
      outIndex: 0,
    );

    final selfSecret = makeUint32(_ix);
    final selfKeys = self.neuter!.derive(selfSecret);
    if (selfKeys == null) return null;
    var selfOut = Down4TXOUT(
      receiver: self.id,
      sats: encaissement,
      secret: selfSecret,
      scriptPubKey: p2pkh(selfKeys.rawAddress),
      outIndex: 1,
    );

    List<Down4TXIN> ins = [];
    for (var utxo in utxos) {
      ins.add(Down4TXIN(utxo: utxo, spender: utxo.receiver));
    }

    var theTx = Down4TX(txsIn: ins, txsOut: [down4Out, selfOut]);

    for (var i = 0; i < theTx.txsIn.length; i++) {
      var scriptSig = p2pkhSig(keys, theTx, i);
      if (scriptSig == null) return null;
      theTx.txsIn[i].script = scriptSig;
    }

    final txid = theTx.txid();
    for (var txout in theTx.txsOut) {
      txout.txid = txid;
    }

    return Down4Payment([theTx], true);
  }

  List<dynamic>? _unsignedIns(Node self, Sats pay, int currentTxSize) {
    const inSize = 148;
    List<Down4TXIN> ins = [];
    var cumSize = currentTxSize;
    final randSats = randomSats();
    var currentMinerFees = (currentTxSize * SATS_PER_BYTE);
    var currentDown4Fees = (currentMinerFees * 1.2) + randSats;
    var accumulatedSats = Sats(0);
    var iUtxo = 0;
    for (final utxo in _utxos.values) {
      var txin = Down4TXIN(
        spender: self.id,
        utxo: utxo,
        sequenceNo: 0,
        dependance: uTXID.contains(utxo.txid) ? utxo.txid : null,
      );
      ins.add(txin);
      cumSize += inSize;
      iUtxo = iUtxo + 1;
      currentTxSize = VarInt.fromInt(iUtxo).data.length + cumSize;
      currentMinerFees = currentTxSize * SATS_PER_BYTE;
      currentDown4Fees = (currentMinerFees * 1.2) + randSats;

      accumulatedSats += utxo.sats;

      var minerFees = Sats(currentMinerFees.ceil());
      var down4Fees = Sats(currentDown4Fees.ceil());

      if (accumulatedSats > minerFees + pay + down4Fees) {
        return [ins, minerFees, down4Fees];
      }
    }
    return null;
  }

  // Down4Payment? payUsers(List<Node> targets, Node self, Sats amount) {
  //   final walletIndex = randomWalletIndex();
  //   var outs = _reqOuts(targets, self, amount, walletIndex);
  //   var inInfo = _unsignedIns(self, amount, targets.length + 2);
  //   if (inInfo == null) return null;
  //   List<Down4TXIN> txsIn = inInfo[0];
  //   Sats minerFees = inInfo[1];
  //   Sats down4Fees = inInfo[2];
  //   final inAmount = txsIn.fold<Sats>(Sats(0), (tot, tx) => tot + tx.sats!);
  //
  //   // add the change
  //   final changeAmount = inAmount - amount - minerFees - down4Fees;
  //   if (changeAmount.asInt > 0) {
  //     final changePubKey = self.neuter!.derive(walletIndex).publicKey;
  //     final changeAddress = checkAddress(changePubKey);
  //     outs.add(Down4TXOUT(
  //       sats: changeAmount,
  //       scriptPubKey: d4out(changeAddress, walletIndex),
  //       walletIndex: walletIndex,
  //       receiver: self.id,
  //       outIndex: outs.length,
  //     ));
  //   }
  //
  //   // add the relay tax
  //   final relayPubKey = DOWN4_NEUTER.derive(walletIndex).publicKey;
  //   final relayChangeAddress = checkAddress(relayPubKey);
  //   outs.add(Down4TXOUT(
  //     sats: down4Fees,
  //     scriptPubKey: d4out(relayChangeAddress, walletIndex),
  //     walletIndex: walletIndex,
  //     outIndex: outs.length,
  //   ));
  //
  //   // here we should have all the tx data necessary for signing
  //   var tx = Down4TX(txsIn: txsIn, maker: self.id, txsOut: outs);
  //   for (var i = 0; i < tx.txsIn.length; i++) {
  //     final derived = bip.derive(tx.txsIn[i].walletIndex!);
  //     final sigData = tx.sigData(i);
  //     if (sigData == null) return null;
  //     final Uint8List sig = derived.sign(sigData.asUint8List());
  //     final r = sig.sublist(0, 32);
  //     final s = sig.sublist(32, 64);
  //     const len = 1 + 1 + 32 + 1 + 1 + 32;
  //     final der = [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
  //     final unlockScript = [...der, 0x41, ...derived.publicKey];
  //
  //     tx.txsIn[i].script = unlockScript;
  //   }
  //   final txid = tx.txid();
  //   for (var txout in tx.txsOut) {
  //     txout.txid = txid;
  //     if (txout.receiver == self.id) _utxos.add(txout);
  //   }
  //   _unsettledTxs.add(tx);
  //   final chain = _chainedTxs([tx]);
  //   return Down4Payment(chain, true);
  // }

  // Down4Payment? payToAnyone(Node self, Sats amount) {
  //   if (amount.asInt > balance) return null;
  //   // for payToAnyone, we need a perfect input Amount for the tx we are giving
  //   // because we can't use change, since we can't know what the transaction ID will be.
  //   // Using change would require the unknown receiver to calculate the TXID and send back
  //   // the tx to us, which we don't want. We simply want to give the utxos and be done with.
  //   // The solution is to first make a tx that will output the perfect amount, and use that output
  //   Down4TX firstTx;
  //   var firstTxsIn = <Down4TXIN>[];
  //   var firstTxsOut = <Down4TXOUT>[];
  //   final wIdx = randomWalletIndex();
  //   // we want our utxo to be amount + minerfees + down4fees
  //   // our final tx should be exactly 1 input and 2 outputs of p2pkh script
  //   const lastTxSize = 4 + 1 + 148 + 1 + 34 + 34 + 4;
  //   final lastTxMinerFees = Sats((SATS_PER_BYTE * lastTxSize).ceil());
  //   final lastTxDown4Fees = Sats((lastTxMinerFees.asInt / 2).ceil());
  //   final desiredUtxoAmount = amount + lastTxMinerFees + lastTxDown4Fees;
  //
  //   // the true amount needed is the first TX fees + desiredUtxoAmount
  //   // so firstTXMinerFees + firstTXDown4Fees + desiredUtxoAmount
  //   // the first two elements need to be calculated dynamically
  //   // first tx is expect 3 outputs (change, down4fees, desiredUtxo)
  //   // and can have n inputs
  //
  //   // _sortUtxos(); // feel like not doing this would yield me more money
  //   var count = Sats(0);
  //   // three outs (34 * 3), vNo (4), nLock (4), outCount (1), inCount(1 to 9)
  //   var firstTxMinerFees =
  //   Sats((SATS_PER_BYTE * (34 * 3)).ceil() + 4 + 4 + 1 + 9);
  //   var firstTxDown4Fees = Sats((firstTxMinerFees.asInt / 2).ceil());
  //   var firstTxTotalReqs =
  //       firstTxMinerFees + firstTxDown4Fees + desiredUtxoAmount;
  //   for (int i = 0; i < _utxos.length; i++) {
  //     firstTxsIn.add(
  //       Down4TXIN(
  //         spender: self.id,
  //         walletIndex: _utxos[i].walletIndex,
  //         sats: _utxos[i].sats,
  //         spentFrom: _utxos[i].txid!,
  //         outIndex: _utxos[i].outIndex!,
  //         sequenceNo: 0,
  //         dependance: uTXID.contains(_utxos[i].txid!) ? _utxos[i].txid : null,
  //       ),
  //     );
  //
  //     firstTxMinerFees += Sats((SATS_PER_BYTE * 148).ceil());
  //     firstTxDown4Fees = Sats((firstTxMinerFees.asInt / 2).ceil());
  //     firstTxTotalReqs =
  //         firstTxMinerFees + firstTxDown4Fees + desiredUtxoAmount;
  //     count += _utxos[i].sats;
  //
  //     if (count >= firstTxTotalReqs) {
  //       break;
  //     } else if (i == _utxos.length - 1) {
  //       return null;
  //     }
  //   }
  //
  //   // First tx change out
  //   final changeAmount = count - firstTxMinerFees;
  //   final changeAddr = checkAddress(self.neuter!.derive(wIdx).publicKey);
  //   var changeOut = Down4TXOUT(
  //     receiver: self.id,
  //     sats: changeAmount,
  //     scriptPubKey: d4out(changeAddr, wIdx),
  //     walletIndex: wIdx,
  //     outIndex: 0,
  //   );
  //   firstTxsOut.add(changeOut);
  //
  //   // First tx down4fees
  //   final down4feeAddr =
  //   checkAddress(DOWN4_NEUTER.derive(wIdx).publicKey);
  //   var taxOut = Down4TXOUT(
  //     sats: firstTxDown4Fees,
  //     scriptPubKey: d4out(down4feeAddr, wIdx),
  //     walletIndex: wIdx,
  //     outIndex: 1,
  //   );
  //   firstTxsOut.add(taxOut);
  //
  //   // finally, the desired output we want to spend in the first place
  //   // can re-use the changeAddr for that one
  //   var desiredOut = Down4TXOUT(
  //     receiver: self.id,
  //     sats: desiredUtxoAmount,
  //     scriptPubKey: d4out(changeAddr, wIdx),
  //     walletIndex: wIdx,
  //     outIndex: 2,
  //   );
  //   firstTxsOut.add(desiredOut);
  //
  //   // now we must sign and terminate this tx
  //   // we use SIG_HASH_ALL for this one, it's immutable
  //   firstTx = Down4TX(txsIn: firstTxsIn, txsOut: firstTxsOut, maker: self.id);
  //   for (var i = 0; i < firstTx.txsIn.length; i++) {
  //     final derived = bip.derive(firstTx.txsIn[i].walletIndex!);
  //     final txData = firstTx.sigData(i, SIG.ALL);
  //     if (txData == null) return null;
  //     final Uint8List sig = derived.sign(txData.asUint8List());
  //     final r = sig.sublist(0, 32);
  //     final s = sig.sublist(32, 64);
  //     const len = 1 + 1 + 32 + 1 + 1 + 32;
  //     final der = [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
  //     final unlockScript = [...der, 0x41, ...derived.publicKey];
  //
  //     firstTx.txsIn[i].script = unlockScript;
  //   }
  //   final firstTxID = firstTx.txid();
  //   for (var txOut in firstTx.txsOut) {
  //     txOut.txid = firstTxID;
  //     if (txOut.receiver == self.id && txOut.walletIndex != 2) {
  //       _utxos.add(txOut);
  //     }
  //   }
  //
  //   Down4TX lastTx;
  //   // so as we already know, this lastTx has 1 perfect input and 2 outputs
  //   var lastOuts = <Down4TXOUT>[];
  //   var lastIns = <Down4TXIN>[];
  //
  //   var lastTaxOut = Down4TXOUT(
  //     sats: lastTxDown4Fees,
  //     scriptPubKey: d4out(down4feeAddr, wIdx),
  //     walletIndex: wIdx,
  //     outIndex: 0,
  //   );
  //   lastOuts.add(lastTaxOut);
  //
  //   var incompleteOut = Down4TXOUT(
  //     sats: amount,
  //     walletIndex: wIdx,
  //     outIndex: 1,
  //   );
  //   lastOuts.add(incompleteOut);
  //
  //   var lastPerfectIn = Down4TXIN(
  //     spentFrom: desiredOut.txid!,
  //     walletIndex: desiredOut.walletIndex,
  //     outIndex: desiredOut.outIndex!,
  //     sequenceNo: 0,
  //     dependance: desiredOut.txid,
  //     sats: desiredOut.sats,
  //   );
  //   lastIns.add(lastPerfectIn);
  //
  //   lastTx = Down4TX(txsIn: lastIns, txsOut: lastOuts, maker: self.id);
  //
  //   // now we sign with either SIGHASH_SINGLE or SIGHASH_SINGLE|ANYONECANPAY
  //   final derived = bip.derive(lastPerfectIn.walletIndex!);
  //   final sigData = lastTx.sigData(0, SIG.SINGLE);
  //   if (sigData == null) return null;
  //   final Uint8List sig = derived.sign(sigData.asUint8List());
  //   final r = sig.sublist(0, 32);
  //   final s = sig.sublist(32, 64);
  //   const len = 1 + 1 + 32 + 1 + 1 + 32;
  //   final der = [0x30, len, 0x02, r.length, ...r, 0x02, s.length, ...s];
  //   final unlockScript = [...der, 0x43, ...derived.publicKey];
  //
  //   lastTx.txsIn.first.script = unlockScript;
  //   _unsettledTxs.add(firstTx);
  //
  //   final chain = _chainedTxs([firstTx]);
  //   return Down4Payment([...chain, lastTx], false);
  // }

  // Future<Down4Payment?> importMoney(Node self, String base58) async {
  //   ECPair pair;
  //   final key = bs58.decode(base58);
  //   if (key.lengthInBytes > 32) {
  //     // is WIF
  //     pair = ECPair.fromWIF(base58);
  //   } else {
  //     // is raw privateKey
  //     pair = ECPair.fromPrivateKey(key);
  //   }
  //   final pk = pair.privateKey;
  //   if (pk == null) return null;
  //
  //   final wIdx = deterministicWalletIndex();
  //   final down4Address =
  //   checkAddress(DOWN4_NEUTER.derive(wIdx).publicKey);
  //   final myAddress = checkAddress(self.neuter!.derive(wIdx).publicKey);
  //
  //   final importAddress = checkAddress(pair.publicKey).toBase58();
  //
  //   var utxos = await getUtxos(importAddress);
  //   if (utxos == null) return null;
  //
  //   final inSats = utxos.fold<Sats>(Sats(0), (s, u) => s + u.sats);
  //   final inCount = utxos.length;
  //
  //   final inCount_ = VarInt.fromInt(utxos.length);
  //   final outCount_ = VarInt.fromInt(2);
  //
  //   final txSize_ = inCount_.data.length +
  //       outCount_.data.length +
  //       4 +
  //       4 +
  //       (148 * inCount) +
  //       (34 * 2);
  //
  //   final txSize = 4 + 4 + 9 + 9 + (148 * inCount) + (34 * 2);
  //   final minerFees = Sats((txSize_ * SATS_PER_BYTE).ceil());
  //   final down4Fees = Sats((minerFees.asInt / 2).ceil());
  //   final totalFees = down4Fees + minerFees;
  //
  //   final myGets = inSats - totalFees;
  //
  //   var txsIn = <Down4TXIN>[];
  //   for (final utxo in utxos) {
  //     txsIn.add(Down4TXIN.fromP2PKH(utxo));
  //   }
  //
  //   var txsOut = <Down4TXOUT>[
  //     Down4TXOUT(
  //       sats: down4Fees,
  //       scriptPubKey: p2pkh(down4Address),
  //       outIndex: 0,
  //     ),
  //     Down4TXOUT(
  //       receiver: self.id,
  //       sats: myGets,
  //       scriptPubKey: p2pkh(myAddress),
  //       outIndex: 1,
  //     ),
  //   ];
  //
  //   var tx = Down4TX(txsIn: txsIn, txsOut: txsOut);
  //   final txID = tx.txid();
  //
  //   for (var i = 0; i < tx.txsIn.length; i++) {
  //     final unlockScript = p2pkhSig(pk, tx, i);
  //     if (unlockScript == null) return null;
  //     tx.txsIn[i].script = unlockScript;
  //   }
  //
  //   for (var txOut in tx.txsOut) {
  //     txOut.txid = txID;
  //   }
  //
  //   return Down4Payment([tx], true);
  // }
}

void main() {
  print("What the fuck is going on");
  var f = io.File("C:\\Users\\coton\\Desktop\\jeff.txt");

  var pkHex = f.readAsStringSync();
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
