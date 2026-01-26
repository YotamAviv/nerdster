import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/v2_verification.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/oneofus/endpoint.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/v2/cloud_functions_source.dart';
import 'package:nerdster/v2/config.dart';

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

    FirebaseConfig.registerUrl(kOneofusDomain, oneofusUrl);
    FirebaseConfig.registerUrl(kNerdsterDomain, nerdsterUrl);

    // Configure Fetcher Endpoints (Legacy/V1 support needed for DemoKey)
    // Fetcher.initEndpoint(kOneofusDomain,
    //    const Endpoint('http', '127.0.0.1', 'one-of-us-net/us-central1/export', port: 5002));
    // Fetcher.initEndpoint(kNerdsterDomain,
    //    const Endpoint('http', '127.0.0.1', 'nerdster/us-central1/export', port: 5001));

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
      final List<({String name, Map<String, dynamic>? params})> permutations = [
        (name: 'Default', params: null),
        (name: 'No Optimization', params: {'omit': []}),
        (
          name: 'Full Optimization',
          params: {
            'omit': ['statement', 'I']
          }
        ),
        (
          name: 'Omit Statement Only',
          params: {
            'omit': ['statement']
          }
        ),
        (
          name: 'Omit I Only',
          params: {
            'omit': ['I']
          }
        ),
        (name: 'Check Previous True', params: {'checkPrevious': 'true'}),
        (name: 'Check Previous False', params: {'checkPrevious': 'false'}),
      ];

      for (final skipVerify in [true, false]) {
        Setting.get<bool>(SettingType.skipVerify).value = skipVerify;
        debugPrint('\n=== Testing with skipVerify: $skipVerify ===');

        for (final p in permutations) {
          debugPrint('\n--- Testing Permutation: ${p.name} (skipVerify: $skipVerify) ---');

          // Manually construct source to inject params
          final url = FirebaseConfig.getUrl(kOneofusDomain)!;
          final source = CloudFunctionsSource<TrustStatement>(
            baseUrl: url,
            paramsOverride: p.params,
            verifier: OouVerifier(),
          );

          await basicScenario(
              source: source, description: '${p.name} (skipVerify: $skipVerify)');

          debugPrint('Permutation ${p.name} Verified!');
        }
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
