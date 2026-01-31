import 'jsonish.dart';

typedef Transformer = String Function(String);

abstract class Statement {
  final Jsonish jsonish;
  final DateTime time;
  final Json i;
  final String iToken; // TODO: IdentityKey
  // Object of verb, may be Json or a token (like, for censor) or a statement..
  final dynamic subject;
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

  /// Verifies that a collection of statements is ordered by time (descending)
  /// and contains only one type of statement (TrustStatement or ContentStatement).
  /// Uses assert, only checks in debug mode
  static void validateOrderTypes(Iterable<Statement> statements) {
    assert(() {
      if (statements.isEmpty) return true;
      final Type firstType = statements.first.runtimeType;

      Statement? previous;
      int i = 0;
      for (final Statement current in statements) {
        if (current.runtimeType != firstType) {
          throw 'Collection contains mixed statement types: $firstType and ${current.runtimeType}';
        }

        if (previous != null) {
          if (!previous.time.isAfter(current.time)) {
            throw 'Statements are not in strictly descending time order.\n'
                'Index ${i - 1}: ${previous.time}\n'
                'Index $i: ${current.time}';
          }
        }
        previous = current;
        i++;
      }
      return true;
    }());
  }

  /// Helper to validate multiple collections of statements.
  /// Uses assert, only checks in debug mode
  static void validateOrderTypess(Iterable<Iterable<Statement>> collections) {
    assert(() {
      for (final collection in collections) {
        validateOrderTypes(collection);
      }
      return true;
    }());
  }

  Statement(this.jsonish, this.subject)
      : time = DateTime.parse(jsonish['time']),
        i = jsonish['I'],
        iToken = getToken(jsonish['I']),
        comment = jsonish['comment'];

  // TODO: CONSIDER: IdentityKey, DelegateKey, or ContentKey depending on verb
  // This would have to be done differently by ContentStatement and TrustStatement.
  // The same would be needed for other subject (content statement only, depends on follow or rate)
  String get subjectToken => (subject is String) ? subject : getToken(subject);

  String get token => jsonish.token;

  dynamic operator [](String key) => jsonish[key];
  bool containsKey(String key) => jsonish.containsKey(key);
  Iterable get keys => jsonish.keys;
  Iterable get values => jsonish.values;

  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer});

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
