import 'dart:async';

import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

Future<(DemoKey, DemoKey?)> blockReplacedKey() async {
  useClock(TestClock()); // DEFER: setUp? tearDown? using tests in code...

  bool showEquivalentKeysBefore = Prefs.showKeys.value;
  bool showTrustStatementsBefore = Prefs.showStatements.value;
  Prefs.showKeys.value = true;
  Prefs.showStatements.value = false;

  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey bart2 = await DemoKey.findOrCreate('bart2');
  DemoKey bart3 = await DemoKey.findOrCreate('bart3');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey homer = await DemoKey.findOrCreate('homer');

  var network;
  var expectedNetwork;
  var expectedEquivalents;
  var dump;
  var expected;

  Statement s1 = await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  Statement r1 = await bart2.doTrust(TrustVerb.replace, bart, revokeAt: s1.token);
  Statement s2 = await bart2.doTrust(TrustVerb.trust, homer);
  Statement r2 = await bart3.doTrust(TrustVerb.replace, bart2, revokeAt: s2.token);
  await lisa.doTrust(TrustVerb.trust, bart3, moniker: 'Bart');
  // Lisa has not cleared trust in bart or ever trusted bart2

  signInState.center  = lisa.token;
  await Comp.waitOnComps([keyLabels, oneofusEquiv]);

  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null,
    "Bart (0)": "5/1/2024 12:03 AM",
    "Bart (1)": "5/1/2024 12:01 AM",
    "homer": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = {"Bart", "Bart (0)", "Bart (1)"};
  jsonShowExpect(oneofusEquiv.getEquivalents(bart3.token), expectedEquivalents);
  myExpect(notifications.rejected.length, 0);

  // ------------------------------------------------------------------------------------
  // Bart (currently 'bart3') now decides that 'bart' no longer represents him and blocks
  // ------------------------------------------------------------------------------------
  Statement bart3blocksBart = await bart3.doTrust(TrustVerb.block, bart);

  signInState.center  = lisa.token;
  await Comp.waitOnComps([keyLabels, oneofusEquiv]);
  myExpect(notifications.rejected.length, 1);
  myExpect(notifications.rejected.keys.first, r1.token);
  myExpect(notifications.rejected.values.first, 'Attempt to replace a blocked key.');
  network = oneofusNet.network;
  expectedNetwork = {
    "Me": null, // Note that I'm not labled "Lisa" any longer.
    "Bart": null,
    "Bart (0)": "5/1/2024 12:03 AM",
    "homer": null,
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = {'Bart', 'Bart (0)'};
  jsonShowExpect(oneofusEquiv.getEquivalents(bart3.token), expectedEquivalents);
  myExpect(notifications.rejected.containsKey(r1.token), true);
  await Comp.waitOnComps([followNet]);
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {
      "N:Bart-true:Me": {
        "N:homer-true:Me->Bart": {},
        "N:Bart (0)-false:5/1/2024 12:03 AM:Me->Bart": {}
      }
    }
  };
  jsonShowExpect(dump, expected);

  signInState.center  = bart3.token;
  await Comp.waitOnComps([keyLabels]);
  myExpect(notifications.rejected.length, 1);
  myExpect(notifications.rejected.length, 1);
  myExpect(notifications.rejected.keys.first, r1.token);
  myExpect(notifications.rejected.values.first, 'Attempt to replace a blocked key.');
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {
      "N:homer-true:Me": {},
      "N:Me (0)-false:5/1/2024 12:03 AM:Me": {}
    }
  };
  jsonShowExpect(dump, expected);

  signInState.center = bart2.token;
  await Comp.waitOnComps([keyLabels, oneofusEquiv]);
  myExpect(notifications.rejected.length, 2);
  jsonShowExpect(notifications.rejected, {
    r2.token:'Attempt to replace your key.', 
    bart3blocksBart.token:'Attempt to block trusted key.', 
  });
  network = oneofusNet.network;
  expectedNetwork = {
    "Me": null,
    "Me (0)": "5/1/2024 12:01 AM",
    "homer": null,
    "Lisa": null,
    "Bart": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  jsonShowExpect(oneofusEquiv.getEquivalents(bart2.token), {bart2.token, bart.token});
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {
      "N:homer-true:Me": {},
      "N:Lisa-true:Me": {
        "N:Bart-true:Me->Lisa": {}
      },
      "N:Me (0)-false:5/1/2024 12:01 AM:Me": {}
    }
  };
  jsonShowExpect(dump, expected);

  signInState.center  = bart.token;
  await Comp.waitOnComps([keyLabels, oneofusEquiv]);

  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {
      "N:Lisa-true:Me": {
        "N:Bart-true:Me->Lisa": {
          "N:homer-true:Me->Lisa->Bart": {},
          "N:Bart (0)-false:5/1/2024 12:03 AM:Me->Lisa->Bart": {}
        }
      }
    }
  };
  jsonShowExpect(dump, expected);

  Prefs.showKeys.value = showEquivalentKeysBefore;
  Prefs.showStatements.value = showTrustStatementsBefore;
  useClock(LiveClock());
  return (DemoKey.findByName('bart3')!, null);
}
