import 'jsonish.dart';
import 'util.dart';

typedef Transformer = String Function(String);

abstract class Statement {
  final Jsonish jsonish;
  final DateTime time;
  final Json i;
  final String iToken;

  final dynamic
      subject; // Object of verb, may be Json or a token (like, for censor) or a statement..

  final String? comment;
  static final Map<Type, String> _class2type = <Type, String>{};
  static final Map<String, String> _domain2type = <String, String>{};

  static void registerFactory(String type, StatementFactory factory, Type statementClass,
      [String? domain]) {
    if (_type2factory.containsKey(type)) assert(_type2factory[type] == factory);
    _type2factory[type] = factory;
    _class2type[statementClass] = type;
    if (domain != null) {
      _domain2type[domain] = type;
    }
  }

  static final Map<String, StatementFactory> _type2factory = <String, StatementFactory>{};

  static Statement make(Jsonish j) => _type2factory[j['statement']]!.make(j);

  static String type<T extends Statement>() => _class2type[T]!;

  static String typeForDomain(String domain) => _domain2type[domain]!;

  Statement(this.jsonish, this.subject)
      : time = parseIso(jsonish['time']),
        i = jsonish['I'],
        iToken = getToken(jsonish['I']),
        comment = jsonish['comment'];

  String get subjectToken {
    if (subject is String) {
      return subject;
    } else {
      return getToken(subject);
    }
  }

  String get token => jsonish.token;

  dynamic operator [](String key) => jsonish[key];
  bool containsKey(String key) => jsonish.containsKey(key);
  Iterable get keys => jsonish.keys;
  Iterable get values => jsonish.values;

  String getDistinctSignature({Transformer? transformer});

  bool get isClear;

  // CODE: As a lot uses either Json or a token (subject, other, iKey), it might
  // make sense to make Jsonish be Json or a string token.
  // One challenge would be managing the cache, say we encounter a Jsonish string token and later
  // encounter its Json equivalent. The factory methods are where these come from, and so it should
  // be manageable.
  // Try to reduce uses and switch to []
  Json get json => jsonish.json;
}

abstract class StatementFactory {
  Statement make(Jsonish j);
}
