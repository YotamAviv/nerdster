import 'package:test/test.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';

void main() {
  setUpAll(() {
    TrustStatement.init();
    ContentStatement.init();
  });

  group('GraphController', () {
    test('builds identity graph data', () {
      final pov = 'pov';
      final alice = 'alice';

      final t1 = TrustStatement(Jsonish({
        'token': 't1',
        'issuer': pov,
        'trust': alice,
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

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

      expect(data.nodes, containsAll([pov, alice]));
      expect(data.edges.length, 1);
      expect(data.edges.first.fromIdentity, pov);
      expect(data.edges.first.toIdentity, alice);
      expect(data.edges.first.isIdentity, isTrue);
    });

    test('builds follow graph data', () {
      final pov = 'pov';
      final alice = 'alice';

      final f1 = ContentStatement(Jsonish({
        'token': 'f1',
        'issuer': pov,
        'follow': alice,
        'with': {'contexts': {'news': 1}},
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

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

      expect(data.nodes, containsAll([pov, alice]));
      expect(data.edges.length, 1);
      expect(data.edges.first.fromIdentity, pov);
      expect(data.edges.first.toIdentity, alice);
      expect(data.edges.first.isFollow, isTrue);
    });

    test('identifies conflicts in graph data', () {
      final pov = 'pov';
      final alice = 'alice';

      final f1 = ContentStatement(Jsonish({
        'token': 'f1',
        'issuer': pov,
        'follow': alice,
        'with': {'contexts': {'news': 1}},
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

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
        notifications: [
          TrustNotification(subject: alice, reason: 'conflict', relatedStatement: f1.token, isConflict: true),
        ],
      );

      final feedModel = V2FeedModel(
        trustGraph: trustGraph,
        followNetwork: followNetwork,
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

      expect(data.edges.any((e) => e.isConflict), isTrue);
    });
  });
}
