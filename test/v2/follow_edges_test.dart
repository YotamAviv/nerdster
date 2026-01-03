import 'package:test/test.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/keys.dart';

void main() {
  setUpAll(() {
    TrustStatement.init();
    ContentStatement.init();
  });

  group('FollowNetwork Edges', () {
    test('populates edges for follow statements', () {
      final pov = 'pov';
      final alice = 'alice';
      final bob = 'bob';

      final t1 = TrustStatement(Jsonish({
        'token': 't1',
        'issuer': pov,
        'trust': alice,
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

      final t2 = TrustStatement(Jsonish({
        'token': 't2',
        'issuer': alice,
        'trust': bob,
        'time': DateTime.now().toIso8601String(),
        'I': {'key': alice},
      }));

      final povD = 'povD';
      final aliceD = 'aliceD';

      final d1 = TrustStatement(Jsonish({
        'token': 'd1',
        'issuer': pov,
        'delegate': povD,
        'with': {'domain': 'nerdster.org'},
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

      final d2 = TrustStatement(Jsonish({
        'token': 'd2',
        'issuer': alice,
        'delegate': aliceD,
        'with': {'domain': 'nerdster.org'},
        'time': DateTime.now().toIso8601String(),
        'I': {'key': alice},
      }));

      final trustGraph = TrustGraph(
        pov: pov,
        distances: {pov: 0, alice: 1, bob: 2},
        orderedKeys: [pov, alice, bob],
        edges: {
          pov: [t1, d1],
          alice: [t2, d2],
        },
      );

      final f1 = ContentStatement(Jsonish({
        'token': 'f1',
        'issuer': pov,
        'follow': alice,
        'with': {
          'contexts': {'news': 1},
        },
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
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

      final Map<DelegateKey, List<ContentStatement>> delegateContent = {
        DelegateKey(povD): [f1],
        DelegateKey(aliceD): [f2],
      };

      final network = reduceFollowNetwork(
        trustGraph,
        DelegateResolver(trustGraph),
        ContentResult(delegateContent: delegateContent),
        'news',
      );

      expect(network.identities, containsAll([pov, alice, bob]));
      expect(network.edges[pov], contains(f1));
      expect(network.edges[alice], contains(f2));
    });

    test('detects conflicts in follow network', () {
      final pov = 'pov';
      final alice = 'alice';

      final t1 = TrustStatement(Jsonish({
        'token': 't1',
        'issuer': pov,
        'trust': alice,
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

      final povD = 'povD';

      final d1 = TrustStatement(Jsonish({
        'token': 'd1',
        'issuer': pov,
        'delegate': povD,
        'with': {'domain': 'nerdster.org'},
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

      final trustGraph = TrustGraph(
        pov: pov,
        distances: {pov: 0, alice: 1},
        orderedKeys: [pov, alice],
        edges: {
          pov: [t1, d1],
        },
      );

      final blockSelf = ContentStatement(Jsonish({
        'token': 'f1_block',
        'issuer': pov,
        'follow': pov,
        'with': {
          'contexts': {'news': -1},
        },
        'time': DateTime.now().toIso8601String(),
        'I': {'key': pov},
      }));

      final Map<DelegateKey, List<ContentStatement>> delegateContent = {
        DelegateKey(povD): [blockSelf],
      };

      final network = reduceFollowNetwork(
        trustGraph,
        DelegateResolver(trustGraph),
        ContentResult(delegateContent: delegateContent),
        'news',
      );

      expect(network.notifications.any((n) => n.isConflict && n.reason.contains('block yourself')), isTrue);
    });
  });
}
