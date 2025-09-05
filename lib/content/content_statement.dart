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
  final bool? like;
  final bool? dismiss;
  final bool? censor;
  final Json? contexts; // (verb == follow)

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
      like: b(withx) ? withx!['recommend'] : null,
      dismiss: b(withx) ? withx!['dismiss'] : null,
      censor: b(withx) ? withx!['censor'] : null,
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
    required this.like,
    required this.dismiss,
    required this.censor,
    required this.contexts,
  });

  // A fancy StatementBuilder would be nice, but the important thing is not to have
  // strings like 'revokeAt' all over the code, and this avoids most of it.
  // CONSIDER: A fancy StatementBuilder.
  // CONSIDER: Factoring a little more into parent.
  static Json make(Json iJson, ContentVerb verb, dynamic subject,
      {String? comment,
      Json? other,
      bool? recommend,
      bool? dismiss,
      bool? censor,
      Json? contexts}) {
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
      'censor': censor,
      'contexts': contexts,
    };
    withx.removeWhere((key, value) => !b(value));
    if (withx.isNotEmpty) {
      json['with'] = withx;
    }
    return json;
  }

  // KLUDGEY, messy, possibly buggy..
  // The transformer is applied on
  // - I: always
  // - subject: never
  // The assumption is that transformer is delegate2oneofus, which I believe maps delegates to
  // canonical oneofus.
  // ContentVerb.follow statements use a Nerdster token for 'I' and a Oneofus token for 'subject'
  // It would seem that for the Nerdster follow case this should transform
  // - I using followNet.delegate2oneofus
  // - subject using getCanonical.getCanonical
  // This is tested in '!canon follow !canon, multiple delegates'
  // It may be the case that followNet does this without leveraging distinct/merge.
  // Smells like I could do something smart like map/reduce.
  @override
  String getDistinctSignature({Transformer? transformer}) {
    String tiToken = b(transformer) ? transformer!(iToken) : iToken;
    String tSubjectToken = subjectToken; // (not transformed)
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
  static final _ContentStatementFactory _singleton = _ContentStatementFactory._internal();
  _ContentStatementFactory._internal();
  factory _ContentStatementFactory() => _singleton;
  @override
  Statement make(j) => ContentStatement(j);
}
