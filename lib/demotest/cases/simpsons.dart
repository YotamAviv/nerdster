import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// Plan: Simpson public demmo
/// - DONE: Showing statements works. TODO: Prefs.labelKeys
/// - DONE: Sign in menu changes..
/// - cleaner story
///   - homer2?
/// - content
///   - lisa: ponies
///   - marge: recipes
///   - homer: bowling
///   - bart: skateboards
///   - milhouse: porn
///   - sideshow?
///   - everyone else something..
/// 
/// Demo mode?
/// ?demo=name or even anything
/// sign in menu changed
/// - includes dump credentials
/// - sign in or just center as any DemoKey oneofus / delegate

Future<(DemoKey, DemoKey?)> simpsons() async {
  useClock(TestClock());

  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey marge = await DemoKey.findOrCreate('marge');
  DemoKey homer2 = await DemoKey.findOrCreate('homer2');
  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  DemoKey sideshow = await DemoKey.findOrCreate('sideshow');
  DemoKey maggie = await DemoKey.findOrCreate('maggie');
  DemoKey lenny = await DemoKey.findOrCreate('lenny');
  DemoKey carl = await DemoKey.findOrCreate('carl');
  DemoKey burns = await DemoKey.findOrCreate('burns');
  DemoKey smithers = await DemoKey.findOrCreate('smithers');
  DemoKey luann = await DemoKey.findOrCreate('luann');
  DemoKey mel = await DemoKey.findOrCreate('mel');

  DemoKey lisaN = await lisa.makeDelegate();
  DemoKey bartN = await bart.makeDelegate();
  DemoKey burnsN = await burns.makeDelegate();
  DemoKey homer2N = await homer2.makeDelegate();
  DemoKey milhouseN = await milhouse.makeDelegate();
  DemoKey carlN = await carl.makeDelegate();
  DemoKey margeN = await marge.makeDelegate();

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
  await sideshow.doTrust(TrustVerb.replace, bart,
      revokeAt: s3.token); // Sideshow tries to thieve bart's key
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

  // Submit something as each delegate
  List<DemoKey> delegates = [
    bartN,
    lisaN,
    milhouseN,
    homer2N,
    carlN,
    burnsN,
    margeN,
  ];
  for (DemoKey delegate in delegates) {
    await delegate.doRate(title: delegate.name);
  }

  // social: bart trusts milhouse, blocks lisa
  // nerd: bart trusts Milhouse, milhouse trusts lisa and bart.
  // family. lisa follows all family; there are other paths.
  await bartN.doFollow(milhouse, {'nerd': 1, 'social': 1});
  await bartN.doFollow(lisa, {'family': 1, 'social': -1, kNerdsterContext: -1});
  await bartN.doFollow(homer, {'family': 1});
  await bartN.doFollow(marge, {kNerdsterContext: 1});
  await milhouseN.doFollow(bart, {'social': 1, 'nerd': 1});
  await milhouseN.doFollow(lisa, {kNerdsterContext: 1, 'nerd': 1});
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
