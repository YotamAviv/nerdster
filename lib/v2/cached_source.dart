import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/io.dart';

/// A caching decorator for [StatementSource].
/// Stores fetched statements in memory to avoid redundant network calls.
///
/// ## Design & Correctness Note
/// This implementation treats each identity as having a single, immutable history.
/// It does not cache different 'revokeAt' views separately, as the trust algorithm
/// is greedy and deterministic; once a key is fetched, its statements are filtered
/// in memory by the logic layer.
class CachedSource implements StatementSource {
  final StatementSource _delegate;

  // Map<Token, List<Statement>>
  final Map<String, List<Statement>> _cache = {};

  CachedSource(this._delegate);

  void clear() {
    _cache.clear();
  }

  @override
  Future<Map<String, List<Statement>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<Statement>> results = {};
    final Map<String, String?> missing = {};

    // 1. Check cache
    for (var entry in keys.entries) {
      final token = entry.key;

      if (_cache.containsKey(token)) {
        results[token] = _cache[token]!;
      } else {
        missing[token] = entry.value;
      }
    }

    // 2. Fetch missing
    if (missing.isNotEmpty) {
      final fetched = await _delegate.fetch(missing);

      // 3. Update cache and results
      for (var token in missing.keys) {
        // If the delegate didn't return anything for a requested key, it means empty list
        final statements = fetched[token] ?? [];

        _cache[token] = statements;
        results[token] = statements;
      }
    }

    return results;
  }
}
