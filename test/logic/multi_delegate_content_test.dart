import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:oneofus_common/fire_factory.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/demotest/test_util.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    setUpTestRegistry();

    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
  });

  test('Content from multiple delegates of same identity should be merged and distincted',
      () async {
    // 1. Setup Identity (Bob) and PoV (Alice)
    final DemoIdentityKey alice = await DemoIdentityKey.create('alice');
    final DemoIdentityKey bob = await DemoIdentityKey.create('bob');

    // Alice trusts Bob
    final TrustStatement trustStmt = await alice.doTrust(TrustVerb.trust, bob);

    // 2. Setup Bob's Delegates (D1, D2)
    final DemoDelegateKey d1 = await DemoDelegateKey.create('d1');
    final DemoDelegateKey d2 = await DemoDelegateKey.create('d2');

    final TrustStatement d1Stmt = await bob.delegate(d1, domain: 'nerdster.org');
    final TrustStatement d2Stmt = await bob.delegate(d2, domain: 'nerdster.org');

    // 3. Create Trust Graph & Resolver
    final TrustGraph graph = TrustGraph(
      pov: alice.id,
      distances: {alice.id: 0, bob.id: 1},
      orderedKeys: [alice.id, bob.id],
      edges: {
        alice.id: [trustStmt],
        bob.id: [d2Stmt, d1Stmt],
      },
      notifications: [],
    );
    final DelegateResolver resolver = DelegateResolver(graph);

    // Pre-resolve so the system knows Bob has d1 and d2
    resolver.resolveForIdentity(bob.id);
    expect(resolver.getDelegatesForIdentity(bob.id), containsAll([d1.id, d2.id]));

    // 4. Content Scenarios

    // Scenario A: Identical Content (Should be distincted to 1)
    // Both delegates rate "Cats" with 5 stars (recommend: true)
    // Since they map to the same Identity, and the content is identical, the distincter
    // should collapse these into a single statement attributed to the Identity.
    final Map<String, dynamic> cats = createTestSubject(title: 'Cats');
    final ContentStatement s1 = await d1.doRate(subject: cats, recommend: true, comment: 'Nice');
    await Future.delayed(Duration(milliseconds: 10)); // Ensure distinct timestamps
    final ContentStatement s2 = await d2.doRate(subject: cats, recommend: true, comment: 'Nice');

    // Scenario B: Conflicting Content (Singular Disposition - Latest Wins)
    final Map<String, dynamic> dogs = createTestSubject(title: 'Dogs');
    final ContentStatement s3 = await d1.doRate(subject: dogs, recommend: true);
    await Future.delayed(Duration(milliseconds: 10));
    final ContentStatement s4 = await d2.doRate(subject: dogs, recommend: false); // Dislike

    // Scenario C: Complementary Content (Latest Wins / Override)
    final Map<String, dynamic> birds = createTestSubject(title: 'Birds');
    final ContentStatement s5 = await d1.doRate(subject: birds, recommend: true);
    await Future.delayed(Duration(milliseconds: 10));
    final ContentStatement s6 =
        await d2.doRate(subject: birds, recommend: true, comment: 'Flying things');

    // 5. Prepare Content Result
    final Map<DelegateKey, List<ContentStatement>> delegateContent = {
      d1.id: [s5, s3, s1],
      d2.id: [s6, s4, s2],
    };
    final ContentResult contentResult = ContentResult(delegateContent: delegateContent);

    // 6. Run Aggregation
    final FollowNetwork followNet = FollowNetwork(
      fcontext: 'test',
      povIdentity: alice.id,
      identities: [alice.id, bob.id], // Ordered by trust
      edges: {}, // Not needed for this test
    );

    final ContentAggregation aggregation = reduceContentAggregation(
      followNet,
      graph,
      resolver,
      contentResult,
      enableCensorship: false,
      labeler: Labeler(graph, delegateResolver: resolver),
    );

    // 7. Assertions

    // catsAgg: expect 1 statement (deduplicated)
    final SubjectAggregation catsAgg = aggregation.subjects.values
        .firstWhere((SubjectAggregation s) => s.subject['title'] == 'Cats');
    expect(catsAgg.statements.length, 1,
        reason: "Identical statements from different delegates should be merged to 1");

    // dogsAgg: expect 1 statements (Latest wins - Singular Disposition)
    final SubjectAggregation dogsAgg = aggregation.subjects.values
        .firstWhere((SubjectAggregation s) => s.subject['title'] == 'Dogs');

    // Expectation for Singular Disposition:
    expect(dogsAgg.likes, 0, reason: "Old 'like' should be superseded");
    expect(dogsAgg.dislikes, 1, reason: "New 'dislike' should be active");

    expect(dogsAgg.statements.length, 1,
        reason: "History should be collapsed to latest disposition");
    expect(dogsAgg.statements.first.token, equals(s4.token));

    // birdsAgg: expect 1 statements (Latest wins)
    final SubjectAggregation birdsAgg = aggregation.subjects.values
        .firstWhere((SubjectAggregation s) => s.subject['title'] == 'Birds');
    expect(birdsAgg.statements.length, 1);
    expect(birdsAgg.statements.first.comment, equals('Flying things'));
  });
}
