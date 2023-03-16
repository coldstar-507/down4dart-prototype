// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realm.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

class RPayment extends _RPayment
    with RealmEntity, RealmObjectBase, RealmObject {
  RPayment(
    String id,
    bool safe,
    int tsSeconds, {
    String? textNote,
    Set<RTX> txs = const {},
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'textNote', textNote);
    RealmObjectBase.set(this, 'safe', safe);
    RealmObjectBase.set(this, 'tsSeconds', tsSeconds);
    RealmObjectBase.set<RealmSet<RTX>>(this, 'txs', RealmSet<RTX>(txs));
  }

  RPayment._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  RealmSet<RTX> get txs =>
      RealmObjectBase.get<RTX>(this, 'txs') as RealmSet<RTX>;
  @override
  set txs(covariant RealmSet<RTX> value) => throw RealmUnsupportedSetError();

  @override
  String? get textNote =>
      RealmObjectBase.get<String>(this, 'textNote') as String?;
  @override
  set textNote(String? value) => RealmObjectBase.set(this, 'textNote', value);

  @override
  bool get safe => RealmObjectBase.get<bool>(this, 'safe') as bool;
  @override
  set safe(bool value) => RealmObjectBase.set(this, 'safe', value);

  @override
  int get tsSeconds => RealmObjectBase.get<int>(this, 'tsSeconds') as int;
  @override
  set tsSeconds(int value) => RealmObjectBase.set(this, 'tsSeconds', value);

  @override
  Stream<RealmObjectChanges<RPayment>> get changes =>
      RealmObjectBase.getChanges<RPayment>(this);

  @override
  RPayment freeze() => RealmObjectBase.freezeObject<RPayment>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(RPayment._);
    return const SchemaObject(ObjectType.realmObject, RPayment, 'RPayment', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('txs', RealmPropertyType.object,
          linkTarget: 'RTX', collectionType: RealmCollectionType.set),
      SchemaProperty('textNote', RealmPropertyType.string, optional: true),
      SchemaProperty('safe', RealmPropertyType.bool),
      SchemaProperty('tsSeconds', RealmPropertyType.int),
    ]);
  }
}

class RUTXO extends _RUTXO with RealmEntity, RealmObjectBase, RealmObject {
  RUTXO(
    String id,
    String scriptPubKey,
    int scriptPubKeyLen,
    bool isChange,
    bool isFee,
    String receiver,
    int outIndex,
    String secret,
    String txid,
    int sats,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'scriptPubKey', scriptPubKey);
    RealmObjectBase.set(this, 'scriptPubKeyLen', scriptPubKeyLen);
    RealmObjectBase.set(this, 'isChange', isChange);
    RealmObjectBase.set(this, 'isFee', isFee);
    RealmObjectBase.set(this, 'receiver', receiver);
    RealmObjectBase.set(this, 'outIndex', outIndex);
    RealmObjectBase.set(this, 'secret', secret);
    RealmObjectBase.set(this, 'txid', txid);
    RealmObjectBase.set(this, 'sats', sats);
  }

  RUTXO._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get scriptPubKey =>
      RealmObjectBase.get<String>(this, 'scriptPubKey') as String;
  @override
  set scriptPubKey(String value) =>
      RealmObjectBase.set(this, 'scriptPubKey', value);

  @override
  int get scriptPubKeyLen =>
      RealmObjectBase.get<int>(this, 'scriptPubKeyLen') as int;
  @override
  set scriptPubKeyLen(int value) =>
      RealmObjectBase.set(this, 'scriptPubKeyLen', value);

  @override
  bool get isChange => RealmObjectBase.get<bool>(this, 'isChange') as bool;
  @override
  set isChange(bool value) => RealmObjectBase.set(this, 'isChange', value);

  @override
  bool get isFee => RealmObjectBase.get<bool>(this, 'isFee') as bool;
  @override
  set isFee(bool value) => RealmObjectBase.set(this, 'isFee', value);

  @override
  String get receiver =>
      RealmObjectBase.get<String>(this, 'receiver') as String;
  @override
  set receiver(String value) => RealmObjectBase.set(this, 'receiver', value);

  @override
  int get outIndex => RealmObjectBase.get<int>(this, 'outIndex') as int;
  @override
  set outIndex(int value) => RealmObjectBase.set(this, 'outIndex', value);

  @override
  String get secret => RealmObjectBase.get<String>(this, 'secret') as String;
  @override
  set secret(String value) => RealmObjectBase.set(this, 'secret', value);

  @override
  String get txid => RealmObjectBase.get<String>(this, 'txid') as String;
  @override
  set txid(String value) => RealmObjectBase.set(this, 'txid', value);

  @override
  int get sats => RealmObjectBase.get<int>(this, 'sats') as int;
  @override
  set sats(int value) => RealmObjectBase.set(this, 'sats', value);

  @override
  Stream<RealmObjectChanges<RUTXO>> get changes =>
      RealmObjectBase.getChanges<RUTXO>(this);

  @override
  RUTXO freeze() => RealmObjectBase.freezeObject<RUTXO>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(RUTXO._);
    return const SchemaObject(ObjectType.realmObject, RUTXO, 'RUTXO', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('scriptPubKey', RealmPropertyType.string),
      SchemaProperty('scriptPubKeyLen', RealmPropertyType.int),
      SchemaProperty('isChange', RealmPropertyType.bool),
      SchemaProperty('isFee', RealmPropertyType.bool),
      SchemaProperty('receiver', RealmPropertyType.string),
      SchemaProperty('outIndex', RealmPropertyType.int),
      SchemaProperty('secret', RealmPropertyType.string),
      SchemaProperty('txid', RealmPropertyType.string),
      SchemaProperty('sats', RealmPropertyType.int),
    ]);
  }
}

class RTXIN extends _RTXIN with RealmEntity, RealmObjectBase, EmbeddedObject {
  RTXIN(
    String spender,
    int scriptSigLen,
    String utxoTXID,
    int utxoIndex,
    String scriptSig,
    int sequenceNo,
  ) {
    RealmObjectBase.set(this, 'spender', spender);
    RealmObjectBase.set(this, 'scriptSigLen', scriptSigLen);
    RealmObjectBase.set(this, 'utxoTXID', utxoTXID);
    RealmObjectBase.set(this, 'utxoIndex', utxoIndex);
    RealmObjectBase.set(this, 'scriptSig', scriptSig);
    RealmObjectBase.set(this, 'sequenceNo', sequenceNo);
  }

  RTXIN._();

  @override
  String get spender => RealmObjectBase.get<String>(this, 'spender') as String;
  @override
  set spender(String value) => RealmObjectBase.set(this, 'spender', value);

  @override
  int get scriptSigLen => RealmObjectBase.get<int>(this, 'scriptSigLen') as int;
  @override
  set scriptSigLen(int value) =>
      RealmObjectBase.set(this, 'scriptSigLen', value);

  @override
  String get utxoTXID =>
      RealmObjectBase.get<String>(this, 'utxoTXID') as String;
  @override
  set utxoTXID(String value) => RealmObjectBase.set(this, 'utxoTXID', value);

  @override
  int get utxoIndex => RealmObjectBase.get<int>(this, 'utxoIndex') as int;
  @override
  set utxoIndex(int value) => RealmObjectBase.set(this, 'utxoIndex', value);

  @override
  String get scriptSig =>
      RealmObjectBase.get<String>(this, 'scriptSig') as String;
  @override
  set scriptSig(String value) => RealmObjectBase.set(this, 'scriptSig', value);

  @override
  int get sequenceNo => RealmObjectBase.get<int>(this, 'sequenceNo') as int;
  @override
  set sequenceNo(int value) => RealmObjectBase.set(this, 'sequenceNo', value);

  @override
  Stream<RealmObjectChanges<RTXIN>> get changes =>
      RealmObjectBase.getChanges<RTXIN>(this);

  @override
  RTXIN freeze() => RealmObjectBase.freezeObject<RTXIN>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(RTXIN._);
    return const SchemaObject(ObjectType.embeddedObject, RTXIN, 'RTXIN', [
      SchemaProperty('spender', RealmPropertyType.string),
      SchemaProperty('scriptSigLen', RealmPropertyType.int),
      SchemaProperty('utxoTXID', RealmPropertyType.string),
      SchemaProperty('utxoIndex', RealmPropertyType.int),
      SchemaProperty('scriptSig', RealmPropertyType.string),
      SchemaProperty('sequenceNo', RealmPropertyType.int),
    ]);
  }
}

class RTX extends _RTX with RealmEntity, RealmObjectBase, RealmObject {
  RTX(
    String id,
    String maker,
    String down4Secret,
    int versionNo,
    int nLockTime,
    int inCounter,
    int outCounter,
    String txID,
    int confirmations, {
    Set<RTXIN> txsIn = const {},
    Set<RUTXO> txsOut = const {},
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'maker', maker);
    RealmObjectBase.set(this, 'down4Secret', down4Secret);
    RealmObjectBase.set(this, 'versionNo', versionNo);
    RealmObjectBase.set(this, 'nLockTime', nLockTime);
    RealmObjectBase.set(this, 'inCounter', inCounter);
    RealmObjectBase.set(this, 'outCounter', outCounter);
    RealmObjectBase.set(this, 'txID', txID);
    RealmObjectBase.set(this, 'confirmations', confirmations);
    RealmObjectBase.set<RealmSet<RTXIN>>(this, 'txsIn', RealmSet<RTXIN>(txsIn));
    RealmObjectBase.set<RealmSet<RUTXO>>(
        this, 'txsOut', RealmSet<RUTXO>(txsOut));
  }

  RTX._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get maker => RealmObjectBase.get<String>(this, 'maker') as String;
  @override
  set maker(String value) => RealmObjectBase.set(this, 'maker', value);

  @override
  String get down4Secret =>
      RealmObjectBase.get<String>(this, 'down4Secret') as String;
  @override
  set down4Secret(String value) =>
      RealmObjectBase.set(this, 'down4Secret', value);

  @override
  int get versionNo => RealmObjectBase.get<int>(this, 'versionNo') as int;
  @override
  set versionNo(int value) => RealmObjectBase.set(this, 'versionNo', value);

  @override
  int get nLockTime => RealmObjectBase.get<int>(this, 'nLockTime') as int;
  @override
  set nLockTime(int value) => RealmObjectBase.set(this, 'nLockTime', value);

  @override
  RealmSet<RTXIN> get txsIn =>
      RealmObjectBase.get<RTXIN>(this, 'txsIn') as RealmSet<RTXIN>;
  @override
  set txsIn(covariant RealmSet<RTXIN> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmSet<RUTXO> get txsOut =>
      RealmObjectBase.get<RUTXO>(this, 'txsOut') as RealmSet<RUTXO>;
  @override
  set txsOut(covariant RealmSet<RUTXO> value) =>
      throw RealmUnsupportedSetError();

  @override
  int get inCounter => RealmObjectBase.get<int>(this, 'inCounter') as int;
  @override
  set inCounter(int value) => RealmObjectBase.set(this, 'inCounter', value);

  @override
  int get outCounter => RealmObjectBase.get<int>(this, 'outCounter') as int;
  @override
  set outCounter(int value) => RealmObjectBase.set(this, 'outCounter', value);

  @override
  String get txID => RealmObjectBase.get<String>(this, 'txID') as String;
  @override
  set txID(String value) => RealmObjectBase.set(this, 'txID', value);

  @override
  int get confirmations =>
      RealmObjectBase.get<int>(this, 'confirmations') as int;
  @override
  set confirmations(int value) =>
      RealmObjectBase.set(this, 'confirmations', value);

  @override
  Stream<RealmObjectChanges<RTX>> get changes =>
      RealmObjectBase.getChanges<RTX>(this);

  @override
  RTX freeze() => RealmObjectBase.freezeObject<RTX>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(RTX._);
    return const SchemaObject(ObjectType.realmObject, RTX, 'RTX', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('maker', RealmPropertyType.string),
      SchemaProperty('down4Secret', RealmPropertyType.string),
      SchemaProperty('versionNo', RealmPropertyType.int),
      SchemaProperty('nLockTime', RealmPropertyType.int),
      SchemaProperty('txsIn', RealmPropertyType.object,
          linkTarget: 'RTXIN', collectionType: RealmCollectionType.set),
      SchemaProperty('txsOut', RealmPropertyType.object,
          linkTarget: 'RUTXO', collectionType: RealmCollectionType.set),
      SchemaProperty('inCounter', RealmPropertyType.int),
      SchemaProperty('outCounter', RealmPropertyType.int),
      SchemaProperty('txID', RealmPropertyType.string),
      SchemaProperty('confirmations', RealmPropertyType.int),
    ]);
  }
}

class RMedia extends _RMedia with RealmEntity, RealmObjectBase, RealmObject {
  RMedia(
    String id,
    String data,
    String metadata,
    bool isSaved,
    int lastUse,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'data', data);
    RealmObjectBase.set(this, 'metadata', metadata);
    RealmObjectBase.set(this, 'isSaved', isSaved);
    RealmObjectBase.set(this, 'lastUse', lastUse);
  }

  RMedia._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get data => RealmObjectBase.get<String>(this, 'data') as String;
  @override
  set data(String value) => RealmObjectBase.set(this, 'data', value);

  @override
  String get metadata =>
      RealmObjectBase.get<String>(this, 'metadata') as String;
  @override
  set metadata(String value) => RealmObjectBase.set(this, 'metadata', value);

  @override
  bool get isSaved => RealmObjectBase.get<bool>(this, 'isSaved') as bool;
  @override
  set isSaved(bool value) => RealmObjectBase.set(this, 'isSaved', value);

  @override
  int get lastUse => RealmObjectBase.get<int>(this, 'lastUse') as int;
  @override
  set lastUse(int value) => RealmObjectBase.set(this, 'lastUse', value);

  @override
  Stream<RealmObjectChanges<RMedia>> get changes =>
      RealmObjectBase.getChanges<RMedia>(this);

  @override
  RMedia freeze() => RealmObjectBase.freezeObject<RMedia>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(RMedia._);
    return const SchemaObject(ObjectType.realmObject, RMedia, 'RMedia', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('data', RealmPropertyType.string),
      SchemaProperty('metadata', RealmPropertyType.string),
      SchemaProperty('isSaved', RealmPropertyType.bool, indexed: true),
      SchemaProperty('lastUse', RealmPropertyType.int, indexed: true),
    ]);
  }
}

class RMessage extends _RMessage
    with RealmEntity, RealmObjectBase, RealmObject {
  RMessage(
    String id,
    String senderID,
    int timestamp,
    String sents,
    String reads, {
    String? mediaID,
    String? text,
    String? replies,
    String? nodes,
    String? forwarderID,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'senderID', senderID);
    RealmObjectBase.set(this, 'mediaID', mediaID);
    RealmObjectBase.set(this, 'text', text);
    RealmObjectBase.set(this, 'replies', replies);
    RealmObjectBase.set(this, 'nodes', nodes);
    RealmObjectBase.set(this, 'forwarderID', forwarderID);
    RealmObjectBase.set(this, 'timestamp', timestamp);
    RealmObjectBase.set(this, 'sents', sents);
    RealmObjectBase.set(this, 'reads', reads);
  }

  RMessage._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get senderID =>
      RealmObjectBase.get<String>(this, 'senderID') as String;
  @override
  set senderID(String value) => RealmObjectBase.set(this, 'senderID', value);

  @override
  String? get mediaID =>
      RealmObjectBase.get<String>(this, 'mediaID') as String?;
  @override
  set mediaID(String? value) => RealmObjectBase.set(this, 'mediaID', value);

  @override
  String? get text => RealmObjectBase.get<String>(this, 'text') as String?;
  @override
  set text(String? value) => RealmObjectBase.set(this, 'text', value);

  @override
  String? get replies =>
      RealmObjectBase.get<String>(this, 'replies') as String?;
  @override
  set replies(String? value) => RealmObjectBase.set(this, 'replies', value);

  @override
  String? get nodes => RealmObjectBase.get<String>(this, 'nodes') as String?;
  @override
  set nodes(String? value) => RealmObjectBase.set(this, 'nodes', value);

  @override
  String? get forwarderID =>
      RealmObjectBase.get<String>(this, 'forwarderID') as String?;
  @override
  set forwarderID(String? value) =>
      RealmObjectBase.set(this, 'forwarderID', value);

  @override
  int get timestamp => RealmObjectBase.get<int>(this, 'timestamp') as int;
  @override
  set timestamp(int value) => RealmObjectBase.set(this, 'timestamp', value);

  @override
  String get sents => RealmObjectBase.get<String>(this, 'sents') as String;
  @override
  set sents(String value) => RealmObjectBase.set(this, 'sents', value);

  @override
  String get reads => RealmObjectBase.get<String>(this, 'reads') as String;
  @override
  set reads(String value) => RealmObjectBase.set(this, 'reads', value);

  @override
  Stream<RealmObjectChanges<RMessage>> get changes =>
      RealmObjectBase.getChanges<RMessage>(this);

  @override
  RMessage freeze() => RealmObjectBase.freezeObject<RMessage>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(RMessage._);
    return const SchemaObject(ObjectType.realmObject, RMessage, 'RMessage', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('senderID', RealmPropertyType.string),
      SchemaProperty('mediaID', RealmPropertyType.string, optional: true),
      SchemaProperty('text', RealmPropertyType.string, optional: true),
      SchemaProperty('replies', RealmPropertyType.string, optional: true),
      SchemaProperty('nodes', RealmPropertyType.string, optional: true),
      SchemaProperty('forwarderID', RealmPropertyType.string, optional: true),
      SchemaProperty('timestamp', RealmPropertyType.int),
      SchemaProperty('sents', RealmPropertyType.string),
      SchemaProperty('reads', RealmPropertyType.string),
    ]);
  }
}

class RNode extends _RNode with RealmEntity, RealmObjectBase, RealmObject {
  RNode(
    String id,
    String name,
    String type,
    int activity, {
    RMedia? media,
    String? keys,
    String? lastName,
    String? description,
    bool? isFriend,
    Set<RNode> public = const {},
    Set<RNode> private = const {},
    Set<RNode> group = const {},
    Set<RMedia> snips = const {},
    Set<RMessage> messages = const {},
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set(this, 'type', type);
    RealmObjectBase.set(this, 'activity', activity);
    RealmObjectBase.set(this, 'media', media);
    RealmObjectBase.set(this, 'keys', keys);
    RealmObjectBase.set(this, 'lastName', lastName);
    RealmObjectBase.set(this, 'description', description);
    RealmObjectBase.set(this, 'isFriend', isFriend);
    RealmObjectBase.set<RealmSet<RNode>>(
        this, 'public', RealmSet<RNode>(public));
    RealmObjectBase.set<RealmSet<RNode>>(
        this, 'private', RealmSet<RNode>(private));
    RealmObjectBase.set<RealmSet<RNode>>(this, 'group', RealmSet<RNode>(group));
    RealmObjectBase.set<RealmSet<RMedia>>(
        this, 'snips', RealmSet<RMedia>(snips));
    RealmObjectBase.set<RealmSet<RMessage>>(
        this, 'messages', RealmSet<RMessage>(messages));
  }

  RNode._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get name => RealmObjectBase.get<String>(this, 'name') as String;
  @override
  set name(String value) => RealmObjectBase.set(this, 'name', value);

  @override
  String get type => RealmObjectBase.get<String>(this, 'type') as String;
  @override
  set type(String value) => RealmObjectBase.set(this, 'type', value);

  @override
  int get activity => RealmObjectBase.get<int>(this, 'activity') as int;
  @override
  set activity(int value) => RealmObjectBase.set(this, 'activity', value);

  @override
  RMedia? get media => RealmObjectBase.get<RMedia>(this, 'media') as RMedia?;
  @override
  set media(covariant RMedia? value) =>
      RealmObjectBase.set(this, 'media', value);

  @override
  String? get keys => RealmObjectBase.get<String>(this, 'keys') as String?;
  @override
  set keys(String? value) => RealmObjectBase.set(this, 'keys', value);

  @override
  String? get lastName =>
      RealmObjectBase.get<String>(this, 'lastName') as String?;
  @override
  set lastName(String? value) => RealmObjectBase.set(this, 'lastName', value);

  @override
  String? get description =>
      RealmObjectBase.get<String>(this, 'description') as String?;
  @override
  set description(String? value) =>
      RealmObjectBase.set(this, 'description', value);

  @override
  RealmSet<RNode> get public =>
      RealmObjectBase.get<RNode>(this, 'public') as RealmSet<RNode>;
  @override
  set public(covariant RealmSet<RNode> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmSet<RNode> get private =>
      RealmObjectBase.get<RNode>(this, 'private') as RealmSet<RNode>;
  @override
  set private(covariant RealmSet<RNode> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmSet<RNode> get group =>
      RealmObjectBase.get<RNode>(this, 'group') as RealmSet<RNode>;
  @override
  set group(covariant RealmSet<RNode> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmSet<RMedia> get snips =>
      RealmObjectBase.get<RMedia>(this, 'snips') as RealmSet<RMedia>;
  @override
  set snips(covariant RealmSet<RMedia> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmSet<RMessage> get messages =>
      RealmObjectBase.get<RMessage>(this, 'messages') as RealmSet<RMessage>;
  @override
  set messages(covariant RealmSet<RMessage> value) =>
      throw RealmUnsupportedSetError();

  @override
  bool? get isFriend => RealmObjectBase.get<bool>(this, 'isFriend') as bool?;
  @override
  set isFriend(bool? value) => RealmObjectBase.set(this, 'isFriend', value);

  @override
  Stream<RealmObjectChanges<RNode>> get changes =>
      RealmObjectBase.getChanges<RNode>(this);

  @override
  RNode freeze() => RealmObjectBase.freezeObject<RNode>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(RNode._);
    return const SchemaObject(ObjectType.realmObject, RNode, 'RNode', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('name', RealmPropertyType.string),
      SchemaProperty('type', RealmPropertyType.string),
      SchemaProperty('activity', RealmPropertyType.int),
      SchemaProperty('media', RealmPropertyType.object,
          optional: true, linkTarget: 'RMedia'),
      SchemaProperty('keys', RealmPropertyType.string, optional: true),
      SchemaProperty('lastName', RealmPropertyType.string, optional: true),
      SchemaProperty('description', RealmPropertyType.string, optional: true),
      SchemaProperty('public', RealmPropertyType.object,
          linkTarget: 'RNode', collectionType: RealmCollectionType.set),
      SchemaProperty('private', RealmPropertyType.object,
          linkTarget: 'RNode', collectionType: RealmCollectionType.set),
      SchemaProperty('group', RealmPropertyType.object,
          linkTarget: 'RNode', collectionType: RealmCollectionType.set),
      SchemaProperty('snips', RealmPropertyType.object,
          linkTarget: 'RMedia', collectionType: RealmCollectionType.set),
      SchemaProperty('messages', RealmPropertyType.object,
          linkTarget: 'RMessage', collectionType: RealmCollectionType.set),
      SchemaProperty('isFriend', RealmPropertyType.bool, optional: true),
    ]);
  }
}

class User extends _User with RealmEntity, RealmObjectBase, RealmObject {
  User(
    int activity,
    String id,
    bool isFriend,
    String firstName,
    String rawKeys, {
    RMedia? media,
    String? lastName,
    String? description,
    Set<String> children = const {},
    Set<RMedia> snips = const {},
    Set<RMessage> messages = const {},
  }) {
    RealmObjectBase.set(this, 'activity', activity);
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'media', media);
    RealmObjectBase.set(this, 'isFriend', isFriend);
    RealmObjectBase.set(this, 'firstName', firstName);
    RealmObjectBase.set(this, 'lastName', lastName);
    RealmObjectBase.set(this, 'description', description);
    RealmObjectBase.set(this, 'rawKeys', rawKeys);
    RealmObjectBase.set<RealmSet<String>>(
        this, 'children', RealmSet<String>(children));
    RealmObjectBase.set<RealmSet<RMedia>>(
        this, 'snips', RealmSet<RMedia>(snips));
    RealmObjectBase.set<RealmSet<RMessage>>(
        this, 'messages', RealmSet<RMessage>(messages));
  }

  User._();

  @override
  int get activity => RealmObjectBase.get<int>(this, 'activity') as int;
  @override
  set activity(int value) => RealmObjectBase.set(this, 'activity', value);

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => throw RealmUnsupportedSetError();

  @override
  RMedia? get media => RealmObjectBase.get<RMedia>(this, 'media') as RMedia?;
  @override
  set media(covariant RMedia? value) =>
      RealmObjectBase.set(this, 'media', value);

  @override
  RealmSet<String> get children =>
      RealmObjectBase.get<String>(this, 'children') as RealmSet<String>;
  @override
  set children(covariant RealmSet<String> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmSet<RMedia> get snips =>
      RealmObjectBase.get<RMedia>(this, 'snips') as RealmSet<RMedia>;
  @override
  set snips(covariant RealmSet<RMedia> value) =>
      throw RealmUnsupportedSetError();

  @override
  RealmSet<RMessage> get messages =>
      RealmObjectBase.get<RMessage>(this, 'messages') as RealmSet<RMessage>;
  @override
  set messages(covariant RealmSet<RMessage> value) =>
      throw RealmUnsupportedSetError();

  @override
  bool get isFriend => RealmObjectBase.get<bool>(this, 'isFriend') as bool;
  @override
  set isFriend(bool value) => RealmObjectBase.set(this, 'isFriend', value);

  @override
  String get firstName =>
      RealmObjectBase.get<String>(this, 'firstName') as String;
  @override
  set firstName(String value) => RealmObjectBase.set(this, 'firstName', value);

  @override
  String? get lastName =>
      RealmObjectBase.get<String>(this, 'lastName') as String?;
  @override
  set lastName(String? value) => RealmObjectBase.set(this, 'lastName', value);

  @override
  String? get description =>
      RealmObjectBase.get<String>(this, 'description') as String?;
  @override
  set description(String? value) =>
      RealmObjectBase.set(this, 'description', value);

  @override
  String get rawKeys => RealmObjectBase.get<String>(this, 'rawKeys') as String;
  @override
  set rawKeys(String value) => throw RealmUnsupportedSetError();

  @override
  Stream<RealmObjectChanges<User>> get changes =>
      RealmObjectBase.getChanges<User>(this);

  @override
  User freeze() => RealmObjectBase.freezeObject<User>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObjectBase.registerFactory(User._);
    return const SchemaObject(ObjectType.realmObject, User, 'User', [
      SchemaProperty('activity', RealmPropertyType.int),
      SchemaProperty('id', RealmPropertyType.string),
      SchemaProperty('media', RealmPropertyType.object,
          optional: true, linkTarget: 'RMedia'),
      SchemaProperty('children', RealmPropertyType.string,
          collectionType: RealmCollectionType.set),
      SchemaProperty('snips', RealmPropertyType.object,
          linkTarget: 'RMedia', collectionType: RealmCollectionType.set),
      SchemaProperty('messages', RealmPropertyType.object,
          linkTarget: 'RMessage', collectionType: RealmCollectionType.set),
      SchemaProperty('isFriend', RealmPropertyType.bool),
      SchemaProperty('firstName', RealmPropertyType.string),
      SchemaProperty('lastName', RealmPropertyType.string, optional: true),
      SchemaProperty('description', RealmPropertyType.string, optional: true),
      SchemaProperty('rawKeys', RealmPropertyType.string),
    ]);
  }
}
