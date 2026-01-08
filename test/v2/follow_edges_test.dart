import 'package:test/test.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';

void main() {
  setUpAll(() {
    TrustStatement.init();
    ContentStatement.init();
  });

  group('FollowNetwork Edges', () {
    test('populates edges for follow statements', () {
      final povKey = {'kty': 'mock', 'val': 'pov'};
      final pov = Jsonish(povKey).token;
      final aliceKey = {'kty': 'mock', 'val': 'alice'};
      final alice = Jsonish(aliceKey).token;
      final bobKey = {'kty': 'mock', 'val': 'bob'};
      final bob = Jsonish(bobKey).token;

      final t1 = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'trust': alice,
        'time': DateTime.now().toIso8601String(),
        'I': povKey,
      }, 't1'));

      final t2 = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'trust': bob,
        'time': DateTime.now().toIso8601String(),
        'I': aliceKey,
      }, 't2'));

      final povD = 'povD';
      final aliceD = 'aliceD';

      final d1 = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'delegate': povD,
        'with': {'domain': 'nerdster.org'},
        'time': DateTime.now().toIso8601String(),
        'I': povKey,
      }, 'd1'));

      final d2 = TrustStatement(Jsonish({
        'statement': 'net.one-of-us',
        'delegate': aliceD,
        'with': {'domain': 'nerdster.org'},
        'time': DateTime.now().toIso8601String(),
        'I': aliceKey,
      }, 'd2'));

      final trustGraph = TrustGraph(
        pov: IdentityKey(pov),
        distances: {
          IdentityKey(pov): 0,
          IdentityKey(alice): 1,
          IdentityKey(bob): 2
        },
        orderedKeys: [IdentityKey(pov), IdentityKey(alice), IdentityKey(bob)],
        edges: {
          IdentityKey(pov): [t1, d1],
          IdentityKey(alice): [t2, d2],
        },
      );

      final f1 = ContentStatement(Jsonish({
        'statement': 'org.nerdster',
        'follow': alice,
        'with': {
          'contexts': {'news': 1},
        },
        'time': DateTime.now().toIso8601String(),
        'I': povKey,
      }, 'f1'));

      final f2 = ContentStatement(Jsonish({
        'statement': 'org.nerdster',
        'follow': bob,
        'with': {
          'contexts': {'news': 1},
        },
        'time': DateTime.now().toIso8601String(),
        'I': aliceKey,
      }, 'f2'));

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
  });
}
