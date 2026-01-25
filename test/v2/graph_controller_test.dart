import 'package:nerdster/v2/delegates.dart';
import 'package:test/test.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() {
    setUpTestRegistry();
  });

  group('GraphController', () {
    test('builds identity graph data', () {
      final Map<String, dynamic> povKey = mockKey('pov');
      final IdentityKey pov = IdentityKey(getToken(povKey));
      final Map<String, dynamic> aliceKey = mockKey('alice');
      final IdentityKey alice = IdentityKey(getToken(aliceKey));

      final TrustStatement t1 = makeTrustStatement(
        verb: TrustVerb.trust,
        iJson: povKey,
        subject: aliceKey,
      );

      final TrustGraph trustGraph = TrustGraph(
        pov: pov,
        distances: <IdentityKey, int>{pov: 0, alice: 1},
        orderedKeys: <IdentityKey>[pov, alice],
        edges: <IdentityKey, List<TrustStatement>>{
          pov: <TrustStatement>[t1],
        },
        paths: <IdentityKey, List<List<IdentityKey>>>{
          alice: <List<IdentityKey>>[
            <IdentityKey>[pov, alice]
          ],
        },
      );

      final V2FeedModel feedModel = V2FeedModel(
        trustGraph: trustGraph,
        followNetwork: FollowNetwork(povIdentity: pov, fcontext: '<identity>'),
        delegateResolver: DelegateResolver(trustGraph),
        labeler: V2Labeler(trustGraph),
        aggregation: ContentAggregation(),
        povIdentity: pov,
        fcontext: '<identity>',
        sortMode: V2SortMode.recentActivity,
        filterMode: DisFilterMode.ignore,
        enableCensorship: false,
      );

      final GraphController controller = GraphController(feedModel);
      controller.focusedIdentity = alice;
      controller.mode = GraphViewMode.identity;
      final GraphData data = controller.buildGraphData();

      expect(data.nodes, containsAll([pov.value, alice.value]));
      expect(data.edges.length, 1);
      expect(data.edges.first.from, pov.value);
      expect(data.edges.first.to, alice.value);
      expect(data.edges.first.isIdentity, isTrue);
    });

    test('builds follow graph data', () {
      final Map<String, dynamic> povKey = mockKey('pov');
      final IdentityKey pov = IdentityKey(getToken(povKey));
      final Map<String, dynamic> aliceKey = mockKey('alice');
      final IdentityKey alice = IdentityKey(getToken(aliceKey));

      final ContentStatement f1 = makeContentStatement(
        verb: ContentVerb.follow,
        subject: alice.value,
        contexts: <String, dynamic>{'news': 1},
        iJson: povKey,
      );

      final TrustGraph trustGraph =
          TrustGraph(pov: pov, distances: <IdentityKey, int>{pov: 0, alice: 1});
      final FollowNetwork followNetwork = FollowNetwork(
        fcontext: 'news',
        identities: <IdentityKey>[pov, alice],
        povIdentity: pov,
        edges: <IdentityKey, List<ContentStatement>>{
          pov: <ContentStatement>[f1],
        },
        paths: <IdentityKey, List<IdentityKey>>{
          alice: <IdentityKey>[pov, alice],
        },
      );

      final V2FeedModel feedModel = V2FeedModel(
        trustGraph: trustGraph,
        followNetwork: followNetwork,
        delegateResolver: DelegateResolver(trustGraph),
        labeler: V2Labeler(trustGraph),
        aggregation: ContentAggregation(),
        povIdentity: pov,
        fcontext: 'news',
        sortMode: V2SortMode.recentActivity,
        filterMode: DisFilterMode.ignore,
        enableCensorship: false,
      );

      final GraphController controller = GraphController(feedModel);
      controller.focusedIdentity = alice;
      controller.mode = GraphViewMode.follow;
      final GraphData data = controller.buildGraphData();

      expect(data.nodes, containsAll([pov.value, alice.value]));
      expect(data.edges.length, 1);
      expect(data.edges.first.from, pov.value);
      expect(data.edges.first.to, alice.value);
      expect(data.edges.first.isFollow, isTrue);
    });

    test('builds identity graph data with delegation', () {
      final Map<String, dynamic> povKey = mockKey('pov');
      final IdentityKey pov = IdentityKey(getToken(povKey));
      final Map<String, dynamic> delegateKey = mockKey('delegate');
      final IdentityKey delegate = IdentityKey(getToken(delegateKey));

      final TrustStatement d1 = makeTrustStatement(
        verb: TrustVerb.delegate,
        iJson: povKey,
        subject: delegateKey,
        domain: 'nerdster.org',
      );

      final TrustGraph trustGraph = TrustGraph(
        pov: pov,
        distances: <IdentityKey, int>{pov: 0, delegate: 1},
        edges: <IdentityKey, List<TrustStatement>>{
          pov: <TrustStatement>[d1]
        },
        paths: <IdentityKey, List<List<IdentityKey>>>{
          delegate: <List<IdentityKey>>[
            <IdentityKey>[pov, delegate]
          ],
        },
      );

      final V2FeedModel feedModel = V2FeedModel(
        trustGraph: trustGraph,
        followNetwork: FollowNetwork(fcontext: '<identity>', povIdentity: pov),
        delegateResolver: DelegateResolver(trustGraph),
        labeler: V2Labeler(trustGraph),
        aggregation: ContentAggregation(),
        povIdentity: pov,
        fcontext: '<identity>',
        sortMode: V2SortMode.recentActivity,
        filterMode: DisFilterMode.ignore,
        enableCensorship: false,
      );

      final GraphController controller = GraphController(feedModel);
      controller.focusedIdentity = delegate;
      controller.mode = GraphViewMode.identity;
      final GraphData data = controller.buildGraphData();

      expect(data.nodes, containsAll([pov.value, delegate.value]));
      expect(data.edges.length, 1);
      expect(data.edges.first.from, pov.value);
      expect(data.edges.first.to, delegate.value);
      expect(data.edges.first.isIdentity, isTrue);
    });
  });
}
