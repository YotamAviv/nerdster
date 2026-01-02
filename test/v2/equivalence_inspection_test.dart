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

  test('Equivalence Inspection: Can inspect merged subject', () async {
    // 1. Run the demo setup (Lisa equates Skateboard to Toy)
    final (lisa, lisaD) = await simpsonsRelateDemo();
    
    // 2. Build the model
    final trustSource = DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final trustPipeline = TrustPipeline(trustSource);
    final graph = await trustPipeline.build(lisa.token);
    final delegateResolver = DelegateResolver(graph);
    final followNetwork = reduceFollowNetwork(graph, delegateResolver, {}, 'nerdster');

    final appSource = DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final contentPipeline = ContentPipeline(
      contentSource: appSource,
    );

    final contentMap = await contentPipeline.fetchContentMap(
      graph, 
      delegateResolver,
      additionalIdentityKeys: [lisa.token, lisaD!.token],
    );

    final aggregation = reduceContentAggregation(
        followNetwork,
        graph,
        delegateResolver,
        contentMap,
        enableCensorship: true,
        meIdentityToken: lisa.token,
        meIdentityKeys: [lisa.token, lisaD.token],
    );

    // 3. Verify Equivalence
    // Toy should be equivalent to Skateboard (or vice versa)
    // Toy token:
    final toy = {'contentType': 'resource', 'title': 'Toy', 'url': 'https://en.wikipedia.org/wiki/Toy'};
    final toyToken = getToken(toy);
    
    // Skateboard token:
    final skateboard = {'contentType': 'resource', 'title': 'Skateboard', 'url': 'https://en.wikipedia.org/wiki/Skateboard'};
    final skateboardToken = getToken(skateboard);

    final canonicalToy = aggregation.equivalence[toyToken];
    final canonicalSkateboard = aggregation.equivalence[skateboardToken];

    print('Toy Token: $toyToken');
    print('Skateboard Token: $skateboardToken');
    print('Canonical Toy: $canonicalToy');
    print('Canonical Skateboard: $canonicalSkateboard');

    // One should point to the other, or both to the same one.
    // In the demo, Lisa equates Skateboard (subject) to Toy (other).
    // Usually the subject becomes canonical if it's older or has more weight?
    // Or maybe just arbitrary.
    
    // Ensure they are equivalent
    expect(canonicalToy == canonicalSkateboard || canonicalToy == skateboardToken || canonicalSkateboard == toyToken, isTrue);
    
    final canonical = canonicalToy ?? toyToken;
    final nonCanonical = (canonical == toyToken) ? skateboardToken : toyToken;

    // The non-canonical one should NOT be in subjects map
    expect(aggregation.subjects.containsKey(nonCanonical), isFalse);
    expect(aggregation.subjects.containsKey(canonical), isTrue);

    // 4. Simulate Inspection Logic (what we added to ContentCard)
    SubjectAggregation? inspectAgg = aggregation.subjects[nonCanonical];
    
    if (inspectAgg == null) {
      final canonicalToken = aggregation.equivalence[nonCanonical];
      if (canonicalToken != null) {
        final canonicalAgg = aggregation.subjects[canonicalToken];
        if (canonicalAgg != null) {
           dynamic subjectObj;
           for (final s in canonicalAgg.statements) {
             if (s.subjectToken == nonCanonical) {
               subjectObj = s.subject;
               break;
             }
             if (s.other != null && getToken(s.other) == nonCanonical) {
               subjectObj = s.other;
               break;
             }
           }
           
           if (subjectObj == null) subjectObj = nonCanonical;

           inspectAgg = SubjectAggregation(
             subject: subjectObj,
             statements: canonicalAgg.statements,
             likes: canonicalAgg.likes,
             dislikes: canonicalAgg.dislikes,
             related: canonicalAgg.related,
             tags: canonicalAgg.tags,
             lastActivity: canonicalAgg.lastActivity,
             isCensored: canonicalAgg.isCensored,
             userDismissalTimestamp: canonicalAgg.userDismissalTimestamp,
             povDismissalTimestamp: canonicalAgg.povDismissalTimestamp,
             isDismissed: canonicalAgg.isDismissed,
             isRated: canonicalAgg.isRated,
             myDelegateStatements: canonicalAgg.myDelegateStatements,
           );
        }
      }
    }

    expect(inspectAgg, isNotNull, reason: "Should be able to inspect non-canonical subject");
    expect(getToken(inspectAgg!.subject), equals(nonCanonical));
    
    // Verify we found the actual object, not just the token (if possible)
    if (inspectAgg.subject is Map) {
      expect(inspectAgg.subject['title'], equals(nonCanonical == toyToken ? 'Toy' : 'Skateboard'));
    }
  });
}
