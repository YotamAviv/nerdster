import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/source_error.dart';
import 'package:flutter/foundation.dart';

/// A caching decorator for [StatementSource].
/// Stores fetched statements in memory to avoid redundant network calls.
///
/// ## Design & Correctness Note
/// This implementation treats each identity as having a single, immutable history.
/// It does not cache different 'revokeAt' views separately, as the trust algorithm
/// is greedy and deterministic; once a key is fetched, its statements are filtered
/// in memory by the logic layer.
class CachedSource<T extends Statement> implements StatementSource<T>, StatementWriter {
  final StatementSource<T> _delegate;
  final StatementWriter? _writer;

  // Full histories: Map<Token, List<Statement>>
  final Map<String, List<T>> _fullCache = {};

  // Partial histories: Map<Token, (revokeAt, List<Statement>)>
  final Map<String, (String, List<T>)> _partialCache = {};

  final Map<String, SourceError> _errorCache = {};

  CachedSource(this._delegate, [this._writer]);

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

  /// Pushes a new statement via the writer and updates the cache.
  ///
  /// The statement is prepended to the cached history (assuming descending time order).
  /// Verifies that `statement.previous` matches the current head of the history (if any).
  @override
  Future<Statement> push(Json json, StatementSigner signer) async {
    if (_writer == null) {
      throw UnimplementedError('No writer provided to CachedSource');
    }

    // 1. Write through to persistence
    final Statement statement = await _writer!.push(json, signer);

    // 2. Update cache
    if (statement is T) {
      _inject(statement);
    } else {
      // In theory, we could throw, but if we are just a cache for T, 
      // and we wrote something else (unlikely given writer pairing), we just ignore caching it.
       debugPrint('CachedSource: warning - wrote statement of type ${statement.runtimeType} but cache expects $T');
    }

    return statement;
  }

  void _inject(T statement) {
    if (statement.iToken.isEmpty) return;
    final String token = statement.iToken;

    // Safety: If we don't have the full history cached, create it if missing?
    // The previous logic was strict: "If we don't have the full history cached, we cannot safely prepend."
    // However, if we just wrote the HEAD, and we have nothing else, we are safe to say the history is [HEAD].
    // BUT only if 'previous' is null. If 'previous' exists, we are missing history.
    
    // Get current history or create new list
    List<T> history = [];
    if (_fullCache.containsKey(token)) {
      history = List.of(_fullCache[token]!);
    } else if (statement['previous'] != null) {
      // Missing history, safe to ignore cache update?
      // If we blindly add it, we have a gap.
      // Better to return and let next fetch resolve it.
      return; 
    }

    if (history.isNotEmpty) {
      final T head = history.first;
      // 'previous' is not a property on Statement but accessible via loose access
      final String? previous = statement['previous'];
      if (previous != head.token) {
        // Optimistic concurrency mismatch or cache stale.
        // Invalidate cache for this token to force refetch next time.
        _fullCache.remove(token);
        return;
      }
    }

    history.insert(0, statement);
    _fullCache[token] = history;
  }

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<T>> results = {};
    final Map<String, String?> missing = {};

    debugPrint('CachedSource: fetching ${keys.length} keys');

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
        results[token] = List.unmodifiable(_fullCache[token]!);
      } else if (revokeAt != null &&
          _partialCache.containsKey(token) &&
          _partialCache[token]!.$1 == revokeAt) {
        // Partial history is safe if the revokeAt matches exactly.
        results[token] = List.unmodifiable(_partialCache[token]!.$2);
      } else {
        if (_partialCache.containsKey(token)) {
           debugPrint('CachedSource miss for $token: partial mismatch req=$revokeAt, cached=${_partialCache[token]!.$1}');
        } else {
           debugPrint('CachedSource miss for $token: not in cache');
        }
        missing[token] = revokeAt;
      }
    }

    debugPrint('CachedSource: results=${results.length}, missing=${missing.length}');

    // 2. Fetch missing
    if (missing.isNotEmpty) {
      final Map<String, List<T>> fetched = await _delegate.fetch(missing);

      // 3. Update cache and results
      for (final String token in missing.keys) {
        // If delegate reported an error for this token, cache it
        final SourceError? error =
            _delegate.errors.where((SourceError e) => e.token == token).firstOrNull;
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
        results[token] = List.unmodifiable(statements);
      }
    }

    return results;
  }
}
