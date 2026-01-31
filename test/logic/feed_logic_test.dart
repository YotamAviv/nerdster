import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/direct_firestore_source.dart';

import 'package:nerdster/singletons.dart';

import 'simpsons_data_helper.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:oneofus_common/crypto/crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore nerdsterFire;
  late FakeFirebaseFirestore oneofusFire;
  late FeedController controller;

  Future<void> waitForLoad(FeedController controller) async {
    while (controller.loading || controller.value == null) {
      if (!controller.loading && controller.value == null && controller.error != null) {
        throw Exception('Controller failed: ${controller.error}');
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  setUp(() async {
    // Reset global state
    signInState.signOut(clearIdentity: true);

    oneofusFire = FakeFirebaseFirestore();
    nerdsterFire = FakeFirebaseFirestore();

    setUpTestRegistry(firestore: oneofusFire); // This registers oneofusFire for both by default
    // We override kNerdsterDomain to use nerdsterFire specifically for tests that care.
    FireFactory.register(kNerdsterDomain, nerdsterFire, null);

    await SimpsonsDataHelper.populate(nerdsterFire, oneofusFire);

    Setting.get<String>(SettingType.fcontext).value = 'family';

    controller = FeedController(
      trustSource: DirectFirestoreSource<TrustStatement>(oneofusFire),
      contentSource: DirectFirestoreSource<ContentStatement>(nerdsterFire),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('Lisa feed should have expected names and content', () async {
    final String lisaToken = DemoIdentityKey.findByName('lisa')!.token;
    await signInState.signIn(lisaToken, null);
    await waitForLoad(controller);

    expect(controller.error, isNull);
    expect(controller.value, isNotNull);

    final FeedModel model = controller.value!;
    final Labeler labeler = model.labeler;

    // Verify some names from Simpsons data
    // We need to know what's in demoData.js to make specific assertions.
    // Based on previous logs, we saw "Secretariat", "Buck", etc.

    expect(model.aggregation.statements, isNotEmpty);

    for (final ContentStatement s in model.aggregation.statements) {
      final String authorName = labeler.getLabel(s.iToken);
    }

    // Verify some specific labels from Lisa's perspective
    final String homerToken = DemoIdentityKey.findByName('homer')!.token;
    final String homer2Token = DemoIdentityKey.findByName('homer2')!.token;
    final String margeToken = DemoIdentityKey.findByName('marge')!.token;

    // Homer was replaced by Homer2, so Homer is "dad'" and Homer2 is "dad"
    expect(labeler.getLabel(homerToken), equals("dad'"));
    expect(labeler.getLabel(homer2Token), equals('dad'));
    expect(labeler.getLabel(margeToken), equals('mom'));
  });

  test(
      'My delegate statements should be available in myDelegateStatements but not in main aggregation if not in PoV network',
      () async {
    // 1. Create Stranger and Me
    final DemoIdentityKey stranger = await DemoIdentityKey.create('stranger');
    final DemoDelegateKey strangerDelegate = await stranger.makeDelegate();
    final DemoIdentityKey me = await DemoIdentityKey.create('me');
    final DemoDelegateKey meDelegate = await me.makeDelegate();

    final Map<String, dynamic> secretariat =
        createTestSubject(title: 'Secretariat', url: 'https://sec.com');

    // 2. Stranger (via delegate) rates "Secretariat" (so it appears in the feed)
    await strangerDelegate.doRate(subject: secretariat, recommend: true);

    // 3. Me (via delegate) rates "Secretariat"
    await meDelegate.doRate(subject: secretariat, recommend: true, comment: 'I like horses');

    // 4. Sign in as Me
    me.keyPair;
    final OouKeyPair meDelegateKeyPair = meDelegate.keyPair;
    await signInState.signIn(me.token, meDelegateKeyPair);

    // 5. Refresh with Stranger as PoV
    // Stranger does NOT trust Me, so Me is not in the trust graph.
    signInState.pov = stranger.id.value;
    await waitForLoad(controller);

    expect(controller.error, isNull);
    expect(controller.value, isNotNull);

    final FeedModel model = controller.value!;

    // 6. Find Secretariat aggregation
    final SubjectAggregation? secretariatAgg = model.aggregation.subjects.values
        .where((SubjectAggregation agg) => agg.subject['title'] == 'Secretariat')
        .firstOrNull;

    if (secretariatAgg != null) {
      // Main statements should NOT contain Me's rating
      final Iterable<ContentStatement> myRatingInMain =
          secretariatAgg.statements.where((ContentStatement s) => s.iToken == meDelegate.token);
      expect(myRatingInMain, isEmpty, reason: "Me's rating should NOT be in main aggregation");

      // main aggregation if not in PoV network
      final List<ContentStatement> myLiteralStmts =
          model.aggregation.myLiteralStatements[secretariatAgg.token] ?? [];
      expect(myLiteralStmts, isNotEmpty,
          reason: "myLiteralStatements should be available for UI overlay even in Pure PoV");
    }

    // Check for My Statements in Global map
    final ContentKey secretariatKey = model.aggregation.myLiteralStatements.keys.firstWhere(
      (ContentKey k) => model.aggregation.myLiteralStatements[k]!
          .any((ContentStatement s) => (s.subject as Map)['title'] == 'Secretariat'),
    );
    final List<ContentStatement> myLiteralStatements =
        model.aggregation.myLiteralStatements[secretariatKey] ?? [];
    expect(myLiteralStatements, isNotEmpty,
        reason: "Me's rating SHOULD be in aggregation.myLiteralStatements");
    expect(myLiteralStatements.first.comment, equals('I like horses'));
  });

  test('Rating a rating should not result in the rating appearing as a top-level subject',
      () async {
    // 1. Setup Viewer, Rater, Critic
    final DemoIdentityKey viewer = await DemoIdentityKey.findOrCreate('viewer');
    final DemoDelegateKey viewerDelegate =
        await viewer.makeDelegate(); // Viewer needs delegate to follow
    final DemoIdentityKey rater = await DemoIdentityKey.findOrCreate('rater');
    final DemoDelegateKey raterDelegate = await rater.makeDelegate();
    final DemoIdentityKey critic = await DemoIdentityKey.findOrCreate('critic');
    final DemoDelegateKey criticDelegate = await critic.makeDelegate();

    // Viewer trusts Rater and Critic (Identities)
    await viewer.trust(rater, moniker: 'rater');
    await viewer.trust(critic, moniker: 'critic');

    // Viewer follows Rater and Critic (Content) so their content appears in 'family' feed
    await viewerDelegate.doFollow(rater, <String, dynamic>{'family': 1});
    await viewerDelegate.doFollow(critic, <String, dynamic>{'family': 1});

    // 2. Rater (via delegate) rates "Inception"
    final ContentStatement ratingStatement =
        await raterDelegate.doRate(title: 'Inception', recommend: true);
    final String ratingToken = ratingStatement.token;

    // 3. Critic (via delegate) rates Rater's rating (e.g. dislikes it)
    await criticDelegate.doRate(subject: ratingToken, recommend: false, comment: 'Bad take');

    // 4. Refresh Viewer's feed
    await signInState.signIn(viewer.id.value, null);
    await waitForLoad(controller);

    expect(controller.error, isNull);
    final FeedModel model = controller.value!;

    // 5. Verify "Inception" is a subject
    final Iterable<SubjectAggregation> inceptionAgg = model.aggregation.subjects.values
        .where((SubjectAggregation agg) => agg.subject['title'] == 'Inception');
    expect(inceptionAgg, isNotEmpty, reason: "Inception should be in the feed");

    // 6. Verify the Rating Statement IS in the aggregation (for lookup)
    final Iterable<SubjectAggregation> ratingAsSubject = model.aggregation.subjects.values
        .where((SubjectAggregation agg) => agg.canonical.value == ratingToken);
    expect(ratingAsSubject, isEmpty,
        reason: "The rating statement should not be in the aggregation for lookup");
  });

  test(
      'My delegate statements should be fetched even if I am not in the PoV graph and not signed in with that delegate',
      () async {
    // 1. Create Stranger and Me
    final DemoIdentityKey stranger = await DemoIdentityKey.create('stranger');
    final DemoIdentityKey me = await DemoIdentityKey.create('me');
    final DemoDelegateKey meDelegate = await me.makeDelegate();

    final Map<String, dynamic> secretariat =
        createTestSubject(title: 'Secretariat', url: 'https://sec.com');

    // 2. Me (via delegate) rates "Secretariat"
    await meDelegate.doRate(subject: secretariat, recommend: true, comment: 'I like horses');

    // 3. Sign in as Me (Identity ONLY, no delegate credential active)
    await signInState.signIn(me.token, null);

    // 4. Refresh with Stranger as PoV
    // Stranger does NOT trust Me.
    signInState.pov = stranger.id.value;
    await waitForLoad(controller);

    // Wait for controller to finish loading the requested PoV
    // (Because signIn triggered a refresh for 'Me', the explicit refresh call might have returned early)
    while (controller.value?.povIdentity != stranger.id || controller.loading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    expect(controller.error, isNull);
    final FeedModel model = controller.value!;

    // 5. Find Secretariat aggregation in the FEED result
    final SubjectAggregation? secretariatInFeed = model.effectiveSubjects
        .where((SubjectAggregation agg) => agg.subject['title'] == 'Secretariat')
        .firstOrNull;

    expect(secretariatInFeed, isNull,
        reason: "Secretariat should NOT be in the feed for Stranger PoV");

    // Check for My Statements in Global map (might not be top-level in feed)
    final ContentKey secretariatKey = model.aggregation.myLiteralStatements.keys.firstWhere(
      (ContentKey k) => model.aggregation.myLiteralStatements[k]!
          .any((ContentStatement s) => (s.subject as Map)['title'] == 'Secretariat'),
    );
    final List<ContentStatement> myLiteralStatements =
        model.aggregation.myLiteralStatements[secretariatKey] ?? [];

    expect(myLiteralStatements, isNotEmpty,
        reason: "Me's rating SHOULD be in aggregation.myLiteralStatements even if not in feed");
    expect(myLiteralStatements.first.comment, equals('I like horses'));
  });
}
