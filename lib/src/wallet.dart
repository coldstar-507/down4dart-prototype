import 'dart:typed_data';

import 'package:flutter_testproject/src/kernel.dart';

import 'data_objects.dart';
// import 'package:dartsv/dartsv.dart';
import 'package:bsv/bsv.dart' as bsv;
import 'web_requests.dart' as r;
import 'dart:math' as math;
import 'package:tuple/tuple.dart';

const satsPerByte = 0.05;

class Down4UTXO {
  final Identifier receiver;
  final bsv.TxOut txout;
  final int walletIndex, outputIndex;
  List<int>? hashBuf;
  Down4UTXO({
    required this.outputIndex,
    required this.receiver,
    required this.txout,
    required this.walletIndex,
    this.hashBuf,
  });
}

class Down4STXI {
  final Identifier spender;
  final bsv.TxIn txin;
  final int walletIndex;
  Down4STXI({
    required this.spender,
    required this.txin,
    required this.walletIndex,
  });
}

class Down4TX {
  List<Down4UTXO> utxos;
  List<Down4STXI> stxis;
  List<int> hashBuf;
  bool settled;
  List<Down4TX> offLineDependance;
  Down4TX({
    required this.utxos,
    required this.stxis,
    required this.hashBuf,
    this.settled = false,
    required this.offLineDependance,
  });

  bool broadcast() {
    //TODO
    return settled = true;
  }

  // List<int> generateHashBuf() {}
}

class Wallet {
  String mnemonic;
  bsv.Bip32 down4priv, master;
  // HDPrivateKey down4priv, master;
  int upperIndex, upperChange, lowerIndex, lowerChange;
  List<Down4UTXO> _utxos = [];
  List<Down4TX> _unsettledTxs = [];

  Wallet({
    required this.mnemonic,
    required this.master,
    required this.down4priv,
    required this.lowerIndex,
    required this.upperIndex,
    required this.lowerChange,
    required this.upperChange,
  });

  factory Wallet.fromJson(Map<String, dynamic> decodedJson) {
    return Wallet(
      mnemonic: decodedJson["mnemonic"],
      master: bsv.Bip32.Mainnet().fromString(decodedJson["master"]),
      down4priv: bsv.Bip32.Mainnet().fromString(decodedJson["down4priv"]),
      lowerIndex: decodedJson["lowerindex"],
      upperIndex: decodedJson["upperindex"],
      lowerChange: decodedJson["lowerchange"],
      upperChange: decodedJson["upperchange"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "mnemonic": mnemonic,
      "master": master.toString(),
      "down4priv": down4priv.toString(),
      "lowerindex": lowerIndex,
      "upperindex": upperIndex,
      "lowerchange": lowerChange,
      "upperchange": upperChange,
    };
  }

  Future<Down4TX?> pay(List<Node> targets, Node self, bsv.BigIntX sats) async {
    // final valueForOneTarget = sats.div(bsv.BigIntX.fromNum(targets.length));
    // // P2PKH outputs are on average 34 bytes
    // // P2PKH inputs are on average 147.5
    // // + 4 + (1 -- 9) + (1 -- 9) + 4
    // final nOut = targets.length + 1;
    // final outFees = bsv.BigIntX.fromNum(34 * nOut * satsPerByte);
    // var t = _inputReadyTx(outFees.add(sats), self);
    // if (t == null) return null;
    // var tx = t.item1;
    // final d4stxins = t.item2;
    // final extraSats = t.item3;
    // final unsettledTxDependance = t.item4;

    // var d4utxos = <Down4UTXO>[];
    // final walletIndex = math.Random().nextInt(1 << 32);
    // for (var i = 0; i < targets.length; i++) {
    //   final pubK = targets[i].neuter?.deriveChild(walletIndex).pubKey;
    //   final address = bsv.Address.fromPubKey(pubK!);
    //   final script = bsv.Script.fromPubKeyHash(address.hashBuf!.asUint8List());
    //   var output = bsv.TxOut.fromProperties(
    //     valueBn: sats.div(bsv.BigIntX.fromNum(targets.length)),
    //     script: script,
    //   );

    //   tx.txOuts!.add(output);

    //   d4utxos.add(Down4UTXO(
    //     receiver: targets[i].id,
    //     txout: output,
    //     walletIndex: walletIndex,
    //     outputIndex: i,
    //   ));
    // }

    // if (extraSats.gt(bsv.BigIntX.zero)) {
    //   final changePub = self.neuter?.deriveChild(walletIndex).pubKey;
    //   final changeAddr = bsv.Address.fromPubKey(changePub!);
    //   final changeOut = bsv.TxOut.fromProperties(
    //     valueBn: extraSats,
    //     script: bsv.Script.fromPubKeyHash(changeAddr.hashBuf!.asUint8List()),
    //   );
    //   d4utxos.add(Down4UTXO(
    //       outputIndex: targets.length,
    //       receiver: self.id,
    //       txout: changeOut,
    //       walletIndex: walletIndex));
    // }

    // return Down4TX(
    //   utxos: d4utxos,
    //   stxis: d4stxins,
    //   hashBuf: tx.hash().data,
    //   offLineDependance: unsettledTxDependance,
    // );
  }

  void bill(List<Identifier> ids, int sats, bool split) {
    // TODO
  }

  Tuple3<List<Down4STXI>, bsv.BigIntX, List<List<int>>>? _inputReadyTx(
    final bsv.BigIntX pay,
    Node self,
  ) {
    // var requiredSats = pay;
    // var sats = bsv.BigIntX.zero;
    // var d4txins = <Down4STXI>[];
    // var unsettledTxDepedance = <List<int>>[];
    // final unsettledTxIDs = _unsettledTxs.map((e) => e.hashBuf).toList();
    // for (var i = 0; i < _utxos.length; i++) {
    //   // get a utxo and it's targeted keypair
    //   final utxo = _utxos[i];
    //   final derived = down4priv.deriveChild(utxo.walletIndex);

    //   var txin = bsv.TxIn().fromPubKeyHashTxOut(
    //     txOut: utxo.txout,
    //     txHashBuf: utxo.hashBuf,
    //     txOutNum: utxo.outputIndex,
    //     pubKey: derived.pubKey,
    //   );


    //   var scriptSig = bsv.Script().writeBuffer(buf)
    //   // add it to a transaction
    //   txb.inputFromPubKeyHash(
    //     txHashBuf: utxo.hashBuf,
    //     txOutNum: utxo.outputIndex,
    //     txOut: utxo.txout,
    //     pubKey: derived.pubKey,
    //   );
    //   // check if utxo is part of an unsettled tx
    //   // those utxo are allowed for offline transactions
    //   // we must track them though, so we can eventually settle them all
    //   if (unsettledTxIDs.contains(utxo.hashBuf) &&
    //       !unsettledTxDepedance.contains(utxo.hashBuf)) {
    //     unsettledTxDepedance.add(utxo.hashBuf!);
    //   }
    //   // sign the transaction
    //   txb.signTxIn(nIn: i, keyPair: bsv.KeyPair.fromPrivKey(derived.privKey!));
    //   // add it to down4 inputs
    //   d4txins.add(Down4STXI(
    //     spender: self.id,
    //     txin: txb.txIns[i],
    //     walletIndex: utxo.walletIndex,
    //   ));
    //   // calculate the newly added fees by the input
    //   final txInSize = txb.txIns[i].toBuffer().length;
    //   final inputFee = bsv.BigIntX.fromNum((txInSize * satsPerByte).ceil());

    //   // calculate the new required sats for a succesful transaction
    //   requiredSats = requiredSats.add(inputFee);
    //   // add utxo sats to spending sats
    //   sats = sats.add(utxo.txout.valueBn!);
    //   // if we have enough, return the transaction, d4txins, extraSats
    //   if (sats.geq(requiredSats)) {
    //     final extraSats = sats.sub(requiredSats);
    //     return Tuple3(d4txins, extraSats, unsettledTxDepedance);
    //   }
    // }
    // return null;
  }

  // Transaction? _inputReadyTx(BigInt requiredSats) {
  //   var transaction = Transaction();
  //   var sats = BigInt.zero;
  //   for (var i = 0; i < _utxos.length; i++) {
  //     final derived = down4priv.deriveChildNumber(_utxos[i].walletIndex);
  //     var unlockBuilder = P2PKHUnlockBuilder(derived.publicKey);
  //     transaction.spendFromOutput(
  //       _utxos[i].txout,
  //       Transaction.NLOCKTIME_MAX_VALUE,
  //       scriptBuilder: unlockBuilder,
  //     );
  //     transaction.signInput(i, derived.privateKey);
  //     sats += _utxos[i].txout.satoshis;
  //     if (sats >= requiredSats) {
  //       return transaction;
  //     }
  //   }
  //   return null;
  // }

  bsv.BigIntX get balance => _utxos
      .map((e) => e.txout.valueBn)
      .reduce((value, element) => value!.add(element!))!;
}
