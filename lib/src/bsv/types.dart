import 'dart:typed_data';
import 'dart:convert';
import 'dart:io' as io;

import 'package:convert/convert.dart';
import 'package:down4/src/bsv/wallet.dart';
import 'package:down4/src/data_objects/couch.dart';
import 'package:pointycastle/export.dart';
import 'package:base85/base85.dart';

import '../globals.dart' show g;
import '../_dart_utils.dart';
import '../web_requests.dart' as r;

import '../data_objects/_data_utils.dart';

import '_bsv_utils.dart';

final secp256k1 = ECCurve_secp256k1();
const SATS_PER_BYTE = 0.05;
final DOWN4_NEUTER = Down4Keys.fromJson({
  "pub": "02ace06b1e02ed686f9f312198aea81254799e991b2ddcea1676aaa43ae9fcac50",
  "cc": "0000000000000000000000000000000000000000000000000000000000000000",
});

enum UtxoType { fee, change, gets, tip, tax }

enum BR {
  ok(200),
  badRequest(400),
  badUnlockScript(461),
  invalidInputs(462),
  malformed(463),
  feeTooLow(465),
  txConflict(466),
  frozenInputs(472);

  final int code;
  const BR(this.code);
}

extension on List<Down4TX> {
  Uint8List get compressFold {
    Iterable<int> it = [];
    int l = 0;
    for (final tx in this) {
      final cp = tx.compressed2;
      l += cp.length;
      it = it.followedBy(cp);
    }

    var buf = Uint8List(l);
    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }
    return buf;
  }
}

extension on List<Down4TXOUT> {
  Uint8List get compressFold {
    Iterable<int> it = [];
    int l = 0;
    for (final txout in this) {
      final cp = txout.compressed2;
      l += cp.length;
      it = it.followedBy(cp);
    }

    var buf = Uint8List(l);
    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }
    return buf;
  }
}

extension on List<Down4TXIN> {
  Uint8List get compressFold {
    Iterable<int> it = [];
    int l = 0;
    for (final txin in this) {
      final cp = txin.compressed2;
      l += cp.length;
      it = it.followedBy(cp);
    }

    var buf = Uint8List(l);
    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }
    return buf;
  }
}

class Down4Payment with Down4Object, Jsons, Locals, Temps {
  @override
  final Down4ID id;

  final ComposedID? spender;

  void fullMerge() {
    for (final tx in txs) {
      tx.merge(ifNotPresent: true);
      for (final txin in tx.txsIn) {
        txin.merge(ifNotPresent: true);
      }
      for (final txout in tx.txsOut) {
        txout.merge(ifNotPresent: true);
      }
    }
    merge(ifNotPresent: true);
  }

  Future<void> trySettlement() async {
    if (confirmations != -1) {
      return print("transactions has already been accepted!");
    }
    
    if (validForBroadcast) {
      return r.broadcastTxs(txs);
    } else {
      print("""
        ================== WARNING =====================
        Payment id: ${id.value} is invalid for broadcast
        """);
    }
  }

  final TXID txid;

  int get confirmations {
    if (txs.isEmpty) {
      return 100;
    } else {
      return txs.last.confirmations;
    }
  }

  List<ComposedID> get receivers {
    final xs = txs;
    if (xs.isEmpty) return [];
    List<ComposedID> rcs = [];
    for (final outs in xs.last.txsOut) {
      final rc = outs.receiver;
      if (rc != null) rcs.add(rc);
    }
    return rcs;
  }

  @override
  String get table => "payments";

  List<Down4TX>? _txs;
  final bool safe;
  final String textNote;
  final int timestamp;

  // this is information we calculate on parsePayment()
  // that are then displayed in payments...
  int? plusMinus;
  double? tipPercentage, discountPercentage;

  void calculatePlusMinus({required ComposedID selfID}) {
    int pm = 0;
    for (final txout in txs.last.txsOut) {
      if (txout.receiver == selfID) {
        pm += txout.sats.asInt;
      }
    }
    for (final txin in txs.last.txsIn) {
      if (txin.spender == selfID) {
        pm -= local<Down4TXOUT>(txin.utxoID)!.sats.asInt;
      }
    }
    plusMinus = pm;
  }

  @override
  Uint8List get tempPayload => compressed.toUint8List();

  @override
  Map<String, String>? get tempPayloadMetadata => null;

  @override
  void updateTempReferences(ComposedID newTempID, int newTempTS) {
    final currentTS = tempTS ?? 0;
    if (currentTS >= newTempTS) return;
    merge(vals: {
      "tempTS": (_tempTS = newTempTS).toString(),
      "tempID": (_tempID = newTempID).value,
    });
  }

  List<Down4TX> get txs {
    List<Down4TX> loadEm() {
      final head = Wallet.loadTX(txid.asBase64);
      if (head == null) return [];
      return Wallet.fullChain(head);
    }

    return _txs ??= loadEm();
  }

  // Iterable<Down4ID> get chain => [...Wallet.dependances(txid), txid].asDown4IDs();

  ComposedID? _tempID;
  int? _tempTS;

  @override
  ComposedID? get tempID => _tempID;

  @override
  int? get tempTS => _tempTS;

  double? discount, tip;

  bool get validForBroadcast {
    for (final tx in txs) {
      final hasAllTxins = tx.ins.length == tx.txsIn.length;
      final hasAllTxouts = tx.outs.length == tx.txsOut.length;
      if (!(hasAllTxins && hasAllTxouts)) return false;
    }
    return true;
  }

  Down4Payment(
    this.id, {
    required this.txid,
    required List<Down4TX>? txs,
    required this.spender,
    this.plusMinus,
    this.discount,
    this.tip,
    required this.safe,
    required this.textNote,
    int? tempTS,
    ComposedID? tempID,
    int? timestamp,
  })  : timestamp = timestamp ?? makeTimestamp(),
        _tempTS = tempTS,
        _tempID = tempID,
        _txs = txs;

  int get independentGets => plusMinus!;

  String get formattedName {
    final pm = plusMinus ?? 0;
    if (pm > 0) {
      return "+$pm";
    } else {
      return pm.toString();
    }
  }

  @override
  int get hashCode => sha1(id.value.codeUnits).toUtf16().hashCode;

  @override
  operator ==(other) => other is Down4Payment && other.id == id;

  List<int> get compressed {
    final t1 = makeTimestamp();
    final tNote = textNote.codeUnits;

    print("compressing ${txs.length} txs");
    final buf = [
      safe ? 0x01 : 0x00,
      ...VarInt.fromInt(tNote.length).data,
      ...tNote,
      // ...utf8.encode(textNote),
      ...VarInt.fromInt(txs.length).data,
      ...txs.fold<List<int>>(<int>[], (p, e) => p + e.compressed),
      // ...utf8.encode(timestamp.toRadixString(34)),
      ...timestamp.toRadixString(34).codeUnits,
    ];

    final t2 = makeTimestamp();
    print("Down4Payment compressed took: ${t2 - t1} ms");
    return buf;
  }

  List<int> get compressed2 {
    final t1 = makeTimestamp();

    final tl = VarInt.fromInt(textNote.length);
    final tn = utf8.encode(textNote);
    final txl = VarInt.fromInt(txs.length);
    final ctxs = txs.compressFold;
    final ts = utf8.encode(timestamp.toRadixString(34));

    final len = 1 +
        tl.data.length +
        tn.length +
        txl.data.length +
        ctxs.length +
        ts.length;

    var buf = Uint8List(len);
    final it = [safe ? 0x01 : 0x00].followedBy(tl.data
        .followedBy(tn.followedBy(txl.data.followedBy(ctxs.followedBy(ts)))));

    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }

    final t2 = makeTimestamp();
    print("Down4Payment compressed took: ${t2 - t1} ms");

    return buf;
  }

  Uint8List get compressed2Mod4 {
    final t1 = makeTimestamp();

    final tl = VarInt.fromInt(textNote.length);
    final tn = utf8.encode(textNote);
    final txl = VarInt.fromInt(txs!.length);
    final ctxs = txs!.compressFold;
    final ts = utf8.encode(timestamp.toRadixString(34));

    var len = 1 +
        tl.data.length +
        tn.length +
        txl.data.length +
        ctxs.length +
        ts.length;

    while ((len % 4) != 0) {
      len++;
    }

    var buf = Uint8List(len);
    final it = [safe ? 0x01 : 0x00].followedBy(tl.data
        .followedBy(tn.followedBy(txl.data.followedBy(ctxs.followedBy(ts)))));

    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }

    final t2 = makeTimestamp();
    print("Down4Payment compressed took: ${t2 - t1} ms");

    return buf;
  }

  factory Down4Payment.fromCompressed(Uint8List buf) {
    final safe = buf[0] == 0x01;
    final textNoteLenVarInt = VarInt.fromRaw(buf.sublist(1));
    final textNoteDataLen = textNoteLenVarInt.data.length;
    final textNoteLen = textNoteLenVarInt.asInt;
    final textOffset = 1 + textNoteDataLen;
    final textOffsetEnd = textOffset + textNoteLen;
    List<int> textNoteData = [];
    String textNote = "";
    if (textNoteLen != 0) {
      textNoteData = buf.sublist(textOffset, textOffset + textNoteLen);
      textNote = String.fromCharCodes(textNoteData);
      // textNote = utf8.decode(textNoteData);
    }

    print("payment textnote: $textNote");

    final nTxVarInt = VarInt.fromRaw(buf.sublist(textOffsetEnd));
    final nTxDataLen = nTxVarInt.data.length;
    List<Down4TX> txs = [];
    int offset = textOffsetEnd + nTxDataLen;
    for (int i = 0; i < nTxVarInt.asInt; i++) {
      final txinfo = Down4TX.fromCompressed(buf.sublist(offset));
      txs.add(txinfo.first);
      offset = offset + txinfo.second;
    }

    final tsBuf = buf.sublist(offset, offset + 7);
    final tsString = String.fromCharCodes(tsBuf);
    // utf8.decode(tsBuf);
    final ts = int.parse(tsString, radix: 34);

    return Down4Payment(Down4ID(),
        spender: g.self.id,
        txid: txs.last.txID,
        txs: txs,
        safe: safe,
        textNote: textNote,
        timestamp: ts);
  }

  List<String> get asQrData {
    final t1 = makeTimestamp();

    // final rawFold = txs.fold<List<int>>(<int>[], (p, v) => p + v.raw);
    // final compressedFold =
    //     txs.fold<List<int>>(<int>[], (p, v) => p + v.compressed);

    // print("COMPRESSING QR");
    // print(txs.fold<String>("", (p, e) => "$p${e.txID.asHex}\n"));

    var comp = compressed;
    while (comp.length % 4 != 0) {
      comp.add(0x00);
    }
    // print("COMPRESSED\n${comp.toHex()}");

    const maxSize = 550;
    final codec = Base85Codec(Alphabets.z85);
    final encode = codec.encode(comp.toUint8List());
    int diviser = 1;
    while (encode.length / diviser > maxSize) {
      diviser = diviser + 1;
    }

    final divided = (encode.length / diviser).floor();
    List<String> listData = [];
    for (int i = 0; i < diviser; i++) {
      String prefix = i == 0 ? "_$diviser," : "$i;";
      bool isLast = i == (diviser - 1);
      if (isLast) {
        listData.add(prefix + encode.substring(i * divided));
      } else {
        listData.add(prefix + encode.substring(i * divided, (i + 1) * divided));
      }
    }

    final t2 = makeTimestamp();

    // print("THERE ARE ${txs.length} TXS");
    // print(
    //   "THERE ARE ${txs.fold<int>(0, (previousValue, element) => previousValue + element.txsIn.length)} INPUTS",
    // );
    // print(
    //   "THERE ARE ${txs.fold<int>(0, (previousValue, element) => previousValue + element.txsOut.length)} OUTPUTS",
    // );
    // // print("RAW FOLDED LEN = ${rawFold.length}");
    // print("COMPRESSED FOLDED LEN = ${compressedFold.length}");
    // print("QR FOLDED LEN = ${listData.join().length}");

    print("\n\tpayment.asQrData took: ${t2 - t1} ms\n");
    return listData;
  }

  List<String> get asQrData2Fast {
    final t1 = makeTimestamp();

    // final compressedFold = txs.compressFold;

    final comp = compressed2Mod4;

    const maxSize = 550;
    final codec = Base85Codec(Alphabets.z85);
    final encode = codec.encode(comp);
    int diviser = 1;
    while (encode.length / diviser > maxSize) {
      diviser = diviser + 1;
    }

    final divided = (encode.length / diviser).floor();
    List<String> listData = [];
    for (int i = 0; i < diviser; i++) {
      var sbuf = StringBuffer(i == 0 ? "_$diviser," : "$i;");
      // String prefix = ;
      bool isLast = i == (diviser - 1);
      if (isLast) {
        sbuf.write(encode.substring(i * divided));
      } else {
        sbuf.write(encode.substring(i * divided, (i + 1) * divided));
      }
      listData.add(sbuf.toString());
    }

    final t2 = makeTimestamp();

    // print("THERE ARE ${txs.length} TXS");
    // print(
    //   "THERE ARE ${txs.fold<int>(0, (previousValue, element) => previousValue + element.txsIn.length)} INPUTS",
    // );
    // print(
    //   "THERE ARE ${txs.fold<int>(0, (previousValue, element) => previousValue + element.txsOut.length)} OUTPUTS",
    // );
    // // print("RAW FOLDED LEN = ${rawFold.length}");
    // print("COMPRESSED FOLDED LEN = ${compressedFold.length}");
    // print("QR FOLDED LEN = ${listData.join().length}");

    print("\n\tpayment.asQrData2Fast took: ${t2 - t1} ms\n");
    return listData;
  }

  factory Down4Payment.fromJson(Map<String, String?> decodedJson) {
    return Down4Payment(Down4ID.fromString(decodedJson["id"])!,
        txs: null,
        plusMinus: int.tryParse(decodedJson["plusMinus"] ?? ""),
        spender: ComposedID.fromString(decodedJson["spender"]),
        txid: TXID.fromBase64(decodedJson["txid"]!),
        safe: decodedJson["safe"] == "true",
        tempTS: int.tryParse(decodedJson["tempTS"] ?? ""),
        tempID: ComposedID.fromString(decodedJson["tempID"]),
        timestamp: int.parse(decodedJson["ts"]!),
        textNote: decodedJson["txt"] ?? "");
  }

  @override
  Map<String, String> toJson({bool includeLocal = true}) => {
        "id": id.value,
        "txid": txid.asBase64,
        if (spender != null) "spender": spender!.value,
        "safe": safe.toString(),
        "ts": timestamp.toString(),
        "plusMinus": plusMinus!.toString(),
        if (tempTS != null) "tempTS": tempTS!.toString(),
        if (tempID != null) "tempID": tempID!.value,
        if (textNote.isNotEmpty) "txt": textNote,
      };

  String toYouKnow() => base64Encode(utf8.encode(jsonEncode(this)));

  factory Down4Payment.fromYouKnow(String youKnow) {
    final base64Decoded = base64Decode(youKnow);
    final utf8Decoded = utf8.decode(base64Decoded);
    final jsonDecoded = jsonDecode(utf8Decoded);
    return Down4Payment.fromJson(jsonDecoded);
  }
}

class VarInt {
  final List<int> data;
  final int asInt;

  const VarInt._(this.data, this.asInt);

  factory VarInt(int n) => VarInt.fromInt(n);

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

  factory VarInt.fromRaw(Uint8List raw) {
    if (raw.lengthInBytes < 1) throw 'Invalid raw for VarInt.fromRaw';
    final firstByte = raw[0];
    if (firstByte == 0xFF) {
      final buf = Uint8List.fromList(raw.sublist(0, 9));
      final theInt = buf.buffer.asByteData().getUint64(1);
      return VarInt._(buf, theInt);
    } else if (firstByte == 0xFE) {
      final buf = Uint8List.fromList(raw.sublist(0, 5));
      final theInt = buf.buffer.asByteData().getUint32(1);
      return VarInt._(buf, theInt);
    } else if (firstByte == 0xFD) {
      final buf = Uint8List.fromList(raw.sublist(0, 3));
      final theInt = buf.buffer.asByteData().getUint16(1);
      return VarInt._(buf, theInt);
    } else {
      final buf = Uint8List.fromList(raw.sublist(0, 1));
      final theInt = buf.buffer.asByteData().getUint8(0);
      return VarInt._(buf, theInt);
    }
  }

  String toHex() => data.toHex();
}

class FourByteInt {
  final List<int> data;
  final int asInt;

  FourByteInt(int n)
      : data = Uint8List(4)..buffer.asByteData().setUint32(0, n, Endian.little),
        asInt = n;

  factory FourByteInt.fromRaw(Uint8List raw) {
    final int = raw.buffer.asByteData().getUint32(0, Endian.little);
    return FourByteInt(int);
  }
}

class TXID {
  final List<int> data;

  TXID(this.data);

  factory TXID.fromHex(String h) => TXID(hex.decode(h).reversed.toList());

  factory TXID.fromBase64(String b64) => TXID(base64Decode(b64));

  String get asBase64 => base64Encode(data);

  String get asHex => data.reversed.toList().toHex();

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

  Sats operator ~/(Sats s) => Sats(asInt ~/ s.asInt);

  bool operator >(Sats s) => asInt > s.asInt;

  bool operator >=(Sats s) => asInt >= s.asInt;

  bool operator <(Sats s) => asInt < s.asInt;

  bool operator <=(Sats s) => asInt <= s.asInt;
}

class Down4TXIN with Down4Object, Jsons, Locals {
  @override
  Down4ID get id => Down4ID(unik: md5(scriptSig!).toBase64());

  @override
  String get table => "txins";

  Down4ID? spender;
  VarInt? _scriptSigLen;
  TXID utxoTXID;
  FourByteInt utxoIndex;
  List<int>? _scriptSig;
  // dependance can be logically replaced by multiple order txs in a payment
  // TXID? dependance; // So I will probably remove it
  FourByteInt sequenceNo;

  Down4TXIN({
    required this.utxoIndex,
    required this.utxoTXID,
    List<int>? scriptSig,
    this.spender,
    int? sequenceNo,
  })  : sequenceNo = FourByteInt(sequenceNo ?? 0xFFFFFFFF),
        _scriptSig = scriptSig,
        _scriptSigLen =
            scriptSig == null ? null : VarInt.fromInt(scriptSig!.length);

  List<int>? get scriptSig => _scriptSig;

  List<int> get compressed {
    final List<int>? encsp = spender?.value.codeUnits;
    // final encsp = spender == null ? [] : utf8.encode(spender!.value);
    return [
      ...raw,
      ...encsp == null ? [0x00] : [encsp.length, ...encsp],
    ];
  }

  List<int> get compressed2 {
    final encsp = spender == null ? <int>[] : utf8.encode(spender!.value);
    final sl = <int>[encsp.length];
    final raw2_ = raw2;

    final l = encsp.length + sl.length + raw2_.length;
    final it = raw2_.followedBy(sl.followedBy(encsp));

    var buf = Uint8List(l);
    int offset = 0;

    for (final b in it) {
      buf[offset] = b;
      offset++;
    }

    return buf;
  }

  static Pair<Down4TXIN, int> fromCompressed(Uint8List d4) {
    final utxoID = TXID(d4.sublist(0, 32));
    final utxoIX = FourByteInt.fromRaw(d4.sublist(32, 36));
    final scriptLenVarInt = VarInt.fromRaw(d4.sublist(36));
    final offset = scriptLenVarInt.data.length;
    final scriptLen = scriptLenVarInt.asInt;
    final script = d4.sublist(36 + offset, 36 + offset + scriptLen);
    final seqNo = FourByteInt.fromRaw(
      d4.sublist(36 + offset + scriptLen, 36 + offset + scriptLen + 4),
    );

    final d4Offset = 36 + offset + scriptLen + 4;
    Down4ID? spender;
    if (d4[d4Offset] != 0x00) {
      final spenderData = d4.sublist(d4Offset + 1, d4Offset + 1 + d4[d4Offset]);
      final spenderStr = String.fromCharCodes(spenderData);
      spender = Down4ID.fromString(spenderStr);
    }

    final txin = Down4TXIN(
        utxoIndex: utxoIX,
        utxoTXID: utxoID,
        scriptSig: script,
        sequenceNo: seqNo.asInt,
        spender: spender);

    return Pair(txin, d4Offset + 1 + d4[d4Offset]); // final offset
  }

  Down4ID get utxoID => down4UtxoID(utxoTXID, utxoIndex);

  factory Down4TXIN.fromJson(Map<String, String?> decodedJson) {
    return Down4TXIN(
      utxoTXID: TXID.fromBase64(decodedJson["utxoTXID"]!),
      utxoIndex: FourByteInt(int.parse(decodedJson["utxoIndex"]!)),
      spender: Down4ID.fromString(decodedJson["spender"]),
      sequenceNo: int.parse(decodedJson["sequenceNo"]!),
      scriptSig: base64Decode(decodedJson["scriptSig"]!),
    );
  }

  @override
  Map<String, String> toJson({bool includeLocal = false}) => {
        "id": id.value,
        "utxoTXID": utxoTXID.asBase64,
        "utxoIndex": utxoIndex.asInt.toString(),
        if (spender != null) "spender": spender!.value,
        "sequenceNo": sequenceNo.asInt.toString(),
        "scriptSig": _scriptSig!.toBase64(),
      };

  List<int> get raw => [
        ...utxoTXID.data,
        ...utxoIndex.data,
        ..._scriptSigLen!.data,
        ..._scriptSig!,
        ...sequenceNo.data,
      ];

  List<int> get raw2 {
    final len = utxoTXID.data.length +
        utxoIndex.data.length +
        _scriptSigLen!.data.length +
        _scriptSig!.length +
        sequenceNo.data.length;

    final it = utxoTXID.data.followedBy(utxoIndex.data.followedBy(_scriptSigLen!
        .data
        .followedBy(_scriptSig!.followedBy(sequenceNo.data))));

    int offset = 0;
    var buf = Uint8List(len);
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }

    return buf;
  }

  List<int> get seqNo => sequenceNo.data;

  List<int> get prevOut => [
        ...utxoTXID.data,
        ...utxoIndex.data,
      ];

  set scriptSig(List<int>? s) {
    _scriptSig = s;
    _scriptSigLen = s == null ? null : VarInt.fromInt(s.length);
  }
}

class Down4TXOUT with Down4Object, Jsons, Locals {
  @override
  String get table => "txouts";

  final List<int> script;
  final VarInt scriptLength;
  final UtxoType type;
  ComposedID? receiver;
  int? outIndex;
  List<int>? secret;
  TXID? txid;
  Sats sats;
  bool _spent;
  bool get spent => _spent;

  Down4TXOUT({
    required this.sats,
    required this.script,
    required this.type,
    this.secret,
    this.outIndex,
    this.receiver,
    this.txid,
    bool spent = false,
  })  : scriptLength = VarInt.fromInt(script.length),
        _spent = spent;

  factory Down4TXOUT.fromJson(Map<String, String?> decodedJson) {
    return Down4TXOUT(
      receiver: ComposedID.fromString(decodedJson["receiver"]),
      secret: decodedJson["secret"] != null
          ? List<int>.from(base64Decode(decodedJson["secret"]!))
          : null,
      outIndex: int.parse(decodedJson["outIndex"]!),
      spent: decodedJson["spent"] == "true",
      txid: TXID.fromHex(decodedJson["txid"]!),
      sats: Sats(int.parse(decodedJson["sats"]!)),
      type: UtxoType.values.byName(decodedJson["type"]!),
      script: base64Decode(decodedJson["script"]!),
    );
  }

  @override
  Map<String, String> toJson({bool includeLocal = true}) => {
        "id": id.value,
        "txid": txid!.asHex,
        "secret": secret!.toBase64(),
        "outIndex": outIndex!.toString(),
        "spent": spent.toString(),
        "sats": sats.asInt.toString(),
        "type": type.name,
        "script": script.toBase64(),
        if (receiver != null) "receiver": receiver!.value,
      };

  // every transaction has a unique secret
  // secret + outIndex is always a unique combination
  @override
  Down4ID get id => down4UtxoID(txid!, FourByteInt(outIndex!));

  // @override
  // Down4ID get id_ => Down4ID(unik: md5(outIndex!.data + secret!));

  bool get isGets => type == UtxoType.gets;

  @override
  int get hashCode {
    final uniqueData = txid!.data + FourByteInt(outIndex!).data;
    return BigInt.parse(hex.encode(uniqueData), radix: 16).hashCode;
  }

  String? markSpent({bool stmt = false}) {
    _spent = true;
    return merge(vals: {"spent": spent.toString()}, stmt: stmt);
  }

  @override
  bool operator ==(other) =>
      other is Down4TXOUT && other.txid == txid && other.outIndex == outIndex;

  List<int> get raw => [
        ...sats.data,
        ...scriptLength.data,
        ...script,
      ];

  List<int> get raw2 {
    final len = sats.data.length + scriptLength.data.length + script.length;
    var buf = Uint8List(len);

    final it = sats.data.followedBy(scriptLength.data.followedBy(script));

    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }
    return buf;
  }

  List<int> get compressed {
    final List<int>? rc = receiver?.value.codeUnits;
    // final List<int>? utf8Receiver =
    //     receiver == null ? null : utf8.encode(receiver!.value);
    return [
      ...raw,
      ...rc == null ? [0x00] : [rc.length, ...rc],
      // ...utf8Receiver == null ? [0x00] : [utf8Receiver.length, ...utf8Receiver],
      type.index,
    ];
  }

  List<int> get compressed2 {
    final rc = receiver == null ? <int>[] : utf8.encode(receiver!.value);
    final rcl = [rc.length];
    final raw2_ = raw2;

    final l = rc.length + rcl.length + raw2_.length;

    final it = raw2_.followedBy(rcl.followedBy(rc));

    var buf = Uint8List(l);
    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }

    return buf;
  }

  static Pair<Down4TXOUT, int> fromCompressed(Uint8List d4) {
    print("parsing this utxo=\n$d4");

    final satInt = Uint8List.fromList(d4.sublist(0, 8))
        .buffer
        .asByteData()
        .getUint64(0, Endian.little);

    print("gaining $satInt sats!!!!!");

    final scriptPubKeyVarInt = VarInt.fromRaw(d4.sublist(8));
    final scriptLen = scriptPubKeyVarInt.asInt;
    print("script is $scriptLen long!!!!");
    final offset = scriptPubKeyVarInt.data.length;
    final script = d4.sublist(8 + offset, 8 + offset + scriptLen);

    final curOffset = 8 + offset + scriptLen;

    ComposedID? receiver;
    int receiverLen = d4[curOffset];
    print("receiverLen=$receiverLen");
    if (receiverLen != 0x00) {
      print(d4.sublist(curOffset, curOffset + 1 + receiverLen));
      final receiverData =
          d4.sublist(curOffset + 1, curOffset + 1 + receiverLen);
      print("receiverData=$receiverData");
      final receiverStr = String.fromCharCodes(receiverData);
      print("receiverStr=$receiverStr");
      receiver = ComposedID.fromString(receiverStr);
      // receiver = ComposedID.fromString(utf8.decode(receiverData));
    }

    final flag = d4[curOffset + 1 + receiverLen];
    final type = UtxoType.values[flag];

    final txout = Down4TXOUT(
        sats: Sats(satInt), script: script, receiver: receiver, type: type);

    return Pair(txout, curOffset + 1 + receiverLen + 1);
  }
}

class Down4TX with Down4Object, Jsons, Locals {
  @override
  Down4ID get id => Down4ID(unik: txID.asBase64);

  @override
  String get table => "transactions";

  ComposedID? maker;
  final List<int> down4Secret;
  final FourByteInt versionNo, nLockTime;
  List<Down4TXIN>? _txsIn;
  List<Down4TXOUT>? _txsOut;
  final VarInt inCounter, outCounter;
  late TXID txID;
  int confirmations;

  Set<Down4ID?> get spenders {
    return txsIn.map((e) => e.spender).toSet();
  }

  List<Down4ID> ins, outs;

  List<Down4TXIN> get txsIn {
    List<Down4TXIN> getEm() {
      final sbuf = StringBuffer();
      sbuf.writeAll(ins.map((e) => e.value.sqlReady), ",");
      // TODO: SAME PROBLEM OF ORDER WITH TRANSACTIONS IN PAYMENTS!!
      // this doesn't specify the order! order is important dummy!!
      final q = "SELECT * FROM txins WHERE id IN (${sbuf.toString()})";
      return db
          .select(q)
          .map((e) {
            final jsns = Map<String, String?>.from(e);
            return Down4TXIN.fromJson(jsns);
          })
          .toList()
          .specificOrder(ins)
          .toList();
    }

    return _txsIn ??= getEm();
  }

  List<Down4TXOUT> get txsOut {
    List<Down4TXOUT> getEm() {
      final sbuf = StringBuffer();
      sbuf.writeAll(outs.map((e) => e.value.sqlReady), ",");
      final q = "SELECT * FROM txouts WHERE id IN (${sbuf.toString()})";
      return db
          .select(q)
          .map((e) {
            final jsns = Map<String, String?>.from(e);
            return Down4TXOUT.fromJson(jsns);
          })
          .toList()
          .specificOrder(outs)
          .toList();
    }

    return _txsOut ??= getEm();
  }

  Down4TX({
    required this.down4Secret,
    required this.ins,
    required this.outs,
    List<Down4TXIN>? txIns,
    List<Down4TXOUT>? txOuts,
    TXID? txid,
    this.maker,
    FourByteInt? vNo,
    FourByteInt? nLock,
    VarInt? inCount,
    VarInt? outCount,
    this.confirmations = -1,
  })  : versionNo = vNo ?? FourByteInt(1),
        nLockTime = nLock ?? FourByteInt(0),
        inCounter = inCount ?? VarInt.fromInt(ins.length),
        outCounter = outCount ?? VarInt.fromInt(outs.length),
        _txsIn = txIns,
        _txsOut = txOuts {
    txID = txid ??
        calculateTXID(
            versionNo, inCount!, txIns!, outCount!, txOuts!, nLockTime);
    // TXID(hash256([
    //   ...versionNo.data,
    //   ...inCounter.data,
    //   ...txsIn!.fold(<int>[], (buf, tx) => [...buf, ...tx.raw]),
    //   ...outCounter.data,
    //   ...txsOut!.fold(<int>[], (buf, tx) => [...buf, ...tx.raw]),
    //   ...nLockTime.data,
    // ]));
  }

  // this should be used when loading own payments from locals
  factory Down4TX.fromJson(Map<String, String?> decodedJson) {
    return Down4TX(
      txid: TXID.fromBase64(decodedJson["id"]!),
      down4Secret: base64Decode(decodedJson["secret"]!),
      maker: ComposedID.fromString(decodedJson["maker"]),
      ins: decodedJson["ins"]!
          .split(" ")
          .map((e) => Down4ID.fromString(e)!)
          .toList(),
      outs: decodedJson["outs"]!
          .split(" ")
          .map((e) => Down4ID.fromString(e)!)
          .toList(),
      vNo: FourByteInt(int.parse(decodedJson["versionNo"]!)),
      nLock: FourByteInt(int.parse(decodedJson["nLockTime"]!)),
      confirmations: int.parse(decodedJson["confirmations"]!),
    );
  }

  @override
  Map<String, String> toJson({bool includeLocal = false}) => {
        "id": id.value,
        "secret": down4Secret.toBase64(),
        if (maker != null) "maker": maker!.value,
        "ins": ins.values,
        "outs": outs.values,
        "versionNo": versionNo.asInt.toString(),
        "nLockTime": nLockTime.asInt.toString(),
        "confirmations": confirmations.toString(),
      };

  List<int> get raw => [
        ...versionNo.data,
        ...inCounter.data,
        ...txsIn.fold(<int>[], (buf, tx) => [...buf, ...tx.raw]),
        ...outCounter.data,
        ...txsOut.fold(<int>[], (buf, tx) => [...buf, ...tx.raw]),
        ...nLockTime.data,
      ];

  // this is necessary in the current system of discarding txs and keeping only
  // the utxos, we can save much space, which is good ofcourse
  // this requires a full transaction, parsing transactions without
  // all the utxos will break this function
  void writeTxInfosToUTXOs() {
    for (int i = 0; i < txsOut.length; i++) {
      txsOut[i].txid ??= txID;
      txsOut[i].outIndex ??= i;
      txsOut[i].secret ??= down4Secret;
    }
  }

  void updateConfirmations(int confs) {
    confirmations = confs;
    merge(vals: {"confirmations": confs.toString()});
  }

  List<int> get compressed {
    final t1 = makeTimestamp();

    print("inCounter=${inCounter.asInt}, nTxins=${txsIn.length}");
    print("outCounter=${outCounter.asInt}, nTxins=${txsOut.length}");    
    
    final buf = [
      ...versionNo.data,
      ...inCounter.data,
      ...txsIn.fold(<int>[], (buf, txin) => buf + txin.compressed),
      ...outCounter.data,
      ...txsOut.fold(<int>[], (buf, txout) => buf + txout.compressed),
      ...nLockTime.data,
      down4Secret.length,
      ...down4Secret,
      ...VarInt.fromInt(confirmations).data,
    ];

    final t2 = makeTimestamp();
    print("Down4TX compressed took: ${t2 - t1} ms");

    return buf;
  }

  List<int> get compressed2 {
    final t1 = makeTimestamp();
    final inFold = txsIn.compressFold;
    // final inFold = txsIn.fold(<int>[], (buf, txin) => buf + txin.compressed);
    final outFold = txsOut.compressFold;
    // final outFold = txsOut.fold(<int>[], (buf, txin) => buf + txin.compressed);
    final confs = VarInt.fromInt(confirmations);

    final len = versionNo.data.length +
        inCounter.data.length +
        inFold.length +
        outCounter.data.length +
        outFold.length +
        nLockTime.data.length +
        down4Secret.length +
        down4Secret.length +
        confs.data.length;

    final it = versionNo.data.followedBy(inCounter.data.followedBy(
        inFold.followedBy(outCounter.data.followedBy(outFold.followedBy(
            nLockTime.data.followedBy([down4Secret.length]
                .followedBy(down4Secret.followedBy(confs.data))))))));

    var buf = Uint8List(len);
    int offset = 0;
    for (final b in it) {
      buf[offset] = b;
      offset++;
    }

    final t2 = makeTimestamp();
    print("Down4TX compressed took: ${t2 - t1} ms");

    return buf;
  }

  static Pair<Down4TX, int> fromCompressed(Uint8List buf) {
    final vNo = FourByteInt.fromRaw(buf.sublist(0, 4));
    final inCountVarInt = VarInt.fromRaw(buf.sublist(4));
    print("there will be ${inCountVarInt.asInt} txins to decode!");
    var txsIn = <Down4TXIN>[];
    var offset = 4 + inCountVarInt.data.length;
    for (int i = 0; i < inCountVarInt.asInt; i++) {
      print("decoding txin #$i");
      final txinInfo = Down4TXIN.fromCompressed(buf.sublist(offset));
      txsIn.add(txinInfo.first);
      offset = offset + txinInfo.second;
    }

    final outCounterVarInt = VarInt.fromRaw(buf.sublist(offset));
    var txsOut = <Down4TXOUT>[];
    offset = offset + outCounterVarInt.data.length;
    print("There will be ${outCounterVarInt.asInt} txout to decode");
    for (int i = 0; i < outCounterVarInt.asInt; i++) {
      print("decoding txout #$i");      
      final txoutInfo = Down4TXOUT.fromCompressed(buf.sublist(offset));
      txsOut.add(txoutInfo.first);
      offset = offset + txoutInfo.second;
    }

    final nLockTime = FourByteInt.fromRaw(buf.sublist(offset, offset + 4));
    final down4SecretLen = buf[offset + 4];
    final down4Secret = buf.sublist(offset + 5, offset + 5 + down4SecretLen);

    final conf = VarInt.fromRaw(buf.sublist(offset + 5 + down4SecretLen));

    final finalOffset = offset + 5 + down4SecretLen + 1;

    final txid = calculateTXID(
        vNo, inCountVarInt, txsIn, outCounterVarInt, txsOut, nLockTime);

    for (int i = 0; i < txsOut.length; i++) {
      txsOut[i].txid = txid;
      txsOut[i].outIndex = i;
    }

    final down4Tx = Down4TX(
        txid: txid,
        down4Secret: down4Secret,
        inCount: inCountVarInt,
        txIns: txsIn,
        ins: txsIn.map((e) => e.id).toList(),
        outCount: outCounterVarInt,
        txOuts: txsOut,
        outs: txsOut.map((e) => e.id).toList(),
        vNo: vNo,
        nLock: nLockTime,
        confirmations: conf.asInt);

    return Pair(down4Tx, finalOffset);
  }

  // List<TXID> get txidDeps {
  //   return txsIn!.fold(<TXID>[], (deps, txin) {
  //     if (txin.dependance != null) {
  //       return deps..add(txin.dependance!);
  //     } else {
  //       return deps;
  //     }
  //   });
  // }

  String get fullRawHex => hex.encode(raw);

  String get asQrData => jsonEncode(toJson());

  @override
  int get hashCode => BigInt.parse(txID.asHex, radix: 16).hashCode;

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

    var sig = signer.generateSignature(message.toUint8List()) as ECSignature;
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

    final out = hmac.process(data.toUint8List());
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
    final chainCode = hex.decode(decodedJson["cc"]).toUint8List();
    ECPrivateKey? prv;
    if (decodedJson["prv"] != null) {
      var big = BigInt.parse(decodedJson["prv"], radix: 16);
      prv = ECPrivateKey(big, secp256k1);
    }

    final pubByte = hex.decode(decodedJson["pub"]).toUint8List();
    final pub = uncompressPublicKey(pubByte);

    return Down4Keys._(publicKey: pub, chainCode: chainCode, privateKey: prv);
  }

  factory Down4Keys.fromRandom(Uint8List keySeed, Uint8List chainCodeSeed) {
    var chainCode = sha256(chainCodeSeed).toUint8List();

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
  // var f = io.File("C:\\Users\\coton\\Desktop\\jeff.txt");
  var f = io.File("/home/scott/jeff.txt");
  var pkHex = f.readAsStringSync();

  // final seed1 = safeSeed(32);
  // final seed2 = safeSeed(32);

  // var pair0 = Down4Keys.fromRandom(seed1, seed2);

  // final f = io.File("/home/scott/jeff.txt");
  // final pkHex = f.readAsStringSync();

  // io.File("/home/scott/jeff.txt").writeAsString(pair0.privKeyHex!);

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
