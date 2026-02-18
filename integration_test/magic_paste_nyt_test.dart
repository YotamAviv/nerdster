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

  testWidgets('Integration: Magic Paste NYT Regression Check', (WidgetTester tester) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (_) {}

    try {
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    } catch (_) {}

    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);

    const nytUrl = 'https://www.nytimes.com/2026/02/17/us/politics/trump-congress-budget-cuts.html';
    
    print('Testing URL: $nytUrl');
    final result = await metadata_service.magicPaste(nytUrl);

    if (result == null) {
      fail('Magic Paste returned null for NYT URL. Regression detected?');
    }

    final title = result['title'] as String?;
    print('Magic Paste Result Title: $title');

    expect(title, isNotNull, reason: 'Should extract a title');
    // NYT titles usually contain the headline. Let's be lenient on exact string match but ensure it's not null/empty
    expect(title?.isNotEmpty, isTrue);
  });
}
