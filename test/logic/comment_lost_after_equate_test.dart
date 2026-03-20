// Regression test for: comment submitted with a new subject is lost from
// RateDialog after equating that subject as equivalent to an existing one.
//
// Scenario:
//   User A submits subject X with comment "XXX" then trusts user B.
//   User B submits subject Y with comment "YYY" then trusts user A.
//   User B equates Y => X  (X is canonical).
//
// Expected (from A's PoV):
//   myLiteralStatements[X] contains A's rate (comment "XXX") — so RateDialog
//   pre-populates "XXX" when A clicks the react icon on the X card.
//
// Expected (from B's PoV):
//   myLiteralStatements[X] contains B's rate (comment "YYY") — so RateDialog
//   pre-populates "YYY" when B clicks the react icon on the X card.
//   (B rated Y, which was equated to X, so it must be reachable via X.)

import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/logic/content_pipeline.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/logic/trust_pipeline.dart';
import 'package:nerdster/models/model.dart';
import 'package:oneofus_common/direct_firestore_source.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
    // Use subject-not-token so subjects stay as Maps (easier to inspect).
    Setting.get(SettingType.debugUseSubjectNotToken).value = true;
  });

  test('Comment from B is visible via canonical subject X after B equates Y=>X', () async {
    // ----- Setup identities -----
    final userA = await DemoIdentityKey.findOrCreate('userA');
    final userB = await DemoIdentityKey.findOrCreate('userB');
    final delegateA = await userA.makeDelegate();
    final delegateB = await userB.makeDelegate();

    // Mutual trust (so each appears in the other's follow network)
    await userA.doTrust(TrustVerb.trust, userB, moniker: 'B');
    await userB.doTrust(TrustVerb.trust, userA, moniker: 'A');

    // ----- Content -----
    final Json subjectX = createTestSubject(title: 'Subject X');
    final Json subjectY = createTestSubject(title: 'Subject Y');

    // A rates X with comment "XXX"
    await delegateA.doRate(subject: subjectX, comment: 'XXX');

    // B rates Y with comment "YYY"
    await delegateB.doRate(subject: subjectY, comment: 'YYY');

    // B follows A and B (self-follow not required but makes the network symmetric)
    await delegateB.doFollow(userA, {kFollowContextNerdster: 1});
    await delegateA.doFollow(userB, {kFollowContextNerdster: 1});

    // B equates Y => X  (X is canonical, Y is equivalent)
    await delegateB.doRelate(ContentVerb.equate, subject: subjectX, other: subjectY);

    // ----- Helper: run the full pipeline for a given PoV / me-delegate -----
    Future<ContentAggregation> runPipeline({
      required DemoIdentityKey pov,
      required DemoDelegateKey meDelegate,
    }) async {
      final trustSource =
          DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
      final graph = await TrustPipeline(trustSource).build(pov.id);
      final delegateResolver = DelegateResolver(graph);

      final appSource =
          DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
      final contentPipeline = ContentPipeline(delegateSource: appSource);

      final Set<DelegateKey> keysToFetch = {};
      for (final identity in graph.orderedKeys) {
        keysToFetch.addAll(delegateResolver.getDelegatesForIdentity(identity));
      }
      keysToFetch.add(meDelegate.id);

      final delegateContent = await contentPipeline.fetchDelegateContent(
        keysToFetch,
        delegateResolver: delegateResolver,
        graph: graph,
      );
      final contentResult = ContentResult(delegateContent: delegateContent);
      final followNetwork = reduceFollowNetwork(
          graph, delegateResolver, contentResult, kFollowContextNerdster);
      final labeler = Labeler(graph,
          delegateResolver: delegateResolver,
          meIdentity: delegateResolver.getIdentityForDelegate(meDelegate.id));

      return reduceContentAggregation(
        followNetwork,
        graph,
        delegateResolver,
        contentResult,
        enableCensorship: false,
        meDelegateKeys: [meDelegate.id],
        labeler: labeler,
      );
    }

    // ----- Assertions from A's PoV -----
    {
      final agg = await runPipeline(pov: userA, meDelegate: delegateA);

      // The canonical subject X should appear in the feed.
      final xKey = ContentKey(getToken(subjectX));
      final xAgg = agg.subjects[xKey];
      expect(xAgg, isNotNull, reason: 'Subject X should appear in A\'s feed');

      // A's rate (comment "XXX") must be findable under X in myLiteralStatements.
      final myStmtsForX = agg.myLiteralStatements[xKey] ?? [];
      final myRate = myStmtsForX.where((s) => s.verb == ContentVerb.rate).toList();
      expect(myRate, isNotEmpty,
          reason: 'A\'s rate should be in myLiteralStatements[X] (comment "XXX" lost)');
      expect(myRate.first.comment, equals('XXX'),
          reason: 'A\'s prior comment should be "XXX"');
    }

    // ----- Assertions from B's PoV -----
    {
      final agg = await runPipeline(pov: userB, meDelegate: delegateB);

      // The canonical subject X should appear in B's feed too.
      final xKey = ContentKey(getToken(subjectX));
      final xAgg = agg.subjects[xKey];
      expect(xAgg, isNotNull, reason: 'Subject X (canonical) should appear in B\'s feed');

      // B's rate was on Y. After equating Y=>X, it must be reachable under X.
      final myStmtsForX = agg.myLiteralStatements[xKey] ?? [];
      final myRate = myStmtsForX.where((s) => s.verb == ContentVerb.rate).toList();
      expect(myRate, isNotEmpty,
          reason: 'B\'s rate (on Y) should be in myLiteralStatements[X] after equating Y=>X');
      expect(myRate.first.comment, equals('YYY'),
          reason: 'B\'s prior comment should be "YYY"');
    }
  });

  test('Comment from B (made with old delegate B1) is visible via X when pipeline uses B1+B2',
      () async {
    // This covers the case where a user rotated their delegate key:
    // the rating was made with B1 but the current signed-in delegate is B2.
    // The pipeline receives both B1 and B2 in meDelegateKeys (as the real
    // feed_controller does when it collects all delegates for the identity).

    // ----- Setup identities -----
    final userA = await DemoIdentityKey.findOrCreate('userA');
    final userB = await DemoIdentityKey.findOrCreate('userB');
    final delegateA = await userA.makeDelegate(); // userA-nerdster0
    final delegateB1 = await userB.makeDelegate(); // userB-nerdster0  (old, used for rating)
    final delegateB2 = await userB.makeDelegate(); // userB-nerdster1  (new, current)

    await userA.doTrust(TrustVerb.trust, userB, moniker: 'B');
    await userB.doTrust(TrustVerb.trust, userA, moniker: 'A');

    final Json subjectX = createTestSubject(title: 'Subject X');
    final Json subjectY = createTestSubject(title: 'Subject Y');

    await delegateA.doRate(subject: subjectX, comment: 'XXX');
    await delegateA.doFollow(userB, {kFollowContextNerdster: 1});

    // B rates Y using the OLD delegate (B1)
    await delegateB1.doRate(subject: subjectY, comment: 'YYY');
    await delegateB1.doFollow(userA, {kFollowContextNerdster: 1});

    // B equates Y => X using the NEW delegate (B2)
    await delegateB2.doRelate(ContentVerb.equate, subject: subjectX, other: subjectY);

    // ----- Run pipeline for B's PoV, providing BOTH of B's delegates -----
    final trustSource =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final graph = await TrustPipeline(trustSource).build(userB.id);
    final delegateResolver = DelegateResolver(graph);

    final appSource =
        DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final contentPipeline = ContentPipeline(delegateSource: appSource);

    final Set<DelegateKey> keysToFetch = {};
    for (final identity in graph.orderedKeys) {
      keysToFetch.addAll(delegateResolver.getDelegatesForIdentity(identity));
    }
    keysToFetch.addAll([delegateB1.id, delegateB2.id]);

    final delegateContent = await contentPipeline.fetchDelegateContent(
      keysToFetch,
      delegateResolver: delegateResolver,
      graph: graph,
    );
    final contentResult = ContentResult(delegateContent: delegateContent);
    final followNetwork =
        reduceFollowNetwork(graph, delegateResolver, contentResult, kFollowContextNerdster);
    final labeler = Labeler(graph,
        delegateResolver: delegateResolver, meIdentity: userB.id);

    final agg = reduceContentAggregation(
      followNetwork,
      graph,
      delegateResolver,
      contentResult,
      enableCensorship: false,
      meDelegateKeys: [delegateB1.id, delegateB2.id], // both delegates
      labeler: labeler,
    );

    // The canonical subject X must appear in the feed
    final xKey = ContentKey(getToken(subjectX));
    expect(agg.subjects[xKey], isNotNull,
        reason: 'Subject X (canonical) should appear in B\'s feed');

    // B's rate (made with B1 on Y) must be reachable under X
    final myStmtsForX = agg.myLiteralStatements[xKey] ?? [];
    final myRate = myStmtsForX.where((s) => s.verb == ContentVerb.rate).toList();
    expect(myRate, isNotEmpty,
        reason:
            'B\'s rate (made with old delegate B1 on Y) should be in myLiteralStatements[X]');
    expect(myRate.first.comment, equals('YYY'),
        reason: 'B\'s prior comment should be "YYY" even when rated with old delegate');
  });
}
