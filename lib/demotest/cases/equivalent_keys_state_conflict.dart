import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/net/key_lables.dart';
import 'package:nerdster/net/oneofus_equiv.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/net/oneofus_net.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';

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

  await lisa.doTrust(TrustVerb.trust, milhouse, moniker: 'Millhouse');
  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  Jsonish s1 = await bart.doTrust(TrustVerb.trust, milhouse);
  Jsonish r1 = await bart2.doTrust(TrustVerb.replace, bart, revokeAt: s1.token);
  await bart2.doTrust(TrustVerb.block, milhouse);
  await lisa.doTrust(TrustVerb.trust, bart2, moniker: 'Bart');
  
  await signIn(lisa.token, null);
  await KeyLabels().waitUntilReady();
  network = OneofusNet().network;
  expectedNetwork = {
    "Lisa": null,
    "Bart": null,
    "Bart (0)": "5/1/2024 12:03 AM"
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = { 'Bart', 'Bart (0)' };
  jsonShowExpect(OneofusEquiv().getEquivalents(bart2.token), expectedEquivalents);
  myExpect(OneofusNet().rejected.isEmpty, true);
  
  // bart now decides that 'bart' no longer represents him and blocks
  Jsonish b1 = await bart2.doTrust(TrustVerb.block, bart);
  
  await signIn(lisa.token, null);  
  network = OneofusNet().network;
  expectedNetwork = {
    "Me": null,
    "Bart": null
  };
  jsonShowExpect(dumpNetwork(network), expectedNetwork);
  expectedEquivalents = { 'Bart' };
  jsonShowExpect(OneofusEquiv().getEquivalents(bart2.token), expectedEquivalents);
  dynamic dump = await OneofusTreeNode.root.dump();
  var expected = {
    "N:Me-true:": {
      "N:Bart-true:Me": {}
    }
  };
  jsonShowExpect(dump, expected);
  myExpect(OneofusNet().rejected.isEmpty, true);

  await signIn(bart2.token, null);
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {}  
  };
  jsonShowExpect(dump, expected);
  myExpect(OneofusNet().rejected.isEmpty, true);

  await signIn(bart.token, null);
  dump = await OneofusTreeNode.root.dump();
  expected = {
    "N:Me-true:": {
      "N:Lisa-true:Me": {
        "N:Bart-true:Me->Lisa": {}
      }
    }
  };
  jsonShowExpect(dump, expected);
  myExpect(OneofusNet().rejected.keys.length, 1);
  myExpect(OneofusNet().rejected.keys.first, b1.token);
  
  useClock(LiveClock());
  return (DemoKey.findByName('bart2')!, null);
}

