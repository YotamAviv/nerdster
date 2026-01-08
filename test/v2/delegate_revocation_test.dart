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

void main() {
  late FakeFirebaseFirestore fire;
  late DirectFirestoreSource<ContentStatement> contentSource;

  setUpAll(() {
    fireChoice = FireChoice.fake;
    TrustStatement.init();
    ContentStatement.init();
  });

  setUp(() {
    DemoKey.reset();
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
    final sideshow = await DemoIdentityKey.create('sideshow');
    final marge = await DemoIdentityKey.create('marge');
    final margeN = await DemoDelegateKey.create('margeN');

    // Marge delegates to margeN (Time T1)
    final s2 = await marge.delegate(margeN, domain: 'nerdster.org');

    // Sideshow revokes margeN as a delegate (Time T2)
    // Even though this is later in time, Sideshow is closer in the graph (Dist 0 vs Dist 1)
    final s1 = await sideshow.delegate(margeN, domain: 'nerdster.org', revokeAt: kSinceAlways);
    
    final tg = TrustGraph(
      pov: IdentityKey(sideshow.token),
      distances: {IdentityKey(sideshow.token): 0, IdentityKey(marge.token): 1},
      edges: {
        IdentityKey(sideshow.token): [s1],
        IdentityKey(marge.token): [s2],
      },
      notifications: [],
    );

    final resolver = DelegateResolver(tg);
    
    // Resolve for sideshow (Distance 0)
    resolver.resolveForIdentity(IdentityKey(sideshow.token));
    expect(resolver.getIdentityForDelegate(DelegateKey(margeN.token)), equals(IdentityKey(sideshow.token)), 
      reason: 'Sideshow claims margeN because he is closer, even though his statement is later');
    expect(resolver.getConstraintForDelegate(DelegateKey(margeN.token)), equals(kSinceAlways),
      reason: 'The delegate is claimed but revoked');

    // Resolve for marge (Distance 1)
    resolver.resolveForIdentity(IdentityKey(marge.token));
    expect(resolver.getIdentityForDelegate(DelegateKey(margeN.token)), equals(IdentityKey(sideshow.token)),
      reason: 'Marge cannot claim margeN because Sideshow already claimed it');
  });

  test('V2Labeler: Should label delegate correctly when revoked by owner', () async {
    final mel = await DemoIdentityKey.create('mel');
    final marge = await DemoIdentityKey.create('marge');
    final margeN = await DemoDelegateKey.create('margeN');

    // Mel trusts Marge
    final sMelMarge = await mel.doTrust(TrustVerb.trust, marge, moniker: 'Marge');

    // Marge delegates to margeN
    final sMargeDelegate = await marge.delegate(margeN, domain: 'nerdster.org');
    
    // Marge revokes margeN
    final sMargeRevoke = await marge.delegate(margeN, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final tg = TrustGraph(
      pov: IdentityKey(mel.token),
      distances: {IdentityKey(mel.token): 0, IdentityKey(marge.token): 1},
      orderedKeys: [IdentityKey(mel.token), IdentityKey(marge.token)],
      edges: {
        IdentityKey(mel.token): [sMelMarge],
        IdentityKey(marge.token): [sMargeRevoke, sMargeDelegate],
      },
      notifications: [],
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(IdentityKey(mel.token));
    resolver.resolveForIdentity(IdentityKey(marge.token));

    final labeler = V2Labeler(tg, delegateResolver: resolver);

    // margeN should be labeled as Marge@nerdster.org
    expect(labeler.getLabel(margeN.token), equals('Marge@nerdster.org'));
  });

  test('Delegate Revocation: Should filter statements after revokeAt', () async {
    final alice = await DemoIdentityKey.create('alice');
    final delegate = await DemoDelegateKey.create('delegate');

    // 1. Delegate signs two statements
    final s1 = await delegate.doRate(title: 'Good');
    final s2 = await delegate.doRate(title: 'Bad');

    await upload(delegate.token, s1);
    await upload(delegate.token, s2);

    // 2. Alice delegates to delegate
    final d1 = await alice.delegate(delegate, domain: 'nerdster.org');
    
    // 3. Alice revokes delegate at s1. 
    // passing s1.token directly as doTrust expects String?
    final d2 = await alice.delegate(delegate, domain: 'nerdster.org', revokeAt: s1.token);

    final tg = TrustGraph(
      pov: IdentityKey(alice.token),
      distances: {IdentityKey(alice.token): 0},
      edges: {
        IdentityKey(alice.token): [d2, d1],
      },
      notifications: [],
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(IdentityKey(alice.token));

    expect(resolver.getConstraintForDelegate(DelegateKey(delegate.token)), equals(IdentityKey(s1.token)));

    // 4. Fetch content
    final pipeline = ContentPipeline(
      delegateSource: contentSource,
    );
    final delegateKey = DelegateKey(delegate.token);
    final delegateContent = await pipeline.fetchDelegateContent(
      {delegateKey},
      delegateResolver: resolver,
      graph: tg,
    );

    final delegateStatements = delegateContent[delegateKey] ?? [];
    expect(delegateStatements.length, equals(1));
    expect(IdentityKey(delegateStatements.first.token), equals(IdentityKey(s1.token)));
  });

  test('Delegate Revocation: "<since always>" should revoke everything', () async {
    final bob = await DemoIdentityKey.create('bob');
    final delegate = await DemoDelegateKey.create('delegate2');

    final s1 = await delegate.doRate(title: 'Something');
    await upload(delegate.token, s1);

    final d1 = await bob.delegate(delegate, domain: 'nerdster.org');
    final d2 = await bob.delegate(delegate, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final tg = TrustGraph(
      pov: IdentityKey(bob.token),
      distances: {IdentityKey(bob.token): 0},
      edges: {
        IdentityKey(bob.token): [d2, d1],
      },
      notifications: [],
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(IdentityKey(bob.token));

    expect(resolver.getConstraintForDelegate(DelegateKey(delegate.token)), equals(kSinceAlways));

    final pipeline = ContentPipeline(
      delegateSource: contentSource,
    );
    final delegateKey = DelegateKey(delegate.token);
    final delegateContent = await pipeline.fetchDelegateContent(
      {delegateKey},
      delegateResolver: resolver,
      graph: tg,
    );

    expect(delegateContent[delegateKey], isEmpty);
  });

  test('Delegate Revocation: Should authorize even if revokeAt is present', () async {
    final alice = await DemoIdentityKey.create('alice');
    final delegate = await DemoDelegateKey.create('delegate');

    // Alice delegates to delegate with a revokeAt (maybe she's revoking an old session but authorizing the key)
    final d1 = await alice.delegate(delegate, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final tg = TrustGraph(
      pov: IdentityKey(alice.token),
      distances: {IdentityKey(alice.token): 0},
      edges: {
        IdentityKey(alice.token): [d1],
      },
      notifications: [],
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(IdentityKey(alice.token));

    expect(resolver.getIdentityForDelegate(DelegateKey(delegate.token)), equals(IdentityKey(alice.token)),
      reason: 'Delegate should be authorized even if revokeAt is present');
    expect(resolver.getConstraintForDelegate(DelegateKey(delegate.token)), equals(kSinceAlways));
  });

  test('Delegate Revocation: Comprehensive test (Revoked but still a delegate)', () async {
    final bob = await DemoIdentityKey.create('bob');
    final delegate = await DemoDelegateKey.create('delegate3');

    // 1. Delegate signs a statement (S1)
    final s1 = await delegate.doRate(title: 'Before Revocation');
    await upload(delegate.token, s1);

    // 2. Bob delegates to delegate
    final d1 = await bob.delegate(delegate, domain: 'nerdster.org');
    
    // 3. Bob revokes delegate at S1
    final d2 = await bob.delegate(delegate, domain: 'nerdster.org', revokeAt: s1.token);

    // 4. Delegate signs another statement (S2) AFTER revocation
    final s2 = await delegate.doRate(title: 'After Revocation');
    await upload(delegate.token, s2);

    final tg = TrustGraph(
      pov: IdentityKey(bob.token),
      distances: {IdentityKey(bob.token): 0},
      edges: {
        IdentityKey(bob.token): [d2, d1], // Sorted by time descending
      },
      notifications: [],
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(IdentityKey(bob.token));

    // Verify it's still a delegate
    expect(resolver.getIdentityForDelegate(DelegateKey(delegate.token)), equals(IdentityKey(bob.token)));
    expect(resolver.getConstraintForDelegate(DelegateKey(delegate.token)), equals(IdentityKey(s1.token)));

    // Verify content filtering
    final pipeline = ContentPipeline(
      delegateSource: contentSource,
    );
    final delegateKey = DelegateKey(delegate.token);
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

    // 4. Bo revokes boD1 at IdentityKey(sFollow.token)
    final sRevoke1 = await bo.delegate(boD1, domain: 'nerdster.org', revokeAt: sFollow.token);

    // Setup Graph
    final tg = TrustGraph(
      pov: IdentityKey(bo.token),
      distances: {IdentityKey(bo.token): 0},
      orderedKeys: [IdentityKey(bo.token)],
      edges: {
        IdentityKey(bo.token): [sRevoke1, sDelegate2, sDelegate1],
      },
      notifications: [],
    );

    // Setup Content
    final delegateKey = DelegateKey(boD1.token);
    final contentResult = ContentResult(
      delegateContent: {
        delegateKey: [sFollow],
      },
    );

    final delegateResolver = DelegateResolver(tg);
    
    // Run Follow Logic
    final fn = reduceFollowNetwork(tg, delegateResolver, contentResult, 'social');

    // Assert
    expect(fn.edges[IdentityKey(bo.token)], isNotNull);
    expect(fn.edges[IdentityKey(bo.token)]!.any((s) => s.subjectToken == IdentityKey(luke.token)), isTrue,
        reason: 'Bo should still follow Luke because the delegate was revoked AT the follow statement');
  });

  test('V2Labeler: Should number multiple delegates for same identity and domain', () async {
    final bob = await DemoIdentityKey.create('bob');
    final d1 = await DemoDelegateKey.create('d1');
    final d2 = await DemoDelegateKey.create('d2');

    // Bob delegates to d1 and d2
    final s1 = await bob.delegate(d1, domain: 'nerdster.org');
    final s2 = await bob.delegate(d2, domain: 'nerdster.org');
    
    // Bob is trusted by POV (me) so he gets a name
    final me = await DemoIdentityKey.create('me');
    final sTrust = await me.doTrust(TrustVerb.trust, bob, moniker: 'Bob');

    final tg = TrustGraph(
      pov: IdentityKey(me.token),
      distances: {IdentityKey(me.token): 0, IdentityKey(bob.token): 1},
      orderedKeys: [IdentityKey(me.token), IdentityKey(bob.token)],
      edges: {
        IdentityKey(me.token): [sTrust],
        IdentityKey(bob.token): [s1, s2], 
      },
      notifications: [],
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(IdentityKey(bob.token));

    final labeler = V2Labeler(tg, delegateResolver: resolver);

    expect(labeler.getLabel(d1.token), equals('Bob@nerdster.org'));
    expect(labeler.getLabel(d2.token), equals('Bob@nerdster.org (2)'));
  });
}
