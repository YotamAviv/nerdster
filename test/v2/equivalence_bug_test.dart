import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/demotest/cases/equivalence_bug.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/orchestrator.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    Setting.get(SettingType.debugUseSubjectNotToken).value = true;

    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoKey.reset();
  });

  test('Equivalence Bug: A=>B, B=>C should resolve to A=>B=>C', () async {
    // 1. Run the bug reproduction scenario
    final (poser, poserN, statements) = await equivalenceBugWithStatements();

    // 2. Fetch Data & Build Aggregation
    final trustSource = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final trustPipeline = TrustPipeline(trustSource);
    final graph = await trustPipeline.build(poser.id);
    final delegateResolver = DelegateResolver(graph);
    final followNetwork =
        reduceFollowNetwork(graph, delegateResolver, ContentResult(), kFollowContextNerdster);

    final appSource = DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final contentPipeline = ContentPipeline(
      delegateSource: appSource,
    );

    // We explicitly fetch content for all necessary delegates in the graph
    // to satisfy internal assertions in ContentLogic.
    final Set<DelegateKey> delegateKeysToFetch = {};
    for (final identity in graph.orderedKeys) {
      delegateKeysToFetch.addAll(delegateResolver.getDelegatesForIdentity(identity));
    }

    final delegateContent = await contentPipeline.fetchDelegateContent(
      delegateKeysToFetch,
      delegateResolver: delegateResolver,
      graph: graph,
    );

    final contentResult = ContentResult(
      delegateContent: delegateContent,
    );

    final labeler = V2Labeler(graph, delegateResolver: delegateResolver, meIdentityToken: poser.id);

    final aggregation = reduceContentAggregation(
      followNetwork,
      graph,
      delegateResolver,
      contentResult,
      enableCensorship: true,
      meDelegateKeys: [poserN!.id],
      labeler: labeler,
    );

    // 3. Define the Subject Keys
    final tokenA = statements[0].subjectToken;
    final tokenB = statements[1].subjectToken;
    final tokenC = statements[2].subjectToken;

    final keyA = ContentKey(tokenA);
    final keyB = ContentKey(tokenB);
    final keyC = ContentKey(tokenC);

    // 4. Inspect Results
    print('Token A: $tokenA');
    print('Token B: $tokenB');
    print('Token C: $tokenC');

    final subA = aggregation.subjects[keyA];
    final subB = aggregation.subjects[keyB];
    final subC = aggregation.subjects[keyC];

    // Expecting all to be merged into ONE subject
    // If they are separate entries in `subjects` map, it implies they failed to merge canonically
    // OR `subjects` contains multiple entries pointing to similar data?
    // Actually, `subjects` map key is the Canonical Token.
    // If A, B, C are equivalent, they should all resolve to the SAME Canonical Token.

    final canonA = aggregation.equivalence[keyA];
    final canonB = aggregation.equivalence[keyB];
    final canonC = aggregation.equivalence[keyC];

    print('Canon A: $canonA');
    print('Canon B: $canonB');
    print('Canon C: $canonC');

    // Assertion 1: All should map to the same canonical key
    expect(canonA, isNotNull, reason: "A should be in equivalence map");
    expect(canonA, equals(canonB), reason: "A and B should be equivalent");
    expect(canonB, equals(canonC), reason: "B and C should be equivalent");
    expect(canonA, equals(canonC), reason: "Transitive property: A and C should be equivalent");

    // Assertion 2: Only one entry in the subjects map should correspond to this group
    // The keys in `aggregation.subjects` are canonical tokens.
    // So if they all map to canonA (let's say), then:
    expect(aggregation.subjects.containsKey(canonA), isTrue);

    // Verify Statement Count
    // We rated A, B, C.
    // We equated A=B, B=C.
    // Total statements: 3 rates + 2 equates.
    // The SubjectAggregation for the canonical token should contain the relevant rate statements.
    final agg = aggregation.subjects[canonA]!;

    // We expect 3 distinct rating statements to be aggregated here
    final rateCount = agg.statements.where((s) => s.verb == ContentVerb.rate).length;
    expect(rateCount, 3, reason: " Should have 3 ratings merged");

    // We expect 2 distinct equate statements to be aggregated here
    final equateCount = agg.statements.where((s) => s.verb == ContentVerb.equate).length;
    expect(equateCount, 2, reason: " Should have 2 equates merged");

    // Verify View Logic Compatibility
    // Simulate the logic in StatementTile to ensure we can resolve titles for these equivalences
    // even when the statement's direct subject/other is not the canonical ID itself.
    for (final s in agg.statements.where((s) => s.verb == ContentVerb.equate)) {
      final ContentKey subjectCanonical =
          aggregation.equivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
      final ContentKey otherCanonical =
          aggregation.equivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other));
      final ContentKey thisCanonical = agg.canonical;

      String? displayText;
      // The UI logic prioritizes matching subjectCanonical first
      if (subjectCanonical == thisCanonical) {
        if (s.other is Map) {
          displayText = s.other['title'];
        }
      } else if (otherCanonical == thisCanonical) {
        if (s.subject is Map) {
          displayText = s.subject['title'];
        }
      }

      expect(displayText, isNotNull,
          reason: "UI should resolve display text for equivalence statement ${s.token}");
      expect(displayText, startsWith("Subject "),
          reason: "Should display the title of the equivalent subject");
    }

    // "Make a unit test ... Add some expects for what should be the outcome shown."
    // These expects demonstrate the "Happy Path". If the bug exists, these will fail.

    // 5. Clear Rating for A
    final sA = statements[0];
    print('Clearing A: ${sA.subjectToken}');
    await poserN!.doRate(subject: sA.subject, verb: ContentVerb.clear);

    // 6. Refresh Pipeline
    // Fetch new content reflecting the clear operation
    final newDelegateContent = await contentPipeline.fetchDelegateContent(
      delegateKeysToFetch,
      delegateResolver: delegateResolver,
      graph: graph,
    );

    final newContentResult = ContentResult(delegateContent: newDelegateContent);

    final newAggregation = reduceContentAggregation(
      followNetwork,
      graph,
      delegateResolver,
      newContentResult,
      enableCensorship: true,
      meDelegateKeys: [poserN.id],
      labeler: labeler,
    );

    // 7. Inspect Related Subjects
    print('--- Post Clear Inspection ---');
    final newCanonA = newAggregation.equivalence[keyA];
    expect(newCanonA, isNotNull, reason: "A should still be equivalent even if cleared");

    final newAgg = newAggregation.subjects[newCanonA]!;
    print('New Canonical for A: $newCanonA');
    print('Related Keys: ${newAgg.related}');

    // Resolve references to titles
    if (newAgg.related.isEmpty) {
      print('No related subjects found.');
    } else {
      for (final relatedKey in newAgg.related) {
        final relAgg = newAggregation.subjects[relatedKey];
        if (relAgg != null) {
          print('Related Title: ${relAgg.subject['title']}');
        } else {
          // Try to find definition in raw map if not top-level
          // But wait, where would we find it?
          print('Related Token (No Aggregation): ${relatedKey.value}');
        }
      }
    }

    // Also perform the UI Logic Check again for the persistence of A's title via Equivalence
    // Since A is cleared, we rely on the Equate statement (B->A) to provide the title.
    print('Checking Equivalence Titles persistence for A...');
    for (final s in newAgg.statements.where((s) => s.verb == ContentVerb.equate)) {
      final ContentKey subjectCanonical =
          newAggregation.equivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
      final ContentKey otherCanonical = newAggregation.equivalence[ContentKey(getToken(s.other))] ??
          ContentKey(getToken(s.other));
      final ContentKey thisCanonical = newAgg.canonical;

      String? displayText;
      if (subjectCanonical == thisCanonical) {
        assert(s.other is Map);
        displayText = s.other['title'];
      } else if (otherCanonical == thisCanonical) {
        assert(s.subject is Map);
        displayText = s.subject['title'];
      }
      print('Found Equivalence Title: $displayText');
    }
  });
}
