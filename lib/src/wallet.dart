import 'data_objects.dart';
import 'package:dartsv/dartsv.dart';
import 'package:dartsv/src/transaction/transaction_input.dart';
import 'web_requests.dart' as r;
import 'dart:math' as math;

class Down4UTXO {
  final TransactionOutput txout;
  final int walletIndex;
  final List<Down4UTXO>? chain;
  bool settled;
  Down4UTXO({
    required this.txout,
    required this.walletIndex,
    this.settled = false,
    this.chain,
  });

  bool broadcast() {
    // TODO
    return settled = true;
  }
}

class Wallet {
  String mnemonic;
  HDPrivateKey down4priv, master;
  int upperIndex, upperChange, lowerIndex, lowerChange;
  BigInt _balance = BigInt.from(0);
  List<Down4UTXO> _utxos = [];

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
      master: HDPrivateKey.fromXpriv(decodedJson["master"]),
      down4priv: HDPrivateKey.fromXpriv(decodedJson["down4priv"]),
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

  Future<String?> pay(
    List<Node> targets,
    Node self,
    BigInt sats,
    bool split,
  ) async {
    final bigIntLen = BigInt.from(targets.length);
    final totalSats = split ? sats : sats * bigIntLen;
    var tx = _inputReadyTx(totalSats);
    final walletIndex = math.Random().nextInt(1 << 32);
    for (var target in targets) {
      final pubKey = target.neuter!.deriveChildNumber(walletIndex).keyBuffer;
      final address = Address.fromCompressedPubKey(pubKey, NetworkType.MAIN);
      tx?.spendTo(
        address,
        BigInt.from(totalSats / bigIntLen),
        scriptBuilder: P2PKHLockBuilder(address),
      );
    }
    final changePub = self.neuter!.deriveChildNumber(walletIndex).keyBuffer;
    final change = Address.fromCompressedPubKey(changePub, NetworkType.MAIN);
    tx?.sendChangeTo(change, scriptBuilder: P2PKHLockBuilder(change));
    return tx?.serialize();
  }

  void bill(List<Identifier> ids, int sats, bool split) {
    // TODO
  }

  Transaction? _inputReadyTx(BigInt requiredSats) {
    var transaction = Transaction();
    var sats = BigInt.zero;
    for (var i = 0; i < _utxos.length; i++) {
      final derived = down4priv.deriveChildNumber(_utxos[i].walletIndex);
      var unlockBuilder = P2PKHUnlockBuilder(derived.publicKey);
      transaction.spendFromOutput(
        _utxos[i].txout,
        Transaction.NLOCKTIME_MAX_VALUE,
        scriptBuilder: unlockBuilder,
      );
      transaction.signInput(i, derived.privateKey);
      sats += _utxos[i].txout.satoshis;
      if (sats >= requiredSats) {
        return transaction;
      }
    }
    return null;
  }

  BigInt get balance => _utxos
      .map((e) => e.txout.satoshis)
      .reduce((value, element) => value + element);
}
