import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/source_error.dart';

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

  final Map<String, SourceError> _errorCache = {};

  CachedSource(this._delegate);

  @override
  List<SourceError> get errors => List.unmodifiable(_errorCache.values);

  void clear() {
    _fullCache.clear();
    _partialCache.clear();
    _errorCache.clear();
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
    for (final MapEntry<String, String?> entry in keys.entries) {
      final String token = entry.key;
      final String? revokeAt = entry.value;

      if (_errorCache.containsKey(token)) {
        // If we have a cached error, do not return any statements or fetch again.
        // The error is already in the 'errors' list.
        continue;
      }

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
      final Map<String, List<T>> fetched = await _delegate.fetch(missing);

      // 3. Update cache and results
      for (final String token in missing.keys) {
        // If delegate reported an error for this token, cache it
        final SourceError? error = _delegate.errors.where((SourceError e) => e.token == token).firstOrNull;
        if (error != null) {
          _errorCache[token] = error;
          continue; // Do not process statements for this token
        }

        final List<T> statements = fetched[token] ?? [];
        final String? revokeAt = missing[token];

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
