import 'package:nerdster/demotest/cases/block_replaced_key.dart';
import 'package:nerdster/demotest/cases/equivalent_keys_state_conflict.dart';
import 'package:nerdster/demotest/cases/multiple_blocks.dart';
import 'package:nerdster/demotest/cases/trust_block_conflict.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:test/test.dart';

/// These are not necessary, but as it was easy, I figured why not test them against 
/// FirebaseEmulator and Cloud Functions, if I want to, every once in a while..., right? But there 
/// is no reason.
void integrationTests() async {
  setUp(() {
    assert(fireChoice != FireChoice.prod);
    useClock(TestClock());
    DemoKey.clear();
  });

  test('blockReplacedKey', () async {
    await blockReplacedKey();
  });

  test('equivalentKeysStateConflict', () async {
    await equivalentKeysStateConflict();
  });

  test('multipleBlocks', () async {
    await multipleBlocks();
  });

  test('trustBlockConflict', () async {
    await trustBlockConflict();
  });
}
