import 'jsonish.dart';
export 'jsonish.dart';
import 'statement.dart';
import 'util.dart';
import 'keys.dart';

const String kOneofusDomain = 'one-of-us.net';

class TrustStatement extends Statement {
  // CONSIDER: wipeCaches? ever?
  static final Map<String, TrustStatement> _cache = <String, TrustStatement>{};

  static void init() {
    Statement.registerFactory('net.one-of-us', _TrustStatementFactory(), TrustStatement, kOneofusDomain);
  }

  final TrustVerb verb;

  // with
  final String? moniker;
  final String? revokeAt;
  final String? domain;

  IdentityKey get iKey => IdentityKey(getToken(this.i));
  String get iToken => iKey.value;

  IdentityKey get subjectAsIdentity {
    if (verb == TrustVerb.trust || 
        verb == TrustVerb.block || 
        verb == TrustVerb.replace || 
        verb == TrustVerb.clear) {
      return IdentityKey(subjectToken);
    }
     throw 'Subject of $verb statement is not an IdentityKey';
  }

  DelegateKey get subjectAsDelegate {
    if (verb == TrustVerb.delegate || verb == TrustVerb.clear) {
      return DelegateKey(subjectToken);
    }
    throw 'Subject of $verb statement is not a DelegateKey';
  }

  bool clears(TrustStatement other) {
    if (verb != TrustVerb.clear) return false;
    // Clearing a trust/block/replace (Identity)
    if (other.verb == TrustVerb.trust || other.verb == TrustVerb.block || other.verb == TrustVerb.replace) {
       return other.subjectAsIdentity.value == subjectToken;
    }
    // Clearing a delegation (Delegate)
    if (other.verb == TrustVerb.delegate) {
      return other.subjectAsDelegate.value == subjectToken;
    }
    return false;
  }

  factory TrustStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;

    TrustVerb? verb;
    dynamic subject;
    for (verb in TrustVerb.values) {
      subject = jsonish[verb.label];
      if (b(subject)) break; // could continue to loop to assert that there isn't a second subject
    }
    assert(b(subject));

    Json? withx = jsonish['with'];
    TrustStatement s = TrustStatement._internal(
      jsonish,
      subject,
      verb: verb!,
      // with
      moniker: (withx != null) ? withx['moniker'] : null,
      revokeAt: (withx != null) ? withx['revokeAt'] : null,
      domain: (withx != null) ? withx['domain'] : null,
    );
    _cache[s.token] = s;
    return s;
  }


  static TrustStatement? find(String token) => _cache[token];

  static void assertValid(
      TrustVerb verb, String? revokeAt, String? moniker, String? comment, String? domain) {
    switch (verb) {
      case TrustVerb.trust:
        assert(!b(revokeAt));
        // assert(b(moniker)); For phone UI in construction..
        assert(!b(domain));
      case TrustVerb.block:
        assert(!b(revokeAt));
        assert(!b(domain));
      case TrustVerb.replace:
        // assert(b(comment)); For phone UI in construction..
        // assert(b(revokeAt)); For phone UI in construction..
        assert(!b(domain));
      case TrustVerb.delegate:
      // assert(b(domain)); For phone UI in construction..
      case TrustVerb.clear:
    }
  }

  TrustStatement._internal(
    super.jsonish,
    super.subject, {
    required this.verb,
    required this.moniker,
    required this.revokeAt,
    required this.domain,
  }) {
    assertValid(verb, revokeAt, moniker, comment, domain);
  }

  // A fancy StatementBuilder would be nice, but the important thing is not to have
  // strings like 'revokeAt' all over the code, and this avoids most of it.
  // CONSIDER: A fancy StatementBuilder.
  static Json make(Json iJson, Json subject, TrustVerb verb,
      {String? revokeAt, String? moniker, String? domain, String? comment}) {
    assertValid(verb, revokeAt, moniker, comment, domain);
    // (This below happens (iKey == subjectKey) when:
    // I'm bart; Sideshow replaces my key; I clear his statement replacing my key.
    // assert(Jsonish(iJson) != Jsonish(otherJson));)

    Json json = {
      'statement': Statement.type<TrustStatement>(),
      'time': clock.nowIso,
      'I': iJson,
      verb.label: subject,
    };
    if (comment != null) json['comment'] = comment;
    Json withx = {};
    if (revokeAt != null) withx['revokeAt'] = revokeAt;
    if (domain != null) withx['domain'] = domain;
    if (moniker != null) withx['moniker'] = moniker;
    withx.removeWhere((key, value) => !b(value));
    if (withx.isNotEmpty) json['with'] = withx;
    return json;
  }

  @override
  bool get isClear => verb == TrustVerb.clear;

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    String canonI = b(iTransformer) ? iTransformer!(iToken) : iToken;
    String canonS = b(sTransformer) ? sTransformer!(subjectToken) : subjectToken;
    return [canonI, canonS].join(':');
  }
}

class _TrustStatementFactory implements StatementFactory {
  static final _TrustStatementFactory _singleton = _TrustStatementFactory._internal();
  _TrustStatementFactory._internal();
  factory _TrustStatementFactory() => _singleton;
  @override
  Statement make(j) => TrustStatement(j);
}
