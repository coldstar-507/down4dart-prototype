import 'dart:convert';
import 'dart:io' as io;

import '../_dart_utils.dart';
import '../data_objects/couch.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/nodes.dart';
import '../web_requests.dart' as r;

import 'package:bs58/bs58.dart';

import '_bsv_utils.dart';
import 'types.dart';

class Wallet with Down4Object, Jsons, Locals {
  @override
  String get table => "personals";

  @override
  Down4ID get id => Down4ID(unik: "single");

  final Down4Keys _keys;
  int _ix;

  Down4Keys get neuter => _keys.neutered();

  int get balance => utxos.fold(0, (bal, tx) => bal + tx.sats.asInt);

  Set<Down4TX> get unsettledTxs => payments
      .map((pay) => pay.txs.where((tx) => tx.confirmations == 0))
      .expand((tx) => tx)
      .toSet();

  Set<TXID> get uTXID => unsettledTxs.map((unsTx) => unsTx.txID).toSet();

  Future<void> walletRoutine() async {
    await Future.wait(await _updateAllStatus());
    await Future.wait(await _settleUnsettledPayments());
    return print("\$\$\$\$\$\$ TERMINATED WALLET ROUTINE \$\$\$\$\$\$");
  }

  Future<List<Future<void>>> _settleUnsettledPayments() async {
    var futures = <Future<void>>[];
    for (final payment in payments) {
      if (payment.lastConfirmations == 0) futures.add(_trySettlement(payment));
    }
    return futures;
  }

  Future<List<Future<void>>> _updateAllStatus() async {
    var futures = <Future<void>>[];
    for (final payment in payments) {
      if (payment.lastConfirmations < 100) futures.add(_updateStatus(payment));
    }
    return futures;
  }

  Future<void> printWalletInfo() async {
    for (final p in payments) {
      print("============PAYMENT============");
      print("""
      id           = ${p.id}
      lastTxID     = ${p.txs.last.txID.asHex}
      message      = ${p.textNote}
      lasTX secret = ${p.txs.last.down4Secret}
      """);
      print("============TXIN===========");
      for (final txin in p.txs.last.txsIn) {
        print("""
        spender = ${txin.spender}
        outIx   = ${txin.utxoIndex.asInt}
        outId   = ${txin.utxoTXID.asHex}
        """);
      }
      print("============UTXO============");
      for (final utxo in p.txs.last.txsOut) {
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

  Down4Payment? payPeople({
    required List<PersonN> people,
    required ComposedID selfID,
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
    Sats inSats = ins.fold(Sats(0), (tot, txin) {
      final utxo = getUtxo(txin.utxoID);
      return tot + (utxo?.sats ?? Sats(0));
    });

    // at this point, there is no reason for the payment to fail
    // except if a key derivation returns null, and in that case, calling the
    // function again should solve the problem
    List<Down4TXOUT> outs = [];
    _ix = _ix + 1;
    merge({"ix": _ix.toString()});
    // the goal here is simply having a unique id everytime
    final txSecret = makeUint32(_ix) + utf8.encode(selfID.unik);
    final d4Keys = DOWN4_NEUTER.derive(txSecret);
    // except for here possibly? must be fucking rare tho
    if (d4Keys == null) return null;
    var d4out = Down4TXOUT(
      type: UtxoType.fee,
      sats: down4Fees,
      script: p2pkh(d4Keys.rawAddress),
    );
    outs.add(d4out);

    for (int i = 0; i < people.length; i++) {
      final userKeys = people[i].neuter.derive(txSecret);
      if (userKeys == null) return null;
      var uOut = Down4TXOUT(
        type: UtxoType.gets,
        sats: payPerPerson,
        script: p2pkh(userKeys.rawAddress),
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
          type: UtxoType.change,
          sats: change,
          script: p2pkh(selfKeys.rawAddress),
          receiver: selfID);
      outs.add(changeOut);
    }

    for (var i = 0; i < ins.length; i++) {
      final spentUtxo = getUtxo(ins[i].utxoID);
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
      setSpent(spentUtxo.id);
    }

    final theTx = Down4TX(down4Secret: txSecret, txsIn: ins, txsOut: outs);

    return Down4Payment(_chainedTxs(theTx), safe: true, textNote: textNote);
  }

  void parsePayment2(Down4ID selfID, Down4Payment pay) {
    final sbuf = StringBuffer("BEGIN TRANSACTION;");
    final List<String> args = [];

    print("parsing payment: ${pay.id}");
    for (final tx in pay.txs) {
      tx.writeTxInfosToUTXOs();
    }
    for (final utxo in pay.txs.last.txsOut) {
      final spent = isSpent(utxo.id);
      print("utxo receiver: ${utxo.receiver}, isSpent: $spent");
      if (utxo.receiver == selfID && !spent) {
        final jsn = utxo.toJson(includeLocal: true);
        final stmt = """
        INSERT INTO utxos ${jsn.sqlInsertKeys}
        VALUES ${jsn.sqlInsertValuesParams};
        """;
        sbuf.write(stmt);
        args.addAll(jsn.values);
      }
    }
    for (final txin in pay.txs.last.txsIn) {
      if (txin.spender == selfID) {
        const stmt = "DELETE FROM utxos WHERE id = ?;";
        const stmt2 = "INSERT INTO spents (id) VALUES (?);";
        sbuf.write(stmt);
        sbuf.write(stmt2);
        args.add(txin.utxoID.value);
        args.add(txin.utxoID.value);
      }
    }

    final jsn = pay.toJson(includeLocal: true);
    final stmt = """
    INSERT INTO payments ${jsn.sqlInsertKeys}
    VALUES ${jsn.sqlInsertValuesParams};
    """;
    sbuf.write(stmt);
    args.addAll(jsn.values);

    sbuf.write("COMMIT;");

    try {
      db.execute(sbuf.toString(), args);
    } catch (e) {
      print("error parsing payment: $e");
      db.execute("ROLLBACK;");
    }

    _trySettlement(pay);
    return;
  }

  void parsePayment(Down4ID selfID, Down4Payment pay) {
    print("parsing payment: ${pay.id}");
    for (final tx in pay.txs) {
      tx.writeTxInfosToUTXOs();
    }
    for (final utxo in pay.txs.last.txsOut) {
      final spent = isSpent(utxo.id);
      print("utxo receiver: ${utxo.receiver}, isSpent: $spent");
      if (utxo.receiver == selfID && !spent) setUtxo(utxo);
    }
    for (final txin in pay.txs.last.txsIn) {
      if (txin.spender == selfID) {
        setSpent(txin.utxoID);
        removeUtxo(txin.utxoID);
      }
    }

    setPayment(pay);
    _trySettlement(pay);
    return;
  }

  Future<Down4Payment?> importMoney(String pkBase68, ComposedID selfID) async {
    final rawKey = BigInt.parse(base58.decode(pkBase68).toHex(), radix: 16);

    final importedKeys = Down4Keys.fromPrivateKey(rawKey);
    final importedAddress = testnetAddress(importedKeys.rawCompressedPub);
    final fetchedUtxos = await getUtxos(importedAddress.toBase58());
    if (fetchedUtxos == null) return null;

    final availableSats =
        fetchedUtxos.values.fold<Sats>(Sats(0), (tot, utxo) => tot + utxo.sats);

    // outs(34*2) + nOut(1) + version(4) + nSeq(4) + nIn(var) + ins(148*nIn)
    final nIn = VarInt.fromInt(fetchedUtxos.length);
    final txSize = (34 * 2) + 9 + (148 * fetchedUtxos.length) + nIn.data.length;

    final minerFees = Sats((SATS_PER_BYTE * txSize).ceil());
    final down4Fees = Sats((minerFees.asInt * 1.2).ceil() + randomSats());
    final encaissement = availableSats - minerFees - down4Fees;

    if (encaissement.asInt <= 0) return null;

    _ix = _ix + 1;
    final txSecret = makeUint32(_ix) + utf8.encode(selfID.unik);
    final down4Keys = DOWN4_NEUTER.derive(txSecret);
    if (down4Keys == null) return null;
    var down4Out = Down4TXOUT(
      type: UtxoType.fee,
      sats: down4Fees,
      script: p2pkh(down4Keys.rawAddress),
    );

    final selfKeys = _keys.derive(txSecret);
    if (selfKeys == null) return null;
    var selfOut = Down4TXOUT(
      type: UtxoType.gets,
      receiver: selfID,
      sats: encaissement,
      script: p2pkh(selfKeys.rawAddress),
    );

    final List<Down4TXOUT> outs = [down4Out, selfOut];

    List<Down4TXIN> ins = [];
    for (var utxo in fetchedUtxos.values) {
      var txin = Down4TXIN(
        utxoIndex: FourByteInt(utxo.outIndex!),
        utxoTXID: utxo.txid!,
        spender: utxo.receiver,
      );
      ins.add(txin);
    }

    for (var i = 0; i < ins.length; i++) {
      final theUtxo = fetchedUtxos[ins[i].utxoID]!;
      final sData = sigData(txsIn: ins, txsOut: outs, nIn: i, utxo: theUtxo);
      if (sData == null) return null;
      final scriptSig = p2pkhSig(keys: importedKeys, sigData: sData);
      if (scriptSig == null) return null;
      ins[i].script = scriptSig;
    }

    final theTx = Down4TX(txsIn: ins, txsOut: outs, down4Secret: txSecret);

    return Down4Payment([theTx], safe: false, textNote: "Imported");
  }

  Future<void> _trySettlement(Down4Payment payment) async {
    final txsToSettle = payment.txs
        .where((tx) => tx.confirmations == 0)
        .toList(growable: false);

    final failures = await r.broadcastTxs(txsToSettle);
    for (final f in failures) {
      print(
        "ERROR Broadcasting tx ID: ${payment.txs[f.first].txID.asHex}, ${f.second}",
      );
    }
  }

  Future<void> _updateStatus(Down4Payment payment) async {
    final ids = payment.txs.map((e) => e.txID.asHex).toList();

    final confirmations = await r.confirmations(ids);
    if (confirmations == null || confirmations.length != ids.length) return;

    for (int i = 0; i < confirmations.length; i++) {
      payment.txs[i].confirmations = confirmations[i];
      setPayment(payment);
    }
  }

  List<Down4TX> _chainedTxs(Down4TX from) {
    final unsettledIDs = uTXID;
    final unsettledTransactions = unsettledTxs;

    // final unsettledIDs = uTXID;
    Set<Down4TX> deps = {from};
    List<Down4TX> copy;
    do {
      copy = List<Down4TX>.from(deps);
      var depIDs = copy.map((tx) => tx.txidDeps).expand((dep) => dep).toSet();
      for (final depID in depIDs) {
        if (unsettledIDs.contains(depID)) {
          deps.add(unsettledTransactions.singleWhere((tx) => tx.txID == depID));
        }
      }
    } while (deps.length != copy.length);

    return copy.reversed.toList(growable: false);
  }

  List<dynamic>? _unsignedIns(Down4ID selfID, Sats pay, int currentTxSize) {
    const inSize = 148;
    List<Down4TXIN> ins = [];
    var cumulSize = currentTxSize;
    final randSats = randomSats();
    var currentMinerFees = (currentTxSize * SATS_PER_BYTE);
    var currentDown4Fees = (currentMinerFees * 1.2) + randSats;
    var accumulatedSats = Sats(0);
    var iUtxo = 0;
    final unsettledTxIDs = uTXID;
    for (final utxo in utxos) {
      var txin = Down4TXIN(
        utxoTXID: utxo.txid!,
        utxoIndex: FourByteInt(utxo.outIndex!),
        spender: selfID,
        sequenceNo: 0,
        dependance: unsettledTxIDs.contains(utxo.txid) ? utxo.txid : null,
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

  Wallet({
    required Down4Keys keys,
    required int? ix,
  })  : _keys = keys,
        _ix = ix ?? -1;

  factory Wallet.fromJson(Map<String, String?> decodedJson) {
    return Wallet(
      keys: Down4Keys.fromYouKnow(decodedJson["keys"] as String),
      ix: int.parse(decodedJson["ix"] as String),
    );
  }

  @override
  Map<String, String> toJson({bool includeLocal = true}) => {
        "keys": _keys.toYouKnow(),
        "ix": _ix.toString(),
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
