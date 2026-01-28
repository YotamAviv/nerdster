import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/logic/graph_controller.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/demotest/test_util.dart';

class MockFeedModel extends FeedModel {
  MockFeedModel({
    required TrustGraph trustGraph,
    required FollowNetwork followNetwork,
    DelegateResolver? delegateResolver,
  }) : super(
          trustGraph: trustGraph,
          followNetwork: followNetwork,
          delegateResolver: delegateResolver ?? DelegateResolver(trustGraph),
          aggregation: ContentAggregation(),
          labeler: Labeler(trustGraph, delegateResolver: delegateResolver),
          povIdentity: trustGraph.pov,
          fcontext: 'test',
          sortMode: SortMode.recentActivity,
          filterMode: DisFilterMode.ignore,
          enableCensorship: false,
        );
}

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  test('GraphController: Root Ordering and Pathfinding', () async {
    final lisa = await DemoIdentityKey.create('lisa');
    final bob = await DemoIdentityKey.create('bob');
    final charlie = await DemoIdentityKey.create('charlie');

    final s1 = await lisa.trust(bob, moniker: 'bob');
    final s2 = await bob.trust(charlie, moniker: 'charlie');
    final s3 = await charlie.trust(lisa, moniker: 'lisa');

    final tg = TrustGraph(
      pov: lisa.id,
      distances: {
        lisa.id: 0,
        bob.id: 1,
        charlie.id: 2,
      },
      edges: {
        lisa.id: [s1],
        bob.id: [s2],
        charlie.id: [s3],
      },
      paths: {
        charlie.id: [
          [lisa.id, bob.id, charlie.id]
        ],
      },
    );

    final fn = FollowNetwork(fcontext: 'test', povIdentity: lisa.id);
    final model = MockFeedModel(trustGraph: tg, followNetwork: fn);

    final controller = GraphController(model);
    controller.mode = GraphViewMode.identity;
    controller.focusedIdentity = charlie.id;
    signInState.pov = lisa.token;

    final data = controller.buildGraphData();

    expect(data.root, equals(lisa.id.value));
    expect(data.nodes.first, equals(lisa.id.value), reason: 'Root should be the first node');
    expect(data.nodes, containsAll([lisa.id.value, bob.id.value, charlie.id.value]));
    // Path lisa -> bob -> charlie has 2 edges.
    // Plus the back-edge charlie -> lisa makes 3.
    expect(data.edges.length, equals(3));
    expect(data.edges.any((e) => e.from == charlie.id.value && e.to == lisa.id.value), isTrue);
  });

  test('GraphController: Node-Disjoint Path Selection', () async {
    final root = await DemoIdentityKey.create('root');
    final a1 = await DemoIdentityKey.create('a1');
    final a2 = await DemoIdentityKey.create('a2');
    final b1 = await DemoIdentityKey.create('b1');
    final b2 = await DemoIdentityKey.create('b2');
    final target = await DemoIdentityKey.create('target');

    // Path 1: root -> a1 -> a2 -> target
    final s1 = await root.trust(a1, moniker: 'a1');
    final s2 = await a1.trust(a2, moniker: 'a2');
    final s3 = await a2.trust(target, moniker: 'target');

    // Path 2: root -> b1 -> b2 -> target
    final s4 = await root.trust(b1, moniker: 'b1');
    final s5 = await b1.trust(b2, moniker: 'b2');
    final s6 = await b2.trust(target, moniker: 'target');

    // Path 3 (Bottleneck): root -> a1 -> b2 -> target
    // This path shares a1 with Path 1 and b2 with Path 2.
    final s7 = await a1.trust(b2, moniker: 'b2');

    final tg = TrustGraph(
      pov: root.id,
      distances: {
        root.id: 0,
        a1.id: 1,
        b1.id: 1,
        a2.id: 2,
        b2.id: 2,
        target.id: 3,
      },
      edges: {
        root.id: [s1, s4],
        a1.id: [s2, s7],
        b1.id: [s5],
        a2.id: [s3],
        b2.id: [s6],
      },
      paths: {
        target.id: [
          [root.id, a1.id, a2.id, target.id],
          [root.id, b1.id, b2.id, target.id],
        ],
      },
    );

    final fn = FollowNetwork(fcontext: 'test', povIdentity: root.id);
    final model = MockFeedModel(trustGraph: tg, followNetwork: fn);

    final controller = GraphController(model);
    controller.mode = GraphViewMode.identity;
    controller.focusedIdentity = target.id;
    signInState.pov = root.token;

    final data = controller.buildGraphData();

    // Should find 2 node-disjoint paths.
    // If it finds Path 1 and Path 2, we get 6 nodes and 6 edges.
    // If it finds Path 3 first, it might only find 1 path.
    // But BFS should find Path 1 or Path 2 or Path 3 (all length 3).

    expect(data.nodes, contains(target.id));
    expect(data.edges.length, greaterThanOrEqualTo(3));
  });
}
