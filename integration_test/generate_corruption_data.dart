import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/oneofus/endpoint.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/v2/config.dart';

/// [Aviv, the human]: I tested corruption detection manually and it worked.
/// TODO: Automate this after V2 

/// This is NOT a standard test. It is a data generation script.
///
/// Purpose:
/// Generate a known state in the Firestore Emulator:
/// 1. Identity Key -> Delegate Key (Trust/Delegate statement)
/// 2. Delegate Key -> 3 Ratings (Content statements)
///
/// Usage:
/// 1. Ensure Emulators are running: `firebase emulators:start`
/// 2. Run this script:
///    `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/generate_corruption_data.dart -d chrome`
///
/// Post-Run Instructions:
/// 1. Check the console output for the Identity Key Token and Delegate Key Token.
/// 2. Open the Firestore Emulator UI (usually http://localhost:4000/firestore).
/// 3. Locate the statements created by these keys.
/// 4. Manually corrupt the data to simulate:
///    - Invalid Signature: Edit a statement's JSON but leave the signature as is.
///    - Broken Notary Chain: Delete or modify the delegation statement so the chain is broken.
/// 5. Use the printed tokens in real tests to verify corruption detection.

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

    // Configure Fetcher Endpoints
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

  testWidgets('Generate Corruption Data', (WidgetTester tester) async {
    debugPrint('\n=== GENERATING CORRUPTION DATA ===\n');

    // 1. Create Keys
    final identity = await DemoKey.create('identity_user');
    final delegateKey = await DemoKey.create('delegate_key');

    debugPrint('Identity Key Created: ${identity.name}');
    debugPrint('Delegate Key Created: ${delegateKey.name}');

    // 2. Associate Identity -> Delegate
    debugPrint('Creating Delegation Statement...');
    await identity.delegate(delegateKey, domain: kNerdsterDomain, comment: 'Delegating for corruption test');

    // 3. Create 3 Ratings using Delegate Key
    debugPrint('Creating 3 Ratings...');
    await delegateKey.doRate(
      subject: {'contentType': 'movie', 'title': 'The Matrix', 'url': 'imdb.com/matrix'},
      recommend: true,
      comment: 'Rating 1: Good',
    );
    await delegateKey.doRate(
      subject: {'contentType': 'movie', 'title': 'The Room', 'url': 'imdb.com/room'},
      recommend: false,
      comment: 'Rating 2: Bad',
    );
    await delegateKey.doRate(
      subject: {'contentType': 'movie', 'title': 'Inception', 'url': 'imdb.com/inception'},
      recommend: true,
      comment: 'Rating 3: Great',
    );

    // 4. Print Keys and Tokens
    debugPrint('\n=== DATA GENERATION COMPLETE ===');
    debugPrint('---------------------------------------------------');
    debugPrint('Identity Key Token: ${identity.token}');
    debugPrint('Delegate Key Token: ${delegateKey.token}');
    debugPrint('---------------------------------------------------');
    debugPrint('Use these tokens to locate data in Firestore and for your hardcoded tests.');
    debugPrint('Waiting 10 seconds before exiting to ensure writes flush...');
    
    await Future.delayed(const Duration(seconds: 10));

    // 5. Report Data to Driver (to save to file)
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    binding.reportData ??= {};
    binding.reportData!['corruption_data'] = {
      'identityToken': identity.token,
      'delegateToken': delegateKey.token,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  });
}
