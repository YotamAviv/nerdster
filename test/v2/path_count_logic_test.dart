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
    final pov = 'pov';
    final a1 = 'a1';
    final b1 = 'b1';
    final a2 = 'a2';
    final b2 = 'b2';

    // PoV -> A1, B1
    final s1 = TrustStatement(Jsonish({
      'token': 's1',
      'issuer': pov,
      'trust': a1,
      'time': '2025-01-01T00:00:00Z',
      'I': {'key': pov},
    }));
    final s2 = TrustStatement(Jsonish({
      'token': 's2',
      'issuer': pov,
      'trust': b1,
      'time': '2025-01-01T00:00:00Z',
      'I': {'key': pov},
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
      pov: [s1, s2],
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
      TrustGraph(pov: pov),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // A1 and B1 are at distance 1. They should be in.
    expect(tg.distances.containsKey(a1), isTrue);
    expect(tg.distances.containsKey(b1), isTrue);

    // A2 is at distance 2. It has only 1 path (pov -> a1 -> a2).
    // Requirement for dist 2 is 2 paths. So A2 should NOT be in.
    expect(tg.distances.containsKey(a2), isFalse, reason: 'A2 has only 1 path, needs 2');

    // B2 is at distance 2 (pov -> b1 -> b2) and distance 3 (pov -> a1 -> a2 -> b2).
    // However, the path through A2 is only valid if A2 is trusted.
    // Since A2 is NOT trusted, it cannot pass trust to B2.
    // So B2 only has 1 valid path (pov -> b1 -> b2).
    // Requirement for dist 2 is 2 paths. So B2 should NOT be in.
    expect(tg.distances.containsKey(b2), isFalse, reason: 'B2 only has 1 valid path because A2 is not trusted');
  });

  test('Path Requirement Logic: B2 is IN if A2 is also IN', () {
    final pov = 'pov';
    final a1 = 'a1';
    final b1 = 'b1';
    final c1 = 'c1';
    final a2 = 'a2';
    final b2 = 'b2';

    // PoV -> A1, B1, C1
    final s1 = TrustStatement(Jsonish({
      'token': 's1', 'issuer': pov, 'trust': a1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s2 = TrustStatement(Jsonish({
      'token': 's2', 'issuer': pov, 'trust': b1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s3 = TrustStatement(Jsonish({
      'token': 's3', 'issuer': pov, 'trust': c1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
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
      pov: [s1, s2, s3],
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
      TrustGraph(pov: pov),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // A2 now has 2 paths: (pov->a1->a2) and (pov->c1->a2).
    // So A2 is IN.
    expect(tg.distances.containsKey(a2), isTrue, reason: 'A2 has 2 node-disjoint paths');

    // B2 now has 2 paths: (pov->b1->b2) and (pov->a1->a2->b2).
    // Wait, are they node-disjoint?
    // Path 1: {pov, b1, b2}
    // Path 2: {pov, a1, a2, b2}
    // Yes!
    expect(tg.distances.containsKey(b2), isTrue, reason: 'B2 has 2 node-disjoint paths');
  });

  test('Path Requirement Logic: Mutual Trust at Degree 2 (Insufficient Paths)', () {
    final pov = 'pov';
    final i1 = 'I1';
    final i2 = 'I2';
    final a = 'A';
    final b = 'B';

    // Me -> I1, Me -> I2
    final s1 = TrustStatement(Jsonish({
      'token': 's1', 'issuer': pov, 'trust': i1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s2 = TrustStatement(Jsonish({
      'token': 's2', 'issuer': pov, 'trust': i2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));

    // I1 -> A, I2 -> B
    final s3 = TrustStatement(Jsonish({
      'token': 's3', 'issuer': i1, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i1},
    }));
    final s4 = TrustStatement(Jsonish({
      'token': 's4', 'issuer': i2, 'trust': b, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i2},
    }));

    // A -> B, B -> A
    final s5 = TrustStatement(Jsonish({
      'token': 's5', 'issuer': a, 'trust': b, 'time': '2025-01-01T00:00:00Z', 'I': {'key': a},
    }));
    final s6 = TrustStatement(Jsonish({
      'token': 's6', 'issuer': b, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': b},
    }));

    final byIssuer = {
      pov: [s1, s2],
      i1: [s3],
      i2: [s4],
      a: [s5],
      b: [s6],
    };

    // Requirement: 1 path for degree 1, 2 paths for degree 2+
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final tg = reduceTrustGraph(
      TrustGraph(pov: pov),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // I1 and I2 are at distance 1. They should be in.
    expect(tg.distances.containsKey(i1), isTrue);
    expect(tg.distances.containsKey(i2), isTrue);

    // A and B are at distance 2.
    // A has paths: (pov->i1->a) and (pov->i2->b->a).
    // However, (pov->i2->b->a) is only valid if B is already trusted.
    // In a greedy BFS, at the moment we evaluate distance 2, neither A nor B are trusted yet.
    // So they both only see 1 path from the "already trusted" set (distance 0 and 1).
    // Thus, they both fail the 2-path requirement.
    expect(tg.distances.containsKey(a), isFalse, reason: 'A needs 2 paths from trusted nodes, but only has 1 (via I1)');
    expect(tg.distances.containsKey(b), isFalse, reason: 'B needs 2 paths from trusted nodes, but only has 1 (via I2)');
  });

  test('Path Requirement Logic: Mutual Trust at Degree 2 (Sufficient Paths)', () {
    final pov = 'pov';
    final i1 = 'I1';
    final i2 = 'I2';
    final i3 = 'I3';
    final a = 'A';
    final b = 'B';

    // Me -> I1, Me -> I2, Me -> I3
    final s1 = TrustStatement(Jsonish({
      'token': 's1', 'issuer': pov, 'trust': i1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s2 = TrustStatement(Jsonish({
      'token': 's2', 'issuer': pov, 'trust': i2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s3 = TrustStatement(Jsonish({
      'token': 's3', 'issuer': pov, 'trust': i3, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));

    // I1 -> A, I3 -> A  (A has 2 paths)
    final s4 = TrustStatement(Jsonish({
      'token': 's4', 'issuer': i1, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i1},
    }));
    final s5 = TrustStatement(Jsonish({
      'token': 's5', 'issuer': i3, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i3},
    }));

    // I2 -> B, I3 -> B  (B has 2 paths)
    final s6 = TrustStatement(Jsonish({
      'token': 's6', 'issuer': i2, 'trust': b, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i2},
    }));
    final s7 = TrustStatement(Jsonish({
      'token': 's7', 'issuer': i3, 'trust': b, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i3},
    }));

    // A -> B, B -> A (Mutual trust)
    final s8 = TrustStatement(Jsonish({
      'token': 's8', 'issuer': a, 'trust': b, 'time': '2025-01-01T00:00:00Z', 'I': {'key': a},
    }));
    final s9 = TrustStatement(Jsonish({
      'token': 's9', 'issuer': b, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': b},
    }));

    final byIssuer = {
      pov: [s1, s2, s3],
      i1: [s4],
      i3: [s5, s7],
      i2: [s6],
      a: [s8],
      b: [s9],
    };

    // Requirement: 1 path for degree 1, 2 paths for degree 2+
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final tg = reduceTrustGraph(
      TrustGraph(pov: pov),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // I1, I2, I3 are at distance 1.
    expect(tg.distances.containsKey(i1), isTrue);
    expect(tg.distances.containsKey(i2), isTrue);
    expect(tg.distances.containsKey(i3), isTrue);

    // A and B are at distance 2.
    // A has 2 paths from {I1, I2, I3}: (pov->i1->a) and (pov->i3->a).
    // B has 2 paths from {I1, I2, I3}: (pov->i2->b) and (pov->i3->b).
    expect(tg.distances.containsKey(a), isTrue, reason: 'A has 2 paths from trusted nodes');
    expect(tg.distances.containsKey(b), isTrue, reason: 'B has 2 paths from trusted nodes');

    // Now that A and B are both IN, they can see each other's mutual trust.
    // For example, B now has a 3rd path: (pov->i1->a->b).
    // However, reduceTrustGraph only stores up to 'pathRequirement' paths.
    expect(tg.paths[a]!.length, equals(2));
    expect(tg.paths[b]!.length, equals(2));
  });

  test('Path Requirement Logic: Adding trust should not remove trust', () {
    final pov = 'pov';
    final i1 = 'I1';
    final i2 = 'I2';
    final i3 = 'I3';
    final i4 = 'I4';
    final i5 = 'I5';
    final a = 'A';
    final b = 'B';
    final x = 'X';

    // Me -> I1, I2, I3, I4
    final s1 = TrustStatement(Jsonish({
      'token': 's1', 'issuer': pov, 'trust': i1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s2 = TrustStatement(Jsonish({
      'token': 's2', 'issuer': pov, 'trust': i2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s3 = TrustStatement(Jsonish({
      'token': 's3', 'issuer': pov, 'trust': i3, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s4 = TrustStatement(Jsonish({
      'token': 's4', 'issuer': pov, 'trust': i4, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));

    // I1 -> A, I2 -> A (A has 2 paths at dist 2)
    final sA1 = TrustStatement(Jsonish({
      'token': 'sA1', 'issuer': i1, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i1},
    }));
    final sA2 = TrustStatement(Jsonish({
      'token': 'sA2', 'issuer': i2, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i2},
    }));

    // I3 -> B, I4 -> B (B has 2 paths at dist 2)
    final sB1 = TrustStatement(Jsonish({
      'token': 'sB1', 'issuer': i3, 'trust': b, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i3},
    }));
    final sB2 = TrustStatement(Jsonish({
      'token': 'sB2', 'issuer': i4, 'trust': b, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i4},
    }));

    // A -> X, B -> X (X has 2 paths at dist 3)
    final sX1 = TrustStatement(Jsonish({
      'token': 'sX1', 'issuer': a, 'trust': x, 'time': '2025-01-01T00:00:00Z', 'I': {'key': a},
    }));
    final sX2 = TrustStatement(Jsonish({
      'token': 'sX2', 'issuer': b, 'trust': x, 'time': '2025-01-01T00:00:00Z', 'I': {'key': b},
    }));

    final byIssuer = {
      pov: [s1, s2, s3, s4],
      i1: [sA1],
      i2: [sA2],
      i3: [sB1],
      i4: [sB2],
      a: [sX1],
      b: [sX2],
    };

    // Requirement: 2 paths for distance 2 (3 degrees) and beyond
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final tg1 = reduceTrustGraph(
      TrustGraph(pov: pov),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // X is in (2 paths: Me->I1/I2->A->X and Me->I3/I4->B->X)
    expect(tg1.distances.containsKey(x), isTrue, reason: 'X should be in with 2 paths at distance 3');
    expect(tg1.distances[x], equals(3));

    // Now add Me -> I5 and I5 -> X (X is now at distance 2 via I5)
    final s5 = TrustStatement(Jsonish({
      'token': 's5', 'issuer': pov, 'trust': i5, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov},
    }));
    final s6 = TrustStatement(Jsonish({
      'token': 's6', 'issuer': i5, 'trust': x, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i5},
    }));

    final byIssuer2 = {
      pov: [s1, s2, s3, s4, s5],
      i1: [sA1],
      i2: [sA2],
      i3: [sB1],
      i4: [sB2],
      i5: [s6],
      a: [sX1],
      b: [sX2],
    };

    final tg2 = reduceTrustGraph(
      TrustGraph(pov: pov),
      byIssuer2,
      pathRequirement: pathRequirement,
    );

    // X should still be in.
    // It fails the 2-path requirement at distance 2 (only has I5->X).
    // But it satisfies it at distance 3 (via A and B).
    expect(tg2.distances.containsKey(x), isTrue, reason: 'X should still be in after adding a closer path');
    expect(tg2.distances[x], equals(3), reason: 'X should still be at distance 3 because it fails the 2-path requirement at distance 2');
  });

  test('Path Requirement Logic: X at 2 degrees (1 path) and 3 degrees (1 path)', () {
    final pov = 'pov';
    final i1 = 'I1';
    final i2 = 'I2';
    final i3 = 'I3';
    final a = 'A';
    final x = 'X';

    // pov -> I1, I2, I3 (dist 1 / 2 degrees)
    final s1 = TrustStatement(Jsonish({'token': 's1', 'issuer': pov, 'trust': i1, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov}}));
    final s2 = TrustStatement(Jsonish({'token': 's2', 'issuer': pov, 'trust': i2, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov}}));
    final s3 = TrustStatement(Jsonish({'token': 's3', 'issuer': pov, 'trust': i3, 'time': '2025-01-01T00:00:00Z', 'I': {'key': pov}}));

    // I1 -> X (X at dist 2 / 3 degrees)
    final s4 = TrustStatement(Jsonish({'token': 's4', 'issuer': i1, 'trust': x, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i1}}));

    // I2 -> A, I3 -> A (A at dist 2 / 3 degrees, 2 paths)
    final s5 = TrustStatement(Jsonish({'token': 's5', 'issuer': i2, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i2}}));
    final s6 = TrustStatement(Jsonish({'token': 's6', 'issuer': i3, 'trust': a, 'time': '2025-01-01T00:00:00Z', 'I': {'key': i3}}));

    // A -> X (X at dist 3 / 4 degrees)
    final s7 = TrustStatement(Jsonish({'token': 's7', 'issuer': a, 'trust': x, 'time': '2025-01-01T00:00:00Z', 'I': {'key': a}}));

    final byIssuer = {
      pov: [s1, s2, s3],
      i1: [s4],
      i2: [s5],
      i3: [s6],
      a: [s7],
    };

    // Requirement: 2 paths for distance 2 (3 degrees) and beyond
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final tg = reduceTrustGraph(
      TrustGraph(pov: pov),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // X at dist 2 (3 degrees): 1 path (I1). Req 2. Fail.
    // X at dist 3 (4 degrees): 2 paths (I1, A). Req 2. Success.
    
    expect(tg.distances[i1], equals(1));
    expect(tg.distances[a], equals(2));
    expect(tg.distances.containsKey(x), isTrue, reason: 'X should be trusted at distance 3');
    expect(tg.distances[x], equals(3), reason: 'X should be at distance 3 because it needs 2 paths');
  });
}
