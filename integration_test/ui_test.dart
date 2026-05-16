import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nerdster/app.dart' as app;
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/content_card.dart';
import 'package:nerdster/ui/statement_tile.dart';
import 'package:oneofus_common/keys.dart' show FedKey;
import 'package:oneofus_common/trust_statement.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const lisaIdentity = {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "RlaSqmVKIvafXNxqI3ir_4B9bf1XEaiZILE66iLbl4Y"
  };

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await OneofusFire.init();

    // On Android emulator, the host machine is 10.0.2.2, not localhost.
    final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    OneofusFire.firestore.useFirestoreEmulator(host, 8081);

    FirebaseConfig.registerRedirect('https://export.one-of-us.net', 'http://$host:5002/one-of-us-net/us-central1/export');
    FirebaseConfig.registerRedirect('https://export.nerdster.org', 'http://$host:5001/nerdster/us-central1/export');
    FirebaseConfig.registerRedirect('https://export.karennet.net', 'http://$host:5004/karennet/us-central1/export');

    // Initialize Statements
    TrustStatement.init();
    ContentStatement.init();
    DismissStatement.init();

    channelFactory = ChannelFactory(FireChoice.emulator);
    channelFactory.register(
        exportUrl: 'https://export.nerdster.org',
        functionsUrl: 'https://us-central1-nerdster.cloudfunctions.net',
        emulatorExportUrl: 'http://$host:5001/nerdster/us-central1/export',
        emulatorFunctionsUrl: 'http://$host:5001/nerdster/us-central1',
        firestore: FirebaseFirestore.instance);
    channelFactory.register(
        exportUrl: 'https://export.one-of-us.net',
        functionsUrl: 'https://us-central1-one-of-us-net.cloudfunctions.net',
        emulatorExportUrl: 'http://$host:5002/one-of-us-net/us-central1/export',
        emulatorFunctionsUrl: 'http://$host:5002/one-of-us-net/us-central1',
        firestore: OneofusFire.firestore);
    channelFactory.register(
        exportUrl: 'https://export.karennet.net',
        functionsUrl: 'https://us-central1-karennet-e4291.cloudfunctions.net',
        emulatorExportUrl: 'http://$host:5004/karennet/us-central1/export',
        emulatorFunctionsUrl: 'http://$host:5004/karennet/us-central1');
  });

  group('UI Integration Tests', () {
    testWidgets('Verify ContentView loads and displays monikers', (WidgetTester tester) async {
        // Lisa's Identity from demoData.js
      final lisaToken = getToken(lisaIdentity);
      print('Signing in as Lisa: $lisaToken');

      // 2. Start the app first so FeedController is created and listening,
      //    then sign in — this triggers _onSignInStateChanged → refresh().
      await tester.pumpWidget(const app.NerdsterApp());
      await signInState.signInWithFedKey(FedKey(lisaIdentity), null);
      print('Current POV: ${signInState.pov}');

      // Pump until ContentCards appear (pipeline + network fetches can take variable time).
      // Polling with pump() avoids pumpAndSettle's hard timeout and works even when
      // ongoing async work keeps the frame tree unsettled.
      const pollInterval = Duration(milliseconds: 500);
      const waitTimeout = Duration(seconds: 60);
      final deadline = DateTime.now().add(waitTimeout);
      while (find.byType(ContentCard).evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out after 60 s waiting for ContentCards to appear');
        }
        await tester.pump(pollInterval);
      }
      await tester.pump(const Duration(seconds: 1)); // let cards render fully

      // 3. Verify UI Components
      final contentCards = find.byType(ContentCard);
      expect(contentCards, findsWidgets, reason: 'Should display at least one ContentCard');

      final int cardCount = tester.widgetList(contentCards).length;
      print('Found $cardCount ContentCards');

      for (int i = 0; i < cardCount; i++) {
        final card = tester.widget<ContentCard>(contentCards.at(i));
        final title = card.aggregation.subject['title'] ?? 'Untitled';
        print('Card $i: Title="$title"');

        for (final s in card.aggregation.statements) {
          if (s.comment != null) {
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

      // 5. Verify Filter Controls
      // The filters are now inside the filter drawer, which is hidden by default.
      // We need to open the drawer first.
      final filterButton = find.byIcon(Icons.tune);
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      // Verify DisFilterMode control exists (Checkbox)
      final dismissFilterFinder = find.byTooltip("Hide content I've dismissed");
      expect(dismissFilterFinder, findsOneWidget);

      // 6. Verify History/Comments are visible
      // The new design shows comments by default (up to 2) without an expansion tile title "History"
      expect(find.byType(StatementTile), findsWidgets,
          reason: 'Should see StatementTiles (comments/ratings) directly on the card');
    });
  });
}
