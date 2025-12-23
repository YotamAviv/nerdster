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

  test('Revoke Since Always', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    await alice.trust(bobNew);
    // bobNew replaces bob, but revokes him "since always"
    await bobNew.doTrust(TrustVerb.replace, bob, revokeAt: '<since always>');
    await bob.trust(charlie); // This statement should be ignored

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(bob.token), isTrue, reason: 'Bob is still part of the identity');
    expect(graph.isTrusted(charlie.token), isFalse, reason: 'Bobs statements should be revoked');
  });

  test('Revoke with Garbage Token (Since Always)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    await alice.trust(bobNew);
    // bobNew replaces bob, but uses a garbage revokeAt token
    await bobNew.doTrust(TrustVerb.replace, bob, revokeAt: 'garbage-token');
    await bob.trust(charlie); // This statement should be ignored

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(charlie.token), isFalse, reason: 'Bobs statements should be revoked due to invalid token');
  });

  test('Revocation Race Condition (Requires 2 passes)', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    // Alice trusts Bob AND BobNew.
    // We want Bob to be processed BEFORE BobNew in the BFS.
    // In reduceTrustGraph, issuer statements are sorted newest-first.
    // So if Alice trusts Bob AFTER she trusts BobNew, Bob will be first in the list.
    
    await alice.trust(bobNew); // Older
    await Future.delayed(Duration(milliseconds: 10));
    await alice.trust(bob);    // Newer -> Processed first
    
    // Bob trusts Charlie.
    await bob.trust(charlie);
    
        // BobNew replaces Bob and revokes his statements.
    await bobNew.doTrust(TrustVerb.replace, bob, revokeAt: '<since always>');

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    // Set maxDegrees to 3 so that BobNew (dist 1) can revoke Bob (dist 2) 
    // and we can see the effect on Charlie (dist 3).
    final pipeline = TrustPipeline(source, maxDegrees: 3);
    
    // This test is designed to FAIL if orchestrator.dart only runs reduceTrustGraph once.
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(bob.token), isTrue);
    expect(graph.isTrusted(charlie.token), isFalse, 
      reason: 'Charlie should be revoked by BobNew. If this fails, it means the race condition was not resolved.');
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

  test('Distance Authority: Deep Replacement Revocation Ignored', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');
    final frank = await DemoKey.create('frank');

    // Alice trusts Bob (dist 1)
    await alice.trust(bob);
    // Alice trusts Charlie (dist 1)
    await alice.trust(charlie);
    // Charlie trusts BobNew (dist 2)
    await charlie.trust(bobNew);
    
    // BobNew replaces Bob and revokes everything
    await bobNew.doTrust(TrustVerb.replace, bob, revokeAt: '<since always>');
    
    // Bob trusts Frank
    await bob.trust(frank);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    
    // --- PoV: Alice ---
    final graphAlice = await pipeline.build(alice.token);
    
    expect(graphAlice.isTrusted(bob.token), isTrue);
    expect(graphAlice.isTrusted(bobNew.token), isTrue);
    expect(graphAlice.isTrusted(frank.token), isTrue, 
      reason: 'Frank should be trusted because BobNew is further away than Bob from Alices PoV');
    expect(graphAlice.notifications.any((n) => n.reason.contains('Revocation ignored due to distance')), isTrue);

    // --- PoV: Charlie ---
    final graphCharlie = await pipeline.build(charlie.token);
    
    expect(graphCharlie.isTrusted(bobNew.token), isTrue);
    expect(graphCharlie.isTrusted(bob.token), isTrue);
    expect(graphCharlie.isTrusted(frank.token), isFalse, 
      reason: 'Frank should be revoked because BobNew is closer to Charlie than Bob is');
  });

  test('Backward Discovery: Pulling in distant keys', () async {
    final alice = await DemoKey.create('alice');
    final bob = await DemoKey.create('bob');
    final bobNew = await DemoKey.create('bobNew');
    final charlie = await DemoKey.create('charlie');

    // Alice -> Charlie (dist 1)
    await alice.trust(charlie);
    // Charlie -> BobNew (dist 2)
    await charlie.trust(bobNew);
    // BobNew replaces Bob
    await bobNew.replace(bob);
    
    // Bob is NOT trusted by anyone else. 
    // Without backward discovery, Bob would be "not in network".
    
    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    // We need maxDegrees: 3 so that BobNew (at dist 2) is processed as an issuer.
    final pipeline = TrustPipeline(source, maxDegrees: 3);
    final graph = await pipeline.build(alice.token);

    expect(graph.isTrusted(bobNew.token), isTrue);
    expect(graph.isTrusted(bob.token), isTrue, 
      reason: 'Bob should be pulled into the network at distance 3 because BobNew is at distance 2');
    expect(graph.distances[bob.token], 3);
  });

  test('Double Replacement (Shortcut vs Fork)', () async {
    final alice = await DemoKey.create('alice');
    final bob1 = await DemoKey.create('bob1');
    final bob2 = await DemoKey.create('bob2');
    final bob3 = await DemoKey.create('bob3');

    // Alice trusts the newest key
    await alice.trust(bob3);

    // Bob3 replaces both predecessors
    await bob3.replace(bob2);
    await bob3.replace(bob1);

    // Bob2 also replaces Bob1 (the standard chain)
    await bob2.replace(bob1);

    final source = DirectFirestoreSource<TrustStatement>(kOneofusDomain);
    final pipeline = TrustPipeline(source, maxDegrees: 5);
    final graph = await pipeline.build(alice.token);

    // --- THOUGHTS ON DOUBLE REPLACEMENT ---
    // Scenario: Bob3 replaces Bob2 AND Bob1. Bob2 replaces Bob1.
    //
    // 1. Is it a Conflict? 
    //    Technically, Bob1 has two keys claiming to be its successor. If Bob2 and Bob3 
    //    were different people, this would be a "Fork" (a hijack attempt).
    //
    // 2. Is it a Shortcut?
    //    Since Bob3 also replaces Bob2, it's a consistent chain. Bob3 is just 
    //    providing a "shortcut" for anyone who only knows Bob1.
    //
    // 3. Current Algorithm Behavior:
    //    The algorithm uses "Distance Authority". Since Bob3 (dist 1) is closer 
    //    than Bob2 (dist 2), Bob3's replacement of Bob1 is processed first.
    //    When Bob2 tries to replace Bob1, the algorithm sees Bob1 is already 
    //    trusted via a shorter path and ignores the second revocation, 
    //    issuing an INFO notification.
    //
    // 4. Open Question:
    //    Should we suppress this notification if the chain is consistent? 
    //    Doing so would require the algorithm to "know" that Bob3 also replaces Bob2
    //    while it is processing Bob2's statements.
    
    expect(graph.isTrusted(bob3.token), isTrue);
    expect(graph.isTrusted(bob2.token), isTrue);
    expect(graph.isTrusted(bob1.token), isTrue);
    
    print('Notifications:');
    for (var n in graph.notifications) {
      print('  - ${n.reason} (Conflict: ${n.isConflict})');
    }

    final hasConflict = graph.notifications.any((n) => n.isConflict && n.reason.contains('replaced by both'));
    final hasInfo = graph.notifications.any((n) => !n.isConflict && n.reason.contains('Revocation ignored due to distance'));
    
    print('Has Conflict: $hasConflict');
    print('Has Info: $hasInfo');
    print('Bob1 Replacement: ${graph.replacements[bob1.token] == bob3.token ? "Bob3" : "Bob2"}');
  });
}
