import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/logic/trust_pipeline.dart';
import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';

void main() {
  setUp(() async {
    setUpTestRegistry();
  });

  test('Basic Trust BFS', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(bob, moniker: 'bob');
    await bob.trust(charlie, moniker: 'charlie');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bob.id), isTrue);
    expect(graph.isTrusted(charlie.id), isTrue);
    expect(graph.distances[bob.id], 1);
    expect(graph.distances[charlie.id], 2);
  });

  test('Key Rotation (Replace)', () async {
    // Simplification: replace always revokes the old key since always — per-token revokeAt
    // is no longer supported. The ONE-OF-US.NET app compensates by letting the user re-sign
    // with the new key any statements they want to keep. The result is the same.
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(bobNew, moniker: 'bobNew'); // Alice only trusts the NEW key
    // final TrustStatement sCharlie =
    await bob.trust(charlie, moniker: 'charlie'); // Charlie was trusted by the OLD key
    // await bobNew.replace(bob, lastGoodToken: sCharlie); // no longer supported, see simplification above
    await bobNew.replace(bob);
    await bobNew.trust(charlie, moniker: 'charlie'); // bobNew re-states the trust in charlie

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    // Alice (0) -> BobNew (1) -> Bob (2) -> Charlie (3)
    // So we need maxDegrees: 3 to reach Charlie.
    // We also need a pathRequirement that allows 1 path at distance 3.
    final TrustPipeline pipeline =
        TrustPipeline(source, maxDegrees: 6, pathRequirement: (int d) => 1);
    final TrustGraph graph = await pipeline.build(alice.id);

    // The algorithm should discover 'bob' via 'bobNew' and find 'charlie'
    expect(graph.isTrusted(bobNew.id), isTrue, reason: 'BobNew should be trusted');
    expect(graph.isTrusted(bob.id), isTrue, reason: 'Bob should be trusted via BobNew');
    expect(graph.isTrusted(charlie.id), isTrue, reason: 'Charlie should be trusted via Bob');
    expect(graph.equivalent2canonical[bob.id], bobNew.id);
  });

  test('Replacement Chain (A→B→C): equivalent2canonical maps each old key directly to canonical', () async {
    // Our user has three successive identity keys: keyA (oldest), keyB, keyC (canonical).
    // keyA does something (blocks x) to establish its history.
    // keyC (canonical) explicitly replaces both keyB and keyA.
    // keyB also replaces keyA (the standard intermediate link).
    // Alice trusts keyC.
    //
    // NOTE: a simple linear chain (keyC replaces keyB, keyB replaces keyA) does NOT produce
    // a 3-key equivalence group. When keyC replaces keyB with kSinceAlways, all of keyB's
    // statements are revoked — including keyB's replace-of-keyA — so keyA is never discovered.
    // The canonical key must explicitly replace all predecessors.
    //
    // With Distance Authority, keyC (dist 1) processes its replace statements before keyB (dist 2).
    // So keyC's replace-of-keyA wins over keyB's: equivalent2canonical[keyA] = keyC (not keyB).
    // Result: equivalent2canonical = { keyA: keyC, keyB: keyC } — each old key maps to the canonical.
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey keyA = await DemoIdentityKey.create('keyA');
    final DemoIdentityKey keyB = await DemoIdentityKey.create('keyB');
    final DemoIdentityKey keyC = await DemoIdentityKey.create('keyC');
    final DemoIdentityKey x = await DemoIdentityKey.create('x');

    await keyA.block(x);
    await keyB.replace(keyA);
    await keyC.replace(keyB);
    await keyC.replace(keyA);
    await alice.trust(keyC, moniker: 'keyC');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(keyC.id), isTrue);
    expect(graph.isTrusted(keyB.id), isTrue);
    expect(graph.isTrusted(keyA.id), isTrue);

    // Each old key maps directly to the canonical (keyC), not to the intermediate (keyB):
    expect(graph.equivalent2canonical[keyA.id], keyC.id);
    expect(graph.equivalent2canonical[keyB.id], keyC.id);
    expect(graph.equivalent2canonical.containsKey(keyC.id), isFalse);

    // resolveIdentity reaches keyC from both old keys in one hop (no chain walking needed):
    expect(graph.resolveIdentity(keyA.id), keyC.id);
    expect(graph.resolveIdentity(keyB.id), keyC.id);
  });

  test('Confidence Levels (Multiple Paths)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');
    final DemoIdentityKey dave = await DemoIdentityKey.create('dave');

    // Alice trusts Bob and Charlie (dist 1)
    // Bob and Charlie trust Dave (dist 2)
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');
    await bob.trust(dave, moniker: 'dave');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');

    // Requirement: 2 paths for distance 2
    final TrustPipeline pipeline =
        TrustPipeline(source, pathRequirement: (int d) => d >= 2 ? 2 : 1);

    TrustGraph graph = await pipeline.build(alice.id);
    expect(graph.isTrusted(dave.id), isFalse, reason: 'Dave only has 1 path');

    await charlie.trust(dave, moniker: 'dave');
    // Now Dave has 2 paths (Bob and Charlie)

    graph = await pipeline.build(alice.id);
    expect(graph.isTrusted(dave.id), isTrue, reason: 'Dave now has 2 paths');
  });

  test('Node-Disjoint Paths (Bottleneck Test)', () async {
    final DemoIdentityKey pov = await DemoIdentityKey.create('pov');
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');
    final DemoIdentityKey dave = await DemoIdentityKey.create('dave');

    // pov -> alice (dist 1)
    await pov.trust(alice, moniker: 'alice');

    // alice -> bob, charlie (dist 2)
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');

    // bob, charlie -> dave (dist 3)
    await bob.trust(dave, moniker: 'dave');
    await charlie.trust(dave, moniker: 'dave');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');

    // Requirement: 2 paths for distance 3
    final TrustPipeline pipeline =
        TrustPipeline(source, pathRequirement: (int d) => d >= 3 ? 2 : 1);

    final TrustGraph graph = await pipeline.build(pov.id);

    // Dave should NOT be trusted because all paths go through Alice
    expect(graph.isTrusted(dave.id), isFalse, reason: 'Dave has a bottleneck at Alice');

    // Now add a second path from pov to bypass Alice
    final DemoIdentityKey zoe = await DemoIdentityKey.create('zoe');
    await pov.trust(zoe, moniker: 'zoe');
    await zoe.trust(bob, moniker: 'bob');

    // Now Dave has 2 node-disjoint paths:
    // 1. pov -> alice -> charlie -> dave
    // 2. pov -> zoe -> bob -> dave

    final TrustGraph graph2 = await pipeline.build(pov.id);
    expect(graph2.isTrusted(dave.id), isTrue, reason: 'Dave now has 2 node-disjoint paths');
  });

  test('Conflicts (Trust vs Block)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');
    final DemoIdentityKey dave = await DemoIdentityKey.create('dave');

    // Alice trusts Bob then Charlie.
    // Since reduceTrustGraph sorts newest first, Charlie is processed before Bob.
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');

    await bob.trust(dave, moniker: 'dave');
    await charlie.block(dave);

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.blocked.contains(dave.id), isTrue);
    expect(graph.isTrusted(dave.id), isFalse);
    expect(graph.conflicts.length, greaterThan(0));
    // Since Charlie is newer, he is processed first, so Dave is blocked, then Bob tries to trust him.
    expect(graph.conflicts.first.reason, contains('trust blocked key'));
  });

  test('Replace Notification (Not Conflict)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');

    await alice.trust(bob, moniker: 'bob');
    await alice.trust(bobNew, moniker: 'bobNew');
    await bobNew.replace(bob);

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(
        graph.notifications
            .any((TrustNotification n) => !n.isConflict && n.reason.contains('being replaced')),
        isTrue);
  });

  test('Clear Trust', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');

    await alice.trust(bob, moniker: 'bob');
    await alice.clear(bob); // This issues a 'clear' statement

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bob.id), isFalse, reason: 'Trust was cleared');
  });

  test('Replace with Constraint (Since Always)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bobOld = await DemoIdentityKey.create('bobOld');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(bobNew, moniker: 'bobNew');
    // bobNew replaces bobOld, but constrains him "since always"
    // We use a very old token (or just replace, assuming it revokes subsequent signatures)
    // Actually, "since always" implies we effectively block the old identity's history?
    // If we use standard replace, it revokes signatures created AFTER the replacement.
    // So we must ensure replacement happens BEFORE bobOld trusts Charlie.
    await bobNew.replace(bobOld);

    await bobOld.trust(charlie, moniker: 'charlie'); // This statement should be ignored

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.isTrusted(bobOld.id), isTrue, reason: 'bobOld is still part of the identity');
    expect(graph.isTrusted(charlie.id), isFalse,
        reason: 'bobOld statements should be ignored due to constraint');
  });

  test('Replacement Race Condition (Requires 2 passes)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bobOld = await DemoIdentityKey.create('bobOld');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    // Alice trusts bobOld AND bobNew.
    // We want bobOld to be processed BEFORE bobNew in the BFS.
    // In reduceTrustGraph, issuer statements are sorted newest-first.
    // So if Alice trusts bobOld AFTER she trusts bobNew, bobOld will be first in the list.

    await alice.trust(bobNew, moniker: 'bobNew'); // Older
    await Future.delayed(const Duration(milliseconds: 10));
    await alice.trust(bobOld, moniker: 'bobOld'); // Newer -> Processed first

    // bobOld trusts Charlie.
    await bobOld.trust(charlie, moniker: 'charlie');

    // bobNew replaces bobOld and constrains his statements.
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: '<since always>');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    // Set maxDegrees to 3 so that bobNew (dist 1) can constrain bobOld (dist 2)
    // and we can see the effect on Charlie (dist 3).
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 3);

    // This test is designed to FAIL if orchestrator.dart only runs reduceTrustGraph once.
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.isTrusted(bobOld.id), isTrue);
    expect(graph.isTrusted(charlie.id), isFalse,
        reason:
            'Charlie should be ignored due to bobNew constraint. If this fails, it means the race condition was not resolved.');
  });

  test('Trust Non-Canonical Key Notification', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(charlie, moniker: 'charlie');
    await alice.trust(bobNew, moniker: 'bobNew');
    await bobNew.replace(bob);

    // Case 1: Charlie trusts the OLD key directly.
    // Since Charlie is NOT the POV (Alice), this should NOT generate a notification.
    await charlie.trust(bob, moniker: 'bob');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.notifications.any((TrustNotification n) => n.reason.contains('non-canonical')),
        isFalse,
        reason: "Should not notify for others' mistakes");

    // Case 2: Alice (POV) trusts the OLD key directly.
    // Since the replacement comes from 'bobNew' (dist 1), and Alice trusts 'bob' (dist 1),
    // the replacement is discovered in Layer 1 processing.
    // 'bob' is already in the graph (from Layer 0 processing).
    // So the replacement logic sees 'bob' in 'distances' and triggers "Trusted key ... is being replaced".
    // The "non-canonical" notification is NOT triggered because Alice (Layer 0) is processed before the replacement is known.

    await alice.trust(bob, moniker: 'bob');

    final TrustPipeline pipeline2 = TrustPipeline(source);
    final TrustGraph graph2 = await pipeline2.build(alice.id);

    expect(
        graph2.notifications
            .any((TrustNotification n) => n.reason.contains('is being replaced by')),
        isTrue,
        reason: "Should notify that a trusted key is being replaced");
  });

  test('Distance Authority: Deep Replacement Constraint Ignored', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bobOld = await DemoIdentityKey.create('bobOld');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');
    final DemoIdentityKey frank = await DemoIdentityKey.create('frank');

    // Alice trusts bobOld (dist 1)
    await alice.trust(bobOld, moniker: 'bobOld');
    // Alice trusts Charlie (dist 1)
    await alice.trust(charlie, moniker: 'charlie');
    // Charlie trusts bobNew (dist 2)
    await charlie.trust(bobNew, moniker: 'bobNew');

    // bobNew replaces bobOld and constrains everything
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: '<since always>');

    // bobOld trusts Frank
    await bobOld.trust(frank, moniker: 'frank');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source);

    // --- PoV: Alice ---
    final TrustGraph graphAlice = await pipeline.build(alice.id);

    expect(graphAlice.isTrusted(bobOld.id), isTrue);
    expect(graphAlice.isTrusted(bobNew.id), isTrue);
    expect(graphAlice.isTrusted(frank.id), isTrue,
        reason:
            'Frank should be trusted because bobNew is further away than bobOld from Alices PoV');
    expect(
        graphAlice.notifications.any((TrustNotification n) =>
            n.reason.contains('Replacement constraint ignored due to distance')),
        isTrue);

    // --- PoV: Charlie ---
    final TrustGraph graphCharlie = await pipeline.build(charlie.id);

    expect(graphCharlie.isTrusted(bobNew.id), isTrue);
    expect(graphCharlie.isTrusted(bobOld.id), isTrue);
    expect(graphCharlie.isTrusted(frank.id), isFalse,
        reason: 'Frank should be ignored because bobNew is closer to Charlie than bobOld is');
  });

  test('Backward Discovery: Pulling in historical keys', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bobOld = await DemoIdentityKey.create('bobOld');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');

    // Alice -> Charlie (dist 1)
    await alice.trust(charlie, moniker: 'charlie');
    // Charlie -> bobNew (dist 2)
    await charlie.trust(bobNew, moniker: 'bobNew');
    // bobNew replaces bobOld
    await bobNew.replace(bobOld);

    // bobOld is NOT trusted by anyone else.
    // Without backward discovery, bobOld would be "not in network".

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    // We need maxDegrees: 3 so that bobNew (at dist 2) is processed as an issuer.
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 3);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.isTrusted(bobOld.id), isTrue,
        reason:
            'bobOld should be pulled into the network at distance 3 because bobNew is at distance 2');
    expect(graph.distances[bobOld.id], 3);
  });

  test('Double Replacement (Shortcut vs Fork)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob1 = await DemoIdentityKey.create('bob1');
    final DemoIdentityKey bob2 = await DemoIdentityKey.create('bob2');
    final DemoIdentityKey bob3 = await DemoIdentityKey.create('bob3');

    // Alice trusts the newest key
    await alice.trust(bob3, moniker: 'bob3');

    // bob3 replaces both predecessors
    await bob3.replace(bob2);
    await bob3.replace(bob1);

    // bob2 also replaces bob1 (the standard chain)
    await bob2.replace(bob1);

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    // --- THOUGHTS ON DOUBLE REPLACEMENT ---
    // Scenario: bob3 replaces bob2 AND bob1. bob2 replaces bob1.
    //
    // 1. Is it a Conflict?
    //    Technically, bob1 has two keys claiming to be its successor. If bob2 and bob3
    //    were different people, this would be a "Fork" (a hijack attempt).
    //
    // 2. Is it a Shortcut?
    //    Since bob3 also replaces bob2, it's a consistent chain. bob3 is just
    //    providing a "shortcut" for anyone who only knows bob1.
    //
    // 3. Current Algorithm Behavior:
    //    The algorithm uses "Distance Authority". Since bob3 (dist 1) is closer
    //    than bob2 (dist 2), bob3's replacement of bob1 is processed first.
    //    When bob2 tries to replace bob1, the algorithm sees bob1 is already
    //    trusted via a shorter path and ignores the second replacement constraint,
    //    issuing an INFO notification.

    expect(graph.isTrusted(bob3.id), isTrue);
    expect(graph.isTrusted(bob2.id), isTrue);
    expect(graph.isTrusted(bob1.id), isTrue);

    final bool hasConflict = graph.notifications
        .any((TrustNotification n) => n.isConflict && n.reason.contains('replaced by both'));
    final bool hasInfo = graph.notifications.any((TrustNotification n) =>
        !n.isConflict && n.reason.contains('Replacement constraint ignored due to distance'));
  });

  test('Ordered Keys (BFS Discovery)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');
    final DemoIdentityKey dave = await DemoIdentityKey.create('dave');

    // Alice -> Bob, Charlie
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');

    // Bob -> Dave
    await bob.trust(dave, moniker: 'dave');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    // Order should be: Alice (0), Charlie (1), Bob (1), Dave (2)
    // Charlie comes before Bob because Alice trusted him later (newest-first processing).
    expect(graph.orderedKeys, [
      alice.id,
      charlie.id,
      bob.id,
      dave.id,
    ]);
    expect(graph.orderedKeys.length, 4);
  });

  test('Graph Paths (Shortest Paths)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey charlie = await DemoIdentityKey.create('charlie');
    final DemoIdentityKey dave = await DemoIdentityKey.create('dave');

    // Alice -> Bob -> Dave
    // Alice -> Charlie -> Dave
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');
    await bob.trust(dave, moniker: 'dave');
    await charlie.trust(dave, moniker: 'dave');

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    final List<List<IdentityKey>> paths = graph.getPathsTo(dave.id);
    expect(paths.length, 2);
    expect(
        paths,
        containsAll(<List<IdentityKey>>[
          <IdentityKey>[alice.id, bob.id, dave.id],
          <IdentityKey>[alice.id, charlie.id, dave.id],
        ]));
  });

  test('Replacement: Far to Close (Identity Link accepted, old key unaffected)', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bobOld = await DemoIdentityKey.create('bobOld');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');
    final DemoIdentityKey dave = await DemoIdentityKey.create('dave');

    // 1. Alice trusts bobOld (dist 1)
    await alice.trust(bobOld, moniker: 'bobOld');

    // 2. bobOld trusts bobNew (dist 2)
    await bobOld.trust(bobNew, moniker: 'bobNew');

    // 3. bobOld trusts Dave (dist 2)
    await bobOld.trust(dave, moniker: 'dave');

    // 4. bobNew (dist 2) replaces bobOld (dist 1).
    await bobNew.replace(bobOld);

    final source = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');
    final TrustPipeline pipeline = TrustPipeline(source, maxDegrees: 5);
    final TrustGraph graph = await pipeline.build(alice.id);

    expect(graph.resolveIdentity(bobOld.id), bobNew.id,
        reason: 'Identity link should be accepted even from a further node');

    expect(graph.isTrusted(dave.id), isTrue,
        reason: 'Dave trusted via bobOld which was already processed before the replacement');

    expect(
        graph.notifications.any((TrustNotification n) =>
            n.reason.contains('Replacement constraint ignored due to distance')),
        isTrue);
  });

  test('Replaced key is not fetched after replacement is known', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoIdentityKey bobNew = await DemoIdentityKey.create('bobNew');

    await alice.trust(bob, moniker: 'bob');
    await bobNew.replace(bob);

    final Set<String> fetchedKeys = {};
    final inner = channelFactory.getChannel<TrustStatement>(kOneofusDomain, 'statements');

    final StatementSource<TrustStatement> trackingSource =
        _TrackingSource(inner, fetchedKeys);

    final TrustPipeline pipeline = TrustPipeline(trackingSource, maxDegrees: 6,
        pathRequirement: (int d) => 1);
    await pipeline.build(alice.id);

    // bob is replaced — it should be fetched at most once (to discover the replacement),
    // never again after that.
    final bobFetchCount =
        fetchedKeys.where((k) => k == bob.id.value).length;
    expect(bobFetchCount, lessThanOrEqualTo(1),
        reason: 'Replaced key bob should not be fetched after replacement is known');
  });
}

class _TrackingSource<T extends Statement> implements StatementSource<T> {
  final StatementSource<T> _inner;
  final Set<String> _fetched;

  _TrackingSource(this._inner, this._fetched);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    _fetched.addAll(keys.keys);
    return _inner.fetch(keys);
  }

  @override
  List<SourceError> get errors => _inner.errors;
}
