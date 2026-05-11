import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/oou_signer.dart';

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

    final controller = FeedController();

    // Initial Refresh
    await controller.refresh();
    expect(controller.value, isNotNull);

    // Find Shakes the Clown in the feed
    final feed = controller.value!;
    SubjectAggregation? shakes =
        feed.effectiveSubjects.where((s) => s.subject['title'] == 'Shakes the Clown').firstOrNull;

    expect(shakes, isNotNull, reason: "Shakes should be in feed initially (via Homer)");
    final shakesToken = shakes!.token;

    // 2. Lisa dismisses Shakes via the dis stream
    final dismissStmt = DismissStatement.make(
      Jsonish.find(lisaDelegate.token)!.json,
      shakes.canonical.value,
      'forever',
    );

    final signer = await OouSigner.make(lisaDelegate.keyPair);
    final disChannel = channelFactory.getChannel<DismissStatement>(kNerdsterDomain, 'statements', excludeTypes: ['org.nerdster']);
    await disChannel.fetch({lisaDelegate.token: null});
    await disChannel.push(dismissStmt, signer);

    // 3. Refresh the feed (First time - "Minor Refresh" simulation)
    await controller.refresh();

    // 4. Verification Check 1
    FeedModel feedAfter = controller.value!;
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

    final FeedModel feedIgnored = controller.value!;
    final SubjectAggregation? shakesIgnored =
        feedIgnored.effectiveSubjects.where((s) => s.token == shakesToken).firstOrNull;

    expect(shakesIgnored, isNotNull, reason: "Shakes should reappear in 'ignore' filter mode");
  });
}
