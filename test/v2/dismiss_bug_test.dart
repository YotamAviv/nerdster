import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);
  });

  test('Simpsons Demo: Lisa dismisses Shakes the Clown', () async {
    // We must ensure settings allow filtering (DisFilterMode.my or .pov)
    Setting.get(SettingType.dis).value = 'my';

    await simpsonsDemo();

    final DemoIdentityKey lisa = DemoIdentityKey.findByName('lisa')!;
    final DemoDelegateKey lisaDelegate = await lisa.makeDelegate();
    await lisa.delegate(lisaDelegate, domain: kNerdsterDomain);

    await signInState.signIn(lisa.id.value, lisaDelegate.keyPair);
    signInState.pov = lisa.id.value;

    final trustSource = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final contentSource =
        DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final controller = V2FeedController(trustSource: trustSource, contentSource: contentSource);

    // Initial Refresh
    await controller.refresh();
    expect(controller.value, isNotNull);

    // Find Shakes the Clown in the feed
    final feed = controller.value!;
    SubjectAggregation? shakes =
        feed.effectiveSubjects.where((s) => s.subject['title'] == 'Shakes the Clown').firstOrNull;

    expect(shakes, isNotNull, reason: "Shakes should be in feed initially (via Homer)");
    final shakesToken = shakes!.token;

    // 2. Lisa dismisses Shakes (simulating RateDialog action)
    // Create a dismiss statement from Lisa's Delegate
    final dismissStmt = ContentStatement.make(
      Jsonish.find(lisaDelegate.token)!.json, // Issuer is Lisa's Delegate
      ContentVerb.rate,
      shakes.subject, // FULL SUBJECT needed
      dismiss: true,
    );

    // Write to Firestore using Writer (to ensure correct path /<ID>/statements/statements)
    final writer = SourceFactory.getWriter(kNerdsterDomain);
    final signer = await OouSigner.make(lisaDelegate.keyPair); // Sign with Delegate Key!
    await writer.push(dismissStmt, signer);

    // 3. Refresh the feed (First time - "Minor Refresh" simulation)
    await controller.refresh();

    // 4. Verification Check 1
    V2FeedModel feedAfter = controller.value!;
    SubjectAggregation? shakesAfter =
        feedAfter.effectiveSubjects.where((s) => s.token == shakesToken).firstOrNull;

    expect(shakesAfter, isNull, reason: "Shakes should be hidden immediately after first refresh");

    // 5. Full verify (just to be safe)
    await controller.refresh();

    feedAfter = controller.value!;
    shakesAfter = feedAfter.effectiveSubjects.where((s) => s.token == shakesToken).firstOrNull;

    expect(shakesAfter, isNull, reason: "Shakes should remain hidden after second refresh");

    // 6. Verify it appears if we change filter to 'ignore'
    Setting.get(SettingType.dis).value = 'ignore';
    // Trigger update (controller listens to settings, but might need manual refresh call if listener logic is complex or async)
    // The controller listener calls refresh, but we await it in test? No, listener is void.
    // So we manually refresh or wait. Best to manually refresh to be deterministic.
    await controller.refresh();

    final V2FeedModel feedIgnored = controller.value!;
    final SubjectAggregation? shakesIgnored =
        feedIgnored.effectiveSubjects.where((s) => s.token == shakesToken).firstOrNull;

    expect(shakesIgnored, isNotNull, reason: "Shakes should reappear in 'ignore' filter mode");
  });
}
