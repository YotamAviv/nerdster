import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/v2/graph_controller.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/trust_statement.dart';



import 'package:nerdster/singletons.dart';

import 'package:nerdster/demotest/demo_key.dart';

class MockV2FeedModel extends V2FeedModel {
  MockV2FeedModel({
    required TrustGraph trustGraph,
    required FollowNetwork followNetwork,
    DelegateResolver? delegateResolver,
  }) : super(
    trustGraph: trustGraph,
    followNetwork: followNetwork,
    aggregation: ContentAggregation(),
    labeler: V2Labeler(trustGraph, delegateResolver: delegateResolver),
    rootToken: trustGraph.root,
    fcontext: 'test',
    sortMode: V2SortMode.recentActivity,
    filterMode: V2FilterMode.ignoreDisses,
    enableCensorship: false,
  );
}

void main() {
  setUpAll(() {
    fireChoice = FireChoice.fake;
    FireFactory.register(kOneofusDomain, FakeFirebaseFirestore(), null);
    TrustStatement.init();
  });

  test('GraphController: Root Ordering and Pathfinding', () async {
    final lisa = await DemoKey.create('lisa');
    final bob = await DemoKey.create('bob');
    final charlie = await DemoKey.create('charlie');

    final s1 = await lisa.trust(bob, moniker: 'bob');
    final s2 = await bob.trust(charlie, moniker: 'charlie');
    final s3 = await charlie.trust(lisa, moniker: 'lisa');

    final tg = TrustGraph(
      root: lisa.token,
      distances: {lisa.token: 0, bob.token: 1, charlie.token: 2},
      edges: {
        lisa.token: [s1],
        bob.token: [s2],
        charlie.token: [s3],
      },
      paths: {
        charlie.token: [
          [lisa.token, bob.token, charlie.token]
        ],
      },
    );

    final fn = FollowNetwork(fcontext: 'test', rootIdentity: lisa.token);
    final model = MockV2FeedModel(trustGraph: tg, followNetwork: fn);

    final controller = GraphController(model);
    controller.mode = GraphViewMode.identity;
    controller.focusedIdentity = charlie.token;
    signInState.pov = lisa.token;
    
    final data = controller.buildGraphData();
    
    expect(data.root, equals(lisa.token));
    expect(data.nodes.first, equals(lisa.token), reason: 'Root should be the first node');
    expect(data.nodes, containsAll([lisa.token, bob.token, charlie.token]));
    // Path lisa -> bob -> charlie has 2 edges
    expect(data.edges.length, equals(2));
  });

  test('GraphController: Node-Disjoint Path Selection', () async {
    final root = await DemoKey.create('root');
    final a1 = await DemoKey.create('a1');
    final a2 = await DemoKey.create('a2');
    final b1 = await DemoKey.create('b1');
    final b2 = await DemoKey.create('b2');
    final target = await DemoKey.create('target');

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
      root: root.token,
      distances: {
        root.token: 0,
        a1.token: 1,
        b1.token: 1,
        a2.token: 2,
        b2.token: 2,
        target.token: 3,
      },
      edges: {
        root.token: [s1, s4],
        a1.token: [s2, s7],
        b1.token: [s5],
        a2.token: [s3],
        b2.token: [s6],
      },
      paths: {
        target.token: [
          [root.token, a1.token, a2.token, target.token],
          [root.token, b1.token, b2.token, target.token],
        ],
      },
    );

    final fn = FollowNetwork(fcontext: 'test', rootIdentity: root.token);
    final model = MockV2FeedModel(trustGraph: tg, followNetwork: fn);

    final controller = GraphController(model);
    controller.mode = GraphViewMode.identity;
    controller.focusedIdentity = target.token;
    signInState.pov = root.token;
    
    final data = controller.buildGraphData();
    
    // Should find 2 node-disjoint paths.
    // If it finds Path 1 and Path 2, we get 6 nodes and 6 edges.
    // If it finds Path 3 first, it might only find 1 path.
    // But BFS should find Path 1 or Path 2 or Path 3 (all length 3).
    
    expect(data.nodes, contains(target.token));
    expect(data.edges.length, greaterThanOrEqualTo(3));
  });

  test('GraphController: Delegate Identity Resolution', () async {
    final lisa = await DemoKey.create('lisa');
    final homer = await DemoKey.create('homer');
    final bart = await DemoKey.create('bart');
    final bartDelegate = await DemoKey.create('bart_delegate');

    // Lisa trusts Homer
    final s1 = await lisa.trust(homer, moniker: 'homer');
    // Homer trusts Bart
    final s2 = await homer.trust(bart, moniker: 'bart');
    // Bart delegates to bartDelegate
    final s3 = await bart.delegate(bartDelegate, domain: 'nerdster.org');

    final tg = TrustGraph(
      root: lisa.token,
      distances: {lisa.token: 0, homer.token: 1, bart.token: 2},
      edges: {
        lisa.token: [s1],
        homer.token: [s2],
        bart.token: [s3],
      },
      paths: {
        bart.token: [
          [lisa.token, homer.token, bart.token]
        ],
      },
    );

    final dr = DelegateResolver(tg);
    dr.resolveForIdentity(bart.token);

    final fn = FollowNetwork(fcontext: 'test', rootIdentity: lisa.token);
    final model = MockV2FeedModel(
      trustGraph: tg, 
      followNetwork: fn,
      delegateResolver: dr,
    );

    final controller = GraphController(model);
    controller.mode = GraphViewMode.identity;
    
    // Focus on the DELEGATE key
    controller.focusedIdentity = bartDelegate.token;
    signInState.pov = lisa.token;
    
    final data = controller.buildGraphData();
    
    // The graph should resolve bartDelegate to Bart and find the path Lisa -> Homer -> Bart
    expect(data.nodes, containsAll([lisa.token, homer.token, bart.token]));
    expect(data.nodes, isNot(contains(bartDelegate.token)), reason: 'Delegate should be resolved to Identity');
    expect(data.edges.length, equals(2));
    expect(data.edges.any((e) => e.fromIdentity == lisa.token && e.toIdentity == homer.token), isTrue);
    expect(data.edges.any((e) => e.fromIdentity == homer.token && e.toIdentity == bart.token), isTrue);
  });
}
