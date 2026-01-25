import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/cases/simpsons_demo.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/oneofus/oou_signer.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';

import 'spy_source.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    setUpTestRegistry(firestore: firestore);
  });

  test('Partial Refresh: Dismissal avoids network fetch', () async {
    Setting.get(SettingType.dis).value = 'my';
    await simpsonsDemo();

    final DemoIdentityKey lisa = DemoIdentityKey.findByName('lisa')!;
    final DemoDelegateKey lisaDelegate = await lisa.makeDelegate();
    await lisa.delegate(lisaDelegate, domain: kNerdsterDomain);

    await signInState.signIn(lisa.id.value, lisaDelegate.keyPair);
    signInState.pov = lisa.id.value;

    final realTrustSource = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final realContentSource =
        DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));

    final spyTrust = SpyStatementSource(realTrustSource);
    final spyContent = SpyStatementSource(realContentSource);

    final controller = V2FeedController(trustSource: spyTrust, contentSource: spyContent);

    // Initial Refresh - Should hit network
    await controller.refresh(lisa.id, meIdentity: lisa.id);
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
    final writer = SourceFactory.getWriter(kNerdsterDomain);
    
    // Construct dismiss statement
    // We need the exact subject object or constructed one.
    // Shakes subject from aggregation is fine.
    final Json json = ContentStatement.make(
      Jsonish.find(lisaDelegate.token)!.json,
      ContentVerb.rate,
      shakes!.subject,
      dismiss: true,
    );

    // Write to Firestore (Network Side Effect)
    final Statement statement = await writer.push(json, signer);

    // 3. PUSH to controller (Partial Refresh Logic)
    // This is what V2RateDialog + ContentView integration does
    controller.push(statement as ContentStatement);

    // 4. Refresh controller (Local Logic Update)
    await controller.refresh(lisa.id, meIdentity: lisa.id, clearCache: false);

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
