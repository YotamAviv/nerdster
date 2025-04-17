import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:test/test.dart';

/// Test against FirebaseEmulator and Cloud Functions..
/// (This section of doc is mostly useless.)
///
/// DEFER: The point of "unit testing" is to test things indepndantly, and so TEST: Fetcher
/// seperately from cloud functions.
/// - TEST: Fetcher on a cloud functions stub (maybe save cloud functions output).
/// - TEST: cloud functions specifically without Fetcher (use files, shouldn't be hard)
/// - TEST: cloud distinct.
///
/// Everything related to distinct...
/// - it's a mess already
/// - it used to be Fetcher job, then it wasn't, and now it's also done by cloud functions.
/// This might require moving distinct(..) into the non-clouddistinct code path thus changing the
///  semantics of Fetcher. But then what's the point? Do I want to maintain 2 code paths forever.
/// 2 code paths forever:
/// pros:
/// - FakeFirebaseFirestore
/// cons:
/// - 2 code paths forever
///
/// TEST: Error prone: There is a pref for using cloud distinct; running this from the DEV menu
/// uses that  settings says.

/// Actually test: What am I worried about?
/// - caching
/// - revokeAt
/// - distinct
/// - notarizations
///
/// Cloud Functions require integration tests
/// - revokeAt
/// - distinct (partial is enough)
/// - lastToken, maybe

const String _domain = kOneofusDomain;
const String _type = kOneofusType;
final FirebaseFirestore _fire = FireFactory.find(_domain);

class TestSigner implements StatementSigner {
  @override
  Future<String> sign(Json json, String string) async {
    Json i = json['I'];
    return 'signed-by-$i';
  }
}

Future<void> fetcherIntegrationTest() async {
  useClock(TestClock());
  FetcherTestHelper helper = FetcherTestHelper();

  test('2', helper.test2);

  test('base', helper.base);

  test('revokeAt', helper.revokeAt);
  test('revokeAtSinceAlways', helper.revokeAtSinceAlways);

  test('notarizationBlockchainViolation', helper.notarizationBlockchainViolation);

  test('distinctContentComment', helper.distinctContentComment);

  test('distinctContentRelateEquate', helper.distinctContentRelateEquate);

  test('clearNot', helper.clearNot);

  test('batch', helper.batch);
}

class FetcherTestHelper {
  int counter = DateTime.now().microsecondsSinceEpoch;
  TestClock testClock = TestClock();

  Future<Json> makeI() async {
    counter++;
    return {'x': 'n$counter'};
  }

  Future<void> test2() async {
    Json kI = await makeI();
    Fetcher fetcher = Fetcher(getToken(kI), _domain);

    List<Statement> js;
    await fetcher.fetch();
    js = fetcher.statements;
    expect(js.length, 0);

    js = fetcher.statements;
    expect(js.length, 0);
  }

  Future<void> base() async {
    Prefs.skipVerify.value = true;

    Json kI = await makeI();
    Fetcher fetcher = Fetcher(getToken(kI), _domain);
    Json map = {
      'statement': _type,
      'time': clock.nowIso,
      'I': kI,
      'block': 'sub',
    };
    Statement statement = await fetcher.push(map, TestSigner());
    expect(statement.containsKey('signature'), true);
    expect(statement.containsKey('previous'), false);

    List<Statement> js;
    await fetcher.fetch();
    js = fetcher.statements;
    expect(js.length, 1);

    js = fetcher.statements;
    expect(js.length, 1);
  }

  Future<void> revokeAt() async {
    Prefs.skipVerify.value = true;
    for (bool doClear in [true, false]) {
      Json kI = await makeI();

      TestSigner signer = TestSigner();
      Fetcher fetcher;

      List<Statement> js;
      fetcher = Fetcher(getToken(kI), _domain);

      await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub1', 'time': clock.nowIso}, signer);
      Statement revokeAtHere = await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub2', 'time': clock.nowIso}, signer);
      await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub3', 'time': clock.nowIso}, signer);
      await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub4', 'time': clock.nowIso}, signer);

      if (doClear) {
        Fetcher.clear();
        await fetcher.fetch();
      }

      js = fetcher.statements;
      expect(js.length, 4);
      expect(fetcher.statements.length, 4);

      fetcher.setRevokeAt(revokeAtHere.token);
      await fetcher.fetch();
      expect(fetcher.statements.length, 2);
      List subjects = List.of(fetcher.statements.map((s) => s.subject));
      // expect(subjects, ['sub4', 'sub3', 'sub2']);
      expect(subjects, ['sub2', 'sub1']);

      await fetcher.fetch();
      js = fetcher.statements;
      expect(js.length, 2);
    }
  }

  Future<void> revokeAtSinceAlways() async {
    Prefs.skipVerify.value = true;
    for (bool doClear in [true, false]) {
      Json kI = await makeI();

      TestSigner signer = TestSigner();
      Fetcher fetcher;

      List<Statement> js;
      fetcher = Fetcher(getToken(kI), _domain);

      await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub1', 'time': clock.nowIso}, signer);
      await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub2', 'time': clock.nowIso}, signer);
      await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub3', 'time': clock.nowIso}, signer);
      await fetcher
          .push({'statement': _type, 'I': kI, 'block': 'sub4', 'time': clock.nowIso}, signer);

      if (doClear) {
        Fetcher.clear();
        await fetcher.fetch();
      }

      js = fetcher.statements;
      expect(js.length, 4);
      expect(fetcher.statements.length, 4);

      fetcher.setRevokeAt('since always');
      await fetcher.fetch();
      expect(fetcher.statements.length, 0);

      await fetcher.fetch();
      js = fetcher.statements;
      expect(js.length, 0);
    }
  }

  Future<void> notarizationBlockchainViolation() async {
    Prefs.skipVerify.value = true;
    TestSigner signer = TestSigner();
    Fetcher fetcher;

    List<Statement> js;
    final Json kI = await makeI();
    final String token = getToken(kI);
    fetcher = Fetcher(token, _domain);

    await fetcher
        .push({'statement': _type, 'I': kI, 'trust': 'sub1', 'time': clock.nowIso}, signer);
    await fetcher
        .push({'statement': _type, 'I': kI, 'trust': 'sub2', 'time': clock.nowIso}, signer);
    clock.nowIso;
    DateTime t1 = testClock.nowClean;
    clock.nowIso;
    await fetcher
        .push({'statement': _type, 'I': kI, 'trust': 'sub3', 'time': clock.nowIso}, signer);
    await fetcher
        .push({'statement': _type, 'I': kI, 'trust': 'sub4', 'time': clock.nowIso}, signer);

    Fetcher.clear();

    Json fraudulent = {'statement': _type, 'I': kI, 'trust': 'bad-sub', 'time': formatIso(t1)};
    Jsonish fraudJ = await Jsonish.makeSign(fraudulent, signer);
    final fireStatements =
        _fire.collection(getToken(kI)).doc('statements').collection('statements');
    await fireStatements
        .doc(fraudJ.token)
        .set(fraudJ.json)
        .then((doc) {}, onError: (e) => print("Error: $e"));

    fetcher = Fetcher(token, _domain);
    // notary verification is different between local and cloud (right now).
    // Cloud functions throws error; local skips the statement.
    await fetcher.fetch();
    expect(notifications.corrupted.length, 1);
    expect(notifications.corrupted.entries.first.key, token);
    print('(500 (Internal Server Error) or "Notarization violation" above was expected)');
  }

  Future<void> distinctContentComment() async {
    ContentStatement.init();
    TestSigner signer = TestSigner();
    Fetcher fetcher;
    Json kI = await makeI();

    Iterable<Statement> js;
    fetcher = Fetcher(getToken(kI), kNerdsterDomain);

    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'rate': {'title': 't1'},
      'comment': '1',
      'time': clock.nowIso
    }, signer);
    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'rate': {'title': 't2'},
      'comment': '2',
      'time': clock.nowIso
    }, signer);
    js = distinct(fetcher.statements);
    expect(js.length, 2);

    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'rate': {'title': 't3'},
      'comment': '3',
      'time': clock.nowIso
    }, signer);
    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'rate': {'title': 't3'},
      'comment': '4',
      'time': clock.nowIso
    }, signer);

    js = distinct(fetcher.statements);
    expect(js.length, 3);
  }

  Future<void> distinctContentRelateEquate() async {
    ContentStatement.init();
    TestSigner signer = TestSigner();
    Fetcher fetcher;

    Iterable<Statement> js;
    Json kI = await makeI();

    fetcher = Fetcher(getToken(kI), kNerdsterDomain);

    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'relate': {'title': 'a'},
      'with': {
        'otherSubject': {'title': 'x'}
      },
      'time': clock.nowIso
    }, signer);
    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'relate': {'title': 'b'},
      'with': {
        'otherSubject': {'title': 'x'}
      },
      'time': clock.nowIso
    }, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 2);

    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'relate': {'title': 'c'},
      'with': {
        'otherSubject': {'title': 'x'}
      },
      'time': clock.nowIso
    }, signer);
    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'relate': {'title': 'c'},
      'with': {
        'otherSubject': {'title': 'x'}
      },
      'time': clock.nowIso
    }, signer);

    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 3);

    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'relate': {'title': '1'},
      'with': {
        'otherSubject': {'title': '2'}
      },
      'time': clock.nowIso
    }, signer);
    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'relate': {'title': '2'},
      'with': {
        'otherSubject': {'title': '1'}
      },
      'time': clock.nowIso
    }, signer);

    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 4);
  }

  // Fetcher and Distincter used to clear "clear" statements, but no longer
  Future<void> clearNot() async {
    ContentStatement.init();
    TestSigner signer = TestSigner();
    Fetcher fetcher;
    Json kI = await makeI();

    Iterable<Statement> js;
    fetcher = Fetcher(getToken(kI), kNerdsterDomain);

    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'relate': {'title': 'a'},
      'with': {
        'otherSubject': {'title': 'x'}
      },
      'time': clock.nowIso
    }, signer);
    await fetcher.fetch();
    js = distinct(fetcher.statements);
    expect(js.length, 1);

    await fetcher.push({
      'statement': kNerdsterType,
      'I': kI,
      'clear': {'title': 'a'},
      'with': {
        'otherSubject': {'title': 'x'}
      },
      'time': clock.nowIso
    }, signer);
    js = distinct(fetcher.statements);
    expect(js.length, 1);
  }

  Future<void> batch() async {
    Prefs.skipVerify.value = true;
    Prefs.batchFetch.value = true;

    // write data
    ContentStatement.init();
    TestSigner signer = TestSigner();

    Json kI1 = await makeI();
    String t1 = getToken(kI1);
    Json kI2 = await makeI();
    String t2 = getToken(kI2);

    for (bool b in [true, false]) {
      // should get same answers without batch fetch

      // this is to not see 'cache miss' in the debug console as pushing requires fetching first.
      if (b) await Fetcher.batchFetch({t1: null, t2: null}, kNerdsterDomain);

      Fetcher.clear();
      Fetcher fetcher1 = Fetcher(t1, kNerdsterDomain);
      Statement s1 = await fetcher1.push({
        'statement': kNerdsterType,
        'I': kI1,
        'rate': {'title': 'a'},
        'time': clock.nowIso
      }, signer);

      Fetcher fetcher2 = Fetcher(t2, kNerdsterDomain);
      Statement s2 = await fetcher2.push({
        'statement': kNerdsterType,
        'I': kI2,
        'rate': {'title': 'a'},
        'time': clock.nowIso
      }, signer);

      // read data
      Fetcher.clear();
      if (b) await Fetcher.batchFetch({t1: null, t2: null}, kNerdsterDomain);
      fetcher2 = Fetcher(t2, kNerdsterDomain);
      await fetcher2.fetch();
      expect(fetcher2.statements.length, 1);
      expect(fetcher2.statements[0].token, s2.token);

      // Repeat with revoke since always
      Fetcher.clear();
      if (b) await Fetcher.batchFetch({t1: null, t2: 'since always'}, kNerdsterDomain);
      fetcher2 = Fetcher(t2, kNerdsterDomain);
      fetcher2.setRevokeAt('since always');
      await fetcher2.fetch();
      expect(fetcher2.statements.length, 0);

      // Repeat with revoke at token
      Fetcher.clear();
      if (b) await Fetcher.batchFetch({t1: null, t2: s2.token}, kNerdsterDomain);
      fetcher2 = Fetcher(t2, kNerdsterDomain);
      fetcher2.setRevokeAt(s2.token);
      await fetcher2.fetch();
      expect(fetcher2.statements.length, 1);
      expect(fetcher2.statements[0].token, s2.token);

      // DEFER: actually verify that we're getting hits.
    }
  }
}
