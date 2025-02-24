import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

Future<(DemoKey, DemoKey?)> trustBlockConflict() async {
  useClock(TestClock());

  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  
  var network;
  var expectedNetwork;

  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  Jsonish listTrustMilhouse = await lisa.doTrust(TrustVerb.trust, milhouse, moniker: 'Millhouse');
  Jsonish bartBlocMilhouse = await bart.doTrust(TrustVerb.block, milhouse);
  

  signInState.center = lisa.token;
  await Comp.waitOnComps([contentBase, keyLabels]);
  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Millhouse": null,
    "Bart": null
  };
  // jsonShowExpect(dumpNetwork(network), expectedNetwork);
  // jsonExpect(oneofusNet.rejected, {bartBlocMilhouse.token: 'Attempt to block trusted key.'});
  print(';');

  signInState.center = bart.token;
  print('x');
  await Comp.waitOnComps([contentBase, keyLabels]);
  print('z');
  network = oneofusNet.network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null
  };
  // jsonShowExpect(dumpNetwork(network), expectedNetwork);
  // jsonExpect(oneofusNet.rejected, {listTrustMilhouse.token: 'Attempt to trust blocked key.'});
  print(';');

  useClock(LiveClock());
  return (bart, null);
}

