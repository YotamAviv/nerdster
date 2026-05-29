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
    "x": "b-L2iq0eURr174i52nZx67sBrVTXXNfzQ9SFFNFbo2Q"
  };

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // On Android emulator, the host machine is 10.0.2.2, not localhost.
    final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);

    FirebaseConfig.registerRedirect('https://export.one-of-us.net', 'http://$host:5002/one-of-us-net/us-central1/export');
    FirebaseConfig.registerRedirect('https://export.nerdster.org', 'http://$host:5001/nerdster/us-central1/export');
    FirebaseConfig.registerRedirect('https://export.karennet.net', 'http://$host:5004/karennet/us-central1/export');
    FirebaseConfig.registerRedirect('https://us-central1-nerdster.cloudfunctions.net/seedNerdster', 'http://$host:5001/nerdster/us-central1/seedNerdster');

    // Initialize Statements
    TrustStatement.init();
    ContentStatement.init();
    DismissStatement.init();

    channelFactory = ChannelFactory(FireChoice.emulator);
    channelFactory.register('nerdster.org', firestore: FirebaseFirestore.instance);
    channelFactory.registerRedirect('https://export.nerdster.org', 'http://$host:5001/nerdster/us-central1/export');
    channelFactory.registerRedirect('https://write.nerdster.org', 'http://$host:5001/nerdster/us-central1/write2');
    channelFactory.registerRedirect('https://export.one-of-us.net', 'http://$host:5002/one-of-us-net/us-central1/export');
    channelFactory.registerRedirect('https://write.one-of-us.net', 'http://$host:5002/one-of-us-net/us-central1/write2');
    channelFactory.registerRedirect('https://export.karennet.net', 'http://$host:5004/karennet/us-central1/export');
  });

  group('UI Integration Tests', () {
    testWidgets('Verify ContentView loads and displays monikers', (WidgetTester tester) async {
        // Lisa's Identity from demoData.js
      final lisaToken = getToken(lisaIdentity);
      print('Signing in as Lisa: $lisaToken');

      // 2. Sign in before pumping the widget so hasPov is true from the start.
      //    This prevents the sign-in dialog from appearing during the test.
      await signInState.signInWithFedKey(FedKey(lisaIdentity), null);
      await tester.pumpWidget(const app.NerdsterApp());
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

      // All startup fetches must have been served from the seed bag — no network round-trips
      // beyond the single seedNerdster call. Any miss means the JS bag is incomplete.
      expect(channelFactory.seedBagMisses, isEmpty,
          reason: 'Bag misses: ${channelFactory.seedBagMisses}\nAll startup fetches must be served from the seed bag (1 round-trip goal)');

      // 4. Verify Monikers (Names)
      // Assuming the emulator has data where Lisa trusts someone named "Bart"
      // We can look for specific text that should be resolved by the Labeler.
      // If the labeler is working, we should see names, not tokens.
      final monikerFinder =
          find.textContaining(RegExp(r'^[A-Z][a-z]+')); // Look for capitalized names
      expect(monikerFinder, findsWidgets, reason: 'Should find human-readable names (monikers)');

      // 5. Verify Filter Controls
      // Filters are in the hamburger MenuAnchor. Open it and check for "Hide dismissed".
      final menuButton = find.byIcon(Icons.menu);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      final dismissFilterFinder = find.text('Hide dismissed');
      expect(dismissFilterFinder, findsOneWidget);

      // 6. Verify History/Comments are visible
      expect(find.byType(StatementTile), findsWidgets,
          reason: 'Should see StatementTiles (comments/ratings) directly on the card');
    });
  });
}
