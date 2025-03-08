import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

/// I loose track at times of what tests were meant to test. As the implementation evolves (like
/// getting rid of blockerBenefit), I've just been going through and updating the outcomes.
/// As long as there are not crashes (ex, assertion failures) and the outcome seems reasonable, 
/// I just go with it.
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

  Statement lisaTrustsMilhouse = await lisa.doTrust(TrustVerb.trust, milhouse, moniker: 'Millhouse');
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  Statement bartTrustsMilhouse = await bart.doTrust(TrustVerb.trust, milhouse);
  await bart2.doTrust(TrustVerb.replace, bart, revokeAt: bartTrustsMilhouse.token);
  Statement bart2blocksMilhouse = await bart2.doTrust(TrustVerb.block, milhouse);
  await lisa.doTrust(TrustVerb.trust, bart2, moniker: 'Bart');
  
  signInState.center = lisa.token;
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null,
    "Millhouse": null,
    "Bart (0)": "5/1/2024 12:03 AM"
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = { 'Bart', 'Bart (0)' };
  jsonShowExpect(oneofusEquiv.getEquivalents(bart2.token), expectedEquivalents);
  myExpect(notifications.rejected.length, 1);
  myExpect(notifications.rejected[bart2blocksMilhouse.token], 'Attempt to block trusted key.');
  
  // Bart (bart2) now decides that 'bart' no longer represents him and blocks
  Statement b1 = await bart2.doTrust(TrustVerb.block, bart);
  
  signInState.center = lisa.token;
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  myExpect(notifications.rejected.length, 1);
  myExpect(notifications.rejected[bart2blocksMilhouse.token], 'Attempt to block trusted key.');
  network = oneofusNet.network;
  expectedNetwork = {
    "Me": null,
    "Bart": null,
    "Millhouse": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = { 'Bart' };
  jsonShowExpect(oneofusEquiv.getEquivalents(bart2.token), expectedEquivalents);
  dynamic dump = await OneofusTreeNode.root.dump();
  var expected = {
    "N:Me-true:": {
      "N:Bart-true:Me": {},
      "N:Millhouse-true:Me": {}
    }
  };
  jsonShowExpect(dump, expected);
  myExpect(notifications.rejected.length, 1);
  // printStatement(notifications.rejected.keys.first);
  myExpect(notifications.rejected[bart2blocksMilhouse.token], 'Attempt to block trusted key.');

  signInState.center = bart2.token;
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {}  
  };
  jsonShowExpect(dump, expected);
  myExpect(notifications.rejected.isEmpty, true);

  await signInState.signIn(bart.token, null);
  await Comp.waitOnComps([oneofusEquiv, keyLabels]);
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {
      "N:milhouse-true:Me": {},
      "N:Lisa-true:Me": {
        "N:milhouse-true:Me->Lisa": {},
        "N:Bart-true:Me->Lisa": {}
      }
    }
  };
  jsonShowExpect(dump, expected);
  myExpect(notifications.rejected.length, 2);
  jsonShowExpect(notifications.rejected, {
    b1.token:'Attempt to block your key.', 
    bart2blocksMilhouse.token: 'Attempt to block trusted key.'
  });
  
  useClock(LiveClock());
  return (DemoKey.findByName('bart2')!, null);
}

