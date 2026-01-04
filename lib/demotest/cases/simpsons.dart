import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';

// This was useful and remains in the tests. The "decentralized" demo Simpsons are in a different file.
Future<(DemoKey, DemoKey?)> simpsons() async {
  useClock(TestClock());

  final DemoKey lisa = await DemoKey.findOrCreate('lisa');
  final DemoKey bart = await DemoKey.findOrCreate('bart');
  final DemoKey homer = await DemoKey.findOrCreate('homer');
  final DemoKey marge = await DemoKey.findOrCreate('marge');
  final DemoKey homer2 = await DemoKey.findOrCreate('homer2');
  final DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  final DemoKey sideshow = await DemoKey.findOrCreate('sideshow');
  final DemoKey maggie = await DemoKey.findOrCreate('maggie');
  final DemoKey lenny = await DemoKey.findOrCreate('lenny');
  final DemoKey carl = await DemoKey.findOrCreate('carl');
  final DemoKey burns = await DemoKey.findOrCreate('burns');
  final DemoKey smithers = await DemoKey.findOrCreate('smithers');
  final DemoKey luann = await DemoKey.findOrCreate('luann');
  final DemoKey mel = await DemoKey.findOrCreate('mel');

  final DemoKey lisaN = await lisa.makeDelegate();
  final DemoKey bartN = await bart.makeDelegate();
  final DemoKey burnsN = await burns.makeDelegate();
  final DemoKey homer2N = await homer2.makeDelegate();
  final DemoKey milhouseN = await milhouse.makeDelegate();
  final DemoKey carlN = await carl.makeDelegate();
  final DemoKey margeN = await marge.makeDelegate();

  // most simpsons state trust in each other.
  await homer.doTrust(TrustVerb.trust, marge, moniker: 'wife');
  Statement s2 = await homer.doTrust(TrustVerb.trust, bart, moniker: 'boy');
  await marge.doTrust(TrustVerb.trust, maggie, moniker: 'baby');
  await marge.doTrust(TrustVerb.trust, bart, moniker: 'son');
  await marge.doTrust(TrustVerb.trust, lisa, moniker: 'daughter');
  await homer2.doTrust(TrustVerb.replace, homer,
      comment: 'lost phone', revokeAt: s2.token); // homer replaces key
  await marge.doTrust(TrustVerb.trust, homer, moniker: 'hubby');
  await bart.doTrust(TrustVerb.trust, marge, moniker: 'moms');
  Statement s3 = await bart.doTrust(TrustVerb.trust, homer, moniker: 'homer');
  
  // Sideshow tries to thieve bart's key
  await sideshow.doTrust(TrustVerb.replace, bart, revokeAt: s3.token);
  
  await bart.doTrust(TrustVerb.trust, homer2, moniker: 'homer2'); // bart trusts homer2
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'sis');
  await homer2.doTrust(TrustVerb.trust, lisa, moniker: 'daughter');
  await lisa.doTrust(TrustVerb.trust, homer, moniker: 'dad');
  await marge.doTrust(TrustVerb.trust, homer2, moniker: 'hubby2'); // marge trusts homer2
  await lisa.doTrust(TrustVerb.trust, marge, moniker: 'mom');
  await bart.doTrust(TrustVerb.clear, homer); // bart clears homer
  await lisa.doTrust(TrustVerb.trust, maggie, moniker: 'sister');
  await marge.doTrust(TrustVerb.clear, homer, moniker: 'homer'); // marge clears homer

  // sideshow
  await sideshow.doTrust(TrustVerb.trust, mel, moniker: 'mel'); // marge clears homer

  // work
  await homer.doTrust(TrustVerb.trust, lenny, moniker: 'colleague');
  await lenny.doTrust(TrustVerb.trust, carl, moniker: 'partner');
  await lenny.doTrust(TrustVerb.trust, homer, moniker: 'homer');
  await carl.doTrust(TrustVerb.trust, lenny, moniker: 'partner');
  await carl.doTrust(TrustVerb.trust, burns, moniker: 'boss');
  await lenny.doTrust(TrustVerb.trust, burns, moniker: 'boss');
  await carl.doTrust(TrustVerb.trust, smithers, moniker: 'staff');
  await carl.doTrust(TrustVerb.trust, burns, moniker: 'boss');

  // school
  await bart.doTrust(TrustVerb.trust, milhouse, moniker: 'friend');
  await milhouse.doTrust(TrustVerb.trust, lisa, moniker: 'babe');
  await milhouse.doTrust(TrustVerb.trust, luann, moniker: 'mom');

  // milhouse->sideshow
  await milhouse.doTrust(TrustVerb.trust, sideshow, moniker: 'clown');

  List<DemoKey> delegates = [
    bartN,
    lisaN,
    milhouseN,
    homer2N,
    carlN,
    burnsN,
    margeN,
  ];
  // Submit something as each delegate
  for (DemoKey delegate in delegates) {
    await delegate.doRate(title: delegate.name);
  }

  // <nerdster>: bart blocks lisa
  // social: bart trusts milhouse, blocks lisa
  // nerd: bart trusts Milhouse, milhouse trusts lisa and bart.
  // family. lisa follows all family; there are other paths.
  await bartN.doFollow(milhouse, {'nerd': 1, 'social': 1});
  await bartN.doFollow(lisa, {'family': 1, 'social': -1, kFollowContextNerdster: -1});
  await bartN.doFollow(homer, {'family': 1});
  await bartN.doFollow(marge, {kFollowContextNerdster: 1});
  await milhouseN.doFollow(bart, {'social': 1, 'nerd': 1});
  await milhouseN.doFollow(lisa, {kFollowContextNerdster: 1, 'nerd': 1});
  await lisaN.doFollow(bart, {'social': 1, 'family': 1});
  await lisaN.doFollow(milhouse, {'social': 1, 'nerd': 1});
  await lisaN.doFollow(maggie, {'family': 1});
  await lisaN.doFollow(homer, {'family': 1});
  await lisaN.doFollow(marge, {'family': 1});
  await homer2N.doFollow(marge, {'famigly': 1}); // homer mispells family. (for testing no follows)
  await margeN.doFollow(lisa, {'family': 1});
  await margeN.doFollow(maggie, {'family': 1});

  useClock(LiveClock());

  return (bart, bartN);
  // return (homer2, homer2N);
}
