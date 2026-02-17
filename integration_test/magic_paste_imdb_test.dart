import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/logic/metadata_service.dart' as metadata_service;
import 'package:nerdster/models/content_statement.dart'; // Defines kNerdsterDomain
import 'package:nerdster/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Integration: Magic Paste with IMDb (Movie Detection)', (WidgetTester tester) async {
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

    // 1. Test IMDb (known problematic site requiring robust fallback/smart parsing)
    const imdbUrl = 'https://www.imdb.com/title/tt0133093/';
    
    // Call the service method which calls the cloud function
    final result = await metadata_service.magicPaste(imdbUrl);

    if (result == null) {
      fail('Magic Paste returned null. Check emulator logs.');
    }

    final contentType = result['contentType'] as String?;
    final title = result['title'] as String?;
    final year = result['year'] as String?;

    print('Magic Paste Result: contentType=$contentType, title=$title, year=$year');

    // Assertions based on "The Matrix (1999)"
    expect(contentType, equals('movie'), reason: 'Should identify as a movie');
    
    // Title should be CLEAN (without year or tagline) if parsed correctly
    expect(title, equals('The Matrix'), reason: 'Should extract clean title');
    
    // Year should be extracted separately
    expect(year, equals('1999'), reason: 'Should extract year');
  });
}
