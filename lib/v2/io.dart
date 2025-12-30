import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';

/// Interface for fetching statements (Trust or Content).
abstract class StatementSource<T extends Statement> {
  /// Fetches statements for the given keys.
  /// [keys] maps the Identity Token to an optional replacement constraint (revokeAt) Token.
  /// If a constraint is provided, only statements up to (and including) that token are returned.
  /// Returns a map of Identity Token -> List of Statements.
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys);
}

/// Interface for writing statements.
abstract class StatementWriter {
  /// Pushes a new statement to the store.
  /// [json] is the raw statement data (without signature/previous).
  /// [signer] is used to sign the statement.
  /// Returns the created Statement.
  Future<Statement> push(Json json, StatementSigner signer);
}


