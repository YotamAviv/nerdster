import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';

const String kNerdsterDomain = 'nerdster.org';

class ContentStatement extends Statement {
  static final Map<String, ContentStatement> _cache = <String, ContentStatement>{};

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
         verb == ContentVerb.clear) { // Clear maps string to ContentKey here if needed, but 'clears' logic handles most
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
    if (other.verb == ContentVerb.relate || other.verb == ContentVerb.dontRelate ||
        other.verb == ContentVerb.equate || other.verb == ContentVerb.dontEquate) {
       
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

    if (verb == ContentVerb.rate || verb == ContentVerb.clear) {
      final isStatement = (s is Map && s.containsKey('statement')) || s is Statement;
      if (verb == ContentVerb.clear ||
          (censor == true) ||
          (verb == ContentVerb.rate && dismissVal != null) ||
          isStatement) {
        if (!debugUseSubjectNotToken) {
          s = getToken(s);
        }
      }
    } else {
      if (!debugUseSubjectNotToken) {
        s = getToken(s);
        if (b(o)) o = getToken(o);
      }
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
