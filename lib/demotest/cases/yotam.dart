import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

Future<(DemoKey, DemoKey?)> yotam() async {
  DemoKey yotam = await DemoKey.findOrCreate('yotam');
  DemoKey amotz = await DemoKey.findOrCreate('amotz');

  DemoKey yotamN = await yotam.makeDelegate();
  DemoKey amotzN = await amotz.makeDelegate();

  await yotam.doTrust(TrustVerb.trust, amotz, moniker: 'Amotz');
  await amotz.doTrust(TrustVerb.trust, yotam, moniker: 'Yotam');

  return (yotam, yotamN);
}
