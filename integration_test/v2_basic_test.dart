import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/v2/cloud_functions_source.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/endpoint.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/main.dart';

import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/v2_verification.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    DemoKey.reset();
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
        final source = CloudFunctionsSource<TrustStatement>(
          baseUrl: url, 
          omit: p.omit,
        );
        
        await testBasicScenario(source: source, description: p.name);
        
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
