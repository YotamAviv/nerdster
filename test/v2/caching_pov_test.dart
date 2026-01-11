import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/demotest/test_util.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/source_error.dart';

class MockSource implements StatementSource<TrustStatement> {
  final Map<String, List<TrustStatement>> data;
  int dFetchCount = 0;

  MockSource(this.data);

  @override
  List<SourceError> get errors => [];

  @override
  Future<Map<String, List<TrustStatement>>> fetch(Map<String, String?> keys) async {
    dFetchCount++;
    final Map<String, List<TrustStatement>> results = {};
    for (final MapEntry<String, String?> entry in keys.entries) {
      final String token = entry.key;
      final String? revokeAt = entry.value;

      List<TrustStatement> list = data[token] ?? [];
      if (revokeAt != null) {
        // Simulate server-side filtering
        final int index = list.indexWhere((TrustStatement s) => s.token == revokeAt);
        if (index != -1) {
          list = list.sublist(0, index + 1);
        }
      }
      results[token] = list;
    }
    return results;
  }
}

void main() {
  setUp(() {
    setUpTestRegistry();
  });

  test('CachedSource: Partial history does not poison full history', () async {
    final Map<String, dynamic> keyB = mockKey('B');
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: mockKey('C'),
      iJson: keyB,
      time: DateTime.parse('2023-01-01T00:00:00Z'),
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: mockKey('D'),
      iJson: keyB,
      time: DateTime.parse('2023-01-02T00:00:00Z'),
    );

    final MockSource mock = MockSource({
      'B': [s1, s2],
    });
    final CachedSource<TrustStatement> cached = CachedSource<TrustStatement>(mock);

    // 1. Fetch partial history for B
    final Map<String, List<TrustStatement>> res1 = await cached.fetch({'B': s1.token});
    expect(res1['B']!.length, 1, reason: 'Should return only S1');
    expect(mock.dFetchCount, 1);

    // 2. Fetch full history for B
    final Map<String, List<TrustStatement>> res2 = await cached.fetch({'B': null});
    expect(res2['B']!.length, 2, reason: 'Should return S1 and S2');
    expect(mock.dFetchCount, 2, reason: 'Should have bypassed the partial cache');

    // 3. Fetch full history again (should be cached now)
    await cached.fetch({'B': null});
    expect(mock.dFetchCount, 2, reason: 'Should have used the full cache');
  });

  test('CachedSource: Full history satisfies partial history request', () async {
    final Map<String, dynamic> keyB = mockKey('B');
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: mockKey('C'),
      iJson: keyB,
      time: DateTime.parse('2023-01-01T00:00:00Z'),
    );
    final TrustStatement s2 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: mockKey('D'),
      iJson: keyB,
      time: DateTime.parse('2023-01-02T00:00:00Z'),
    );

    final MockSource mock = MockSource({
      'B': [s1, s2],
    });
    final CachedSource<TrustStatement> cached = CachedSource<TrustStatement>(mock);

    // 1. Fetch full history first
    await cached.fetch({'B': null});
    expect(mock.dFetchCount, 1);

    // 2. Fetch partial history (should use full cache)
    final Map<String, List<TrustStatement>> res = await cached.fetch({'B': s1.token});
    expect(res['B']!.length, 2, reason: 'Returns full history; logic layer will filter');
    expect(mock.dFetchCount, 1, reason: 'Should have used the full cache');
  });

  test('CachedSource: resetRevokeAt clears partials but keeps fulls', () async {
    final TrustStatement s1 = makeTrustStatement(
      verb: TrustVerb.trust,
      subject: mockKey('C'),
      iJson: mockKey('B'),
      time: DateTime.parse('2023-01-01T00:00:00Z'),
    );

    final MockSource mock = MockSource({
      'B': [s1],
      'A': [],
    });
    final CachedSource<TrustStatement> cached = CachedSource<TrustStatement>(mock);

    await cached.fetch({'A': null}); // Full
    await cached.fetch({'B': s1.token}); // Partial
    expect(mock.dFetchCount, 2);

    cached.resetRevokeAt();

    await cached.fetch({'A': null});
    expect(mock.dFetchCount, 2, reason: 'A (full) should still be cached');

    await cached.fetch({'B': s1.token});
    expect(mock.dFetchCount, 3, reason: 'B (partial) should have been cleared');
  });
}
