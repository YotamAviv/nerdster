import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';

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
