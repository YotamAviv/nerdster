import 'dart:convert';

import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:test/test.dart';


const String jsonSubjects = 
'''
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

const String jsonFakeNewsBadOrder = 
'''
{
  "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/",
  "contentType": "article",
  "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com"
}''';

const String jsonFakeNewsGoodOrder = 
'''
{
  "contentType": "article",
  "title": "Fact Check: Trump Blasts ‘Fake News’ and Repeats Inaccurate Claims at CPAC - NYTimes.com",
  "url": "https://mobile.nytimes.com/2017/02/24/us/politics/fact-check-trump-blasts-fake-news-and-repeats-inaccurate-claims-at-cpac.html?referer=https://www.google.com/"
}''';

const String jsonStatements = 
'''
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

const Map<String, dynamic> bartTrustsHomerUnsigned = {
  "statement": "net.one-of-us.trust",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "ZiM9U4jopOgkUHWpDdIuMcxahz1cEN5z1ZWQEqF1fng"
  },
  "comment": "dad",
  "date": "2024-05-01T07:01:00Z",
  "privateComment": "Homey",
  "subject": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "qh97FymJdQResajTkoK7n5q8-8PK1KSnp2MEyVHCCx8"
  },
  "verb": "trust",
};

const Map<String, dynamic> bartTrustsHomerSigned = {
  "statement": "net.one-of-us.trust",
  "I": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "ZiM9U4jopOgkUHWpDdIuMcxahz1cEN5z1ZWQEqF1fng"
  },
  "comment": "dad",
  "date": "2024-05-01T07:01:00Z",
  "privateComment": "Homey",
  "subject": {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "qh97FymJdQResajTkoK7n5q8-8PK1KSnp2MEyVHCCx8"
  },
  "verb": "trust",
  "signature": "77778e9e13ec1025f4d641ad650b26884a1fd5101edee06897c6152bc66a33747f6c5fb4d6e115fb2c135f8e58f8d2fd05ebf892425365836b3236fa045b0e0e"
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
    } catch(e) {
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

  test('{signature, previous} do not affect token', () async {
    Jsonish.wipeCache();

    Jsonish unsigned = Jsonish(bartTrustsHomerUnsigned);

    // // Keep commented out normally. Comment in to sign for subsequent testing
    // OouKeyPair keyPair = await CryptoFactoryEd25519().createKeyPair();
    // OouSigner signer = await OouSigner.make(keyPair);
    // Json copyToSign = Map.from(bartTrustsHomerUnsigned);
    // copyToSign['I'] = await (await keyPair.publicKey).json;
    // Jsonish signedX = await Jsonish.makeSign(copyToSign, signer);
    // print(signedX.ppJson);
    // return;

    String token1 = unsigned.token;

    Jsonish.wipeCache();

    Map<String, dynamic> signed = Map.from(bartTrustsHomerSigned);
    Jsonish jsonishSigned = await Jsonish.makeVerify(signed, OouVerifier());
    String token2 = jsonishSigned.token;

    expect(token1 == token2, false);
  });

  test('CANCELLED: Jsonish demands verifying signature', () async {
    // Jsonish.wipeCache();

    // try {
    //   Map<String, dynamic> signedBogus = Map.from(bartTrustsHomerUnsigned);
    //   signedBogus['signature'] = 'bogus';
    //   Jsonish jsonishSignedBogus = Jsonish(signedBogus);
    // } catch (e) {
    //   print(e);
    //   return;
    // }
    // fail('expected exception');
  });
}
