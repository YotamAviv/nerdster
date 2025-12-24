import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/notifications.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  fireChoice = FireChoice.fake;
  FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
  FireFactory.register(kNerdsterDomain, FakeFirebaseFirestore(), null);
  TrustStatement.init();
  ContentStatement.init();

  // To restore Prefs changes
  late Map<Setting, dynamic> prefsSnapshot;
  tearDown(() {
    Prefs.restore(prefsSnapshot);
  });
  setUp(() async {
    prefsSnapshot = Prefs.snapshot();
    timezoneOffsetKludge = 0;
    useClock(TestClock());
    DemoKey.reset();
    signInState.signOut();

    for (final fire in FireFactory.domain2fire.values) {
      await fire.$1.clearPersistence();
    }
  });

  test('base', () async {
    final (DemoKey oneofus, DemoKey delegate) = await DemoKey.demos['loner']();

    await signInState.signIn(oneofus.token, delegate.keyPair);
    await delegateCheck.waitUntilReady();
    expect(delegateCheck.problem.value, null);
  });

  test('revoked', () async {
    final (DemoKey oneofus, DemoKey delegate) = await DemoKey.demos['loner']();

    await signInState.signIn(oneofus.token, delegate.keyPair);

    await oneofus.doTrust(TrustVerb.delegate, delegate, domain: kNerdsterDomain, revokeAt: 'yup');

    await delegateCheck.waitUntilReady();
    expect(delegateCheck.problem.value!.title, 'Your Nerdster delegate is revoked');
  });

  test('not associated', () async {
    final (DemoKey oneofus, DemoKey delegate) = await DemoKey.demos['loner']();

    await signInState.signIn(oneofus.token, delegate.keyPair);

    await oneofus.doTrust(TrustVerb.clear, delegate);

    await delegateCheck.waitUntilReady();
    expect(delegateCheck.problem.value!.title,
        'Your Nerdster delegate is not associated with your signed in identity');
  });
}
