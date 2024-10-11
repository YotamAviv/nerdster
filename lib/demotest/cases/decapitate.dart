import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/demotest/test_clock.dart';

/// This is to help debug the issues I encountered around test 
/// '3\'rd level replaces 1\'st level trust'.
/// TODO: Maybe run the dfs that in the NerdNode test.
Future<(DemoKey, DemoKey?)> decap() async {
  useClock(TestClock());

  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey marge = await DemoKey.findOrCreate('marge');
  DemoKey homer2 = await DemoKey.findOrCreate('homer2');
  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey lenny = await DemoKey.findOrCreate('lenny');

  Jsonish s2 = await homer.doTrust(TrustVerb.trust, lenny);
  await bart.doTrust(TrustVerb.trust, homer);
  await homer.doTrust(TrustVerb.trust, marge);
  await marge.doTrust(TrustVerb.trust, lisa);
  await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token);
  await marge.doTrust(TrustVerb.trust, homer2);

  useClock(LiveClock());

  return (bart, null);
}

/// TODO: NerdNode or NerdTreeNode issue: Consider: Maybe bart should not see both 
/// the old homer key and the homer EG which he doesn't trust directly as children.
/// Hmm...
/// - he should see that he trusts a replaced, non-canonical key directly.
/// - he does have web-of-trust to homer's EG, and the tooltip is correct 'Me->homer->marge->homer2'
Future<(DemoKey, DemoKey?)> decap2() async {
  useClock(TestClock());

  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey marge = await DemoKey.findOrCreate('marge');
  DemoKey homer2 = await DemoKey.findOrCreate('homer2');
  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey lenny = await DemoKey.findOrCreate('lenny');

  await homer.doTrust(TrustVerb.trust, lenny);
  await bart.doTrust(TrustVerb.trust, homer);
  Jsonish s2 = await homer.doTrust(TrustVerb.trust, marge);
  await marge.doTrust(TrustVerb.trust, lisa);
  await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token);
  await marge.doTrust(TrustVerb.trust, homer2);

  useClock(LiveClock());

  return (bart, null);
}
