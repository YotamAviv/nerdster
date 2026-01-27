import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/oneofus/jsonish.dart';

const String jsonStatements = '''
[
  {
    "user": "Yotam Aviv",
    "date": "2017-06-07T01:49:06Z",
    "tags": [
      "news"
    ],
    "subject": {
      "contentType": "article",
      "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/",
      "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com"
    }
  },
  {
    "user": "Yotam Aviv",
    "date": "2017-06-07T01:49:06Z",
    "tags": [
      "film"
    ],
    "subject": {
      "contentType": "movie",
      "title": "Hell or High Water",
      "year": 2016
    }
  }
]''';

void main() {
  test('json decode statements', () {
    var statements = jsonDecode(jsonStatements);
    expect(statements is List, true);
    expect(statements[0] is Map, true);
    expect(statements[0]['user'], 'Yotam Aviv');
  });

  test('json encode map created in different order', () {

    Map map1 = {};
    // expect(map1.runtimeType.toString(), '');
    map1['a'] = 1;
    map1['b'] = 2;
    const String map1json = '''
{
  "a": 1,
  "b": 2
}''';

    Map map2 = {};
    map2['b'] = 2;
    map2['a'] = 1;
    const String map2json = '''
{
  "b": 2,
  "a": 1
}''';

    expect(encoder.convert(map1), map1json);
    expect(encoder.convert(map2), map2json);
  });

  test('json encode statements', () {
    var statements = jsonDecode(jsonStatements);
    String jsonStatements2 = encoder.convert(statements);

    expect(jsonStatements2, jsonStatements);
  });
}
