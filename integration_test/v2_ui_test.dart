import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nerdster/app.dart' as app;
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/content_card.dart';
import 'package:nerdster/v2/statement_tile.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/endpoint.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus_fire.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const lisaIdentity = {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "NOqGmF9lMMWEUL9lMWs0mZZM9BSybVplqvawUkLbwOs"
  };

  setUpAll(() async {
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

  group('V2 UI Integration Tests', () {
    testWidgets('Verify ContentView loads and displays monikers', (WidgetTester tester) async {
      // 1. Setup environment for Emulator
      fireChoice = FireChoice.emulator;

      // Lisa's Identity from demoData.js
      final lisaToken = getToken(lisaIdentity);
      print('Signing in as Lisa: $lisaToken');

      // 2. Start the app
      await signInState.signIn(lisaToken, null);
      print('Current POV: ${signInState.pov}');

      await tester.pumpWidget(const app.NerdsterApp());

      // Wait for the pipeline to run and UI to settle
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 3. Verify UI Components
      final contentCards = find.byType(ContentCard);
      expect(contentCards, findsWidgets, reason: 'Should display at least one ContentCard');

      final int cardCount = tester.widgetList(contentCards).length;
      print('Found $cardCount ContentCards');

      for (int i = 0; i < cardCount; i++) {
        final card = tester.widget<ContentCard>(contentCards.at(i));
        final title = (card.aggregation.subject is Map)
            ? (card.aggregation.subject['title'] ?? 'Untitled')
            : card.model.labeler.getLabel(card.aggregation.subject.toString());
        print('Card $i: Title="$title"');

        for (final s in card.aggregation.statements) {
          if (b(s.comment)) {
            final label = card.model.labeler.getLabel(s.iToken);
            print('  Comment by $label: ${s.comment}');
          }
        }
      }

      // 4. Verify Monikers (Names)
      // Assuming the emulator has data where Lisa trusts someone named "Bart"
      // We can look for specific text that should be resolved by the Labeler.
      // If the labeler is working, we should see names, not tokens.
      final monikerFinder =
          find.textContaining(RegExp(r'^[A-Z][a-z]+')); // Look for capitalized names
      expect(monikerFinder, findsWidgets, reason: 'Should find human-readable names (monikers)');

      // 5. Verify "Hide Seen" Toggle
      // The switch is now inside the filter drawer, which is hidden by default.
      // We need to open the drawer first.
      final filterButton = find.byIcon(Icons.tune);
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // 6. Verify History/Comments are visible
      // The new design shows comments by default (up to 2) without an expansion tile title "History"
      expect(find.byType(StatementTile), findsWidgets,
          reason: 'Should see StatementTiles (comments/ratings) directly on the card');
    });
  });
}
