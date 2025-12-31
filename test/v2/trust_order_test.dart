import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/fire_choice.dart';
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

  test('Trust Order Verification', () async {
    final DemoKey alice = await DemoKey.create('alice');
    final DemoKey bob = await DemoKey.create('bob');
    final DemoKey charlie = await DemoKey.create('charlie');

    final DemoKey aliceN = await alice.makeDelegate();
    final DemoKey bobN = await bob.makeDelegate();
    final DemoKey charlieN = await charlie.makeDelegate();

    // User's snippet
    // await alice.trust(bob, moniker: 'bob'); 
    // await alice.trust(charlie, moniker: 'charlie');
    final TrustGraph graph = reduceTrustGraph(TrustGraph(root: alice.token), {
      alice.token: [
        await alice.trust(charlie, moniker: 'charlie'), 
        await alice.trust(bob, moniker: 'bob'), 
      ],
      // alice.token: alice.trustStatements,
      bob.token: [
        await bob.trust(charlie, moniker: 'charlie'),
        await bob.trust(alice, moniker: 'alice')
      ],
      charlie.token: [
        await charlie.trust(bob, moniker: 'bob'),
        await charlie.trust(alice, moniker: 'alice')
      ],
    });
    
    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Collect statements
    final Map<String, List<ContentStatement>> allStatements = {};
    for (final dk in [alice, aliceN, bob, bobN, charlie, charlieN]) {
      if (dk.isDelegate) allStatements[dk.token] = dk.contentStatements;
    }

    final FollowNetwork netAlice = reduceFollowNetwork(graph, delegateResolver, allStatements, kNerdsterContext);
    final V2Labeler labeler = V2Labeler(graph);
    
    final List<String> expected = [alice.token, charlie.token, bob.token];
    final List<String> actual = netAlice.identities;

    final List<String> expectedNames = expected.map((t) => labeler.getLabel(t)).toList();
    final List<String> actualNames = actual.map((t) => labeler.getLabel(t)).toList();

    expect(actualNames, equals(expectedNames), reason: 'Network order should be Alice, then Charlie, then Bob');
  });
}
