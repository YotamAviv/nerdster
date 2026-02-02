import 'dart:convert';
import 'dart:io';

import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

const String jsonSubjects = '''
[
  {
    "contentType": "article",
    "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/",
    "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com"
  },
  {
    "contentType": "movie",
    "title": "Hell or High Water",
    "year": 2016
  },
  {
    "contentType": "article",
    "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/",
    "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com"
  }
]''';

const String jsonFakeNewsBadOrder = '''
{
  "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/",
  "contentType": "article",
  "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com"
}''';

const String jsonFakeNewsGoodOrder = '''
{
  "contentType": "article",
  "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com",
  "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/"
}''';

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
  },
  {
    "subject": {
      "contentType": "article",
      "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/",
      "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com"
    },
    "user": "Yotam Aviv",
    "date": "2024-04-04T10:24:02Z",
    "rating": 3
  }
]''';

const Json bartTrustsHomerUnsigned = {
  "statement": "net.one-of-us.trust",
  "I": {"crv": "Ed25519", "kty": "OKP", "x": "ZiM9U4jopOgkUHWpDdIuMcxahz1cEN5z1ZWQEqF1fng"},
  "comment": "dad",
  "date": "2024-05-01T07:01:00Z",
  "privateComment": "Homey",
  "subject": {"crv": "Ed25519", "kty": "OKP", "x": "qh97FymJdQResajTkoK7n5q8-8PK1KSnp2MEyVHCCx8"},
  "verb": "trust",
};

const Json bartTrustsHomerSigned = {
  "statement": "net.one-of-us.trust",
  "I": {"crv": "Ed25519", "kty": "OKP", "x": "ZiM9U4jopOgkUHWpDdIuMcxahz1cEN5z1ZWQEqF1fng"},
  "comment": "dad",
  "date": "2024-05-01T07:01:00Z",
  "privateComment": "Homey",
  "subject": {"crv": "Ed25519", "kty": "OKP", "x": "qh97FymJdQResajTkoK7n5q8-8PK1KSnp2MEyVHCCx8"},
  "verb": "trust",
  "signature":
      "77778e9e13ec1025f4d641ad650b26884a1fd5101edee06897c6152bc66a33747f6c5fb4d6e115fb2c135f8e58f8d2fd05ebf892425365836b3236fa045b0e0e"
};

void main() {
  test('json: decode', () {
    Jsonish.wipeCache();
    var statements = jsonDecode(jsonStatements);
    expect(statements is List, true);
    expect(statements[0] is Map, true);
    expect(statements[0]['user'], 'Yotam Aviv');
  });

  test('== and identical', () async {
    Jsonish.wipeCache();
    var subjects = jsonDecode(jsonSubjects);

    Jsonish fakenews = Jsonish(subjects[0]);
    Jsonish fakenews2 = Jsonish(subjects[2]);

    try {
      fakenews.json['dummy'] = 'dummy';
      fail('expected exception. map should be immutable');
    } catch (e) {
      // expected.
    }

    expect(fakenews, fakenews2);
    expect(fakenews.hashCode, fakenews2.hashCode);
    expect(fakenews.token, fakenews2.token);
    expect(identical(fakenews, fakenews2), true);
  });

  test('bad order', () async {
    Jsonish.wipeCache();
    var subjects = jsonDecode(jsonSubjects);
    var subjectsBadOrder = jsonDecode(jsonFakeNewsBadOrder);

    Jsonish fakenews = Jsonish(subjects[0]);
    Jsonish fakenewsBadOrder = Jsonish(subjectsBadOrder);

    expect(fakenews, fakenewsBadOrder);
    expect(fakenews.hashCode, fakenewsBadOrder.hashCode);
    expect(fakenews.token, fakenewsBadOrder.token);
    expect(identical(fakenews, fakenewsBadOrder), true);
  });

  test('identical subjects alone or from statement', () async {
    Jsonish.wipeCache();
    var subjects = jsonDecode(jsonSubjects);
    var statements = jsonDecode(jsonStatements);

    Jsonish fakenews = Jsonish(subjects[0]);
    Jsonish fakenewsFromStatement = Jsonish(statements[0]['subject']);

    expect(fakenews, fakenewsFromStatement);
    expect(fakenews.hashCode, fakenewsFromStatement.hashCode);
    expect(fakenews.token, fakenewsFromStatement.token);
    expect(identical(fakenews, fakenewsFromStatement), true);
  });

  test('good JSON from bad order', () async {
    Jsonish.wipeCache();
    Jsonish fakenewsBadOrder = Jsonish(jsonDecode(jsonFakeNewsBadOrder));
    String goodJson = fakenewsBadOrder.ppJson;

    expect(goodJson, jsonFakeNewsGoodOrder);
  });

  test('token cache', () async {
    Jsonish.wipeCache();
    Jsonish fakenews = Jsonish(jsonDecode(jsonFakeNewsBadOrder));
    String token = fakenews.token;
    Jsonish? fakenews2 = Jsonish.find(token);

    expect(identical(fakenews, fakenews2), true);
  });

  test('signature affects token', () async {
    // Keep commented out normally. Comment in to sign for subsequent testing
    // OouKeyPair keyPair = await CryptoFactoryEd25519().createKeyPair();
    // OouSigner signer = await OouSigner.make(keyPair);
    // Json copyToSign = Map.from(bartTrustsHomerUnsigned);
    // copyToSign['I'] = await (await keyPair.publicKey).json;
    // Jsonish signedX = await Jsonish.makeSign(copyToSign, signer);
    // print(signedX.ppJson);
    // return;

    Jsonish.wipeCache();
    Jsonish withoutSignature = Jsonish(bartTrustsHomerUnsigned);

    Jsonish.wipeCache();
    Jsonish withSignature = Jsonish(bartTrustsHomerSigned);
    expect(withoutSignature.token != withSignature.token, true);

    Jsonish.wipeCache();
    Jsonish withSignatureVerified = await Jsonish.makeVerify(bartTrustsHomerSigned, OouVerifier());
    expect(withSignature.token, withSignatureVerified.token);
  });

  test('unknown keys at bottom but above signature', () async {
    const Json statementBadOrder = {
      "signature":
          "268613a844523fe8682ced911f724df04d9502056dd172ffa6b5b9dec5ee9d29ffc5748d71da3c8625511a928f97ae0639b8c4e1321135d964b36c588f718907",
      "statement": "net.one-of-us",
      "time": "2025-02-17T14:22:24.842019Z",
      "I": {"crv": "Ed25519", "kty": "OKP", "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"},
      "with": {"moniker": "Eyal F"},
      "previous": "bf020f1641972aed5cbd4c6c040f78e5d936e105",
      "trust": {"kty": "OKP", "crv": "Ed25519", "x": "M7l7bQBumX2Z-Rhh8M2nvgupd65ZwNn8x0uHY7H5bRY"}
    };

    Jsonish.wipeCache();
    Jsonish jsonish = Jsonish(statementBadOrder);
    expect(jsonish.ppJson, '''{
  "statement": "net.one-of-us",
  "time": "2025-02-17T14:22:24.842019Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
  },
  "trust": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "M7l7bQBumX2Z-Rhh8M2nvgupd65ZwNn8x0uHY7H5bRY"
  },
  "with": {
    "moniker": "Eyal F"
  },
  "previous": "bf020f1641972aed5cbd4c6c040f78e5d936e105",
  "signature": "268613a844523fe8682ced911f724df04d9502056dd172ffa6b5b9dec5ee9d29ffc5748d71da3c8625511a928f97ae0639b8c4e1321135d964b36c588f718907"
}''');

    Json statementBadOrderWithUnknownKeys = Map.from(statementBadOrder);
    statementBadOrderWithUnknownKeys['Timmy'] = 'rock';
    statementBadOrderWithUnknownKeys['Betty'] = 'Timmy';
    Jsonish.wipeCache();
    Jsonish jsonish2 = Jsonish(statementBadOrderWithUnknownKeys);
    // print(jsonish2.ppJson);
    expect(jsonish2.keys.last, 'signature');
    expect(jsonish2.ppJson, '''{
  "statement": "net.one-of-us",
  "time": "2025-02-17T14:22:24.842019Z",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "Fenc6ziXKt69EWZY-5wPxbJNX9rk3CDRVSAEnA8kJVo"
  },
  "trust": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "M7l7bQBumX2Z-Rhh8M2nvgupd65ZwNn8x0uHY7H5bRY"
  },
  "with": {
    "moniker": "Eyal F"
  },
  "previous": "bf020f1641972aed5cbd4c6c040f78e5d936e105",
  "Betty": "Timmy",
  "Timmy": "rock",
  "signature": "268613a844523fe8682ced911f724df04d9502056dd172ffa6b5b9dec5ee9d29ffc5748d71da3c8625511a928f97ae0639b8c4e1321135d964b36c588f718907"
}''');
  });

  test('yotam data', () async {
    // Helper to find test data whether running from root or package dir
    File findFile(String filename) {
      if (File('test/$filename').existsSync()) return File('test/$filename');
      if (File('packages/oneofus_common/test/$filename').existsSync()) {
        return File('packages/oneofus_common/test/$filename');
      }
      throw Exception('Could not find test data: $filename');
    }

    final Json yotamNerdster =
        jsonDecode(findFile('yotam-nerdster.json').readAsStringSync());
    final Json yotamOneofus =
        jsonDecode(findFile('yotam-oneofus.json').readAsStringSync());
    final Json other = jsonDecode(findFile('other.json').readAsStringSync());
    // DEFER: TEST: Other with unknow fields
    for (final exported in [yotamOneofus, yotamNerdster, other]) {
      for (final Json statement in exported['statements'] as Iterable) {
        // Kludge: The server communicates token as "id" to us in the statement.
        final id = statement['id'];
        statement.remove('id');
        Jsonish jsonish = Jsonish(statement);
        expect(jsonish.token, id);
      }
    }
  });

  test('no side effects to json source', () {
    Json json = {
      "map": {"b": true, "a": true},
      "list": ["b", "a"]
    };
    Jsonish(json);
    expect(json["list"], ["b", "a"]);
    expect(json["map"], {"b": true, "a": true});
  });

  test('json source immutable, no worries', () {
    Json json = {
      "map": Map.unmodifiable({"b": true, "a": true}),
      "list": List.unmodifiable(["b", "a"])
    };
    Jsonish(json);
  });

  test('print key2order', () {
    if (false) {
      print(encoder.convert(Jsonish.key2order));
    }
  });
}
