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

  DemoKey lisaN = await lisa.makeDelegate();
  DemoKey bartN = await bart.makeDelegate();
  DemoKey burnsN = await burns.makeDelegate();
  DemoKey homer2N = await homer2.makeDelegate();
  DemoKey milhouseN = await milhouse.makeDelegate();
  DemoKey carlN = await carl.makeDelegate();
  DemoKey margeN = await marge.makeDelegate();

  // Everyone trusts lisa (no dead ends)
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer2.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await marge.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await milhouse.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await sideshow.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
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
  const Json secretariat = {'contentType': 'movie', 'title': "Secretariat", 'year': '2010'};

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
// ?oneofus=%7B%22crv%22%3A%22Ed25519%22%2C%22kty%22%3A%22OKP%22%2C%22x%22%3A%22y2Y-ZrOmiBUMxnpAlFNCzsJmC_MSy82j1V-WsuSbnIw%22%7D&followNetDegrees=2&follow=%3Cone-of-us%3E 
// from DEV => dump demo credentials..
const _credentials = {
  "lisa": {
    "token": "82a7eb63dec62d5647367ec5c8347069d8101479",
    "keyPair": {
      "crv": "Ed25519",
      "d": "mnH8j1Nv3bi5wC85OS6lU_nsDyLOGJVMnz0UqjJiOMQ",
      "kty": "OKP",
      "x": "y2Y-ZrOmiBUMxnpAlFNCzsJmC_MSy82j1V-WsuSbnIw"
    }
  },
  "bart": {
    "token": "d7a66ddca3c1c54c89eb4239e0f1d9a241fbd40f",
    "keyPair": {
      "crv": "Ed25519",
      "d": "3Qs3uBX6UFfLJwqVJ70_2ugpP6H--r_HGSJ9DGDobTY",
      "kty": "OKP",
      "x": "0Fs4efRmj4bneAEEOtQnmAzNUThOLxTAWXk0cwEA-EA"
    }
  },
  "homer": {
    "token": "66449e4d99272f37730dd17463040adc7ddf4a9c",
    "keyPair": {
      "crv": "Ed25519",
      "d": "-cvo0OM-yNLyJGmMDn4za1LkY6SPE362YSl41X55a0k",
      "kty": "OKP",
      "x": "ugakw_Kv-wcZZ-nd_xQ55JIXAIybIMyllwzIpsfcgXc"
    }
  },
  "homer2": {
    "token": "f68253654c8cba214ba840417f202e185b45bad9",
    "keyPair": {
      "crv": "Ed25519",
      "d": "gMQPXPwB55lN0qjaqS4GLJAgJPMlDIIJbC_dee1ohsM",
      "kty": "OKP",
      "x": "ecvCarFtJo-LOP-merz2QLZ5EnSu8xlaADn-Pk-NwUA"
    }
  },
  "marge": {
    "token": "a5e9aa26d93a232e22192ef9b9bab4b695ada0c5",
    "keyPair": {
      "crv": "Ed25519",
      "d": "X9cHmvEZelHlhxmiSa85yeHpE9uWua2faPCJkDuojoQ",
      "kty": "OKP",
      "x": "M-eo10bSbxvgRhS6W80rpkBR5_V0RkqcWRPSM3q4TsE"
    }
  },
  "milhouse": {
    "token": "1672a842ab6dd46c8d2a6b4ec225d5dd51dc3c78",
    "keyPair": {
      "crv": "Ed25519",
      "d": "KSncXQ3S05ngtfipuT3Ol_k5aZ76GWuoaIZmClLBEPw",
      "kty": "OKP",
      "x": "Kv3Gz4m2X2xOydK-tv5ARxk3NLkt_w9F_l6HqqJ3okU"
    }
  },
  "sideshow": {
    "token": "7e079a433c2212986f411be4fb0b3ca7ff3acaeb",
    "keyPair": {
      "crv": "Ed25519",
      "d": "RwOuNtrKiszxBH_VFJXlgQVn-QwMMxA2ktmen-XCXQg",
      "kty": "OKP",
      "x": "9_7XL0188B3v-DzIJAwpIinsXVcrOzq2_aRRbuIp2o4"
    }
  },
  "maggie": {
    "token": "2ee7c781ebd23f8d936bf4e8be123cadf1e61f84",
    "keyPair": {
      "crv": "Ed25519",
      "d": "xkA26Vah6WwHi7k8_MlwVxFq0dntqeqRATrJQJ12hTg",
      "kty": "OKP",
      "x": "XSg56LpIEH4oMK8IjJ5bqh3z64P-a_E8znrGEjpVtMk"
    }
  },
  "lenny": {
    "token": "13f5e8a027aa78b9bdfe07b584d270e542011615",
    "keyPair": {
      "crv": "Ed25519",
      "d": "kRii22z5d66NObHg53FSZ2E__05MHspJOZ3UQQtoGjI",
      "kty": "OKP",
      "x": "tET_CsAHlfCY_4qOp2ImdOlHdhAizI9R2zYPMqS0hh0"
    }
  },
  "carl": {
    "token": "8c1d2c118f0f81151eae96ae7af2aceaed0d7b73",
    "keyPair": {
      "crv": "Ed25519",
      "d": "PBTnXfhbxT42XH0t31A8KIWCwHanYfbI5oHsVLnV2a8",
      "kty": "OKP",
      "x": "HnorP9pDxOy4Hcjoh1z_9L44eeT1-9BA1h--7UvjkdI"
    }
  },
  "burns": {
    "token": "70f8d2b9df5a6d2e517ef0529c846edda4c94dce",
    "keyPair": {
      "crv": "Ed25519",
      "d": "iRGGV6SuECCEH54MrJjKedKg8gGHhgmxTiVOYPAPD1U",
      "kty": "OKP",
      "x": "M5COCy9hhkKPxp3vDxyLH-OgHZZ-YsJZnqilWnacVLI"
    }
  },
  "smithers": {
    "token": "fbc84244f8c658e8e2a5375940ccb05d7e780921",
    "keyPair": {
      "crv": "Ed25519",
      "d": "OuHW6iqLpms0pQVWvNwHhKeF-AKoDQRKK1GqjKOaK-8",
      "kty": "OKP",
      "x": "jVEVT6J2F-BM8njX07gmZ-z6C14mtgamRkEghql8TYM"
    }
  },
  "luann": {
    "token": "029a5f727f7e75f94adb4965bf63aa9c53bcc62e",
    "keyPair": {
      "crv": "Ed25519",
      "d": "npfF4BTNu-nh4JwRlHAOFESnodmwzm3v-WdjAvjG3UY",
      "kty": "OKP",
      "x": "Rcf0YFaUEq4F79kdhFpyPk7_U24I6cEQ5xxUyL6m6y0"
    }
  },
  "mel": {
    "token": "6ccce58e8ae3d30a63832a55914b7b09580583f5",
    "keyPair": {
      "crv": "Ed25519",
      "d": "Urdf45TBzLcucGWKtCJXsT3PoJd-052sRsEW0OI_nSE",
      "kty": "OKP",
      "x": "jLVsTRi7H-gSOfH5RDwmTXCk2wwfpz8EWkl6AV4Oca4"
    }
  },
  "lisa-nerdster0": {
    "token": "4755af016c4c5ca59b509f66c08e53897d11d342",
    "keyPair": {
      "crv": "Ed25519",
      "d": "77DGtqNu98S4AitdE9IxsZm0iWsI-T4aRh3ybKeA-Ag",
      "kty": "OKP",
      "x": "CSw9n8uvs9eX2tdcCmc5JEOW5gLwD772trBJ8BPJVSM"
    }
  },
  "bart-nerdster0": {
    "token": "5bc6225feabb618141a46bac8527ed5faa0776a3",
    "keyPair": {
      "crv": "Ed25519",
      "d": "LzBIYqtCKsbAkTjZYjZJxfuTRY50TZ8_x3cJfO0mxT8",
      "kty": "OKP",
      "x": "5JCneLN-ioam8mIiJwPdhnRTWCLkDsusemqgmWWmdhw"
    }
  },
  "burns-nerdster0": {
    "token": "d9aac4166ca73753894324b29a5303083dc2b9e4",
    "keyPair": {
      "crv": "Ed25519",
      "d": "uelBslUjyZ1_M9IXYYFasQP29NeT8bFML3WtodOHK7Q",
      "kty": "OKP",
      "x": "OfDT7VQcggttPIZa4dgu-KwqncSn7fIVvrKtgCAWzGM"
    }
  },
  "homer2-nerdster0": {
    "token": "6427eb45b54b26c8bb6c13737d1cbc32527bcc80",
    "keyPair": {
      "crv": "Ed25519",
      "d": "R9iJVLDMSS9SWaZmuGAcED940vUBcVUIkXhJ6KqBUxk",
      "kty": "OKP",
      "x": "li6nvPgiRM8Z7KyERsDalDv-2ZNLuNQajXamrnlIQyQ"
    }
  },
  "milhouse-nerdster0": {
    "token": "60e20ef6fc80e5febe575afcfcb9585e2291fedb",
    "keyPair": {
      "crv": "Ed25519",
      "d": "1SgVV_ns10OGW_OAH9QtTDDob7aWTPGlXcr_K87qGgI",
      "kty": "OKP",
      "x": "UrXGg4tDdoKJ19TUR2k1jTtnM_MVoVGApbieGOQ2cAw"
    }
  },
  "carl-nerdster0": {
    "token": "071269ecb38997c69e297cec0dc31839e113bcd7",
    "keyPair": {
      "crv": "Ed25519",
      "d": "h-TrOBn3J29N5VFRie4prFDXMrtYWOVpC3lzu2eLDlo",
      "kty": "OKP",
      "x": "UK9xv9xmW7MOYw4Km2ThNfonSN54Zb-cJYS7t-o14q0"
    }
  },
  "marge-nerdster0": {
    "token": "a662dd1f17b7a8addfe90ee0ddea6b047af3fde9",
    "keyPair": {
      "crv": "Ed25519",
      "d": "3ha-PjYSO5UB3IdY-S7U0Xh8tLb-72UrvZWqzelBnEE",
      "kty": "OKP",
      "x": "WOX4u23gzUTED7yct5FG4yvFf_vnpIEn6o4wXVHfhI4"
    }
  }
};