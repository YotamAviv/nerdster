import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/logic/metadata_service.dart' as metadata_service;
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/firebase_options.dart';

/// Loads test cases from integration_test/magic_paste_cases.json.
/// Each case may have:
///   url (required), expectSuccess (required),
///   expectedContentType, expectedTitle, expectedYear, expectedAuthor (all optional),
///   note (optional, for documentation).
Future<List<Map<String, dynamic>>> loadCases() async {
  final raw = await rootBundle.loadString('integration_test/magic_paste_cases.json');
  final list = jsonDecode(raw) as List<dynamic>;
  return list.cast<Map<String, dynamic>>();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (useEmulator) {
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    }
    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);
  });

  testWidgets('Magic Paste: all cases', (WidgetTester tester) async {
    final cases = await loadCases();

    final requiredCases = cases.where((c) => c['expectSuccess'] == true).toList();
    final optionalCases = cases.where((c) => c['expectSuccess'] == false).toList();

    int requiredPassed = 0;

    // Run required cases
    for (final tc in requiredCases) {
      final url = tc['url'] as String;
      final note = tc['note'] as String? ?? '';
      print('\n--- Required case: $url${note.isNotEmpty ? ' ($note)' : ''} ---');

      final result = await metadata_service.magicPaste(url);
      if (result == null) {
        print('FAIL: magicPaste returned null');
        continue;
      }

      final contentType = result['contentType'] as String?;
      final title = result['title'] as String?;
      final year = result['year'] as String?;
      final author = result['author'] as String?;
      print('Result: contentType=$contentType, title=$title, year=$year, author=$author');

      bool passed = true;

      if (tc.containsKey('expectedContentType')) {
        if (contentType != tc['expectedContentType']) {
          print('FAIL: expectedContentType=${tc['expectedContentType']}, got=$contentType');
          passed = false;
        }
      }
      if (tc.containsKey('expectedTitle')) {
        if (title == null || !title.contains(tc['expectedTitle'] as String)) {
          print('FAIL: expectedTitle to contain "${tc['expectedTitle']}", got=$title');
          passed = false;
        }
      }
      if (tc.containsKey('expectedYear')) {
        if (year != tc['expectedYear']) {
          print('FAIL: expectedYear=${tc['expectedYear']}, got=$year');
          passed = false;
        }
      }
      if (tc.containsKey('expectedAuthor')) {
        if (author != tc['expectedAuthor']) {
          print('FAIL: expectedAuthor=${tc['expectedAuthor']}, got=$author');
          passed = false;
        }
      }

      if (passed) {
        print('PASS');
        requiredPassed++;
      }
    }

    // Run optional (expectSuccess: false) cases - logged but not counted
    for (final tc in optionalCases) {
      final url = tc['url'] as String;
      final note = tc['note'] as String? ?? '';
      print(
          '\n--- Optional case (expectSuccess=false): $url${note.isNotEmpty ? ' ($note)' : ''} ---');

      final result = await metadata_service.magicPaste(url);
      if (result == null) {
        print('Got null (expected to be unreliable)');
        continue;
      }

      final contentType = result['contentType'] as String?;
      final title = result['title'] as String?;
      print('Result: contentType=$contentType, title=$title');
    }

    // Assert all required cases passed
    print('\n=== Summary: $requiredPassed / ${requiredCases.length} required cases passed ===');
    expect(
      requiredPassed,
      equals(requiredCases.length),
      reason: '$requiredPassed of ${requiredCases.length} required magic paste cases passed.',
    );
  });
}
