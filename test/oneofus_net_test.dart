import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/block_replaced_key.dart';
import 'package:nerdster/demotest/cases/equivalent_keys_state_conflict.dart';
import 'package:nerdster/demotest/cases/multiple_blocks.dart';
import 'package:nerdster/demotest/cases/trust_block_conflict.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/net/net_node.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/greedy_bfs_trust.dart';
import 'package:nerdster/trust/trust.dart';
import 'package:test/test.dart';

printStatement(String statementToken) {
  TrustStatement statement = TrustStatement.find(statementToken)!;
  String string = encoder.convert(keyLabels.show(statement));
  print(string);
}

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  DemoKey homer = await DemoKey.findOrCreate('dummy');
  DemoKey homer2 = await DemoKey.findOrCreate('dummy');
  DemoKey marge = await DemoKey.findOrCreate('dummy');
  DemoKey bart = await DemoKey.findOrCreate('dummy');
  DemoKey lisa = await DemoKey.findOrCreate('dummy');
  DemoKey maggie = await DemoKey.findOrCreate('dummy');
  DemoKey lenny = await DemoKey.findOrCreate('dummy');
  DemoKey carl = await DemoKey.findOrCreate('dummy');
  DemoKey burns = await DemoKey.findOrCreate('dummy');
  DemoKey smithers = await DemoKey.findOrCreate('dummy');
  DemoKey milhouse = await DemoKey.findOrCreate('dummy');
  DemoKey luann = await DemoKey.findOrCreate('dummy');
  DemoKey sideshow = await DemoKey.findOrCreate('dummy');

  setUp(() async {
    timezoneOffsetKludge = 0;
    useClock(TestClock());
    DemoKey.clear();
    signInState.signOut();
    await signInState.signIn(Jsonish({}).token, null); // unnecessary.
    oneofusNet.degrees = 6;
    oneofusNet.numPaths = 1;
    followNet.fcontext = null;
    Prefs.showKeys.value = false;
    Prefs.showStatements.value = false;
    await FireFactory.clearPersistence();

    homer = await DemoKey.findOrCreate('homer');
    homer2 = await DemoKey.findOrCreate('homer2');
    marge = await DemoKey.findOrCreate('marge');
    bart = await DemoKey.findOrCreate('bart');
    lisa = await DemoKey.findOrCreate('lisa');
    maggie = await DemoKey.findOrCreate('maggie');
    lenny = await DemoKey.findOrCreate('lenny');
    carl = await DemoKey.findOrCreate('carl');
    burns = await DemoKey.findOrCreate('burns');
    smithers = await DemoKey.findOrCreate('smithers');
    milhouse = await DemoKey.findOrCreate('milhouse');
    luann = await DemoKey.findOrCreate('luann');
    sideshow = await DemoKey.findOrCreate('sideshow');
  });

  test('base', () async {
    int i = 0;
    await lisa.doTrust(TrustVerb.trust, marge);
    await lisa.doTrust(TrustVerb.trust, homer);
    await homer.doTrust(TrustVerb.trust, lisa); // wihtout this we're "Me".

    signInState.center = lisa.token;
    await keyLabels.waitUntilReady();
    var network = oneofusNet.network;
    var expectedNetwork = {"lisa": null, "homer": null, "marge": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {
      "N:lisa-true:": {
        "N:homer-true:lisa": {"N:lisa-true:lisa->homer": {}},
        "N:marge-true:lisa": {}
      }
    };
    jsonShowExpect(dump, expectedTree);
  });

  test('blockReplacedKey', () async {
    await blockReplacedKey();
  });

  test('equivalentKeysStateConflict', () async {
    await equivalentKeysStateConflict();
  });

  test('multipleBlocks', () async {
    await multipleBlocks();
  });

  test('trustBlockConflict', () async {
    await trustBlockConflict();
  });

  test('revoke me rejected', () async {
    Statement s1 = await homer.doTrust(TrustVerb.trust, sideshow);
    Statement replaceStatement =
        await sideshow.doTrust(TrustVerb.replace, homer, revokeAt: s1.token);

    await signInState.signIn(homer.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null, "sideshow": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    // expect a rejected statement.
    expect(notifications.rejected.length, 1);
    expect(notifications.rejected.keys.first, replaceStatement.token);
    // homer remains canonical
    expect(oneofusEquiv.getCanonical(homer.token), homer.token);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {
      "N:Me-true:": {"N:sideshow-true:Me": {}}
    };
    jsonShowExpect(dump, expectedTree);
  });

  // UI should prevent this, but the backend should also prevernt it.
  test('''don't trust myself''', () async {
    Statement s1 = await bart.doTrust(TrustVerb.trust, bart);

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    // expect a rejected statement.
    expect(notifications.rejected.length, 1);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {"N:Me-true:": {}};
    jsonShowExpect(dump, expectedTree);
  });

  test('''3'rd level block rejected on 1'st level trust''', () async {
    await bart.doTrust(TrustVerb.trust, homer);
    await homer.doTrust(TrustVerb.trust, marge);
    await marge.doTrust(TrustVerb.trust, lisa);
    Statement lisaBlocksHomer = await lisa.doTrust(TrustVerb.block, homer);

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    jsonExpect(notifications.rejected, {lisaBlocksHomer.token: 'Attempt to block trusted key.'});
  });

  test('''3'rd level replace succeeds on 1'st level trust''', () async {
    await bart.doTrust(TrustVerb.trust, homer);
    Statement s = await homer.doTrust(TrustVerb.trust, marge);
    await marge.doTrust(TrustVerb.trust, lisa);
    Statement lisaReplacesHomer = await lisa.doTrust(TrustVerb.replace, homer, revokeAt: s.token);

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(notifications.rejected.isEmpty, true);
    expect(notifications.rejected.containsKey(lisaReplacesHomer.token), false);
    expect(oneofusEquiv.getCanonical(homer.token), lisa.token);
  });

  /// Self be-heading
  /// This one is unusual and challenging to understand.
  ///
  /// Homer's mistake here is that he revokes his old key too early,
  /// after he trusted marge, who later signs off on replacing the key
  /// that trusted her.
  ///
  /// See some related nonsense in decapitate.dart
  test('3\'rd level replaces 1\'st level trust', () async {
    Statement s2 = await homer.doTrust(TrustVerb.trust,
        lenny); // I added this because I need a statement. I could block, but that's above.
    await bart.doTrust(TrustVerb.trust, homer);
    await homer.doTrust(TrustVerb.trust, marge);
    await marge.doTrust(TrustVerb.trust, lisa);
    await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token);
    await marge.doTrust(TrustVerb.trust, homer2);

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null, "homer": "5/1/2024 12:01 AM", "lenny": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    await compareNetworkToTree(bart.token);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {
      "N:Me-true:": {
        "N:homer-true:5/1/2024 12:01 AM:Me": {"N:lenny-true:Me->homer": {}}
      }
    };
    jsonShowExpect(dump, expectedTree);
  });

  test('3\'rd level replaces 1\'st level trust, homer better', () async {
    await homer.doTrust(TrustVerb.trust, lenny);
    await bart.doTrust(TrustVerb.trust, homer);
    Statement s2 = await homer.doTrust(TrustVerb.trust, marge);
    await marge.doTrust(TrustVerb.trust, lisa);
    await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token);
    await marge.doTrust(TrustVerb.trust, homer2);

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {
      "Me": null,
      "homer": "5/1/2024 12:03 AM",
      "marge": null,
      "lenny": null,
      "homer2": null,
      "lisa": null
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {
      "N:Me-true:": {
        "N:homer2-true:Me": {
          "N:marge-true:Me->homer2": {
            "N:homer2-true:Me->homer2->marge": {},
            "N:lisa-true:Me->homer2->marge": {}
          },
          "N:lenny-true:Me->homer2": {}
        }
      }
    };
    jsonShowExpect(dump, expectedTree);

    await compareNetworkToTree(bart.token);
  });

  test('diamond trust', () async {
    await homer.doTrust(TrustVerb.trust, lisa);
    await homer.doTrust(TrustVerb.trust, bart);
    await bart.doTrust(TrustVerb.trust, marge);
    await lisa.doTrust(TrustVerb.trust, marge);

    await signInState.signIn(homer.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null, "bart": null, "lisa": null, "marge": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {
      "N:Me-true:": {
        "N:bart-true:Me": {"N:marge-true:Me->bart": {}},
        "N:lisa-true:Me": {"N:marge-true:Me->lisa": {}}
      }
    };
    jsonShowExpect(dump, expectedTree);

    await compareNetworkToTree(homer.token);
  });

  test('diamond trust, 2 paths (not great)', () async {
    // (Correct, works as intended, but not necessarily great:
    // Marge is trusted via 2 paths, but the nerds on those paths are not in the network,
    // and so Marge isn't trusted.)
    await homer.doTrust(TrustVerb.trust, lisa);
    await homer.doTrust(TrustVerb.trust, bart);
    await bart.doTrust(TrustVerb.trust, marge);
    await lisa.doTrust(TrustVerb.trust, marge);

    await signInState.signIn(homer.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    oneofusNet.numPaths = 2;
    assert(!oneofusEquiv.ready);

    await oneofusEquiv.waitUntilReady();
    assert(oneofusEquiv.ready);
    assert(oneofusNet.ready);
    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {"N:Me-true:": {}};
    jsonShowExpect(dump, expectedTree);
  });

  test('diamond trust, 2 paths, redux', () async {
    await homer.doTrust(TrustVerb.trust, lisa);
    await homer.doTrust(TrustVerb.trust, bart);
    await bart.doTrust(TrustVerb.trust, marge);
    await lisa.doTrust(TrustVerb.trust, marge);
    await bart.doTrust(TrustVerb.trust, lisa);
    await lisa.doTrust(TrustVerb.trust, bart);

    oneofusNet.numPaths = 2;
    await signInState.signIn(homer.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null, "bart": null, "lisa": null, "marge": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expectedTree = {
      "N:Me-true:": {
        "N:bart-true:Me": {
          "N:lisa-true:Me->bart": {
            "N:bart-true:Me->bart->lisa": {},
            "N:marge-true:Me->bart->lisa": {}
          },
          "N:marge-true:Me->bart": {}
        },
        "N:lisa-true:Me": {
          "N:bart-true:Me->lisa": {
            "N:lisa-true:Me->lisa->bart": {},
            "N:marge-true:Me->lisa->bart": {}
          },
          "N:marge-true:Me->lisa": {}
        }
      }
    };
    jsonShowExpect(dump, expectedTree);
  });

  test('nameless', () async {
    await bart.doTrust(TrustVerb.trust, homer);
    Statement s = await homer.doTrust(TrustVerb.trust, bart);
    await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s.token);
    await bart.doTrust(TrustVerb.clear, homer);
    await bart.doTrust(TrustVerb.trust, homer2);

    // There used to be a problem here: Bart doesn't know homer's name.
    // homer is in the network because bart =>(trust) homer2 =>(replace) homer.
    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(keyLabels.labelKey(homer2.token), 'homer2');
    expect(keyLabels.labelKey(homer.token), 'homer2 (0)');
  });

  test('homer2 replaces homer ago: lisa not trusted', () async {
    await bart.doTrust(TrustVerb.trust, homer);
    await lisa.doTrust(TrustVerb.trust, marge);
    await lisa.doTrust(TrustVerb.trust, homer);
    Statement s2 = await homer.doTrust(TrustVerb.trust, marge);
    await homer.doTrust(TrustVerb.trust, lisa);
    await marge.doTrust(TrustVerb.trust, burns);
    await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token); // lisa not trusted
    await bart.doTrust(TrustVerb.clear, homer);
    await bart.doTrust(TrustVerb.trust, homer2);

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {
      "Me": null,
      "homer2": null,
      "homer2 (0)": "5/1/2024 12:04 AM",
      "marge": null,
      "burns": null
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expected = {
      "N:Me-true:": {
        "N:homer2-true:Me": {
          "N:marge-true:Me->homer2": {"N:burns-true:Me->homer2->marge": {}}
        }
      }
    };
    jsonShowExpect(dump, expected);
  });

  test('homer2 replaces homer late: lisa trusted', () async {
    await bart.doTrust(TrustVerb.trust, homer);
    await lisa.doTrust(TrustVerb.trust, marge);
    await lisa.doTrust(TrustVerb.trust, homer);
    await homer.doTrust(TrustVerb.trust, marge);
    Statement s2 = await homer.doTrust(TrustVerb.trust, lisa);
    await marge.doTrust(TrustVerb.trust, burns);
    await homer2.doTrust(TrustVerb.replace, homer, revokeAt: s2.token); // lisa trusted.
    await bart.doTrust(TrustVerb.clear, homer);
    await bart.doTrust(TrustVerb.trust, homer2);

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {
      "Me": null,
      "homer2": null,
      "homer2 (0)": "5/1/2024 12:05 AM",
      "lisa": null,
      "marge": null,
      "burns": null
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expected = {
      "N:Me-true:": {
        "N:homer2-true:Me": {
          "N:lisa-true:Me->homer2": {
            "N:homer2-true:Me->homer2->lisa": {},
            "N:marge-true:Me->homer2->lisa": {"N:burns-true:Me->homer2->lisa->marge": {}}
          },
          "N:marge-true:Me->homer2": {"N:burns-true:Me->homer2->marge": {}}
        }
      }
    };
    jsonShowExpect(dump, expected);
  });

  test('overidden (distinct)', () async {
    await maggie.doTrust(TrustVerb.trust, homer);
    await maggie.doTrust(TrustVerb.block, bart); // to be overriden
    await maggie.doTrust(TrustVerb.trust, marge);
    await maggie.doTrust(TrustVerb.trust, bart); // overrides the earlier block.

    await signInState.signIn(maggie.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    dynamic dump = await OneofusTreeNode.root.dump();
    var expected = {
      "N:Me-true:": {"N:bart-true:Me": {}, "N:marge-true:Me": {}, "N:homer-true:Me": {}}
    };
    jsonShowExpect(dump, expected);
  });

  test('early blocks overriden by later trusts', () async {
    await maggie.doTrust(TrustVerb.trust, homer);
    await maggie.doTrust(TrustVerb.block, bart); // to be overriden
    await maggie.doTrust(TrustVerb.trust, marge);
    await maggie.doTrust(TrustVerb.block, bart); // to be overriden
    await maggie.doTrust(TrustVerb.trust, bart); // to be overriden
    await maggie.doTrust(TrustVerb.block, bart); // to be overriden
    await maggie.doTrust(TrustVerb.trust, marge); // repeat
    await maggie.doTrust(TrustVerb.trust, bart); // overrides the earlier block.

    await signInState.signIn(maggie.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    dynamic dump = await OneofusTreeNode.root.dump();
    var expected = {
      "N:Me-true:": {"N:bart-true:Me": {}, "N:marge-true:Me": {}, "N:homer-true:Me": {}}
    };
    jsonShowExpect(dump, expected);
  });

  test('Bad actor tries to replace key', () async {
    await homer.doTrust(TrustVerb.trust, bart);
    Statement s2 = await homer.doTrust(TrustVerb.trust, marge);
    Statement s3 = await sideshow.doTrust(TrustVerb.replace, homer, revokeAt: s2.token); // rejected
    await bart.doTrust(TrustVerb.trust, sideshow);

    await signInState.signIn(homer.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    expect(notifications.rejected.keys, {s3.token});
    dynamic dump = await OneofusTreeNode.root.dump();
    var expected = {
      "N:Me-true:": {
        "N:marge-true:Me": {},
        "N:bart-true:Me": {"N:sideshow-true:Me->bart": {}}
      }
    };
    jsonShowExpect(dump, expected);
  });

  test('Bad actor tries to replace replaced key', () async {
    Statement s2 = await homer.doTrust(TrustVerb.trust, bart);
    Statement s3 = await homer.doTrust(TrustVerb.trust, marge);
    await homer2.doTrust(TrustVerb.replace, homer,
        revokeAt: s2.token); // (marge not trusted, key already replaced.)
    Statement s4 = await sideshow.doTrust(TrustVerb.replace, homer, revokeAt: s3.token); // rejected
    await bart.doTrust(TrustVerb.trust, sideshow);

    await signInState.signIn(homer2.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    expect(notifications.rejected.containsKey(s4.token), true);
    expect(oneofusEquiv.getCanonical(homer.token), homer2.token);
    expect(oneofusEquiv.getCanonical(homer2.token), homer2.token);
    expect(oneofusEquiv.getEquivalents(homer2.token), {homer2.token, homer.token});
    expect(oneofusEquiv.getEquivalents(sideshow.token), {sideshow.token});

    var network = oneofusNet.network;
    var expectedNetwork = {
      "Me": null,
      "Me (0)": "5/1/2024 12:01 AM",
      "bart": null,
      "sideshow": null
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    dynamic dump = await OneofusTreeNode.root.dump();
    var expected = {
      "N:Me-true:": {
        "N:bart-true:Me": {"N:sideshow-true:Me->bart": {}}
      }
    };
    jsonShowExpect(dump, expected);
  });

  test('fixed bug, same key twice under single parent', () async {
    DemoKey key1 = await DemoKey.findOrCreate('key1');
    DemoKey key5 = await DemoKey.findOrCreate('key5');
    DemoKey key6 = await DemoKey.findOrCreate('key6');
    await key1.doTrust(TrustVerb.trust, key5);
    await key1.doTrust(TrustVerb.trust, key6);
    Statement s2 = await key1.doTrust(TrustVerb.trust, key6);

    DemoKey key2 = await DemoKey.findOrCreate('key2');
    await key2.doTrust(TrustVerb.replace, key1, revokeAt: s2.token);

    await key2.doTrust(TrustVerb.trust, key5);
    await key2.doTrust(TrustVerb.trust, key6);
    await key5.doTrust(TrustVerb.trust, key1);
    await key6.doTrust(TrustVerb.trust, key1);
    await key5.doTrust(TrustVerb.trust, key2);
    await key6.doTrust(TrustVerb.trust, key2);

    await signInState.signIn(key2.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    dynamic network = oneofusNet.network;
    dynamic dump = await OneofusTreeNode.root.dump();

    var expectedNetwork = {
      "key2": null,
      "key2 (0)": "5/1/2024 12:03 AM",
      "key6": null,
      "key5": null
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    var expectedDump = {
      "N:key2-true:": {
        "N:key6-true:key2": {"N:key2-true:key2->key6": {}},
        "N:key5-true:key2": {"N:key2-true:key2->key5": {}}
      }
    };
    jsonShowExpect(dump, expectedDump);
  });

  test('egos', () async {
    var (oneofus, delegate) = await DemoKey.demos['egos']();
    // TODO(2): dump statements. Currently, the different statement tokens are preventing me.
    await signInState.signIn(oneofus.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {"Me": null, "hipster": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    Prefs.keyLabel.value = true;

    await followNet.waitUntilReady();
    dynamic dump = await OneofusTreeNode.root.dump();
    var expected = {
      "N:Me-true:": {"N:hipster-true:Me": {}}
    };
    jsonShowExpect(dump, expected);
  });

  test('simpsons', () async {
    var (n, d) = await DemoKey.demos['simpsons']();
    expect(n, bart);
    expect(d, DemoKey.findByName('bart-nerdster0'));
    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {
      "son": null,
      "friend": null,
      "sis": null,
      "homer2": null,
      "moms": null,
      "homer2 (0)": "5/1/2024 12:09 AM",
      "clown": null,
      "mom": null,
      "sister": null,
      "mel": null
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    assert(oneofusEquiv.getCanonical(bart.token) == bart.token);

    // Prefs.nice.value = true;
    dynamic statementsDump = dumpStatements();
    // DEFER: This can't quite work yet because the revoke at tokens.
    // I could make it work by converting tokens of statements to tokens of
    // the same statements but piped though NetBase().show..
    // expect(statementsDump, simpsonsStatementsDump);
    // print(Jsonish.encoder.convert(statementsDump));

    dynamic treeDump = await OneofusTreeNode.root.dump();

    expect(oneofusEquiv.getCanonical(homer2.token), homer2.token);
    expect(oneofusEquiv.getEquivalents(homer2.token), {homer.token, homer2.token});
    expect(keyLabels.show(oneofusEquiv.getCanonical(homer.token)), keyLabels.show(homer2.token));
  });

  /// This test does not use [OneofusNet] but does use its [FetcherNode].
  /// Ideally, I would have unit tests for [Trust1].
  test('degrees base', () async {
    DemoKey d1 = await DemoKey.findOrCreate('1');
    DemoKey d2 = await DemoKey.findOrCreate('2');
    DemoKey d3 = await DemoKey.findOrCreate('3');
    await d1.doTrust(TrustVerb.trust, d2);
    await d2.doTrust(TrustVerb.trust, d3);

    GreedyBfsTrust trust1;
    Map<String, Node> network;

    trust1 = GreedyBfsTrust(degrees: 1);
    network = await trust1.process(FetcherNode(d1.token), notifier: notifications);
    expect(network.keys, [d1.token]);

    trust1 = GreedyBfsTrust(degrees: 2);
    network = await trust1.process(FetcherNode(d1.token), notifier: notifications);
    expect(network.keys, [d1.token, d2.token]);

    trust1 = GreedyBfsTrust(degrees: 3);
    network = await trust1.process(FetcherNode(d1.token), notifier: notifications);
    expect(network.keys, [d1.token, d2.token, d3.token]);
  });

  test('degrees base block', () async {
    DemoKey d1 = await DemoKey.findOrCreate('1');
    DemoKey d21 = await DemoKey.findOrCreate('2.1');
    DemoKey d22 = await DemoKey.findOrCreate('2.2');
    DemoKey d3 = await DemoKey.findOrCreate('3');
    await d1.doTrust(TrustVerb.trust, d21);
    await d1.doTrust(TrustVerb.trust, d22);
    Statement block = await d21.doTrust(TrustVerb.block, d22);
    await d21.doTrust(TrustVerb.trust, d3);

    GreedyBfsTrust trust1;
    Map<String, Node> network;

    trust1 = GreedyBfsTrust(degrees: 1);
    notifications.clear();
    network = await trust1.process(FetcherNode(d1.token), notifier: notifications);
    expect(network.keys, [d1.token]);
    expect(notifications.rejected.length, 0);

    trust1 = GreedyBfsTrust(degrees: 2);
    notifications.clear();
    network = await trust1.process(FetcherNode(d1.token), notifier: notifications);
    jsonExpect(notifications.rejected, {block.token: "Attempt to block trusted key."});
    expect(notifications.rejected.length, 1);
    expect(network.keys, [d1.token, d22.token, d21.token]);

    trust1 = GreedyBfsTrust(degrees: 3);
    notifications.clear();
    network = await trust1.process(FetcherNode(d1.token), notifier: notifications);
    jsonExpect(notifications.rejected, {block.token: "Attempt to block trusted key."});
    expect(network.keys, [d1.token, d22.token, d21.token, d3.token]);
  });

  // Notification:
  // - Web-of-trust key equivalence rejected: Replaced key not in network.
  test('simpsons, degrees=2', () async {
    oneofusNet.degrees = 2;
    await DemoKey.demos['simpsons']();
    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {"son": null, "friend": null, "sis": null, "homer2": null, "moms": null};
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    // TEMP: expect(notifications.rejected.length, 0);
    expect(notifications.rejected.length, 1);
    MapEntry e = notifications.rejected.entries.first;
    String rejectedToken = e.key;
    String reason = e.value;
    // printStatement(rejectedToken);
    TrustStatement rejectedStatement = TrustStatement.find(rejectedToken)!;
    expect(keyLabels.labelKey(rejectedStatement.iToken), 'homer2');
    expect(rejectedStatement.verb, TrustVerb.replace);
    expect(rejectedStatement.subjectToken, homer.token); // no label (homer not in network)
    expect(reason, 'Replaced key not in network.');
  });

  // Notification:
  // - Attempt to replace your key.
  test('simpsons, degrees=3', () async {
    oneofusNet.degrees = 3;
    await DemoKey.demos['simpsons']();
    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    var network = oneofusNet.network;
    var expectedNetwork = {
      "son": null,
      "friend": null,
      "sis": null,
      "homer2": null,
      "moms": null,
      "homer2 (0)": "5/1/2024 12:09 AM",
      "clown": null,
      "mom": null,
      "sister": null
    };
    jsonShowExpect(dumpNetwork(network), expectedNetwork);

    expect(notifications.rejected.length, 1);
    MapEntry e = notifications.rejected.entries.first;
    String rejectedToken = e.key;
    String reason = e.value;
    // printStatement(rejectedToken);
    TrustStatement rejectedStatement = TrustStatement.find(rejectedToken)!;
    expect(keyLabels.labelKey(rejectedStatement.iToken), 'clown');
    expect(rejectedStatement.verb, TrustVerb.replace);
    expect(keyLabels.labelKey(rejectedStatement.subjectToken), 'son');
    expect(reason, 'Attempt to replace your key.');
  });

  test('Attempt to block your key.', () async {
    oneofusNet.degrees = 3;
    await DemoKey.demos['simpsons']();

    Statement lisaBlocksMarge = await lisa.doTrust(TrustVerb.block, marge);

    await signInState.signIn(marge.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(notifications.rejected.length, 1);
    MapEntry e = notifications.rejected.entries.first;
    String rejectedToken = e.key;
    String reason = e.value;
    expect(lisaBlocksMarge.token, rejectedToken);
    expect(reason, 'Attempt to block your key.');
  });

  test('Attempt to replace replaced key rejected.', () async {
    oneofusNet.degrees = 3;
    await DemoKey.demos['simpsons']();

    Statement s = await bart.doTrust(TrustVerb.trust, lisa);
    Statement rejected = await lisa.doTrust(TrustVerb.replace, homer, revokeAt: s.token);

    await signInState.signIn(homer2.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(notifications.rejected.length, 1);
    MapEntry e = notifications.rejected.entries.first;
    String rejectedToken = e.key;
    String reason = e.value;
    expect(rejected.token, rejectedToken);
    expect(reason, 'Attempt to replace a replaced key.');
  });

  test('simpsons label key edges', () async {
    await DemoKey.demos['simpsons']();

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(toJson(labelPathsX(lisa.token)), [
      [
        {'sis': 'sis'}
      ],
      [
        {'friend': 'friend'},
        {'sis': 'babe'}
      ],
      [
        {'homer2': 'homer2'},
        {'sis': 'daughter'}
      ],
      [
        {'moms': 'moms'},
        {'sis': 'daughter'}
      ]
    ]);

    await signInState.signIn(homer.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(toJson(labelPathsX(homer2.token)), [
      [
        {'wife': 'wife'},
        {'hubby2': 'hubby2'}
      ]
    ]);

    await signInState.signIn(homer2.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);
    expect(toJson(labelPathsX(homer.token)), [
      [
        {'hubby2 (0)': '(replaced)'}
      ],
      [
        {'daughter': 'daughter'},
        {'hubby2 (0)': 'dad'}
      ]
    ]);
  });

  test('NerdNode', () async {
    await DemoKey.demos['simpsons']();

    await signInState.signIn(bart.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    // CONSIDER: Test something beyond just this.
    await compareNetworkToTree(bart.token);
  });

  /// Not particularly realistic or stressfull.
  test('Stress (Sometimes I skip this, takes too long)', () async {
    // return;
    DemoKey o;
    DemoKey? n;
    (o, n) = await DemoKey.demos['stress']();

    final stopwatch = Stopwatch()..start();

    await signInState.signIn(o.token, null);
    await Comp.waitOnComps([contentBase, keyLabels]);

    print('Stress test executed in ${stopwatch.elapsed}');
  });
}

Future<Set> dfs(NetNode n) async {
  await followNet.waitUntilReady();

  Set dumped = {n};
  void dfs2(NetNode n, {String indent = ''}) {
    for (NetNode c in n.children) {
      if (!dumped.contains(c)) {
        dumped.add(c);
        // print('$indent${NetBase().show(c.token)}');
        dfs2(c, indent: '$indent  ');
      }
    }
  }

  dfs2(n);
  return dumped;
}

Future<void> compareNetworkToTree(String rootToken) async {
  // dfs should equal canonicals in network
  Set dumped = await dfs(NetNode(rootToken));
  Set<String> networkCanon =
      Set.of(oneofusNet.network.keys.where((t) => oneofusEquiv.getCanonical(t) == t));
  Set<String> dumpedKeys = Set.of(dumped.map((n) => n.token));
  expect(Set.of(keyLabels.show(dumpedKeys)), Set.of(keyLabels.show(networkCanon)));
  expect(dumped.length, networkCanon.length);
}
