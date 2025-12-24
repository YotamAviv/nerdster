import 'dart:collection';

import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';

Future<(DemoKey, DemoKey?)> trustBlockConflict() async {
  useClock(TestClock());

  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  
  LinkedHashMap<String, Node> network;
  Map<String, Null> expectedNetwork;

  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  Statement listTrustMilhouse = await lisa.doTrust(TrustVerb.trust, milhouse, moniker: 'Milhouse');
  Statement bartBlocMilhouse = await bart.doTrust(TrustVerb.block, milhouse);

  signInState.pov = lisa.token;
  await Comp.waitOnComps([contentBase, keyLabels]);
  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Milhouse": null,
    "Bart": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  jsonExpect(baseProblemCollector.rejected, {bartBlocMilhouse.token: 'Attempt to block trusted key.'});


  signInState.pov = bart.token;
  await Comp.waitOnComps([contentBase, keyLabels]);
  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  jsonExpect(baseProblemCollector.rejected, {listTrustMilhouse.token: 'Attempt to trust blocked key.'});

  useClock(LiveClock());
  return (bart, null);
}

