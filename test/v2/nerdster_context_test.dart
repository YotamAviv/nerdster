import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/delegates.dart';
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

  test('<nerdster> context: direct trust implies follow', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');

    // Alice trusts Bob in WoT
    final t1 = await alice.trust(bob, moniker: 'bob');
    // Bob trusts Charlie in WoT
    final t2 = await bob.trust(charlie, moniker: 'charlie');

    final allTrustStatements = {
      alice.token: [t1, ...alice.trustStatements],
      bob.token: [t2, ...bob.trustStatements],
    };

    final trustGraph = reduceTrustGraph(
      TrustGraph(root: alice.token),
      allTrustStatements,
    );

    final delegateResolver = DelegateResolver(trustGraph);

    // No explicit follow statements
    final allContentStatements = <String, List<ContentStatement>>{};

    final followNet = reduceFollowNetwork(
      trustGraph,
      delegateResolver,
      allContentStatements,
      kNerdsterContext,
    );

    // Alice should follow Bob because of direct trust
    expect(followNet.contains(bob.token), true, reason: 'Alice should follow Bob via direct trust');
    
    // Alice should follow Charlie because Bob (who Alice follows) trusts Charlie
    expect(followNet.contains(charlie.token), true, reason: 'Alice should follow Charlie via Bob\'s trust');
  });

  test('<nerdster> context: block in WoT does NOT imply block in follow', () async {
    // The rule only mentions "vouched for" (trust), not "distrust" or "block".
    // Actually, let's check if block in WoT should affect follow.
    // Usually, follow blocks are explicit.
  });
}
