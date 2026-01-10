import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/util.dart';

import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/demotest/test_util.dart';

void main() {
  late FakeFirebaseFirestore fire;
  late DirectFirestoreSource<ContentStatement> contentSource;

  setUp(() {
    setUpTestRegistry();
    fireChoice = FireChoice.fake;
    fire = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, fire, null);
    FireFactory.register(kNerdsterDomain, fire, null);
    contentSource = DirectFirestoreSource<ContentStatement>(fire);
  });

  Future<void> upload(String token, Statement s) async {
    await fire
        .collection(token)
        .doc('statements')
        .collection('statements')
        .doc(s.token)
        .set(s.jsonish.json);
  }

  test('DelegateResolver: Revoked delegate is still claimed by revoker (Proximity wins)', () async {
    final DemoIdentityKey sideshow = await DemoIdentityKey.create('sideshow');
    final DemoIdentityKey marge = await DemoIdentityKey.create('marge');
    final DemoDelegateKey margeN = await DemoDelegateKey.create('margeN');

    // Marge delegates to margeN (Time T1)
    final TrustStatement s2 = await marge.delegate(margeN, domain: 'nerdster.org');

    // Sideshow revokes margeN as a delegate (Time T2)
    // Even though this is later in time, Sideshow is closer in the graph (Dist 0 vs Dist 1)
    final TrustStatement s1 = await sideshow.delegate(margeN, domain: 'nerdster.org', revokeAt: kSinceAlways);
    
    final TrustGraph tg = TrustGraph(
      pov: sideshow.id,
      distances: {sideshow.id: 0, marge.id: 1},
      edges: {
        sideshow.id: [s1],
        marge.id: [s2],
      },
      notifications: [],
    );

    final DelegateResolver resolver = DelegateResolver(tg);
    
    // Resolve for sideshow (Distance 0)
    resolver.resolveForIdentity(sideshow.id);
    expect(resolver.getIdentityForDelegate(margeN.id), equals(sideshow.id), 
      reason: 'Sideshow claims margeN because he is closer, even though his statement is later');
    expect(resolver.getConstraintForDelegate(margeN.id), equals(kSinceAlways),
      reason: 'The delegate is claimed but revoked');

    // Resolve for marge (Distance 1)
    resolver.resolveForIdentity(marge.id);
    expect(resolver.getIdentityForDelegate(margeN.id), equals(sideshow.id),
      reason: 'Marge cannot claim margeN because Sideshow already claimed it');
  });

  test('V2Labeler: Should label delegate correctly when revoked by owner', () async {
    final mel = await DemoIdentityKey.create('mel');
    final DemoIdentityKey marge = await DemoIdentityKey.create('marge');
    final DemoDelegateKey margeN = await DemoDelegateKey.create('margeN');

    // Mel trusts Marge
    final TrustStatement sMelMarge = await mel.doTrust(TrustVerb.trust, marge, moniker: 'Marge');

    // Marge delegates to margeN
    final TrustStatement sMargeDelegate = await marge.delegate(margeN, domain: 'nerdster.org');
    
    // Marge revokes margeN
    final TrustStatement sMargeRevoke = await marge.delegate(margeN, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final TrustGraph tg = TrustGraph(
      pov: mel.id,
      distances: {mel.id: 0, marge.id: 1},
      orderedKeys: [mel.id, marge.id],
      edges: {
        mel.id: [sMelMarge],
        marge.id: [sMargeRevoke, sMargeDelegate],
      },
      notifications: [],
    );

    final DelegateResolver resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(mel.id);
    resolver.resolveForIdentity(marge.id);

    final labeler = V2Labeler(tg, delegateResolver: resolver);

    // margeN should be labeled as Marge@nerdster.org
    expect(labeler.getLabel(margeN.token), equals('Marge@nerdster.org'));
  });

  test('Delegate Revocation: Should filter statements after revokeAt', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final delegate = await DemoDelegateKey.create('delegate');

    // 1. Delegate signs two statements
    final ContentStatement s1 = await delegate.doRate(title: 'Good');
    final ContentStatement s2 = await delegate.doRate(title: 'Bad');

    await upload(delegate.token, s1);
    await upload(delegate.token, s2);

    // 2. Alice delegates to delegate
    final TrustStatement d1 = await alice.delegate(delegate, domain: 'nerdster.org');
    
    // 3. Alice revokes delegate at s1. 
    // passing s1.token directly as doTrust expects String?
    final TrustStatement d2 = await alice.delegate(delegate, domain: 'nerdster.org', revokeAt: s1.token);

    final TrustGraph tg = TrustGraph(
      pov: alice.id,
      distances: {alice.id: 0},
      edges: {
        alice.id: [d2, d1],
      },
      notifications: [],
    );

    final DelegateResolver resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(alice.id);

    expect(resolver.getConstraintForDelegate(delegate.id), equals(ContentKey(s1.token)));

    // 4. Fetch content
    final pipeline = ContentPipeline(
      delegateSource: contentSource,
    );
    final delegateKey = delegate.id;
    final delegateContent = await pipeline.fetchDelegateContent(
      {delegateKey},
      delegateResolver: resolver,
      graph: tg,
    );

    final delegateStatements = delegateContent[delegateKey] ?? [];
    expect(delegateStatements.length, equals(1));
    expect(ContentKey(delegateStatements.first.token), equals(ContentKey(s1.token)));
  });

  test('Delegate Revocation: "<since always>" should revoke everything', () async {
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final delegate = await DemoDelegateKey.create('delegate2');

    final ContentStatement s1 = await delegate.doRate(title: 'Something');
    await upload(delegate.token, s1);

    final TrustStatement d1 = await bob.delegate(delegate, domain: 'nerdster.org');
    final TrustStatement d2 = await bob.delegate(delegate, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final TrustGraph tg = TrustGraph(
      pov: bob.id,
      distances: {bob.id: 0},
      edges: {
        bob.id: [d2, d1],
      },
      notifications: [],
    );

    final DelegateResolver resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(bob.id);

    expect(resolver.getConstraintForDelegate(delegate.id), equals(kSinceAlways));

    final pipeline = ContentPipeline(
      delegateSource: contentSource,
    );
    final delegateKey = delegate.id;
    final delegateContent = await pipeline.fetchDelegateContent(
      {delegateKey},
      delegateResolver: resolver,
      graph: tg,
    );

    expect(delegateContent[delegateKey], isEmpty);
  });

  test('Delegate Revocation: Should authorize even if revokeAt is present', () async {
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final delegate = await DemoDelegateKey.create('delegate');

    // Alice delegates to delegate with a revokeAt (maybe she's revoking an old session but authorizing the key)
    final TrustStatement d1 = await alice.delegate(delegate, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final TrustGraph tg = TrustGraph(
      pov: alice.id,
      distances: {alice.id: 0},
      edges: {
        alice.id: [d1],
      },
      notifications: [],
    );

    final DelegateResolver resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(alice.id);

    expect(resolver.getIdentityForDelegate(delegate.id), equals(alice.id),
      reason: 'Delegate should be authorized even if revokeAt is present');
    expect(resolver.getConstraintForDelegate(delegate.id), equals(kSinceAlways));
  });

  test('Delegate Revocation: Comprehensive test (Revoked but still a delegate)', () async {
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final delegate = await DemoDelegateKey.create('delegate3');

    // 1. Delegate signs a statement (S1)
    final ContentStatement s1 = await delegate.doRate(title: 'Before Revocation');
    await upload(delegate.token, s1);

    // 2. Bob delegates to delegate
    final TrustStatement d1 = await bob.delegate(delegate, domain: 'nerdster.org');
    
    // 3. Bob revokes delegate at S1
    final TrustStatement d2 = await bob.delegate(delegate, domain: 'nerdster.org', revokeAt: s1.token);

    // 4. Delegate signs another statement (S2) AFTER revocation
    final ContentStatement s2 = await delegate.doRate(title: 'After Revocation');
    await upload(delegate.token, s2);

    final TrustGraph tg = TrustGraph(
      pov: bob.id,
      distances: {bob.id: 0},
      edges: {
        bob.id: [d2, d1], // Sorted by time descending
      },
      notifications: [],
    );

    final DelegateResolver resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(bob.id);

    // Verify it's still a delegate
    expect(resolver.getIdentityForDelegate(delegate.id), equals(bob.id));
    expect(resolver.getConstraintForDelegate(delegate.id), equals(IdentityKey(s1.token)));

    // Verify content filtering
    final pipeline = ContentPipeline(
      delegateSource: contentSource,
    );
    final delegateKey = delegate.id;
    final delegateContent = await pipeline.fetchDelegateContent(
      {delegateKey},
      delegateResolver: resolver,
      graph: tg,
    );

    final delegateStatements = delegateContent[delegateKey] ?? [];
    
    // Should only contain S1
    expect(delegateStatements.any((s) => IdentityKey(s.token) == IdentityKey(s1.token)), isTrue, reason: 'S1 should be present');
    expect(delegateStatements.any((s) => IdentityKey(s.token) == IdentityKey(s2.token)), isFalse, reason: 'S2 should be ignored');
    expect(delegateStatements.length, equals(1));
  });

  test('Bo follows Luke, revokes delegate at follow statement, follow should persist', () async {
    final bo = await DemoIdentityKey.create('bo');
    final luke = await DemoIdentityKey.create('luke');
    final boD1 = await DemoDelegateKey.create('boD1');
    final boD2 = await DemoDelegateKey.create('boD2');

    // 1. Bo delegates to boD1
    final sDelegate1 = await bo.delegate(boD1, domain: 'nerdster.org');

    // 2. Bo (via boD1) follows Luke
    final sFollow = await boD1.doFollow(luke, {'social': 1});

    // 3. Bo delegates to boD2
    final sDelegate2 = await bo.delegate(boD2, domain: 'nerdster.org');

    // 4. Bo revokes boD1 at sFollow.id
    final sRevoke1 = await bo.delegate(boD1, domain: 'nerdster.org', revokeAt: sFollow.token);

    // Setup Graph
    final TrustGraph tg = TrustGraph(
      pov: bo.id,
      distances: {bo.id: 0},
      orderedKeys: [bo.id],
      edges: {
        bo.id: [sRevoke1, sDelegate2, sDelegate1],
      },
      notifications: [],
    );

    // Setup Content
    final delegateKey = boD1.id;
    final contentResult = ContentResult(
      delegateContent: {
        delegateKey: [sFollow],
      },
    );

    final delegateResolver = DelegateResolver(tg);
    
    // Run Follow Logic
    final fn = reduceFollowNetwork(tg, delegateResolver, contentResult, 'social');

    // Assert
    expect(fn.edges[bo.id], isNotNull);
    expect(fn.edges[bo.id]!.any((s) => IdentityKey(s.subjectToken!) == luke.id), isTrue,
        reason: 'Bo should still follow Luke because the delegate was revoked AT the follow statement');
  });

  test('V2Labeler: Should number multiple delegates for same identity and domain', () async {
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');
    final DemoDelegateKey d1 = await DemoDelegateKey.create('d1');
    final DemoDelegateKey d2 = await DemoDelegateKey.create('d2');

    // Bob delegates to d1 and d2
    final TrustStatement s1 = await bob.delegate(d1, domain: 'nerdster.org');
    final TrustStatement s2 = await bob.delegate(d2, domain: 'nerdster.org');
    
    // Bob is trusted by POV (me) so he gets a name
    final me = await DemoIdentityKey.create('me');
    final sTrust = await me.doTrust(TrustVerb.trust, bob, moniker: 'Bob');

    final TrustGraph tg = TrustGraph(
      pov: me.id,
      distances: {me.id: 0, bob.id: 1},
      orderedKeys: [me.id, bob.id],
      edges: {
        me.id: [sTrust],
        bob.id: [s1, s2], 
      },
      notifications: [],
    );

    final DelegateResolver resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(bob.id);

    final labeler = V2Labeler(tg, delegateResolver: resolver);

    expect(labeler.getLabel(d1.token), equals('Bob@nerdster.org'));
    expect(labeler.getLabel(d2.token), equals('Bob@nerdster.org (2)'));
  });
}
