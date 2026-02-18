import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/logic/metadata_service.dart' as metadata_service;
import 'package:nerdster/models/content_statement.dart'; 
import 'package:nerdster/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Integration: Magic Paste with Robust Fallback', (WidgetTester tester) async {
    // Basic setup inside the test to ensure execution order
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (_) {}

    // Use localhost emulators
    try {
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    } catch (_) {}

    // Register with service layer
    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);

    // 1. Test NYT (known difficult site requiring robust fallback)
    const nytUrl = 'https://www.nytimes.com/2026/02/17/us/politics/trump-congress-budget-cuts.html';
    
    // Call the service method which calls the cloud function
    final result = await metadata_service.magicPaste(nytUrl);

    if (result == null) {
      fail('Magic Paste returned null. Check emulator logs.');
    }

    final title = result['title'] as String?;
    print('Magic Paste Result Title: $title');

    expect(title, isNotNull, reason: 'Should extract a title');
    expect(title, contains('Trump Sought Vast Budget Cuts'), reason: 'Should match the expected article title');
  });
}
