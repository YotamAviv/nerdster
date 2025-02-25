import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:test/test.dart';

Future<(DemoKey, DemoKey?)> testDeletion1() async {
  useClock(TestClock());

  DemoKey loner = await DemoKey.findOrCreate('loner');
  DemoKey lonerN = await loner.makeDelegate();

  await lonerN.doRate(title: 'title');
  await signInState.signIn(loner.token, null);
  await contentBase.waitUntilReady();
  expect(contentBase.roots.length, 1);

  await lonerN.doCensor(title: 'title');
  contentBase.listen();
  await contentBase.waitUntilReady();
  expect(contentBase.roots.length, 0);

  return (loner, lonerN);
}

/// Players:
/// - deleter1 <-> deleter2
/// - observer1 -> deleter1
/// - observer2 -> deleter2
///   deleter1 issues deletion1 to delete subject1
///   deleter2 issues deletion2 to delete deletion1
/// Cases:
/// I am deleter2
///   censorship enabled :   deletion2 respected, not visible; deletion1 ignored, not visible (because it's deleted)
///   censorship disabled:   deletion2 respected, not visible; deletion1 ignored, not visible (because it's deleted)
/// I (user) am deleter1
///   censorship enabled: THE CRUX (of the biscuit)! I just deleted subject1; I don't want to see it! I have censorship enabled, but I don't want my censorship censored.
///                          deletion1 respected, not visible; deletion2 ignored, not visible (because deletion1 is not visible).
///   censorship disabled:   deletion1 respected, not visible; deletion2 ignored, not visible (because deletion1 is not visible)
/// I am someone unrelated:
///   deleter1 trumps deleter2:
///     censorship enabled:  deletion1 respected, not visible; deletion2 ignored, not visible (because deletion1 is not visible).
///     censorship disabled: deletion2 ignored, visible; deletion2 ignored, visible
///   deleter2 trumps deleter1:
///     censorship enabled:  deletion2 respected, not visible; deletion1 ignored, not visible (because it's deleted)
///     censorship disabled: deletion1 ignored, visible; deletion2 ignored, visible
/// 
/// It's good to have any test, but this needs improvement.
/// TODO: What's correct? Is the code correct? Make the code correct. Test the correct code.
Future<(DemoKey, DemoKey?)> deletions3() async {
  useClock(TestClock());
  // ContentBase().censor = true;
  DemoKey loner = await DemoKey.findOrCreate('loner');
  DemoKey lonerN = await loner.makeDelegate();

  // I was crashing with something related to TestHandle unless the 'expect' was 
  // in the context of a test, and so I put it in the context of a test.
  DemoKey deleter1 = await DemoKey.findOrCreate('deleter1');
  DemoKey deleter1N = await deleter1.makeDelegate();
  DemoKey deleter2 = await DemoKey.findOrCreate('deleter2');
  DemoKey deleter2N = await deleter2.makeDelegate();
  DemoKey observer1 = await DemoKey.findOrCreate('observer1');
  DemoKey observer2 = await DemoKey.findOrCreate('observer2');

  // deleters 1 and 2 trust each other.
  // observers 1 and 2 trust the deleters respectively, and so each
  // observer trusts both deleters but in a different order.
  await deleter1.doTrust(TrustVerb.trust, deleter2);
  await deleter2.doTrust(TrustVerb.trust, deleter1);
  await deleter1.doTrust(TrustVerb.trust, loner);
  await deleter2.doTrust(TrustVerb.trust, loner);
  await observer1.doTrust(TrustVerb.trust, deleter1);
  await observer2.doTrust(TrustVerb.trust, deleter2);

  // deleter1 delets subject; deleter2 deletes deleter1's deletion.
  Jsonish rating = await lonerN.doRate(title: 'title');
  Jsonish deletion1 = await deleter1N.doCensor(title: 'title');
  Jsonish deletion2 = await deleter2N.doCensor(subject: deletion1.json);

  // observer1 should be censored as per deleter1's desire.
  await signInState.signIn(observer1.token, null);
  await contentBase.waitUntilReady();
  // Using 'assert', not 'expect' from test. Not sure why it's probablematic here outside the
  // context of a test but not for the one above.
  assert(contentBase.roots.length == 0, contentBase.roots.length); 

  // observer2 should not be censored as per deleter2's desire to delete deleter1's deletion.
  assert(contentBase.ready);
  await signInState.signIn(observer2.token, null);
  await contentBase.waitUntilReady();
  assert(contentBase.roots.length == 1, contentBase.roots.length);
  assert(contentBase.roots.first.getChildren().length == 1);

  useClock(LiveClock());

  return (loner, lonerN);
}
