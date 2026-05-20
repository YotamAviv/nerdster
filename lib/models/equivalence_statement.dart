import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';

const String kNerdsterEquivalenceType = 'org.nerdster.equivalence';

class EquivalenceStatement extends Statement {
  static final Map<String, EquivalenceStatement> _cache = {};

  static void clearCache() => _cache.clear();

  /// The equivalent (non-canonical) side; stored in with.otherSubject.
  final String otherString;

  /// True if this is a dontEquate; false if equate.
  final bool not;

  /// True if this is a clear statement (removes the prior equate/dontEquate).
  final bool _clear;

  /// The canonical side; stored in the verb field (equate/dontEquate/clear).
  String get string => subjectToken;

  @override
  bool get isClear => _clear;

  DelegateKey get iKey => DelegateKey(getToken(i));
  @override
  String get iToken => iKey.value;

  static void init() {
    Statement.registerFactory(kNerdsterEquivalenceType, _EquivalenceStatementFactory(),
        EquivalenceStatement, kNerdsterEquivalenceType);
  }

  factory EquivalenceStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;

    final dynamic equateSubject = jsonish['equate'];
    final dynamic dontEquateSubject = jsonish['dontEquate'];
    final dynamic clearSubject = jsonish['clear'];
    assert(equateSubject != null || dontEquateSubject != null || clearSubject != null,
        'EquivalenceStatement missing equate/dontEquate/clear field');

    final bool isDont = dontEquateSubject != null;
    final bool isClearVerb = clearSubject != null;
    // The verb field holds the canonical string.
    final dynamic rawSubject = isClearVerb ? clearSubject : (isDont ? dontEquateSubject : equateSubject);
    assert(rawSubject is String, 'EquivalenceStatement subject must be a plain string');

    // with.otherSubject holds the equivalent (non-canonical) string.
    final dynamic other = (jsonish['with'] as Map?)?['otherSubject'];
    assert(other is String, 'EquivalenceStatement with.otherSubject must be a plain string');

    final EquivalenceStatement s = EquivalenceStatement._internal(jsonish, rawSubject as String,
        otherString: other as String, not: isDont, clear: isClearVerb);
    _cache[s.token] = s;
    return s;
  }

  static EquivalenceStatement? find(String token) => _cache[token];

  EquivalenceStatement._internal(super.jsonish, super.subject,
      {required this.otherString, required this.not, required bool clear})
      : _clear = clear;

  /// Builds the JSON for an equate or dontEquate statement.
  /// [canonical] goes in the verb field; [equivalent] goes in with.otherSubject —
  /// matching the ContentStatement equate convention.
  static Json make(Json iJson, String equivalent, String canonical,
      {bool not = false, bool clear = false}) {
    final String verb = clear ? 'clear' : (not ? 'dontEquate' : 'equate');
    return {
      'statement': kNerdsterEquivalenceType,
      'time': clock.nowIso,
      'I': iJson,
      verb: canonical,
      'with': {'otherSubject': equivalent},
    };
  }

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    final String ti = iTransformer != null ? iTransformer(iToken) : iToken;
    final List<String> pair = [string, otherString]..sort();
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
