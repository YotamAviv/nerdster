import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/source_error.dart';

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
  Future<Statement> push(Json json, StatementSigner signer, {String? previous}) async {
    if (_writer == null) {
      throw UnimplementedError('No writer provided to CachedSource');
    }

    final String issuerId = getToken(json['I']);
    String? expectedPrevious;

    if (_fullCache.containsKey(issuerId)) {
      if (_fullCache[issuerId]!.isEmpty) {
        expectedPrevious = "";
      } else {
        expectedPrevious = _fullCache[issuerId]!.first.token;
      }
    }

    // Auto-detect previous from cache if not provided
    if (previous == null) {
      previous = expectedPrevious;
    } else {
      // Validate provided previous against cache
      // Note: We only validate if we actually have a cache history.
      if (expectedPrevious != null && previous != expectedPrevious) {
        throw Exception(
            'Cache Inconsistency: Provided previous ($previous) does not match cached head ($expectedPrevious). Refresh required.');
      }
    }

    // 1. Write through to persistence
    // If a previous token is provided (from the cache head), pass it to the writer
    // to enforce optimistic concurrency control.
    final Statement statement = await _writer.push(json, signer, previous: previous);
    if (statement is! T) {
      throw Exception('type ${statement.runtimeType} but cache expects $T');
    }

    // 2. Update cache
    _inject(statement);

    return statement;
  }

  void _inject(T statement) {
    assert(statement.iToken.isNotEmpty);
    final String token = statement.iToken;
    if (!_fullCache.containsKey(token)) {
      return;
    }
    List<T> history = List.of(_fullCache[token]!);

    final String? previous = statement['previous'];
    if (history.isEmpty) {
      if (previous != null) {
        throw Exception('Cache inconsistency detected for token $token');
      }
    } else {
      final T head = history.first;
      if (previous != head.token) {
        throw Exception('Cache inconsistency detected for token $token');
      }
    }

    history.insert(0, statement);
    _fullCache[token] = history;
  }

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<T>> results = {};
    final Map<String, String?> missing = {};

    // debugPrint('CachedSource: fetching ${keys.length} keys');

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
        // if (_partialCache.containsKey(token)) {
        //   debugPrint(
        //       'CachedSource miss for $token: partial mismatch req=$revokeAt, cached=${_partialCache[token]!.$1}');
        // } else {
        //   debugPrint('CachedSource miss for $token: not in cache');
        // }
        missing[token] = revokeAt;
      }
    }

    // debugPrint('CachedSource: results=${results.length}, missing=${missing.length}');

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
