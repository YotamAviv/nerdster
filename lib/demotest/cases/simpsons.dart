import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';

// This was useful and remains in the tests. The "decentralized" demo Simpsons are in a different file.
Future<(DemoIdentityKey, DemoDelegateKey?)> simpsons() async {
  useClock(TestClock());

  final DemoIdentityKey lisa = await DemoIdentityKey.findOrCreate('lisa');
  final DemoIdentityKey bart = await DemoIdentityKey.findOrCreate('bart');
  final DemoIdentityKey homer = await DemoIdentityKey.findOrCreate('homer');
  final DemoIdentityKey marge = await DemoIdentityKey.findOrCreate('marge');
  final DemoIdentityKey homer2 = await DemoIdentityKey.findOrCreate('homer2');
  final DemoIdentityKey milhouse = await DemoIdentityKey.findOrCreate('milhouse');
  final DemoIdentityKey sideshow = await DemoIdentityKey.findOrCreate('sideshow');
  final DemoIdentityKey maggie = await DemoIdentityKey.findOrCreate('maggie');
  final DemoIdentityKey lenny = await DemoIdentityKey.findOrCreate('lenny');
  final DemoIdentityKey carl = await DemoIdentityKey.findOrCreate('carl');
  final DemoIdentityKey burns = await DemoIdentityKey.findOrCreate('burns');
  final DemoIdentityKey smithers = await DemoIdentityKey.findOrCreate('smithers');
  final DemoIdentityKey luann = await DemoIdentityKey.findOrCreate('luann');
  final DemoIdentityKey mel = await DemoIdentityKey.findOrCreate('mel');

  final DemoDelegateKey lisaN = await lisa.makeDelegate();
  final DemoDelegateKey bartN = await bart.makeDelegate();
  final DemoDelegateKey burnsN = await burns.makeDelegate();
  final DemoDelegateKey homer2N = await homer2.makeDelegate();
  final DemoDelegateKey milhouseN = await milhouse.makeDelegate();
  final DemoDelegateKey carlN = await carl.makeDelegate();
  final DemoDelegateKey margeN = await marge.makeDelegate();

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

  List<DemoDelegateKey> delegates = [
    bartN,
    lisaN,
    milhouseN,
    homer2N,
    carlN,
    burnsN,
    margeN,
  ];
  // Submit something as each delegate
  for (DemoDelegateKey delegate in delegates) {
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
