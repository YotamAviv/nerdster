import 'dart:async';

import 'package:oneofus_common/distincter.dart' as d;
import 'package:oneofus_common/statement.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement_source.dart';

/// A caching decorator for [StatementSource].
/// Stores fetched statements in memory to avoid redundant network calls.
///
/// ## Design & Correctness Note
/// This implementation treats each identity as having a single, immutable history.
/// It does not cache different 'revokeAt' views separately, as the trust algorithm
/// is greedy and deterministic; once a key is fetched, its statements are filtered
/// in memory by the logic layer.
class CachedSource<T extends Statement> implements StatementChannel<T> {
  final StatementSource<T> _source;
  final StatementWriter<T>? _writer;

  // Full histories: Map<Token, List<Statement>>
  final Map<String, List<T>> _fullCache = {};

  // Partial histories: Map<Token, (revokeAt, List<Statement>)>
  final Map<String, (String, List<T>)> _partialCache = {};

  final Map<String, SourceError> _errorCache = {};

  // Serializes concurrent pushes per issuer so each reads the correct cache head.
  final Map<String, Future<void>> _pushQueues = {};

  final VoidCallback? optimisticConcurrencyFunc;

  CachedSource(this._source, [this._writer, this.optimisticConcurrencyFunc]);

  @override
  List<SourceError> get errors => List.unmodifiable(_errorCache.values);

  @override
  void clear() {
    _fullCache.clear();
    _partialCache.clear();
    _errorCache.clear();
  }

  @override
  void resetRevokeAt() {
    _partialCache.clear();
  }

  /// Pushes a new statement via the writer and updates the cache.
  ///
  /// The statement is prepended to the cached history (assuming descending time order).
  /// Verifies that `statement.previous` matches the current head of the history (if any).
  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) {
    if (_writer == null) throw UnimplementedError('No writer');
    if (previous != null) throw StateError('CachedSource.push, no previous parameter');

    final String issuerId = getToken(json['I']);
    final completer = Completer<T>();
    final Future<void> prev = _pushQueues[issuerId] ?? Future.value();
    _pushQueues[issuerId] = prev.catchError((_) {}).then((_) async {
      try {
        assert(_fullCache.containsKey(issuerId), 'fetch before push');
        final ExpectedPrevious head = _fullCache[issuerId]!.isEmpty
            ? const ExpectedPrevious(null)
            : ExpectedPrevious(_fullCache[issuerId]!.first.token);
        final T statement = await _writer.push(json, signer,
            previous: head,
            optimisticConcurrencyFailed: optimisticConcurrencyFailed ?? optimisticConcurrencyFunc);
        _inject(statement);
        completer.complete(statement);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });
    return completer.future;
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
      if (previous != null && previous.isNotEmpty) {
        throw Exception('Cache inconsistency detected for token $token (expected Genesis)');
      }
    } else {
      final T head = history.first;
      if (previous != head.token) {
        throw Exception('Cache inconsistency detected for token $token (prev $previous != head ${head.token})');
      }
    }

    history.insert(0, statement);
    _fullCache[token] = d.distinct(history).toList();
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
        if (revokeAt == null) {
          results[token] = List.unmodifiable(_fullCache[token]!);
        } else {
          // Apply revokeAt filter in-memory when the revokeAt token is present in this
          // stream's cache. Statements are newest-first, so sublist(idx) returns
          // everything at and before the revokeAt position.
          // If the token is not found (e.g. it lives in a different stream like 'dis'),
          // fall through to the underlying source which searches allStreams by time.
          final List<T> full = _fullCache[token]!;
          final int idx = full.indexWhere((T s) => s.token == revokeAt);
          if (idx >= 0) {
            results[token] = List.unmodifiable(full.sublist(idx));
          } else {
            missing[token] = revokeAt;
          }
        }
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
      final Map<String, List<T>> fetched = await _source.fetch(missing);

      // 3. Update cache and results
      for (final String token in missing.keys) {
        // If delegate reported an error for this token, cache it
        final SourceError? error =
            _source.errors.where((SourceError e) => e.token == token).firstOrNull;
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
