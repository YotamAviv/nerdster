import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import '../test_utils.dart';

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  IdentityKey id(Map<String, dynamic> key) => IdentityKey(Jsonish(key).token);

  test('Path Requirement Logic: 2 paths for 3 and 4 degrees', () {
    final Map<String, dynamic> povKey = mockKey('pov');
    final IdentityKey pov = id(povKey);
    final Map<String, dynamic> a1Key = mockKey('a1');
    final IdentityKey a1 = id(a1Key);
    final Map<String, dynamic> b1Key = mockKey('b1');
    final IdentityKey b1 = id(b1Key);
    final Map<String, dynamic> a2Key = mockKey('a2');
    final IdentityKey a2 = id(a2Key);
    final Map<String, dynamic> b2Key = mockKey('b2');
    final IdentityKey b2 = id(b2Key);

    // PoV -> A1, B1
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: a1Key,
      iJson: povKey,
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: b1Key,
      iJson: povKey,
    );

    // A1 -> A2
    final TrustStatement s3 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: a2Key,
      iJson: a1Key,
    );

    // B1 -> B2
    final TrustStatement s4 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: b2Key,
      iJson: b1Key,
    );

    // A2 -> B2
    final TrustStatement s5 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: b2Key,
      iJson: a2Key,
    );

    final Map<IdentityKey, List<TrustStatement>> byIssuer = {
      pov: [s2, s1],
      a1: [s3],
      b1: [s4],
      a2: [s5],
    };

    // Requirement: 2 paths for 3 degrees (dist 2) and 4 degrees (dist 3)
    int pathRequirement(int dist) {
      if (dist >= 2) return 2;
      return 1;
    }

    final TrustGraph tg = reduceTrustGraph(
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
    final Map<String, dynamic> povKey = mockKey('pov');
    final IdentityKey pov = id(povKey);
    final Map<String, dynamic> a1Key = mockKey('a1');
    final IdentityKey a1 = id(a1Key);
    final Map<String, dynamic> b1Key = mockKey('b1');
    final IdentityKey b1 = id(b1Key);
    final Map<String, dynamic> c1Key = mockKey('c1');
    final IdentityKey c1 = id(c1Key);
    final Map<String, dynamic> a2Key = mockKey('a2');
    final IdentityKey a2 = id(a2Key);
    final Map<String, dynamic> b2Key = mockKey('b2');
    final IdentityKey b2 = id(b2Key);

    // PoV -> A1, B1, C1
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: a1Key,
      iJson: povKey,
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: b1Key,
      iJson: povKey,
    );
    final TrustStatement s3 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: c1Key,
      iJson: povKey,
    );

    // A1 -> A2, C1 -> A2
    final TrustStatement s4 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: a2Key,
      iJson: a1Key,
    );
    final TrustStatement s5 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: a2Key,
      iJson: c1Key,
    );

    // B1 -> B2, A2 -> B2
    final TrustStatement s6 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: b2Key,
      iJson: b1Key,
    );
    final TrustStatement s7 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: b2Key,
      iJson: a2Key,
    );

    final Map<IdentityKey, List<TrustStatement>> byIssuer = {
      pov: [s3, s2, s1],
      a1: [s4],
      c1: [s5],
      b1: [s6],
      a2: [s7],
    };

    int pathRequirement(int dist) {
      if (dist >= 2) return 2;
      return 1;
    }

    final TrustGraph tg = reduceTrustGraph(
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
    final Map<String, dynamic> povKey = mockKey('pov');
    final IdentityKey pov = id(povKey);
    final Map<String, dynamic> i1Key = mockKey('I1');
    final IdentityKey i1 = id(i1Key);
    final Map<String, dynamic> i2Key = mockKey('I2');
    final IdentityKey i2 = id(i2Key);
    final Map<String, dynamic> aKey = mockKey('A');
    final IdentityKey a = id(aKey);
    final Map<String, dynamic> bKey = mockKey('B');
    final IdentityKey b = id(bKey);

    // Me -> I1, Me -> I2
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i1Key,
      iJson: povKey,
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i2Key,
      iJson: povKey,
    );

    // I1 -> A, I2 -> B
    final TrustStatement s3 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: i1Key,
    );
    final TrustStatement s4 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: bKey,
      iJson: i2Key,
    );

    // A -> B, B -> A
    final TrustStatement s5 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: bKey,
      iJson: aKey,
    );
    final TrustStatement s6 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: bKey,
    );

    final Map<IdentityKey, List<TrustStatement>> byIssuer = {
      pov: [s2, s1],
      i1: [s3],
      i2: [s4],
      a: [s5],
      b: [s6],
    };

    // Requirement: 1 path for degree 1, 2 paths for degree 2+
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final TrustGraph tg = reduceTrustGraph(
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
    final Map<String, dynamic> povKey = mockKey('pov');
    final IdentityKey pov = id(povKey);
    final Map<String, dynamic> i1Key = mockKey('I1');
    final IdentityKey i1 = id(i1Key);
    final Map<String, dynamic> i2Key = mockKey('I2');
    final IdentityKey i2 = id(i2Key);
    final Map<String, dynamic> i3Key = mockKey('I3');
    final IdentityKey i3 = id(i3Key);
    final Map<String, dynamic> aKey = mockKey('A');
    final IdentityKey a = id(aKey);
    final Map<String, dynamic> bKey = mockKey('B');
    final IdentityKey b = id(bKey);

    // Me -> I1, Me -> I2, Me -> I3
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i1Key,
      iJson: povKey,
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i2Key,
      iJson: povKey,
    );
    final TrustStatement s3 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i3Key,
      iJson: povKey,
    );

    // I1 -> A, I3 -> A  (A has 2 paths)
    final TrustStatement s4 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: i1Key,
    );
    final TrustStatement s5 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: i3Key,
    );

    // I2 -> B, I3 -> B  (B has 2 paths)
    final TrustStatement s6 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: bKey,
      iJson: i2Key,
    );
    final TrustStatement s7 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: bKey,
      iJson: i3Key,
    );

    // A -> B, B -> A (Mutual trust)
    final TrustStatement s8 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: bKey,
      iJson: aKey,
    );
    final TrustStatement s9 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: bKey,
    );

    final Map<IdentityKey, List<TrustStatement>> byIssuer = {
      pov: [s3, s2, s1],
      i1: [s4],
      i3: [s7, s5],
      i2: [s6],
      a: [s8],
      b: [s9],
    };

    // Requirement: 1 path for degree 1, 2 paths for degree 2+
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final TrustGraph tg = reduceTrustGraph(
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
    final Map<String, dynamic> povKey = mockKey('pov');
    final IdentityKey pov = id(povKey);
    final Map<String, dynamic> i1Key = mockKey('I1');
    final IdentityKey i1 = id(i1Key);
    final Map<String, dynamic> i2Key = mockKey('I2');
    final IdentityKey i2 = id(i2Key);
    final Map<String, dynamic> i3Key = mockKey('I3');
    final IdentityKey i3 = id(i3Key);
    final Map<String, dynamic> i4Key = mockKey('I4');
    final IdentityKey i4 = id(i4Key);
    final Map<String, dynamic> i5Key = mockKey('I5');
    final IdentityKey i5 = id(i5Key);
    final Map<String, dynamic> aKey = mockKey('A');
    final IdentityKey a = id(aKey);
    final Map<String, dynamic> bKey = mockKey('B');
    final IdentityKey b = id(bKey);
    final Map<String, dynamic> xKey = mockKey('X');
    final IdentityKey x = id(xKey);

    // Me -> I1, I2, I3, I4
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i1Key,
      iJson: povKey,
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i2Key,
      iJson: povKey,
    );
    final TrustStatement s3 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i3Key,
      iJson: povKey,
    );
    final TrustStatement s4 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i4Key,
      iJson: povKey,
    );

    // I1 -> A, I2 -> A (A has 2 paths at dist 2)
    final TrustStatement sA1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: i1Key,
    );
    final TrustStatement sA2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: i2Key,
    );

    // I3 -> B, I4 -> B (B has 2 paths at dist 2)
    final TrustStatement sB1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: bKey,
      iJson: i3Key,
    );
    final TrustStatement sB2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: bKey,
      iJson: i4Key,
    );

    // A -> X, B -> X (X has 2 paths at dist 3)
    final TrustStatement sX1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: xKey,
      iJson: aKey,
    );
    final TrustStatement sX2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: xKey,
      iJson: bKey,
    );

    final Map<IdentityKey, List<TrustStatement>> byIssuer = {
      pov: [s4, s3, s2, s1],
      i1: [sA1],
      i2: [sA2],
      i3: [sB1],
      i4: [sB2],
      a: [sX1],
      b: [sX2],
    };

    // Requirement: 2 paths for distance 2 (3 degrees) and beyond
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final TrustGraph tg1 = reduceTrustGraph(
      TrustGraph(pov: pov),
      byIssuer,
      pathRequirement: pathRequirement,
    );

    // X is in (2 paths: Me->I1/I2->A->X and Me->I3/I4->B->X)
    expect(tg1.distances.containsKey(x), isTrue, reason: 'X should be in with 2 paths at distance 3');
    expect(tg1.distances[x], equals(3));

    // Now add Me -> I5 and I5 -> X (X is now at distance 2 via I5)
    final TrustStatement s5 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i5Key,
      iJson: povKey,
    );
    final TrustStatement s6 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: xKey,
      iJson: i5Key,
    );

    final Map<IdentityKey, List<TrustStatement>> byIssuer2 = {
      pov: [s5, s4, s3, s2, s1],
      i1: [sA1],
      i2: [sA2],
      i3: [sB1],
      i4: [sB2],
      i5: [s6],
      a: [sX1],
      b: [sX2],
    };

    final TrustGraph tg2 = reduceTrustGraph(
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
    final Map<String, dynamic> povKey = mockKey('pov');
    final IdentityKey pov = id(povKey);
    final Map<String, dynamic> i1Key = mockKey('I1');
    final IdentityKey i1 = id(i1Key);
    final Map<String, dynamic> i2Key = mockKey('I2');
    final IdentityKey i2 = id(i2Key);
    final Map<String, dynamic> i3Key = mockKey('I3');
    final IdentityKey i3 = id(i3Key);
    final Map<String, dynamic> aKey = mockKey('A');
    final IdentityKey a = id(aKey);
    final Map<String, dynamic> xKey = mockKey('X');
    final IdentityKey x = id(xKey);

    // pov -> I1, I2, I3 (dist 1 / 2 degrees)
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i1Key,
      iJson: povKey,
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i2Key,
      iJson: povKey,
    );
    final TrustStatement s3 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: i3Key,
      iJson: povKey,
    );

    // I1 -> X (X at dist 2 / 3 degrees)
    final TrustStatement s4 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: xKey,
      iJson: i1Key,
    );

    // I2 -> A, I3 -> A (A at dist 2 / 3 degrees, 2 paths)
    final TrustStatement s5 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: i2Key,
    );
    final TrustStatement s6 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: aKey,
      iJson: i3Key,
    );

    // A -> X (X at dist 3 / 4 degrees)
    final TrustStatement s7 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: xKey,
      iJson: aKey,
    );

    final Map<IdentityKey, List<TrustStatement>> byIssuer = {
      pov: [s3, s2, s1],
      i1: [s4],
      i2: [s5],
      i3: [s6],
      a: [s7],
    };

    // Requirement: 2 paths for distance 2 (3 degrees) and beyond
    int pathRequirement(int dist) => (dist >= 2) ? 2 : 1;

    final TrustGraph tg = reduceTrustGraph(
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
