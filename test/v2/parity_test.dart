import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/cases/trust_block_conflict.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:test/test.dart';

void main() {
  group('V2 Parity Tests', () {
    setUp(() {
      fireChoice = FireChoice.fake;
      FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
      FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
      TrustStatement.init();
      ContentStatement.init();
      DemoKey.clear(); // Ensure clean slate
    });

    test('Simpsons Demo Parity (Bart)', () async {
      // 1. Run the full Simpsons Demo setup
      await simpsonsDemo();
      
      // 2. Find Bart
      final bart = await DemoKey.findOrCreate('bart');
      final homer = await DemoKey.findOrCreate('homer');
      final homer2 = await DemoKey.findOrCreate('homer2');
      final sideshow = await DemoKey.findOrCreate('sideshow');
      final marge = await DemoKey.findOrCreate('marge');

            // 3. Run V2 Pipeline for Alice
      final source = DirectFirestoreSource(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final graph = await pipeline.build(alice.token);

      print('V2 Graph Stats: Nodes=${graph.distances.length}, Blocked=${graph.blocked.length}, Conflicts=${graph.conflicts.length}');
      for (var c in graph.conflicts) {
        print('Conflict: ${c.subject} -> ${c.reason}');
      }

      // 4. Assertions based on user report ("2 notifications for Bart")
      
      // Expectation 1: Sideshow Bob Conflict
      // Mel trusts Sideshow. Marge blocks Sideshow. Bart trusts both.
      final sideshowConflict = graph.conflicts.where((c) => c.subject == sideshow.token);
      expect(sideshowConflict, isNotEmpty, reason: 'Should have conflict for Sideshow Bob');
      expect(sideshowConflict.first.reason, contains('Attempt to trust blocked key'), reason: 'Mel tries to trust blocked Sideshow');

      // Expectation 2: Homer Replacement Conflict
      // Homer2 replaces Homer. Bart trusts Homer directly.
      final homerConflict = graph.conflicts.where((c) => c.subject == homer.token);
      expect(homerConflict, isNotEmpty, reason: 'Should have conflict for Homer');
      expect(homerConflict.first.reason, contains('Attempt to replace trusted key'), reason: 'Homer2 tries to replace trusted Homer');

      expect(graph.conflicts.length, equals(2), reason: 'Should have exactly 2 conflicts');
    });

    test('trustBlockConflict parity', () async {
      // 1. Run the V1 demo/test.
      // This populates the FakeFirestore and asserts V1 behavior (via jsonExpect inside the demo).
      // It leaves signInState.pov as Bart.
      final (bart, _) = await trustBlockConflict();

      // 2. Run V2 Pipeline for Bart
      final source = DirectFirestoreSource(kOneofusDomain);
      final pipeline = TrustPipeline(source);
      final graph = await pipeline.build(bart.token);

      // 3. Assert V2 matches V1 expectations
      // V1 Expectation for Bart:
      // network = { "Lisa": null, "Bart": null }; (Milhouse is missing/blocked)
      // rejected = { listTrustMilhouse.token: 'Attempt to trust blocked key.' }

      // Check Graph Membership
      // Bart trusts Lisa. Lisa trusts Milhouse. Bart blocks Milhouse.
      // Milhouse should be blocked.
      
      // Find tokens for names
      final lisaToken = (await DemoKey.findOrCreate('lisa')).token;
      final milhouseToken = (await DemoKey.findOrCreate('milhouse')).token;

      expect(graph.isTrusted(lisaToken), isTrue, reason: 'Bart should trust Lisa');
      expect(graph.isTrusted(milhouseToken), isFalse, reason: 'Bart should NOT trust Milhouse (Blocked)');
      expect(graph.blocked.contains(milhouseToken), isTrue, reason: 'Milhouse should be in blocked set');

      // Check Conflicts
      // Lisa trusts Milhouse, but Bart blocks Milhouse.
      // Since Bart trusts Lisa, Lisa's trust of Milhouse is visible.
      // But Bart blocks Milhouse.
      // This is "Attempt to trust blocked key" (Lisa trying to trust Milhouse, who is blocked by Bart).
      
      // Debug V1 state
      print('V1 Rejected: ${baseProblemCollector.rejected}');
      print('V1 Warned: ${baseProblemCollector.warned}');
      // Corrupted is private but we can infer if tests pass.
      
      expect(graph.conflicts, isNotEmpty, reason: 'Should have conflicts');
      
      print('Conflicts found: ${graph.conflicts.length}');
      for (var c in graph.conflicts) {
        print('Conflict: ${c.subject} -> ${c.reason}');
      }

      final conflict = graph.conflicts.firstWhere(
        (c) => c.subject == milhouseToken,
        orElse: () => throw Exception('No conflict found for Milhouse'),
      );

      expect(conflict.reason, contains('Attempt to trust blocked key'), reason: 'Reason should match V1 logic');
    });
  });
}
