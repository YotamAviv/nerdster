import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';

const String kNerdsterDomain = 'nerdster.org';

class ContentStatement extends Statement {
  static final Map<String, ContentStatement> _cache = <String, ContentStatement>{};

  static void clearCache() => _cache.clear();

  final ContentVerb verb;

  // with
  final dynamic other;
  final bool? like;
  final String? dismiss;
  final bool? censor;
  final Json? contexts; // (verb == follow)

  DelegateKey get iKey => DelegateKey(getToken(this.i));
  String get iToken => iKey.value;

  ContentKey get subjectAsContent {
    if (verb == ContentVerb.rate ||
        verb == ContentVerb.equate ||
        verb == ContentVerb.dontEquate ||
        verb == ContentVerb.relate ||
        verb == ContentVerb.dontRelate ||
        verb == ContentVerb.clear) {
      // Clear maps string to ContentKey here if needed, but 'clears' logic handles most
      return ContentKey(subjectToken);
    }
    throw 'Subject of $verb is not a ContentKey';
  }

  IdentityKey get subjectAsIdentity {
    if (verb == ContentVerb.follow || verb == ContentVerb.clear) {
      return IdentityKey(subjectToken);
    }
    throw 'Subject of $verb is not an IdentityKey';
  }

  ContentKey? get otherSubjectKey {
    if (other != null) {
      return ContentKey(getToken(other));
    }
    return null;
  }

  bool clears(ContentStatement other) {
    if (verb != ContentVerb.clear) return false;

    // 1. Basic Subject Match (Target Subject)
    if (other.subjectToken != subjectToken) return false;

    // 2. Binary Verbs (Relate/Equate) require matching 'other' subject too.
    if (other.verb == ContentVerb.relate ||
        other.verb == ContentVerb.dontRelate ||
        other.verb == ContentVerb.equate ||
        other.verb == ContentVerb.dontEquate) {
      // The clearing statement must also have an 'other' subject defined.
      if (otherSubjectKey == null) return false;

      // Compare the secondary keys.
      return other.otherSubjectKey?.value == otherSubjectKey?.value;
    }

    // 3. Unary Verbs (Rate, Follow) only require the primary subject match.
    return true;
  }

  static void init() {
    Statement.registerFactory(
        'org.nerdster', _ContentStatementFactory(), ContentStatement, kNerdsterDomain);
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

    dynamic rawDismiss = withx?['dismiss'];
    String? dismissVal;
    if (rawDismiss is bool && rawDismiss == true) {
      dismissVal = 'forever';
    } else if (rawDismiss is String) {
      dismissVal = rawDismiss;
    }

    ContentStatement s = ContentStatement._internal(
      jsonish,
      subject,
      verb: verb!,
      // with (would be nice if Dart would let me pass the Map as the args)
      other: withx?['otherSubject'],
      like: withx?['recommend'],
      dismiss: dismissVal,
      censor: withx?['censor'],
      contexts: withx?['contexts'],
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

  /// Encapsulates the logic for creating content statements, including the conditional
  /// tokenization (or not) of subject, other subject.
  static Json make(Json iJson, ContentVerb verb, dynamic subject,
      {String? comment,
      dynamic other,
      bool? recommend,
      dynamic dismiss,
      bool? censor,
      Json? contexts}) {
    dynamic s = subject;
    dynamic o = other;

    // Backward compatibility for dismiss: true -> 'forever'
    String? dismissVal;
    if (dismiss is bool && dismiss == true) {
      dismissVal = 'forever';
    } else if (dismiss is String) {
      dismissVal = dismiss;
    }

    final bool debugUseSubjectNotToken = Setting.get(SettingType.debugUseSubjectNotToken).value;

    final isStatement = (s is Map && s.containsKey('statement'));

    bool shouldTokenize = false;
    if (verb == ContentVerb.rate) {
      if (isStatement || censor == true) {
        shouldTokenize = true;
      }
    } else if (verb == ContentVerb.clear) {
      shouldTokenize = true;
    } else if (verb == ContentVerb.follow) {
      shouldTokenize = true;
    }

    if (shouldTokenize && !debugUseSubjectNotToken) {
      s = getToken(s);
    }

    Json json = {
      'statement': Statement.type<ContentStatement>(),
      'time': clock.nowIso,
      'I': iJson,
      verb.label: s,
    };
    if (comment != null) {
      json['comment'] = comment;
    }
    Json withx = {
      'otherSubject': o,
      'recommend': recommend,
      'dismiss': dismissVal,
      'censor': censor,
      'contexts': contexts,
    };
    withx.removeWhere((key, value) => !b(value));
    if (withx.isNotEmpty) {
      json['with'] = withx;
    }
    return json;
  }

  /// All subject tokens mentioned in this statement. Used for both indexing
  /// (making a "Relation" visible from either subject) and for signature generation.
  Iterable<String> get involvedTokens sync* {
    yield subjectToken;
    if (b(other)) yield getToken(other);
  }

  /// Generates a unique signature for this statement's intent to identify redundancies
  /// during aggregation (Merge + Distinct).
  ///
  /// - [iTransformer]: Maps the signer (usually a delegate) to their canonical identity.
  /// - [sTransformer]: Maps subjects to their canonical tokens (via Equivalence).
  ///
  /// Commutative operations (e.g., A relates to B) produce the same signature
  /// regardless of token order or which delegate issued them.
  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    final String tiToken = b(iTransformer) ? iTransformer!(iToken) : iToken;
    final List<String> ts =
        involvedTokens.map((t) => b(sTransformer) ? sTransformer!(t) : t).toList();

    // We want just one of 'subject relatedTo otherSubject' and 'otherSubject relatedTo subject',
    // and so we sort the tokens.
    if (ts.length > 1) ts.sort();

    return [tiToken, ...ts].join(':');
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
