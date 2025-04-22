import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

/// Simpson public demo
/// - DEFER: Prefs.labelKeys checkbox on custom show statements dialog
/// - TODO: Export all credentials so that I can tweak later on PROD
///   No need: Hardcode the credentials so that I can delete from PROD and rewrite.
///
/// The plan was to show this on PROD using FakeFirestore, but that doesn't work in production, and
/// so some of the work on the demo sign-in menu is wasted.
/// Since the demo will use data hosted on PROD, not FakeFirestore, I've decided to not
/// work to make it writeable by the demo'ing user (change follow contexts, submit, diss, etc..).

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

  // Everyone trusts lisa (no dead ends)
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer2.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await marge.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await milhouse.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await sideshow.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa'); // DEFER: Try removing
  await maggie.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await lenny.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await carl.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await burns.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await smithers.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await luann.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await mel.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');

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
  await lisa.doTrust(TrustVerb.trust, marge, moniker: 'Mom');
  await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await lisa.doTrust(TrustVerb.trust, maggie, moniker: 'Maggie');
  await marge.doTrust(TrustVerb.trust, homer2, moniker: 'Hubby'); // marge trusts homer2
  await bart.doTrust(TrustVerb.clear, homer); // bart clears homer
  await marge.doTrust(TrustVerb.clear, homer, moniker: 'Homer');

  // sideshow
  await sideshow.doTrust(TrustVerb.trust, mel, moniker: 'Mel');
  await sideshow.doTrust(TrustVerb.trust, milhouse, moniker: '4-Eyes');
  await sideshow.doTrust(TrustVerb.trust, lenny,
      moniker: 'Hugh G. Reckshin'); // Well at least that's accurate
  await sideshow.doTrust(TrustVerb.trust, marge,
      moniker: 'Amanda Hugginkiss'); // Yeah, yeah, looking for Amanda Huggenkiss. What else is new?
  await sideshow.doTrust(TrustVerb.trust, homer, moniker: 'Dick Hurtz'); // Who's Dick Hurtz?
  await sideshow.doTrust(TrustVerb.trust, carl,
      moniker: 'Ben Dover'); // That doesn't sound like a real name

  await lisa.doTrust(TrustVerb.block, sideshow);

  // work
  await homer.doTrust(TrustVerb.trust, lenny, moniker: 'colleague');
  await lenny.doTrust(TrustVerb.trust, carl, moniker: 'partner');
  await lenny.doTrust(TrustVerb.trust, homer, moniker: 'Homes');
  await carl.doTrust(TrustVerb.trust, lenny, moniker: 'partner');
  await carl.doTrust(TrustVerb.trust, burns, moniker: 'boss');
  await lenny.doTrust(TrustVerb.trust, burns, moniker: 'burns');
  await carl.doTrust(TrustVerb.trust, smithers, moniker: 'staff');

  // school
  await bart.doTrust(TrustVerb.trust, milhouse, moniker: 'Milhouse');
  await milhouse.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await milhouse.doTrust(TrustVerb.trust, luann, moniker: 'Mom');

  // milhouse->sideshow
  await milhouse.doTrust(TrustVerb.trust, sideshow, moniker: 'Sideshow T. Clown');

  DemoKey lisaN = await lisa.makeDelegate();
  DemoKey bartN = await bart.makeDelegate();
  DemoKey burnsN = await burns.makeDelegate();
  DemoKey homer2N = await homer2.makeDelegate();
  DemoKey milhouseN = await milhouse.makeDelegate();
  DemoKey carlN = await carl.makeDelegate();
  DemoKey margeN = await marge.makeDelegate();
  DemoKey sideshowN = await sideshow.makeDelegate();

  // Submit something as each delegate
  const Json buck = {'contentType': 'movie', 'title': 'Buck', 'year': '2001'};
  const Json dogtown = {'contentType': 'movie', 'title': 'Dogtown and Z-Boys', 'year': '2001'};
  const Json porkys = {'contentType': 'movie', 'title': "Porky's", 'year': '1981'};
  const Json banana = {
    'contentType': 'recipe',
    'title': "Banana Banana Bread Recipe (with Video)",
    'url': 'https://www.allrecipes.com/recipe/20144/banana-banana-bread/'
  };
  const Json kingpin = {'contentType': 'movie', 'title': "Kingpin", 'year': '1996'};
  const Json secretariat = {'contentType': 'movie', 'title': "Secretariat", 'year': '2010'};
  const Json shakes = {'contentType': 'movie', 'title': "Shakes the Clown", 'year': '1991'};

  await lisaN.doRate(subject: buck, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: dogtown, recommend: true, verb: ContentVerb.rate);
  await milhouseN.doRate(subject: porkys, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: porkys, comment: 'rad', verb: ContentVerb.rate);
  await margeN.doRate(subject: porkys, verb: ContentVerb.censor);
  await margeN.doRate(subject: banana, recommend: true, verb: ContentVerb.rate);
  await homer2N.doRate(subject: kingpin, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: porkys, comment: 'rad', verb: ContentVerb.rate);
  await bartN.doRate(subject: buck, dismiss: true, verb: ContentVerb.rate);
  await lisaN.doRate(subject: secretariat, recommend: true, verb: ContentVerb.rate);
  await margeN.doRate(subject: secretariat, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: secretariat, comment: 'boring', verb: ContentVerb.rate);
  await carlN.doRate(
      subject: porkys, recommend: true, comment: 'disgusting', verb: ContentVerb.rate);
  await sideshowN.doRate(subject: shakes, recommend: true, verb: ContentVerb.rate);

  // social: bart trusts milhouse, blocks lisa
  // nerd: bart trusts Milhouse, milhouse trusts lisa and bart.
  // family. lisa follows all family; there are other paths.
  await bartN.doFollow(milhouse, {'social': 1});
  await bartN.doFollow(lisa, {'family': 1, 'social': -1, kNerdsterContext: -1});
  await bartN.doFollow(homer, {'family': 1});
  await bartN.doFollow(marge, {kNerdsterContext: -1});
  await milhouseN.doFollow(bart, {'social': 1});
  await milhouseN.doFollow(lisa, {'social': 1});
  await lisaN.doFollow(bart, {'social': 1, 'family': 1});
  // await lisaN.doFollow(milhouse, {'social': 1, 'nerd': 1});
  await lisaN.doFollow(maggie, {'family': 1});
  await lisaN.doFollow(homer, {'family': 1});
  await lisaN.doFollow(marge, {'family': 1, kNerdsterContext: -1});
  // await homer2N.doFollow(marge, {'family': 1});
  await margeN.doFollow(lisa, {'family': 1});
  await margeN.doFollow(maggie, {'family': 1});
  await burnsN.doFollow(lisa, {kNerdsterContext: -1});
  await burnsN.doFollow(bart, {kNerdsterContext: -1});
  await burnsN.doFollow(marge, {kNerdsterContext: -1});
  await burnsN.doFollow(homer2, {kNerdsterContext: -1});

  // Access with: &followNetDegrees=2&follow=<one-of-us>
  Prefs.followNetDegrees.value = 2;
  followNet.fcontext = '<one-of-us>';

  useClock(LiveClock());

  return (lisa, lisaN);
}



// 4/20/2025, created demo on prod
// from /etc => gen link..
// ?oneofus=%7B%22crv%22%3A%22Ed25519%22%2C%22kty%22%3A%22OKP%22%2C%22x%22%3A%22I-BKc0Dnenk0uQ_SfhJ9HSZnviG1yXLVLHaROnIpyQk%22%7D&follow=%3Cone-of-us%3E
// from DEV => dump demo credentials..
const _credentials = 
{
  "lisa": {
    "token": "a74fc1893a51476a00042d2ff925cba943c7ca65",
    "keyPair": {
      "crv": "Ed25519",
      "d": "HuUqhxhERY-Dcjvxcwp_CBTiunKIxO81lzRdRXB8agU",
      "kty": "OKP",
      "x": "I-BKc0Dnenk0uQ_SfhJ9HSZnviG1yXLVLHaROnIpyQk"
    }
  },
  "bart": {
    "token": "04440ff3a5df3d56e4d137f8eaf1b2ab149aa8df",
    "keyPair": {
      "crv": "Ed25519",
      "d": "uzlOon8jC_UBaKQtcQM9f6NnORlIropbc67bgFrh_LM",
      "kty": "OKP",
      "x": "gzqiur0Ri1y0MOEiISz4Hl67tZjR7N_6ViHHRYFKBVM"
    }
  },
  "homer": {
    "token": "a32618598a34435cf9b5aa005c3e6c7230baa26c",
    "keyPair": {
      "crv": "Ed25519",
      "d": "d8BMZAew1CJ-78IbO1nxsAHfdmwDtem6xw6tqV-mRLc",
      "kty": "OKP",
      "x": "mWXfUEx5NewA_NUuFzvw1dT1QWo29Lp0HyHc90sP924"
    }
  },
  "homer2": {
    "token": "e343e79b5c7bc2e17cb9029ed0340197eb45f547",
    "keyPair": {
      "crv": "Ed25519",
      "d": "UJ65P2Wg9dM7rp8Cb-BTWDiqC0ANsLGoH9yIVf6J37A",
      "kty": "OKP",
      "x": "5DtRxR0xB0LFiIqUw3W246jqWPEgY2eYA3T7-iI5z0U"
    }
  },
  "marge": {
    "token": "77e6d26dbe514f13c1ebb5b5de10692a4c1f4866",
    "keyPair": {
      "crv": "Ed25519",
      "d": "Yjx7QMnEgoZAOeH8vrfAFrnwist2YmAI9GsX-zKcz5w",
      "kty": "OKP",
      "x": "mKalXac6R42FI_xwgNOIRFSYfb0Z2iMC6kgnFRrRD14"
    }
  },
  "milhouse": {
    "token": "6a958d948c6bcaf9a7fb7e61291e14c713045bbb",
    "keyPair": {
      "crv": "Ed25519",
      "d": "farEe_ageqWNJbnq3WkKMC10inGak_O0qw_nFHX1qPs",
      "kty": "OKP",
      "x": "rebyF1bYMaFvXRsrWnIeBooyWP8opECIV5h0Nl-HCjM"
    }
  },
  "sideshow": {
    "token": "4521f6e65f23eb0354ea6f03f47acdf40f2d79ac",
    "keyPair": {
      "crv": "Ed25519",
      "d": "hPQyGh4ZKR31Ms51-YoMF87E_VeFwSPwqyRoGTBTey0",
      "kty": "OKP",
      "x": "ql1B9UsGvgm4fhyJUKc-upbfGmeyhnnei6WEJk-5up0"
    }
  },
  "maggie": {
    "token": "515c7800224202e1a8da64d6a4d91daae26e862e",
    "keyPair": {
      "crv": "Ed25519",
      "d": "HBHO_lMgw6G1brUyImAZ3XvmWmA1_-cRnmhLkj9VVGk",
      "kty": "OKP",
      "x": "Gp2t3wUwr3BNBl7d5JEIA-d2dqE5OHf47aJOd17L1bM"
    }
  },
  "lenny": {
    "token": "faa98e4b7587d1896eea731bf898a48eb4d406ba",
    "keyPair": {
      "crv": "Ed25519",
      "d": "-_s-pe-m0k5iD9bKcdGyWvze5SSsVPlIw6_l6eXnHgs",
      "kty": "OKP",
      "x": "mCVNAnu7eDpK9T4dQ4FYa-tk8gc3cRBTTbL3TjNbmeE"
    }
  },
  "carl": {
    "token": "dd1a44e24bba667827d74402129dc4027d185c79",
    "keyPair": {
      "crv": "Ed25519",
      "d": "oKHk2MpvHzTsmZqdDrylmZWA9GSkYpmig_i3BgJ1uQc",
      "kty": "OKP",
      "x": "EGvtqNF4ppXda5j5f-OlkAzUQ6OU1Y0-3jFf_d-rjSU"
    }
  },
  "burns": {
    "token": "9d4b36849adb3fa72ad8eddc0fdd0cfbaa64e6d7",
    "keyPair": {
      "crv": "Ed25519",
      "d": "62K8mF5JnG_MQrISn3NWV5ITI5h_aMjvKHc943Tm-_M",
      "kty": "OKP",
      "x": "a1C4ygPoCvvqUUgUsIrnRpcXh1_46HDIVNg5SVx8ovM"
    }
  },
  "smithers": {
    "token": "fabec032007fe99716a846a23182399957988d7b",
    "keyPair": {
      "crv": "Ed25519",
      "d": "U-cS8pyDqrTjweLamyCwPh6U4nSnTbeAiymiA3FbBtU",
      "kty": "OKP",
      "x": "wtaGnyGJGZ_tiY4YYCJFd-Dg_ahA4_1KOV6sdzvfcPI"
    }
  },
  "luann": {
    "token": "4c699dbef4a0b175b64266a668d006647809293e",
    "keyPair": {
      "crv": "Ed25519",
      "d": "s4Ah2NI-VEaEWVzy-tZfDfXv36CpypndCdy5qU2tX6w",
      "kty": "OKP",
      "x": "6yMN5ld3AZv1Fe5_g6Y2j5TgkAqFnt9_j-shrFFdt-Q"
    }
  },
  "mel": {
    "token": "b396e7856ba55e390842cd0fff5dd3765a888ec0",
    "keyPair": {
      "crv": "Ed25519",
      "d": "NdFQUFn3WTMvn5k5lbzuphZJAKtISJBjVNKYbFgnio4",
      "kty": "OKP",
      "x": "-NDfO5vnuikGpPJOhHQLc6SFmiOz9N-zUlMJVJ9rUsc"
    }
  },
  "lisa-nerdster0": {
    "token": "f7f74c08a3a372e5d617c724c84bbac0f6081a8f",
    "keyPair": {
      "crv": "Ed25519",
      "d": "-tLYDr1-uD2EymgIs_1B5kJviFcXlkF7YYTYP1-ibXU",
      "kty": "OKP",
      "x": "R0QT3mJcCm5cNUWpD6fNwG_LTeQ8qExcJTkxZEbtdGY"
    }
  },
  "bart-nerdster0": {
    "token": "20ece5f7122935f26f791807731acee2cfdd1eab",
    "keyPair": {
      "crv": "Ed25519",
      "d": "MHRJJ1MPexhY9EQOnK7QrLecTRRig4IKJx_dnuzLCHc",
      "kty": "OKP",
      "x": "vdNKZHNsM_f1EK2PrVNw36k_KqJInPYImjMO-d6ptd8"
    }
  },
  "burns-nerdster0": {
    "token": "fbcf578344030cfdf4ed03836d0fdd03764a0abf",
    "keyPair": {
      "crv": "Ed25519",
      "d": "EV84uH33ZeWNFgG7Onpd2jJnfLVuzYKVYyIWRTtz8uE",
      "kty": "OKP",
      "x": "DHypl0Hy2ydywjjq9qB_LiqR1pU4Zhdq-lHOMbe2wvg"
    }
  },
  "homer2-nerdster0": {
    "token": "d01bcac507f18c80a7844f2218f685582c8a22ce",
    "keyPair": {
      "crv": "Ed25519",
      "d": "ctPiQf_qaiavGgxdq6yxBFgg0GouVAg1_dHMjPDHYQc",
      "kty": "OKP",
      "x": "pEEm1HMpujO_IcAwsPBe0qARKMPcW8gHnJj_mFd8ks8"
    }
  },
  "milhouse-nerdster0": {
    "token": "d7741b3f7cd011b319f3a5f3b438dba0216583ee",
    "keyPair": {
      "crv": "Ed25519",
      "d": "rMDefUp6p3-L4IAFqkaMaZgr3ch7mV97Ey2jmbcCMXQ",
      "kty": "OKP",
      "x": "4j6E1TbUWxaE_cjbab7XccB30HYOi4BHSlTijMLG-Dw"
    }
  },
  "carl-nerdster0": {
    "token": "5cb92a66dcba3673a15e29b25f1747e4ceac3158",
    "keyPair": {
      "crv": "Ed25519",
      "d": "RkNtuDx9cYk8DfIfaWLUdxnYLxcjAs0aWvEi6Xt7k1k",
      "kty": "OKP",
      "x": "9SCW3bqrQUeaZ878IWYfs8BKrqgMkBEYj3hCYNyChd4"
    }
  },
  "marge-nerdster0": {
    "token": "1b93ebb2194b372b25d96a8da917ccb5c4e20d35",
    "keyPair": {
      "crv": "Ed25519",
      "d": "D6_2p54Ro3BpiWhmsDa_32n_S7FfGIBXDt5No0A8Cpo",
      "kty": "OKP",
      "x": "OpgJB7rgi8YjvVzJr6w4I42Aj2pECg9-lYR6-bISQRo"
    }
  },
  "sideshow-nerdster0": {
    "token": "7e0dc35755c49f1d15815bb8eb7a6c78ca89bc11",
    "keyPair": {
      "crv": "Ed25519",
      "d": "mTYuRx5rY1VhOg7IFERKORHvmJGL3UqKbcfgICAwHjo",
      "kty": "OKP",
      "x": "JDSLrdBgcuGD4XuLu0oHmoSq_odHXIBeFf3rrdh-1cE"
    }
  }
};