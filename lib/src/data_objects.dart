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
  final String id, sd;
  final String? p;
  final List<String>? pl;
  const Reaction(this.id, this.sd, {this.p, this.pl});

  Reaction.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        sd = json['sd'] as String,
        p = json['p'] as String?,
        pl = json['pl'] as List<String>?;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sd': sd,
        'p': p,
        'pl': pl,
      }..removeWhere((key, value) => value == null);
}

class Message {
  final String id, sd, tn, nm;
  final String? t, p;
  final int ts;
  final List<String>? pl, r, n;
  const Message(this.id, this.sd, this.tn, this.nm, this.ts,
      {this.t, this.p, this.pl, this.r, this.n});

  Message.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        sd = json['id'] as String,
        tn = json['tn'] as String,
        nm = json['nm'] as String,
        t = json['t'] as String?,
        p = json['p'] as String?,
        ts = json['ts'] as int,
        pl = json['pl'] as List<String>?,
        r = json['r'] as List<String>?,
        n = json['n'] as List<String>?;

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
      }..removeWhere((key, value) => value == null);
}

class Node {
  final NodeTypes t;
  final String id, nm, im;
  final String? tn;
  final List<String>? rt, adm, usr, cht, mkt, cpt, jnl, itm, evt, tkt;
  Node(
    this.t,
    this.id,
    this.nm,
    this.im, {
    this.tn,
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
        id = json['id'] as String,
        nm = json['nm'] as String,
        im = json['im'] as String,
        tn = json['tn'] as String,
        rt = json['rt'] as List<String>?,
        adm = json['adm'] as List<String>?,
        usr = json['usr'] as List<String>?,
        cht = json['cht'] as List<String>?,
        mkt = json['mkt'] as List<String>?,
        cpt = json['cpt'] as List<String>?,
        jnl = json['jnl'] as List<String>?,
        itm = json['itm'] as List<String>?,
        evt = json['evt'] as List<String>?,
        tkt = json['tkt'] as List<String>?;

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
        'tkt': tkt
      }..removeWhere((key, value) => value == null);
}
