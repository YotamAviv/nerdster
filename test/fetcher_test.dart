import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/crypto/crypto2559.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:test/test.dart';

/// Actually test: What am I worried about?
/// - caching
/// - revoked at 
/// - distinct
/// - notarizations
/// 
/// Caching:
/// - Need non-async method for ChildrenProvider<T> = Iterable<T> Function(T node); (not async)
/// Other current related issues:
/// - I create a lot of DistinctFetchers per token; they should all be the same one.
/// - TrustBridge, Node, NerdBase, and NerdNode are tightly related the implementation does not leverage that.
/// 
/// Thinking...
/// I should set revokeAt on the Fetcher, and at that time, it should:
/// - remove from the cache statements newer than that.
/// 
/// Do I ever really want to fetch again (as in refresh)?
/// Probably not, too complicated.
/// The Ajax push updates my own. The user can refresh, and it will be a legit refresh.

const OouCryptoFactory _crypto = CryptoFactoryEd25519();
const String _domain = kOneofusDomain;
const String _type = kOneofusType;
final FirebaseFirestore _fire = FireFactory.domain2fire[_domain]!;

const Json kI = {'trust': 'me'};

class TestSigner implements StatementSigner {
  @override
  Future<String> sign(Json json, String string) async {
    Json i = json['I'];
    return 'signed by $i';
  }
}

void main() async {
  FireFactory.registerFire(kOneofusDomain, FakeFirebaseFirestore());
  FireFactory.registerFire(kNerdsterDomain, FakeFirebaseFirestore());
  TestClock testClock = TestClock();

  setUp(() async {
    testClock = TestClock();
    useClock(testClock);
    for (final fire in FireFactory.domain2fire.values) {
      await fire.clearPersistence();
    }
    Fetcher.clear();
    clearDistinct();
  });

  test('FakeFirebaseFirestore', () async {
    const JsonEncoder flatEncoder = JsonEncoder();
    Fetcher fetcher;
    
    OouKeyPair bartKeyPair = await _crypto.createKeyPair();
    OouPublicKey bartPublicKey = await bartKeyPair.publicKey;
    Json bartPublicKeyJson = await bartPublicKey.json;
    String bartPublicKeyFlat = flatEncoder.convert(bartPublicKeyJson);
    String bartToken = Jsonish(bartPublicKeyJson).token;
    StatementSigner signer = await OouSigner.make(bartKeyPair);

    RegExp bartTokenRegExp = RegExp(bartPublicKeyFlat);

    DateTime now = DateTime.now();
    Json map = {
      'statement': _type,
      'time': formatIso(now),
      'I': await bartPublicKey.json,
      'subject': 'Bart!',
    };
    /// Jsonish j = await Jsonish.makeSign(map, signer);

    fetcher = Fetcher(bartToken, _domain);

    Jsonish pushed = await fetcher.push(map, signer);
    Json map2 = Map.of(pushed.json)..remove('signature')..remove('previous');
    expect(map2, map);

    List<Jsonish> js;

    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 1);
    expect(js[0], pushed);

    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 1);
    expect(js[0], pushed);

    // Clear our cache, let FakeFirebaseFirestore persist. 
    Fetcher.clear();

    fetcher = Fetcher(bartToken, _domain);

    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 1);
    expect(js[0], pushed);

    // Clear our cache, and FakeFirebaseFirestore's persistence. 
    Fetcher.clear();
    await _fire.clearPersistence();
    
    fetcher = Fetcher(bartToken, _domain);

    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 0);
  });

  test('2 FakeFirebaseFirestores', () async {
    final FakeFirebaseFirestore f1 = FakeFirebaseFirestore();
    final FakeFirebaseFirestore f2 = FakeFirebaseFirestore();

    await f1.collection('c').doc('f').set({'f': 'f1'});
    await f2.collection('c').doc('f').set({'f': 'f2'});

    QuerySnapshot<Json> snapshots1 = await f1.collection('c').orderBy('time', descending: true).get();
    for (final docSnapshot in snapshots1.docs) {
      final Json data = docSnapshot.data();
      expect(data, {'f': 'f1'});
    }

    QuerySnapshot<Json> snapshots2 = await f2.collection('c').orderBy('time', descending: true).get();
    for (final docSnapshot in snapshots2.docs) {
      final Json data = docSnapshot.data();
      expect(data, {'f': 'f2'});
    }
  });

  test('2', () async {
    Fetcher fetcher = Fetcher(getToken(kI), _domain);

    List<Jsonish> js;
    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 0);

    js = fetcher.cachedNotDistinct;
    expect(js.length, 0);
  });

  test('base', () async {
    Fetcher fetcher = Fetcher(getToken(kI), _domain, testingNoVerify: true);
    Json map = {
      'statement': _type, 
      'time': clock.nowIso,
      'I': kI,
      'subject': 'stuff',
    };
    Jsonish statement = await fetcher.push(map, TestSigner());
    expect(statement.json.containsKey('signature'), true);
    expect(statement.json.containsKey('previous'), false);

    List<Jsonish> js;
    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 1);

    js = fetcher.cachedNotDistinct;
    expect(js.length, 1);
  });

  test('revokeAt', () async {
    TestSigner signer = TestSigner();
    Fetcher fetcher;

    List<Jsonish> js;    
    fetcher = Fetcher(getToken(kI), _domain, testingNoVerify: true);

    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff1', 'time': clock.nowIso}, signer);
    Jsonish statment2 = await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff2', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff3', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff4', 'time': clock.nowIso}, signer);

    fetcher = Fetcher(getToken(kI), _domain, testingNoVerify: true);

    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 4);
    js = fetcher.cachedNotDistinct;
    expect(js.length, 4);

    fetcher.setRevokeAt(statment2.token);
    
    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 2);
    js = fetcher.cachedNotDistinct;
    expect(js.length, 2);
  });

  test('revokeAt with clear()', () async {
    TestSigner signer = TestSigner();
    Fetcher fetcher;
    
    List<Jsonish> js;    
    fetcher = Fetcher(getToken(kI), _domain, testingNoVerify: true);

    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff1', 'time': clock.nowIso}, signer);
    Jsonish statment2 = await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff2', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff3', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff4', 'time': clock.nowIso}, signer);

    Fetcher.clear();
    fetcher = Fetcher(getToken(kI), _domain, testingNoVerify: true);

    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 4);
    js = fetcher.cachedNotDistinct;
    expect(js.length, 4);

    fetcher.setRevokeAt(statment2.token);
    
    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 2);
    js = fetcher.cachedNotDistinct;
    expect(js.length, 2);
  });

  test('notarization / blockchain violation', () async {
    TestSigner signer = TestSigner();
    Fetcher fetcher;
    
    List<Jsonish> js;    
    fetcher = Fetcher(getToken(kI), _domain, testingNoVerify: true);

    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff1', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff2', 'time': clock.nowIso}, signer);
    DateTime t1 = testClock.nowClean;
    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff3', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': _type, 'I': kI, 'subject': 'stuff4', 'time': clock.nowIso}, signer);

    Fetcher.clear();

    Json fraudulent = {'statement': _type, 'I': kI, 'subject': 'bad-stuff', 'time': formatIso(t1)};
    Jsonish fraudJ = await Jsonish.makeSign(fraudulent, signer);
    final fireStatements =
            _fire.collection(getToken(kI)).doc(_domain).collection('statements');
    // NOTE: We don't 'await'.. Ajax!.. Bad idea now that others call this, like tests.
    // DEFER: In case this seems slow, try Ajax after all.
    await fireStatements.doc(fraudJ.token).set(fraudulent)
        .then((doc) {}, onError: (e) => print("Error: $e"));
        // CONSIDER: Handle in case asynch DB write succeeds or fails.
    
    fetcher = Fetcher(getToken(kI), _domain, testingNoVerify: true);

    await fetcher.fetch();
    js = fetcher.cachedNotDistinct;
    expect(js.length, 4);
    js = fetcher.cachedNotDistinct;
    expect(js.length, 4);
  });


  test('distinct content comment', () async {
    ContentStatement.init();
    TestSigner signer = TestSigner();
    Fetcher fetcher;

    Iterable<Statement> js;
    fetcher = Fetcher(getToken(kI), kNerdsterDomain, testingNoVerify: true);

    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'rate': {'title': 't1'}, 'comment': '1', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'rate': {'title': 't2'}, 'comment': '2','time': clock.nowIso}, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 2);

    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'rate': {'title': 't3'}, 'comment': '3', 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'rate': {'title': 't3'}, 'comment': '4','time': clock.nowIso}, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 3);
  });

test('distinct content relate/equate', () async {
    ContentStatement.init();
    TestSigner signer = TestSigner();
    Fetcher fetcher;

    Iterable<Statement> js;
    fetcher = Fetcher(getToken(kI), kNerdsterDomain, testingNoVerify: true);
    
    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'relate': {'title': 'a'}, 'with': {'otherSubject': {'title': 'x'}}, 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'relate': {'title': 'b'}, 'with': {'otherSubject': {'title': 'x'}}, 'time': clock.nowIso}, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 2);

    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'relate': {'title': 'c'}, 'with': {'otherSubject': {'title': 'x'}}, 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'relate': {'title': 'c'}, 'with': {'otherSubject': {'title': 'x'}}, 'time': clock.nowIso}, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 3);

    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'relate': {'title': '1'}, 'with': {'otherSubject': {'title': '2'}}, 'time': clock.nowIso}, signer);
    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'relate': {'title': '2'}, 'with': {'otherSubject': {'title': '1'}}, 'time': clock.nowIso}, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 4);
  });

test('clear', () async {
    ContentStatement.init();
    TestSigner signer = TestSigner();
    Fetcher fetcher;

    Iterable<Statement> js;
    fetcher = Fetcher(getToken(kI), kNerdsterDomain, testingNoVerify: true);
    
    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'relate': {'title': 'a'}, 'with': {'otherSubject': {'title': 'x'}}, 'time': clock.nowIso}, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 1);

    await fetcher.push({'statement': kNerdsterType, 'I': kI, 'clear': {'title': 'a'}, 'with': {'otherSubject': {'title': 'x'}}, 'time': clock.nowIso}, signer);
    js = distinct(fetcher.statements);
    expect(js.length, 0);
  });
}
