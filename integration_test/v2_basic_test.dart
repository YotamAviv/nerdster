import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/demotest/cases/v2_scenarios.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/cloud_functions_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/endpoint.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/main.dart';

import 'package:nerdster/demotest/demo_key.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    DemoKey.clear();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await OneofusFire.init();

    // Connect to Emulators
    fireChoice = FireChoice.emulator;
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    OneofusFire.firestore.useFirestoreEmulator('localhost', 8081);

    // Configure V2 for Emulator
    const host = 'localhost'; 
    const oneofusUrl = 'http://$host:5002/one-of-us-net/us-central1/export';
    const nerdsterUrl = 'http://$host:5001/nerdster/us-central1/export';
    
    V2Config.registerUrl(kOneofusDomain, oneofusUrl);
    V2Config.registerUrl(kNerdsterDomain, nerdsterUrl);

    // Configure Fetcher Endpoints (Legacy/V1 support needed for DemoKey)
    Fetcher.initEndpoint(kOneofusDomain,
        const Endpoint('http', '127.0.0.1', 'one-of-us-net/us-central1/export', port: 5002));
    Fetcher.initEndpoint(kNerdsterDomain,
        const Endpoint('http', '127.0.0.1', 'nerdster/us-central1/export', port: 5001));

    // Initialize Statements
    TrustStatement.init();
    ContentStatement.init();

    // Register FireFactory
    FireFactory.register(kOneofusDomain, OneofusFire.firestore, null);
    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, null);
  });

  testWidgets('V2 Integration: Basic Scenario', (WidgetTester tester) async {
    try {
      debugPrint('Running Basic Scenario Setup...');
      await basicScenario();
      final marge = DemoKey.findByName('marge')!;
      final lisa = DemoKey.findByName('lisa')!;
      final bart = DemoKey.findByName('bart')!;

      debugPrint('Setup complete. Waiting 2 seconds for consistency...');
      await Future.delayed(const Duration(seconds: 2));

      // Define permutations to test
      final permutations = [
        (name: 'No Optimization', omit: null),
        (name: 'Full Optimization', omit: ['statement', 'I']),
        (name: 'Omit Statement Only', omit: ['statement']),
        (name: 'Omit I Only', omit: ['I']),
      ];

      for (final p in permutations) {
        debugPrint('\n--- Testing Permutation: ${p.name} ---');
        
        // Manually construct source to inject omit params
        final url = V2Config.getUrl(kOneofusDomain)!;
        final source = CloudFunctionsSource(
          baseUrl: url, 
          statementType: kOneofusType,
          omit: p.omit,
        );
        
        final pipeline = TrustPipeline(source);
        
        debugPrint('Building graph from Marge...');
        final graph = await pipeline.build(marge.token);

        debugPrint('Graph built. Node count: ${graph.distances.length}');
        debugPrint('Distances: ${graph.distances}');
        debugPrint('Is Lisa trusted? ${graph.isTrusted(lisa.token)}');
        debugPrint('Is Bart trusted? ${graph.isTrusted(bart.token)}');

        expect(graph.isTrusted(lisa.token), isTrue, reason: '[${p.name}] Marge should trust Lisa');
        expect(graph.distances[lisa.token], 1, reason: '[${p.name}] Lisa should be distance 1');

        expect(graph.isTrusted(bart.token), isTrue, reason: '[${p.name}] Marge should trust Bart');
        expect(graph.distances[bart.token], 1, reason: '[${p.name}] Bart should be distance 1');
        
        debugPrint('Permutation ${p.name} Verified!');
      }
      
      debugPrint('All Permutations Verified!');
    } catch (e, stack) {
      debugPrint('TEST FAILED WITH ERROR: $e');
      debugPrint('STACK TRACE: $stack');
      debugPrint('Waiting 5 minutes for debugging...');
      await Future.delayed(const Duration(minutes: 5));
      rethrow;
    }
  });
}
