import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/egos.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_util.dart'; // import shared helper
import 'package:nerdster/oneofus/jsonish.dart';

Future<(DemoIdentityKey, DemoDelegateKey?)> equivalenceBug() async {
  final (poser, poserN, _) = await equivalenceBugWithStatements();
  return (poser, poserN);
}

Future<(DemoIdentityKey, DemoDelegateKey?, List<ContentStatement>)> equivalenceBugWithStatements() async {
  final (DemoIdentityKey poser, DemoDelegateKey? poserN) = await egosCircle();

  // Rate A, B, C using createTestSubject helper
  final ContentStatement sA = await poserN!
      .doRate(subject: createTestSubject(title: "Subject A"), recommend: true, comment: 'Rating A');
  final ContentStatement sB = await poserN.doRate(
      subject: createTestSubject(title: "Subject B"), recommend: true, comment: 'Rating B');
  final ContentStatement sC = await poserN.doRate(
      subject: createTestSubject(title: "Subject C"), recommend: true, comment: 'Rating C');

  // Equate B => C
  await poserN.doRelate(ContentVerb.equate, subject: sC.subject, other: sB.subject);
  // Equate A => B  TODO: BUG: Which way's which ? Document it.
  await poserN.doRelate(ContentVerb.equate, subject: sB.subject, other: sA.subject);

  return (poser, poserN, [sA, sB, sC]);
}
