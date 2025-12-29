import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

Future<(DemoKey, DemoKey?)> largeGraph() async {
  useClock(TestClock());

  final DemoKey a = await DemoKey.findOrCreate('A');
  final DemoKey aN = await a.makeDelegate();
  
  // A trusts B1..B9
  final List<DemoKey> bKeys = [];
  for (int i = 1; i <= 9; i++) {
    final b = await DemoKey.findOrCreate('B$i');
    bKeys.add(b);
    await a.doTrust(TrustVerb.trust, b, moniker: 'B$i');
  }

  // B1 trusts C1..C9
  // B2 trusts C4..C14
  // ...
  // Bi trusts C(3*i-2) .. C(3*i+6)
  final Map<int, DemoKey> cKeys = {};
  for (int i = 1; i <= 9; i++) {
    final b = bKeys[i - 1];
    final start = 3 * i - 2;
    final end = 3 * i + 6;
    for (int j = start; j <= end; j++) {
      if (!cKeys.containsKey(j)) {
        cKeys[j] = await DemoKey.findOrCreate('C$j');
      }
      await b.doTrust(TrustVerb.trust, cKeys[j]!, moniker: 'C$j');
    }
  }

  // Add some blocks
  // B3 blocks C1 (conflict if A trusts B1 and B1 trusts C1)
  await bKeys[2].doTrust(TrustVerb.block, cKeys[1]!, comment: 'B3 dislikes C1');

  // Add some replaces
  // C5 is replaced by C5_new
  final c5 = cKeys[5]!;
  final c5new = await DemoKey.findOrCreate('C5_new');
  await c5new.doTrust(TrustVerb.replace, c5, comment: 'C5 lost key', revokeAt: c5.token);

  // B2 trusts C5_new
  await bKeys[1].doTrust(TrustVerb.trust, c5new, moniker: 'C5');

  // Add some follow statements to test Follow Mode
  for (var b in bKeys) {
    await aN.doFollow(b, {'large': 1});
    final bN = await b.makeDelegate();
    // Each B follows their C's
    final start = 3 * (bKeys.indexOf(b) + 1) - 2;
    final end = 3 * (bKeys.indexOf(b) + 1) + 6;
    for (int j = start; j <= end; j++) {
      await bN.doFollow(cKeys[j]!, {'large': 1});
    }
  }

  // Add a long chain for testing truncation
  // Root -> B1 -> L1 -> L2 -> L3 -> L4 -> L5
  final l1 = await DemoKey.findOrCreate('L1');
  final l2 = await DemoKey.findOrCreate('L2');
  final l3 = await DemoKey.findOrCreate('L3');
  final l4 = await DemoKey.findOrCreate('L4');
  final l5 = await DemoKey.findOrCreate('L5');

  await bKeys[0].doTrust(TrustVerb.trust, l1, moniker: 'L1');
  await l1.doTrust(TrustVerb.trust, l2, moniker: 'L2');
  await l2.doTrust(TrustVerb.trust, l3, moniker: 'L3');
  await l3.doTrust(TrustVerb.trust, l4, moniker: 'L4');
  await l4.doTrust(TrustVerb.trust, l5, moniker: 'L5');

  return (a, aN);
}
