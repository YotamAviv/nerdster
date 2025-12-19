import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/io.dart';

/// A caching decorator for [StatementSource].
/// Stores fetched statements in memory to avoid redundant network calls.
///
/// The cache is keyed by both the Identity Token and the 'revokeAt' Token,
/// as the set of valid statements depends on the revocation point (time travel).
class CachedSource implements StatementSource {
  final StatementSource _delegate;
  
  // Map<Token, Map<RevokeAt?, List<Statement>>>
  final Map<String, Map<String?, List<Statement>>> _cache = {};

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
      final revokeAt = entry.value;

      if (_cache.containsKey(token) && _cache[token]!.containsKey(revokeAt)) {
        results[token] = _cache[token]![revokeAt]!;
      } else {
        missing[token] = revokeAt;
      }
    }

    // 2. Fetch missing
    if (missing.isNotEmpty) {
      final fetched = await _delegate.fetch(missing);
      
      // 3. Update cache and results
      for (var entry in missing.entries) {
        final token = entry.key;
        final revokeAt = entry.value;
        
        // If the delegate didn't return anything for a requested key, it means empty list
        final statements = fetched[token] ?? [];
        
        if (!_cache.containsKey(token)) {
          _cache[token] = {};
        }
        _cache[token]![revokeAt] = statements;
        results[token] = statements;
      }
    }

    return results;
  }
}
