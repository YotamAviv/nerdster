import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/demotest/demo_key.dart';

import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/prefs.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoKey.clear();
  });

  test('Basic Trust BFS', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');

    await alice.trust(bob);
    await bob.trust(charlie);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bob.token), isTrue);
    expect(graph.isTrusted(charlie.token), isTrue);
    expect(graph.distances[bob.token], 1);
    expect(graph.distances[charlie.token], 2);
  });

  test('Key Rotation (Replace)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    await alice.trust(bobNew); // Alice only trusts the NEW key
    await bobNew.replace(bob); // bobNew replaces bob
    await bob.trust(charlie);  // Charlie was trusted by the OLD key

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    // Alice (0) -> BobNew (1) -> Bob (2) -> Charlie (3)
    // So we need maxDegrees: 3 to reach Charlie.
    // We also need a pathRequirement that allows 1 path at distance 3.
    final pipeline = TrustPipeline(source, maxDegrees: 6, pathRequirement: (d) => 1);
    final graph = await pipeline.build(alice.token);

    // The algorithm should discover 'bob' via 'bobNew' and find 'charlie'
    expect(graph.isTrusted(bobNew.token), isTrue, reason: 'BobNew should be trusted');
    expect(graph.isTrusted(bob.token), isTrue, reason: 'Bob should be trusted via BobNew');
    expect(graph.isTrusted(charlie.token), isTrue, reason: 'Charlie should be trusted via Bob');
    expect(graph.replacements[bob.token], bobNew.token);
  });

  test('Confidence Levels (Multiple Paths)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');
    final dave = await DemoKey.create('dave');

    // Alice trusts Bob and Charlie (dist 1)
    // Bob and Charlie trust Dave (dist 2)
    await alice.trust(bob);
    await alice.trust(charlie);
    await bob.trust(dave);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    
    // Requirement: 2 paths for distance 2
    final pipeline = TrustPipeline(source, pathRequirement: (d) => d >= 2 ? 2 : 1);
    
    var graph = await pipeline.build(alice.token);
    expect(graph.isTrusted(dave.token), isFalse, reason: 'Dave only has 1 path');

    await charlie.trust(dave);
    // Now Dave has 2 paths (Bob and Charlie)
    
    graph = await pipeline.build(alice.token);
    expect(graph.isTrusted(dave.token), isTrue, reason: 'Dave now has 2 paths');
  });

  test('Conflicts (Trust vs Block)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');
    final dave = await DemoKey.create('dave');

    // Alice trusts Bob then Charlie. 
    // Since reduceTrustGraph sorts newest first, Charlie is processed before Bob.
    await alice.trust(bob);
    await alice.trust(charlie);
    
    await bob.trust(dave);
    await charlie.block(dave);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.blocked.contains(dave.token), isTrue);
    expect(graph.isTrusted(dave.token), isFalse);
    expect(graph.conflicts.length, greaterThan(0));
    // Since Charlie is newer, he is processed first, so Dave is blocked, then Bob tries to trust him.
    expect(graph.conflicts.first.reason, contains('trust blocked key'));
  });

  test('Replace Notification (Not Conflict)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');

    await alice.trust(bob);
    await alice.trust(bobNew);
    await bobNew.replace(bob);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.notifications.any((n) => !n.isConflict && n.reason.contains('being replaced')), isTrue);
  });

  test('Clear Trust', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');

    await alice.trust(bob);
    await alice.revoke(bob); // This issues a 'clear' statement

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bob.token), isFalse, reason: 'Trust was cleared');
  });

  test('Replace with Constraint (Since Always)', () async {
    final alice = await DemoKey.create('alice');
    final bobOld = await DemoKey.create('bobOld');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    await alice.trust(bobNew);
    // bobNew replaces bobOld, but constrains him "since always"
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: '<since always>');
    await bobOld.trust(charlie); // This statement should be ignored

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(bobOld.token), isTrue, reason: 'bobOld is still part of the identity');
    expect(graph.isTrusted(charlie.token), isFalse, reason: 'bobOld statements should be ignored due to constraint');
  });

  test('Replace with Garbage Constraint (Since Always)', () async {
    final alice = await DemoKey.create('alice');
    final bobOld = await DemoKey.create('bobOld');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    await alice.trust(bobNew);
    // bobNew replaces bobOld, but uses a garbage revokeAt token
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: 'garbage-token');
    await bobOld.trust(charlie); // This statement should be ignored

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(charlie.token), isFalse, reason: 'bobOld statements should be ignored due to invalid constraint token');
  });

  test('Replacement Race Condition (Requires 2 passes)', () async {
    final alice = await DemoKey.create('alice');
    final bobOld = await DemoKey.create('bobOld');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    // Alice trusts bobOld AND bobNew.
    // We want bobOld to be processed BEFORE bobNew in the BFS.
    // In reduceTrustGraph, issuer statements are sorted newest-first.
    // So if Alice trusts bobOld AFTER she trusts bobNew, bobOld will be first in the list.
    
    await alice.trust(bobNew); // Older
    await Future.delayed(Duration(milliseconds: 10));
    await alice.trust(bobOld);    // Newer -> Processed first
    
    // bobOld trusts Charlie.
    await bobOld.trust(charlie);
    
    // bobNew replaces bobOld and constrains his statements.
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: '<since always>');

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    // Set maxDegrees to 3 so that bobNew (dist 1) can constrain bobOld (dist 2) 
    // and we can see the effect on Charlie (dist 3).
    final pipeline = TrustPipeline(source, maxDegrees: 3);
    
    // This test is designed to FAIL if orchestrator.dart only runs reduceTrustGraph once.
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(bobOld.token), isTrue);
    expect(graph.isTrusted(charlie.token), isFalse, 
      reason: 'Charlie should be ignored due to bobNew constraint. If this fails, it means the race condition was not resolved.');
  });

  test('Trust Non-Canonical Key Notification', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    await alice.trust(charlie);
    await alice.trust(bobNew);
    await bobNew.replace(bob);
    await charlie.trust(bob); // Charlie trusts the OLD key directly, but BobNew (also trusted) replaced it

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.notifications.any((n) => n.reason.contains('non-canonical')), isTrue);
  });

  test('Distance Authority: Deep Replacement Constraint Ignored', () async {
    final alice = await DemoKey.create('alice');
    final bobOld = await DemoKey.create('bobOld');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');
    final frank = await DemoKey.create('frank');

    // Alice trusts bobOld (dist 1)
    await alice.trust(bobOld);
    // Alice trusts Charlie (dist 1)
    await alice.trust(charlie);
    // Charlie trusts bobNew (dist 2)
    await charlie.trust(bobNew);
    
    // bobNew replaces bobOld and constrains everything
    await bobNew.doTrust(TrustVerb.replace, bobOld, revokeAt: '<since always>');
    
    // bobOld trusts Frank
    await bobOld.trust(frank);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    
    // --- PoV: Alice ---
    final graphAlice = await pipeline.build(alice.token);
    
    expect(graphAlice.isTrusted(bobOld.token), isTrue);
    expect(graphAlice.isTrusted(bobNew.token), isTrue);
    expect(graphAlice.isTrusted(frank.token), isTrue, 
      reason: 'Frank should be trusted because bobNew is further away than bobOld from Alices PoV');
    expect(graphAlice.notifications.any((n) => n.reason.contains('Replacement constraint ignored due to distance')), isTrue);

    // --- PoV: Charlie ---
    final graphCharlie = await pipeline.build(charlie.token);
    
    expect(graphCharlie.isTrusted(bobNew.token), isTrue);
    expect(graphCharlie.isTrusted(bobOld.token), isTrue);
    expect(graphCharlie.isTrusted(frank.token), isFalse, 
      reason: 'Frank should be ignored because bobNew is closer to Charlie than bobOld is');
  });

  test('Backward Discovery: Pulling in historical keys', () async {
    final alice = await DemoKey.create('alice');
    final bobOld = await DemoKey.create('bobOld');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    // Alice -> Charlie (dist 1)
    await alice.trust(charlie);
    // Charlie -> bobNew (dist 2)
    await charlie.trust(bobNew);
    // bobNew replaces bobOld
    await bobNew.replace(bobOld);
    
    // bobOld is NOT trusted by anyone else. 
    // Without backward discovery, bobOld would be "not in network".
    
    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    // We need maxDegrees: 3 so that bobNew (at dist 2) is processed as an issuer.
    final pipeline = TrustPipeline(source, maxDegrees: 3);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(bobOld.token), isTrue, 
      reason: 'bobOld should be pulled into the network at distance 3 because bobNew is at distance 2');
    expect(graph.distances[bobOld.token], 3);
  });

  test('Double Replacement (Shortcut vs Fork)', () async {
    final alice = await DemoKey.create('alice');
    final bobV1 = await DemoKey.create('bobV1');
    final bobV2 = await DemoKey.create('bobV2');
    final bobV3 = await DemoKey.create('bobV3');

    // Alice trusts the newest key
    await alice.trust(bobV3);

    // bobV3 replaces both predecessors
    await bobV3.replace(bobV2);
    await bobV3.replace(bobV1);

    // bobV2 also replaces bobV1 (the standard chain)
    await bobV2.replace(bobV1);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);

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
    
    expect(graph.isTrusted(bobV3.token), isTrue);
    expect(graph.isTrusted(bobV2.token), isTrue);
    expect(graph.isTrusted(bobV1.token), isTrue);
    
    print('Notifications:');
    for (var n in graph.notifications) {
      print('  - ${n.reason} (Conflict: ${n.isConflict})');
    }

    final hasConflict = graph.notifications.any((n) => n.isConflict && n.reason.contains('replaced by both'));
    final hasInfo = graph.notifications.any((n) => !n.isConflict && n.reason.contains('Replacement constraint ignored due to distance'));
    
    print('Has Conflict: $hasConflict');
    print('Has Info: $hasInfo');
    print('bobV1 Replacement: ${graph.replacements[bobV1.token] == bobV3.token ? "bobV3" : "bobV2"}');
  });

  test('Ordered Keys (BFS Discovery)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');
    final dave = await DemoKey.create('dave');

    // Alice -> Bob, Charlie
    await alice.trust(bob);
    await alice.trust(charlie);

    // Bob -> Dave
    await bob.trust(dave);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);

    // Order should be: Alice (0), Charlie (1), Bob (1), Dave (2)
    // Charlie comes before Bob because Alice trusted him later (newest-first processing).
    expect(graph.orderedKeys, [
      alice.token,
      charlie.token,
      bob.token,
      dave.token,
    ]);
    expect(graph.orderedKeys.length, 4);
  });

  test('Graph Paths (Shortest Paths)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');
    final dave = await DemoKey.create('dave');

    // Alice -> Bob -> Dave
    // Alice -> Charlie -> Dave
    await alice.trust(bob);
    await alice.trust(charlie);
    await bob.trust(dave);
    await charlie.trust(dave);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);

    final paths = graph.getPathsTo(dave.token);
    expect(paths.length, 2);
    expect(paths, containsAll([
      [alice.token, bob.token, dave.token],
      [alice.token, charlie.token, dave.token],
    ]));
  });

  test('Replacement: Far to Close (Identity Link vs Replacement Constraint)', () async {
    final alice = await DemoKey.create('alice');
    final bobOld = await DemoKey.create('bobOld');
    final bobNew = await DemoKey.create('bobNew');
    final dave = await DemoKey.create('dave');

    // 1. Alice trusts bobOld (dist 1)
    await alice.trust(bobOld);
    
    // 2. bobOld trusts bobNew (dist 2)
    await bobOld.trust(bobNew);
    
    // 3. bobOld trusts Dave (dist 2)
    final sDave = await bobOld.trust(dave);

    // 4. bobNew (dist 2) replaces bobOld (dist 1) with a constraint
    // This is "Far to Close" because bobNew is further than Alice.
    await bobNew.replace(bobOld, lastGoodToken: sDave);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);

    // Identity Link should be accepted
    expect(graph.resolveIdentity(bobOld.token), bobNew.token, 
      reason: 'Identity link should be accepted even from a further node');
    
    // Replacement constraint should be ignored
    expect(graph.isTrusted(dave.token), isTrue, 
      reason: 'Dave should still be trusted because the replacement constraint from a further node was ignored');
    
    expect(graph.notifications.any((n) => n.reason.contains('Replacement constraint ignored due to distance')), isTrue);
  });
}
