import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';

Future<(DemoKey, DemoKey?)> trustBlockConflict() async {
  useClock(TestClock()); // DEFER: setUp? tearDown? using tests in code...

  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey milhouse = await DemoKey.findOrCreate('milhouse');
  
  var network;
  var expectedNetwork;
  var expectedEquivalents;

  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await lisa.doTrust(TrustVerb.trust, milhouse, moniker: 'Millhouse');
  await bart.doTrust(TrustVerb.block, milhouse);
  
  await signIn(lisa.token, null);
  
  network = OneofusNet().network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);

  useClock(LiveClock());
  return (bart, null);
}

