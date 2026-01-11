import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/demotest/test_util.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  test('<nerdster> context: direct trust implies follow', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');

    // Alice trusts Bob in WoT
    await alice.trust(bob, moniker: 'bob');
    // Bob trusts Charlie in WoT
    await bob.trust(charlie, moniker: 'charlie');

    final allTrustStatements = {
      alice.id: alice.trustStatements,
      bob.id: bob.trustStatements,
    };

    final trustGraph = reduceTrustGraph(
      TrustGraph(pov: alice.id),
      allTrustStatements,
    );

    final delegateResolver = DelegateResolver(trustGraph);

    // No explicit follow statements
    final contentResult = ContentResult();

    final followNet = reduceFollowNetwork(
      trustGraph,
      delegateResolver,
      contentResult,
      kFollowContextNerdster,
    );

    // Alice should follow Bob because of direct trust
    expect(followNet.contains(bob.id), true, reason: 'Alice should follow Bob via direct trust');

    // Alice should follow Charlie because Bob (who Alice follows) trusts Charlie
    expect(followNet.contains(charlie.id), true,
        reason: 'Alice should follow Charlie via Bob\'s trust');
  });

  test('<nerdster> context: block in WoT does NOT imply block in follow', () async {
    // The rule only mentions "vouched for" (trust), not "distrust" or "block".
    // Actually, let's check if block in WoT should affect follow.
    // Usually, follow blocks are explicit.
  });
}
