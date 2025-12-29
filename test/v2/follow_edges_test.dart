import 'package:test/test.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/oneofus/jsonish.dart';

void main() {
  setUpAll(() {
    TrustStatement.init();
    ContentStatement.init();
  });

  group('FollowNetwork Edges', () {
    test('populates edges for follow statements', () {
      final root = 'root';
      final alice = 'alice';
      final bob = 'bob';

      final t1 = TrustStatement(Jsonish({
        'token': 't1',
        'issuer': root,
        'trust': alice,
        'time': DateTime.now().toIso8601String(),
        'I': {'key': root},
      }));

      final t2 = TrustStatement(Jsonish({
        'token': 't2',
        'issuer': alice,
        'trust': bob,
        'time': DateTime.now().toIso8601String(),
        'I': {'key': alice},
      }));

      final trustGraph = TrustGraph(
        root: root,
        distances: {root: 0, alice: 1, bob: 2},
        orderedKeys: [root, alice, bob],
        edges: {
          root: [t1],
          alice: [t2],
        },
      );

      final f1 = ContentStatement(Jsonish({
        'token': 'f1',
        'issuer': root,
        'follow': alice,
        'with': {
          'contexts': {'news': 1},
        },
        'time': DateTime.now().toIso8601String(),
        'I': {'key': root},
      }));

      final f2 = ContentStatement(Jsonish({
        'token': 'f2',
        'issuer': alice,
        'follow': bob,
        'with': {
          'contexts': {'news': 1},
        },
        'time': DateTime.now().toIso8601String(),
        'I': {'key': alice},
      }));

      final Map<String, List<ContentStatement>> byToken = {
        root: [f1],
        alice: [f2],
      };

      final network = reduceFollowNetwork(
        trustGraph,
        DelegateResolver(trustGraph),
        byToken,
        'news',
      );

      expect(network.identities, containsAll([root, alice, bob]));
      expect(network.edges[root], contains(f1));
      expect(network.edges[alice], contains(f2));
    });

    test('detects conflicts in follow network', () {
      final root = 'root';
      final alice = 'alice';

      final t1 = TrustStatement(Jsonish({
        'token': 't1',
        'issuer': root,
        'trust': alice,
        'time': DateTime.now().toIso8601String(),
        'I': {'key': root},
      }));

      final trustGraph = TrustGraph(
        root: root,
        distances: {root: 0, alice: 1},
        orderedKeys: [root, alice],
        edges: {
          root: [t1],
        },
      );

      final blockSelf = ContentStatement(Jsonish({
        'token': 'f1_block',
        'issuer': root,
        'follow': root,
        'with': {
          'contexts': {'news': -1},
        },
        'time': DateTime.now().toIso8601String(),
        'I': {'key': root},
      }));

      final Map<String, List<ContentStatement>> byToken = {
        root: [blockSelf],
      };

      final network = reduceFollowNetwork(
        trustGraph,
        DelegateResolver(trustGraph),
        byToken,
        'news',
      );

      expect(network.notifications.any((n) => n.isConflict && n.reason.contains('block yourself')), isTrue);
    });
  });
}
