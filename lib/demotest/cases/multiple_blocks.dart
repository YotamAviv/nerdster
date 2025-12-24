import 'dart:collection';

import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';

Future<(DemoKey, DemoKey?)> multipleBlocks() async {
  useClock(TestClock());
  late Map<Setting, dynamic> prefsSnapshot = Prefs.snapshot();
  Setting.get<bool>(SettingType.showKeys).value = true;

  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  DemoKey sideshow = await DemoKey.findOrCreate('sideshow');
  
  LinkedHashMap<String, Node> network;
  Map<String, Null> expectedNetwork;

  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await bart.doTrust(TrustVerb.trust, milhouse, moniker: 'Millhouse');
  await milhouse.doTrust(TrustVerb.trust, sideshow, moniker: 'Sideshow');
  await bart.doTrust(TrustVerb.block, sideshow);
  await lisa.doTrust(TrustVerb.block, sideshow);
  
  await signInState.signIn(lisa.token, null);
  await Comp.waitOnComps([contentBase, keyLabels]);
  
  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null,
    "Millhouse": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  
  useClock(LiveClock());
  Prefs.restore(prefsSnapshot);
  return (bart, null);
}

