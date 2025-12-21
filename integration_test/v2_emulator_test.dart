import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/demotest/cases/v2_scenarios.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Connect to Emulators
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

    // Configure V2 for Emulator
    const host = 'localhost'; 
    const oneofusUrl = 'http://$host:5002/one-of-us-net/us-central1/export';
    const nerdsterUrl = 'http://$host:5001/nerdster/us-central1/export';
    
    V2Config.registerUrl(kOneofusDomain, oneofusUrl);
    V2Config.registerUrl(kNerdsterDomain, nerdsterUrl);
  });

  testWidgets('V2 Integration: Graceful Recovery Scenario', (WidgetTester tester) async {
    print('Running Graceful Recovery Setup...');
    final keys = await setupGracefulRecovery();
    final alice = keys['alice']!;
    final bobB = keys['bobB']!;
    final bobA = keys['bobA']!;
    final malicious = keys['malicious']!;

    print('Setup complete. Verifying with V2 Orchestrator...');

    final source = SourceFactory.get(kOneofusDomain);
    print('Using source: ${source.runtimeType}');

    final pipeline = TrustPipeline(source);
    
    print('Building graph from Alice...');
    final graph = await pipeline.build(alice.token);

    print('Verifying graph...');
    expect(graph.root, alice.token);
    
    // Verify Alice trusts BobB (the replacement)
    expect(graph.edges.containsKey(bobB.token), isTrue, reason: "Alice should trust BobB");
    
    // Verify BobA is present but likely has constraints (Orchestrator returns the raw graph, logic is in the reducer)
    // The graph structure in V2 might differ from legacy 'network' map.
    // TrustGraph contains 'graph' (adjacency list) and 'revokeAtConstraints'.
    
    expect(graph.edges.containsKey(bobA.token), isTrue, reason: "BobA should be in the graph (as replaced)");
    expect(graph.revokeAtConstraints[bobA.token], isNotNull, reason: "BobA should have a revokeAt constraint");
    
    // Verify Malicious is NOT in the graph (or at least not trusted/reachable in a valid way)
    // If the reducer works correctly, Malicious might be in the adjacency list of BobA, 
    // but since BobA is revoked-at-time-X, and Malicious was trusted AFTER time-X, 
    // the edge BobA->Malicious should be filtered out or marked invalid?
    // Actually, the reducer filters edges based on revokeAt.
    // So Malicious should NOT be in the adjacency list of BobA if the edge was revoked.
    // OR, Malicious is just not reachable.
    
    // Let's check if Malicious is in the graph keys at all.
    // If the edge BobA->Malicious is invalid, the BFS shouldn't traverse it (or should drop it).
    expect(graph.edges.containsKey(malicious.token), isFalse, reason: "Malicious should not be reachable");
    
    print('Success!');
  });
}
