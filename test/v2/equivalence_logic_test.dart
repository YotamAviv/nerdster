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
import 'package:nerdster/fire_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/oneofus/jsonish.dart';

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
    final DemoKey alice = await DemoKey.create('alice');
    final DemoKey bob = await DemoKey.create('bob');
    final DemoKey charlie = await DemoKey.create('charlie');

    final DemoKey aliceN = await alice.makeDelegate();
    final DemoKey bobN = await bob.makeDelegate();
    final DemoKey charlieN = await charlie.makeDelegate();

    // This works, too. See matching comment below.
    // Alice trusts Charlie and Bob
    // await alice.trust(bob, moniker: 'bob');
    // await alice.trust(charlie, moniker: 'charlie');

    // Bob trusts Alice (just ot name her)
    await bob.trust(alice, moniker: 'alice');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: alice.token), {
      // This works, too. See matching comment above.
      // alice.token: alice.trustStatements.toList(),
      alice.token: [
        await alice.trust(charlie, moniker: 'charlie'),
        await alice.trust(bob, moniker: 'bob'),
      ],
      bob.token: bob.trustStatements.toList(),
      charlie.token: charlie.trustStatements.toList(),
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Subjects
    final String sA = 'https://example.com/A';
    final String sB = 'https://example.com/B';
    final String sC = 'https://example.com/C';

    // Statements
    // Alice says A == B
    await aliceN.doRelate(ContentVerb.equate, subject: sA, other: sB);

    // Bob says B == C
    await bobN.doRelate(ContentVerb.equate, subject: sB, other: sC);

    // Charlie says A == B but B != C
    await charlieN.doRelate(ContentVerb.equate, subject: sA, other: sB);
    await charlieN.doRelate(ContentVerb.dontEquate, subject: sB, other: sC);

    // Collect statements
    final Map<String, List<ContentStatement>> contentStatements = {};
    for (final dk in [aliceN, bobN, charlieN]) {
      contentStatements[dk.token] = dk.contentStatements;
    }

    // Use <nerdster> context
    final FollowNetwork netAlice =
        reduceFollowNetwork(graph, delegateResolver, contentStatements, kNerdsterContext);

    // Verify Network Order
    final V2Labeler labeler = V2Labeler(graph);
    final List<String> expected = [alice.token, charlie.token, bob.token];
    final List<String> actual = netAlice.identities;
    final List<String> expectedNames = expected.map((t) => labeler.getLabel(t)).toList();
    final List<String> actualNames = actual.map((t) => labeler.getLabel(t)).toList();

    expect(actualNames, equals(expectedNames),
        reason: 'Network order should be Alice, then Charlie, then Bob');

    final ContentAggregation aggAlice =
        reduceContentAggregation(netAlice, graph, delegateResolver, contentStatements);

    final String? canonA = aggAlice.equivalence[sA];
    final String? canonB = aggAlice.equivalence[sB];
    final String? canonC = aggAlice.equivalence[sC];

    // Expectation: A == B, but B != C (because Charlie says dontEquate B-C and Charlie > Bob)
    expect(canonA, isNotNull);
    expect(canonA, equals(canonB));
    expect(canonB, isNot(equals(canonC)),
        reason: 'Charlie (more trusted) said DontEquate B-C, overriding Bob');
  });
}
