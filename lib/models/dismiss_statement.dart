import 'package:oneofus_common/clock.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';

const String kNerdsterDisType = 'org.nerdster.dis';

class DismissStatement extends Statement {
  static final Map<String, DismissStatement> _cache = <String, DismissStatement>{};

  static void clearCache() => _cache.clear();

  /// 'forever', 'snooze', or null (= clear / un-dismiss).
  final String? dismiss;

  DelegateKey get iKey => DelegateKey(getToken(i));

  ContentKey get subjectAsContent => ContentKey(subjectToken);

  @override
  bool get isClear => dismiss == null;

  static void init() {
    Statement.registerFactory(
        kNerdsterDisType, _DismissStatementFactory(), DismissStatement, kNerdsterDisType);
  }

  factory DismissStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;

    final dynamic rawSubject = jsonish['rate'];
    assert(rawSubject != null, 'DismissStatement missing rate subject');

    final String? dis = (jsonish['with'] as Map?)?['dismiss'] as String?;
    assert(dis == null || dis == 'forever' || dis == 'snooze',
        'DismissStatement invalid dismiss value: $dis');

    final DismissStatement s = DismissStatement._internal(jsonish, rawSubject, dismiss: dis);
    _cache[s.token] = s;
    return s;
  }

  static DismissStatement? find(String token) => _cache[token];

  DismissStatement._internal(super.jsonish, super.subject, {required this.dismiss});

  /// Builds the JSON for a dismiss or un-dismiss (clear) statement.
  /// Pass dismiss=null to issue a clear.
  static Json make(Json iJson, dynamic subject, String? dismiss) {
    assert(dismiss == null || dismiss == 'forever' || dismiss == 'snooze');
    final String s = (subject is String) ? subject : getToken(subject);
    final Json json = {
      'statement': kNerdsterDisType,
      'time': clock.nowIso,
      'I': iJson,
      'rate': s,
    };
    if (dismiss != null) {
      json['with'] = {'dismiss': dismiss};
    }
    return json;
  }

  /// One effective dismiss state per (issuer, subject) pair.
  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    final String ti = iTransformer != null ? iTransformer(iToken) : iToken;
    final String s = sTransformer != null ? sTransformer(subjectToken) : subjectToken;
    return '$ti:$s';
  }
}

class _DismissStatementFactory implements StatementFactory {
  static final _DismissStatementFactory _singleton = _DismissStatementFactory._internal();
  _DismissStatementFactory._internal();
  factory _DismissStatementFactory() => _singleton;
  @override
  Statement make(Jsonish j) => DismissStatement(j);
}
