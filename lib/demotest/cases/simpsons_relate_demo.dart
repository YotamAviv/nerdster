import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// Simpsons Relate/Equate Demo
///
/// Characters:
/// - Lisa: The intellectual, relates things logically.
/// - Bart: The prankster, un-relates things, equates random stuff.
/// - Homer: Equates food to everything.
/// - Marge: Tries to keep things organized.
///
/// Scenarios:
/// 1. Lisa relates "Science" to "Math".
/// 2. Bart un-relates "Science" from "Math".
/// 3. Homer equates "Donut" to "Happiness".
/// 4. Marge relates "Donut" to "Food".
/// 5. Bart equates "Skateboard" to "Transportation".
/// 6. Lisa un-equates "Skateboard" from "Transportation".
/// 7. Bart relates "El Barto" to "Art".
/// 8. Marge un-relates "El Barto" from "Art".
///
Future<(DemoKey, DemoKey?)> simpsonsRelateDemo() async {
  useClock(TestClock(Duration(days: 1)));

  // 1. Create Identity Keys
  DemoKey lisa = await DemoKey.findOrCreate('lisa');
  DemoKey bart = await DemoKey.findOrCreate('bart');
  DemoKey homer = await DemoKey.findOrCreate('homer');
  DemoKey marge = await DemoKey.findOrCreate('marge');

  // 2. Establish Trust (Family trusts each other)
  await lisa.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await lisa.doTrust(TrustVerb.trust, homer, moniker: 'Dad');
  await lisa.doTrust(TrustVerb.trust, marge, moniker: 'Mom');

  await bart.doTrust(TrustVerb.trust, lisa, moniker: 'Lis');
  await bart.doTrust(TrustVerb.trust, homer, moniker: 'Homer');
  await bart.doTrust(TrustVerb.trust, marge, moniker: 'Mom');

  await homer.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await homer.doTrust(TrustVerb.trust, bart, moniker: 'Boy');
  await homer.doTrust(TrustVerb.trust, marge, moniker: 'Marge');

  await marge.doTrust(TrustVerb.trust, lisa, moniker: 'Lisa');
  await marge.doTrust(TrustVerb.trust, bart, moniker: 'Bart');
  await marge.doTrust(TrustVerb.trust, homer, moniker: 'Homie');

  // 3. Create Delegate Keys
  DemoKey lisaD = await lisa.makeDelegate(export: 'lisa-delegate');
  DemoKey bartD = await bart.makeDelegate(export: 'bart-delegate');
  DemoKey homerD = await homer.makeDelegate(export: 'homer-delegate');
  DemoKey margeD = await marge.makeDelegate(export: 'marge-delegate');

  // 4. Create Content & Relationships

  // Subjects
  // Using 'resource' as a valid generic content type.
  final science = {'contentType': 'resource', 'title': 'Science', 'url': 'https://en.wikipedia.org/wiki/Science'};
  final math = {'contentType': 'resource', 'title': 'Math', 'url': 'https://en.wikipedia.org/wiki/Mathematics'};
  final donut = {'contentType': 'resource', 'title': 'Donut', 'url': 'https://en.wikipedia.org/wiki/Doughnut'};
  final happiness = {'contentType': 'resource', 'title': 'Happiness', 'url': 'https://en.wikipedia.org/wiki/Happiness'};
  final food = {'contentType': 'resource', 'title': 'Food', 'url': 'https://en.wikipedia.org/wiki/Food'};
  final skateboard = {'contentType': 'resource', 'title': 'Skateboard', 'url': 'https://en.wikipedia.org/wiki/Skateboard'};
  final transportation = {'contentType': 'resource', 'title': 'Transportation', 'url': 'https://en.wikipedia.org/wiki/Transport'};
  final elBarto = {'contentType': 'resource', 'title': 'El Barto', 'url': 'https://simpsons.fandom.com/wiki/El_Barto'};
  final art = {'contentType': 'resource', 'title': 'Art', 'url': 'https://en.wikipedia.org/wiki/Art'};
  final toy = {'contentType': 'resource', 'title': 'Toy', 'url': 'https://en.wikipedia.org/wiki/Toy'};

  // Lisa relates Science to Math
  await lisaD.doRelate(ContentVerb.relate, subject: science, other: math);

  // Bart un-relates Science from Math (just to be annoying)
  await bartD.doRelate(ContentVerb.dontRelate, subject: science, other: math);

  // Homer equates Donut to Happiness
  await homerD.doRelate(ContentVerb.equate, subject: donut, other: happiness);

  // Marge relates Donut to Food
  await margeD.doRelate(ContentVerb.relate, subject: donut, other: food);

  // Bart equates Skateboard to Transportation
  await bartD.doRelate(ContentVerb.equate, subject: skateboard, other: transportation);

  // Lisa un-equates Skateboard from Transportation (technically it is, but maybe she disagrees in this context?)
  // Or maybe she equates it to "Toy"
  await lisaD.doRelate(ContentVerb.equate, subject: skateboard, other: toy);
  await lisaD.doRelate(ContentVerb.dontEquate, subject: skateboard, other: transportation);

  // Bart relates El Barto to Art
  await bartD.doRelate(ContentVerb.relate, subject: elBarto, other: art);

  // Marge un-relates El Barto from Art (it's vandalism!)
  await margeD.doRelate(ContentVerb.dontRelate, subject: elBarto, other: art);

  useClock(LiveClock());

  return (lisa, lisaD);
}
