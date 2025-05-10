import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// Simpson public demo
/// - Lisa's view clean, no porn, no notifications
/// - Lisa: horses, Homer: bowling, .... Bart disses Lisa's content...
/// - Krusty bad actor, affects Milhouses view the most
/// - Marge censors Superbad
///
/// BUG: I saw all of milhouse's statements in red at some point, might be missing a clear notifications or something.
///
/// History: The plan was to show this on PROD using FakeFirestore, but that doesn't work in production.
/// Since the demo will use data hosted on PROD, not FakeFirestore, I've decided to not
/// work to make it writeable by the demo'ing user (change follow contexts, submit, diss, etc..).
/// DEFER: Option to show statements like FakeFire which uses Prefs.labelKeys to show nice.

Future<(DemoKey, DemoKey?)> simpsonsDemo() async {
  useClock(TestClock(Duration(days: 1)));

  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey homer2 = await DemoKey.findOrCreate('homer2');
  DemoKey marge = await DemoKey.findOrCreate('marge');
  DemoKey maggie = await DemoKey.findOrCreate('maggie');

  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  DemoKey ralph = await DemoKey.findOrCreate('ralph');
  DemoKey nelson = await DemoKey.findOrCreate('nelson');
  DemoKey lenny = await DemoKey.findOrCreate('lenny');
  DemoKey carl = await DemoKey.findOrCreate('carl');
  DemoKey burns = await DemoKey.findOrCreate('burns');
  DemoKey smithers = await DemoKey.findOrCreate('smithers');
  DemoKey luann = await DemoKey.findOrCreate('luann');

  DemoKey krusty = await DemoKey.findOrCreate('krusty');
  DemoKey sideshow = await DemoKey.findOrCreate('sideshow');
  DemoKey mel = await DemoKey.findOrCreate('mel');

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
      comment: 'lost phone', revokeAt: s2.token); // homer replaces key
  await marge.doTrust(TrustVerb.trust, homer, moniker: 'Hubby');
  // await bart.doTrust(TrustVerb.trust, marge, moniker: 'Moms');
  await bart.doTrust(TrustVerb.trust, homer, moniker: 'Homer');
  await lisa.doTrust(TrustVerb.trust, homer2, moniker: 'Homer'); // lisa trusts homer2
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Sis');
  await homer2.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  // await lisa.doTrust(TrustVerb.trust, homer, moniker: 'Dad');
  await lisa.doTrust(TrustVerb.trust, marge, moniker: 'Mom');
  // await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await lisa.doTrust(TrustVerb.trust, maggie, moniker: 'Maggie');
  await marge.doTrust(TrustVerb.trust, homer2, moniker: 'Hubby'); // marge trusts homer2
  // await bart.doTrust(TrustVerb.clear, homer); // bart clears homer
  // await marge.doTrust(TrustVerb.clear, homer);

  // sideshow...
  // - make Milhouse be labeled 4-Eyes from his own POV due to Sideshow... takes effort
  //   - path from mihouse to bart long
  // - bogus people (Amanda Hugginkiss...)
  await bart.doTrust(TrustVerb.trust, milhouse, moniker: 'Milhouse');
  await krusty.doTrust(TrustVerb.trust, mel, moniker: 'Mel');
  await mel.doTrust(TrustVerb.trust, sideshow, moniker: 'Sideshow');
  DemoKey seymore = await DemoKey.findOrCreate('seymore');
  DemoKey amanda = await DemoKey.findOrCreate('amanda');
  await sideshow.doTrust(TrustVerb.trust, mel, moniker: 'Mel');
  await sideshow.doTrust(TrustVerb.trust, milhouse, moniker: '4-Eyes');
  await sideshow.doTrust(TrustVerb.trust, amanda,
      moniker: 'Amanda Hugginkiss'); // Yeah, yeah, looking for Amanda Huggenkiss. What else is new?
  await sideshow.doTrust(TrustVerb.trust, seymore,
      moniker: 'Seymore Butts'); // That doesn't sound like a real name
  await sideshow.doTrust(TrustVerb.block, marge);

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
  await marge.doTrust(TrustVerb.block, sideshow, comment: 'Naughty!!!');
  await milhouse.doTrust(TrustVerb.trust, krusty, moniker: 'Krusty');

  DemoKey lisaN = await lisa.makeDelegate();
  DemoKey bartN = await bart.makeDelegate();
  DemoKey burnsN = await burns.makeDelegate();
  DemoKey homer2N = await homer2.makeDelegate();
  DemoKey milhouseN = await milhouse.makeDelegate();
  DemoKey carlN = await carl.makeDelegate();
  DemoKey smithersN = await smithers.makeDelegate();
  DemoKey margeN = await marge.makeDelegate();

  DemoKey sideshowN = await sideshow.makeDelegate();
  DemoKey melN = await mel.makeDelegate();
  DemoKey amandaN = await amanda.makeDelegate();
  DemoKey seymoreN = await seymore.makeDelegate();

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

  await smithersN.doRate(subject: brokeback, recommend: true, verb: ContentVerb.rate);
  await carlN.doRate(subject: brokeback, recommend: true, verb: ContentVerb.rate);
  await sideshowN.doRate(subject: brokeback, dismiss: true, verb: ContentVerb.rate);

  await lisaN.doRate(subject: buck, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: dogtown, recommend: true, verb: ContentVerb.rate);
  await milhouseN.doRate(subject: superbad, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: superbad, recommend: true, comment: 'rad', verb: ContentVerb.rate);
  await margeN.doRate(subject: superbad, verb: ContentVerb.censor);
  await margeN.doRate(subject: banana, recommend: true, verb: ContentVerb.rate);
  await homer2N.doRate(subject: kingpin, recommend: true, verb: ContentVerb.rate);
  await bartN.doRate(subject: superbad, comment: 'rad', verb: ContentVerb.rate);
  await bartN.doRate(subject: buck, dismiss: true, verb: ContentVerb.rate);
  await lisaN.doRate(subject: secretariat, recommend: true, verb: ContentVerb.rate);
  await margeN.doRate(subject: secretariat, recommend: true, verb: ContentVerb.rate);
  await carlN.doRate(
      subject: superbad, dismiss: true, comment: 'disgusting', verb: ContentVerb.rate);

  await sideshowN.doRate(subject: joker, recommend: true, verb: ContentVerb.rate);
  await sideshowN.doRate(subject: shakes, recommend: true, verb: ContentVerb.rate);
  await melN.doRate(subject: joker, recommend: true, verb: ContentVerb.rate);
  await melN.doRate(subject: shakes, recommend: true, verb: ContentVerb.rate);
  await amandaN.doRate(subject: joker, recommend: true, verb: ContentVerb.rate);
  await amandaN.doRate(subject: shakes, recommend: true, verb: ContentVerb.rate);
  await seymoreN.doRate(subject: joker, recommend: true, verb: ContentVerb.rate);
  await seymoreN.doRate(subject: shakes, recommend: true, verb: ContentVerb.rate);

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
  await lisaN.doFollow(marge, {'family': 1});
  // await homer2N.doFollow(marge, {'family': 1});
  await margeN.doFollow(lisa, {'family': 1});
  await margeN.doFollow(maggie, {'family': 1});
  await burnsN.doFollow(lisa, {kNerdsterContext: -1});
  await burnsN.doFollow(bart, {kNerdsterContext: -1});
  await burnsN.doFollow(marge, {kNerdsterContext: -1});
  await burnsN.doFollow(homer2, {kNerdsterContext: -1});

  // // Access with: &followNetDegrees=2&follow=<one-of-us>
  // oneofusNet.listen(); // KLUDGE: Workaround for the bug below.
  // // BUG: The code below will trigger processing, and in case OneofusNet though it was
  // // ready because !b(signInState.center), then FollowNet crashes.
  // Prefs.followNetDegrees.value = 2;
  // followNet.fcontext = '<one-of-us>';

  useClock(LiveClock());

  return (lisa, lisaN);
}

// 4/20/2025, created demo on prod
// from /etc => gen link..
// ?oneofus=%7B%22crv%22%3A%22Ed25519%22%2C%22kty%22%3A%22OKP%22%2C%22x%22%3A%22v4TpRrenkE50t7n-Rr1q87ff4fKbm9ZnzTDuJKmEyCA%22%7D&followNetDegrees=2&follow=%3Cone-of-us%3E
// ?oneofus=%7B%22crv%22%3A%22Ed25519%22%2C%22kty%22%3A%22OKP%22%2C%22x%22%3A%22I-BKc0Dnenk0uQ_SfhJ9HSZnviG1yXLVLHaROnIpyQk%22%7D&follow=%3Cone-of-us%3E
// from DEV => dump demo credentials..
const _credentials = {
  "lisa": {
    "token": "25b68be3f622486d8b0a5e03460aeaa89532b997",
    "keyPair": {
      "crv": "Ed25519",
      "d": "HV0PIHO_mYEnRIaXD2JXotRWcpHCtyOtDA4XBOOdvNk",
      "kty": "OKP",
      "x": "v4TpRrenkE50t7n-Rr1q87ff4fKbm9ZnzTDuJKmEyCA"
    }
  },
  "bart": {
    "token": "cdd5855ee9689815105e6fe949343fb6ce483393",
    "keyPair": {
      "crv": "Ed25519",
      "d": "RYXlIZ6P_e-1h_QHd9YMVWVqzBiiNwyCaOv87m6ieTM",
      "kty": "OKP",
      "x": "sz-Rgf-ZjZVbhrrR7Yqx2i7aF32Unc1MVy_IhF2lenU"
    }
  },
  "homer": {
    "token": "dc34c3fada7e4ed8a5f3b546d0e73b969008da94",
    "keyPair": {
      "crv": "Ed25519",
      "d": "09v5-6CidrYZ8nQRbp14PezJQ7L07KHpJBaJNAlWg0I",
      "kty": "OKP",
      "x": "OUxNNAP0V4D33rYiWyqI7nkBQFoif0c9bw5IGdZJ4R0"
    }
  },
  "homer2": {
    "token": "ba2ef53ed11dce7bdfaf51f71fd1461874c89911",
    "keyPair": {
      "crv": "Ed25519",
      "d": "lEz51QkVQpADIHqhspAzZ3AQyg2NzCEDYYL7jFhEKGQ",
      "kty": "OKP",
      "x": "clDXRJvro0umnKdiIjedxFkBCZU6LNP4F0Nu8l9E6B0"
    }
  },
  "marge": {
    "token": "b8927c60255624f41b2ab5f53340a2b4ab1f0911",
    "keyPair": {
      "crv": "Ed25519",
      "d": "Eih2EPXh5aRLhKJY1dGp1I4fE8XeROpnRLeJ8dNhrzQ",
      "kty": "OKP",
      "x": "WLHa0PCgmBIayg4pkv6h92uJZinBrbdGf954a0BZ_EQ"
    }
  },
  "milhouse": {
    "token": "4d9bae7c1e586e3f051a7cffe73c1f5d22850a86",
    "keyPair": {
      "crv": "Ed25519",
      "d": "i_WHWZjjybOF5WmjY1atgsBP8-QgGLX4M1uCGXBYf_M",
      "kty": "OKP",
      "x": "BlEZ7QtO3NJ2tTasdAs2Cl_xpnjR-os5fON3x_NLRoQ"
    }
  },
  "sideshow": {
    "token": "ebf63e48b25fef936d282d7b45ae21c7bd9f6237",
    "keyPair": {
      "crv": "Ed25519",
      "d": "o_lLwlhrtHGGcyKGJB3OosrJAIJ6c1n65Pd3kg43K0c",
      "kty": "OKP",
      "x": "D6TXT-1j1gDLjrnGRIzn6nQZ3EDuNazKCDWByGpJST0"
    }
  },
  "maggie": {
    "token": "aa1980c14df273d0454682b0bd04f688db25be86",
    "keyPair": {
      "crv": "Ed25519",
      "d": "NzBMQuBH_V2Q7CJ23oEOAZcNPl3Xw2kwa4E6g73HyLI",
      "kty": "OKP",
      "x": "0T4JP4S1E0HRH17Zuzq8GxOE5gG70m2K9-ufpy7uPs4"
    }
  },
  "lenny": {
    "token": "2908869ad34a15571e4775dd1ef378735a6e311d",
    "keyPair": {
      "crv": "Ed25519",
      "d": "WfhJYkyYqZQL3Pz2l9PkxA9JrN9leVhgs18uA7dsxS4",
      "kty": "OKP",
      "x": "Js1Vm_d_0wDj3us0DkXZm1qu7FICvMbXu-_3gLwSVBc"
    }
  },
  "carl": {
    "token": "2b5844aca21f7166116f950a1b54f87cc6313eb6",
    "keyPair": {
      "crv": "Ed25519",
      "d": "nMSu4Ye0o_7CyUl1zQkC7FiYsaVrfLdvnpx1O8L89BY",
      "kty": "OKP",
      "x": "s5bOk8KcvKr60DG73eq6SFo19EnnUksLIebPwHdT9Ow"
    }
  },
  "burns": {
    "token": "98304b63448135d7ee5293b26085ad353350c98f",
    "keyPair": {
      "crv": "Ed25519",
      "d": "MS4Q5Ym-Iz3vShTYCYbgSxRxM0CzJYUEFdEDLMRKK5g",
      "kty": "OKP",
      "x": "HMKKEcvoeCR2vUwZXBOiUyWJRsgQPj-z-zU1zjoj1LM"
    }
  },
  "smithers": {
    "token": "1dc412b32150a3080bb8311e43d167037a0e2078",
    "keyPair": {
      "crv": "Ed25519",
      "d": "mgg1X-0reC99FMqVO35AXGML-emSb2AbXBtrqhzv1ZM",
      "kty": "OKP",
      "x": "F0VHtbphd8yfyQDvwGYSBTaJtusoxSDV4ZFtBAzfJWg"
    }
  },
  "luann": {
    "token": "e478a226ca2215e5ddea2487bd93ee04d22ecffc",
    "keyPair": {
      "crv": "Ed25519",
      "d": "_mRatONJDHTxvKvKXiuThtXzdcMtyrV4GZeQ4arNBRU",
      "kty": "OKP",
      "x": "CCgy6YHDK0oTABYpXqmOTwYMk-tIQjn5ECWgthL6qhg"
    }
  },
  "mel": {
    "token": "6c8da8a4a9c561b16572528bbf32cd2340e1d2f0",
    "keyPair": {
      "crv": "Ed25519",
      "d": "VpQIKCnRtaL-VRN4jNubKQsHOkSOCEtrSdkANTB9ssQ",
      "kty": "OKP",
      "x": "NJCoSix09PB_nVrM3wZQMhlvgJTc-5QtT08GizEaam0"
    }
  },
  "amanda": {
    "token": "2672dae995a12eb1620e036e9770ccb5b0374064",
    "keyPair": {
      "crv": "Ed25519",
      "d": "pmb7KSk-Iq9EJq_6LidZbnleJsineG3LxodjtWvXua4",
      "kty": "OKP",
      "x": "f_QIoylejvUgyZgdosrevD6_Ad_8TAslDKoX5_-VBRA"
    }
  },
  "hugh": {
    "token": "78703912f67770cdf7c8d20bb81ba2ff46acb782",
    "keyPair": {
      "crv": "Ed25519",
      "d": "Pilt-JMsw2rrRHSQMu4e1kXx1okG5w_K_FDjgYPqGJY",
      "kty": "OKP",
      "x": "fL2TSythmkbpQJ_WovO8HHjliR7dpn9REWVIalD4SCI"
    }
  },
  "dick": {
    "token": "57c905eb0cd9704b741af94df103d522462517be",
    "keyPair": {
      "crv": "Ed25519",
      "d": "Oe-ShKDKbkN_cU8FWmrlvh-0yJ8cnjZtCTqDPWmrsGQ",
      "kty": "OKP",
      "x": "arTVcBqndfgWDaMzhKDOBZvqj8LFHInYvvvNpEFF6kY"
    }
  },
  "ben": {
    "token": "3edfa829b9b6edad3c5203706048622e525efc84",
    "keyPair": {
      "crv": "Ed25519",
      "d": "GpY-Px5YcTQICMd-9seg7Cx_7LM-9fkKzezfcwZWPhc",
      "kty": "OKP",
      "x": "reZUW9YLByVe_EhPSOY-g1SyozYVd2s6tVcoWr8jYgM"
    }
  },
  "lisa-nerdster0": {
    "token": "874ef6099f0012c063c417fcf255b38b213e467e",
    "keyPair": {
      "crv": "Ed25519",
      "d": "rfk7xIGZ4BsYjtg8FhwZExpw3LbSeE8D52HvN7mvF0I",
      "kty": "OKP",
      "x": "fis1nA99KJNVAbsCgGq0B7nKyz0W6IwR7QV7p5l4KKY"
    }
  },
  "bart-nerdster0": {
    "token": "b30e75c4575543c40220d15db81c73e46a0b8c24",
    "keyPair": {
      "crv": "Ed25519",
      "d": "HujncddV1qvTLuNgSaMuRSicjK02J9OXRdltOHxqx1Y",
      "kty": "OKP",
      "x": "m6lI7xROSxLJHh-YtD1NbLj3X3x9Wpqaxvc3jfCGZhc"
    }
  },
  "burns-nerdster0": {
    "token": "af3a1e9b3733feabed5118959b35800520ba1c31",
    "keyPair": {
      "crv": "Ed25519",
      "d": "XtULWn7cJvT3D0kAVgD6teS5CnzfPm_VWzhWVbb1-bM",
      "kty": "OKP",
      "x": "k7erczSpWbjsJwp8iCxw8rsvs4RqZRCNHRT2mYfBeZU"
    }
  },
  "homer2-nerdster0": {
    "token": "dfd55225d5fc1989dc4fa0e75b338e00b4d8ef27",
    "keyPair": {
      "crv": "Ed25519",
      "d": "Owk6uxOjJVv9vO9s8ZETtDXx22pW5drHUQ6uYQi3ncI",
      "kty": "OKP",
      "x": "UtJJOGlIiDGHr1Ec9ES6JGFhv4m0-7I5-XEgXAyjMSI"
    }
  },
  "milhouse-nerdster0": {
    "token": "59143f5147b06811cc62d63b5154e8e0707521c0",
    "keyPair": {
      "crv": "Ed25519",
      "d": "rx4vYQOWqhGrQ2WyID8G4jJLKSFJV5NU5XcvA30lE0s",
      "kty": "OKP",
      "x": "w7LOEn5gW0rB-YVACU2NkgiZ_l3mAIw686Bs3q_cS-0"
    }
  },
  "carl-nerdster0": {
    "token": "74c329b0243fc409ffe730563f6053886ff49982",
    "keyPair": {
      "crv": "Ed25519",
      "d": "NVWcwGU1gbwj_9YsMruTFn0AXDuoOARyRPuwH5_3KkQ",
      "kty": "OKP",
      "x": "sPiHMpxbd5v3aitz_BYc4eE5Nao2VzUBea56z7VSO8g"
    }
  },
  "marge-nerdster0": {
    "token": "8df42f86439a8eab3217d4853da48fa3bc85c15c",
    "keyPair": {
      "crv": "Ed25519",
      "d": "6IXrTh878qvS8GSdMjTunJBc4CpI6CeKV32CCI5RvAA",
      "kty": "OKP",
      "x": "wbNMeRmbgQp9Eg9pElbMB44IXKjO3K4oQgmmkkKHgDk"
    }
  },
  "sideshow-nerdster0": {
    "token": "067e2282dd48594d8181a16d5038d422ee29225e",
    "keyPair": {
      "crv": "Ed25519",
      "d": "dVW8Ss96b3SOXfsT8JJKOZzeRlIaibU7Kg1LbDFM2Tk",
      "kty": "OKP",
      "x": "fgVDFZ6cIdLQFVJ7x9w-03UpzydO0rd2AJ4gJdhPfPo"
    }
  },
  "mel-nerdster0": {
    "token": "403056c78a86d93d32c04955fc4b1cef424044cd",
    "keyPair": {
      "crv": "Ed25519",
      "d": "-yvTQuBisnCkt6jGtvrIyWF12TXsHXopUDqWjm5XfO0",
      "kty": "OKP",
      "x": "JGn_hgc3RpMkBKYpLv0W9ZIDMPfYbZey9H2fJkhurks"
    }
  },
  "hugh-nerdster0": {
    "token": "c5e9d22500394c5a734a0668b4113dd3908f082a",
    "keyPair": {
      "crv": "Ed25519",
      "d": "96kEtAcM6DJHS4uQQT-5mU34lMZJuXsNscplYTiWBa8",
      "kty": "OKP",
      "x": "eAFubYtaL-bibxQjNJq7aEmihf8N1a9FXcNoUuj173I"
    }
  }
};
