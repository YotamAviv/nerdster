import 'package:nerdster/demotest/demo_key.dart';

/// Scenario 1: Graceful Recovery (Hacked Key)
/// 
/// 1. Bob gets hacked. Hacker uses Bob's key to trust a malicious actor.
/// 2. Alice blocks Bob, citing the malicious trust statement.
/// 3. Bob recovers, rotates to a new key, and revokes the malicious trust.
/// 4. Alice's block should be dropped because the evidence is now invalid.
Future<Map<String, DemoKey>> setupGracefulRecovery() async {
  var alice = await DemoKey.create('Alice_GR');
  var charlie = await DemoKey.create('Charlie_GR');
  var bobA = await DemoKey.create('BobA_GR');
  var malicious = await DemoKey.create('Malicious_GR');

  // Establish the trust path
  await alice.trust(charlie);
  await charlie.trust(bobA);

  // Bob does something valid (e.g., trusts Charlie back)
  var sGood = await bobA.trust(charlie);
  
  // --- THE HACK ---
  var sBad = await bobA.trust(malicious); 

  // --- THE BLOCK ---
  await alice.block(bobA, citing: [sBad]);

  // --- THE RECOVERY ---
  var bobB = await DemoKey.create('BobB_GR');
  await bobB.replace(bobA, lastGoodToken: sGood);
  
  await charlie.trust(bobB);

  return {
    'alice': alice,
    'charlie': charlie,
    'bobA': bobA,
    'bobB': bobB,
    'malicious': malicious,
  };
}

/// Scenario 2: Persistent Block (Offense Not Cleared)
///
/// Alice blocks BobA for a bad act. BobA does NOT revoke the act.
/// The block should remain active.
Future<Map<String, DemoKey>> setupPersistentBlock() async {
  var alice = await DemoKey.create('Alice_PB');
  var charlie = await DemoKey.create('Charlie_PB');
  var bobA = await DemoKey.create('BobA_PB');
  var malicious = await DemoKey.create('Malicious_PB');

  await alice.trust(charlie);
  await charlie.trust(bobA);

  // BobA trusts malicious.
  var sBad = await bobA.trust(malicious);

  // Alice blocks BobA citing sBad.
  await alice.block(bobA, citing: [sBad]);

  return {
    'alice': alice,
    'charlie': charlie,
    'bobA': bobA,
    'malicious': malicious,
  };
}

/// Scenario 4: Mutual Friend Conflict
///
/// Alice -> Charlie -> Bob
/// Alice -> Dave -> Bob
/// Alice blocks Bob.
/// Even though Dave and Charlie trust Bob, Alice should not.
Future<Map<String, DemoKey>> setupMutualFriendConflict() async {
  var alice = await DemoKey.create('Alice_MFC');
  var charlie = await DemoKey.create('Charlie_MFC');
  var dave = await DemoKey.create('Dave_MFC');
  var bob = await DemoKey.create('Bob_MFC');
  var malicious = await DemoKey.create('Malicious_MFC');

  await alice.trust(charlie);
  await alice.trust(dave);
  await charlie.trust(bob);
  await dave.trust(bob);

  // Bob trusts malicious
  var sBad = await bob.trust(malicious);

  // Alice blocks Bob
  await alice.block(bob, citing: [sBad]);

  return {
    'alice': alice,
    'charlie': charlie,
    'dave': dave,
    'bob': bob,
    'malicious': malicious,
  };
}

/// Scenario 5: Lost Key (No Hack)
///
/// Bob loses his phone. Creates BobB. Replaces BobA.
/// Everyone should just update.
Future<Map<String, DemoKey>> setupLostKey() async {
  var alice = await DemoKey.create('Alice_LK');
  var charlie = await DemoKey.create('Charlie_LK');
  var bobA = await DemoKey.create('BobA_LK');

  await alice.trust(charlie);
  await charlie.trust(bobA);

  // BobA is lost. BobB replaces it.
  var bobB = await DemoKey.create('BobB_LK');
  await bobB.replace(bobA);
  
  await charlie.trust(bobB);

  return {
    'alice': alice,
    'charlie': charlie,
    'bobA': bobA,
    'bobB': bobB,
  };
}

/// Scenario 6: Poor Judgment (Transitive Citing)
///
/// Alice blocks Bob for an offense.
/// Charlie trusts Bob.
/// Alice blocks Charlie, citing his trust in Bob.
/// Charlie eventually revokes trust in Bob, healing the block.
Future<Map<String, DemoKey>> setupPoorJudgment() async {
  var alice = await DemoKey.create('Alice_PJ');
  var charlie = await DemoKey.create('Charlie_PJ');
  var bob = await DemoKey.create('Bob_PJ');
  var malicious = await DemoKey.create('Malicious_PJ');

  // Setup: Alice -> Charlie -> Bob -> Malicious
  await alice.trust(charlie);
  await charlie.trust(bob);
  var sBad = await bob.trust(malicious);

  // 1. Alice blocks Bob (Primary Offense)
  await alice.block(bob, citing: [sBad]);

  // 2. Alice sees Charlie still trusts Bob.
  var sPoorJudgment = await charlie.trust(bob); 

  // Alice blocks Charlie, citing his trust in Bob.
  await alice.block(charlie, citing: [sPoorJudgment]);

  // HEALING CHECK:
  // Charlie realizes his mistake and revokes trust in Bob.
  await charlie.revoke(bob);

  return {
    'alice': alice,
    'charlie': charlie,
    'bob': bob,
    'malicious': malicious,
  };
}

/// Scenario 7: The Whac-A-Mole Flaw
///
/// Charlie trusts Bob (s1). Alice blocks Charlie citing s1.
/// Charlie revokes s1 (Heals).
/// Charlie trusts Bob again (s2).
/// Alice is exposed again.
Future<Map<String, DemoKey>> setupWhacAMole() async {
  var alice = await DemoKey.create('Alice_WAM');
  var charlie = await DemoKey.create('Charlie_WAM');
  var bob = await DemoKey.create('Bob_WAM');

  await alice.trust(charlie);
  var sTrust1 = await charlie.trust(bob);

  // Alice blocks Charlie for trusting Bob.
  await alice.block(charlie, citing: [sTrust1]);

  // Charlie revokes the specific trust statement.
  await charlie.revoke(bob); 

  // --- THE FLAW ---
  // Charlie trusts Bob again (new statement).
  await charlie.trust(bob);

  return {
    'alice': alice,
    'charlie': charlie,
    'bob': bob,
  };
}

/// Scenario: Basic Trust
///
/// Lisa <-> Marge
/// Marge -> Bart
Future<(DemoKey, DemoKey?)> basicScenario() async {
  var lisa = await DemoKey.create('lisa');
  var marge = await DemoKey.create('marge');
  var bart = await DemoKey.create('bart');

  await lisa.trust(marge);
  await marge.trust(lisa);
  await marge.trust(bart);

  return (marge, null);
}


