import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/oneofus/jsonish.dart';

import 'package:flutter_test/flutter_test.dart';

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  setUp(() async {
    useClock(TestClock());
    DemoKey.reset();
  });

  test('V2 Equivalence: Transitive and DontEquate', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    final DemoDelegateKey aliceN = await alice.makeDelegate();
    final DemoDelegateKey bobN = await bob.makeDelegate();
    final DemoDelegateKey charlieN = await charlie.makeDelegate();

    // This works, too. See matching comment below.
    // Alice trusts Charlie and Bob
    // await alice.trust(bob, moniker: 'bob');
    // await alice.trust(charlie, moniker: 'charlie');

    // Bob trusts Alice (just ot name her)
    await bob.trust(alice, moniker: 'alice');

    final t2 = await alice.trust(bob, moniker: 'bob');
    final t1 = await alice.trust(charlie, moniker: 'charlie');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: IdentityKey(alice.token)), {
      // alice.token: alice.trustStatements.toList(),
      IdentityKey(alice.token): alice.trustStatements.toList(),
      IdentityKey(bob.token): bob.trustStatements.toList(),
      IdentityKey(charlie.token): charlie.trustStatements.toList(),
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Subjects
    final Json sA = {'contentType': 'article', 'title': 'A', 'url': 'https://example.com/A'};
    final Json sB = {'contentType': 'article', 'title': 'B', 'url': 'https://example.com/B'};
    final Json sC = {'contentType': 'article', 'title': 'C', 'url': 'https://example.com/C'};

    final String sAToken = getToken(sA);
    final String sBToken = getToken(sB);
    final String sCToken = getToken(sC);

    // Statements

    // Bob says B == C
    await bobN.doRelate(ContentVerb.equate, subject: sB, other: sC);

    // Charlie says A == B but B != C
    await charlieN.doRelate(ContentVerb.equate, subject: sA, other: sB);
    await charlieN.doRelate(ContentVerb.dontEquate, subject: sB, other: sC);

    // Define subjects by rating them (so their Map definition exists in the graph)
    await aliceN.doRate(subject: sA, recommend: true);
    await aliceN.doRate(subject: sB, recommend: true);
    await aliceN.doRate(subject: sC, recommend: true);
    // Note: It doesn't matter who rates them, as long as someone in the graph does.

    // Alice says A == B
    await aliceN.doRelate(ContentVerb.equate, subject: sA, other: sB);

    // Collect statements
    final Map<DelegateKey, List<ContentStatement>> delegateContent = {};
    for (final dk in [aliceN, bobN, charlieN]) {
      delegateContent[DelegateKey(dk.token)] = dk.contentStatements;
    }
    final contentResult = ContentResult(delegateContent: delegateContent);

    // Use <nerdster> context
    final FollowNetwork netAlice =
        reduceFollowNetwork(graph, delegateResolver, contentResult, kFollowContextNerdster);

    // Verify Network Order
    final V2Labeler labeler = V2Labeler(graph);
    final List<String> expected = [alice.token, charlie.token, bob.token];
    final List<String> actual = netAlice.identities.map((k) => k.value).toList();
    final List<String> expectedNames = expected.map((t) => labeler.getLabel(t)).toList();
    final List<String> actualNames = actual.map((t) => labeler.getLabel(t)).toList();

    expect(actualNames, equals(expectedNames),
        reason: 'Network order should be Alice, then Charlie, then Bob');

    final ContentAggregation aggAlice =
        reduceContentAggregation(netAlice, graph, delegateResolver, contentResult);

    final ContentKey? canonA = aggAlice.equivalence[ContentKey(sAToken)];
    final ContentKey? canonB = aggAlice.equivalence[ContentKey(sBToken)];
    final ContentKey? canonC = aggAlice.equivalence[ContentKey(sCToken)];

    // Expectation: A == B, but B != C (because Charlie says dontEquate B-C and Charlie > Bob)
    expect(canonA, isNotNull);
    expect(canonA, equals(canonB));
    expect(canonB, isNot(equals(canonC)),
        reason: 'Charlie (more trusted) said DontEquate B-C, overriding Bob');
  });
}
