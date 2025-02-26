import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';

const String kNerdsterDomain = 'nerdster.org';
const String kNerdsterType = 'org.nerdster';

class ContentStatement extends Statement {
  static final Map<String, ContentStatement> _cache = <String, ContentStatement>{};

  final ContentVerb verb;

  // with
  final dynamic other;
  final bool? recommend; // CONSIDER: make verb
  final bool? dismiss; // CONSIDER: make verb
  final Json? contexts;

  static void init() {
    Statement.registerFactory(kNerdsterType, _ContentStatementFactory());
  }

  factory ContentStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;

    ContentVerb? verb;
    dynamic subject;
    for (verb in ContentVerb.values) {
      subject = jsonish[verb.label];
      if (b(subject)) {
        break;
      }
    }
    assert(b(subject));

    Json? withx = jsonish['with'];
    ContentStatement s = ContentStatement._internal(
      jsonish,
      subject,
      verb: verb!,
      // with (would be nice if Dart would let me pass the Map as the args)
      other: b(withx) ? withx!['otherSubject'] : null,
      recommend: b(withx) ? withx!['recommend'] : null,
      dismiss: b(withx) ? withx!['dismiss'] : null,
      contexts: b(withx) ? withx!['contexts'] : null,
    );
    _cache[s.token] = s;
    return s;
  }

  static ContentStatement? find(String token) => _cache[token];

  ContentStatement._internal(
    super.jsonish,
    super.subject, {
    required this.verb,
    required this.other,
    required this.recommend,
    required this.dismiss,
    required this.contexts,
  });

  // A fancy StatementBuilder would be nice, but the important thing is not to have
  // strings like 'revokeAt' all over the code, and this avoids most of it.
  // CONSIDER: A fancy StatementBuilder.
  // CONSIDER: Factoring a little more into parent.
  static Json make(Json iJson, ContentVerb verb, dynamic subject,
      {String? comment, Json? other, bool? recommend, bool? dismiss, Json? contexts}) {
    Json json = {
      'statement': kNerdsterType,
      'time': clock.nowIso,
      'I': iJson,
      verb.label: subject,
    };
    if (comment != null) {
      json['comment'] = comment;
    }
    Json withx = {
      'otherSubject': other,
      'recommend': recommend,
      'dismiss': dismiss,
      'contexts': contexts,
    };
    withx.removeWhere((key, value) => !b(value));
    if (withx.isNotEmpty) {
      json['with'] = withx;
    }
    return json;
  }

  // KLUDGEY'ish: The transformer is applied on
  // - iToken: always
  // - subjectToken: never
  // SUSPECT: The assumption is that transformer is delegate2oneofus.
  // Note that ContentVerb.follow statements use a Nerdster token for 'I' and a Oneofus
  // token for 'subject'
  @override
  String getDistinctSignature({Transformer? transformer}) {
    String tiToken = b(transformer) ? transformer!(iToken) : iToken;
    String tSubjectToken = subjectToken;
    if (b(other)) {
      // We want just one of 'subject relatedTo otherSubject' and 'otherSubject relatedTo subject',
      // and so we sort the tokens.
      String s1 = tSubjectToken;
      String s2 = getToken(other);
      if (s1.compareTo(s2) < 0) {
        return [tiToken, s1, s2].join(':');
      } else {
        return [tiToken, s2, s1].join(':');
      }
    } else {
      return [tiToken, subjectToken].join(':');
    }
  }

  @override
  bool get isClear => verb == ContentVerb.clear;
}

class _ContentStatementFactory implements StatementFactory {
  @override
  Statement make(j) => ContentStatement(j);
}
