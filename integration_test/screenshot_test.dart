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


    TrustStatement.init();
    ContentStatement.init();
  });

  Future<void> saveScreenshot(List<int> bytes, String name) async {
    try {
      // Use systemTemp so this works on Mac, Linux, Android, and iOS simulator.
      final dir = Directory('${Directory.systemTemp.path}/nerdster_screenshots');
      await dir.create(recursive: true);
      final file = File('${dir.path}/nerdster_screenshot_$name.png');
      await file.writeAsBytes(Uint8List.fromList(bytes));
      debugPrint('Screenshot saved: ${file.path}');
    } catch (e) {
      debugPrint('Failed to save screenshot $name: $e');
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

    // ── Screenshot 1: Sign-in screen (not yet signed in) ──────────────────
    await tester.pumpWidget(const app.NerdsterApp());

    // Let the post-frame callback for showDialog execute
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final s0 = await binding.takeScreenshot('00_sign_in');
    await saveScreenshot(s0, '00_sign_in');

    // ── Sign in programmatically ──────────────────────────────────────────
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

    // ── Screenshot 2: Content feed ─────────────────────────────────────────
    final s1 = await binding.takeScreenshot('01_content_feed');
    await saveScreenshot(s1, '01_content_feed');

    // ── Screenshot 3: Filter drawer open ──────────────────────────────────
    final filterButton = find.byIcon(Icons.tune);
    if (filterButton.evaluate().isNotEmpty) {
      await tester.tap(filterButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    final s2 = await binding.takeScreenshot('02_filters_open');
    await saveScreenshot(s2, '02_filters_open');

    // Close filter drawer if open (tap back or outside)
    final NavigatorState? nav = app.navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      await tester.pumpAndSettle();
    }

    // ── Screenshot 4: First card "Show more" expanded ──────────────────────
    final showMoreBtn = find.widgetWithText(TextButton, 'Show more');
    if (showMoreBtn.evaluate().isNotEmpty) {
      await tester.tap(showMoreBtn.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    final s3 = await binding.takeScreenshot('03_card_expanded');
    await saveScreenshot(s3, '03_card_expanded');

    debugPrint('All screenshots captured in ${Directory.systemTemp.path}/nerdster_screenshots/');
  });
}
