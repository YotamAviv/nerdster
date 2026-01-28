import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/trust_logic.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);
  });

  test('Trust Order Verification', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    final DemoDelegateKey aliceN = await alice.makeDelegate();
    final DemoDelegateKey bobN = await bob.makeDelegate();
    final DemoDelegateKey charlieN = await charlie.makeDelegate();

    final TrustStatement t1 = await alice.trust(charlie, moniker: 'charlie');
    final TrustStatement t2 = await alice.trust(bob, moniker: 'bob');
    final TrustStatement t3 = await bob.trust(charlie, moniker: 'charlie');
    final TrustStatement t4 = await bob.trust(alice, moniker: 'alice');

    final TrustStatement t5 = await charlie.trust(bob, moniker: 'bob');
    final TrustStatement t6 = await charlie.trust(alice, moniker: 'alice');

    final TrustGraph graph = reduceTrustGraph(TrustGraph(pov: alice.id), {
      alice.id: [t2, t1],
      bob.id: [t4, t3],
      charlie.id: [t6, t5],
    });

    final DelegateResolver delegateResolver = DelegateResolver(graph);

    // Collect statements
    final Map<DelegateKey, List<ContentStatement>> delegateContent = {};
    for (final DemoKey dk in [alice, aliceN, bob, bobN, charlie, charlieN]) {
      if (dk is DemoDelegateKey) delegateContent[dk.id] = dk.contentStatements;
    }

    final FollowNetwork netAlice = reduceFollowNetwork(graph, delegateResolver,
        ContentResult(delegateContent: delegateContent), kFollowContextNerdster);
    final V2Labeler labeler = V2Labeler(graph);

    final List<String> expected = [alice.token, bob.token, charlie.token];
    final List<String> actual = netAlice.identities.map((IdentityKey k) => k.value).toList();

    final List<String> expectedNames = expected.map((String t) => labeler.getLabel(t)).toList();
    final List<String> actualNames = actual.map((String t) => labeler.getLabel(t)).toList();

    expect(actualNames, equals(expectedNames),
        reason: 'Network order should be Alice, then Bob, then Charlie');
  });
}
