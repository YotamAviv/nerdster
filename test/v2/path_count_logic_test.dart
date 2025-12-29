import 'package:test/test.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';

void main() {
  setUpAll(() {
    TrustStatement.init();
  });

  test('Path Requirement Logic: 2 paths for 3 and 4 degrees', () {
    final root = 'root';
    final a1 = 'a1';
    final b1 = 'b1';
    final a2 = 'a2';
    final b2 = 'b2';

    // PoV -> A1, B1
    final s1 = TrustStatement(Jsonish({
      'token': 's1',
      'issuer': root,
      'trust': a1,
      'time': '2025-01-01T00:00:00Z',
      'I': {'key': root},
    }));
    final s2 = TrustStatement(Jsonish({
      'token': 's2',
      'issuer': root,
      'trust': b1,
      'time': '2025-01-01T00:00:00Z',
      'I': {'key': root},
    }));

    // A1 -> A2
    final s3 = TrustStatement(Jsonish({
      'token': 's3',
      'issuer': a1,
      'trust': a2,
      'time': '2025-01-01T00:00:00Z',
      'I': {'key': a1},
    }));

    // B1 -> B2
    final s4 = TrustStatement(Jsonish({
      'token': 's4',
      'issuer': b1,
      'trust': b2,
      'time': '2025-01-01T00:00:00Z',
      'I': {'key': b1},
    }));

    // A2 -> B2
    final s5 = TrustStatement(Jsonish({
      'token': 's5',
      'issuer': a2,
      'trust': b2,
      'time': '2025-01-01T00:00:00Z',
      'I': {'key': a2},
    }));

    final byIssuer = {
      root: [s1, s2],
      a1: [s3],
      b1: [s4],
      a2: [s5],
    };

    // Requirement: 2 paths for 3 degrees (dist 2) and 4 degrees (dist 3)
    int pathRequirement(int dist) {
      if (dist >= 2) return 2;
      return 1;
    }

    final tg = reduceTrustGraph(
      TrustGraph(root: root),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // A1 and B1 are at distance 1. They should be in.
    expect(tg.distances.containsKey(a1), isTrue);
    expect(tg.distances.containsKey(b1), isTrue);

    // A2 is at distance 2. It has only 1 path (root -> a1 -> a2).
    // Requirement for dist 2 is 2 paths. So A2 should NOT be in.
    expect(tg.distances.containsKey(a2), isFalse, reason: 'A2 has only 1 path, needs 2');

    // B2 is at distance 2 (root -> b1 -> b2) and distance 3 (root -> a1 -> a2 -> b2).
    // However, the path through A2 is only valid if A2 is trusted.
    // Since A2 is NOT trusted, it cannot pass trust to B2.
    // So B2 only has 1 valid path (root -> b1 -> b2).
    // Requirement for dist 2 is 2 paths. So B2 should NOT be in.
    expect(tg.distances.containsKey(b2), isFalse, reason: 'B2 only has 1 valid path because A2 is not trusted');
  });

  test('Path Requirement Logic: B2 is IN if A2 is also IN', () {
    final root = 'root';
    final a1 = 'a1';
    final b1 = 'b1';
    final c1 = 'c1';
    final a2 = 'a2';
    final b2 = 'b2';

    // PoV -> A1, B1, C1
    final s1 = TrustStatement(Jsonish({
      'token': 's1', 'issuer': root, 'trust': a1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': root},
    }));
    final s2 = TrustStatement(Jsonish({
      'token': 's2', 'issuer': root, 'trust': b1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': root},
    }));
    final s3 = TrustStatement(Jsonish({
      'token': 's3', 'issuer': root, 'trust': c1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': root},
    }));

    // A1 -> A2, C1 -> A2
    final s4 = TrustStatement(Jsonish({
      'token': 's4', 'issuer': a1, 'trust': a2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': a1},
    }));
    final s5 = TrustStatement(Jsonish({
      'token': 's5', 'issuer': c1, 'trust': a2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': c1},
    }));

    // B1 -> B2, A2 -> B2
    final s6 = TrustStatement(Jsonish({
      'token': 's6', 'issuer': b1, 'trust': b2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': b1},
    }));
    final s7 = TrustStatement(Jsonish({
      'token': 's7', 'issuer': a2, 'trust': b2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': a2},
    }));

    final byIssuer = {
      root: [s1, s2, s3],
      a1: [s4],
      c1: [s5],
      b1: [s6],
      a2: [s7],
    };

    int pathRequirement(int dist) {
      if (dist >= 2) return 2;
      return 1;
    }

    final tg = reduceTrustGraph(
      TrustGraph(root: root),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // A2 now has 2 paths: (root->a1->a2) and (root->c1->a2).
    // So A2 is IN.
    expect(tg.distances.containsKey(a2), isTrue, reason: 'A2 has 2 node-disjoint paths');

    // B2 now has 2 paths: (root->b1->b2) and (root->a1->a2->b2).
    // Wait, are they node-disjoint?
    // Path 1: {root, b1, b2}
    // Path 2: {root, a1, a2, b2}
    // Yes!
    expect(tg.distances.containsKey(b2), isTrue, reason: 'B2 has 2 node-disjoint paths');
  });
}
