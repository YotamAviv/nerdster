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
    DemoKey.clear();
    Fetcher.clear();
    await FireFactory.clearPersistence();
    // TEMP: Unnecesary: notifications.clear();
  });

  test('egos', () async {
    var (identity, delegate) = await egos();
    await signInState.signIn(identity.token, null);
    await Comp.waitOnComps([NotificationsComp()]);
    expect(NotificationsComp().hints.length, 1);
    TitleDescProblem issue = NotificationsComp().hints.first;
    expect(issue.title, "You're invisible to others");
  });

  test('egos circle', () async {
    var (identity, delegate) = await egosCircle();
    await signInState.signIn(identity.token, null);
    await Comp.waitOnComps([NotificationsComp()]);
    var x = NotificationsComp().hints;
    if (NotificationsComp().hints.isNotEmpty) {
      print(NotificationsComp().hints.first);
    }
    expect(NotificationsComp().hints.isEmpty, true);
  });
}
