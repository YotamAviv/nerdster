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

  testWidgets('Integration: Fetch Title (Old Logic) Live Check', (WidgetTester tester) async {
    const nytUrl = 'https://www.nytimes.com/2026/02/17/us/politics/trump-congress-budget-cuts.html';
    
    print('Testing fetchTitle (old logic) against emulator with URL: $nytUrl');

    final title = await metadata_service.fetchTitle(nytUrl);

    print('Fetch Title Result: $title');

    if (title == null) {
      fail('Fetch Title returned null. The old logic is broken too!');
    }

    expect(title, isNotNull, reason: 'Should extract a title using the old scraper');
    expect(title, isNotEmpty);
  });
}