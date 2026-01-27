import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/source_error.dart';

/// Interface for fetching statements (Trust or Content).
abstract class StatementSource<T extends Statement> {
  /// Fetches statements for the given keys.
  /// [keys] maps the Identity Token to an optional replacement constraint (revokeAt) Token.
  /// If a constraint is provided, only statements up to (and including) that token are returned.
  /// Returns a map of Identity Token -> List of Statements.
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys);

  /// Returns any notifications (e.g. corruption, warnings) generated during the last fetch.
  List<SourceError> get errors;
}

/// Interface for writing statements.
abstract class StatementWriter {
  /// Pushes a new statement to the store.
  /// [json] is the raw statement data (without signature/previous).
  /// [signer] is used to sign the statement.
  /// [previous] (Optional) The token of the last known statement.
  ///   If NOT provided (null), no optimistic concurrency check is performed.
  ///   If provided as an empty string (""), asserts that no previous statement exists (Genesis).
  ///   If provided as a token, asserts that it is the latest statement.
  ///   The push MUST fail if the assertion is incorrect.
  /// Returns the created Statement.
  Future<Statement> push(Json json, StatementSigner signer, {String? previous});
}
