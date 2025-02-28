import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/demotest/test_clock.dart';

/// This is to help debug the issues I encountered around test 
/// '3\'rd level replaces 1\'st level trust'.
/// CONSIDER: Maybe run the dfs that in the NerdNode test.
Future<(DemoKey, DemoKey?)> decap() async {
  useClock(TestClock());

  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey marge = await DemoKey.findOrCreate('marge');
  DemoKey homer2 = await DemoKey.findOrCreate('homer2');
  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey lenny = await DemoKey.findOrCreate('lenny');

  Statement s2 = await homer.doTrust(TrustVerb.trust, lenny);
  await bart.doTrust(TrustVerb.trust, homer);
  await homer.doTrust(TrustVerb.trust, marge);
  await marge.doTrust(TrustVerb.trust, lisa);
  await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token);
  await marge.doTrust(TrustVerb.trust, homer2);

  useClock(LiveClock());

  return (bart, null);
}

/// CONSIDER: NerdNode or NerdTreeNode issue: Consider: Maybe bart should not see both 
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
  Statement s2 = await homer.doTrust(TrustVerb.trust, marge);
  await marge.doTrust(TrustVerb.trust, lisa);
  await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token);
  await marge.doTrust(TrustVerb.trust, homer2);

  useClock(LiveClock());

  return (bart, null);
}

// I've lost track of why the other 2 above are called decap, but this is a true decapitation.
// Homer trust marge, who blocks him, and so her block counts even though it takes her out as well.
Future<(DemoKey, DemoKey?)> blockDecap() async {
  useClock(TestClock());

  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey marge = await DemoKey.findOrCreate('marge');
  DemoKey bart = await DemoKey.findOrCreate('bart');

  await bart.doTrust(TrustVerb.trust, homer);
  await homer.doTrust(TrustVerb.trust, marge);
  await marge.doTrust(TrustVerb.block, homer);


  useClock(LiveClock());

  return (bart, null);
}
