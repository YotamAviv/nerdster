import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/egos.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:test/test.dart';

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  setUp(() async {
    useClock(TestClock());
    DemoKey.reset();
    Fetcher.clear();
    await FireFactory.clearPersistence();
  });

  test('egos', () async {
    var (identity, delegate) = await egos();
    await signInState.signIn(identity.token, null);
    await Comp.waitOnComps([notifications]);
    expect(notifications.problems.length, 1);
    TitleDescProblem issue = notifications.problems.first;
    expect(issue.title, "You're invisible to others");
  });

  test('egos circle', () async {
    var (identity, delegate) = await egosCircle();
    await signInState.signIn(identity.token, null);
    await Comp.waitOnComps([notifications]);
    var x = notifications.problems;
    if (notifications.problems.isNotEmpty) {
      print(notifications.problems.first);
    }
    expect(notifications.problems.isEmpty, true);
  });
}
