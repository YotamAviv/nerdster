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
class CachedSource<T extends Statement> implements StatementSource<T> {
  final StatementSource<T> _delegate;

  // Full histories: Map<Token, List<Statement>>
  final Map<String, List<T>> _fullCache = {};

  // Partial histories: Map<Token, (revokeAt, List<Statement>)>
  final Map<String, (String, List<T>)> _partialCache = {};

  CachedSource(this._delegate);

  void clear() {
    _fullCache.clear();
    _partialCache.clear();
  }

  /// Clears all cached partial histories. 
  /// Full histories remain valid across PoV changes.
  void resetRevokeAt() {
    _partialCache.clear();
  }

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<T>> results = {};
    final Map<String, String?> missing = {};

    // 1. Check cache
    for (var entry in keys.entries) {
      final token = entry.key;
      final revokeAt = entry.value;

      if (_fullCache.containsKey(token)) {
        // Full history is always safe to use; logic layer will filter if needed.
        results[token] = _fullCache[token]!;
      } else if (revokeAt != null &&
          _partialCache.containsKey(token) &&
          _partialCache[token]!.$1 == revokeAt) {
        // Partial history is safe if the revokeAt matches exactly.
        results[token] = _partialCache[token]!.$2;
      } else {
        missing[token] = revokeAt;
      }
    }

    // 2. Fetch missing
    if (missing.isNotEmpty) {
      final fetched = await _delegate.fetch(missing);

      // 3. Update cache and results
      for (var token in missing.keys) {
        final statements = fetched[token] ?? [];
        final revokeAt = missing[token];

        if (revokeAt == null) {
          _fullCache[token] = statements;
        } else {
          _partialCache[token] = (revokeAt, statements);
        }
        results[token] = statements;
      }
    }

    return results;
  }
}
