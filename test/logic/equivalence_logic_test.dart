import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:oneofus_common/fire_factory.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/trust_logic.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/demotest/test_util.dart';

void main() async {
  setUp(() async {
    setUpTestRegistry();
  });

  test('V2 Equivalence: Transitive and DontEquate', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    final DemoDelegateKey aliceN = await alice.makeDelegate();
    final DemoDelegateKey bobN = await bob.makeDelegate();
    final DemoDelegateKey charlieN = await charlie.makeDelegate();

    // Bob trusts Alice (just to name her)
    await bob.trust(alice, moniker: 'alice');

    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: alice.id), {
      alice.id: alice.trustStatements.toList(),
      bob.id: bob.trustStatements.toList(),
      charlie.id: charlie.trustStatements.toList(),
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Subjects
    final Map<String, dynamic> sA = <String, dynamic>{
      'contentType': 'article',
      'title': 'A',
      'url': 'https://example.com/A'
    };
    final Map<String, dynamic> sB = <String, dynamic>{
      'contentType': 'article',
      'title': 'B',
      'url': 'https://example.com/B'
    };
    final Map<String, dynamic> sC = <String, dynamic>{
      'contentType': 'article',
      'title': 'C',
      'url': 'https://example.com/C'
    };

    final ContentKey sAKey = ContentKey(getToken(sA));
    final ContentKey sBKey = ContentKey(getToken(sB));
    final ContentKey sCKey = ContentKey(getToken(sC));

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
    final Map<DelegateKey, List<ContentStatement>> delegateContent =
        <DelegateKey, List<ContentStatement>>{};
    for (final DemoDelegateKey dk in [aliceN, bobN, charlieN]) {
      delegateContent[dk.id] = dk.contentStatements;
    }
    final ContentResult contentResult = ContentResult(delegateContent: delegateContent);

    // Use <nerdster> context
    final FollowNetwork netAlice =
        reduceFollowNetwork(graph, delegateResolver, contentResult, kFollowContextNerdster);

    // Verify Network Order
    final Labeler labeler = Labeler(graph);
    final List<IdentityKey> expected = <IdentityKey>[alice.id, charlie.id, bob.id];
    final List<IdentityKey> actual = netAlice.identities.toList();

    final List<String> expectedNames =
        expected.map((IdentityKey t) => labeler.getLabel(t.value)).toList();
    final List<String> actualNames =
        actual.map((IdentityKey t) => labeler.getLabel(t.value)).toList();

    expect(actualNames, equals(expectedNames),
        reason: 'Network order should be Alice, then Charlie, then Bob');

    final ContentAggregation aggAlice = reduceContentAggregation(
        netAlice, graph, delegateResolver, contentResult,
        labeler: labeler);

    final ContentKey? canonA = aggAlice.equivalence[sAKey];
    final ContentKey? canonB = aggAlice.equivalence[sBKey];
    final ContentKey? canonC = aggAlice.equivalence[sCKey];

    // Expectation: A == B, but B != C (because Charlie says dontEquate B-C and Charlie > Bob)
    expect(canonA, isNotNull);
    expect(canonA, equals(canonB));
    expect(canonB, isNot(equals(canonC)),
        reason: 'Charlie (more trusted) said DontEquate B-C, overriding Bob');
  });
}
