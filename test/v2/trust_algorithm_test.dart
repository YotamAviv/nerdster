import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/demotest/demo_key.dart';

import 'package:nerdster/app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoKey.reset();
  });

  test('Basic Trust BFS', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(bob, moniker: 'bob');
    await bob.trust(charlie, moniker: 'charlie');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bob.id), isTrue);
    expect(graph.isTrusted(charlie.id), isTrue);
    expect(graph.distances[bob.id], 1);
    expect(graph.distances[charlie.id], 2);
  });

  test('Key Rotation (Replace)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(bobNew, moniker: 'bobNew'); // Alice only trusts the NEW key
    final sCharlie = await bob.trust(charlie, moniker: 'charlie');  // Charlie was trusted by the OLD key
    await bobNew.replace(bob, lastGoodToken: sCharlie); // bobNew replaces bob, valid up to sCharlie

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    // Alice (0) -> BobNew (1) -> Bob (2) -> Charlie (3)
    // So we need maxDegrees: 3 to reach Charlie.
    // We also need a pathRequirement that allows 1 path at distance 3.
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(alice.id);

    // The algorithm should discover 'bob' via 'bobNew' and find 'charlie'
    expect(graph.isTrusted(bobNew.id), isTrue, reason: 'BobNew should be trusted');
    expect(graph.isTrusted(bob.id), isTrue, reason: 'Bob should be trusted via BobNew');
    expect(graph.isTrusted(charlie.id), isTrue, reason: 'Charlie should be trusted via Bob');
    expect(graph.replacements[bob.id], bobNew.id);
  });

  test('Confidence Levels (Multiple Paths)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');
    final dave = await DemoIdentityKey.create('dave');

    // Alice trusts Bob and Charlie (dist 1)
    // Bob and Charlie trust Dave (dist 2)
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');
    await bob.trust(dave, moniker: 'dave');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    
    // Requirement: 2 paths for distance 2
    final pipeline = TrustPipeline(source, pathRequirement: (d) => d >= 2 ? 2 : 1);
    
    var graph = await pipeline.build(alice.id);
    expect(graph.isTrusted(dave.id), isFalse, reason: 'Dave only has 1 path');

    await charlie.trust(dave, moniker: 'dave');
    // Now Dave has 2 paths (Bob and Charlie)
    
    graph = await pipeline.build(alice.id);
    expect(graph.isTrusted(dave.id), isTrue, reason: 'Dave now has 2 paths');
  });

  test('Node-Disjoint Paths (Bottleneck Test)', () async {
    final pov = await DemoIdentityKey.create('pov');
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');
    final dave = await DemoIdentityKey.create('dave');

    // pov -> alice (dist 1)
    await pov.trust(alice, moniker: 'alice');
    
    // alice -> bob, charlie (dist 2)
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');
    
    // bob, charlie -> dave (dist 3)
    await bob.trust(dave, moniker: 'dave');
    await charlie.trust(dave, moniker: 'dave');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    
    // Requirement: 2 paths for distance 3
    final pipeline = TrustPipeline(source, pathRequirement: (d) => d >= 3 ? 2 : 1);
    
    final graph = await pipeline.build(pov.id);
    
    // Dave should NOT be trusted because all paths go through Alice
    expect(graph.isTrusted(dave.id), isFalse, reason: 'Dave has a bottleneck at Alice');
    
    // Now add a second path from pov to bypass Alice
    final zoe = await DemoIdentityKey.create('zoe');
    await pov.trust(zoe, moniker: 'zoe');
    await zoe.trust(bob, moniker: 'bob');
    
    // Now Dave has 2 node-disjoint paths:
    // 1. pov -> alice -> charlie -> dave
    // 2. pov -> zoe -> bob -> dave
    
    final graph2 = await pipeline.build(pov.id);
    expect(graph2.isTrusted(dave.id), isTrue, reason: 'Dave now has 2 node-disjoint paths');
  });

  test('Conflicts (Trust vs Block)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');
    final dave = await DemoIdentityKey.create('dave');

    // Alice trusts Bob then Charlie. 
    // Since reduceTrustGraph sorts newest first, Charlie is processed before Bob.
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');
    
    await bob.trust(dave, moniker: 'dave');
    await charlie.block(dave);

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.id);

    expect(graph.blocked.contains(dave.id), isTrue);
    expect(graph.isTrusted(dave.id), isFalse);
    expect(graph.conflicts.length, greaterThan(0));
    // Since Charlie is newer, he is processed first, so Dave is blocked, then Bob tries to trust him.
    expect(graph.conflicts.first.reason, contains('trust blocked key'));
  });

  test('Replace Notification (Not Conflict)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final bobNew = await DemoIdentityKey.create('bobNew');

    await alice.trust(bob, moniker: 'bob');
    await alice.trust(bobNew, moniker: 'bobNew');
    await bobNew.replace(bob);

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.notifications.any((n) => !n.isConflict && n.reason.contains('being replaced')), isTrue);
  });

  test('Clear Trust', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');

    await alice.trust(bob, moniker: 'bob');
    await alice.clear(bob); // This issues a 'clear' statement

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bob.id), isFalse, reason: 'Trust was cleared');
  });

  test('Replace with Constraint (Since Always)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bobOld = await DemoIdentityKey.create('bobOld');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(bobNew, moniker: 'bobNew');
    // bobNew replaces bobOld, but constrains him "since always"
    // We use a very old token (or just replace, assuming it revokes subsequent signatures)
    // Actually, "since always" implies we effectively block the old identity's history? 
    // If we use standard replace, it revokes signatures created AFTER the replacement.
    // So we must ensure replacement happens BEFORE bobOld trusts Charlie.
    await bobNew.replace(bobOld); 
    
    await bobOld.trust(charlie, moniker: 'charlie'); // This statement should be ignored

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.isTrusted(bobOld.id), isTrue, reason: 'bobOld is still part of the identity');
    expect(graph.isTrusted(charlie.id), isFalse, reason: 'bobOld statements should be ignored due to constraint');
  });

  test('Replace with Garbage Constraint (Since Always)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bobOld = await DemoIdentityKey.create('bobOld');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(bobNew, moniker: 'bobNew');
    // bobNew replaces bobOld, but uses a garbage revokeAt token
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: 'garbage-token');
    await bobOld.trust(charlie, moniker: 'charlie'); // This statement should be ignored

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.isTrusted(charlie.id), isFalse, reason: 'bobOld statements should be ignored due to invalid constraint token');
  });

  test('Replacement Race Condition (Requires 2 passes)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bobOld = await DemoIdentityKey.create('bobOld');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final charlie = await DemoIdentityKey.create('charlie');

    // Alice trusts bobOld AND bobNew.
    // We want bobOld to be processed BEFORE bobNew in the BFS.
    // In reduceTrustGraph, issuer statements are sorted newest-first.
    // So if Alice trusts bobOld AFTER she trusts bobNew, bobOld will be first in the list.
    
    await alice.trust(bobNew, moniker: 'bobNew'); // Older
    await Future.delayed(Duration(milliseconds: 10));
    await alice.trust(bobOld, moniker: 'bobOld');    // Newer -> Processed first
    
    // bobOld trusts Charlie.
    await bobOld.trust(charlie, moniker: 'charlie');
    
    // bobNew replaces bobOld and constrains his statements.
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: '<since always>');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    // Set maxDegrees to 3 so that bobNew (dist 1) can constrain bobOld (dist 2) 
    // and we can see the effect on Charlie (dist 3).
    final pipeline = TrustPipeline(source, maxDegrees: 3);
    
    // This test is designed to FAIL if orchestrator.dart only runs reduceTrustGraph once.
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.isTrusted(bobOld.id), isTrue);
    expect(graph.isTrusted(charlie.id), isFalse, 
      reason: 'Charlie should be ignored due to bobNew constraint. If this fails, it means the race condition was not resolved.');
  });

  test('Trust Non-Canonical Key Notification', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final charlie = await DemoIdentityKey.create('charlie');

    await alice.trust(charlie, moniker: 'charlie');
    await alice.trust(bobNew, moniker: 'bobNew');
    await bobNew.replace(bob);
    
    // Case 1: Charlie trusts the OLD key directly.
    // Since Charlie is NOT the POV (Alice), this should NOT generate a notification.
    await charlie.trust(bob, moniker: 'bob'); 

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.notifications.any((n) => n.reason.contains('non-canonical')), isFalse, reason: "Should not notify for others' mistakes");

    // Case 2: Alice (POV) trusts the OLD key directly.
    // Since the replacement comes from 'bobNew' (dist 1), and Alice trusts 'bob' (dist 1),
    // the replacement is discovered in Layer 1 processing.
    // 'bob' is already in the graph (from Layer 0 processing).
    // So the replacement logic sees 'bob' in 'distances' and triggers "Trusted key ... is being replaced".
    // The "non-canonical" notification is NOT triggered because Alice (Layer 0) is processed before the replacement is known.
    
    await alice.trust(bob, moniker: 'bob');
    
    final pipeline2 = TrustPipeline(source);
    final graph2 = await pipeline2.build(alice.id);
    
    expect(graph2.notifications.any((n) => n.reason.contains('is being replaced by')), isTrue, 
      reason: "Should notify that a trusted key is being replaced");
  });

  test('Distance Authority: Deep Replacement Constraint Ignored', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bobOld = await DemoIdentityKey.create('bobOld');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final charlie = await DemoIdentityKey.create('charlie');
    final frank = await DemoIdentityKey.create('frank');

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

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source);
    
    // --- PoV: Alice ---
    final graphAlice = await pipeline.build(alice.id);
    
    expect(graphAlice.isTrusted(bobOld.id), isTrue);
    expect(graphAlice.isTrusted(bobNew.id), isTrue);
    expect(graphAlice.isTrusted(frank.id), isTrue, 
      reason: 'Frank should be trusted because bobNew is further away than bobOld from Alices PoV');
    expect(graphAlice.notifications.any((n) => n.reason.contains('Replacement constraint ignored due to distance')), isTrue);

    // --- PoV: Charlie ---
    final graphCharlie = await pipeline.build(charlie.id);
    
    expect(graphCharlie.isTrusted(bobNew.id), isTrue);
    expect(graphCharlie.isTrusted(bobOld.id), isTrue);
    expect(graphCharlie.isTrusted(frank.id), isFalse, 
      reason: 'Frank should be ignored because bobNew is closer to Charlie than bobOld is');
  });

  test('Backward Discovery: Pulling in historical keys', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bobOld = await DemoIdentityKey.create('bobOld');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final charlie = await DemoIdentityKey.create('charlie');

    // Alice -> Charlie (dist 1)
    await alice.trust(charlie, moniker: 'charlie');
    // Charlie -> bobNew (dist 2)
    await charlie.trust(bobNew, moniker: 'bobNew');
    // bobNew replaces bobOld
    await bobNew.replace(bobOld);
    
    // bobOld is NOT trusted by anyone else. 
    // Without backward discovery, bobOld would be "not in network".
    
    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    // We need maxDegrees: 3 so that bobNew (at dist 2) is processed as an issuer.
    final pipeline = TrustPipeline(source, maxDegrees: 3);
    final graph = await pipeline.build(alice.id);

    expect(graph.isTrusted(bobNew.id), isTrue);
    expect(graph.isTrusted(bobOld.id), isTrue, 
      reason: 'bobOld should be pulled into the network at distance 3 because bobNew is at distance 2');
    expect(graph.distances[bobOld.id], 3);
  });

  test('Double Replacement (Shortcut vs Fork)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bobV1 = await DemoIdentityKey.create('bobV1');
    final bobV2 = await DemoIdentityKey.create('bobV2');
    final bobV3 = await DemoIdentityKey.create('bobV3');

    // Alice trusts the newest key
    await alice.trust(bobV3, moniker: 'bobV3');

    // bobV3 replaces both predecessors
    await bobV3.replace(bobV2);
    await bobV3.replace(bobV1);

    // bobV2 also replaces bobV1 (the standard chain)
    await bobV2.replace(bobV1);

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);

    // --- THOUGHTS ON DOUBLE REPLACEMENT ---
    // Scenario: bobV3 replaces bobV2 AND bobV1. bobV2 replaces bobV1.
    //
    // 1. Is it a Conflict? 
    //    Technically, bobV1 has two keys claiming to be its successor. If bobV2 and bobV3 
    //    were different people, this would be a "Fork" (a hijack attempt).
    //
    // 2. Is it a Shortcut?
    //    Since bobV3 also replaces bobV2, it's a consistent chain. bobV3 is just 
    //    providing a "shortcut" for anyone who only knows bobV1.
    //
    // 3. Current Algorithm Behavior:
    //    The algorithm uses "Distance Authority". Since bobV3 (dist 1) is closer 
    //    than bobV2 (dist 2), bobV3's replacement of bobV1 is processed first.
    //    When bobV2 tries to replace bobV1, the algorithm sees bobV1 is already 
    //    trusted via a shorter path and ignores the second replacement constraint, 
    //    issuing an INFO notification.
    
    expect(graph.isTrusted(bobV3.id), isTrue);
    expect(graph.isTrusted(bobV2.id), isTrue);
    expect(graph.isTrusted(bobV1.id), isTrue);
    
    print('Notifications:');
    for (var n in graph.notifications) {
      print('  - ${n.reason} (Conflict: ${n.isConflict})');
    }

    final hasConflict = graph.notifications.any((n) => n.isConflict && n.reason.contains('replaced by both'));
    final hasInfo = graph.notifications.any((n) => !n.isConflict && n.reason.contains('Replacement constraint ignored due to distance'));
    
    print('Has Conflict: $hasConflict');
    print('Has Info: $hasInfo');
    print('bobV1 Replacement: ${graph.replacements[bobV1.id] == bobV3.id ? "bobV3" : "bobV2"}');
  });

  test('Ordered Keys (BFS Discovery)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');
    final dave = await DemoIdentityKey.create('dave');

    // Alice -> Bob, Charlie
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');

    // Bob -> Dave
    await bob.trust(dave, moniker: 'dave');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);

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
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');
    final dave = await DemoIdentityKey.create('dave');

    // Alice -> Bob -> Dave
    // Alice -> Charlie -> Dave
    await alice.trust(bob, moniker: 'bob');
    await alice.trust(charlie, moniker: 'charlie');
    await bob.trust(dave, moniker: 'dave');
    await charlie.trust(dave, moniker: 'dave');

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);

    final paths = graph.getPathsTo(dave.id);
    expect(paths.length, 2);
    expect(paths, containsAll([
      [alice.id, bob.id, dave.id],
      [alice.id, charlie.id, dave.id],
    ]));
  });

  test('Replacement: Far to Close (Identity Link vs Replacement Constraint)', () async {
    final alice = await DemoIdentityKey.create('alice');
    final bobOld = await DemoIdentityKey.create('bobOld');
    final bobNew = await DemoIdentityKey.create('bobNew');
    final dave = await DemoIdentityKey.create('dave');

    // 1. Alice trusts bobOld (dist 1)
    await alice.trust(bobOld, moniker: 'bobOld');
    
    // 2. bobOld trusts bobNew (dist 2)
    await bobOld.trust(bobNew, moniker: 'bobNew');
    
    // 3. bobOld trusts Dave (dist 2)
    final sDave = await bobOld.trust(dave, moniker: 'dave');

    // 4. bobNew (dist 2) replaces bobOld (dist 1) with a constraint
    // This is "Far to Close" because bobNew is further than Alice.
    await bobNew.replace(bobOld, lastGoodToken: sDave);

    final source = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.id);

    // Identity Link should be accepted
    expect(graph.resolveIdentity(bobOld.id), bobNew.id, 
      reason: 'Identity link should be accepted even from a further node');
    
    // Replacement constraint should be ignored
    expect(graph.isTrusted(dave.id), isTrue, 
      reason: 'Dave should still be trusted because the replacement constraint from a further node was ignored');
    
    expect(graph.notifications.any((n) => n.reason.contains('Replacement constraint ignored due to distance')), isTrue);
  });
}
