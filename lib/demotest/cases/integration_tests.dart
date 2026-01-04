import 'package:nerdster/demotest/demo_key.dart';

import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:flutter_test/flutter_test.dart';

/// These are not necessary, but as it was easy, I figured why not test them against
/// FirebaseEmulator and Cloud Functions, if I want to, every once in a while..., right? But there
/// is no reason.
void integrationTests() async {
  // To restore Prefs changes
  late Map<Setting, dynamic> prefsSnapshot;
  tearDown(() {
    Prefs.restore(prefsSnapshot);
  });
  setUp(() {
    if (fireChoice == FireChoice.prod) throw 'not on production';
    prefsSnapshot = Prefs.snapshot();
    useClock(TestClock());
    DemoKey.reset();
  });

  // test('multipleBlocks', () async {
  //   await multipleBlocks();
  // });

  // test('trustBlockConflict', () async {
  //   await trustBlockConflict();
  // });

  // Only on [FakeFirebase]
  // test('egosCorrupt', () async {
  //   await egosCorrupt();
  // });
}
