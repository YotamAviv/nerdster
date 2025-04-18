import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// Plan: Simpson public demmo
/// - DONE: Show statements.. TODO: Prefs.labelKeys
/// - cleaner story
///   TODO: Bart appears red, but there's no hint as to why.
/// - content
///   DONE: 
///   - lisa: ponies
///   - marge: recipes
///   - homer: bowling
///   - bart: skateboards
///   - milhouse: porn
///   MAYBE:
///   - sideshow?
///   - everyone else something..

Future<(DemoKey, DemoKey?)> simpsons2() async {
  useClock(TestClock(Duration(days: 1)));

  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey homer2 = await DemoKey.findOrCreate('homer2');
  DemoKey marge = await DemoKey.findOrCreate('marge');
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
  await homer.doTrust(TrustVerb.trust, marge, moniker: 'Wife');
  Statement s2 = await homer.doTrust(TrustVerb.trust, bart, moniker: 'Boy');
  await marge.doTrust(TrustVerb.trust, maggie, moniker: 'Baby');
  await marge.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await marge.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer2.doTrust(TrustVerb.replace, homer,
      comment: 'lost phone', revokeAt: s2.token); // homer replaces key
  await marge.doTrust(TrustVerb.trust, homer, moniker: 'Hubby');
  await bart.doTrust(TrustVerb.trust, marge, moniker: 'Moms');
  Statement s3 = await bart.doTrust(TrustVerb.trust, homer, moniker: 'Homer');
  await sideshow.doTrust(TrustVerb.replace, bart,
      revokeAt: s3.token); // Sideshow tries to thieve bart's key
  await bart.doTrust(TrustVerb.trust, homer2, moniker: 'Homer'); // bart trusts homer2
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Sis');
  await homer2.doTrust(TrustVerb.trust, lisa, moniker: 'Daughter');
  await lisa.doTrust(TrustVerb.trust, homer, moniker: 'Dad');
  await marge.doTrust(TrustVerb.trust, homer2, moniker: 'Hubby'); // marge trusts homer2
  await lisa.doTrust(TrustVerb.trust, marge, moniker: 'Mom');
  await bart.doTrust(TrustVerb.clear, homer); // bart clears homer
  await lisa.doTrust(TrustVerb.trust, maggie, moniker: 'Sister');
  await marge.doTrust(TrustVerb.clear, homer, moniker: 'Homer');

  // sideshow
  await sideshow.doTrust(TrustVerb.trust, mel, moniker: 'Mel');
  await sideshow.doTrust(TrustVerb.trust, milhouse, moniker: '4-Eyes');

  // work
  await homer.doTrust(TrustVerb.trust, lenny, moniker: 'colleague');
  await lenny.doTrust(TrustVerb.trust, carl, moniker: 'partner');
  await lenny.doTrust(TrustVerb.trust, homer, moniker: 'Homes');
  await carl.doTrust(TrustVerb.trust, lenny, moniker: 'partner');
  await carl.doTrust(TrustVerb.trust, burns, moniker: 'boss');
  await lenny.doTrust(TrustVerb.trust, burns, moniker: 'burns');
  await carl.doTrust(TrustVerb.trust, smithers, moniker: 'staff');
  
  // school
  await bart.doTrust(TrustVerb.trust, milhouse, moniker: 'Milhouse'); // This is after Sideshow..
  // TEMP: await milhouse.doTrust(TrustVerb.trust, bart, moniker: 'Bart'); // This is after Sideshow..
  await milhouse.doTrust(TrustVerb.trust, lisa, moniker: 'Babe');
  await milhouse.doTrust(TrustVerb.trust, luann, moniker: 'Mom');

  // milhouse->sideshow
  await milhouse.doTrust(TrustVerb.trust, sideshow, moniker: 'clown');

  // Submit something as each delegate
  List<DemoKey> delegates = [
    lisaN,
    bartN,
    milhouseN,
    homer2N,
    carlN,
    burnsN,
    margeN,
  ];
  const Json buck = {'contentType': 'movie', 'title': 'Buck', 'year': '2001'};
  const Json dogtown = {'contentType': 'movie', 'title': 'Dogtown and Z-Boys', 'year': '2001'};
  const Json porkys = {'contentType': 'movie', 'title': "Porky's", 'year': '1981'};
  const Json banana = {
    'contentType': 'recipe',
    'title': "Banana Banana Bread Recipe (with Video)",
    'url': 'https://www.allrecipes.com/recipe/20144/banana-banana-bread/'
  };
  const Json kingpin = {'contentType': 'movie', 'title': "Kingpin", 'year': '1996'};

  await lisaN.doRate(subject: buck, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: dogtown, recommend: true, verb: ContentVerb.rate);
  await milhouseN.doRate(subject: porkys, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: porkys, comment: 'rad', verb: ContentVerb.rate);
  await margeN.doRate(subject: porkys, verb: ContentVerb.censor);
  await margeN.doRate(subject: banana, recommend: true, verb: ContentVerb.rate);
  await homer2N.doRate(subject: kingpin, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: porkys, comment: 'rad', verb: ContentVerb.rate);
  await bartN.doRate(subject: buck, dismiss: true, verb: ContentVerb.rate);

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

  return (lisa, lisaN);
}
