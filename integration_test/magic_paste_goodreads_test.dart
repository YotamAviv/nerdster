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

  testWidgets('Integration: Magic Paste Goodreads Book', (WidgetTester tester) async {
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

    const goodreadsUrl = 'https://www.goodreads.com/book/show/131791.The_Deer_Park';
    
    print('Testing URL: $goodreadsUrl');
    final result = await metadata_service.magicPaste(goodreadsUrl);

    if (result == null) {
      fail('Magic Paste returned null for Goodreads URL.');
    }

    final contentType = result['contentType'] as String?;
    final title = result['title'] as String?;
    final author = result['author'] as String?;

    print('Magic Paste Result: contentType=$contentType, title=$title, author=$author');

    expect(contentType, equals('book'), reason: 'Should identify as a book');
    expect(title, equals('The Deer Park'), reason: 'Should extract the correct book title');
    expect(author, equals('Norman Mailer'), reason: 'Should extract the correct author');
  });
}
