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
import 'package:nerdster/oneofus/keys.dart';
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
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    final DemoDelegateKey aliceN = await alice.makeDelegate();
    final DemoDelegateKey bobN = await bob.makeDelegate();
    final DemoDelegateKey charlieN = await charlie.makeDelegate();

    final t1 = await alice.trust(charlie, moniker: 'charlie');
    final t2 = await alice.trust(bob, moniker: 'bob');
    final t3 = await bob.trust(charlie, moniker: 'charlie');
    final t4 = await bob.trust(alice, moniker: 'alice');

    final t5 = await charlie.trust(bob, moniker: 'bob');
    final t6 = await charlie.trust(alice, moniker: 'alice');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: IdentityKey(alice.token)), {
      IdentityKey(alice.token): [t2, t1],
      IdentityKey(bob.token): [t4, t3],
      IdentityKey(charlie.token): [t6, t5],
    });
    
    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Collect statements
    final Map<DelegateKey, List<ContentStatement>> delegateContent = {};
    for (final dk in [alice, aliceN, bob, bobN, charlie, charlieN]) {
      if (dk is DemoDelegateKey) delegateContent[DelegateKey(dk.token)] = dk.contentStatements;
    }

    final FollowNetwork netAlice = reduceFollowNetwork(graph, delegateResolver, ContentResult(delegateContent: delegateContent), kFollowContextNerdster);
    final V2Labeler labeler = V2Labeler(graph);
    
    final List<String> expected = [alice.token, bob.token, charlie.token];
    final List<String> actual = netAlice.identities.map((k) => k.value).toList();

    final List<String> expectedNames = expected.map((t) => labeler.getLabel(t)).toList();
    final List<String> actualNames = actual.map((t) => labeler.getLabel(t)).toList();

    expect(actualNames, equals(expectedNames), reason: 'Network order should be Alice, then Bob, then Charlie');
  });
}
