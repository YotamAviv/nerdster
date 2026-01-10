import 'package:nerdster/v2/delegates.dart';
import 'package:test/test.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';

void main() {
  setUpAll(() {
    TrustStatement.init();
    ContentStatement.init();
  });

  group('GraphController', () {
    test('builds identity graph data', () {
      final povKey = {'kty': 'mock', 'val': 'pov'};
      final pov = IdentityKey(Jsonish(povKey).token);
      final aliceKey = {'kty': 'mock', 'val': 'alice'};
      final alice = IdentityKey(Jsonish(aliceKey).token);

      final t1 = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'trust': alice.value,
        'time': DateTime.now().toIso8601String(),
        'I': povKey,
      }, 't1'));

      final trustGraph = TrustGraph(
        pov: pov,
        distances: {pov: 0, alice: 1},
        orderedKeys: [pov, alice],
        edges: {
          pov: [t1],
        },
        paths: {
          alice: [[pov, alice]],
        },
      );

      final feedModel = V2FeedModel(
        trustGraph: trustGraph,
        followNetwork: FollowNetwork(povIdentity: pov, fcontext: '<identity>'),
        delegateResolver: DelegateResolver(trustGraph),
        labeler: V2Labeler(trustGraph),
        aggregation: ContentAggregation(),
        povToken: pov,
        fcontext: '<identity>',
        sortMode: V2SortMode.recentActivity,
        filterMode: V2FilterMode.ignoreDisses,
        enableCensorship: false,
      );

      final controller = GraphController(feedModel);
      controller.focusedIdentity = alice;
      controller.mode = GraphViewMode.identity;
      final data = controller.buildGraphData();

      expect(data.nodes, containsAll([pov.value, alice.value]));
      expect(data.edges.length, 1);
      expect(data.edges.first.from, pov.value);
      expect(data.edges.first.to, alice.value);
      expect(data.edges.first.isIdentity, isTrue);
    });

    test('builds follow graph data', () {
      final povKey = {'kty': 'mock', 'val': 'pov'};
      final pov = IdentityKey(Jsonish(povKey).token);
      final aliceKey = {'kty': 'mock', 'val': 'alice'};
      final alice = IdentityKey(Jsonish(aliceKey).token);

      final f1 = ContentStatement(Jsonish({
        'statement': 'org.nerdster',
        'follow': alice.value,
        'with': {'contexts': {'news': 1}},
        'time': DateTime.now().toIso8601String(),
        'I': povKey,
      }, 'f1'));

      final trustGraph = TrustGraph(pov: pov, distances: {pov: 0, alice: 1});
      final followNetwork = FollowNetwork(
        fcontext: 'news',
        identities: [pov, alice],
        povIdentity: pov,
        edges: {
          pov: [f1],
        },
        paths: {
          alice: [pov, alice],
        },
      );

      final feedModel = V2FeedModel(
        trustGraph: trustGraph,
        followNetwork: followNetwork,
        delegateResolver: DelegateResolver(trustGraph),
        labeler: V2Labeler(trustGraph),
        aggregation: ContentAggregation(),
        povToken: pov,
        fcontext: 'news',
        sortMode: V2SortMode.recentActivity,
        filterMode: V2FilterMode.ignoreDisses,
        enableCensorship: false,
      );

      final controller = GraphController(feedModel);
      controller.focusedIdentity = alice;
      controller.mode = GraphViewMode.follow;
      final data = controller.buildGraphData();

      expect(data.nodes, containsAll([pov.value, alice.value]));
      expect(data.edges.length, 1);
      expect(data.edges.first.from, pov.value);
      expect(data.edges.first.to, alice.value);
      expect(data.edges.first.isFollow, isTrue);
    });

    test('builds identity graph data with delegation', () {
      final povKey = {'kty': 'mock', 'val': 'pov'};
      final pov = IdentityKey(Jsonish(povKey).token);
      final delegateKey = {'kty': 'mock', 'val': 'delegate'};
      final delegate = IdentityKey(Jsonish(delegateKey).token);

      final d1 = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'delegate': delegate.value,
        'with': {'domain': 'nerdster.org'},
        'time': DateTime.now().toIso8601String(),
        'I': povKey,
      }, 'd1'));

      final trustGraph = TrustGraph(
        pov: pov, 
        distances: {pov: 0, delegate: 1},
        edges: {pov: [d1]},
        paths: {
          delegate: [[pov, delegate]],
        }
      );
      
      final feedModel = V2FeedModel(
        trustGraph: trustGraph,
        followNetwork: FollowNetwork(fcontext: '<identity>', povIdentity: pov),
        delegateResolver: DelegateResolver(trustGraph),
        labeler: V2Labeler(trustGraph),
        aggregation: ContentAggregation(),
        povToken: pov,
        fcontext: '<identity>',
        sortMode: V2SortMode.recentActivity,
        filterMode: V2FilterMode.ignoreDisses,
        enableCensorship: false,
      );

      final controller = GraphController(feedModel);
      controller.focusedIdentity = delegate;
      controller.mode = GraphViewMode.identity;
      final data = controller.buildGraphData();

      expect(data.nodes, containsAll([pov.value, delegate.value]));
      expect(data.edges.length, 1);
      expect(data.edges.first.from, pov.value);
      expect(data.edges.first.to, delegate.value);
      expect(data.edges.first.isIdentity, isTrue);
    });
  });
}
