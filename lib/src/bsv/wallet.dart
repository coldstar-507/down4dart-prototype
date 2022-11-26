import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
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

  Down4Payment? payUsers(List<User> users, User self, Sats amount) {
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
      isFee: true,
      sats: down4Fees,
      secret: d4Secret,
      outIndex: outs.length,
      scriptPubKey: p2pkh(d4Keys.rawAddress),
    );
    outs.add(d4out);

    for (int i = 0; i < users.length; i++) {
      final userSecret = makeUint32(_ix) + utf8.encode(users[i].id);
      final userKeys = users[i].neuter.derive(userSecret);
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
        isChange: true,
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

  void parsePayment(User self, Down4Payment pay) {
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

  Future<Down4Payment?> importMoney(String pkBase68, User self) async {
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
      isFee: true,
      sats: down4Fees,
      secret: down4Secret,
      scriptPubKey: p2pkh(down4Keys.rawAddress),
      outIndex: 0,
    );

    final selfSecret = makeUint32(_ix);
    final selfKeys = self.neuter.derive(selfSecret);
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

  List<dynamic>? _unsignedIns(User self, Sats pay, int currentTxSize) {
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
}

void main() {
  var f = io.File("C:\\Users\\coton\\Desktop\\jeff.txt");
  var pkHex = f.readAsStringSync();

  // final seed1 = safeSeed(32);
  // final seed2 = safeSeed(32);

  // var pair0_ = Down4Keys.fromRandom(seed1, seed2);

  // final f = io.File("/home/scott/jeff.txt");
  // final pkHex = f.readAsStringSync();

  // io.File("/home/scott/jeff.txt").writeAsString(pair0_.privKeyHex!);

  final pair0 = Down4Keys.fromPrivateKey(BigInt.parse(pkHex, radix: 16));
  final pair1 = pair0.derive(makeUint32(1))!;
  final pair2 = pair0.derive(makeUint32(2))!;
  final pair3 = pair0.derive(makeUint32(3))!;

  print("TEST0: ${testnetAddress(pair0.rawCompressedPub).toBase58()}");
  print("TEST1: ${testnetAddress(pair1.rawCompressedPub).toBase58()}");
  print("TEST2: ${testnetAddress(pair2.rawCompressedPub).toBase58()}");
  print("TEST3: ${testnetAddress(pair3.rawCompressedPub).toBase58()}");

  print("TEST0PK: ${pair0.privKeyBase58}");
  print("TEST1PK: ${pair1.privKeyBase58}");
  print("TEST2PK: ${pair2.privKeyBase58}");
  print("TEST3PK: ${pair3.privKeyBase58}");
}
