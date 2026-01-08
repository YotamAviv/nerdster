import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/follow_logic.dart';

/// Simpson public demo
/// - Lisa's view clean, no porn, no notifications
/// - Lisa: horses, Homer: bowling, .... Bart disses Lisa's content...
/// - Krusty bad actor, affects Milhouses view the most
/// - Marge censors Superbad
///
/// Demo:
/// - Lisa, looks fine
///   - no notificattions
///   - horses (Lisa), bowling, recipes, skateboards, alt movies
/// - Bart
///   - notifications:
///     - Nerdster remembers Lisa's initial sign in (<reset>), but Bart blocked for from <nerdster> follow netwok.
///     - Bart hasn't updated to Homer's new key
///     - Sideshow Mel trying to trust Sideshow Bob, who's already blocked
///   - movies only: clown, skateboarding, adult comedy
/// - Milhouse
///   - notifications
///     - Sideshow is trusted and is trying to block Marge
///     - Marge is trying to block Sideshow
///   - Milhouse called "4-Eyes"
///   - Clown movies have likes from bogus people: Seymore Butts, Amanda Hugginkiss.
///
///
/// History: The plan was to show this on PROD using FakeFirestore, but that doesn't work in production.
/// Since the demo will use data hosted on PROD, not FakeFirestore, I've decided to not
/// work to make it writeable by the demo'ing user (change follow contexts, submit, diss, etc..).
/// DEFER: Option to show statements like FakeFire which uses Prefs.labelKeys to show nice.

Future<(DemoKey, DemoKey?)> simpsonsDemo() async {
  useClock(TestClock(Duration(days: 1)));

  DemoIdentityKey lisa = await DemoIdentityKey.findOrCreate('lisa');
  DemoIdentityKey bart = await DemoIdentityKey.findOrCreate('bart');
  DemoIdentityKey homer = await DemoIdentityKey.findOrCreate('homer');
  DemoIdentityKey homer2 = await DemoIdentityKey.findOrCreate('homer2');
  DemoIdentityKey marge = await DemoIdentityKey.findOrCreate('marge');
  DemoIdentityKey maggie = await DemoIdentityKey.findOrCreate('maggie');

  DemoIdentityKey milhouse = await DemoIdentityKey.findOrCreate('milhouse');
  DemoIdentityKey luann = await DemoIdentityKey.findOrCreate('luann');
  DemoIdentityKey ralph = await DemoIdentityKey.findOrCreate('ralph');
  DemoIdentityKey nelson = await DemoIdentityKey.findOrCreate('nelson');

  DemoIdentityKey lenny = await DemoIdentityKey.findOrCreate('lenny');
  DemoIdentityKey carl = await DemoIdentityKey.findOrCreate('carl');
  DemoIdentityKey burns = await DemoIdentityKey.findOrCreate('burns');
  DemoIdentityKey smithers = await DemoIdentityKey.findOrCreate('smithers');

  DemoIdentityKey krusty = await DemoIdentityKey.findOrCreate('krusty');
  DemoIdentityKey sideshow = await DemoIdentityKey.findOrCreate('sideshow');
  DemoIdentityKey mel = await DemoIdentityKey.findOrCreate('mel');

  // Most trusts lisa
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer2.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await marge.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  // await milhouse.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await sideshow.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await maggie.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await lenny.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await carl.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await burns.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await smithers.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  // await luann.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await luann.doTrust(TrustVerb.trust, homer, moniker: 'Homer');
  // await mel.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');

  // most simpsons trust each other
  // - homer replaces his key
  // - keep Lisa to bart path long for no notifications
  await homer.doTrust(TrustVerb.trust, marge, moniker: 'Wife');
  Statement s2 = await homer.doTrust(TrustVerb.trust, bart, moniker: 'Boy');
  await marge.doTrust(TrustVerb.trust, maggie, moniker: 'Maggie');
  await marge.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await marge.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer2.doTrust(TrustVerb.replace, homer,
      comment: 'lost phone', revokeAt: s2.token, export: 'homer-replace-key'); // homer replaces key
  await marge.doTrust(TrustVerb.trust, homer, moniker: 'Hubby');
  // await bart.doTrust(TrustVerb.trust, marge, moniker: 'Moms');
  await bart.doTrust(TrustVerb.trust, homer, moniker: 'Homer');
  await lisa.doTrust(TrustVerb.trust, homer2, moniker: 'Homer'); // lisa trusts homer2
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Sis');
  await homer2.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  // await lisa.doTrust(TrustVerb.trust, homer, moniker: 'Dad');
  await lisa.doTrust(TrustVerb.trust, marge, moniker: 'Mom', export: 'lisa-trust-mom');
  // await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await lisa.doTrust(TrustVerb.trust, maggie, moniker: 'Maggie');
  await marge.doTrust(TrustVerb.trust, homer2, moniker: 'Hubby'); // marge trusts homer2
  // await bart.doTrust(TrustVerb.clear, homer); // bart clears homer
  // await marge.doTrust(TrustVerb.clear, homer);

  // sideshow...
  // - make Milhouse be labeled 4-Eyes from his own PoV due to Sideshow... takes effort
  //   - path from mihouse to bart long
  // - bogus people (Amanda Hugginkiss...)
  await bart.doTrust(TrustVerb.trust, milhouse, moniker: 'Milhouse');
  await krusty.doTrust(TrustVerb.trust, mel, moniker: 'Mel');
  await mel.doTrust(TrustVerb.trust, sideshow, moniker: 'Sideshow');
  DemoIdentityKey seymore = await DemoIdentityKey.findOrCreate('seymore');
  DemoIdentityKey amanda = await DemoIdentityKey.findOrCreate('amanda');
  await sideshow.doTrust(TrustVerb.trust, mel, moniker: 'Mel');
  await sideshow.doTrust(TrustVerb.trust, milhouse, moniker: '4-Eyes');
  await sideshow.doTrust(TrustVerb.trust, amanda,
      moniker: 'Amanda Hugginkiss',
      export:
          'sideshow-trust-amanda'); // Yeah, yeah, looking for Amanda Huggenkiss. What else is new?
  await sideshow.doTrust(TrustVerb.trust, seymore,
      moniker: 'Seymore Butts'); // That doesn't sound like a real name
  await sideshow.doTrust(TrustVerb.block, marge, comment: 'Karen');

  // work
  await homer2.doTrust(TrustVerb.trust, lenny, moniker: 'Lenny');
  await homer2.doTrust(TrustVerb.trust, carl, moniker: 'Carl');
  await lenny.doTrust(TrustVerb.trust, carl, moniker: 'partner');
  await lenny.doTrust(TrustVerb.trust, homer, moniker: 'Holmes');
  await carl.doTrust(TrustVerb.trust, lenny, moniker: 'partner');
  await carl.doTrust(TrustVerb.trust, burns, moniker: 'boss');
  await lenny.doTrust(TrustVerb.trust, burns, moniker: 'Burns');
  await carl.doTrust(TrustVerb.trust, smithers, moniker: 'Smithers');

  // school
  await milhouse.doTrust(TrustVerb.trust, luann, moniker: 'Mom');
  await ralph.doTrust(TrustVerb.trust, nelson, moniker: 'Nelson');
  await nelson.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await milhouse.doTrust(TrustVerb.trust, ralph, moniker: 'Ralph');

  // milhouse->krusty, marge-x> sideshow
  await marge.doTrust(TrustVerb.block, sideshow,
      comment: 'Naughty! You vouched for ficticious names to rack up likes',
      export: 'marge-block-sideshow');
  await milhouse.doTrust(TrustVerb.trust, krusty, moniker: 'Krusty');

  DemoDelegateKey lisaN = await lisa.makeDelegate();
  DemoDelegateKey bartN = await bart.makeDelegate();
  DemoDelegateKey burnsN = await burns.makeDelegate();
  DemoDelegateKey homer2N = await homer2.makeDelegate();
  DemoDelegateKey milhouseN = await milhouse.makeDelegate();
  DemoDelegateKey carlN = await carl.makeDelegate();
  DemoDelegateKey smithersN = await smithers.makeDelegate();
  DemoDelegateKey margeN = await marge.makeDelegate(export: 'marge-delegate');

  DemoDelegateKey sideshowN = await sideshow.makeDelegate();
  DemoDelegateKey melN = await mel.makeDelegate();
  DemoDelegateKey amandaN = await amanda.makeDelegate();
  DemoDelegateKey seymoreN = await seymore.makeDelegate();

  await sideshow.delegate(margeN,
      domain: kNerdsterDomain, revokeAt: kSinceAlways, comment: 'Karen..', export: 'sideshow-revoke-marge-delegate');

  // Submit something as each delegate
  const Json brokeback = {'contentType': 'movie', 'title': "Brokeback Mountain", 'year': '2005'};
  const Json buck = {'contentType': 'movie', 'title': 'Buck', 'year': '2001'};
  const Json dogtown = {'contentType': 'movie', 'title': 'Dogtown and Z-Boys', 'year': '2001'};
  const Json superbad = {'contentType': 'movie', 'title': "Superbad", 'year': '2007'};
  const Json banana = {
    'contentType': 'recipe',
    'title': "Banana Banana Bread Recipe (with Video)",
    'url': 'https://www.allrecipes.com/recipe/20144/banana-banana-bread/'
  };
  const Json kingpin = {'contentType': 'movie', 'title': "Kingpin", 'year': '1996'};
  const Json secretariat = {'contentType': 'movie', 'title': "Secretariat", 'year': '2010'};
  const Json shakes = {'contentType': 'movie', 'title': "Shakes the Clown", 'year': '1991'};
  const Json joker = {'contentType': 'movie', 'title': "Joker", 'year': '2019'};

  await smithersN.doRate(subject: brokeback, recommend: true);
  await carlN.doRate(subject: brokeback, recommend: true);
  await sideshowN.doRate(subject: brokeback, dismiss: true);
  await margeN.doRate(subject: brokeback, recommend: true, comment: '#horses');

  await lisaN.doRate(subject: buck, recommend: true, comment: 'instant #classic');
  await bartN.doRate(subject: dogtown, recommend: true, comment: 'instant #classic');
  await milhouseN.doRate(subject: superbad, recommend: true, comment: 'two thumbs way up');
  await bartN.doRate(subject: superbad, recommend: true, comment: '#rad #sick meisterpeace');
  await margeN.doRate(subject: getToken(superbad), censor: true, export: 'marge-censor-superbad');
  await margeN.doRate(
      subject: banana,
      recommend: true,
      comment: '#nutritious and #delicious',
      export: 'marge-banana-rate');
  await homer2N.doRate(subject: kingpin, recommend: true, comment: '#rad');
  await bartN.doRate(subject: buck, dismiss: true, recommend: false, comment: '#barf');
  // DEFER: Dissing should use the token, not the full subject.
  await bartN.doRate(subject: banana, dismiss: true, export: 'bart-diss-banana');
  await lisaN.doRate(subject: secretariat, recommend: true, comment: '#poignant #horses');
  await margeN.doRate(subject: secretariat, recommend: true);
  await carlN.doRate(subject: superbad, dismiss: true, comment: '#disgusting', recommend: false);

  await sideshowN.doRate(subject: joker, recommend: true, comment: 'instant #classic');
  await sideshowN.doRate(subject: shakes, recommend: true, comment: 'instant #classic');
  await melN.doRate(subject: joker, recommend: true, comment: 'instant #classic');
  await melN.doRate(subject: shakes, recommend: true, comment: 'instant #classic');
  await amandaN.doRate(subject: joker, recommend: true, comment: 'instant #classic');
  await amandaN.doRate(subject: shakes, recommend: true, comment: 'instant #classic');
  await seymoreN.doRate(subject: joker, recommend: true, comment: 'instant #classic');
  await seymoreN.doRate(subject: shakes, recommend: true, comment: 'instant #classic');

  // <nerdster>: bart blocks lisa, marge
  // <nerdster>: burns blocks multiple..
  // social: bart trusts milhouse, blocks lisa
  // nerd: bart trusts Milhouse, milhouse trusts lisa and bart.
  // family. lisa follows all family; there are other paths.
  await bartN.doFollow(milhouse, {'social': 1}, export: 'bart-follow-milhouse-social');
  await bartN.doFollow(lisa, {'family': 1, 'social': -1, kFollowContextNerdster: -1});
  await bartN.doFollow(homer, {'family': 1});
  await bartN.doFollow(marge, {kFollowContextNerdster: -1});
  await milhouseN.doFollow(bart, {'social': 1});
  await milhouseN.doFollow(lisa, {'social': 1});
  await lisaN.doFollow(bart, {'social': 1, 'family': 1});
  // await lisaN.doFollow(milhouse, {'social': 1, 'nerd': 1});
  await lisaN.doFollow(maggie, {'family': 1});
  await lisaN.doFollow(homer, {'family': 1});
  await lisaN.doFollow(marge, {'family': 1});
  // await homer2N.doFollow(marge, {'family': 1});
  await margeN.doFollow(lisa, {'family': 1});
  await margeN.doFollow(maggie, {'family': 1});
  await burnsN.doFollow(lisa, {kFollowContextNerdster: -1});
  await burnsN.doFollow(bart, {kFollowContextNerdster: -1});
  await burnsN.doFollow(marge, {kFollowContextNerdster: -1});
  await burnsN.doFollow(homer2, {kFollowContextNerdster: -1});

  useClock(LiveClock());

  return (lisa, lisaN);
}
