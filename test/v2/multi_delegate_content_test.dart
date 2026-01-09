import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/demotest/test_util.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    DemoKey.reset();
    ContentStatement.init();
    TrustStatement.init();
    
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
  });

  test('Content from multiple delegates of same identity should be merged and distincted', () async {
    // 1. Setup Identity (Bob) and PoV (Alice)
    final alice = await DemoIdentityKey.create('alice');
    final bob = await DemoIdentityKey.create('bob');
    
    // Alice trusts Bob
    final trustStmt = await alice.doTrust(TrustVerb.trust, bob);

    // 2. Setup Bob's Delegates (D1, D2)
    final d1 = await DemoDelegateKey.create('d1');
    final d2 = await DemoDelegateKey.create('d2');

    final d1Stmt = await bob.delegate(d1, domain: 'nerdster.org');
    final d2Stmt = await bob.delegate(d2, domain: 'nerdster.org');

    // 3. Create Trust Graph & Resolver
    final graph = TrustGraph(
      pov: alice.id,
      distances: {alice.id: 0, bob.id: 1},
      orderedKeys: [alice.id, bob.id],
      edges: {
        alice.id: [trustStmt],
        bob.id: [d1Stmt, d2Stmt],
      },
      notifications: [],
    );
    final resolver = DelegateResolver(graph);
    
    // Pre-resolve so the system knows Bob has d1 and d2
    resolver.resolveForIdentity(bob.id);
    expect(resolver.getDelegatesForIdentity(bob.id), containsAll([d1.id, d2.id]));

    // 4. Content Scenarios
    
    // Scenario A: Identical Content (Should be distincted to 1)
    // Both delegates rate "Cats" with 5 stars (recommend: true)
    // Since they map to the same Identity, and the content is identical, the distincter
    // should collapse these into a single statement attributed to the Identity.
    final cats = createTestSubject(title: 'Cats');
    final s1 = await d1.doRate(subject: cats, recommend: true, comment: 'Nice');
    await Future.delayed(Duration(milliseconds: 10)); // Ensure distinct timestamps
    final s2 = await d2.doRate(subject: cats, recommend: true, comment: 'Nice');

    // Scenario B: Conflicting Content (Singular Disposition - Latest Wins)
    // D1 rates "Dogs" true. Later, D2 rates "Dogs" false.
    // "Bob" (the Identity) gets only one vote. His latest action (via D2) should supersede the previous one.
    // The distincter logic is smart enough to handle this if distinct signatures match.
    // However, if the distinct signature includes the 'content' (like recommend:true vs false), 
    // then distincter WON'T collapse them, and the Aggregation logic must handle the override.
    //
    // Let's verify what actually happens.
    final dogs = createTestSubject(title: 'Dogs');
    final s3 = await d1.doRate(subject: dogs, recommend: true);
    await Future.delayed(Duration(milliseconds: 10));
    final s4 = await d2.doRate(subject: dogs, recommend: false); // Dislike

    // Scenario C: Complementary Content (Latest Wins / Override)
    // D1 rates "Birds". Later, D2 rates "Birds" with a comment.
    // This is effectively an update to the rating.
    final birds = createTestSubject(title: 'Birds');
    final s5 = await d1.doRate(subject: birds, recommend: true);
    await Future.delayed(Duration(milliseconds: 10));
    final s6 = await d2.doRate(subject: birds, recommend: true, comment: 'Flying things');


    // 5. Prepare Content Result
    final Map<DelegateKey, List<ContentStatement>> delegateContent = {
      d1.id: [s1, s3, s5],
      d2.id: [s2, s4, s6],
    };
    final contentResult = ContentResult(delegateContent: delegateContent);

    // 6. Run Aggregation
    final followNet = FollowNetwork(
      fcontext: 'test',
      povIdentity: alice.id,
      identities: [alice.id, bob.id], // Ordered by trust
      edges: {}, // Not needed for this test
    );

    final aggregation = reduceContentAggregation(
      followNet,
      graph,
      resolver,
      contentResult,
      enableCensorship: false,
    );

    // 7. Assertions

    // catsAgg: expect 1 statement (deduplicated)
    final catsAgg = aggregation.subjects.values.firstWhere((s) => s.subject['title'] == 'Cats');
    expect(catsAgg.statements.length, 1, reason: "Identical statements from different delegates should be merged to 1");
    
    // dogsAgg: expect 1 statements (Latest wins - Singular Disposition)
    // Bob cannot vote "True" and then vote "False" and have both count.
    // The aggregation must end up with the latest state.
    final dogsAgg = aggregation.subjects.values.firstWhere((s) => s.subject['title'] == 'Dogs');
    
    // DEBUG: Print what we actually got to understand current behavior
    print('Dogs Statements: ${dogsAgg.statements.length}');
    for(var s in dogsAgg.statements) {
       print(' - ${s.token} (${s.time}): recommend=${s.like}');
    }

    // Expectation for Singular Disposition:
    // We expect the system to interpret this as a change of heart.
    // Therefore, only the latest statement (s4 Dislike) should be effective.
    expect(dogsAgg.likes, 0, reason: "Old 'like' should be superseded");
    expect(dogsAgg.dislikes, 1, reason: "New 'dislike' should be active");
    
    // Ideally we only see the latest statement in the list too, but if the implementation
    // keeps history but only counts latest score, that might be acceptable (though distincter ideally filters).
    // Let's assert strict cleanliness for now.
    expect(dogsAgg.statements.length, 1, reason: "History should be collapsed to latest disposition");
    expect(dogsAgg.statements.first.token, equals(s4.token));

    // birdsAgg: expect 1 statements (Latest wins)
    // D2 was latest (s6, comment: 'Flying things')
    final birdsAgg = aggregation.subjects.values.firstWhere((s) => s.subject['title'] == 'Birds');
    expect(birdsAgg.statements.length, 1);
    expect(birdsAgg.statements.first.comment, equals('Flying things'));

  });
}
