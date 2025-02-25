import 'jsonish.dart';
import 'util.dart';

typedef Transformer = String Function(String);

abstract class Statement {
  final Jsonish jsonish;
  final DateTime time;
  final String iToken;
 
  final dynamic subject; // Object of verb, may be Json or a token (like, for censor) or a statement..

  final String? comment;

  static registerFactory(String type, StatementFactory factory) {
    if(_type2factory.containsKey(type)) {
      // assert(_type2factory[type] == factory);
    }
    _type2factory[type] = factory;
  }

  static final Map<String, StatementFactory> _type2factory = <String, StatementFactory>{};

  static Statement make(Jsonish j) {
    String type = j.json['statement'];
    return _type2factory[type]!.make(j);
  }

  Statement(this.jsonish, this.subject) :
      time = parseIso(jsonish.json['time']),
      iToken = getToken(jsonish.json['I']),
      comment = jsonish.json['comment'];

  String get subjectToken {
    if (subject is String) {
      return subject;
    } else {
      return Jsonish(subject).token;
    }
  }

  String get token => jsonish.token;
  Json get json => jsonish.json;

  String getDistinctSignature({Transformer? transformer});

  bool get isClear;
}

abstract class StatementFactory {
  Statement make(Jsonish j);
}