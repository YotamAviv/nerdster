import 'package:nerdster/oneofus/statement.dart';

/// Interface for fetching statements (Trust or Content).
abstract class StatementSource {
  /// Fetches statements for the given keys.
  /// [keys] maps the Identity Token to an optional 'revokeAt' Token.
  /// If 'revokeAt' is provided, only statements up to (and including) that token are returned.
  /// Returns a map of Identity Token -> List of Statements.
  Future<Map<String, List<Statement>>> fetch(Map<String, String?> keys);
}


