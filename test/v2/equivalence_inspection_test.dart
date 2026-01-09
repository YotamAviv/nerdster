import 'package:nerdster/content/content_types.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_utils.dart';
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
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    fireChoice = FireChoice.fake;
    // Enable storing full subjects in statements for inspection
    Setting.get(SettingType.debugUseSubjectNotToken).value = true;
    
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
    final graph = await trustPipeline.build(lisa.id);
    final delegateResolver = DelegateResolver(graph);
    final followNetwork = reduceFollowNetwork(graph, delegateResolver, ContentResult(), kFollowContextNerdster);

    final appSource = DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final contentPipeline = ContentPipeline(
      delegateSource: appSource,
    );

    final delegateContent = await contentPipeline.fetchDelegateContent(
      {lisaD!.id},
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
        meDelegateKeys: [lisaD.id],
    );

    // 3. Verify Equivalence
    // Toy should be equivalent to Skateboard (or vice versa)
    // Toy token:
    final toy = createTestSubject(type: ContentType.resource, title: 'Toy', url: 'https://en.wikipedia.org/wiki/Toy');
    final toyToken = getToken(toy);
    
    // Skateboard token:
    final skateboard = createTestSubject(type: ContentType.resource, title: 'Skateboard', url: 'https://en.wikipedia.org/wiki/Skateboard');
    final skateboardToken = getToken(skateboard);

    final toyKey = ContentKey(toyToken);
    final skateboardKey = ContentKey(skateboardToken);

    final canonicalToy = aggregation.equivalence[toyKey];
    final canonicalSkateboard = aggregation.equivalence[skateboardKey];

    print('Toy Token: $toyToken');
    print('Skateboard Token: $skateboardToken');
    print('Canonical Toy: $canonicalToy');
    print('Canonical Skateboard: $canonicalSkateboard');

    // One should point to the other, or both to the same one.
    // In the demo, Lisa equates Skateboard (subject) to Toy (other).
    // Usually the subject becomes canonical if it's older or has more weight?
    // Or maybe just arbitrary.
    
    // Ensure they are equivalent
    expect(canonicalToy == canonicalSkateboard || canonicalToy == skateboardKey || canonicalSkateboard == toyKey, isTrue);
    
    final canonical = canonicalToy ?? toyKey;
    final nonCanonical = (canonical == toyKey) ? skateboardKey : toyKey;

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
             // print('Checking statement subject: ${s.subjectToken} vs $nonCanonical');
             if (s.subjectToken == nonCanonical.value) {
               subjectObj = s.subject;
               break;
             }
             if (s.other != null) {
                // print('Checking statement other: ${getToken(s.other)} vs $nonCanonical');
                if (getToken(s.other) == nonCanonical.value) {
                   subjectObj = s.other;
                   break;
                }
             }
           }
           
           if (subjectObj == null || subjectObj is! Map) {
             // Should not happen in strict mode if data is adequately supplied
             // Use a valid placeholder only if strictly necessary for the test to proceed
             subjectObj = createTestSubject(type: ContentType.article, url: nonCanonical.value, title: 'Unknown');
           }

           inspectAgg = SubjectAggregation(
             canonicalTokenIn: nonCanonical,
             subject: Map<String, dynamic>.from(subjectObj as Map),
             statements: canonicalAgg.statements,
             likes: canonicalAgg.likes,
             dislikes: canonicalAgg.dislikes,
             related: canonicalAgg.related,
             tags: canonicalAgg.tags,
             lastActivity: canonicalAgg.lastActivity,
             isCensored: canonicalAgg.isCensored,
             myDelegateStatements: canonicalAgg.myDelegateStatements,
             povStatements: canonicalAgg.povStatements,
           );
        }
      }
    }

    expect(inspectAgg, isNotNull, reason: "Should be able to inspect non-canonical subject");
    expect(inspectAgg!.canonical, equals(nonCanonical));
    
    // Verify we found the actual object, not just the token (if possible)
    expect(inspectAgg.subject['title'], equals(nonCanonical.value == toyToken ? 'Toy' : 'Skateboard'));
  });
}
