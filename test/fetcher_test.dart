import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // You have to add this manually, for some reason it cannot be added automatically
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/fetcher_integration_test.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:flutter_test/flutter_test.dart';

const String _domain = kOneofusDomain;
const String _type = kOneofusType;
late final FirebaseFirestore _fire;

void main() async {
  FetcherTestHelper helper = FetcherTestHelper();
  fireChoice = FireChoice.fake;
  FireFactory.register(_domain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  _fire = FireFactory.find(_domain);
  TrustStatement.init();

  // To restore Prefs changes
  late Map<Setting, dynamic> prefsSnapshot;
  setUp(() {
    prefsSnapshot = Prefs.snapshot();
  });
  tearDown(() {
    Prefs.restore(prefsSnapshot);
  });

  test('2', helper.test2);

  test('base', helper.base);

  test('revokeAt', helper.revokeAt);
  test('revokeAtSinceAlways', helper.revokeAtSinceAlways);

  test('notarizationBlockchainViolation', helper.notarizationBlockchainViolation);

  test('distinctContentComment', helper.distinctContentComment);

  test('distinctContentRelateEquate', helper.distinctContentRelateEquate);

  test('clearNot', helper.clearNot);

  test('batch', helper.batch);

  // I must have written this as I was first using FakeFirebaseFirestore.
  // I uses the full blown fetcher signing push(..) to write to the db; it should have been
  // done in a more "unit testing" fashion.
  test('FakeFirebaseFirestore', () async {
    Fetcher fetcher;

    OouKeyPair bartKeyPair = await crypto.createKeyPair();
    OouPublicKey bartPublicKey = await bartKeyPair.publicKey;
    Json bartPublicKeyJson = await bartPublicKey.json;
    String bartToken = Jsonish(bartPublicKeyJson).token;
    StatementSigner signer = await OouSigner.make(bartKeyPair);

    DateTime now = DateTime.now();
    Json map = {
      'statement': _type,
      'time': formatIso(now),
      'I': await bartPublicKey.json,
      TrustVerb.trust.label: 'Bart!',
    };

    fetcher = Fetcher(bartToken, _domain);

    Statement pushedStatement = await fetcher.push(map, signer);
    Json pushedStatementJson = Map.of(pushedStatement.json)
      ..remove('signature')
      ..remove('previous');
    expect(pushedStatementJson, map);

    List<Statement> js;

    await fetcher.fetch();
    js = fetcher.statements;
    expect(js.length, 1);
    expect(js[0], pushedStatement);

    await fetcher.fetch();
    js = fetcher.statements;
    expect(js.length, 1);
    expect(js[0], pushedStatement);

    // Clear Fetcher cache; rely on FakeFirebaseFirestore for persistence.
    Fetcher.clear();

    fetcher = Fetcher(bartToken, _domain);

    await fetcher.fetch();
    js = fetcher.statements;
    expect(js.length, 1);
    expect(js[0], pushedStatement);

    // Clear our cache, and FakeFirebaseFirestore's persistence.
    Fetcher.clear();
    await _fire.clearPersistence();

    fetcher = Fetcher(bartToken, _domain);

    await fetcher.fetch();
    js = fetcher.statements;
    expect(js.length, 0);
  });

  test('2 FakeFirebaseFirestores', () async {
    final FakeFirebaseFirestore f1 = FakeFirebaseFirestore();
    final FakeFirebaseFirestore f2 = FakeFirebaseFirestore();

    await f1.collection('c').doc('f').set({'f': 'f1'});
    await f2.collection('c').doc('f').set({'f': 'f2'});

    QuerySnapshot<Json> snapshots1 =
        await f1.collection('c').orderBy('time', descending: true).get();
    for (final docSnapshot in snapshots1.docs) {
      final Json data = docSnapshot.data();
      expect(data, {'f': 'f1'});
    }

    QuerySnapshot<Json> snapshots2 =
        await f2.collection('c').orderBy('time', descending: true).get();
    for (final docSnapshot in snapshots2.docs) {
      final Json data = docSnapshot.data();
      expect(data, {'f': 'f2'});
    }
  });

  test('sublist', () {
    List l = [0, 1, 2, 3, 4, 5];
    expect(l.firstWhereOrNull((element) => element == 2), 2);
    List s = l.sublist(0, 2);
    expect(s.length, 2);
    expect(s, [0, 1]);
  });

  // This is to confirm that if Distincter caches Fetcher's list of statements, then a bug will
  // occur after Fetcher.push(..).
  test('list retains identity as key even after change (re: Distincter cache)', () {
    List l = [1];
    l.add(1);
    Map<List, String> map = <List, String>{};

    map[l] = 'x';
    l.add(2);

    expect(map[l], 'x');
  });

  test('consume iterator)', () {
    // I'm pretty sure that I've witnessed iteration of an Interable (not an interator) affect its contents.
    // I'm trying (but failing) to demostrate that phenomenom.
    List l = [];
    l.add(1);
    l.add(2);
    l.add(3);
    Iterable i = l.where((x) => x != 2);
    expect(i.length, 2);
    expect(i.length, 2);
  });
}
