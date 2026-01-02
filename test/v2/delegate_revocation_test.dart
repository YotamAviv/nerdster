import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/util.dart';

import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/demotest/demo_key.dart';

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

  test('DelegateResolver: Should not pick up revoked delegates', () async {
    final sideshow = await DemoKey.create('sideshow');
    final marge = await DemoKey.create('marge');
    final margeN = await DemoKey.create('margeN');

    // Sideshow revokes margeN as a delegate (even though he doesn't own it)
    final s1 = await sideshow.doTrust(TrustVerb.delegate, margeN, revokeAt: kSinceAlways);
    
    // Marge delegates to margeN
    final s2 = await marge.doTrust(TrustVerb.delegate, margeN, domain: 'nerdster.org');

    final tg = TrustGraph(
      root: sideshow.token,
      distances: {sideshow.token: 0, marge.token: 1},
      edges: {
        sideshow.token: [s1],
        marge.token: [s2],
      },
    );

    final resolver = DelegateResolver(tg);
    
    // Resolve for sideshow
    resolver.resolveForIdentity(sideshow.token);
    expect(resolver.getIdentityForDelegate(margeN.token), equals(sideshow.token), 
      reason: 'Sideshow claimed margeN (even if he revoked it)');

    // Resolve for marge
    resolver.resolveForIdentity(marge.token);
    expect(resolver.getIdentityForDelegate(margeN.token), equals(sideshow.token),
      reason: 'Sideshow still owns it because he claimed it first');
  });

  test('V2Labeler: Should label delegate correctly when revoked by owner', () async {
    final mel = await DemoKey.create('mel');
    final marge = await DemoKey.create('marge');
    final margeN = await DemoKey.create('margeN');

    // Mel trusts Marge
    final sMelMarge = await mel.doTrust(TrustVerb.trust, marge, moniker: 'Marge');

    // Marge delegates to margeN
    final sMargeDelegate = await marge.doTrust(TrustVerb.delegate, margeN, domain: 'nerdster.org');
    
    // Marge revokes margeN
    final sMargeRevoke = await marge.doTrust(TrustVerb.delegate, margeN, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final tg = TrustGraph(
      root: mel.token,
      distances: {mel.token: 0, marge.token: 1},
      orderedKeys: [mel.token, marge.token],
      edges: {
        mel.token: [sMelMarge],
        marge.token: [sMargeRevoke, sMargeDelegate],
      },
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(mel.token);
    resolver.resolveForIdentity(marge.token);

    final labeler = V2Labeler(tg, delegateResolver: resolver);

    // margeN should be labeled as Marge@nerdster.org
    expect(labeler.getLabel(margeN.token), equals('Marge@nerdster.org'));
  });

  test('Delegate Revocation: Should filter statements after revokeAt', () async {
    final alice = await DemoKey.create('alice');
    final delegate = await DemoKey.create('delegate');

    // 1. Delegate signs two statements
    final s1 = await delegate.doRate(title: 'Good');
    final s2 = await delegate.doRate(title: 'Bad');

    await upload(delegate.token, s1);
    await upload(delegate.token, s2);

    // 2. Alice delegates to delegate
    final d1 = await alice.doTrust(TrustVerb.delegate, delegate, domain: 'nerdster.org');
    
    // 3. Alice revokes delegate at s1
    final d2 = await alice.doTrust(TrustVerb.delegate, delegate, revokeAt: s1.token);

    final tg = TrustGraph(
      root: alice.token,
      distances: {alice.token: 0},
      edges: {
        alice.token: [d2, d1],
      },
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(alice.token);

    expect(resolver.getConstraintForDelegate(delegate.token), equals(s1.token));

    // 4. Fetch content
    final pipeline = ContentPipeline(contentSource: contentSource);
    final contentMap = await pipeline.fetchContentMap(tg, resolver);

    final delegateStatements = contentMap[delegate.token] ?? [];
    expect(delegateStatements.length, equals(1));
    expect(delegateStatements.first.token, equals(s1.token));
  });

  test('Delegate Revocation: "<since always>" should revoke everything', () async {
    final bob = await DemoKey.create('bob');
    final delegate = await DemoKey.create('delegate2');

    final s1 = await delegate.doRate(title: 'Something');
    await upload(delegate.token, s1);

    final d1 = await bob.doTrust(TrustVerb.delegate, delegate, domain: 'nerdster.org');
    final d2 = await bob.doTrust(TrustVerb.delegate, delegate, revokeAt: kSinceAlways);

    final tg = TrustGraph(
      root: bob.token,
      distances: {bob.token: 0},
      edges: {
        bob.token: [d2, d1],
      },
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(bob.token);

    expect(resolver.getConstraintForDelegate(delegate.token), equals(kSinceAlways));

    final pipeline = ContentPipeline(contentSource: contentSource);
    final contentMap = await pipeline.fetchContentMap(tg, resolver);

    expect(contentMap[delegate.token], isEmpty);
  });

  test('Delegate Revocation: Should authorize even if revokeAt is present', () async {
    final alice = await DemoKey.create('alice');
    final delegate = await DemoKey.create('delegate');

    // Alice delegates to delegate with a revokeAt (maybe she's revoking an old session but authorizing the key)
    final d1 = await alice.doTrust(TrustVerb.delegate, delegate, domain: 'nerdster.org', revokeAt: kSinceAlways);

    final tg = TrustGraph(
      root: alice.token,
      distances: {alice.token: 0},
      edges: {
        alice.token: [d1],
      },
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(alice.token);

    expect(resolver.getIdentityForDelegate(delegate.token), equals(alice.token),
      reason: 'Delegate should be authorized even if revokeAt is present');
    expect(resolver.getConstraintForDelegate(delegate.token), equals(kSinceAlways));
  });

  test('Delegate Revocation: Comprehensive test (Revoked but still a delegate)', () async {
    final bob = await DemoKey.create('bob');
    final delegate = await DemoKey.create('delegate3');

    // 1. Delegate signs a statement (S1)
    final s1 = await delegate.doRate(title: 'Before Revocation');
    await upload(delegate.token, s1);

    // 2. Bob delegates to delegate
    final d1 = await bob.doTrust(TrustVerb.delegate, delegate, domain: 'nerdster.org');
    
    // 3. Bob revokes delegate at S1
    final d2 = await bob.doTrust(TrustVerb.delegate, delegate, revokeAt: s1.token);

    // 4. Delegate signs another statement (S2) AFTER revocation
    final s2 = await delegate.doRate(title: 'After Revocation');
    await upload(delegate.token, s2);

    final tg = TrustGraph(
      root: bob.token,
      distances: {bob.token: 0},
      edges: {
        bob.token: [d2, d1], // Sorted by time descending
      },
    );

    final resolver = DelegateResolver(tg);
    resolver.resolveForIdentity(bob.token);

    // Verify it's still a delegate
    expect(resolver.getIdentityForDelegate(delegate.token), equals(bob.token));
    expect(resolver.getConstraintForDelegate(delegate.token), equals(s1.token));

    // Verify content filtering
    final pipeline = ContentPipeline(contentSource: contentSource);
    final contentMap = await pipeline.fetchContentMap(tg, resolver);

    final delegateStatements = contentMap[delegate.token] ?? [];
    
    // Should only contain S1
    expect(delegateStatements.any((s) => s.token == s1.token), isTrue, reason: 'S1 should be present');
    expect(delegateStatements.any((s) => s.token == s2.token), isFalse, reason: 'S2 should be ignored');
    expect(delegateStatements.length, equals(1));
  });
}
