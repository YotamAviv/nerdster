import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';

/// A read-filtered, write-passthrough facade over a root [StatementChannel<Statement>].
///
/// Reads delegate to the parent and filter the result set to type T via [whereType].
/// Writes delegate directly to the parent so head tracking is always correct,
/// regardless of the mix of statement types in the stream.
///
/// Distinctness is NOT applied here — it is the responsibility of the root
/// [_CachedSource] to maintain a distinct cache when constructed with distinct=true.
///
/// PERFORMANCE CRITICAL: the excludeTypes parameter on the root exists because users
/// dismiss thousands of items but rate only dozens. Peer streams must exclude dismiss
/// statements or the bandwidth cost becomes prohibitive.
class FilteredChannel<T extends Statement> implements StatementChannel<T> {
  final StatementChannel<Statement> _parent;

  FilteredChannel(this._parent);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<Statement>> all = await _parent.fetch(keys);
    return {
      for (final MapEntry<String, List<Statement>> e in all.entries)
        e.key: e.value.whereType<T>().toList(),
    };
  }

  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) async {
    return await _parent.push(json, signer,
        previous: previous,
        optimisticConcurrencyFailed: optimisticConcurrencyFailed) as T;
  }

  @override
  List<SourceError> get errors => _parent.errors;

  @override
  Future<void> clear() => _parent.clear();

  @override
  void resetRevokeAt() => _parent.resetRevokeAt();

  @override
  bool isCached(String issuerId) => _parent.isCached(issuerId);

  @override
  void seed(String issuerId, List<T> statements) {
    _parent.seed(issuerId, List<Statement>.from(statements));
  }
}
