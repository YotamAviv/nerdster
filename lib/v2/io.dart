import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';

/// Interface for fetching statements (Trust or Content).
abstract class StatementSource {
  /// Fetches statements for the given keys.
  /// [keys] maps the Identity Token to an optional 'revokeAt' Token.
  /// If 'revokeAt' is provided, only statements up to (and including) that token are returned.
  /// Returns a map of Identity Token -> List of Statements.
  Future<Map<String, List<Statement>>> fetch(Map<String, String?> keys);
}

/// A source that parses a raw JSON map (Token -> List<StatementJson>).
/// This matches the format of the 'export' Cloud Function.
class MemorySource implements StatementSource {
  final Map<String, List<Statement>> data = {};

  MemorySource([Map<String, List<dynamic>>? jsonData]) {
    if (jsonData != null) {
      for (var entry in jsonData.entries) {
        data[entry.key] = entry.value.map((json) {
          final jsonish = Jsonish(json);
          return Statement.make(jsonish);
        }).toList();
      }
    }
  }

  @override
  Future<Map<String, List<Statement>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<Statement>> results = {};
    for (var entry in keys.entries) {
      final key = entry.key;
      // TODO: Implement revokeAt filtering for MemorySource if needed for tests
      if (data.containsKey(key)) {
        results[key] = data[key]!;
      }
    }
    return results;
  }
}

