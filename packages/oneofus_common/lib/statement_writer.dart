import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';

/// Explicitly defines the expected state of the 'previous' pointer.
class ExpectedPrevious {
  /// The token we expect to see. null means we expect 'Genesis' (no previous statement).
  final String? token;
  const ExpectedPrevious(this.token);
}

abstract class StatementWriter<T extends Statement> {
  /// Pushes a new statement to the store.
  /// [json] is the raw statement data (without signature/previous).
  /// [signer] is used to sign the statement.
  /// [previous] (Optional) The expected state of the previous statement.
  ///   If NOT provided (null), no optimistic concurrency check is performed.
  ///   If provided (ExpectedPrevious), checks against the database state.
  ///   ExpectedPrevious(null) -> Expect Genesis (no previous).
  ///   ExpectedPrevious(token) -> Expect 'previous' to be this token.
  ///   The push MUST fail if the assertion is incorrect.
  /// Returns the created Statement.
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed});
}
