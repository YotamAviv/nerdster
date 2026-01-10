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
import 'package:nerdster/v2/labeler.dart';
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

    final labeler = V2Labeler(graph, delegateResolver: delegateResolver, meIdentity: lisa.id);

    final aggregation = reduceContentAggregation(
        followNetwork,
        graph,
        delegateResolver,
        contentResult,
        enableCensorship: true,
        meDelegateKeys: [lisaD.id],
        labeler: labeler,
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

    // The non-canonical one SHOULD be in subjects map now (dense map)
    expect(aggregation.subjects.containsKey(nonCanonical), isTrue);
    expect(aggregation.subjects.containsKey(canonical), isTrue);

    // 4. Verify that the subjects map is dense and contains both tokens.
    final canonicalAgg = aggregation.subjects[canonical]!;
    final nonCanonicalAgg = aggregation.subjects[nonCanonical]!;

    expect(canonicalAgg.token, equals(canonical));
    expect(canonicalAgg.canonical, equals(canonical));

    expect(nonCanonicalAgg.token, equals(nonCanonical));
    expect(nonCanonicalAgg.canonical, equals(canonical));
    expect(nonCanonicalAgg.subject['title'], equals(nonCanonical == skateboardKey ? 'Skateboard' : 'Toy'));

    // Both should share the same group data
    expect(nonCanonicalAgg.group.canonical, equals(canonicalAgg.group.canonical));
    expect(nonCanonicalAgg.likes, equals(canonicalAgg.likes));
  });
}
