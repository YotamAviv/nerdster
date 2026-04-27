import 'dart:math';

import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/clock.dart';

Future<(DemoIdentityKey, DemoDelegateKey?)> stress() async {
  useClock(TestClock());

  const int numKeys = 100;
  const int numTrusts = 400;
  const int numReplaces = 50;

  List<DemoIdentityKey> keys = <DemoIdentityKey>[];
  for (int i = 0; i < numKeys; i++) {
    keys.add(await DemoIdentityKey.findOrCreate('key$i'));
  }

  for (int i = 0; i < numKeys; i++) {
    var delegateKey = await DemoDelegateKey.findOrCreate('key$i-nerdster');
    await keys[i].delegate(delegateKey, comment: 'nerdster key', domain: kNerdsterDomain);
  }

  for (int i = 0; i < numTrusts; i++) {
    int keyIndex = Random().nextInt(numKeys);
    int keyIndex2 = Random().nextInt(numKeys);
    if (keyIndex == keyIndex2) {
      keyIndex2 = (keyIndex2 + 1) % (numKeys);
    }
    await keys[keyIndex].doTrust(TrustVerb.trust, keys[keyIndex2]);
  }

  for (int x = 0; x < numReplaces; x++) {
    int keyIndex = Random().nextInt(numKeys);
    int keyIndex2 = Random().nextInt(numKeys);
    if (keyIndex == keyIndex2) {
      keyIndex2 = (keyIndex2 + 1) % (numKeys);
    }
    await keys[keyIndex].doTrust(TrustVerb.replace, keys[keyIndex2],
        revokeAt: kSinceAlways);
  }

  return (keys[0], null);
}
