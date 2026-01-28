import 'package:flutter_test/flutter_test.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:nerdster/logic/trust_pipeline.dart';
import 'package:nerdster/logic/content_pipeline.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/demotest/cases/simpsons_relate_demo.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/demotest/test_util.dart';

void main() {
  setUp(() async {
    setUpTestRegistry();
    // Enable storing full subjects in statements for inspection
    Setting.get(SettingType.debugUseSubjectNotToken).value = true;
  });

  test('Equivalence Inspection: Can inspect merged subject', () async {
    // 1. Run the demo setup (Lisa equates Skateboard to Toy)
    final (DemoIdentityKey lisa, DemoDelegateKey? lisaD) = await simpsonsRelateDemo();

    // 2. Build the model
    final DirectFirestoreSource<TrustStatement> trustSource =
        DirectFirestoreSource<TrustStatement>(FireFactory.find(kOneofusDomain));
    final TrustPipeline trustPipeline = TrustPipeline(trustSource);
    final TrustGraph graph = await trustPipeline.build(lisa.id);
    final DelegateResolver delegateResolver = DelegateResolver(graph);
    final FollowNetwork followNetwork =
        reduceFollowNetwork(graph, delegateResolver, ContentResult(), kFollowContextNerdster);

    final DirectFirestoreSource<ContentStatement> appSource =
        DirectFirestoreSource<ContentStatement>(FireFactory.find(kNerdsterDomain));
    final ContentPipeline contentPipeline = ContentPipeline(
      delegateSource: appSource,
    );

    final Map<DelegateKey, List<ContentStatement>> delegateContent =
        await contentPipeline.fetchDelegateContent(
      <DelegateKey>{lisaD!.id},
      delegateResolver: delegateResolver,
      graph: graph,
    );

    final ContentResult contentResult = ContentResult(
      delegateContent: delegateContent,
    );

    final Labeler labeler =
        Labeler(graph, delegateResolver: delegateResolver, meIdentity: lisa.id);

    final ContentAggregation aggregation = reduceContentAggregation(
      followNetwork,
      graph,
      delegateResolver,
      contentResult,
      enableCensorship: true,
      meDelegateKeys: <DelegateKey>[lisaD.id],
      labeler: labeler,
    );

    // 3. Verify Equivalence
    // Toy should be equivalent to Skateboard (or vice versa)
    // Toy token:
    final Map<String, dynamic> toy = createTestSubject(
        type: ContentType.resource, title: 'Toy', url: 'https://en.wikipedia.org/wiki/Toy');
    final String toyToken = getToken(toy);

    // Skateboard token:
    final Map<String, dynamic> skateboard = createTestSubject(
        type: ContentType.resource,
        title: 'Skateboard',
        url: 'https://en.wikipedia.org/wiki/Skateboard');
    final String skateboardToken = getToken(skateboard);

    final toyKey = ContentKey(toyToken);
    final skateboardKey = ContentKey(skateboardToken);

    final canonicalToy = aggregation.equivalence[toyKey];
    final canonicalSkateboard = aggregation.equivalence[skateboardKey];

    // One should point to the other, or both to the same one.
    // In the demo, Lisa equates Skateboard (subject) to Toy (other).
    // Usually the subject becomes canonical if it's older or has more weight?
    // Or maybe just arbitrary.

    // Ensure they are equivalent
    expect(
        canonicalToy == canonicalSkateboard ||
            canonicalToy == skateboardKey ||
            canonicalSkateboard == toyKey,
        isTrue);

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
    expect(nonCanonicalAgg.subject['title'],
        equals(nonCanonical == skateboardKey ? 'Skateboard' : 'Toy'));

    // Both should share the same group data
    expect(nonCanonicalAgg.group.canonical, equals(canonicalAgg.group.canonical));
    expect(nonCanonicalAgg.likes, equals(canonicalAgg.likes));
  });
}
