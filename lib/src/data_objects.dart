typedef Identifier = String;
typedef Base64Image = String;
typedef Name = String;

enum NodeTypes {
  rt,
  usr,
  cht,
  mkt,
  cpt,
  jnl,
  itm,
  evt,
  tkt,
}

class Reaction {
  final Identifier id, sd;
  final Base64Image? p;
  final List<Base64Image>? pl;
  const Reaction({required this.id, required this.sd, this.p, this.pl});

  Reaction.fromJson(Map<String, dynamic> json)
      : id = json['id'] as Identifier,
        sd = json['sd'] as Identifier,
        p = json['p'] as Base64Image?,
        pl = json['pl'] as List<Base64Image>?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sd': sd,
        'p': p,
        'pl': pl,
      }..removeWhere((key, value) => value == null);
}

class Down4Message {
  final Identifier id, sd; // sender, live-parent
  final Base64Image tn;
  final Name nm;
  final String? t; // text
  final Base64Image? p; // photo
  final int? ts;
  final bool ch; // true is chat, false is post
  final List<Base64Image>? pl; // photoloop
  final List<Identifier>? r, n; // reactions, nodes
  const Down4Message(
      {required this.id,
      required this.sd,
      required this.tn,
      required this.nm,
      required this.ch,
      this.ts,
      this.t,
      this.p,
      this.pl,
      this.r,
      this.n});

  Down4Message.fromJson(Map<String, dynamic> json)
      : id = json['id'] as Identifier,
        sd = json['sd'] as Identifier,
        tn = json['tn'] as Base64Image,
        nm = json['nm'] as Name,
        ch = json['ch'] as bool,
        t = json['t'] as String?,
        p = json['p'] as Base64Image?,
        ts = json['ts'] as int,
        pl = json['pl'] as List<Base64Image>?,
        r = json['r'] as List<Identifier>?,
        n = json['n'] as List<Identifier>?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sd': sd,
        'tn': tn,
        'nm': nm,
        't': t,
        'p': p,
        'ts': ts,
        'pl': pl,
        'r': r,
        'n': n,
        'ch': ch
      }..removeWhere((key, value) => value == null);
}

class Node {
  final NodeTypes t;
  final Identifier id;
  final Name nm;
  final Base64Image im;
  final Base64Image? tn;
  final List<Identifier>? rt, adm, usr, cht, mkt, cpt, jnl, itm, evt, tkt;
  final List<Identifier>? msg, pst;
  Node({
    required this.t,
    required this.id,
    required this.nm,
    required this.im,
    this.tn,
    this.msg,
    this.pst,
    this.rt,
    this.adm,
    this.usr,
    this.cht,
    this.mkt,
    this.cpt,
    this.jnl,
    this.itm,
    this.evt,
    this.tkt,
  });

  Node.fromJson(Map<String, dynamic> json)
      : t = NodeTypes.values.byName(json['t']),
        id = json['id'] as Identifier,
        nm = json['nm'] as Name,
        im = json['im'] as Base64Image,
        tn = json['tn'] as Base64Image,
        rt = json['rt'] as List<Identifier>?,
        adm = json['adm'] as List<Identifier>?,
        usr = json['usr'] as List<Identifier>?,
        cht = json['cht'] as List<Identifier>?,
        mkt = json['mkt'] as List<Identifier>?,
        cpt = json['cpt'] as List<Identifier>?,
        jnl = json['jnl'] as List<Identifier>?,
        itm = json['itm'] as List<Identifier>?,
        evt = json['evt'] as List<Identifier>?,
        tkt = json['tkt'] as List<Identifier>?,
        pst = json['pst'] as List<Identifier>?,
        msg = json['msg'] as List<Identifier>?;

  Map<String, dynamic> toJson() => {
        't': t.name,
        'id': id,
        'nm': nm,
        'im': im,
        'tn': tn,
        'rt': rt,
        'adm': adm,
        'usr': usr,
        'cht': cht,
        'mkt': mkt,
        'cpt': cpt,
        'jnl': jnl,
        'itm': itm,
        'evt': evt,
        'tkt': tkt,
        'msg': msg,
        'pst': pst
      }..removeWhere((key, value) => value == null);
}
