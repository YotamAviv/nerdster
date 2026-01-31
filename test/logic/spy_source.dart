import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement_source.dart';

/// A wrapper around [StatementSource] that records fetch calls.
class SpyStatementSource<T extends Statement> implements StatementSource<T> {
  final StatementSource<T> _delegate;
  final List<Map<String, String?>> fetchHistory = [];

  SpyStatementSource(this._delegate);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    fetchHistory.add(Map.from(keys));
    return _delegate.fetch(keys);
  }

  @override
  List<SourceError> get errors => _delegate.errors;

  /// Clears the recorded history.
  void resetHistory() {
    fetchHistory.clear();
  }
}
