import 'package:nerdster/comp.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';

Future<(DemoKey, DemoKey?)> multipleBlocks() async {
  useClock(TestClock());

  Prefs.showKeys.value = true;

  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  DemoKey sideshow = await DemoKey.findOrCreate('sideshow');
  
  var network;
  var expectedNetwork;
  var expectedEquivalents;

  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await bart.doTrust(TrustVerb.trust, milhouse, moniker: 'Millhouse');
  await milhouse.doTrust(TrustVerb.trust, sideshow, moniker: 'Sideshow');
  await bart.doTrust(TrustVerb.block, sideshow);
  await lisa.doTrust(TrustVerb.block, sideshow);
  
  await signInState.signIn(lisa.token, null);
  await Comp.waitOnComps([contentBase, keyLabels]);
  
  network = OneofusNet().network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null,
    "Millhouse": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  
  useClock(LiveClock());
  return (bart, null);
}

