import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'data_objects.dart';
import 'package:bsv/bsv.dart' as bsv;
import 'package:qr_flutter/qr_flutter.dart' as qr;

extension AsUint8List on List<int> {
  Uint8List asUint8List() => Uint8List.fromList(this);
}

List<int> p2pkh(List<int> address) => [0x76, 0xa9, ...address, 0x88, 0xac];

int deterministicWalletIndex() =>
    (DateTime.now().millisecondsSinceEpoch / 86400000).floor();

class Wallet {
  static const SATS_PER_BYTE = 0.05;
  static const DOWN4_SATS_PER_BYTE = 0.025;
  static final DOWN4_NEUTER = bsv.Bip32().fromHex("TODO");

  bsv.Bip32 bip;
  List<Down4TXOUT> utxos;
  List<Down4TX> unsettledTxs;
  Wallet(this.utxos, this.bip, this.unsettledTxs);

  int get balance => utxos.fold(0, (bal, tx) => bal + tx.sats.asInt);

  void sortUtxos() =>
      utxos.sort(((a, b) => b.sats.asInt.compareTo(a.sats.asInt)));

  List<Down4TXOUT> _requiredOuts(
    List<Node> targets,
    Node self,
    Sats sats,
    int walletIndex,
  ) {
    List<Down4TXOUT> outs = [];
    Sats satsPerTarget = Sats((sats.asInt / targets.length).floor());
    for (int i = 0; i < targets.length; i++) {
      final targetPubKey = targets[i].neuter!.deriveChild(walletIndex).pubKey;
      final address = bsv.Address.fromPubKey(targetPubKey!).hashBuf!;
      outs.add(Down4TXOUT(
        receiver: targets[i].id,
        walletIndex: walletIndex,
        outIndex: i,
        sats: satsPerTarget,
        scriptPubKey: p2pkh(address),
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
        txid: utxos[i].txid!,
        outIndex: FourByteInt(utxos[i].outIndex!),
        sequenceNo: FourByteInt(0),
      ));

      sats = Sats(sats.asInt + utxos[i].sats.asInt);
      minerFees = Sats(minerFees.asInt + (148 * SATS_PER_BYTE).ceil());
      down4Fees = Sats((minerFees.asInt / 2).ceil());

      if (sats > minerFees + pay + down4Fees) {
        return [ins, minerFees, down4Fees];
      }
    }
    return null;
  }

  Down4TX? pay(List<Node> targets, Node self, Sats amount) {
    sortUtxos();
    final walletIndex = deterministicWalletIndex();
    var outs = _requiredOuts(targets, self, amount, walletIndex);
    var inInfo = _unsignedIns(self, amount, targets.length + 2);
    if (inInfo == null) return null;
    List<Down4TXIN> txsIn = inInfo[0];
    Sats minerFees = inInfo[1];
    Sats down4Fees = inInfo[2];
    final inAmount = txsIn.fold<Sats>(Sats(0), (tot, tx) => tot + tx.sats!);

    // add the change
    final changeAmount = inAmount - amount - minerFees - down4Fees;
    final changePubKey = self.neuter!.deriveChild(walletIndex).pubKey!;
    final changeAdress = bsv.Address.fromPubKey(changePubKey);
    outs.add(Down4TXOUT(
      sats: changeAmount,
      scriptPubKey: p2pkh(changeAdress.hashBuf!),
      walletIndex: walletIndex,
      receiver: self.id,
      outIndex: outs.length,
    ));

    // add the relay tax
    final relayPubKey = DOWN4_NEUTER.deriveChild(walletIndex).pubKey!;
    final relayChangeAddress = bsv.Address.fromPubKey(relayPubKey);
    outs.add(Down4TXOUT(
      sats: down4Fees,
      scriptPubKey: p2pkh(relayChangeAddress.hashBuf!),
      walletIndex: walletIndex,
      outIndex: outs.length,
    ));

    // here we should have all the tx data necessary for signing
    var tx = Down4TX(txsIn: txsIn, maker: self.id, txsOut: outs);
    final txdata = tx.asData;
    for (var txin in tx.txsIn) {
      final pk = bip.deriveChild(txin.walletIndex!).privKey!;
      final kp = bsv.KeyPair.fromPrivKey(pk);
      var ecdsa = bsv.Ecdsa(
        endian: Endian.little,
        hashBuf: bsv.Hash.sha256(txdata.asUint8List()).data,
        keyPair: kp,
      );
      ecdsa.sign();
      final signature = ecdsa.sig!.toTxFormat();
      final unlockScript = [...signature, ...kp.pubKey!.toBuffer()];
      txin.script = unlockScript;
    }
    final txid = tx.txid();
    for (var txout in tx.txsOut) {
      txout.txid = txid;
    }
    return tx;
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
  List<int> txid;
  FourByteInt outIndex, sequenceNo;
  VarInt? scriptSigLen;
  List<int>? scriptSig;

  Down4TXIN({
    this.spender,
    this.walletIndex,
    this.sats,
    required this.txid,
    this.scriptSig,
    required this.outIndex,
    required this.sequenceNo,
    this.scriptSigLen,
  });

  factory Down4TXIN.fromJson(dynamic decodedJson) => Down4TXIN(
        spender: decodedJson["sp"],
        walletIndex: decodedJson["wi"],
        sats: Sats(decodedJson["s"]),
        txid: decodedJson["id"],
        outIndex: FourByteInt(decodedJson["oi"]),
        sequenceNo: FourByteInt(decodedJson["sn"]),
        scriptSigLen: VarInt.fromInt(decodedJson["sl"]),
        scriptSig: hex.decode(decodedJson["sc"]),
      );

  List<int> get asData => [
        ...txid,
        ...scriptSigLen!.data,
        ...scriptSig!,
        ...sequenceNo.data,
      ];

  set script(List<int> script) {
    scriptSig = script;
    scriptSigLen = VarInt.fromInt(script.length);
  }

  Map<String, dynamic> toJson() => {
        "sp": spender!,
        "wi": walletIndex!,
        "s": sats!.asInt,
        "id": hex.encode(txid),
        "oi": outIndex.asInt,
        "sn": sequenceNo.asInt,
        "sl": scriptSigLen!.asInt,
        "sc": hex.encode(scriptSig!),
      };
}

class Down4TXOUT {
  Identifier? receiver;
  int? walletIndex, outIndex;
  List<int>? txid;
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
        txid: decodedJson["id"],
        sats: Sats(decodedJson["s"]),
        scriptPubKey: hex.decode(decodedJson["sc"]),
      );

  List<int> get asData => [
        ...sats.data,
        ...scriptPubKeyLen.data,
        ...scriptPubKey,
      ];

  Map<String, dynamic> toJson() => {
        "rc": receiver!,
        "wi": walletIndex!,
        "oi": outIndex!,
        "id": txid!,
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
  List<int>? txID;

  Down4TX({
    this.maker,
    int? pVersionNo,
    int? pNLockTime,
    required this.txsIn,
    required this.txsOut,
  })  : versionNo = FourByteInt(pVersionNo ?? 2),
        nLockTime = FourByteInt(pNLockTime ?? 0),
        inCounter = VarInt.fromInt(txsIn.length),
        outCounter = VarInt.fromInt(txsOut.length);

  factory Down4TX.fromJson(dynamic decodedJson) => Down4TX(
        maker: decodedJson["mk"],
        pVersionNo: decodedJson["vn"],
        pNLockTime: decodedJson["nl"],
        txsIn: List<dynamic>.from(decodedJson["ti"])
            .map((encodedIn) => Down4TXIN.fromJson(jsonDecode(encodedIn)))
            .toList(),
        txsOut: List<dynamic>.from(decodedJson["ti"])
            .map((encodedOut) => Down4TXOUT.fromJson(jsonDecode(encodedOut)))
            .toList(),
      );

  List<int> get asData => [
        ...versionNo.data,
        ...inCounter.data,
        ...txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
        ...outCounter.data,
        ...txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
        ...nLockTime.data,
      ];

  List<int> txid() =>
      txID = bsv.Hash.sha256Sha256(asData.asUint8List()).toBuffer();

  String get asHex => hex.encode(asData);

  Map<String, dynamic> toJson() => {
        "mk": maker!,
        "vn": versionNo.asInt,
        "nl": nLockTime.asInt,
        "ti": txsIn.map((txin) => txin.toJson()),
        "ic": inCounter.asInt,
        "to": txsOut.map((txout) => txout.toJson()),
        "oc": outCounter.asInt,
        "id": hex.encode(txID!),
      };

  String get asQrData => jsonEncode(this);
}

main() {
  var jeff = VarInt.fromInt(14435729);
  var andrew = VarInt.fromInt(134250981);

  print(jeff.toHex());
  print(andrew.toHex());

  int dd = 32432;
}
