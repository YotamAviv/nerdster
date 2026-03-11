import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nerdster/app.dart' as app;
import 'package:nerdster/bootstrap_sign_in.dart';
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/trust_statement.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await OneofusFire.init();

    // Connect to Emulators (same as other integration tests)
    fireChoice = FireChoice.emulator;
    final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    OneofusFire.firestore.useFirestoreEmulator(host, 8081);

    final oneofusUrl = 'http://$host:5002/one-of-us-net/us-central1/export';
    final nerdsterUrl = 'http://$host:5001/nerdster/us-central1/export';
    FirebaseConfig.registerUrl(kOneofusDomain, oneofusUrl);
    FirebaseConfig.registerUrl(kNerdsterDomain, nerdsterUrl);

    TrustStatement.init();
    ContentStatement.init();

    FireFactory.register(kOneofusDomain, OneofusFire.firestore, null);
    FireFactory.register(kNerdsterDomain, FirebaseFirestore.instance, null);
  });

  group('Bootstrap Mode Integration Tests', () {
    testWidgets('Bootstrap: signs in automatically and shows orange key icon',
        (WidgetTester tester) async {
      try {
        // Simulate what ?bootstrap=true does on startup: call bootstrapSignIn() directly.
        // (In real usage this is triggered from app.dart via the URL query param.)
        await bootstrapSignIn();

        expect(signInState.isSignedIn, isTrue,
            reason: 'Bootstrap should have signed in');
        expect(signInState.delegate, isNotNull,
            reason: 'Bootstrap should have a delegate key');
        expect(bootstrapLocalStatements.value.isNotEmpty, isTrue,
            reason: 'Bootstrap local statements should be injected');

        // Launch the app (already signed in)
        await tester.pumpWidget(const app.NerdsterApp());

        // Wait for the pipeline to run and UI to settle
        await tester.pumpAndSettle(const Duration(seconds: 10));

        // The orange key icon should be visible in the toolbar
        final orangeKeyFinder = find.byWidgetPredicate((widget) {
          return widget is Icon &&
              widget.icon == Icons.vpn_key &&
              widget.color == Colors.orange;
        });
        expect(orangeKeyFinder, findsOneWidget,
            reason: 'Bootstrap mode should show an orange key icon');

        debugPrint('Bootstrap test: orange key icon found ✓');
        debugPrint('Bootstrap test: signed in as ${signInState.identity}');
        debugPrint('Bootstrap test: delegate = ${signInState.delegate}');
        debugPrint('Bootstrap test: localStatements count = ${bootstrapLocalStatements.value.values.fold(0, (s, l) => s + l.length)}');

        // Tap the key icon — should show the Bootstrap Explanation Dialog (not sign-in dialog)
        await tester.tap(orangeKeyFinder);
        await tester.pumpAndSettle();

        expect(find.text('You are using a bootstrap identity.'), findsOneWidget,
            reason: 'Tapping orange key should show Bootstrap Explanation Dialog');

        debugPrint('Bootstrap test: explanation dialog shown ✓');

        // Dismiss the dialog
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();

        debugPrint('Bootstrap integration test passed ✓');
      } catch (e, stack) {
        debugPrint('BOOTSTRAP TEST FAILED: $e');
        debugPrint('STACK: $stack');
        await Future.delayed(const Duration(minutes: 5));
        rethrow;
      }
    });
  });
}
