import 'dart:math';

import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

Future<(DemoKey, DemoKey?)> stress() async {
  useClock(TestClock());

  const int numKeys = 100;
  const int numTrusts = 400;
  const int numReplaces = 50;

  List<DemoKey> keys = <DemoKey>[];
  for (int i = 0; i < numKeys; i++) {
    keys.add(await DemoKey.findOrCreate('key$i'));
  }

  // make a delegate for each key 
  // (mostly so that we have at least one statement per key for choosing at random later)
  Map<int, List<String>> index2statementTokens = {};
  for (int i = 0; i < numKeys; i++) {
    Jsonish s = await keys[i].doTrust(TrustVerb.delegate,
        await DemoKey.findOrCreate('key$i-nerdster'),
        comment: 'nerdster key', domain: kNerdsterDomain);
    index2statementTokens[i] = <String>[s.token];
  }

  for (int i = 0; i < numTrusts; i++) {
    int keyIndex = Random().nextInt(numKeys);
    int keyIndex2 = Random().nextInt(numKeys);
    if (keyIndex == keyIndex2) {
      keyIndex2 = (keyIndex2 + 1) % (numKeys);
    }
    Jsonish s = await keys[keyIndex].doTrust(TrustVerb.trust, keys[keyIndex2]);
    index2statementTokens[keyIndex]!.add(s.token);
  }

  for (int keyIndex = 0; keyIndex < numReplaces; keyIndex++) {
    int keyIndex = Random().nextInt(numKeys);
    int keyIndex2 = Random().nextInt(numKeys);
    if (keyIndex == keyIndex2) {
      keyIndex2 = (keyIndex2 + 1) % (numKeys);
    }
    int statementIndex = Random().nextInt(index2statementTokens[keyIndex2]!.length);
    await keys[keyIndex].doTrust(TrustVerb.replace, keys[keyIndex2],
        revokeAt: index2statementTokens[keyIndex2]![statementIndex]);
  }

  useClock(LiveClock()); // DEFER: Get use of clock less error prone.
  
  return (keys[0], null);
}
