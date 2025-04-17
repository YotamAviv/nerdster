import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/jsonish.dart';

Future<(DemoKey, DemoKey?)> loner() async {
  DemoKey loner = await DemoKey.findOrCreate('loner');
  DemoKey lonerN = await loner.makeDelegate();
  
  return (loner, lonerN);
}

Future<(DemoKey, DemoKey?)> lonerEquate() async {
  var out = await loner();
  DemoKey lonerN = await DemoKey.findOrCreate('loner-nerdster0');

  await lonerN.doRate(title: 'a');
  await lonerN.doRate(title: 'b');
  await lonerN.doRelate(ContentVerb.equate, title: 'a', otherTitle: 'b');
  
  return out;
}

