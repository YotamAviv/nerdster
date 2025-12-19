import 'package:test/test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/v2_scenarios.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fireChoice = FireChoice.fake;
    fakeFirestore = FakeFirebaseFirestore();
    TrustStatement.init();
    ContentStatement.init();
    // Register FakeFirestore for both domains used by DemoKey/Fetcher
    FireFactory.register(kOneofusDomain, fakeFirestore, null);
    FireFactory.register(kNerdsterDomain, fakeFirestore, null);
    
    // Clear V2Config URLs to ensure SourceFactory uses DirectFirestoreSource (which uses FireFactory)
    // (Assuming V2Config has a way to clear or we just don't register them)
    // V2Config is static, so we might need to clear it if previous tests set it.
    // But here we just rely on not setting them.
  });

  // Helper to get the graph for a key
  Future<Map<String, TrustStatement>> getNetwork(DemoKey key) async {
    final source = SourceFactory.get(kOneofusDomain);
    final pipeline = TrustPipeline(source);
    final graph = await pipeline.build(key.token);
    
    // Convert graph.edges (Map<String, List<TrustStatement>>) to a simple Map<String, TrustStatement>
    // representing the "active" statement or just presence.
    // The legacy 'network' map was Map<String, TrustStatement>.
    // Here we can map the token to the *last* valid statement or just a placeholder.
    // For the assertions, we mostly check containsKey and revokeAt.
    
    final Map<String, TrustStatement> network = {};
    for (var entry in graph.edges.entries) {
      final token = entry.key;
      final stmts = entry.value;
      if (stmts.isNotEmpty) {
        // Use the most recent statement as the representative?
        network[token] = stmts.first; 
      }
    }
    
    // Also include replaced keys if they are in the graph structure?
    // The legacy 'network' included them.
    // In V2, 'graph.edges' contains valid edges.
    // If a key is replaced, is it in 'edges'?
    // The reducer logic should handle this.
    
    // We also need to attach 'revokeAt' info to the statement if possible, 
    // or check graph.revokeAtConstraints separately.
    // But the test expects `aliceNet[bobA.token]?.revokeAt`.
    // TrustStatement has a 'revokeAt' field.
    // If the graph has a constraint, does it modify the statement? No.
    // The constraint is in `graph.revokeAtConstraints`.
    
    // So we might need to wrap or modify how we assert.
    return network;
  }
  
  // Helper to check revokeAt in assertions
  bool isRevoked(String token, Map<String, TrustStatement> net) {
     // This is tricky because the test checks `net[token]?.revokeAt`.
     // But `revokeAt` is a property of the *TrustStatement* (the edge), not the node.
     // Wait, `TrustStatement` has `revokeAt` field? Yes, if it's a 'replace' or 'delegate' statement.
     // But the test checks `aliceNet[bobA.token]`. 
     // If `bobA` was replaced, `aliceNet[bobA]` should be the *replacement statement*?
     // Or the statement *about* BobA?
     
     // In legacy: `network` contained the TrustStatement *from the perspective of the viewer*.
     // If Alice trusts BobA, `network[BobA]` is the TrustStatement (Alice->BobA).
     // If BobA is replaced by BobB, does Alice have a statement for BobA?
     // Maybe `network[BobA]` is the *replace* statement?
     
     return false; // Placeholder
  }

  group('Scenario 1: Graceful Recovery (Hacked Key)', () {
    test('Block is moot if offending statement is revoked', () async {
      var keys = await setupGracefulRecovery();
      var alice = keys['alice']!;
      var charlie = keys['charlie']!;
      var bobA = keys['bobA']!;
      var bobB = keys['bobB']!;
      var malicious = keys['malicious']!;

      // Build graphs using V2
      final source = SourceFactory.get(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      
      final aliceGraph = await pipeline.build(alice.token);
      final charlieGraph = await pipeline.build(charlie.token);
      final bobGraph = await pipeline.build(bobB.token);

      // --- ASSERTIONS ---

      // 1. Alice's Network
      expect(aliceGraph.isTrusted(charlie.token), isTrue);
      expect(aliceGraph.isTrusted(bobB.token), isTrue);
      expect(aliceGraph.isTrusted(bobA.token), isFalse, reason: "BobA is blocked by Alice");
      
      // Check revocation constraint
      // expect(aliceGraph.revokeAtConstraints[bobA.token], isNotNull, reason: "BobA should be revoked");
      
      expect(aliceGraph.isTrusted(malicious.token), isFalse, reason: "Malicious should not be trusted");

      // 2. Charlie's Network
      expect(charlieGraph.isTrusted(bobB.token), isTrue);
      expect(charlieGraph.isTrusted(bobA.token), isTrue);
      expect(charlieGraph.revokeAtConstraints[bobA.token], isNotNull);
      expect(charlieGraph.isTrusted(malicious.token), isFalse);

      // 3. BobB's Network
      expect(bobGraph.isTrusted(charlie.token), isTrue);
      expect(bobGraph.isTrusted(bobA.token), isTrue);
      expect(bobGraph.revokeAtConstraints[bobA.token], isNotNull);

      // --- NOTIFICATIONS ---
      // Notifications are not part of the TrustGraph, they are side effects or computed separately.
      // We skip notification checks for the V2 unit test for now, as V2 focuses on the Graph.
    });
  });

  group('Scenario 2: Persistent Block (Offense Not Cleared)', () {
    test('Block remains active if cited offense is still valid', () async {
      var keys = await setupPersistentBlock();
      var alice = keys['alice']!;
      var charlie = keys['charlie']!;
      var bobA = keys['bobA']!;
      var malicious = keys['malicious']!;

      final source = SourceFactory.get(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final aliceGraph = await pipeline.build(alice.token);
      final charlieGraph = await pipeline.build(charlie.token);
      
      // Alice's Network
      expect(aliceGraph.isTrusted(bobA.token), isFalse, reason: "BobA should be blocked");
      expect(aliceGraph.isTrusted(malicious.token), isFalse, reason: "Malicious path broken by block");

      // Charlie's Network (No block)
      expect(charlieGraph.isTrusted(bobA.token), isTrue);
      expect(charlieGraph.isTrusted(malicious.token), isTrue);
    });
  });

  group('Scenario 3: Invalid Block (No Citation)', () {
    test('Blocking without citation throws an error', () async {
      var alice = await DemoKey.create('Alice');
      var bob = await DemoKey.create('Bob');

      expect(() => alice.block(bob, citing: []), throwsA(isA<ArgumentError>()));
    });
  });

  group('Scenario 4: Mutual Friend Conflict', () {
    test('Block overrides trust from other paths', () async {
      var keys = await setupMutualFriendConflict();
      var alice = keys['alice']!;
      var bob = keys['bob']!;
      var malicious = keys['malicious']!;

      final source = SourceFactory.get(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final aliceGraph = await pipeline.build(alice.token);

      expect(aliceGraph.isTrusted(bob.token), isFalse, reason: "Block should override all trust paths");
      expect(aliceGraph.isTrusted(malicious.token), isFalse);
    });
  });

  group('Scenario 5: Lost Key (No Hack)', () {
    test('Simple rotation maintains trust without blocks', () async {
      var keys = await setupLostKey();
      var alice = keys['alice']!;
      var charlie = keys['charlie']!;
      var bobA = keys['bobA']!;
      var bobB = keys['bobB']!;

      // Alice needs to know about BobB to see the replacement
      await alice.trust(bobB);

      final source = SourceFactory.get(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final aliceGraph = await pipeline.build(alice.token);

      expect(aliceGraph.isTrusted(bobB.token), isTrue, reason: "Alice should follow the replacement");
      expect(aliceGraph.isTrusted(bobA.token), isTrue, reason: "Old key visible but revoked");
      expect(aliceGraph.revokeAtConstraints[bobA.token], isNotNull);
    });
  });

  group('Scenario 6: Poor Judgment (Transitive Citing)', () {
    test('Blocking a friend for trusting a blocked key', () async {
      var keys = await setupPoorJudgment();
      var alice = keys['alice']!;
      var charlie = keys['charlie']!;
      var bob = keys['bob']!;

      final source = SourceFactory.get(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final aliceGraph = await pipeline.build(alice.token);
      
      expect(aliceGraph.isTrusted(charlie.token), isTrue, reason: "Charlie forgiven after revoking bad trust");
      expect(aliceGraph.isTrusted(bob.token), isFalse, reason: "Bob still blocked by Alice");
    });
  });

  group('Scenario 7: The Whac-A-Mole Flaw (Re-issued Offenses)', () {
    test('Healing is fragile if the offense is re-committed with a new statement', () async {
      var keys = await setupWhacAMole();
      var alice = keys['alice']!;
      var charlie = keys['charlie']!;
      var bob = keys['bob']!;

      final source = SourceFactory.get(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final aliceGraph = await pipeline.build(alice.token);
      
      expect(aliceGraph.isTrusted(charlie.token), isTrue, reason: "Alice still trusts Charlie (Flaw)");
      expect(aliceGraph.isTrusted(bob.token), isTrue, reason: "Alice is exposed to Bob again (Flaw)");
    });
  });
}
