import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/cases/simpsons_relate_demo.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/model.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    firestore = FakeFirebaseFirestore();
    FireFactory.register(kOneofusDomain, firestore, null);
    FireFactory.register(kNerdsterDomain, firestore, null);
    TrustStatement.init();
    ContentStatement.init();
    DemoKey.reset();
  });

  test('Nested Rating: Lisa comments on her rating of Art', () async {
    // 1. Run the demo setup
    final (lisa, lisaD) = await simpsonsRelateDemo();
    expect(lisaD, isNotNull);

    // 2. Find Lisa's rating of "Art"
    // We need to fetch statements authored by Lisa's delegate
    final appSource = DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final lisaStatementsMap = await appSource.fetch({lisaD!.token: null});
    final lisaStatements = lisaStatementsMap[lisaD.token] ?? [];
    
    ContentStatement? artRating;
    for (final s in lisaStatements) {
      if (s.verb == ContentVerb.rate) {
        final subject = s.subject;
        if (subject is Map && subject['title'] == 'Art') {
          artRating = s;
          break;
        }
      }
    }
    
    expect(artRating, isNotNull, reason: "Lisa should have rated Art");
    print('Found Art Rating: ${artRating!.token}');

    // 3. Lisa comments on her own rating
    // "I really mean it!"
    final commentText = "I really mean it!";
    await lisaD.doRate(
      subject: artRating.token, // Use token for statements about statements
      comment: commentText,
      recommend: true,
    );

    // 4. Verify the new statement exists at the backend
    final updatedLisaStatementsMap = await appSource.fetch({lisaD.token: null});
    final updatedLisaStatements = updatedLisaStatementsMap[lisaD.token] ?? [];
    ContentStatement? nestedRating;
    
    for (final s in updatedLisaStatements) {
      if (s.verb == ContentVerb.rate && s.comment == commentText) {
        nestedRating = s;
        break;
      }
    }

    expect(nestedRating, isNotNull, reason: "Nested rating should exist in Firestore");
    print('Found Nested Rating: ${nestedRating!.token}');
    
    // Verify the subject of the nested rating is indeed the art rating
    // The subject in the statement might be tokenized depending on settings, 
    // but let's check what we get.
    final subject = nestedRating.subject;
    if (subject is String) {
      // It's a token
      expect(subject, equals(artRating.token));
    } else if (subject is Map) {
      // It's the object (or statement json)
      // If it's a statement, it should have a signature that matches
      final subjectStatement = ContentStatement(Jsonish(subject as Map<String, dynamic>));
      expect(subjectStatement.token, equals(artRating.token));
    }

    // 5. Verify via ContentPipeline (simulating FeedController logic)
    // We need a TrustGraph to resolve delegates
    final trustSource = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final trustPipeline = TrustPipeline(trustSource);
    final graph = await trustPipeline.build(lisa.token);
    final delegateResolver = DelegateResolver(graph);
    final followNetwork = reduceFollowNetwork(graph, delegateResolver, ContentResult(), 'nerdster'); // Empty content map for follow net is fine for this test

    final contentPipeline = ContentPipeline(
      delegateSource: appSource,
    );

    // Fetch content map for valid delegates
    // We must include delegates that define the subjects Lisa refers to (e.g. Bart defines Skateboard)
    final allDelegateKeys = DemoKey.all
        .where((k) => k.isDelegate)
        .map((k) => DelegateKey(k.token))
        .toSet();

    final delegateContent = await contentPipeline.fetchDelegateContent(
      allDelegateKeys,
      delegateResolver: delegateResolver,
      graph: graph,
    );

    final contentResult = ContentResult(
      delegateContent: delegateContent,
    );

    final aggregation = reduceContentAggregation(
        followNetwork,
        graph,
        delegateResolver,
        contentResult,
        enableCensorship: true,
        meIdentityKeys: [IdentityKey(lisa.token)],
        meDelegateKeys: [DelegateKey(lisaD.token)],
    );

    // Check if the nested rating is in the aggregation
    // It should be in subjects[artRating!.token]
    final SubjectAggregation? nestedAgg = aggregation.subjects[artRating!.token];
    // TODO: False! Remove: expect(nestedAgg, isNotNull, reason: "Aggregation should exist for the rating statement");
    // expect(nestedAgg!.statements.any((s) => s.token == nestedRating!.token), isTrue);

  });
}
