import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/oou_signer.dart';

import 'spy_source.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);
  });

  test('Partial Refresh: Dismissal avoids network fetch', () async {
    Setting.get(SettingType.dis).value = 'my';
    var (DemoIdentityKey lisa, DemoDelegateKey? lisaDelegate) = await simpsonsDemo();

    // This alternative passes, too. It tests using a new delegate, and so the cache would be [],
    // and this would be the first statement (previous == null).
    // lisaDelegate = await lisa.makeDelegate();
    // await lisa.delegate(lisaDelegate, domain: kNerdsterDomain);

    await signInState.signIn(lisa.id.value, lisaDelegate!.keyPair);
    signInState.pov = lisa.id.value;

    final realTrustSource = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final realContentSource =
        DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));

    final spyTrust = SpyStatementSource(realTrustSource);
    final spyContent = SpyStatementSource(realContentSource);

    final controller = FeedController(trustSource: spyTrust, contentSource: spyContent);

    // Initial Refresh - Should hit network
    await controller.refresh(); // uses signInState pov
    expect(controller.value, isNotNull);

    // Check initial fetch history
    int initialContentFetches = spyContent.fetchHistory.length;
    // We expect fetches because we follow people and ourselves/delegates
    expect(initialContentFetches, greaterThan(0));

    // Reset history to track NEW fetches clearly
    spyContent.resetHistory();
    spyTrust.resetHistory();

    final feed = controller.value!;
    SubjectAggregation? shakes =
        feed.effectiveSubjects.where((s) => s.subject['title'] == 'Shakes the Clown').firstOrNull;
    expect(shakes, isNotNull, reason: "Shakes should be in feed initially");

    SubjectAggregation? secretariat =
        feed.effectiveSubjects.where((s) => s.subject['title'] == 'Secretariat').firstOrNull;
    expect(secretariat, isNotNull);
    // Verify Lisa's like on Secretariat
    final secretariatMyLike = secretariat!.statements
        .where((s) =>
            s.verb == ContentVerb.rate &&
            s.like == true &&
            controller.value!.delegateResolver.getIdentityForDelegate(s.iKey)!.value ==
                lisa.id.value)
        .firstOrNull;
    expect(secretariatMyLike, isNotNull, reason: "Lisa should like Secretariat initially");

    // 2. Lisa dismisses Shakes
    final signer = await OouSigner.make(lisaDelegate.keyPair);
    // writer removed

    // Construct dismiss statement
    final Json json = ContentStatement.make(
      Jsonish.find(lisaDelegate.token)!.json,
      ContentVerb.rate,
      shakes!.subject,
      dismiss: true,
    );

    // Write to Firestore AND Cache (Network Side Effect + Local Update)
    // Uses spyContent -> realContentSource -> FakeFirestore
    // Explicitly casting contentSource to CachedSource to access internal writer via interface?
    // CachedSource implements StatementWriter now.
    await controller.contentSource.push(json, signer);

    // 4. Update controller (Local Logic Update)
    await controller.notify();

    // 5. Verification
    // A. UI Updated?
    final feedAfter = controller.value!;
    SubjectAggregation? shakesAfter =
        feedAfter.effectiveSubjects.where((s) => s.token == shakes.token).firstOrNull;
    expect(shakesAfter, isNull, reason: "Shakes should be dismissed locally");

    // Check Secretariat still has Lisa's like
    SubjectAggregation? secretariatAfter =
        feedAfter.effectiveSubjects.where((s) => s.subject['title'] == 'Secretariat').firstOrNull;
    expect(secretariatAfter, isNotNull);
    final secretariatMyLikeAfter = secretariatAfter!.statements
        .where((s) =>
            s.verb == ContentVerb.rate &&
            s.like == true &&
            controller.value!.delegateResolver.getIdentityForDelegate(s.iKey)!.value ==
                lisa.id.value)
        .firstOrNull;
    expect(secretariatMyLikeAfter, isNotNull,
        reason: "Lisa's like on Secretariat should persist after dismissing Shakes");

    // B. No Network Fetch for Content?
    // We expect ZERO fetches because cache should have handled everything
    expect(spyContent.fetchHistory, isEmpty,
        reason: "Should not fetch content from network after push: ${spyContent.fetchHistory}");
  });
}
