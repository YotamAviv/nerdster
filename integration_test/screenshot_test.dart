// App Store screenshot generator. Run with:
//   flutter test integration_test/screenshot_test.dart -d "iPhone 16 Pro Max"
//   flutter test integration_test/screenshot_test.dart -d "iPad Pro 13-inch (M4)"
//
// Retrieve screenshots from the simulator after the run:
//   find ~/Library/Developer/CoreSimulator/Devices -name "nerdster_screenshot_*.png" 2>/dev/null
//   find ~/Library/Developer/CoreSimulator/Devices -name "nerdster_screenshot_*.png" -exec cp {} ~/Desktop/ \;

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nerdster/app.dart' as app;
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/firebase_options.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/oneofus_fire.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/trust_statement.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Credentials from appStoreCredentials.json — identity with Lisa in network + delegate.
  const Map<String, dynamic> identityJson = {
    "crv": "Ed25519",
    "kty": "OKP",
    "x": "HK8iy7bH8ccq8zXxaKCeZxoZad7_4Y-7UIJn7UfJNvE"
  };
  const Map<String, dynamic> delegateJson = {
    "crv": "Ed25519",
    "d": "aqQQ8Uemm29IuP52iofBexLZvLH4C5KKXDpXps7_45M",
    "kty": "OKP",
    "x": "20c1w0tGrdwZgpVOA9S9AfCs9MQBBRVuOiNxYg7vO4A"
  };

  setUpAll(() async {
    fireChoice = FireChoice.prod;

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) rethrow;
    }
    await OneofusFire.init();

    FireFactory.register(
        kNerdsterDomain, FirebaseFirestore.instance, FirebaseFunctions.instance);
    FireFactory.register(kOneofusDomain, OneofusFire.firestore, OneofusFire.functions);

    const oneofusUrl = 'https://export.one-of-us.net';
    const nerdsterUrl = 'https://export.nerdster.org';
    FirebaseConfig.registerUrl(kOneofusDomain, oneofusUrl);
    FirebaseConfig.registerUrl(kNerdsterDomain, nerdsterUrl);

    TrustStatement.init();
    ContentStatement.init();
  });

  Future<void> saveScreenshot(List<int> bytes, String name) async {
    try {
      // Use /private/tmp which on the iOS simulator maps to the Mac host's /private/tmp,
      // accessible from the Mac terminal after the test completes.
      final dir = Directory('/private/tmp/nerdster_screenshots');
      await dir.create(recursive: true);
      final file = File('${dir.path}/nerdster_screenshot_$name.png');
      await file.writeAsBytes(Uint8List.fromList(bytes));
      debugPrint('Screenshot saved: ${file.path}');
    } catch (e) {
      debugPrint('Failed to save screenshot $name: $e');
    }
  }

  // Helper: dismiss any open dialog/sheet/route pushed on top of root.
  Future<void> dismissOverlay(WidgetTester tester) async {
    final NavigatorState? nav = app.navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
  }

  testWidgets('App Store screenshots', (WidgetTester tester) async {
    // Suppress non-fatal network image load errors (e.g. Wikipedia 429 rate-limits)
    // that would otherwise fail the test even though all screenshots are captured first.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('NetworkImageLoadException') || msg.contains('statusCode: 429')) {
        debugPrint('[screenshot_test] Suppressed image error: $msg');
        return;
      }
      originalOnError?.call(details);
    };

    // ── Screenshot 00: Sign-in screen (not yet signed in) ─────────────────
    await tester.pumpWidget(const app.NerdsterApp());

    // Let the post-frame callback for showDialog execute
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final s0 = await binding.takeScreenshot('00_sign_in');
    await saveScreenshot(s0, '00_sign_in');

    // ── Dismiss the sign-in dialog, then sign in programmatically ─────────
    await dismissOverlay(tester);

    final identityKey = await crypto.parsePublicKey(identityJson);
    final delegateKeyPair = await crypto.parseKeyPair(delegateJson);
    final identityToken = getToken(await identityKey.json);
    await signInState.signIn(identityToken, delegateKeyPair);

    // ── Wait for content to load from production ──────────────────────────
    // Pump generously — network round-trips to export functions may take seconds.
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    try {
      await tester.pumpAndSettle(const Duration(seconds: 5));
    } catch (_) {
      // pumpAndSettle may timeout if background listeners keep ticking — that's OK.
    }

    // ── Screenshot 01: Content feed ────────────────────────────────────────
    final s1 = await binding.takeScreenshot('01_content_feed');
    await saveScreenshot(s1, '01_content_feed');

    // ── Screenshot 02: Filter drawer open ─────────────────────────────────
    // The filter button is an InkWell containing Icons.tune.
    // Pump with explicit duration to let AnimatedSize (200ms) finish.
    final tuneIcon = find.byIcon(Icons.tune);
    if (tuneIcon.evaluate().isNotEmpty) {
      await tester.tap(tuneIcon.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    final s2 = await binding.takeScreenshot('02_filters_open');
    await saveScreenshot(s2, '02_filters_open');

    // Close filter drawer by tapping tune icon again
    if (tuneIcon.evaluate().isNotEmpty) {
      await tester.tap(tuneIcon.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    // ── Screenshot 03: Rate dialog ─────────────────────────────────────────
    // Tap the rate_review icon on the first card's action bar.
    final rateIcon = find.byIcon(Icons.rate_review_outlined);
    if (rateIcon.evaluate().isNotEmpty) {
      await tester.tap(rateIcon.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    final s3 = await binding.takeScreenshot('03_rate_dialog');
    await saveScreenshot(s3, '03_rate_dialog');
    await dismissOverlay(tester);

    // ── Screenshot 04: Graph view ──────────────────────────────────────────
    // Tap the first blue user-label (InkWell wrapping the iToken Text) in a
    // StatementTile to push NerdyGraphView onto the navigator.
    // The labels are blue underlined Text widgets inside InkWells.
    // We look for a Text with Colors.blue style that isn't a tag (#...).
    final userLabelFinder = find.byWidgetPredicate((widget) {
      if (widget is! Text) return false;
      final text = widget.data ?? '';
      if (text.startsWith('#') || text.isEmpty) return false;
      final style = widget.style;
      return style != null &&
          style.color == Colors.blue &&
          style.fontWeight == FontWeight.bold;
    });

    if (userLabelFinder.evaluate().isNotEmpty) {
      await tester.tap(userLabelFinder.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    final s4 = await binding.takeScreenshot('04_graph_view');
    await saveScreenshot(s4, '04_graph_view');
    await dismissOverlay(tester);

    debugPrint('All screenshots captured. Run:');
    debugPrint(
        '  cp /private/tmp/nerdster_screenshots/*.png ~/Desktop/nerdster_screenshots_iphone/');
  });
}
