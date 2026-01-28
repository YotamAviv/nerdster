import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/jsonish.dart';
export 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';

const String kOneofusDomain = 'one-of-us.net';
const String kSinceAlways = '<since always>';

class TrustStatement extends Statement {
  // CONSIDER: wipeCaches? ever?
  static final Map<String, TrustStatement> _cache = <String, TrustStatement>{};

  static void clearCache() => _cache.clear();

  static void init() {
    Statement.registerFactory(
        'net.one-of-us', _TrustStatementFactory(), TrustStatement, kOneofusDomain);
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
    if (other.verb == TrustVerb.trust ||
        other.verb == TrustVerb.block ||
        other.verb == TrustVerb.replace) {
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
      if (subject != null)
        break; // could continue to loop to assert that there isn't a second subject
    }
    assert(subject != null);

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
        assert(revokeAt == null);
        // assert(b(moniker)); For phone UI in construction..
        assert(domain == null);
      case TrustVerb.block:
        assert(revokeAt == null);
        assert(domain == null);
      case TrustVerb.replace:
        // assert(b(comment)); For phone UI in construction..
        // assert(b(revokeAt)); For phone UI in construction..
        assert(domain == null);
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
    withx.removeWhere((key, value) => value == null);
    if (withx.isNotEmpty) json['with'] = withx;
    return json;
  }

  @override
  bool get isClear => verb == TrustVerb.clear;

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    String canonI = iTransformer != null ? iTransformer(iToken) : iToken;
    String canonS = sTransformer != null ? sTransformer(subjectToken) : subjectToken;
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
