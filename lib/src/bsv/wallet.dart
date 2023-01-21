import 'dart:convert';
import 'dart:typed_data';
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
  Map<Identifier, bool> _spent;
  int _ix;

  Down4Keys get neuter => _keys.neutered();

  // Down4Keys get keys => _keys;

  // Map<Identifier, Down4TXOUT> get utxos => _utxos;

  int get balance => _utxos.values.fold(0, (bal, tx) => bal + tx.sats.asInt);

  Set<Down4Payment> get payments => _payments.values.toSet();

  Set<Down4TX> get unsettledTxs => _payments.values
      .map((pay) => pay.txs.where((tx) => tx.confirmations == 0))
      .expand((tx) => tx)
      .toSet();

  Set<TXID> get uTXID => unsettledTxs.map((ustx) => ustx.txID).toSet();

  void settlementRoutine() {
    for (final payment in payments) {
      if (payment.lastConfirmations == 0) _trySettlement(payment);
    }
  }

  Future<void> updateAllStatus() async {
    for (final payment in payments) {
      if (payment.lastConfirmations < 100) _updateStatus(payment);
    }
  }

  void printWalletInfo() {
    for (final p in _payments.entries) {
      print("============PAYMENT============");
      print("""
      id           = ${p.key}
      lastTxID     = ${p.value.txs.last.txID.asHex}
      message      = ${p.value.textNote}
      lasTX secret = ${p.value.txs.last.down4Secret}
      """);
      print("============TXIN===========");
      for (final txin in p.value.txs.last.txsIn) {
        print("""
        spender = ${txin.spender}
        outIx   = ${txin.utxoIndex.asInt}
        outId   = ${txin.utxoTXID.asHex}
        """);
      }
      print("============UTXO============");
      for (final utxo in p.value.txs.last.txsOut) {
        print("""
        outIx    = ${utxo.outIndex} 
        sats     = ${utxo.sats.asInt} ${utxo.sats.data}
        txid     = ${utxo.txid!.asHex}
        id       = ${utxo.id}
        receiver = ${utxo.receiver}
        secret   = ${utxo.secret}
        """);
      }
    }
  }

  // void paymentRoutine() {
  //   // clears space and make other routines faster
  //   // we can remove payment after the last tx has over 60 confirmations
  //   for (final payment in payments) {
  //     final confirmations = payment.txs.last.confirmations;
  //     if (confirmations > 60) {
  //       _payments.remove(payment.id);
  //     } else if (confirmations == 0) {
  //       _trySettlement(payment);
  //     }
  //   }
  // }

  Down4Payment? payPeople({
    required List<Person> people,
    required Identifier selfID,
    required Sats amount,
    String textNote = "",
  }) {
    final nPeople = people.length;
    final payPerPerson = Sats((amount.asInt / nPeople).floor());

    // outs being script(25) + scriptLen(1) + sats(8) == 34
    final nOuts = nPeople + 2;
    final varOutSize = VarInt.fromInt(nOuts).data.length;
    // know size = nOuts(var) + outs(nOuts * 34) + version(4) + nSeq(4)
    var knownTxSize = varOutSize + (nOuts * 34) + 8;

    final inInfos = _unsignedIns(selfID, amount, knownTxSize);
    if (inInfos == null) return null;
    List<Down4TXIN> ins = inInfos[0];
    Sats minerFees = inInfos[1];
    Sats down4Fees = inInfos[2];
    Sats inSats = ins.fold(
      Sats(0),
      (tot, txin) => tot + _utxos[txin.utxoID]!.sats,
    );

    // at this point, there is no reason for the payment to fail
    // except if a key derivation returns, and in that case, calling the
    // function again should solve the problem
    List<Down4TXOUT> outs = [];
    _ix = _ix + 1;
    // the goal here is simply having a unique id everytime
    final txSecret = makeUint32(_ix) + utf8.encode(selfID);
    final d4Keys = DOWN4_NEUTER.derive(txSecret);
    // except for here possibly? must be fucking rare tho
    if (d4Keys == null) return null;
    var d4out = Down4TXOUT(
      isFee: true,
      sats: down4Fees,
      scriptPubKey: p2pkh(d4Keys.rawAddress),
    );
    outs.add(d4out);

    for (int i = 0; i < people.length; i++) {
      final userKeys = people[i].neuter.derive(txSecret);
      if (userKeys == null) return null;
      var uOut = Down4TXOUT(
        sats: payPerPerson,
        scriptPubKey: p2pkh(userKeys.rawAddress),
        receiver: people[i].id,
      );
      outs.add(uOut);
    }

    // change
    final change = inSats - down4Fees - minerFees - amount;
    if (change.asInt > 0) {
      final selfKeys = _keys.derive(txSecret);
      if (selfKeys == null) return null;
      var changeOut = Down4TXOUT(
        isChange: true,
        sats: change,
        scriptPubKey: p2pkh(selfKeys.rawAddress),
        receiver: selfID,
      );
      outs.add(changeOut);
    }

    for (var i = 0; i < ins.length; i++) {
      final spentUtxo = _utxos[ins[i].utxoID];
      if (spentUtxo == null) return null;

      final utxoSecret = spentUtxo.secret;
      if (utxoSecret == null) return null;

      final sData = sigData(txsIn: ins, txsOut: outs, nIn: i, utxo: spentUtxo);
      if (sData == null) return null;

      final keysForSig = _keys.derive(utxoSecret);
      if (keysForSig == null) return null;

      final scriptSig = p2pkhSig(keys: keysForSig, sigData: sData);
      if (scriptSig == null) return null;

      ins[i].script = scriptSig;
      _spent[spentUtxo.id] = true;
    }

    final theTx = Down4TX(down4Secret: txSecret, txsIn: ins, txsOut: outs);

    return Down4Payment(_chainedTxs(theTx), true, textNote: textNote);
  }

  void parsePayment(Identifier selfID, Down4Payment pay) {
    for (final tx in pay.txs) {
      tx.writeTxInfosToUTXOs();
    }
    for (final utxo in pay.txs.last.txsOut) {
      final spent = _spent[utxo.id] ?? false;
      if (utxo.receiver == selfID && !spent) _utxos[utxo.id] = utxo;
    }
    for (final txin in pay.txs.last.txsIn) {
      if (txin.spender == selfID) _utxos.remove(txin.utxoID);
    }
    _payments[pay.id] = pay;
    _trySettlement(pay);
  }

  Future<Down4Payment?> importMoney(String pkBase68, Identifier selfID) async {
    final rawKey = BigInt.parse(base58.decode(pkBase68).toHex(), radix: 16);

    final importedKeys = Down4Keys.fromPrivateKey(rawKey);
    final importedAddress = testnetAddress(importedKeys.rawCompressedPub);
    final fetchedUtxos = await getUtxos(importedAddress.toBase58());
    if (fetchedUtxos == null) return null;

    final availSats =
        fetchedUtxos.fold<Sats>(Sats(0), (tot, utxo) => tot + utxo.sats);

    // outs(34*2) + nOut(1) + version(4) + nSeq(4) + nIn(var) + ins(148*nIn)
    final nIn = VarInt.fromInt(fetchedUtxos.length);
    final txSize = (34 * 2) + 9 + (148 * fetchedUtxos.length) + nIn.data.length;

    final minerFees = Sats((SATS_PER_BYTE * txSize).ceil());
    final down4Fees = Sats((minerFees.asInt * 1.2).ceil() + randomSats());
    final encaissement = availSats - minerFees - down4Fees;

    if (encaissement.asInt <= 0) return null;

    _ix = _ix + 1;
    final txSecret = makeUint32(_ix) + utf8.encode(selfID);
    final down4Keys = DOWN4_NEUTER.derive(txSecret);
    if (down4Keys == null) return null;
    var down4Out = Down4TXOUT(
      isFee: true,
      sats: down4Fees,
      scriptPubKey: p2pkh(down4Keys.rawAddress),
    );

    final selfKeys = _keys.derive(txSecret);
    if (selfKeys == null) return null;
    var selfOut = Down4TXOUT(
      receiver: selfID,
      sats: encaissement,
      scriptPubKey: p2pkh(selfKeys.rawAddress),
    );

    final List<Down4TXOUT> outs = [down4Out, selfOut];

    List<Down4TXIN> ins = [];
    for (var utxo in fetchedUtxos) {
      var txin = Down4TXIN(
        utxoIndex: FourByteInt(utxo.outIndex!),
        utxoTXID: utxo.txid!,
        spender: utxo.receiver,
      );
      ins.add(txin);
    }

    for (var i = 0; i < ins.length; i++) {
      final theUtxo = fetchedUtxos.firstWhere(
        (element) => element.id == ins[i].utxoID,
      );
      final sData = sigData(txsIn: ins, txsOut: outs, nIn: i, utxo: theUtxo);
      if (sData == null) return null;
      final scriptSig = p2pkhSig(keys: importedKeys, sigData: sData);
      if (scriptSig == null) return null;
      ins[i].script = scriptSig;
    }

    final theTx = Down4TX(txsIn: ins, txsOut: outs, down4Secret: txSecret);

    return Down4Payment([theTx], true, textNote: "Imported");
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

  Future<void> _updateStatus(Down4Payment payment) async {
    final ids = payment.txs.map((e) => e.txID.asHex).toList();

    final confirmations = await r.confirmations(ids);
    if (confirmations == null || confirmations.length != ids.length) return;

    for (int i = 0; i < confirmations.length; i++) {
      _payments[payment.id]!.txs[i].confirmations = confirmations[i];
    }
  }

  List<Down4TX> _chainedTxs(Down4TX from) {
    final unsettledIDs = uTXID;
    Set<Down4TX> deps = {from};
    List<Down4TX> copy;
    do {
      copy = List<Down4TX>.from(deps);
      var depIDs = copy.map((tx) => tx.txidDeps).expand((dep) => dep).toSet();
      for (final depID in depIDs) {
        if (unsettledIDs.contains(depID)) {
          deps.add(unsettledTxs.singleWhere((tx) => tx.txID == depID));
        }
      }
    } while (deps.length != copy.length);

    return copy.reversed.toList(growable: false);
  }

  List<dynamic>? _unsignedIns(Identifier selfID, Sats pay, int currentTxSize) {
    const inSize = 148;
    List<Down4TXIN> ins = [];
    var cumulSize = currentTxSize;
    final randSats = randomSats();
    var currentMinerFees = (currentTxSize * SATS_PER_BYTE);
    var currentDown4Fees = (currentMinerFees * 1.2) + randSats;
    var accumulatedSats = Sats(0);
    var iUtxo = 0;
    for (final utxo in _utxos.values) {
      var txin = Down4TXIN(
        utxoTXID: utxo.txid!,
        utxoIndex: FourByteInt(utxo.outIndex!),
        spender: selfID,
        sequenceNo: 0,
        dependance: uTXID.contains(utxo.txid) ? utxo.txid : null,
      );
      ins.add(txin);
      cumulSize += inSize;
      iUtxo = iUtxo + 1;
      currentTxSize = VarInt.fromInt(iUtxo).data.length + cumulSize;
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

  Wallet._({
    int? ix,
    Map<Identifier, Down4TXOUT>? utxos,
    Map<Identifier, Down4Payment>? payments,
    required Down4Keys keys,
    Map<Identifier, bool>? spent,
  })  : _utxos = utxos ?? <Identifier, Down4TXOUT>{},
        _payments = payments ?? <Identifier, Down4Payment>{},
        _spent = spent ?? <Identifier, bool>{},
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
      spent: Map.from(decodedJson["spent"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "utxos": _utxos.map((key, val) => MapEntry(key, val.toJson())),
        "payments": _payments.map((key, val) => MapEntry(key, val.toJson())),
        "keys": _keys.toJson(),
        "ix": _ix,
        "spent": _spent,
      };
}

void main() {
  var f = io.File("C:\\Users\\coton\\Desktop\\jeff.txt");
  // var f = io.File("/home/scott/jeff.txt");
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
