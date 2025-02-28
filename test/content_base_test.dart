import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/demotest/cases/deletions.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/crypto/crypto.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:test/test.dart';

// I'm not sure about this one. The statements seem to be in the wrong order.
// My recollection is that
// Someone states something aobut DeleteQuestion3
// Someone states something about that
// Someone deletes something
// Something is left dangling, but it's okay, probably with censorship on or off, because he deleted his own thing.

// - doesn't mess with Prefs (showStatements, showEquivalentKeys, etc...)
// - includes everything for now (content, network, nerd tree..)
Future<void> testByDump(caseDump) async {
  await loadDump(caseDump);
  OouPublicKey center = await crypto.parsePublicKey(caseDump['center']);
  await signInState.signIn(Jsonish(await center.json).token, null);
  await contentBase.waitUntilReady();

  // print(await dumpDump(null));
  Json dump = await dumpDump(null);
  jsonExpect(dump, caseDump);
  // jsonExpect(_content.dump(), caseDump['content']);
}

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.registerFire(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.registerFire(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  setUp(() async {
    timezoneOffsetKludge = 0;
    useClock(TestClock());
    DemoKey.clear();
    signInState.signOut();
    await signInState.signIn(Jsonish({}).token, null); // unnecessary.
    contentBase.censor = true;
    followNet.fcontext = null;
    oneofusNet.numPaths = 1;
    Prefs.showKeys.value = false;
    Prefs.showStatements.value = false;
    for (final fire in FireFactory.domain2fire.values) {
      await fire.$1.clearPersistence();
    }
  });

  test('base rate', () async {
    DemoKey? oneofus, delegate;
    (oneofus, delegate) = await DemoKey.demos['loner']();
    DemoKey lonerD = DemoKey.findByName('loner-nerdster0')!;
    expect(delegate!.token, lonerD.token);

    Iterable<ContentTreeNode> roots;

    await signInState.signIn(oneofus!.token, delegate.keyPair);
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 0);

    Statement statement = await lonerD.doRate(title: "t1");
    expect(statement.containsKey('signature'), true);
    contentBase.listen();
    await signInState.signIn(oneofus.token, delegate.keyPair);
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 1);

    Statement statement2 = await lonerD.doRate(title: "t2");
    expect(statement2.containsKey('signature'), true);
    expect(statement2.containsKey('previous'), true);
    await signInState.signIn(oneofus.token, delegate.keyPair);
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 2);
  });

  // Poser recommends and disses "{JS}Big Beard: Growing and Managing Unruly, Big Beards".
  // Jock see's Poser's recommend and dis.
  // Accomplished manually using the UI and dumped.
  test('rate and dis', () async {
    timezoneOffsetKludge = -3;
    Prefs.showStatements.value = true;
    Prefs.showKeys.value = true;
    Prefs.keyLabel.value = false;
    await contentBase.waitUntilReady();
    await testByDump(rateAndDis);
  });

  /// view as Jock using stock DemoKeys.egos.
  test('jock1', () async {
    timezoneOffsetKludge = -3;
    Prefs.showStatements.value = true;
    Prefs.showKeys.value = true;
    Prefs.keyLabel.value = false;
    await testByDump(jock1);
  });

  test('equate subject node to its own statement', () async {
    var (oneofus, delegate) = await DemoKey.demos['loner']();
    DemoKey lonerD = DemoKey.findByName('loner-nerdster0')!;
    expect(lonerD, delegate);

    Iterable<ContentTreeNode> roots;

    await signInState.signIn(oneofus.token, null);
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 0);

    ContentStatement rateStatement = await lonerD.doRate(title: "t1") as ContentStatement;
    contentBase.listen();
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 1);
    ContentTreeNode t1Node = roots.first;
    expect(t1Node.getChildren().length, 1);

    ContentStatement relateStatement = 
        await lonerD.doRelate(ContentVerb.relate, title: "t1", other: rateStatement.json) as ContentStatement;
    contentBase.listen();
    expect(relateStatement.subject, rateStatement.subject);
    expect(relateStatement.other, rateStatement.json);
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 1);
    ContentTreeNode t1Node1 = roots.first;
    expect(t1Node1.toString(), t1Node.toString());
    expect(t1Node1.getChildren().length, 3);
  });

  test('replace delegate', () async {
    await DemoKey.demos['loner']();
    DemoKey loner = DemoKey.findByName('loner')!;
    DemoKey lonerD = DemoKey.findByName('loner-nerdster0')!;

    Iterable<ContentTreeNode> roots;

    await signInState.signIn(loner.token, lonerD.keyPair);
    await Comp.waitOnComps([contentBase, keyLabels]);
    roots = contentBase.roots;
    expect(roots.length, 0);

    Statement statement = await lonerD.doRate(title: "t1");
    expect(statement.containsKey('signature'), true);
    expect(!statement.containsKey('previous'), true);
    await signInState.signIn(loner.token, lonerD.keyPair);
    contentBase.listen();
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 1);

    Statement statement2 = await lonerD.doRate(title: "t2");
    expect(statement2.containsKey('signature'), true);
    expect(statement2.containsKey('previous'), true);
    contentBase.listen();
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 2);

    // Revoke existing delegate at statement
    await loner.doTrust(TrustVerb.delegate, lonerD,
        domain: kNerdsterDomain, comment: 'bad', revokeAt: statement.token);

    await signInState.signIn(loner.token, lonerD.keyPair);
    await contentBase.waitUntilReady();
    expect(keyLabels.show(dumpNetwork(oneofusNet.network)), {'Me': null});

    Map<String, Fetcher> delegateNetwork;
    Map<String, DateTime?> dn;
    await followNet.waitUntilReady();
    delegateNetwork = followNet.delegate2fetcher;
    dn = delegateNetwork.map((token, node) => MapEntry(token, node.revokeAtTime));
    expect(keyLabels.show(dn), {'Me-delegate': '5/1/2024 12:02 AM'});
    roots = contentBase.roots;
    expect(roots.length, 1);

    // Make new delegate
    DemoKey lonerD2 = await DemoKey.findOrCreate('loner-nerdster2');
    await loner.doTrust(TrustVerb.delegate, lonerD2,
        comment: 'nerdster key 2', domain: kNerdsterDomain);
    followNet.listen();
    await Comp.waitOnComps([followNet, keyLabels]);
    delegateNetwork = followNet.delegate2fetcher;
    dn = delegateNetwork.map((token, node) => MapEntry(token, node.revokeAtTime));
    expect(keyLabels.show(dn), {'Me-delegate': null, 'Me-delegate (0)': '5/1/2024 12:02 AM'});

    // say something as new delegate
    Statement statement3 = await lonerD2.doRate(title: "t3");
    expect(statement3.containsKey('signature'), true);
    expect(!statement3.containsKey('previous'), true);
    await signInState.signIn(loner.token, lonerD2.keyPair);
    await contentBase.waitUntilReady();
    roots = contentBase.roots;
    expect(roots.length, 2);

    // say something as revoked delegate
    try {
      Statement statement4 = await lonerD.doRate(title: "t4");
      fail('expected error. Our code will not allow stating stuff with revoked fetcher.');
    } catch (e) {
      // expected
    }
  });

  test('equate1 without dump', () async {
    DemoKey? nerd, delegate;
    (nerd, delegate) = await DemoKey.demos['lonerEquate']();
    await signInState.signIn(nerd!.token, (delegate != null) ? delegate.keyPair : null);
    await contentBase.waitUntilReady();
    expect(contentBase.roots.length, 1);
  });

  /// As Loner:
  /// - submit article 'a'
  /// - submit article 'b'
  /// - equate article 'a' to 'b'
  test('equate1', () async {
    timezoneOffsetKludge = -3;
    Prefs.showStatements.value = true;
    Prefs.showKeys.value = true;
    Prefs.keyLabel.value = false;
    await testByDump(equate1);
  });

  test('delete', () async {
    await testDeletion1();
  });

  test('delete3', () async {
    await deletions3();
  });

  test('findContentType book', () {
    Json json = {
      "statement": "org.nerdster",
      "time": "2024-08-07T14:40:46.979Z",
      "I": {"crv": "Ed25519", "kty": "OKP", "x": "deXDCxNMEL2RLjaf0EBZn9QTxGZFvHYqM1REGUH0hfQ"},
      "rate": {"contentType": "book", "author": "", "title": "b"},
      "with": {"recommend": true},
      "signature":
          "9c0d1c6467270a5b45717df5e9e2b7960f4fdedffb68cafa92a43c6dfe45d431761df6a3e370b6932aed75aa193175f1c5ca081b8ce48adba19c73f08df8970b"
    };
    Set<ContentType> types = ContentBase.findContentTypes(json);
    expect(types, {ContentType.book});
  });

  test('findContentType relate video to relation of book and article', () {
    Json json = {
      "statement": "org.nerdster",
      "time": "2024-08-07T14:42:45.597Z",
      "I": {"crv": "Ed25519", "kty": "OKP", "x": "LsVyWkHAxT0dbO4Uhjn2ACIw4YwWtXcIhKWoLOEPKc8"},
      "relate": {
        "statement": "org.nerdster",
        "time": "2024-08-07T14:42:04.270Z",
        "I": {"crv": "Ed25519", "kty": "OKP", "x": "LsVyWkHAxT0dbO4Uhjn2ACIw4YwWtXcIhKWoLOEPKc8"},
        "relate": {"contentType": "article", "title": "a", "url": "a"},
        "with": {
          "otherSubject": {"contentType": "book", "author": "b", "title": "b"}
        },
        "previous": "444cbf1b367b6c500ba7022d459962c119736fd2",
        "signature":
            "d8ab6f2f9bc4d37d2ece6b44972eb1b85a79341c36f87f24435d63ae7f7ba3b62cdf5048c5ee5398f6af5d2f7b8f66ab938a11e76c08beaed57ac5c0e4b00407"
      },
      "with": {
        "otherSubject": {
          "statement": "org.nerdster",
          "time": "2024-08-07T14:42:18.554Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "LsVyWkHAxT0dbO4Uhjn2ACIw4YwWtXcIhKWoLOEPKc8"},
          "rate": {"contentType": "video", "title": "v", "url": ""},
          "with": {
            "tags": ["v"]
          },
          "previous": "a1b6ad7ac383d274faf87e5c1790b1799c2474fb",
          "signature":
              "a6dcba6f36b3cf1078611502f83bde131241532114de4978583f1a707c092b89410840b1ea3d933916a2afb7f805de53ceb15320a7feb36db1c1be731e908b0c"
        }
      },
      "previous": "d7f2b689b1cb5d5ec3ed688272ee1e6ae68d554c",
      "signature":
          "078f8b71de663c3a66012c5f8fbb465ea0166b079e5b908e8bf803eadcf716f002f785905c58bb1e30d0298f73d60dc7bdec99c64fa847c5e455e601c611730c"
    };
    Set<ContentType> types = ContentBase.findContentTypes(json);
    expect(types, {ContentType.book, ContentType.video, ContentType.article});
  });
}

var jock1 = {
  "center": {"crv": "Ed25519", "kty": "OKP", "x": "BxZe_ANg7RlQcfosSkfHUwbRtz_xLCPM-cWE7R0bblA"},
  "domain2token2statements": {
    "one-of-us.net": {
      "56fdb386774d706095337396360b57bb6cbb191f": [
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:44:02.836Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "BxZe_ANg7RlQcfosSkfHUwbRtz_xLCPM-cWE7R0bblA"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "dKi3SaaazVBOZm4F0ouVzLP69JEnwT3yv7CogqRdGY0"
          },
          "with": {"domain": "nerdster.org"},
          "previous": "328b0c8559e33df8b21af1e7a2f1219e08ee6477",
          "signature":
              "fb011599c486b3678555391966157d6fdaa580a4c12e054ee8c01fb81418960ac9d2f1400155f37ee94f2fb85cacf69b02188cde234cd5ecfc4f75b0dd13ff0a"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:44:02.702Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "BxZe_ANg7RlQcfosSkfHUwbRtz_xLCPM-cWE7R0bblA"},
          "trust": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "5Q1RPSuMtqdubngTkqeMXv0xQtUuw3TMC_9vlNVMNUM"
          },
          "with": {"moniker": "poser"},
          "signature":
              "f8c723011858240d48779bb9972b1776b475824fd46c059c473b53a94e8883f8ff27487f67a6a3fcc81312af344f91878da625c2780cb2121e1684f27e047908"
        }
      ],
      "8db118b9e32a722334a9ce723a47b41c062bcb56": [
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:44:02.912Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "5Q1RPSuMtqdubngTkqeMXv0xQtUuw3TMC_9vlNVMNUM"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "3_6RapYV6PKTDcz55usZAhRtFxasaacgZ5Rj9Weko4I"
          },
          "with": {"domain": "nerdster.org"},
          "previous": "71ab5928a2070d6e521780712a86606ee64b4a12",
          "signature":
              "14caa2f3c3d09490a636e233aad8601f4284d290e2a01262925b33e1e2f06b073cf0e32d918b6f154c2157e28f4c3dc9a9ffd08c01ad2b83e4febe1e0f6ae508"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:44:02.756Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "5Q1RPSuMtqdubngTkqeMXv0xQtUuw3TMC_9vlNVMNUM"},
          "trust": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "U_BlQtkySWF_T6lElFcYIn6KJedXv5ivJhLU8h27dDs"
          },
          "with": {"moniker": "hipster"},
          "signature":
              "cfd7660d5d4510b47e5dd8b695d55b0a1285afe40887c55c53fd848f7bdf98d0f4ab9741bba3b26a4c0d0f747ae9c0225e7752885e120cea0ad98e174ee17f06"
        }
      ],
      "fde5faa93a9a6576eebe94647b2c4e7aaedb20b9": [
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:44:03.257Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "U_BlQtkySWF_T6lElFcYIn6KJedXv5ivJhLU8h27dDs"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "1f6Mf4iXFM0DuC_vwEj1CQVYICKtWeyAwSQtnzsynCg"
          },
          "with": {"domain": "nerdster.org"},
          "previous": "33404bc620f40ca4739f7637d308ff523948e9d0",
          "signature":
              "d959e90d7f44b5311b8f1a551ebc09afad0fdd8c6d9dd8163af1e9cd7ccd1165688d2fb46b052d7d4dc93380a5535381bbd005035e03abe71fb8306fd8f04d07"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:44:03.184Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "U_BlQtkySWF_T6lElFcYIn6KJedXv5ivJhLU8h27dDs"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "o40GKCMBVnBAtdpJn0LGDZIZUnembgyFhOvEZW073zE"
          },
          "with": {
            "revokeAt": "47512abceda919b934a3360678d165b24680f9d2",
            "domain": "nerdster.org"
          },
          "comment": "bad",
          "previous": "de25dadc68192d3747604e963b918290d1255230",
          "signature":
              "c8b216a32a838bf21a1bc84a6dc277a3a153abe6e68662528155df407840d3e80f959808e87cc87a76bf96cc0d2071e700c503f439cf62b59eb65034e0ea800f"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:44:02.986Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "U_BlQtkySWF_T6lElFcYIn6KJedXv5ivJhLU8h27dDs"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "o40GKCMBVnBAtdpJn0LGDZIZUnembgyFhOvEZW073zE"
          },
          "with": {"domain": "nerdster.org"},
          "signature":
              "dbf5b43f96dc8f25b360344b756a15be47257c0abfcf8b9b70e4c473422e8ccdbfd8476c4d780dfdca17d48ea8e7bf1369e2831a2d8266209eddcc58ac13dd0c"
        }
      ]
    },
    "nerdster.org": {
      "edfd79eb5950976eaf12c0ffaf5948e8fa848df1": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:44:03.036Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "dKi3SaaazVBOZm4F0ouVzLP69JEnwT3yv7CogqRdGY0"},
          "rate": {
            "contentType": "video",
            "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
            "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
          },
          "with": {"recommend": true},
          "comment": "Sick!",
          "signature":
              "54269da0faf6b3a3aa5f64d820a48c839c50125753c4287d39c8960aacf7bc837a3a74112778788d07616ae5156a0b8347db84736485071b2427eb0f9cfea100"
        }
      ],
      "0bd00587bd5219fb8facf8219adc312b885c962d": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:44:03.358Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "3_6RapYV6PKTDcz55usZAhRtFxasaacgZ5Rj9Weko4I"},
          "rate": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:44:03.085Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "o40GKCMBVnBAtdpJn0LGDZIZUnembgyFhOvEZW073zE"
            },
            "rate": {
              "contentType": "article",
              "title": "Big Beard: Growing and Managing Unruly, Big Beards",
              "url":
                  "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
            },
            "with": {"recommend": true},
            "comment": "Rad!",
            "signature":
                "dc87893dd8e8d3862afdb5fc5b998744e7349ee00c87ec96d30eb5b3d98b9e188cbb08afdea0b12b34622d7d6e9992a01a3e3d7a9d7599dc437cacb290bbde0e"
          },
          "with": {"recommend": true},
          "comment": "Yeah, baby.",
          "signature":
              "69dd026581ea43db67b887c003730a9c1c0c4d29e7a4b369f59e5574adbd77188d87a2014b30aaaac7402414c5aab98485b86e8ae5e77c72a53eee37066e8e04"
        }
      ],
      "4bd109a54e4e0f4fa2bfe424516f261f57d3db8c": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:44:03.407Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "1f6Mf4iXFM0DuC_vwEj1CQVYICKtWeyAwSQtnzsynCg"},
          "rate": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:44:03.358Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "3_6RapYV6PKTDcz55usZAhRtFxasaacgZ5Rj9Weko4I"
            },
            "rate": {
              "statement": "org.nerdster",
              "time": "2024-10-10T20:44:03.085Z",
              "I": {
                "crv": "Ed25519",
                "kty": "OKP",
                "x": "o40GKCMBVnBAtdpJn0LGDZIZUnembgyFhOvEZW073zE"
              },
              "rate": {
                "contentType": "article",
                "title": "Big Beard: Growing and Managing Unruly, Big Beards",
                "url":
                    "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
              },
              "with": {"recommend": true},
              "comment": "Rad!",
              "signature":
                  "dc87893dd8e8d3862afdb5fc5b998744e7349ee00c87ec96d30eb5b3d98b9e188cbb08afdea0b12b34622d7d6e9992a01a3e3d7a9d7599dc437cacb290bbde0e"
            },
            "with": {"recommend": true},
            "comment": "Yeah, baby.",
            "signature":
                "69dd026581ea43db67b887c003730a9c1c0c4d29e7a4b369f59e5574adbd77188d87a2014b30aaaac7402414c5aab98485b86e8ae5e77c72a53eee37066e8e04"
          },
          "with": {"recommend": true},
          "comment": "Thanks!",
          "previous": "a35d97c4467eb77f49912518e2062e99d2539351",
          "signature":
              "74fa4d64d9b7c7b81e11158910806c350991ad217fda2b2fb82de202db0b0217e630689eae997d324d525296d49ca022f1d4dd7e7d1fe97ca47fb001de7d7401"
        },
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:44:03.306Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "1f6Mf4iXFM0DuC_vwEj1CQVYICKtWeyAwSQtnzsynCg"},
          "rate": {
            "contentType": "article",
            "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
            "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
          },
          "with": {"recommend": true},
          "signature":
              "4161c650a5c746b1a107d38f21eaf0da9bf50d1a0d835f181ba2ad47fdb6dcb62ee1c176ad4e2de28d30a7cfdaad1e2172601c1504d56b217d44f15b410d1f07"
        }
      ],
      "3063e7a385669011ab4af99167fc41373d09232c": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:44:03.085Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "o40GKCMBVnBAtdpJn0LGDZIZUnembgyFhOvEZW073zE"},
          "rate": {
            "contentType": "article",
            "title": "Big Beard: Growing and Managing Unruly, Big Beards",
            "url":
                "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
          },
          "with": {"recommend": true},
          "comment": "Rad!",
          "signature":
              "dc87893dd8e8d3862afdb5fc5b998744e7349ee00c87ec96d30eb5b3d98b9e188cbb08afdea0b12b34622d7d6e9992a01a3e3d7a9d7599dc437cacb290bbde0e"
        }
      ]
    }
  },
  "network": {
    "56fdb386774d706095337396360b57bb6cbb191f": null,
    "8db118b9e32a722334a9ce723a47b41c062bcb56": null,
    "fde5faa93a9a6576eebe94647b2c4e7aaedb20b9": null
  },
  "nerds": {
    "N:Me-true:": {
      "N:poser-true:Me": {
        "N:hipster-true:Me->poser": {
          "N:hipster-delegate-false:Me->poser->hipster": {},
          "N:hipster-delegate (0)-false:10/10/2024 1:44 PM:Me->poser->hipster": {},
          "S:1be34a1ae02178586be9cde87f01e495192e1812:@10/10/2024 1:44 PM:delegated:hipster-delegate":
              {},
          "S:33404bc620f40ca4739f7637d308ff523948e9d0:@10/10/2024 1:44 PM:delegated:hipster-delegate (0)":
              {}
        },
        "N:poser-delegate-false:Me->poser": {},
        "S:16ced061c9251a7d1458350aca55d97886b620a8:@10/10/2024 1:44 PM:delegated:poser-delegate":
            {},
        "S:71ab5928a2070d6e521780712a86606ee64b4a12:@10/10/2024 1:44 PM:trusted:hipster": {}
      },
      "N:Me-delegate-false:Me": {},
      "S:ca9007da20fddb2574651b9a711efccd3b9a8f89:@10/10/2024 1:44 PM:delegated:Me-delegate": {},
      "S:328b0c8559e33df8b21af1e7a2f1219e08ee6477:@10/10/2024 1:44 PM:trusted:poser": {}
    }
  },
  "content": [
    {
      "subject": {
        "contentType": "article",
        "title": "Big Beard: Growing and Managing Unruly, Big Beards",
        "url":
            "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
      },
      "props": {"recommend": 1, "numComments": 3, "recentActivity": "10/10/2024 1:44 PM"},
      "children": [
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:44:03.085Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "o40GKCMBVnBAtdpJn0LGDZIZUnembgyFhOvEZW073zE"
            },
            "rate": {
              "contentType": "article",
              "title": "Big Beard: Growing and Managing Unruly, Big Beards",
              "url":
                  "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
            },
            "with": {"recommend": true},
            "comment": "Rad!",
            "signature":
                "dc87893dd8e8d3862afdb5fc5b998744e7349ee00c87ec96d30eb5b3d98b9e188cbb08afdea0b12b34622d7d6e9992a01a3e3d7a9d7599dc437cacb290bbde0e"
          }
        }
      ]
    },
    {
      "subject": {
        "contentType": "article",
        "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
        "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
      },
      "props": {"recommend": 1, "numComments": 0, "recentActivity": "10/10/2024 1:44 PM"},
      "children": [
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:44:03.306Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "1f6Mf4iXFM0DuC_vwEj1CQVYICKtWeyAwSQtnzsynCg"
            },
            "rate": {
              "contentType": "article",
              "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
              "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
            },
            "with": {"recommend": true},
            "signature":
                "4161c650a5c746b1a107d38f21eaf0da9bf50d1a0d835f181ba2ad47fdb6dcb62ee1c176ad4e2de28d30a7cfdaad1e2172601c1504d56b217d44f15b410d1f07"
          }
        }
      ]
    },
    {
      "subject": {
        "contentType": "video",
        "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
        "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
      },
      "props": {"recommend": 1, "numComments": 1, "recentActivity": "10/10/2024 1:44 PM"},
      "children": [
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:44:03.036Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "dKi3SaaazVBOZm4F0ouVzLP69JEnwT3yv7CogqRdGY0"
            },
            "rate": {
              "contentType": "video",
              "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
              "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
            },
            "with": {"recommend": true},
            "comment": "Sick!",
            "signature":
                "54269da0faf6b3a3aa5f64d820a48c839c50125753c4287d39c8960aacf7bc837a3a74112778788d07616ae5156a0b8347db84736485071b2427eb0f9cfea100"
          }
        }
      ]
    }
  ]
};

var equate1 = {
  "center": {"crv": "Ed25519", "kty": "OKP", "x": "ZDQrdTG4xuXEDO2yRYtmJEoYRILcintTd-fCgdObe3A"},
  "domain2token2statements": {
    "one-of-us.net": {
      "2af42950bc87929498b72f25abc5faa90187acfb": [
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:54:18.143Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "ZDQrdTG4xuXEDO2yRYtmJEoYRILcintTd-fCgdObe3A"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "l-SxQt89p0zdwuJBZHoZPwAT4mMS7yFZ0AFqFsOPZow"
          },
          "with": {"domain": "nerdster.org"},
          "signature":
              "43de93a093b1fa428d48a4e8c846d159fc9ca5added2f954c81a71a1476211a03aa574372a27fb55ca5b986790cd5cc70bca182e06c2652bfb32297beab6c204"
        }
      ]
    },
    "nerdster.org": {
      "745c1ed4167af251491fcc24793626e7714ff416": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:54:58.223Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "l-SxQt89p0zdwuJBZHoZPwAT4mMS7yFZ0AFqFsOPZow"},
          "equate": {"contentType": "article", "title": "a", "url": ""},
          "with": {
            "otherSubject": {"contentType": "article", "title": "b", "url": ""}
          },
          "previous": "008986d2c184415862772443634aa0aa70ad0fb5",
          "signature":
              "b3f320ef30f574de9553a009b8e0175d0382a191c904efa2850635c651ec9cb9b934a45b23fb6df068165fa57f6e32ea4dc9a727a72566855939fad070348208"
        },
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:54:40.632Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "l-SxQt89p0zdwuJBZHoZPwAT4mMS7yFZ0AFqFsOPZow"},
          "rate": {"contentType": "article", "title": "b", "url": ""},
          "with": {"recommend": true},
          "previous": "f9b004807654e70c89bfbc186fd3dd284f379df0",
          "signature":
              "2577181ab85c7000246f890cadf65e25b623e47ea69ec3e839182f758a010a85f66b9b005129751e1ae9f9da631b31456ab576f347a811168b08cf183c77f60a"
        },
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:54:32.719Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "l-SxQt89p0zdwuJBZHoZPwAT4mMS7yFZ0AFqFsOPZow"},
          "rate": {"contentType": "article", "title": "a", "url": ""},
          "with": {"recommend": true},
          "signature":
              "0cb694b2352a7b6101cfd0048a42e19dbb1864fb319be9afca3745a7f0ca7ce11ed499d2ab58e511772a80a176a7c7ea5a50431acf7ba18a8cba3908b121490f"
        }
      ]
    }
  },
  "network": {"2af42950bc87929498b72f25abc5faa90187acfb": null},
  "nerds": {
    "N:Me-true:": {
      "N:Me-delegate-false:Me": {},
      "S:75605fa84501f7a97731514f24569bfe7475015c:@10/10/2024 1:54 PM:delegated:Me-delegate": {}
    }
  },
  "content": [
    {
      "subject": {"contentType": "article", "title": "a", "url": ""},
      "props": {"recommend": 2, "numComments": 0, "recentActivity": "10/10/2024 1:54 PM"},
      "children": [
        {
          "subject": {"contentType": "article", "title": "b", "url": ""}
        },
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:54:58.223Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "l-SxQt89p0zdwuJBZHoZPwAT4mMS7yFZ0AFqFsOPZow"
            },
            "equate": {"contentType": "article", "title": "a", "url": ""},
            "with": {
              "otherSubject": {"contentType": "article", "title": "b", "url": ""}
            },
            "previous": "008986d2c184415862772443634aa0aa70ad0fb5",
            "signature":
                "b3f320ef30f574de9553a009b8e0175d0382a191c904efa2850635c651ec9cb9b934a45b23fb6df068165fa57f6e32ea4dc9a727a72566855939fad070348208"
          }
        },
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:54:40.632Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "l-SxQt89p0zdwuJBZHoZPwAT4mMS7yFZ0AFqFsOPZow"
            },
            "rate": {"contentType": "article", "title": "b", "url": ""},
            "with": {"recommend": true},
            "previous": "f9b004807654e70c89bfbc186fd3dd284f379df0",
            "signature":
                "2577181ab85c7000246f890cadf65e25b623e47ea69ec3e839182f758a010a85f66b9b005129751e1ae9f9da631b31456ab576f347a811168b08cf183c77f60a"
          }
        },
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:54:32.719Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "l-SxQt89p0zdwuJBZHoZPwAT4mMS7yFZ0AFqFsOPZow"
            },
            "rate": {"contentType": "article", "title": "a", "url": ""},
            "with": {"recommend": true},
            "signature":
                "0cb694b2352a7b6101cfd0048a42e19dbb1864fb319be9afca3745a7f0ca7ce11ed499d2ab58e511772a80a176a7c7ea5a50431acf7ba18a8cba3908b121490f"
          }
        }
      ]
    }
  ]
};

var rateAndDis = {
  "center": {"crv": "Ed25519", "kty": "OKP", "x": "bou5jRZeLlDI4mtV0nuEC-gwYqk6uwD9472F8Y_ntNc"},
  "domain2token2statements": {
    "one-of-us.net": {
      "c51d0df5f341a825987721406b6f1fdc29774343": [
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:53:24.755Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "bou5jRZeLlDI4mtV0nuEC-gwYqk6uwD9472F8Y_ntNc"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "QOlIS9l5gDh4xIcz1KNC2Er54Z_0FpUHe_6tvCT6dVo"
          },
          "with": {"domain": "nerdster.org"},
          "previous": "2e37900e39773a84655584c3c8754a0c39039de0",
          "signature":
              "1cf6aa20ba87fc9932547fe4987b76eb4fdf5dd072a8048b2d993439ea56ec95229f844f36a7d6bebb76381c44534b1840736ccfd4057cf1b18f56949e727404"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:53:24.625Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "bou5jRZeLlDI4mtV0nuEC-gwYqk6uwD9472F8Y_ntNc"},
          "trust": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "p6cclPelxuYknwn9sAVlDd8PcmFOHLLjBL7aU4Z3m1U"
          },
          "with": {"moniker": "poser"},
          "signature":
              "d2e2ec348684f1313dc99ade5937717000226dc8d4752ed06f6e64d0b2463667e5d78fe19e4f301a287ef6932e1676de659fb29ca8c2800b0543558cc3a9c402"
        }
      ],
      "8d700ca8ff24a89dec40e99bf9665f5e2d510fd7": [
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:53:24.822Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "p6cclPelxuYknwn9sAVlDd8PcmFOHLLjBL7aU4Z3m1U"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "CKrvWnFIBGzan38iKQBIQFdiiic4l-LDkMHuJUmXuxs"
          },
          "with": {"domain": "nerdster.org"},
          "previous": "3db77a56ba6ff6e21a5b0d45905779a71935ecd4",
          "signature":
              "c257b7465ce31b5ca9ddb777042a8144902e56fcf58c63790fff27ade4bab412cf8983e7d9ab83e68847b01ad13bb2a7b2c770565337fba166b9f4400e07b107"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:53:24.686Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "p6cclPelxuYknwn9sAVlDd8PcmFOHLLjBL7aU4Z3m1U"},
          "trust": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "v7aJFV0w1cFFOgs1_efJpsS04Ne34P6RkBP1hZGatlQ"
          },
          "with": {"moniker": "hipster"},
          "signature":
              "800dfe0b37929eb0300aab0750c12eb41c70ace2a08153fad23ab5e9c51061376a49126e1f111e2bdec809005c6934169fa9268262ec16c530282b1f7440e20c"
        }
      ],
      "ae733e55f54c08bdb0763ca32c2694b7bb5cc286": [
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:53:25.132Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "v7aJFV0w1cFFOgs1_efJpsS04Ne34P6RkBP1hZGatlQ"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "27ntcunav4EZxDiqimmjpSaQ6NQUV8z1doAT9N8TVfo"
          },
          "with": {"domain": "nerdster.org"},
          "previous": "319118699fb7a63667fa4dc2e1b74f66c47e387a",
          "signature":
              "667a9651a34f123b7d775641ed6b3d1e240f43d31efc86c95a7e4a1d75ef96e16c1d8a488aeaf260d8035c87881c7c16b18dd8370353c2fed5e38674f7414c02"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:53:25.065Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "v7aJFV0w1cFFOgs1_efJpsS04Ne34P6RkBP1hZGatlQ"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "RWS7tp1uhbegjwO-Hx0h5Kaivw4SqiBf1LWXx7qiv-w"
          },
          "with": {
            "revokeAt": "609906ece8d16aabdd59c43d745560f0c3b5fac5",
            "domain": "nerdster.org"
          },
          "comment": "bad",
          "previous": "0ea8b728ad6a92b511caf372c286cb6c4a51e038",
          "signature":
              "61f5cd18d0e4f2816502ac2e19a16c1e7d1b338b04750efe50fc600a0d7070a636c5adf2130ff95f83d1a169579c337c29dd5d85421d5c17f052ed0b8f9dbd05"
        },
        {
          "statement": "net.one-of-us",
          "time": "2024-10-10T20:53:24.889Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "v7aJFV0w1cFFOgs1_efJpsS04Ne34P6RkBP1hZGatlQ"},
          "delegate": {
            "crv": "Ed25519",
            "kty": "OKP",
            "x": "RWS7tp1uhbegjwO-Hx0h5Kaivw4SqiBf1LWXx7qiv-w"
          },
          "with": {"domain": "nerdster.org"},
          "signature":
              "bca5b87165a620c7815d1b5948d2c82c4e24868e79bcd6f2e1192bbdecd5756c329084b86ccf11016065686784f989eebf22ac264c33e8098f64fe294d2d1a0f"
        }
      ]
    },
    "nerdster.org": {
      "ebb171997c2ef40eaed3878d9d189e7bf6eac9b5": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:53:24.934Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "QOlIS9l5gDh4xIcz1KNC2Er54Z_0FpUHe_6tvCT6dVo"},
          "rate": {
            "contentType": "video",
            "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
            "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
          },
          "with": {"recommend": true},
          "comment": "Sick!",
          "signature":
              "f5d49f8aa9169cce79ec23dec4e44b58f12e196f054ad048c6c3f3805ef905f935d16c12846a8f7d57600ca037b77984173e7686599a318db60ab6fafbfaac0e"
        }
      ],
      "d943f5c5bbc236eae2c3bf38b224fb7d0c9e12bf": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:53:41.049Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "CKrvWnFIBGzan38iKQBIQFdiiic4l-LDkMHuJUmXuxs"},
          "rate": {
            "contentType": "article",
            "title": "Big Beard: Growing and Managing Unruly, Big Beards",
            "url":
                "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
          },
          "with": {"recommend": true, "dismiss": true},
          "previous": "fe6cad6efdde517f1be9f8c0a24f41290a448789",
          "signature":
              "2bfc2412509e20a1cc8c4d4eab723996a9af72f90eae8f36b6124a7de8ce47ad38d41fca3ddcccb90686193f99d00436c1ff70422d7e536371dd444eaad98503"
        },
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:53:25.224Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "CKrvWnFIBGzan38iKQBIQFdiiic4l-LDkMHuJUmXuxs"},
          "rate": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:53:24.978Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "RWS7tp1uhbegjwO-Hx0h5Kaivw4SqiBf1LWXx7qiv-w"
            },
            "rate": {
              "contentType": "article",
              "title": "Big Beard: Growing and Managing Unruly, Big Beards",
              "url":
                  "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
            },
            "with": {"recommend": true},
            "comment": "Rad!",
            "signature":
                "595a051c184751029ff38906fce6e972995635b36f9936745fd3c75598ddde395f3a040962192957edef76f32b4d1c6cb5aa832862a5596b1576f468f53e440c"
          },
          "with": {"recommend": true},
          "comment": "Yeah, baby.",
          "signature":
              "97dc19618cbc7db03dfb0813ec79e1f5c97c90c36dc059e2886353abe7d98c2d188933892adadc30d5560da53a9e1e623d60cd7557c93b7048e9fc2aae1ec20e"
        }
      ],
      "2806740a13e54c7d70ba0d7c8e54986e466d77df": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:53:25.268Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "27ntcunav4EZxDiqimmjpSaQ6NQUV8z1doAT9N8TVfo"},
          "rate": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:53:25.224Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "CKrvWnFIBGzan38iKQBIQFdiiic4l-LDkMHuJUmXuxs"
            },
            "rate": {
              "statement": "org.nerdster",
              "time": "2024-10-10T20:53:24.978Z",
              "I": {
                "crv": "Ed25519",
                "kty": "OKP",
                "x": "RWS7tp1uhbegjwO-Hx0h5Kaivw4SqiBf1LWXx7qiv-w"
              },
              "rate": {
                "contentType": "article",
                "title": "Big Beard: Growing and Managing Unruly, Big Beards",
                "url":
                    "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
              },
              "with": {"recommend": true},
              "comment": "Rad!",
              "signature":
                  "595a051c184751029ff38906fce6e972995635b36f9936745fd3c75598ddde395f3a040962192957edef76f32b4d1c6cb5aa832862a5596b1576f468f53e440c"
            },
            "with": {"recommend": true},
            "comment": "Yeah, baby.",
            "signature":
                "97dc19618cbc7db03dfb0813ec79e1f5c97c90c36dc059e2886353abe7d98c2d188933892adadc30d5560da53a9e1e623d60cd7557c93b7048e9fc2aae1ec20e"
          },
          "with": {"recommend": true},
          "comment": "Thanks!",
          "previous": "29b82155a9363e7e88bcfb71195747c9588b315c",
          "signature":
              "24be71fc72992a77eef0779ba8686b7b4fbfb5c54d092703cce827f87e15c0f9143b30a7dee5dcf3aae887961953fc84d4d1acf2bd351010d6e19f9f282dd403"
        },
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:53:25.179Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "27ntcunav4EZxDiqimmjpSaQ6NQUV8z1doAT9N8TVfo"},
          "rate": {
            "contentType": "article",
            "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
            "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
          },
          "with": {"recommend": true},
          "signature":
              "5cc49f2fb7a3d89ec2b39398eb34f5c050774b71dc719ce47398026afb0ff9c35d28343198d118dc8b414c50aedd46390281f8eba2cdabb3514dc020df4f0509"
        }
      ],
      "500c31fa8e1138f84c08d266480ce39c1b618d31": [
        {
          "statement": "org.nerdster",
          "time": "2024-10-10T20:53:24.978Z",
          "I": {"crv": "Ed25519", "kty": "OKP", "x": "RWS7tp1uhbegjwO-Hx0h5Kaivw4SqiBf1LWXx7qiv-w"},
          "rate": {
            "contentType": "article",
            "title": "Big Beard: Growing and Managing Unruly, Big Beards",
            "url":
                "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
          },
          "with": {"recommend": true},
          "comment": "Rad!",
          "signature":
              "595a051c184751029ff38906fce6e972995635b36f9936745fd3c75598ddde395f3a040962192957edef76f32b4d1c6cb5aa832862a5596b1576f468f53e440c"
        }
      ]
    }
  },
  "network": {
    "c51d0df5f341a825987721406b6f1fdc29774343": null,
    "8d700ca8ff24a89dec40e99bf9665f5e2d510fd7": null,
    "ae733e55f54c08bdb0763ca32c2694b7bb5cc286": null
  },
  "nerds": {
    "N:Me-true:": {
      "N:poser-true:Me": {
        "N:hipster-true:Me->poser": {
          "N:hipster-delegate-false:Me->poser->hipster": {},
          "N:hipster-delegate (0)-false:10/10/2024 1:53 PM:Me->poser->hipster": {},
          "S:f6872af18559e8e6da8b278455cc30c68ea6b5ca:@10/10/2024 1:53 PM:delegated:hipster-delegate":
              {},
          "S:319118699fb7a63667fa4dc2e1b74f66c47e387a:@10/10/2024 1:53 PM:delegated:hipster-delegate (0)":
              {}
        },
        "N:poser-delegate-false:Me->poser": {},
        "S:5780285c98235c834fa316ece86b1fcb26ed0c9b:@10/10/2024 1:53 PM:delegated:poser-delegate":
            {},
        "S:3db77a56ba6ff6e21a5b0d45905779a71935ecd4:@10/10/2024 1:53 PM:trusted:hipster": {}
      },
      "N:Me-delegate-false:Me": {},
      "S:29f02d57dc1278d46e36dccf63f46ecacdf8c4b8:@10/10/2024 1:53 PM:delegated:Me-delegate": {},
      "S:2e37900e39773a84655584c3c8754a0c39039de0:@10/10/2024 1:53 PM:trusted:poser": {}
    }
  },
  "content": [
    {
      "subject": {
        "contentType": "article",
        "title": "Big Beard: Growing and Managing Unruly, Big Beards",
        "url":
            "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
      },
      "props": {"recommend": 1, "numComments": 3, "recentActivity": "10/10/2024 1:53 PM"},
      "children": [
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:53:41.049Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "CKrvWnFIBGzan38iKQBIQFdiiic4l-LDkMHuJUmXuxs"
            },
            "rate": {
              "contentType": "article",
              "title": "Big Beard: Growing and Managing Unruly, Big Beards",
              "url":
                  "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
            },
            "with": {"recommend": true, "dismiss": true},
            "previous": "fe6cad6efdde517f1be9f8c0a24f41290a448789",
            "signature":
                "2bfc2412509e20a1cc8c4d4eab723996a9af72f90eae8f36b6124a7de8ce47ad38d41fca3ddcccb90686193f99d00436c1ff70422d7e536371dd444eaad98503"
          }
        },
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:53:24.978Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "RWS7tp1uhbegjwO-Hx0h5Kaivw4SqiBf1LWXx7qiv-w"
            },
            "rate": {
              "contentType": "article",
              "title": "Big Beard: Growing and Managing Unruly, Big Beards",
              "url":
                  "https://thebeardclub.com/blogs/beard-culture/how-to-overcome-the-challenges-of-a-big-beard"
            },
            "with": {"recommend": true},
            "comment": "Rad!",
            "signature":
                "595a051c184751029ff38906fce6e972995635b36f9936745fd3c75598ddde395f3a040962192957edef76f32b4d1c6cb5aa832862a5596b1576f468f53e440c"
          }
        }
      ]
    },
    {
      "subject": {
        "contentType": "article",
        "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
        "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
      },
      "props": {"recommend": 1, "numComments": 0, "recentActivity": "10/10/2024 1:53 PM"},
      "children": [
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:53:25.179Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "27ntcunav4EZxDiqimmjpSaQ6NQUV8z1doAT9N8TVfo"
            },
            "rate": {
              "contentType": "article",
              "title": "25+ Coolest Sleeve Tattoos for Men  | Man of Many",
              "url": "https://manofmany.com/entertainment/art/coolest-sleeve-tattoos"
            },
            "with": {"recommend": true},
            "signature":
                "5cc49f2fb7a3d89ec2b39398eb34f5c050774b71dc719ce47398026afb0ff9c35d28343198d118dc8b414c50aedd46390281f8eba2cdabb3514dc020df4f0509"
          }
        }
      ]
    },
    {
      "subject": {
        "contentType": "video",
        "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
        "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
      },
      "props": {"recommend": 1, "numComments": 1, "recentActivity": "10/10/2024 1:53 PM"},
      "children": [
        {
          "subject": {
            "statement": "org.nerdster",
            "time": "2024-10-10T20:53:24.934Z",
            "I": {
              "crv": "Ed25519",
              "kty": "OKP",
              "x": "QOlIS9l5gDh4xIcz1KNC2Er54Z_0FpUHe_6tvCT6dVo"
            },
            "rate": {
              "contentType": "video",
              "title": "Russell Wilson Top 10 Plays with Seahawks - YouTube",
              "url": "https://www.youtube.com/watch?v=CkZ8VHfmdiU"
            },
            "with": {"recommend": true},
            "comment": "Sick!",
            "signature":
                "f5d49f8aa9169cce79ec23dec4e44b58f12e196f054ad048c6c3f3805ef905f935d16c12846a8f7d57600ca037b77984173e7686599a318db60ab6fafbfaac0e"
          }
        }
      ]
    }
  ]
};
