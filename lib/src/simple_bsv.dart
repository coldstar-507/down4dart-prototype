import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'data_objects.dart';
import 'package:pointycastle/digests/sha256.dart' as s256;
import 'package:pointycastle/digests/ripemd160.dart' as r160;
import 'package:bip32/bip32.dart';
import 'down4_utility.dart';

const TAAL_BATCH_BROADCAST = "https://api.taal.com/api/v1/batchBroadcast";

// request.post({
//   url: 'https://api.taal.com/api/v1/batchBroadcast',
//   headers: {
//     'Authorization': apiKey,
//     'Content-Type': 'application/octet-stream'
//   },
//   body: txBuffer
// }, function(error, response, body) {
//   console.log(error, response.statusCode, body)
// })

List<int> _p2pkh(List<int> address) => [0x76, 0xa9, ...address, 0x88, 0xac];

Uint8List sha256(Uint8List data) => s256.SHA256Digest().process(data);

Uint8List sha256sha256(Uint8List data) => sha256(sha256(data));

Uint8List ripemd160(Uint8List data) => r160.RIPEMD160Digest().process(data);

Uint8List _makeAddress(Uint8List pubKey) => ripemd160(sha256(pubKey));

int _deterministicWalletIndex() =>
    (DateTime.now().millisecondsSinceEpoch / 86400000).floor();

class Wallet {
  static const SATS_PER_BYTE = 0.05;
  static const DOWN4_SATS_PER_BYTE = 0.025;
  static final DOWN4_NEUTER = BIP32.fromSeed(Uint8List.fromList(
    [1, 2], // TODO
  ));

  final String _mnemonic;
  BIP32 down4priv;
  List<Down4TXOUT> utxos;
  List<Down4TX> unsettledTxs;
  Wallet(this.utxos, this.down4priv, this.unsettledTxs, String mnemonic)
      : _mnemonic = mnemonic;

  String get mnemonic => _mnemonic;

  List<TXID> get uTXID => unsettledTxs.map((e) => e.txID!).toList();

  int get balance => utxos.fold(0, (bal, tx) => bal + tx.sats.asInt);

  List<Down4TX> recDeps(List<Down4TX> deps) {
    var newDeps = deps
        .map((tx) => tx.txidDeps)
        .expand((txid) => txid)
        .toSet()
        .map((txid) => unsettledTxs.singleWhere((tx) => tx.txID == txid))
        .toList();

    if (newDeps.length == deps.length) return deps;
    return recDeps(newDeps);
  }

  Map<String, dynamic> toJson() => {
        "m": mnemonic,
        "bip": down4priv.toBase58(),
        "utxos": utxos.map((e) => e.toJson()),
        "txs": unsettledTxs.map((e) => e.toJson()),
      };

  factory Wallet.fromJson(dynamic decodedJson) {
    return Wallet(
      List<dynamic>.from(decodedJson["utxos"])
          .map((e) => Down4TXOUT.fromJson(jsonDecode(e)))
          .toList(),
      BIP32.fromBase58(decodedJson["bip"]),
      List<dynamic>.from(decodedJson["txs"])
          .map((e) => Down4TX.fromJson(jsonDecode(e)))
          .toList(),
      decodedJson["m"],
    );
  }

  void sortUtxos() {
    return utxos.sort(((a, b) => b.sats.asInt.compareTo(a.sats.asInt)));
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
        scriptPubKey: _p2pkh(address),
      ));
    }
    return outs;
  }

  List<dynamic>? _unsignedIns(Node self, Sats pay, int nOuts) {
    List<Down4TXIN> ins = [];
    var minerFees = Sats(((nOuts * 34) * SATS_PER_BYTE).ceil());
    var down4Fees = Sats((minerFees.asInt / 2).ceil());
    var sats = Sats(0);
    for (int i = 0; i < utxos.length; i++) {
      ins.add(Down4TXIN(
          spender: self.id,
          walletIndex: utxos[i].walletIndex,
          sats: utxos[i].sats,
          spentFrom: utxos[i].txid!,
          outIndex: FourByteInt(utxos[i].outIndex!),
          sequenceNo: FourByteInt(0),
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

  List<Down4TX>? pay(List<Node> targets, Node self, Sats amount) {
    sortUtxos();
    final walletIndex = _deterministicWalletIndex();
    var outs = _reqOuts(targets, self, amount, walletIndex);
    var inInfo = _unsignedIns(self, amount, targets.length + 2);
    if (inInfo == null) return null;
    List<Down4TXIN> txsIn = inInfo[0];
    Sats minerFees = inInfo[1];
    Sats down4Fees = inInfo[2];
    final inAmount = txsIn.fold<Sats>(Sats(0), (tot, tx) => tot + tx.sats!);

    // add the change
    final changeAmount = inAmount - amount - minerFees - down4Fees;
    final changePubKey = self.neuter!.derive(walletIndex).publicKey;
    final changeAddress = _makeAddress(changePubKey);
    outs.add(Down4TXOUT(
      sats: changeAmount,
      scriptPubKey: _p2pkh(changeAddress),
      walletIndex: walletIndex,
      receiver: self.id,
      outIndex: outs.length,
    ));

    // add the relay tax
    final relayPubKey = DOWN4_NEUTER.derive(walletIndex).publicKey;
    final relayChangeAddress = _makeAddress(relayPubKey);
    outs.add(Down4TXOUT(
      sats: down4Fees,
      scriptPubKey: _p2pkh(relayChangeAddress),
      walletIndex: walletIndex,
      outIndex: outs.length,
    ));

    // here we should have all the tx data necessary for signing
    var tx = Down4TX(txsIn: txsIn, maker: self.id, txsOut: outs);
    final txdata = tx.asRawData.asUint8List();
    for (var txin in tx.txsIn) {
      final derived = down4priv.derive(txin.walletIndex!);
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
    var deps = recDeps([tx]);
    return [...deps, tx];
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
  bool operator ==(other) => other is TXID && other.data == data;
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
    required this.outIndex,
    required this.sequenceNo,
    this.scriptSigLen,
    this.dependance,
  });

  factory Down4TXIN.fromJson(dynamic decodedJson) => Down4TXIN(
        spender: decodedJson["sp"],
        walletIndex: decodedJson["wi"],
        sats: Sats(decodedJson["s"]),
        spentFrom: TXID.fromHex(decodedJson["id"]),
        outIndex: FourByteInt(decodedJson["oi"]),
        sequenceNo: FourByteInt(decodedJson["sn"]),
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
  VarInt scriptPubKeyLen;
  List<int> scriptPubKey;

  Down4TXOUT({
    this.receiver,
    this.walletIndex,
    this.txid,
    this.outIndex,
    required this.sats,
    required this.scriptPubKey,
  }) : scriptPubKeyLen = VarInt.fromInt(scriptPubKey.length);

  factory Down4TXOUT.fromJson(dynamic decodedJson) => Down4TXOUT(
        receiver: decodedJson["rc"],
        walletIndex: decodedJson["wi"],
        outIndex: decodedJson["oi"],
        txid: TXID.fromHex(decodedJson["id"]),
        sats: Sats(decodedJson["s"]),
        scriptPubKey: hex.decode(decodedJson["sc"]),
      );

  List<int> get asData => [
        ...sats.data,
        ...scriptPubKeyLen.data,
        ...scriptPubKey,
      ];

  Map<String, dynamic> toJson() => {
        "rc": receiver,
        "wi": walletIndex,
        "oi": outIndex,
        "id": txid!.asHex,
        "s": sats.asInt,
        "sc": hex.encode(scriptPubKey),
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

  List<int> get asRawData => [
        ...versionNo.data,
        ...inCounter.data,
        ...txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
        ...outCounter.data,
        ...txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
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
      txID = TXID.fromBigEndian(sha256sha256(asRawData.asUint8List()));

  String get asRawHex => hex.encode(asRawData);

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

void main() {
  var scriptSig = hex.decode(
    "4830450221008824eee04a2fbe62d2c3ee330eb2523b2c0188240714bb1d893aced1c454fa9a02202d32dbccc2af1c4b830795f2fa8cd569a06ee70cb9d836bbd510f0b45a47711b4121028580686976c0e6a7e44a78387913e2d7508ff2344d5f48669ba111dcd04170a8",
  );

  var tx = Down4TX(
    maker: "scott",
    nLockTime: 598793,
    versionNo: 1,
    txsIn: [
      Down4TXIN(
        spentFrom: TXID.fromBigEndianHex(
          "b8ed28aa87b92328e26a20553ac49fcb21e1f68daeb6cf7bcf4536e40503ffa8",
        ),
        sats: Sats(100),
        spender: "scott",
        outIndex: FourByteInt(0),
        sequenceNo: FourByteInt(4294967294),
        scriptSig: scriptSig,
        scriptSigLen: VarInt.fromInt(scriptSig.length),
      ),
    ],
    txsOut: [
      Down4TXOUT(
        sats: Sats(1800),
        scriptPubKey: hex.decode(
          "76a9146b0a9ed05da7223a1fe57e1a4d307556f7d6200788ac",
        ),
      ),
      Down4TXOUT(
        sats: Sats(90000),
        scriptPubKey: hex.decode(
          "76a914b993e512cb186f3f1c3f556a09716a1580eb99a188ac",
        ),
      ),
    ],
  );

  var txid = tx.txid();
  print("Tx ID: ${txid.asHex}\nSerialized Tx: ${tx.asRawHex}");

  const full =
      "0100000001a8ff0305e43645cf7bcfb6ae8df6e121cb9fc43a55206ae22823b987aa28edb8000000006b4830450221008824eee04a2fbe62d2c3ee330eb2523b2c0188240714bb1d893aced1c454fa9a02202d32dbccc2af1c4b830795f2fa8cd569a06ee70cb9d836bbd510f0b45a47711b4121028580686976c0e6a7e44a78387913e2d7508ff2344d5f48669ba111dcd04170a8feffffff0208070000000000001976a9146b0a9ed05da7223a1fe57e1a4d307556f7d6200788ac905f0100000000001976a914b993e512cb186f3f1c3f556a09716a1580eb99a188ac09230900";

  print(tx.asRawHex == full);

  const txid_ =
      "d8c5c42cbd1df7e48acab76fe05f2c9e612a20996fd37f4ffd4dc251385b6ba3";

  print(txid.asHex == txid_);

  // print(tx.asJsonString.length); // throws error because no txid in outputs

  // var jeff = VarInt.fromInt(14435729);
  // var andrew = VarInt.fromInt(134250981);

  // print(jeff.toHex());
  // print(andrew.toHex());

  // int dd = 32432;
}
