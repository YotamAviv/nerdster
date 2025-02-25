import 'jsonish.dart';
import 'statement.dart';
import 'util.dart';

const String kOneofusDomain = 'one-of-us.net';
const String kOneofusType = 'net.one-of-us';

enum TrustVerb {
  trust('trust', 'trusted'),
  block('block', 'blocked'),
  replace('replace', 'replaced'), // requires 'revokeAt'

  delegate('delegate', 'delegated'), // allows 'revokeAt' 

  clear('clear', 'cleared');

  const TrustVerb(this.label, this.pastTense);
  final String label;
  final String pastTense;
}

class TrustStatement extends Statement {
  // CONSIDER: wipeCaches? ever?
  static final Map<String, TrustStatement> _cache = <String, TrustStatement>{};

  static void init() {
    Statement.registerFactory(kOneofusType, _TrustStatementFactory());
  }

  final TrustVerb verb;

  // with
  final String? moniker;
  final String? revokeAt;
  final String? domain;

  factory TrustStatement (Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) {
      return _cache[jsonish.token]!;
    }
    Json json = jsonish.json;

    TrustVerb? verb;
    dynamic subject;
    for (verb in TrustVerb.values) {
      subject = json[verb.label];
      if (b(subject)) {
        break; // could continue to loop to make sure that there isn't a second subject
      }
    }
    assert(b(subject));

    Json? withx = json['with'];
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

  static void assertValid(TrustVerb verb, String? revokeAt, String? moniker, String? comment, String? domain) {
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
    super.subject,
    {
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
  static Json make(Json iJson, Json otherJson, TrustVerb verb,
      {String? revokeAt, String? moniker, String? domain, String? comment}) {
    assertValid(verb, revokeAt, moniker, comment, domain);
    // (This below happens (iKey == subjectKey) when:
    // I'm bart; Sideshow replaces my key; I clear his statement replacing my key.
    // assert(Jsonish(iJson) != Jsonish(otherJson));)

    Json json = {
      'statement': kOneofusType,
      'time': clock.nowIso,
      'I': iJson,
      verb.label: otherJson,
    };
    if (comment != null) {
      json['comment'] = comment;
    }
    Json withx = {};
    if (revokeAt != null) {
      withx['revokeAt'] = revokeAt;
    }
    if (domain != null) {
      withx['domain'] = domain;
    }
    if (moniker != null) {
      withx['moniker'] = moniker;
    }
    withx.removeWhere((key, value) => !b(value));
    if (withx.isNotEmpty) {
      json['with'] = withx;
    }
    return json;
  }

  @override
  bool get isClear => verb == TrustVerb.clear;
  
  @override
  // NOTE: We use transformer on {iToken, 'subjectToken'}. That could be cleaner
  // expressing which of the 2 or both we want, but I see no harm.
  String getDistinctSignature({String Function(String)? transformer}) {
    String canonI = b(transformer) ? transformer!(iToken) : iToken;
    String canonS = b(transformer) ? transformer!(subjectToken) : subjectToken;
    return [canonI, canonS].join(':');
  } 
}

class _TrustStatementFactory implements StatementFactory { 
  @override
  Statement make(j) => TrustStatement(j);
}
