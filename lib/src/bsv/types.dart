import 'dart:typed_data';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

import '../down4_utility.dart';
import '../data_objects.dart';
import 'utils.dart';

final secp256k1 = ECCurve_secp256k1();
const SATS_PER_BYTE = 0.05;
final DOWN4_NEUTER = Down4Keys.fromJson({
  "pub": "02ace06b1e02ed686f9f312198aea81254799e991b2ddcea1676aaa43ae9fcac50",
  "cc": "0000000000000000000000000000000000000000000000000000000000000000",
});

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

  List<int> toData() => utf8.encode(jsonEncode(this));
}

class Down4Payment {
  final List<Down4TX> txs;
  final bool safe;
  String? textNote;
  List<Uint8List>? qrPngs;
  Down4Payment(this.txs, this.safe, {this.textNote, this.qrPngs});

  int get independentGets {
    final tx = txs.last;
    return tx.txsOut
        .firstWhere((txOut) => !(txOut.isFee || txOut.isChange))
        .sats
        .asInt;
  }

  String get formattedName {
    final tx = txs.last;
    final spender = txs.last.txsIn.first.spender ?? "";
    String receivers = "";
    int singularGets = tx.txsOut.firstWhere((txOut) => txOut.isGets).sats.asInt;
    int count = 0;
    for (final txOut in txs.last.txsOut) {
      if (txOut.isGets) {
        receivers += txOut.receiver! + " ";
        count += 1;
      }
    }

    if (count > 1) {
      return spender + " --$count x $singularGets--> " + receivers;
    } else {
      return spender + " --$singularGets--> " + receivers;
    }
  }

  String get id {
    final idFold = txs.fold<List<int>>([], (prev, tx) => prev + tx.txID!.data);
    return sha256(idFold.asUint8List()).toHex();
  }

  int get lastConfirmations => txs.last.confirmations;

  @override
  int get hashCode => BigInt.parse(id, radix: 16).hashCode;

  @override
  operator ==(other) => other is Down4Payment && other.id == id;

  List<String> toJsonList() {
    var asData = base64Encode(utf8.encode(jsonEncode(txs)));
    var theList = <String>[];
    var len = asData.length;
    var devider = 1;
    while (len / devider > 1000) {
      devider = devider + 1;
    }
    var devided = (len / devider).ceil();
    for (int i = 0; i < devider; i++) {
      Map<String, dynamic> obj = {"index": i, "tot": devider};
      if (i == devider - 1) {
        obj["data"] = asData.substring(i * devided);
      } else {
        obj["data"] = asData.substring(i * devided, (i + 1) * devided);
      }
      theList.add(jsonEncode(obj));
    }
    return theList;
  }

  factory Down4Payment.fromJsonList(List<String> dataList) {
    final fullData = dataList.join("");
    final jsonTxs = jsonDecode(utf8.decode(base64Decode(fullData)));
    final txs = List.from(jsonTxs)
        .map((e) => Down4TX.fromJson(e))
        .toList(growable: false);
    return Down4Payment(txs, true);
  }

  Map<String, dynamic> toJsoni(int i) => {
        "tx": txs[i].toJson(),
        "len": txs.length,
        "safe": safe,
      };

  Map<String, dynamic> toJson({bool withImages = false}) => {
        "id": id,
        "tx": txs.map((tx) => tx.toJson()).toList(),
        "len": txs.length,
        "safe": safe,
        if (textNote != null) "txt": textNote,
        if (withImages && qrPngs != null)
          "qrs": qrPngs!.map((qr) => base64Encode(qr)).toList(growable: false),
      };

  String toYouKnow() => base64Encode(utf8.encode(jsonEncode(this)));

  factory Down4Payment.fromYouKnow(String youKnow) {
    return Down4Payment.fromJson(
      jsonDecode(utf8.decode(base64Decode(youKnow))),
    );
  }

  factory Down4Payment.fromJson(dynamic decodedJson) {
    return Down4Payment(
      List<dynamic>.from(decodedJson["tx"])
          .map((e) => Down4TX.fromJson(e))
          .toList(),
      decodedJson["safe"],
      textNote: decodedJson["txt"],
      qrPngs: decodedJson["qrs"] == null
          ? null
          : List<String>.from(decodedJson["qrs"])
              .map((b) => base64Decode(b))
              .toList(growable: false),
    );
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
        ..buffer.asByteData().setUint16(1, n);
    } else if (n >= 65536 && n <= 4294967295) {
      data = Uint8List(5)
        ..buffer.asByteData().setUint8(0, 0xFE)
        ..buffer.asByteData().setUint32(1, n);
    } else {
      data = Uint8List(9)
        ..buffer.asByteData().setUint8(0, 0xFF)
        ..buffer.asByteData().setUint64(1, n);
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

  factory TXID.fromHex(String h) => TXID(hex.decode(h).reversed.toList());

  // factory TXID.fromBigEndian(List<int> be) => TXID(be.reversed.toList());
  //
  // factory TXID.fromBigEndianHex(String beh) =>
  //     TXID(hex.decode(beh).reversed.toList());

  // List<int> get asBigEndian => data.reversed.toList();

  String get asHex => data.reversed.toList().toHex();

  // String get asHexBigEndian => data.reversed.toList().toHex();

  // bool equals(TXID other) => data == other.data;

  @override
  int get hashCode => BigInt.parse(asHex, radix: 16).hashCode;

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
  Down4TXOUT utxo;
  Identifier? spender;
  VarInt? _scriptSigLen;
  List<int>? _scriptSig;
  TXID? dependance;
  FourByteInt sequenceNo;

  Down4TXIN({
    required this.utxo,
    int? scriptSigLen,
    List<int>? scriptSig,
    this.spender,
    int? sequenceNo,
    this.dependance,
  })  : sequenceNo = FourByteInt(sequenceNo ?? 0xFFFFFFFF),
        _scriptSig = scriptSig,
        _scriptSigLen =
            scriptSigLen != null ? VarInt.fromInt(scriptSigLen) : null;

  // factory Down4TXIN.fromP2PKH(Down4TXOUT txOut) {
  //   return Down4TXIN(
  //     utxo: txOut,
  //     spender: txOut.receiver,
  //     sequenceNo: 0,
  //   );
  // }
  List<int>? get scriptSig => _scriptSig;

  factory Down4TXIN.fromJson(dynamic decodedJson) => Down4TXIN(
        utxo: Down4TXOUT.fromJson(decodedJson["utxo"]),
        spender: decodedJson["sp"],
        sequenceNo: decodedJson["sn"],
        scriptSigLen: decodedJson["sl"],
        scriptSig: hex.decode(decodedJson["sc"]),
        dependance:
            decodedJson["dp"] != null ? TXID.fromHex(decodedJson["dp"]) : null,
      );

  List<int> get asData => [
        ...utxo.txid!.data,
        ...FourByteInt(utxo.outIndex!).data,
        ..._scriptSigLen!.data,
        ..._scriptSig!,
        ...sequenceNo.data,
      ];

  List<int> get seqNo => sequenceNo.data;

  List<int> get prevOut => [
        ...utxo.txid!.data,
        ...FourByteInt(utxo.outIndex!).data,
      ];

  set script(List<int> script) {
    _scriptSig = script;
    _scriptSigLen = VarInt.fromInt(script.length);
  }

  Map<String, dynamic> toJson() => {
        "utxo": utxo.toJson(),
        "sp": spender,
        "sn": sequenceNo.asInt,
        "sl": _scriptSigLen?.asInt,
        "sc": _scriptSig!.toHex(),
        "dp": dependance?.asHex,
      };
}

class Down4TXOUT {
  Identifier? receiver;
  int? outIndex;
  List<int>? secret;
  TXID? txid;
  Sats sats;
  VarInt? scriptPubKeyLen;
  List<int>? scriptPubKey;
  final bool isChange;
  final bool isFee;

  Down4TXOUT({
    this.isChange = false,
    this.isFee = false,
    this.receiver,
    this.secret,
    this.txid,
    this.outIndex,
    required this.sats,
    this.scriptPubKey,
  }) : scriptPubKeyLen = VarInt.fromInt(scriptPubKey?.length ?? 0);

  factory Down4TXOUT.fromJson(dynamic decodedJson) => Down4TXOUT(
        receiver: decodedJson["rc"],
        secret: decodedJson["st"] != null
            ? List<int>.from(decodedJson["st"])
            : null,
        outIndex: decodedJson["oi"],
        txid: TXID.fromHex(decodedJson["id"]),
        sats: Sats(decodedJson["s"]),
        isChange:
            decodedJson["ic"] ?? false, // TODO the ?? false should be removed
        isFee:
            decodedJson["if"] ?? false, // TODO the ?? false should be removed
        scriptPubKey: hex.decode(decodedJson["sc"]),
      );

  set scriptLen(int n) => scriptPubKeyLen = VarInt.fromInt(n);

  String get id =>
      sha256((txid!.data + FourByteInt(outIndex!).data).asUint8List()).toHex();

  bool get isGets => !(isFee || isChange);

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
        "if": isFee,
        "ic": isChange,
        "rc": receiver,
        "st": secret,
        "oi": outIndex,
        "id": txid!.asHex,
        "s": sats.asInt,
        "sc": hex.encode(scriptPubKey!),
      };
}

class Down4TX {
  Identifier? maker;
  FourByteInt versionNo, nLockTime;
  List<Down4TXIN> txsIn;
  List<Down4TXOUT> txsOut;
  VarInt inCounter, outCounter;
  TXID? txID;
  int confirmations;

  Down4TX({
    this.maker,
    int? versionNo,
    int? nLockTime,
    required this.txsIn,
    required this.txsOut,
    this.txID,
    this.confirmations = 0,
  })  : versionNo = FourByteInt(versionNo ?? 1),
        nLockTime = FourByteInt(nLockTime ?? 0),
        inCounter = VarInt.fromInt(txsIn.length),
        outCounter = VarInt.fromInt(txsOut.length);

  factory Down4TX.fromJson(dynamic decodedJson) => Down4TX(
        maker: decodedJson["mk"],
        versionNo: decodedJson["vn"],
        nLockTime: decodedJson["nl"],
        confirmations: decodedJson["cf"],
        txID: TXID.fromHex(decodedJson["id"]),
        txsIn: List.from(decodedJson["ti"])
            .map((jsonIn) => Down4TXIN.fromJson(jsonIn))
            .toList(),
        txsOut: List.from(decodedJson["to"])
            .map((jsonOut) => Down4TXOUT.fromJson(jsonOut))
            .toList(),
      );

  List<int> get raw {
    return [
      ...versionNo.data,
      ...inCounter.data,
      ...txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
      ...outCounter.data,
      ...txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.asData]),
      ...nLockTime.data,
    ];
  }

  List<int>? sigData(int nIn, [int sigHashType = SIG.ALL]) {
    switch (sigHashType) {
      case SIG.ALL:
        return [
          ...versionNo.data,
          ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.prevOut])),
          ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.seqNo])),
          ...txsIn[nIn].prevOut,
          ...txsIn[nIn].utxo.scriptPubKeyLen!.data,
          ...txsIn[nIn].utxo.scriptPubKey!,
          ...txsIn[nIn].utxo.sats.data,
          ...txsIn[nIn].sequenceNo.data,
          ...hash256(txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.asData])),
          ...nLockTime.data,
          ...FourByteInt(sigHashType).data,
        ];
      case SIG.SINGLE:
        return [
          ...versionNo.data,
          ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.prevOut])),
          ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.seqNo])),
          ...txsIn[nIn].prevOut,
          ...txsIn[nIn].utxo.scriptPubKeyLen!.data,
          ...txsIn[nIn].utxo.scriptPubKey!,
          ...txsIn[nIn].utxo.sats.data,
          ...txsIn[nIn].sequenceNo.data,
          ...hash256(txsOut[nIn].asData),
          ...nLockTime.data,
          ...FourByteInt(sigHashType).data,
        ];
      case SIG.NONE:
        return [
          ...versionNo.data,
          ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.prevOut])),
          ...hash256(txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.seqNo])),
          ...txsIn[nIn].prevOut,
          ...txsIn[nIn].utxo.scriptPubKeyLen!.data,
          ...txsIn[nIn].utxo.scriptPubKey!,
          ...txsIn[nIn].utxo.sats.data,
          ...txsIn[nIn].sequenceNo.data,
          ...Uint8List(32),
          ...nLockTime.data,
          ...FourByteInt(sigHashType).data,
        ];
      case SIG.ALL_ANYONECANPAY:
        return [
          ...versionNo.data,
          ...Uint8List(32),
          ...Uint8List(32),
          ...txsIn[nIn].prevOut,
          ...txsIn[nIn].utxo.scriptPubKeyLen!.data,
          ...txsIn[nIn].utxo.scriptPubKey!,
          ...txsIn[nIn].utxo.sats.data,
          ...txsIn[nIn].sequenceNo.data,
          ...hash256(txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.asData])),
          ...nLockTime.data,
          ...FourByteInt(sigHashType).data,
        ];
      case SIG.SINGLE_ANYONECANPAY:
        return [
          ...versionNo.data,
          ...Uint8List(32),
          ...Uint8List(32),
          ...txsIn[nIn].prevOut,
          ...txsIn[nIn].utxo.scriptPubKeyLen!.data,
          ...txsIn[nIn].utxo.scriptPubKey!,
          ...txsIn[nIn].utxo.sats.data,
          ...txsIn[nIn].sequenceNo.data,
          ...hash256(txsOut[nIn].asData),
          ...nLockTime.data,
          ...FourByteInt(sigHashType).data,
        ];
      case SIG.NONE_ANYONECANPAY:
        return [
          ...versionNo.data,
          ...Uint8List(32),
          ...Uint8List(32),
          ...txsIn[nIn].prevOut,
          ...txsIn[nIn].utxo.scriptPubKeyLen!.data,
          ...txsIn[nIn].utxo.scriptPubKey!,
          ...txsIn[nIn].utxo.sats.data,
          ...txsIn[nIn].sequenceNo.data,
          ...Uint8List(32),
          ...nLockTime.data,
          ...FourByteInt(sigHashType).data,
        ];
    }
    return null;
  }

  List<TXID> get txidDeps {
    return txsIn.fold(<TXID>[], (deps, txin) {
      if (txin.dependance != null) {
        return deps..add(txin.dependance!);
      } else {
        return deps;
      }
    });
  }

  TXID txid() => txID = TXID(hash256(raw.asUint8List()));

  String get fullRawHex => hex.encode(raw);

  Map<String, dynamic> toJson([bool withTxs = true]) => {
        "mk": maker,
        "vn": versionNo.asInt,
        "nl": nLockTime.asInt,
        "id": txID!.asHex,
        "cf": confirmations,
        if (withTxs) "ti": txsIn.map((txin) => txin.toJson()).toList(),
        if (withTxs) "to": txsOut.map((txout) => txout.toJson()).toList(),
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
  })  : id = TXID.fromHex(pID),
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

class OP {
  static const FALSE = 0x00;

  static List<int> PUSHDATA(List<int> data) {
    final len = data.length;
    if (len >= 1 && len <= 75) {
      return [len, ...data];
    } else if (len >= 76 && len <= 255) {
      return [0x4c, len, ...data];
    } else if (len >= 256 && len <= 65535) {
      final twoBytes = Uint8List(2)..buffer.asByteData().setInt64(0, len);
      return [0x4d, ...twoBytes, ...data];
    } else if (len >= 65536 && len <= 4294967295) {
      final fourBytes = Uint8List(4)..buffer.asByteData().setInt64(0, len);
      return [0x4e, ...fourBytes, ...data];
    }
    throw "error, can't push $len bytes of data";
  }

  static const ONE_NEGATE = 0x4f;
  static const TRUE = 0x51;
  static const NOP = 0x61;
  static const IF = 0x63;
  static const NOTIF = 0x64;
  static const ELSE = 0x67;
  static const ENDIF = 0x68;
  static const VERIFY = 0x69;
  static const RETURN = 0x6a;
  static const TOALTSTACK = 0x6b;
  static const FROMALTSTACK = 0x6c;
  static const DROP2 = 0x6d;
  static const DUP2 = 0x6e;
  static const DUP3 = 0x6f;
  static const OVER2 = 0x70;
  static const ROT2 = 0x71;
  static const SWAP2 = 0x72;
  static const IFDUP = 0x73;
  static const DEPTH = 0x74;
  static const DROP = 0x75;
  static const DUP = 0x76;
  static const NIP = 0x77;
  static const OVER = 0x78;
  static const PICK = 0x79;
  static const ROLL = 0x7a;
  static const ROT = 0x7b;
  static const SWAP = 0x7c;
  static const TUCK = 0x7d;
  static const CAT = 0x7e;
  static const SPLIT = 0x7f;
  static const NUM2BIN = 0x80;
  static const BIN2NUM = 0x81;
  static const SIZE = 0x82;
  static const INVERT = 0x83;
  static const AND = 0x84;
  static const OR = 0x85;
  static const XOR = 0x86;
  static const EQUAL = 0x87;
  static const EQUALVERIFY = 0x88;
  static const ADD1 = 0x8b;
  static const SUB1 = 0x8c;
  static const NEGATE = 0x8f;
  static const ABS = 0x90;
  static const NOT = 0x91;
  static const ZERO_NOTEQUAL = 0x92;
  static const ADD = 0x93;
  static const SUB = 0x94;
  static const MUL = 0x95;
  static const DIV = 0x96;
  static const MOD = 0x97;
  static const LSHIFT = 0x98;
  static const RSHIFT = 0x99;
  static const BOOLAND = 0x9a;
  static const BOOLOR = 0x9b;
  static const NUMEQUAL = 0x9c;
  static const NUMEQUALVERIFY = 0x9d;
  static const NUMNOTEQUAL = 0x9e;
  static const LESSTHAN = 0x9f;
  static const GREATERTHAN = 0xa0;
  static const LESSTHANOREQUAL = 0xa1;
  static const GREATERTHANOREQUAL = 0xa2;
  static const MIN = 0xa3;
  static const MAX = 0xa4;
  static const WITHIN = 0xa5;
  static const RIPEMD160 = 0xa6;
  static const SHA1 = 0xa7;
  static const SHA256 = 0xa8;
  static const HASH160 = 0xa9;
  static const HASH256 = 0xaa;
  static const CODESEPARATOR = 0xab;
  static const CHECKSIG = 0xac;
  static const CHECKSIGVERIFY = 0xad;
  static const CHECKMULTISIG = 0xae;
  static const CHECKMULTISIGVERIFY = 0xaf;
}

class SIG {
  static const ALL = 0x41;
  static const NONE = 0x42;
  static const SINGLE = 0x43;
  static const ALL_ANYONECANPAY = 0xc1;
  static const NONE_ANYONECANPAY = 0xc2;
  static const SINGLE_ANYONECANPAY = 0xc3;
}

class Down4Keys {
  ECPublicKey publicKey;
  ECPrivateKey? privateKey;
  Uint8List chainCode;

  Down4Keys._({
    required this.publicKey,
    this.privateKey,
    Uint8List? chainCode,
  }) : chainCode = chainCode ?? Uint8List(32);

  ECSignature? sha256Sign(Uint8List message) {
    if (privateKey == null) return null;
    var pkParam = PrivateKeyParameter(privateKey!);

    var signer = Signer('SHA-256/DET-ECDSA');
    signer.init(true, pkParam);

    var sig = signer.generateSignature(message.asUint8List()) as ECSignature;
    return sig.normalize(secp256k1);
  }

  bool verify(Uint8List message, ECSignature sig) {
    var pbParam = PublicKeyParameter(publicKey);

    var verifier = Signer('SHA-256/DET-ECDSA');
    verifier.init(false, pbParam);

    return verifier.verifySignature(message, sig);
  }

  Down4Keys? derive(List<int> secret) {
    var hmac = Mac('SHA-512/HMAC');
    hmac.init(KeyParameter(chainCode));

    var xString = publicKey.Q!.x!.toBigInteger()!.toRadixString(16);
    var yString = publicKey.Q!.y!.toBigInteger()!.toRadixString(16);
    if (xString.length % 2 != 0) xString = '0' + xString;
    if (yString.length % 2 != 0) yString = '0' + yString;

    final bigX = hex.decode(xString);
    final bigY = hex.decode(yString);

    final data = bigX + bigY + secret;

    final out = hmac.process(data.asUint8List());
    final left = out.sublist(0, 32);
    final right = out.sublist(32, 64);

    final big = BigInt.parse(right.toHex(), radix: 16);

    final bigPoint = secp256k1.G * big;
    if (bigPoint == null) return null;
    final newPoint = bigPoint + publicKey.Q!;
    final pub = ECPublicKey(newPoint, secp256k1);

    if (isNeutered) {
      return Down4Keys._(publicKey: pub, chainCode: left);
    } else {
      final newScalar = (privateKey!.d! + big) % secp256k1.n;
      final prv = ECPrivateKey(newScalar, secp256k1);
      return Down4Keys._(publicKey: pub, privateKey: prv, chainCode: left);
    }
  }

  List<int> get rawAddress => hash160(publicKey.Q!.getEncoded());

  String get checkAddressB58 => mainetAddress(rawCompressedPub).toBase58();

  bool get isNeutered => privateKey == null;

  String get compressedPubKeyHex => rawCompressedPub.toHex();

  Uint8List get rawCompressedPub => publicKey.Q!.getEncoded();

  String? get privKeyHex => privateKey?.d?.toRadixString(16);

  String get privKeyBase58 => privKeyHex!.length % 2 == 0
      ? hex.decode(privKeyHex!).toBase58()
      : hex.decode('0' + privKeyHex!).toBase58();

  Down4Keys neutered() =>
      Down4Keys._(publicKey: publicKey, chainCode: chainCode);

  Map<String, dynamic> toJson() => {
        if (!isNeutered) "prv": privKeyHex,
        "pub": compressedPubKeyHex,
        "cc": chainCode.toHex(),
      };

  String toYouKnow() => base64Encode(utf8.encode(jsonEncode(this)));

  factory Down4Keys.fromYouKnow(String youKnow) {
    return Down4Keys.fromJson(jsonDecode(utf8.decode(base64Decode(youKnow))));
  }

  factory Down4Keys.fromJson(dynamic decodedJson) {
    final chainCode = hex.decode(decodedJson["cc"]).asUint8List();
    ECPrivateKey? prv;
    if (decodedJson["prv"] != null) {
      var big = BigInt.parse(decodedJson["prv"], radix: 16);
      prv = ECPrivateKey(big, secp256k1);
    }

    final pubByte = hex.decode(decodedJson["pub"]).asUint8List();
    final pub = uncompressPublicKey(pubByte);

    return Down4Keys._(publicKey: pub, chainCode: chainCode, privateKey: prv);
  }

  factory Down4Keys.fromRandom(Uint8List keySeed, Uint8List chainCodeSeed) {
    var chainCode = sha256(chainCodeSeed).asUint8List();

    var keyParams = ECKeyGeneratorParameters(secp256k1);

    var random = FortunaRandom();
    random.seed(KeyParameter(keySeed));

    var generator = ECKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, random));

    final pair = generator.generateKeyPair();

    return Down4Keys._(
      publicKey: pair.publicKey as ECPublicKey,
      privateKey: pair.privateKey as ECPrivateKey,
      chainCode: chainCode,
    );
  }

  factory Down4Keys.fromPrivateKey(BigInt d, [Uint8List? cc]) {
    final pk = ECPrivateKey(d, secp256k1);
    final pubPoint = secp256k1.G * d;
    final pub = ECPublicKey(pubPoint, secp256k1);

    return Down4Keys._(publicKey: pub, privateKey: pk);
  }
}

void main() {
  print("What the fuck is going on");

  var lol = 0x41;
  var jk = 0x01 | 0x40;
  print(lol == jk);

  // final seed = List<int>.generate(32, (index) => (index * 23) % 256);
  // final seed2 = List<int>.generate(32, (index) => (index * 21) % 256);
  // var keys = Down4Keys.fromRandom(seed.asUint8List(), seed2.asUint8List());
  //
  // var keys1 = keys.derive(makeUint32(1));
  // var keys2 = keys.derive(makeUint32(2));
  //
  // print("Keys 0: ${keys.toJson()}");
  // print("Keys 1: ${keys1!.toJson()}");
  // print("Keys 2: ${keys2!.toJson()}");
}
