import 'package:test/test.dart';
// import 'package:nerdster/demotest/demo_key.dart';

void main() {
  // TODO: IMPLEMENTATION THOUGHTS - CITED BLOCKING & HEALING
  //
  // The 'citing' parameter in a block statement MUST be a non-empty List<Statement>.
  // Blocking without a reason (citation) is NOT allowed.
  //
  // HEALING MECHANISM:
  // A block is considered "active" only if at least one of the cited statements is "valid"
  // (i.e., exists in the graph and has not been revoked or replaced-away).
  //
  // If ALL cited statements are revoked (e.g., by a key rotation that excludes them,
  // or an explicit revocation), the block becomes "moot".
  // A moot block is ignored by the trust logic, effectively "healing" the relationship
  // without requiring the blocker to manually unblock.
  //
  // POOR JUDGMENT (Transitive Citing):
  // If Bob commits an offense (sBad) and Charlie trusts Bob (sTrust),
  // Alice can block Bob citing [sBad].
  // If Charlie persists in trusting Bob, Alice can block Charlie citing [sTrust].
  // This effectively treats "trusting a bad actor" as an offense itself.
  //
  // SCENARIOS TO TEST:
  // 1. Graceful Recovery: Offense revoked -> Block moot -> Trust established.
  // 2. Persistent Block: Offense remains -> Block active -> Trust denied.
  // 3. Invalid Block: Empty citation list -> Error.
  // 4. Mutual Friend: Block overrides positive trust paths.
  // 5. Lost Key: Simple rotation without blocks.
  // 6. Poor Judgment: Blocking a friend for trusting a blocked key.

  group('Scenario 1: Graceful Recovery (Hacked Key)', () {
    test('Block is moot if offending statement is revoked', () async {
      // Intent: 
      // 1. Bob gets hacked. Hacker uses Bob's key to trust a malicious actor.
      // 2. Alice blocks Bob, citing the malicious trust statement.
      // 3. Bob recovers, rotates to a new key, and revokes the malicious trust.
      // 4. Alice's block should be dropped because the evidence is now invalid.

      // --- SETUP ---
      // Alice -> Charlie -> Bob(A)
      var alice = await DemoKey.create('Alice');
      var charlie = await DemoKey.create('Charlie');
      var bobA = await DemoKey.create('BobA');
      var malicious = await DemoKey.create('Malicious');

      // Establish the trust path
      await alice.trust(charlie);
      await charlie.trust(bobA);

      // Bob does something valid (e.g., trusts Charlie back)
      // This establishes a "last good" point.
      var sGood = await bobA.trust(charlie);
      
      // --- THE HACK ---
      // Hacker gets control of BobA and trusts a malicious actor
      var sBad = await bobA.trust(malicious); 

      // --- THE BLOCK ---
      // Alice sees the bad trust. She blocks BobA.
      // CRITICAL: She cites 'sBad' as the reason.
      await alice.block(bobA, citing: [sBad]);

      // --- THE RECOVERY ---
      // Bob regains control (or realizes he lost it) and creates a new key.
      var bobB = await DemoKey.create('BobB');

      // BobB replaces BobA immediately.
      // CRITICAL: He sets 'lastGoodToken' to 'sGood'.
      // This means: "BobA was valid up until sGood. Anything after that (like sBad) is invalid."
      await bobB.replace(bobA, lastGoodToken: sGood);
      
      // Charlie verifies BobB manually and trusts him.
      await charlie.trust(bobB);

      // --- ASSERTIONS ---

      // 1. Alice's Network
      // Alice should trust Charlie, BobB, and BobA (as a replaced key).
      // BobA should have a revokeAt set to sGood (or the replacement token).
      // Malicious should NOT be in the network.
      var aliceNet = alice.network;
      expect(aliceNet.containsKey(charlie.token), isTrue);
      expect(aliceNet.containsKey(bobB.token), isTrue);
      expect(aliceNet.containsKey(bobA.token), isTrue);
      expect(aliceNet[bobA.token]?.revokeAt, isNotNull, reason: "BobA should be revoked");
      expect(aliceNet.containsKey(malicious.token), isFalse, reason: "Malicious should not be trusted");

      // 2. Charlie's Network
      var charlieNet = charlie.network;
      expect(charlieNet.containsKey(bobB.token), isTrue);
      expect(charlieNet.containsKey(bobA.token), isTrue);
      expect(charlieNet[bobA.token]?.revokeAt, isNotNull);
      expect(charlieNet.containsKey(malicious.token), isFalse);

      // 3. BobB's Network
      var bobNet = bobB.network;
      expect(bobNet.containsKey(charlie.token), isTrue);
      expect(bobNet.containsKey(bobA.token), isTrue);
      expect(bobNet[bobA.token]?.revokeAt, isNotNull);

      // --- NOTIFICATIONS ---
      // Charlie trusted BobA. He should be notified of the replacement.
      expect(charlie.notifications, contains(predicate((n) => 
        n.toString().contains("Key BobA replaced by BobB")
      )));

      // Alice blocked BobA citing a specific statement. 
      // That statement was revoked, so the block is moot.
      // This is "Graceful Recovery", so she should NOT be notified.
      expect(alice.notifications, isEmpty, reason: "Alice should not be bothered by moot blocks");

      // BobB initiated the replacement. He shouldn't be notified of his own action.
      expect(bobB.notifications, isEmpty);
      
      // Malicious is out of the loop.
      expect(malicious.notifications, isEmpty);
    });
  });

  group('Scenario 2: Persistent Block (Offense Not Cleared)', () {
    test('Block remains active if cited offense is still valid', () async {
      // Intent:
      // Alice blocks BobA for a bad act. BobA does NOT revoke the act.
      // The block should remain active.

      var alice = await DemoKey.create('Alice');
      var charlie = await DemoKey.create('Charlie');
      var bobA = await DemoKey.create('BobA');
      var malicious = await DemoKey.create('Malicious');

      await alice.trust(charlie);
      await charlie.trust(bobA);

      // BobA trusts malicious.
      var sBad = await bobA.trust(malicious);

      // Alice blocks BobA citing sBad.
      await alice.block(bobA, citing: [sBad]);

      // --- ASSERTIONS ---
      
      // Alice's Network
      // Block is active. BobA is filtered out.
      var aliceNet = alice.network;
      expect(aliceNet.containsKey(bobA.token), isFalse, reason: "BobA should be blocked");
      expect(aliceNet.containsKey(malicious.token), isFalse, reason: "Malicious path broken by block");

      // Charlie's Network (No block)
      // Charlie still sees BobA and Malicious.
      var charlieNet = charlie.network;
      expect(charlieNet.containsKey(bobA.token), isTrue);
      expect(charlieNet.containsKey(malicious.token), isTrue);
    });
  });

  group('Scenario 3: Invalid Block (No Citation)', () {
    test('Blocking without citation throws an error', () async {
      // Intent:
      // Ensure that the API enforces the "must cite something" rule.
      
      var alice = await DemoKey.create('Alice');
      var bob = await DemoKey.create('Bob');

      // Alice tries to block Bob without a reason.
      // This should fail.
      expect(() => alice.block(bob, citing: []), throwsA(isA<ArgumentError>()));
    });
  });

  group('Scenario 4: Mutual Friend Conflict', () {
    test('Block overrides trust from other paths', () async {
      // Intent:
      // Alice -> Charlie -> Bob
      // Alice -> Dave -> Bob
      // Alice blocks Bob.
      // Even though Dave and Charlie trust Bob, Alice should not.

      var alice = await DemoKey.create('Alice');
      var charlie = await DemoKey.create('Charlie');
      var dave = await DemoKey.create('Dave');
      var bob = await DemoKey.create('Bob');
      var malicious = await DemoKey.create('Malicious');

      await alice.trust(charlie);
      await alice.trust(dave);
      await charlie.trust(bob);
      await dave.trust(bob);

      // Bob trusts malicious
      var sBad = await bob.trust(malicious);

      // Alice blocks Bob
      await alice.block(bob, citing: [sBad]);

      // --- ASSERTIONS ---
      var aliceNet = alice.network;
      expect(aliceNet.containsKey(bob.token), isFalse, reason: "Block should override all trust paths");
      expect(aliceNet.containsKey(malicious.token), isFalse);
    });
  });

  group('Scenario 5: Lost Key (No Hack)', () {
    test('Simple rotation maintains trust without blocks', () async {
      // Intent:
      // Bob loses his phone. Creates BobB. Replaces BobA.
      // Everyone should just update.

      var alice = await DemoKey.create('Alice');
      var charlie = await DemoKey.create('Charlie');
      var bobA = await DemoKey.create('BobA');

      await alice.trust(charlie);
      await charlie.trust(bobA);

      // BobA is lost. BobB replaces it.
      var bobB = await DemoKey.create('BobB');
      await bobB.replace(bobA);
      
      await charlie.trust(bobB);

      // --- ASSERTIONS ---
      var aliceNet = alice.network;
      expect(aliceNet.containsKey(bobB.token), isTrue, reason: "Alice should follow the replacement");
      expect(aliceNet.containsKey(bobA.token), isTrue, reason: "Old key visible but revoked");
      expect(aliceNet[bobA.token]?.revokeAt, isNotNull);
      
      // Notifications
      expect(charlie.notifications, contains(predicate((n) => 
        n.toString().contains("Key BobA replaced by BobB")
      )));
    });
  });

  group('Scenario 6: Poor Judgment (Transitive Citing)', () {
    test('Blocking a friend for trusting a blocked key', () async {
      // Intent:
      // Alice blocks Bob for an offense.
      // Charlie trusts Bob.
      // Alice considers Charlie's trust in Bob to be "Poor Judgment".
      // Alice blocks Charlie, citing his trust statement.

      var alice = await DemoKey.create('Alice');
      var charlie = await DemoKey.create('Charlie');
      var bob = await DemoKey.create('Bob');
      var malicious = await DemoKey.create('Malicious');

      // Setup: Alice -> Charlie -> Bob -> Malicious
      await alice.trust(charlie);
      await charlie.trust(bob);
      var sBad = await bob.trust(malicious);

      // 1. Alice blocks Bob (Primary Offense)
      await alice.block(bob, citing: [sBad]);

      // Verify Bob is blocked
      expect(alice.network.containsKey(bob.token), isFalse);
      expect(alice.network.containsKey(charlie.token), isTrue, reason: "Charlie still trusted initially");

      // 2. Alice sees Charlie still trusts Bob.
      // She decides to block Charlie for this "Poor Judgment".
      // She needs the statement where Charlie trusted Bob.
      // In a real app, she'd find this in the graph.
      // For the test, we can capture it or assume we have it.
      // Let's assume we can get it from Charlie or the graph.
      // (Simulating finding the edge)
      var sPoorJudgment = await charlie.trust(bob); // Re-issuing or getting the hash

      // Alice blocks Charlie, citing his trust in Bob.
      await alice.block(charlie, citing: [sPoorJudgment]);

      // --- ASSERTIONS ---
      
      // Alice's Network
      // Charlie should now be blocked.
      var aliceNet = alice.network;
      expect(aliceNet.containsKey(charlie.token), isFalse, reason: "Charlie blocked for poor judgment");
      
      // Bob is definitely still blocked (path broken anyway).
      expect(aliceNet.containsKey(bob.token), isFalse);

      // HEALING CHECK:
      // If Charlie revokes his trust in Bob, does Alice's block on Charlie heal?
      // Charlie realizes his mistake and revokes trust in Bob.
      await charlie.revoke(bob); // Or revoke the specific statement sPoorJudgment

      // Now sPoorJudgment is revoked.
      // Alice's block on Charlie cited sPoorJudgment.
      // Therefore, the block on Charlie should become moot.
      // Alice should trust Charlie again.
      
      // (Note: We need to refresh aliceNet)
      var aliceNetHealed = alice.network;
      expect(aliceNetHealed.containsKey(charlie.token), isTrue, reason: "Charlie forgiven after revoking bad trust");
    });
  });

  group('Scenario 7: The Whac-A-Mole Flaw (Re-issued Offenses)', () {
    test('Healing is fragile if the offense is re-committed with a new statement', () async {
      // Intent:
      // Demonstrate the limitation of citing specific statements.
      // If Alice blocks Charlie for trusting Bob (Statement A), and Charlie revokes A,
      // Alice heals. But if Charlie immediately trusts Bob again (Statement B),
      // Alice's block (citing A) remains moot, and she is exposed to Bob again
      // unless she actively blocks B.
      //
      // DOCUMENTED FLAW:
      // - The guy I block could just re-trust the offender with a new comment.
      // - Now it's a different statement, so the old block doesn't catch it.
      // - This applies to all offending statements (spam, etc).
      // - MITIGATION: Ideally, the social pressure of "I will block you if you trust him"
      //   leads to the friend permanently removing the trust.

      var alice = await DemoKey.create('Alice');
      var charlie = await DemoKey.create('Charlie');
      var bob = await DemoKey.create('Bob');

      await alice.trust(charlie);
      var sTrust1 = await charlie.trust(bob);

      // Alice blocks Charlie for trusting Bob.
      await alice.block(charlie, citing: [sTrust1]);

      // Verify Block
      expect(alice.network.containsKey(charlie.token), isFalse);

      // Charlie revokes the specific trust statement.
      await charlie.revoke(bob); // Revokes sTrust1

      // Verify Healing
      // Alice sees sTrust1 is revoked. Block is moot.
      expect(alice.network.containsKey(charlie.token), isTrue, reason: "Healed after revocation");

      // --- THE FLAW ---
      // Charlie trusts Bob again (new statement).
      var sTrust2 = await charlie.trust(bob);

      // Alice's block cited sTrust1. sTrust1 is still revoked.
      // So Alice still trusts Charlie.
      // And now she sees Bob again (via sTrust2).
      var aliceNet = alice.network;
      expect(aliceNet.containsKey(charlie.token), isTrue, reason: "Alice still trusts Charlie (Flaw)");
      expect(aliceNet.containsKey(bob.token), isTrue, reason: "Alice is exposed to Bob again (Flaw)");
    });
  });
}
