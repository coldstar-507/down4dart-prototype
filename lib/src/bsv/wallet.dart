import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';

import '../_dart_utils.dart';
import '../data_objects/couch.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/nodes.dart';
import '../web_requests.dart' as r;
import '../globals.dart' show g;

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

  Future<void> walletRoutine({VoidCallback? callback}) async {
    await _updateAllStatus();
    await Future.delayed(const Duration(seconds: 1));
    await Future.wait(await _settleUnsettledPayments());
    callback?.call();
    return print("""
      /////////////////////////////////////////////////////////
      // \$\$\$\$\$\$ TERMINATED WALLET ROUTINE \$\$\$\$\$\$ //
      /////////////////////////////////////////////////////////
      """);
  }

  Future<List<Future<void>>> _settleUnsettledPayments() async {
    var futures = <Future<void>>[];
    for (final payment in payments) {
      if (payment.confirmations == -1) futures.add(payment.trySettlement());
    }
    return futures;
  }

  Future<void> _updateAllStatus() async {
    final txs = sub100confsTxs().toList(growable: false);
    final ids = txs.map((e) => e.txID.asHex).toList();

    final confirmations = await r.confirmations(ids);
    for (final confs in confirmations.entries) {
      final c = confs.value;
      if (c != null) {
        final txid = TXID.fromHex(confs.key);
        final tx = txs.singleWhere((tx) => tx.txID == txid);
        tx.updateConfirmations(c);
      }
    }
  }

  Future<void> printWalletInfo() async {
    for (final p in payments) {
      print("============PAYMENT============");
      print("""
        id        = ${p.id.unik}
        lastTxID  = ${p.txs.last.txID.asHex}
        message   = ${p.textNote}
      """);
      print("==============TX==============");
      if (p.txs.isNotEmpty) {
        final lastTx = p.txs.last;
        print("""
        id        = ${lastTx.id.value}
        txid hex  = ${lastTx.txID.asHex}
        nIns      = ${lastTx.inCounter.asInt}
        nOuts     = ${lastTx.outCounter.asInt}
        confs     = ${lastTx.confirmations}
        secret    = ${lastTx.down4Secret}
        """);
        // print("==RAW==");
        // printWrapped(lastTx.raw.toHex());

        print("============TXIN===========");
        for (final txin in lastTx.txsIn) {
          print("""
        spender   = ${txin.spender?.unik}
        outIx     = ${txin.utxoIndex.asInt}
        outId     = ${txin.utxoTXID.asHex}
        """);
        }
        print("============UTXO============");
        for (final utxo in lastTx.txsOut) {
          print("""
        outIx     = ${utxo.outIndex} 
        sats      = ${utxo.sats.asInt} ${utxo.sats.data}
        txid      = ${utxo.txid!.asHex}
        id        = ${utxo.id.unik}
        receiver  = ${utxo.receiver?.unik}
        secret    = ${utxo.secret}
        spent     = ${utxo.spent}
        """);
        }
      }
    }
    print("===============SPENTS===============");
    final spts = allSpents().toList();
    for (int i = 0; i < spts.length; i++) {
      print("""
        spents[$i] = ${spts[i]}
        """);
    }
  }

  Down4Payment? payPeople({
    required List<PersonN> people,
    required ComposedID selfID,
    required Sats amount,
    double? discount,
    double? tip,
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
    final (txIns, minerFees, down4Fees) = inInfos;
    Sats inSats = txIns.fold(Sats(0), (tot, txin) {
      final utxo = getUtxo(txin.utxoID);
      return tot + (utxo?.sats ?? Sats(0));
    });

    // at this point, there is no reason for the payment to fail
    // except if a key derivation returns null, and in that case, calling the
    // function again should solve the problem
    List<Down4TXOUT> txOuts = [];
    _ix = _ix + 1;
    merge(vals: {"ix": _ix.toString()});
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
    txOuts.add(d4out);

    for (int i = 0; i < people.length; i++) {
      final userKeys = people[i].neuter.derive(txSecret);
      if (userKeys == null) return null;
      var uOut = Down4TXOUT(
        type: UtxoType.gets,
        sats: payPerPerson,
        script: p2pkh(userKeys.rawAddress),
        receiver: people[i].id,
      );
      txOuts.add(uOut);
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
      txOuts.add(changeOut);
    }

    for (var i = 0; i < txIns.length; i++) {
      final spentUtxo = getUtxo(txIns[i].utxoID);
      if (spentUtxo == null) return null;

      final utxoSecret = spentUtxo.secret;
      if (utxoSecret == null) return null;

      final sData =
          sigData(txsIn: txIns, txsOut: txOuts, nIn: i, utxo: spentUtxo);
      if (sData == null) return null;

      final keysForSig = _keys.derive(utxoSecret);
      if (keysForSig == null) return null;

      final scriptSig = p2pkhSig(keys: keysForSig, sigData: sData);
      if (scriptSig == null) return null;

      txIns[i].scriptSig = scriptSig;
    }

    final (inCount, outCount) = (VarInt(txIns.length), VarInt(txOuts.length));
    final (versionNo, nLockTime) = (FourByteInt(1), FourByteInt(0));
    final txid =
        calculateTXID(versionNo, inCount, txIns, outCount, txOuts, nLockTime);

    for (int i = 0; i < txOuts.length; i++) {
      txOuts[i].txid = txid;
      txOuts[i].outIndex = i;
    }

    final theTx = Down4TX(
        down4Secret: txSecret,
        vNo: versionNo,
        inCount: inCount,
        txIns: txIns,
        outCount: outCount,
        txOuts: txOuts,
        ins: txIns.map((e) => e.id).toList(),
        outs: txOuts.map((e) => e.id).toList(),
        nLock: nLockTime);

    return Down4Payment(Down4ID(),
        txid: theTx.txID,
        txs: fullChain(theTx),
        tip: tip,
        discount: discount,
        spender: g.self.id,
        safe: true,
        textNote: textNote);
  }


  Down4Payment? parsePayment3(ComposedID selfID, Down4Payment pay,
      {VoidCallback? callblack}) {
      
    print("parsing payment: ${pay.id.value}");
    if (pay.existsLocally() || !pay.receivers.contains(selfID)) {
      print("payment was already parsed");
      return null;
    }
    final sbuf = StringBuffer()..writeln("BEGIN TRANSACTION;");
    for (final tx in pay.txs) {
      tx.writeTxInfosToUTXOs();
    }
    for (final utxo in pay.txs.last.txsOut) {
      final spent = isSpent(utxo.id);
      print("utxo receiver: ${utxo.receiver?.unik}, isSpent: $spent");
      if (utxo.receiver == selfID && !spent) {
        sbuf.writeln(utxo.merge(stmt: true)!);
      }
    }
    for (final txin in pay.txs.last.txsIn) {
      if (txin.spender == selfID) {
        final txout = local<Down4TXOUT>(txin.utxoID);
        if (txout == null) continue;
        sbuf.writeln(handleUtxo(txout, stmt: true)!);
        sbuf.writeln(setSpent(txout.id, stmt: true)!);
      }
    }

    sbuf.writeln("COMMIT;");

    try {
      final txstr = sbuf.toString();
      print("============ EXECUTING TRANSACTION ============\n\n$txstr\n");
      db.execute(txstr);
      print("\n============ VALIDATED TRANSACTION ============\n");
      return pay
        ..calculatePlusMinus(selfID: selfID)
        ..trySettlement(cb: callblack)        
        ..fullMerge();
    } catch (e) {
      print("error parsing payment: $e");
      db.execute("ROLLBACK;");
    }

    return null;
  }

  void walletTrimRoutine() {
    const q = """
      SELECT * FROM transactions
      WHERE CAST(confirmations AS INTEGER) > 80
    """;
    final xs = db.select(q).map((e) {
      final jsns = Map<String, String?>.from(e);
      return Down4TX.fromJson(jsns);
    });

    for (final x in xs) {
      if (x.spenders.contains(g.self.id)) continue;
      for (final txin in x.txsIn) {
        txin.delete();
      }
      for (final txout in x.txsOut) {
        if (txout.spent) txout.delete();
      }
      x.delete();
    }
  }

  // void parsePayment(ComposedID selfID, Down4Payment pay) {
  //   print("parsing payment: ${pay.id}");
  //   for (final tx in pay.txs) {
  //     if (tx.txsOut.length != tx.outCounter.asInt) {
  //       return print("cannot parse payment, we don't have all the TXOUTS");
  //     }
  //     tx.writeTxInfosToUTXOs();
  //   }
  //   for (final utxo in pay.txs.last.txsOut) {
  //     final spent = isSpent(utxo.id);
  //     print("utxo receiver: ${utxo.receiver}, isSpent: $spent");
  //     if (utxo.receiver == selfID && !spent) setUtxo(utxo);
  //   }
  //   for (final txin in pay.txs.last.txsIn) {
  //     if (txin.spender == selfID) {
  //       final utxo = local<Down4TXOUT>(txin.utxoID)!..markSpent();
  //       setSpent(utxo.id);
  //       removeUtxoIfSettled(utxo);
  //     }
  //   }

  //   pay
  //     ..calculatePlusMinus(selfID: selfID)
  //     ..fullMerge();

  //   _trySettlement(pay);
  //   return;
  // }

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

    final List<Down4TXOUT> txOuts = [down4Out, selfOut];

    List<Down4TXIN> txIns = [];
    for (var utxo in fetchedUtxos.values) {
      var txin = Down4TXIN(
        satSpent: utxo.sats.asInt,
        utxoIndex: FourByteInt(utxo.outIndex!),
        utxoTXID: utxo.txid!,
        spender: utxo.receiver,
      );
      txIns.add(txin);
    }

    for (var i = 0; i < txIns.length; i++) {
      final theUtxo = fetchedUtxos[txIns[i].utxoID]!;
      final sData =
          sigData(txsIn: txIns, txsOut: txOuts, nIn: i, utxo: theUtxo);
      if (sData == null) return null;
      final scriptSig = p2pkhSig(keys: importedKeys, sigData: sData);
      if (scriptSig == null) return null;
      txIns[i].scriptSig = scriptSig;
    }

    final (inCount, outCount) = (VarInt(txIns.length), VarInt(txOuts.length));
    final (versionNo, nLockTime) = (FourByteInt(1), FourByteInt(0));
    final txid =
        calculateTXID(versionNo, inCount, txIns, outCount, txOuts, nLockTime);

    for (int i = 0; i < txOuts.length; i++) {
      txOuts[i].txid = txid;
      txOuts[i].outIndex = i;
    }

    final theTx = Down4TX(
        vNo: versionNo,
        txIns: txIns,
        inCount: inCount,
        ins: txIns.map((e) => e.id).toList(),
        outCount: outCount,
        txOuts: txOuts,
        outs: txOuts.map((e) => e.id).toList(),
        nLock: nLockTime,
        down4Secret: txSecret);

    return Down4Payment(Down4ID(),
        spender: null,
        txid: theTx.txID,
        txs: [theTx],
        safe: false,
        textNote: "Imported");
  }

  static List<Down4TX> fullChain(Down4TX head) {
    List<List<Down4TX>> ch = [
      [head]
    ];
    do {
      final txs = ch.last;
      final Set<TXID> refs = txs
          .map((tx) => tx.txsIn.map((txin) => txin.utxoTXID))
          .expand((txid) => txid)
          .toSet();
      final refstr = refs.map((txid) => txid.asBase64.sqlReady).join(",");
      final q = """
        SELECT * FROM transactions
        WHERE confirmations = '-1' AND id IN ($refstr)
        """;
      final r = db.select(q).map((e) {
        final jsns = Map<String, String?>.from(e);
        return Down4TX.fromJson(jsns);
      });
      ch.add(r.toList());
    } while (ch.last.isNotEmpty);

    Set<Down4TX> sortedChain = {};
    for (final xs in ch.reversed) {
      sortedChain.addAll(xs);
    }

    return sortedChain.toList();
  }

  static Iterable<Down4TX> loadTXs(Iterable<Down4ID> txids) {
    final refstr = txids.map((txid) => txid.sqlReady).join(",");
    final q = """
        SELECT * FROM transactions
        WHERE id IN ($refstr)
        """;
    return db
        .select(q)
        .map((e) {
          final jsns = Map<String, String?>.from(e);
          return Down4TX.fromJson(jsns);
        })
        .toList()
        .specificOrder(txids);
  }

  (List<Down4TXIN>, Sats, Sats)? _unsignedIns(
      Down4ID selfID, Sats pay, int currentTxSize) {
    const inSize = 148;
    List<Down4TXIN> ins = [];
    var cumulSize = currentTxSize;
    final randSats = randomSats();
    var currentMinerFees = (currentTxSize * SATS_PER_BYTE);
    var currentDown4Fees = (currentMinerFees * 1.2) + randSats;
    var accumulatedSats = Sats(0);
    var iUtxo = 0;
    for (final utxo in utxos) {
      var txin = Down4TXIN(
          satSpent: utxo.sats.asInt,
          utxoTXID: utxo.txid!,
          utxoIndex: FourByteInt(utxo.outIndex!),
          spender: selfID,
          sequenceNo: 0);
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
        return (ins, minerFees, down4Fees);
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

  /////////////////////////////////////////////////////////////////////
  //// static utility functions ///////////////////////////////////////
  /////////////////////////////////////////////////////////////////////
  static Iterable<Down4Payment> get payments sync* {
    const raw = "SELECT * FROM payments ORDER BY ts DESC";
    final rows = db.select(raw);
    for (final row in rows) {
      final jsns = Map<String, String?>.from(row);
      yield Down4Payment.fromJson(jsns);
    }
  }

  static Iterable<Down4Payment> nPayments(
      {required int limit, int offset = 0}) sync* {
    final raw = """
        SELECT * FROM payments
        ORDER BY ts DESC
        LIMIT $limit OFFSET $offset
        """;

    final rows = db.select(raw);
    for (final row in rows) {
      final jsns = Map<String, String?>.from(row);
      yield Down4Payment.fromJson(jsns);
    }
  }

  static Iterable<Down4TXOUT> get utxos sync* {
    final raw = """
    SELECT * FROM txouts
    WHERE spent = 'false' AND receiver = ${g.self.id.sqlReady}
    """;
    final rows = db.select(raw);
    for (final row in rows) {
      final jsns = Map<String, String?>.from(row);
      yield Down4TXOUT.fromJson(jsns);
    }
  }

  static Down4TXOUT? getUtxo(Down4ID id) {
    return local<Down4TXOUT>(id);
  }

  static String? removeUtxo(Down4ID id, {bool stmt = false}) {
    final raw = "DELETE FROM txouts WHERE id = ${id.sqlReady};";
    if (stmt) return raw;
    db.execute(raw);
    return null;
  }

  static Iterable<Down4TX> sub100confsTxs() sync* {
    const raw = """
      SELECT * FROM transactions
      WHERE CAST(confirmations AS INTEGER) < 100
    """;
    final jsnL = db.select(raw);
    print("there are ${jsnL.length} sub 100 confs txs!");
    for (final jsn in jsnL) {
      final jsns = Map<String, String?>.from(jsn);
      yield Down4TX.fromJson(jsns);
    }
  }

  static Iterable<Down4TX> allTxs() sync* {
    const raw = "SELECT * FROM transactions";
    final jsnL = db.select(raw);
    for (final jsn in jsnL) {
      final jsns = Map<String, String?>.from(jsn);
      yield Down4TX.fromJson(jsns);
    }
  }

  static Down4TX? loadTX(String id) {
    const raw = "SELECT * FROM transactions WHERE id = ?";
    final r = db.select(raw, [id]);
    if (r.isEmpty) return null;
    final jsns = Map<String, String?>.from(r.single);
    return Down4TX.fromJson(jsns);
  }

  static String? handleUtxo(Down4TXOUT utxo, {bool stmt = false}) {
    final localTx = loadTX(utxo.txid!.asBase64);
    if (localTx == null) return removeUtxo(utxo.id, stmt: stmt);
    final (spenders, confs) = (localTx.spenders, localTx.confirmations);
    // if spender contains self, means we initiated the tx,
    // and we want to keep those for a while
    // TODO: decide when to archive our own transactions
    if (!spenders.contains(g.self.id) && confs > 30) {
      return removeUtxo(utxo.id, stmt: stmt);
    } else {
      return utxo.markSpent(stmt: stmt);
    }
  }

  static Down4Payment? getPayment(Down4ID id) {
    return local<Down4Payment>(id);
  }

  static String? removePayment(Down4ID id, {bool stmt = false}) {
    final raw = "DELETE FROM payments WHERE id = ${id.value.sqlReady};";
    if (stmt) return raw;
    db.execute(raw);
    return null;
  }

  static String? setPayment(Down4Payment payment, {bool stmt = false}) {
    return payment.merge(stmt: stmt);
  }

  static String? setUtxo(Down4TXOUT utxo, {bool stmt = false}) {
    return utxo.merge(stmt: stmt);
  }

  static bool isSpent(Down4ID utxoID) {
    final raw = "SELECT * FROM spents WHERE id = ${utxoID.value.sqlReady};";
    return db.select(raw).isNotEmpty;
  }

  static Iterable<String> allSpents() sync* {
    const raw = "SELECT * FROM spents";
    for (final r in db.select(raw)) {
      yield r["id"] as String;
    }
  }

  static String? setSpent(Down4ID id, {bool stmt = false}) {
    final raw = """
    INSERT INTO spents (id) VALUES (${id.value.sqlReady});
    """;
    if (stmt) return raw;
    db.execute(raw);
    return null;
  }

  // still no use, intended as a possible control mechanism
  static void unSpend(Down4ID id) {
    final raw = "DELETE FROM spents WHERE id = ${id.value.sqlReady}";
    db.execute(raw);
  }

  static Wallet? load() {
    return local<Wallet>(Down4ID(unik: "single"));
  }
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
