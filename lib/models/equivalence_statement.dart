import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';

const String kNerdsterEquivalenceType = 'org.nerdster.equivalence';

enum EquivalenceVerb { equate, dontEquate, clear }

class EquivalenceStatement extends Statement {
  static final Map<String, EquivalenceStatement> _cache = {};

  static void clearCache() => _cache.clear();

  /// The equivalent (non-canonical) side; stored in with.otherSubject.
  final String equivalent;

  final EquivalenceVerb verb;

  /// The canonical side; stored in the verb field (equate/dontEquate/clear).
  String get canonical => subject;

  bool get not => verb == EquivalenceVerb.dontEquate;

  @override
  bool get isClear => verb == EquivalenceVerb.clear;

  DelegateKey get iKey => DelegateKey(getToken(i));
  @override
  String get iToken => iKey.value;

  static void init() {
    Statement.registerFactory(kNerdsterEquivalenceType, _EquivalenceStatementFactory(),
        EquivalenceStatement, kNerdsterEquivalenceType);
  }

  factory EquivalenceStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;

    EquivalenceVerb? verb;
    String? subject;
    for (final v in EquivalenceVerb.values) {
      final dynamic s = jsonish[v.name];
      if (s != null) { verb = v; subject = s as String; break; }
    }
    assert(verb != null && subject != null, 'EquivalenceStatement missing equate/dontEquate/clear field');

    // with.otherSubject holds the equivalent (non-canonical) string.
    final dynamic other = (jsonish['with'] as Map?)?['otherSubject'];
    assert(other is String, 'EquivalenceStatement with.otherSubject must be a plain string');

    final EquivalenceStatement s = EquivalenceStatement._internal(jsonish, subject as String,
        equivalent: other as String, verb: verb!);
    _cache[s.token] = s;
    return s;
  }

  static EquivalenceStatement? find(String token) => _cache[token];

  EquivalenceStatement._internal(super.jsonish, super.subject,
      {required this.equivalent, required this.verb});

  /// [canonical] goes in the verb field; [equivalent] goes in with.otherSubject.
  static Json make(Json iJson, String equivalent, String canonical,
      {EquivalenceVerb verb = EquivalenceVerb.equate}) {
    return {
      'statement': kNerdsterEquivalenceType,
      'time': clock.nowIso,
      'I': iJson,
      verb.name: canonical,
      'with': {'otherSubject': equivalent},
    };
  }

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    final String ti = iTransformer != null ? iTransformer(iToken) : iToken;
    final List<String> pair = [canonical, equivalent]..sort();
    return 'equivalence:$ti:${pair.join(":")}';
  }
}

class _EquivalenceStatementFactory implements StatementFactory {
  static final _EquivalenceStatementFactory _singleton = _EquivalenceStatementFactory._internal();
  _EquivalenceStatementFactory._internal();
  factory _EquivalenceStatementFactory() => _singleton;
  @override
  Statement make(Jsonish j) => EquivalenceStatement(j);
}
