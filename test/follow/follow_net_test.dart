import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/demotest/cases/delegate_merge.dart';
import 'package:nerdster/demotest/cases/egos.dart';
import 'package:nerdster/demotest/cases/simpsons.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/follow/follow_net.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:test/test.dart';

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  DemoKey dummy = await DemoKey.findOrCreate('dummy');
  DemoKey homer = dummy;
  DemoKey homer2 = dummy;
  DemoKey marge = dummy;
  DemoKey bart = dummy;
  DemoKey lisa = dummy;
  DemoKey maggie = dummy;
  DemoKey lenny = dummy;
  DemoKey carl = dummy;
  DemoKey burns = dummy;
  DemoKey smithers = dummy;
  DemoKey milhouse = dummy;
  DemoKey luann = dummy;
  DemoKey sideshow = dummy;
  DemoKey bartN = dummy;
  DemoKey lisaN = dummy;
  DemoKey milhouseN = dummy;
  DemoKey homer2N = dummy;
  DemoKey carlN = dummy;
  DemoKey burnsN = dummy;
  DemoKey margeN = dummy;

  setUp(() async {
    useClock(TestClock());
    DemoKey.clear();
    signInState.signOut();
    oneofusNet.numPaths = 1;
    followNet.fcontext = kOneofusContext;
    Prefs.showKeys.value = false;
    Prefs.showStatements.value = false;
    await FireFactory.clearPersistence();
  });

  loadSimpsons() {
    homer = DemoKey.findByName('homer')!;
    homer2 = DemoKey.findByName('homer2')!;
    marge = DemoKey.findByName('marge')!;
    bart = DemoKey.findByName('bart')!;
    lisa = DemoKey.findByName('lisa')!;
    maggie = DemoKey.findByName('maggie')!;
    lenny = DemoKey.findByName('lenny')!;
    carl = DemoKey.findByName('carl')!;
    burns = DemoKey.findByName('burns')!;
    smithers = DemoKey.findByName('smithers')!;
    milhouse = DemoKey.findByName('milhouse')!;
    luann = DemoKey.findByName('luann')!;
    sideshow = DemoKey.findByName('sideshow')!;

    bartN = DemoKey.findByName('bart-nerdster0')!;
    lisaN = DemoKey.findByName('lisa-nerdster0')!;
    milhouseN = DemoKey.findByName('milhouse-nerdster0')!;
    homer2N = DemoKey.findByName('homer2-nerdster0')!;
    carlN = DemoKey.findByName('carl-nerdster0')!;
    burnsN = DemoKey.findByName('burns-nerdster0')!;
    margeN = DemoKey.findByName('marge-nerdster0')!;
  }

  test('base', () async {
    await simpsons();
    loadSimpsons();
    Fetcher.clear();
    signInState.center = bart.token;

    // maggie isn't in because she doesn't have a delegate
    followNet.fcontext = 'family';
    await Comp.waitOnComps([followNet, keyLabels]);
    Json expected = {
      "son": ["son-delegate"],
      "homer2": ["homer2-delegate"],
      "sis": ["sis-delegate"],
      "moms": ["moms-delegate"],
      "sister": []
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);
    expect(followNet.most, ['family', 'social', 'nerd', 'famigly']);
    expect(followNet.centerContexts, {'family', 'social', 'nerd'});

    followNet.fcontext = kOneofusContext;
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "son": ["son-delegate"],
      "friend": ["friend-delegate"],
      "sis": ["sis-delegate"],
      "homer2": ["homer2-delegate"],
      "moms": ["moms-delegate"],
      "clown": [],
      "mom": [],
      "sister": [],
      "mel": []
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    followNet.fcontext = 'nerd';
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "son": ["son-delegate"],
      "friend": ["friend-delegate"],
      "sis": ["sis-delegate"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    followNet.fcontext = 'social';
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "son": ["son-delegate"],
      "friend": ["friend-delegate"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);
  });

  test('base follow Oneofus without delegate', () async {
    DemoKey nerd1 = await DemoKey.findOrCreate('nerd1');
    DemoKey nerd1N = await nerd1.makeDelegate();
    DemoKey nerd2 = await DemoKey.findOrCreate('nerd2');
    // Should not be needed. DemoKey nerd2N = await nerd2.makeDelegate();
    await nerd1.doTrust(TrustVerb.trust, nerd2);
    await nerd1N.doFollow(nerd2, {'nerd': 1});
    followNet.fcontext = 'nerd';
    signInState.center = nerd1.token;
    await Comp.waitOnComps([followNet, keyLabels]);
    Json expected = {
      "Me": ["Me-delegate"],
      "nerd2": [],
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);
  });

  /// - multiple equivalents (2)
  /// - multiple delegates (2)
  /// rate same subject
  test('delegateMerge', () async {
    await delegateMerge();
  });

  test('2 delegates, same subject, clear', () async {
    DemoKey loner = await DemoKey.findOrCreate('loner');
    DemoKey lonerN = await loner.makeDelegate();
    DemoKey lonerN2 = await loner.makeDelegate();
    Statement n1 = await lonerN.doRate(title: 't');
    Statement n2 = await lonerN2.doRate(title: 't');

    signInState.center = loner.token;
    contentBase.listen();
    await Comp.waitOnComps([contentBase, keyLabels]);
    myExpect(contentBase.roots.length, 1);

    // Either should work
    if (Random().nextBool()) {
      await lonerN.doRate(title: 't', verb: ContentVerb.clear);
    } else {
      await lonerN2.doRate(title: 't', verb: ContentVerb.clear);
    }
    contentBase.listen();
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(followNet.getStatements(loner.token).first.verb, ContentVerb.clear);
    myExpect(contentBase.roots.length, 0);
  });

  test('2 delegates, differet subjects, clear', () async {
    DemoKey loner = await DemoKey.findOrCreate('loner');
    DemoKey lonerN = await loner.makeDelegate();
    DemoKey lonerN2 = await loner.makeDelegate();
    Statement n1 = await lonerN.doRate(title: 't1');
    Statement n2 = await lonerN2.doRate(title: 't2');

    signInState.center = loner.token;
    contentBase.listen();
    await Comp.waitOnComps([contentBase, keyLabels]);
    myExpect(contentBase.roots.length, 2);

    // Either should work
    if (Random().nextBool()) {
      await lonerN.doRate(title: 't1', verb: ContentVerb.clear);
    } else {
      await lonerN2.doRate(title: 't2', verb: ContentVerb.clear);
    }
    contentBase.listen();
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(followNet.getStatements(loner.token).length, 2);
    myExpect(contentBase.roots.length, 1);
  });

  test('''bo and luke rate; bo claims luke's delegate; should see 1 rating''', () async {
    DemoKey bo = await DemoKey.findOrCreate('bo');
    DemoKey luke = await DemoKey.findOrCreate('luke');
    await bo.doTrust(TrustVerb.trust, luke);
    await luke.doTrust(TrustVerb.trust, bo);
    DemoKey boN = await bo.makeDelegate();
    DemoKey lukeN = await luke.makeDelegate();
    await boN.doRate(title: 't', recommend: true);
    await lukeN.doRate(title: 't', recommend: true);

    signInState.center = bo.token;
    await Comp.waitOnComps([contentBase, keyLabels]);
    myExpect(contentBase.roots.length, 1);
    ContentTreeNode cn = contentBase.roots.first;
    expect(cn.getChildren().length, 2); // 2 ratings

    Statement boClaimsLukes = await bo.doTrust(TrustVerb.delegate, lukeN);

    signInState.center = bo.token;
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(oneofusNet.network.keys, [bo.token, luke.token]);
    // Check rejection
    // (I don't have the rejected statement here because it's not returned by luke.makeDelegate)
    expect(notifications.rejected.values, {"Delegate already claimed."});
    expect(oneofusEquiv.oneofus2delegates[luke.token], Set());
    expect(oneofusEquiv.oneofus2delegates[bo.token], {boN.token, lukeN.token});
    myExpect(contentBase.roots.length, 1);
    cn = contentBase.roots.first;
    expect(cn.getChildren().length, 1); // 2 ratings

    //
    signInState.center = luke.token;
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(notifications.rejected, {boClaimsLukes.token: "Delegate already claimed."});
  });

  test('clear, 2 equivs', () async {
    DemoKey somebodyElse = await DemoKey.findOrCreate('somebodyElse');

    DemoKey loner = await DemoKey.findOrCreate('loner');
    DemoKey lonerN = await loner.makeDelegate();
    Statement n1 = await lonerN.doRate(title: 't');

    Statement s1 = await loner.doTrust(TrustVerb.block, somebodyElse);
    DemoKey loner2 = await DemoKey.findOrCreate('loner2');
    await loner2.doTrust(TrustVerb.replace, loner, revokeAt: s1.token);
    DemoKey loner2N = await loner2.makeDelegate();
    Statement n2 = await loner2N.doRate(title: 't');

    signInState.center = loner2.token;
    followNet.listen();
    contentBase.listen();
    await Comp.waitOnComps([contentBase, keyLabels]);
    myExpect(contentBase.roots.length, 1);
    myExpect(contentBase.roots.first.getChildren().length, 1);

    // This delegate is inherited, revoked, and so
    // Either should work
    if (Random().nextBool()) {
      Statement n3 = await loner2N.doRate(title: 't', verb: ContentVerb.clear);
    } else {
      Statement n4 = await lonerN.doRate(title: 't', verb: ContentVerb.clear);
    }
    contentBase.listen();
    followNet.listen();
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(followNet.getStatements(loner2.token).length, 1);
    myExpect(contentBase.roots.length, 0);
  });

  test('!canon follow !canon', () async {
    var expected;
    DemoKey somebodyElse = await DemoKey.findOrCreate('somebodyElse');

    DemoKey bob = await DemoKey.findOrCreate('bob');
    DemoKey bobN = await bob.makeDelegate();
    DemoKey steve = await DemoKey.findOrCreate('steve');
    DemoKey steveN = await steve.makeDelegate();
    Statement b1 = await bob.doTrust(TrustVerb.block, somebodyElse);
    Statement s1 = await steve.doTrust(TrustVerb.block, somebodyElse);
    DemoKey steve2 = await DemoKey.findOrCreate('steve2');
    await steve2.doTrust(TrustVerb.replace, steve, revokeAt: s1.token);
    DemoKey bob2 = await DemoKey.findOrCreate('bob2');
    await bob2.doTrust(TrustVerb.replace, bob, revokeAt: b1.token);
    await bob2.doTrust(TrustVerb.trust, steve2);

    // (bob2 replaced bob; steve2 replaced steve; bob2 trusts steve2
    // all 4 in oneofus; each has 2 delegates.)
    signInState.center = bob2.token;
    await Comp.waitOnComps([oneofusNet, keyLabels]);
    expected = {
      "Me": null,
      "Me (0)": "5/1/2024 12:03 AM",
      "steve2": null,
      "steve2 (0)": "5/1/2024 12:04 AM"
    };
    jsonShowExpect(dumpNetwork(oneofusNet.network), expected);

    // steve doesn't trust bob and has 1 delegate
    signInState.center = steve2.token;
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // Now the test: fcontext = null
    signInState.center = bob2.token;
    followNet.fcontext = kOneofusContext;
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate"],
      "steve2": ["steve2-delegate"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // Now the test: fcontext = social
    signInState.center = bob2.token;
    followNet.fcontext = 'social';
    await bobN.doFollow(steve, {'social': 1});
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate"],
      "steve2": ["steve2-delegate"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);
  });

  test('!canon follow !canon, multiple delegates', () async {
    var expected;
    DemoKey somebodyElse = await DemoKey.findOrCreate('somebodyElse');

    DemoKey bob = await DemoKey.findOrCreate('bob');
    DemoKey bobN = await bob.makeDelegate();
    DemoKey steve = await DemoKey.findOrCreate('steve');
    DemoKey steveN = await steve.makeDelegate();
    Statement b1 = await bob.doTrust(TrustVerb.block, somebodyElse);
    Statement s1 = await steve.doTrust(TrustVerb.block, somebodyElse);
    DemoKey steve2 = await DemoKey.findOrCreate('steve2');
    await steve2.doTrust(TrustVerb.replace, steve, revokeAt: s1.token);
    DemoKey steve2N = await steve2.makeDelegate();
    DemoKey bob2 = await DemoKey.findOrCreate('bob2');
    await bob2.doTrust(TrustVerb.replace, bob, revokeAt: b1.token);
    DemoKey bob2N = await bob2.makeDelegate();
    await bob2.doTrust(TrustVerb.trust, steve2);

    // (bob2 replaced bob; steve2 replaced steve; bob2 trusts steve2
    // all 4 in oneofus; each has 2 delegates.)
    signInState.center = bob2.token;
    await Comp.waitOnComps([oneofusNet, keyLabels]);
    expected = {
      "Me": null,
      "Me (0)": "5/1/2024 12:03 AM",
      "steve2": null,
      "steve2 (0)": "5/1/2024 12:04 AM"
    };
    jsonShowExpect(dumpNetwork(oneofusNet.network), expected);

    // (steve doesn't trust bob and has 2 delegates)
    signInState.center = steve2.token;
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate", "Me-delegate (0)"],
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // Now the test: fcontext = null
    signInState.center = bob2.token;
    followNet.fcontext = kOneofusContext;
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate", "Me-delegate (0)"],
      "steve2": ["steve2-delegate", "steve2-delegate (0)"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // Now the test: fcontext = social
    followNet.fcontext = 'social';
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate", "Me-delegate (0)"],
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // (signInState.center = bob2.token;)
    followNet.fcontext = 'social';
    await bobN.doFollow(steve, {'social': 1}); // !canon follow !canon
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate", "Me-delegate (0)"],
      "steve2": ["steve2-delegate", "steve2-delegate (0)"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // Now have bob2 and steve2 claim their older delegates (nothing should change, other than
    // maybe notifications, rejections)
    await bob2.doTrust(TrustVerb.delegate, bobN);
    await steve2.doTrust(TrustVerb.delegate, steveN);
    oneofusEquiv.listen();
    // (signInState.center = bob2.token;)
    followNet.fcontext = kOneofusContext;
    await Comp.waitOnComps([followNet, keyLabels]);
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // (signInState.center = bob2.token;)
    followNet.fcontext = 'social';
    // (await bobN.doFollow(steve, {'social': 1});)
    await Comp.waitOnComps([followNet, keyLabels]);
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // Use this opportunity to check a litte about rejections of claim delegate statements
    expect(followNet.delegate2oneofus[bob2N.token], bob2.token);
    expect(followNet.delegate2oneofus[bobN.token], bob2.token);
    expect(followNet.oneofus2delegates[bob2.token], {bobN.token, bob2N.token});
    expect(followNet.oneofus2delegates[bob.token], null);
    // We don't have the delegate statements right here (not returned by luke.makeDelegate), and
    // so I'll just count them  instead of comparing them
    expect(notifications.rejected.length, 2);
  });

  test('follow !oneofus', () async {
    var expected;
    // bob doesn't trust steve
    DemoKey bob = await DemoKey.findOrCreate('bob');
    DemoKey bobN = await bob.makeDelegate();
    DemoKey steve = await DemoKey.findOrCreate('steve');
    DemoKey steveN = await steve.makeDelegate();
    await steveN.doRate(title: 't');

    signInState.center = bob.token;
    await Comp.waitOnComps([oneofusNet, keyLabels]);
    var network = oneofusNet.network;
    var expectedNetwork = {
      "Me": null,
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    followNet.listen();
    contentBase.listen();
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate"],
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // bob doesn't trust steve, but bobN follows steve.
    await bobN.doFollow(steve, {'social': 1});
    followNet.fcontext = 'social';
    await Comp.waitOnComps([followNet, keyLabels]);
    expected = {
      "Me": ["Me-delegate"],
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);
  });

  test('canon and other follow varieties', () async {
    // This test is messier than the better, classic unit tests. It's here, could probably be removed.
    var expected;
    DemoKey somebodyElse = await DemoKey.findOrCreate('somebodyElse');

    DemoKey bob = await DemoKey.findOrCreate('bob');
    DemoKey bobN = await bob.makeDelegate();
    await bobN.doRate(title: 'bobN');

    DemoKey steve = await DemoKey.findOrCreate('steve');
    DemoKey steveN = await steve.makeDelegate();
    await steveN.doRate(title: 'steveN');
    Statement s1 = await steve.doTrust(TrustVerb.block, somebodyElse);
    DemoKey steve2 = await DemoKey.findOrCreate('steve2');
    await steve2.doTrust(TrustVerb.replace, steve, revokeAt: s1.token);
    DemoKey steve2N = await steve2.makeDelegate();
    await steve2N.doRate(title: 'steve2N');
    Statement s2 = await bob.doTrust(TrustVerb.trust, steve2);

    signInState.center = bob.token;
    await Comp.waitOnComps([oneofusNet, keyLabels, contentBase]); //
    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null, "steve2": null, "steve2 (0)": "5/1/2024 12:05 AM"};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    followNet.listen();
    contentBase.listen();
    await Comp.waitOnComps([followNet, keyLabels, contentBase]);
    expected = {
      "Me": ["Me-delegate"],
      "steve2": ["steve2-delegate", "steve2-delegate (0)"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    await bobN.doFollow(steve, {'social': 1});
    followNet.fcontext = 'social';
    await Comp.waitOnComps([followNet, keyLabels, contentBase]);
    expected = {
      "Me": ["Me-delegate"],
      "steve2": ["steve2-delegate", "steve2-delegate (0)"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    await bobN.doFollow(steve, {}, verb: ContentVerb.clear);
    await bobN.doFollow(steve2, {'social': 1});
    followNet.fcontext = 'social';
    await Comp.waitOnComps([followNet, keyLabels, contentBase]);
    expected = {
      "Me": ["Me-delegate"],
      "steve2": ["steve2-delegate", "steve2-delegate (0)"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    await bobN.doFollow(steve2, {}, verb: ContentVerb.clear);
    followNet.fcontext = 'social';
    await Comp.waitOnComps([followNet, keyLabels, contentBase]);
    expected = {
      "Me": ["Me-delegate"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    // Now replace bob so that he's also !canon
    DemoKey bob2 = await DemoKey.findOrCreate('bob2');
    await bob2.doTrust(TrustVerb.replace, bob, revokeAt: s2.token);
    signInState.center = bob2.token;
    followNet.fcontext = 'social';
    await Comp.waitOnComps([oneofusNet, keyLabels, contentBase]);
    network = oneofusNet.network;
    expectedNetwork = {
      "Me": null,
      "Me (0)": "5/1/2024 12:09 AM",
      "steve2": null,
      "steve2 (0)": "5/1/2024 12:05 AM"
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);
    await Comp.waitOnComps([followNet, keyLabels, contentBase]);
    expected = {
      "Me": ["Me-delegate"],
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);

    followNet.fcontext = kOneofusContext;
    await Comp.waitOnComps([followNet, keyLabels, contentBase]);
    expected = {
      "Me": ["Me-delegate"],
      "steve2": ["steve2-delegate", "steve2-delegate (0)"]
    };
    jsonShowExpect(followNet.oneofus2delegates, expected);
  });

  /// This test is in response to a bug.
  /// Switching between context='social' and context=null was acting strangely.
  test('poser social follow bug', () async {
    var (poser, delegate) = await egos();

    DemoKey hipster = DemoKey.findByName('hipster')!;
    DemoKey hipDel0 = DemoKey.findByName('hipster-nerdster0')!;
    DemoKey hipDel1 = DemoKey.findByName('hipster-nerdster1')!;

    signInState.center = poser.token;
    await contentBase.waitUntilReady();
    expect(contentBase.roots.length, 2);
    Map<String, String?> delegate2revokedAt =
        followNet.delegate2fetcher.map((d, f) => MapEntry(d, f.revokeAt));
    List<String> ss = List.of(followNet.getStatements(hipster.token).map((s) => s.token));
    Set<String> hipDels = followNet.oneofus2delegates[hipster.token]!;
    String? hipDel0r = followNet.delegate2fetcher[hipDel0.token]!.revokeAt;
    String? hipDel1r = followNet.delegate2fetcher[hipDel1.token]!.revokeAt;
    List<String> hipDel0rSs =
        List.of(followNet.delegate2fetcher[hipDel0.token]!.statements.map((s) => s.token));
    List<String> hipDel1rSs =
        List.of(followNet.delegate2fetcher[hipDel1.token]!.statements.map((s) => s.token));

    followNet.fcontext = 'social';
    await contentBase.waitUntilReady();
    expect(contentBase.roots.length, 2);
    Map<String, String?> delegate2revokedAt2 =
        followNet.delegate2fetcher.map((d, f) => MapEntry(d, f.revokeAt));
    expect(delegate2revokedAt2, delegate2revokedAt);
    List<String> ss2 = List.of(followNet.getStatements(hipster.token).map((s) => s.token));
    expect(ss2, ss);
    Set<String> hipDels2 = followNet.oneofus2delegates[hipster.token]!;
    expect(hipDels2, hipDels);

    oneofusNet.listen();
    await contentBase.waitUntilReady();
    expect(contentBase.roots.length, 2);
    Map<String, String?> delegate2revokedAt3 =
        followNet.delegate2fetcher.map((d, f) => MapEntry(d, f.revokeAt));
    expect(delegate2revokedAt3, delegate2revokedAt);
    Set<String> hipDels3 = followNet.oneofus2delegates[hipster.token]!;
    expect(hipDels3, hipDels);
    String? hipDel0r3 = followNet.delegate2fetcher[hipDel0.token]!.revokeAt;
    expect(hipDel0r3, hipDel0r);
    String? hipDel1r3 = followNet.delegate2fetcher[hipDel1.token]!.revokeAt;
    expect(hipDel1r3, hipDel1r);
    List<String> hipDel1rSs3 =
        List.of(followNet.delegate2fetcher[hipDel1.token]!.statements.map((s) => s.token));
    expect(hipDel1rSs3, hipDel1rSs);
    List<String> hipDel0rSs3 =
        List.of(followNet.delegate2fetcher[hipDel0.token]!.statements.map((s) => s.token));
    expect(hipDel0rSs3, hipDel0rSs);
    List<String> ss3 = List.of(followNet.getStatements(hipster.token).map((s) => s.token));
    expect(ss3, ss);
  });

  /// Bart blocks lisa for social, and when centered as lisa, that's
  /// appropriately rejected.
  test('lisa social', () async {
    await simpsons();
    loadSimpsons();

    followNet.fcontext = 'family';
    signInState.center = lisa.token;
    await Comp.waitOnComps([followNet, keyLabels]);
    jsonShowExpect(followNet.delegate2oneofus,
        {"daughter-delegate": "daughter", "mom-delegate": "mom", "son-delegate": "son"});

    followNet.fcontext = 'social';
    signInState.center = lisa.token;
    await Comp.waitOnComps([followNet, keyLabels]);
    jsonShowExpect(followNet.delegate2oneofus,
        {"daughter-delegate": "daughter", "son-delegate": "son", "friend-delegate": "friend"});
  });

  test('bart default', () async {
    await simpsons();
    loadSimpsons();

    followNet.fcontext = kNerdsterContext;
    signInState.center = bart.token;
    await Comp.waitOnComps([followNet, keyLabels]);
    jsonShowExpect(followNet.delegate2oneofus, {
      "son-delegate": "son",
      "homer2-delegate": "homer2",
      "friend-delegate": "friend",
      "moms-delegate": "moms"
    });
  });

  // This test was used to fix a bug
  test('followNet subset of oneofusNet', () async {
    await simpsons();
    loadSimpsons();

    Prefs.oneofusNetDegrees.value = 2;
    Prefs.followNetDegrees.value = 3;
    followNet.fcontext = kNerdsterContext;

    signInState.center = bart.token;
    await Comp.waitOnComps([followNet, keyLabels]);

    expect((Set.of(oneofusNet.network.keys)).containsAll(followNet.oneofus2delegates.keys), true);
  });
}
