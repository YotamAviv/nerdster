import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

Future<(DemoKey, DemoKey?)> equivalentKeysStateConflict() async {
  useClock(TestClock()); // DEFER: setUp? tearDown? using tests in code...
  Prefs.showKeys.value = true;
  Prefs.showStatements.value = false;

  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey bart2 = await DemoKey.findOrCreate('bart2');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  
  var network;
  var expectedNetwork;
  var expectedEquivalents;

  Jsonish lisaTrustsMilhouse = await lisa.doTrust(TrustVerb.trust, milhouse, moniker: 'Millhouse');
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  Jsonish bartTrustsMilhouse = await bart.doTrust(TrustVerb.trust, milhouse);
  await bart2.doTrust(TrustVerb.replace, bart, revokeAt: bartTrustsMilhouse.token);
  await bart2.doTrust(TrustVerb.block, milhouse);
  await lisa.doTrust(TrustVerb.trust, bart2, moniker: 'Bart');
  
  await signInState.signIn(lisa.token, null);
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null,
    "Bart (0)": "5/1/2024 12:03 AM"
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = { 'Bart', 'Bart (0)' };
  jsonShowExpect(oneofusEquiv.getEquivalents(bart2.token), expectedEquivalents);
  myExpect(oneofusNet.rejected.length, 2);
  myExpect(oneofusNet.rejected[lisaTrustsMilhouse.token], 'A trusted key was blocked.');
  myExpect(oneofusNet.rejected[bartTrustsMilhouse.token], 'Attempt to trust blocked key.');
  
  // bart now decides that 'bart' no longer represents him and blocks
  Jsonish b1 = await bart2.doTrust(TrustVerb.block, bart);
  
  await signInState.signIn(lisa.token, null);  
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  network = oneofusNet.network;
  expectedNetwork = {
    "Me": null,
    "Bart": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = { 'Bart' };
  jsonShowExpect(oneofusEquiv.getEquivalents(bart2.token), expectedEquivalents);
  dynamic dump = await OneofusTreeNode.root.dump();
  var expected = {
    "N:Me-true:": {
      "N:Bart-true:Me": {}
    }
  };
  jsonShowExpect(dump, expected);
  myExpect(oneofusNet.rejected.length, 1);
  printStatement(oneofusNet.rejected.keys.first);
  myExpect(oneofusNet.rejected[lisaTrustsMilhouse.token], 'A trusted key was blocked.');

  await signInState.signIn(bart2.token, null);
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {}  
  };
  jsonShowExpect(dump, expected);
  myExpect(oneofusNet.rejected.isEmpty, true);

  await signInState.signIn(bart.token, null);
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {
      "N:Lisa-true:Me": {
        "N:Bart-true:Me->Lisa": {}
      }
    }
  };
  jsonShowExpect(dump, expected);
  myExpect(oneofusNet.rejected.keys.length, 3);
  myExpect(oneofusNet.rejected.keys.first, b1.token);
  
  useClock(LiveClock());
  return (DemoKey.findByName('bart2')!, null);
}

