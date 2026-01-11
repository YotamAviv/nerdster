import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/demotest/test_util.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  IdentityKey id(Map<String, dynamic> key) => IdentityKey(Jsonish(key).token);

  group('FollowNetwork Edges', () {
    test('populates edges for follow statements', () {
      final Map<String, dynamic> povKey = mockKey('pov');
      final IdentityKey pov = id(povKey);
      final Map<String, dynamic> aliceKey = mockKey('alice');
      final IdentityKey alice = id(aliceKey);
      final Map<String, dynamic> bobKey = mockKey('bob');
      final IdentityKey bob = id(bobKey);

      final TrustStatement t1 = makeTrustStatement(
        verb: TrustVerb.trust,
        subject: aliceKey,
        iJson: povKey,
      );

      final TrustStatement t2 = makeTrustStatement(
        verb: TrustVerb.trust,
        subject: bobKey,
        iJson: aliceKey,
      );

      const String povDName = 'povD';
      const String aliceDName = 'aliceD';

      final TrustStatement d1 = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: povDName,
        domain: 'nerdster.org',
        iJson: povKey,
      );

      final TrustStatement d2 = makeTrustStatement(
        verb: TrustVerb.delegate,
        subject: aliceDName,
        domain: 'nerdster.org',
        iJson: aliceKey,
      );

      final TrustGraph trustGraph = TrustGraph(
        pov: pov,
        distances: {pov: 0, alice: 1, bob: 2},
        orderedKeys: [pov, alice, bob],
        edges: {
          pov: [d1, t1],
          alice: [d2, t2],
        },
      );

      final ContentStatement f1 = makeContentStatement(
        verb: ContentVerb.follow,
        subject: alice.value,
        contexts: {'news': 1},
        iJson: povKey,
      );

      final ContentStatement f2 = makeContentStatement(
        verb: ContentVerb.follow,
        subject: bob.value,
        contexts: {'news': 1},
        iJson: aliceKey,
      );

      final Map<DelegateKey, List<ContentStatement>> delegateContent = {
        d1.subjectAsDelegate: [f1],
        d2.subjectAsDelegate: [f2],
      };

      final FollowNetwork network = reduceFollowNetwork(
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
