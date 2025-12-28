import 'package:flutter_test/flutter_test.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/oneofus/util.dart';

/// ## Reasoning: Greedy-Safe Caching in V2
///
/// The Trust Algorithm is "Greedy" because it fixes the distance and constraints 
/// (like `revokeAt`) for a key the first time it is encountered in a BFS traversal.
///
/// However, these constraints are only stable for a **single PoV** (root token).
/// If the PoV changes, a key might be reached via a different path with different 
/// (or no) `revokeAt` constraints.
///
/// ### The Caching Challenge:
/// 1. **Full History** (revokeAt: null) is always safe to cache and reuse. 
///    The logic layer can filter a full history down to any required partial view.
/// 2. **Partial History** (revokeAt: token) is only safe to reuse if the 
///    requested `revokeAt` matches exactly.
/// 3. **Poisoning**: If a partial history is served to a request for a full 
///    history, the system will miss statements, leading to missing monikers 
///    or broken trust links.
///
/// ### The Solution:
/// - `CachedSource` maintains separate caches for full and partial histories.
/// - Full histories are never cleared (unless explicitly requested).
/// - Partial histories are cleared via `resetRevokeAt()` whenever the PoV changes.
class MockSource implements StatementSource<TrustStatement> {
  final Map<String, List<TrustStatement>> data;
  int fetchCount = 0;

  MockSource(this.data);

  @override
  Future<Map<String, List<TrustStatement>>> fetch(Map<String, String?> keys) async {
    fetchCount++;
    final Map<String, List<TrustStatement>> results = {};
    for (var entry in keys.entries) {
      final token = entry.key;
      final revokeAt = entry.value;
      
      var list = data[token] ?? [];
      if (revokeAt != null) {
        // Simulate server-side filtering
        final index = list.indexWhere((s) => s.token == revokeAt);
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
    TrustStatement.init();
  });

  test('CachedSource: Partial history does not poison full history', () async {
    final s1 = TrustStatement(Jsonish({'time': '2023-01-01T00:00:00Z', 'I': {'x': 'B'}, 'trust': {'x': 'C'}}));
    final s2 = TrustStatement(Jsonish({'time': '2023-01-02T00:00:00Z', 'I': {'x': 'B'}, 'trust': {'x': 'D'}}));
    
    final mock = MockSource({
      'B': [s1, s2],
    });
    final cached = CachedSource(mock);

    // 1. Fetch partial history for B
    final res1 = await cached.fetch({'B': s1.token});
    expect(res1['B']!.length, 1, reason: 'Should return only S1');
    expect(mock.fetchCount, 1);

    // 2. Fetch full history for B
    final res2 = await cached.fetch({'B': null});
    expect(res2['B']!.length, 2, reason: 'Should return S1 and S2');
    expect(mock.fetchCount, 2, reason: 'Should have bypassed the partial cache');

    // 3. Fetch full history again (should be cached now)
    await cached.fetch({'B': null});
    expect(mock.fetchCount, 2, reason: 'Should have used the full cache');
  });

  test('CachedSource: Full history satisfies partial history request', () async {
    final s1 = TrustStatement(Jsonish({'time': '2023-01-01T00:00:00Z', 'I': {'x': 'B'}, 'trust': {'x': 'C'}}));
    final s2 = TrustStatement(Jsonish({'time': '2023-01-02T00:00:00Z', 'I': {'x': 'B'}, 'trust': {'x': 'D'}}));
    
    final mock = MockSource({
      'B': [s1, s2],
    });
    final cached = CachedSource(mock);

    // 1. Fetch full history first
    await cached.fetch({'B': null});
    expect(mock.fetchCount, 1);

    // 2. Fetch partial history (should use full cache)
    final res = await cached.fetch({'B': s1.token});
    expect(res['B']!.length, 2, reason: 'Returns full history; logic layer will filter');
    expect(mock.fetchCount, 1, reason: 'Should have used the full cache');
  });

  test('CachedSource: resetRevokeAt clears partials but keeps fulls', () async {
    final s1 = TrustStatement(Jsonish({'time': '2023-01-01T00:00:00Z', 'I': {'x': 'B'}, 'trust': {'x': 'C'}}));
    
    final mock = MockSource({
      'B': [s1],
      'A': [],
    });
    final cached = CachedSource(mock);

    await cached.fetch({'A': null}); // Full
    await cached.fetch({'B': s1.token}); // Partial
    expect(mock.fetchCount, 2);

    cached.resetRevokeAt();

    await cached.fetch({'A': null});
    expect(mock.fetchCount, 2, reason: 'A (full) should still be cached');

    await cached.fetch({'B': s1.token});
    expect(mock.fetchCount, 3, reason: 'B (partial) should have been cleared');
  });
}
