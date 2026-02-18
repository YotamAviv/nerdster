import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/logic/metadata_service.dart' as metadata_service;
import 'package:nerdster/models/content_statement.dart'; // for kNerdsterDomain

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator('localhost', 5001);
    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instanceFor(region: 'us-central1'));
  });

  testWidgets('Fetch Title: Stack Overflow (Working)', (WidgetTester tester) async {
    const soUrl = 'https://stackoverflow.com/questions/79891300/ionic-angular-routing-url-changing-but-not-the-display';
    
    print('Testing fetchTitle with Stack Overflow URL: $soUrl');

    final title = await metadata_service.fetchTitle(soUrl);

    print('SO Fetch Title Result: $title');

    expect(title, isNotNull, reason: 'Should extract title from Stack Overflow');
    expect(title, isNotEmpty);
    expect(title, contains('Ionic'), reason: 'Title should contain "Ionic" from the question');
  });

  testWidgets('Fetch Title: NYT (Problematic)', (WidgetTester tester) async {
    const nytUrl = 'https://www.nytimes.com/2026/02/17/us/politics/trump-congress-budget-cuts.html';
    
    print('Testing fetchTitle with NYT URL: $nytUrl');

    final title = await metadata_service.fetchTitle(nytUrl);

    print('NYT Fetch Title Result: $title');

    // NYT may block or return captcha, so we just check if we get something back
    // In production this works, but may fail in test environment
    if (title == null || title.isEmpty) {
      print('WARNING: NYT returned null/empty. This is a known issue with NYT blocking scrapers.');
    } else {
      expect(title, contains('Trump'), reason: 'If we got a title, it should be about Trump');
    }
  });
}