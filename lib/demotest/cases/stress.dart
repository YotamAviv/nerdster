import 'dart:math';

import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

Future<(DemoIdentityKey, DemoDelegateKey?)> stress() async {
  useClock(TestClock());

  const int numKeys = 100;
  const int numTrusts = 400;
  const int numReplaces = 50;

  List<DemoIdentityKey> keys = <DemoIdentityKey>[];
  for (int i = 0; i < numKeys; i++) {
    keys.add(await DemoIdentityKey.findOrCreate('key$i'));
  }

  // make a delegate for each key
  // (mostly so that we have at least one statement per key for choosing at random later)
  Map<int, List<String>> index2statementTokens = {};
  for (int i = 0; i < numKeys; i++) {
    var delegateKey = await DemoDelegateKey.findOrCreate('key$i-nerdster');
    Statement s =
        await keys[i].delegate(delegateKey, comment: 'nerdster key', domain: kNerdsterDomain);
    index2statementTokens[i] = <String>[s.token];
  }

  for (int i = 0; i < numTrusts; i++) {
    int keyIndex = Random().nextInt(numKeys);
    int keyIndex2 = Random().nextInt(numKeys);
    if (keyIndex == keyIndex2) {
      keyIndex2 = (keyIndex2 + 1) % (numKeys);
    }
    Statement s = await keys[keyIndex].doTrust(TrustVerb.trust, keys[keyIndex2]);
    index2statementTokens[keyIndex]!.add(s.token);
  }

  for (int x = 0; x < numReplaces; x++) {
    int keyIndex = Random().nextInt(numKeys);
    int keyIndex2 = Random().nextInt(numKeys);
    if (keyIndex == keyIndex2) {
      keyIndex2 = (keyIndex2 + 1) % (numKeys);
    }
    int statementIndex = Random().nextInt(index2statementTokens[keyIndex2]!.length);
    await keys[keyIndex].doTrust(TrustVerb.replace, keys[keyIndex2],
        revokeAt: index2statementTokens[keyIndex2]![statementIndex]);
  }

  return (keys[0], null);
}
