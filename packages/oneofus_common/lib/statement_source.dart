import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement.dart';

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

/// Explicitly defines the expected state of the 'previous' pointer.
class ExpectedPrevious {
  /// The token we expect to see. null means we expect 'Genesis' (no previous statement).
  final String? token;
  const ExpectedPrevious(this.token);
}

abstract class StatementWriter<T extends Statement> {
  /// Pushes a new statement to the store.
  /// [json] is the raw statement data without [signature, previous].
  /// [signer] is used to sign the statement.
  /// [previous] (Optional) The expected state of the previous statement.
  ///   If NOT provided (null), no optimistic concurrency check is performed.
  ///   If provided (ExpectedPrevious), checks against the database state.
  ///   ExpectedPrevious(null) -> Expect Genesis (no previous).
  ///   ExpectedPrevious(token) -> Expect 'previous' to be this token.
  ///   The push MUST fail if the assertion is incorrect.
  /// [optimisticConcurrencyFailed] (Optional)
  ///   If provided, the push is done optimistically:
  ///   - requires [previous] to be provided.
  ///   - The function returns immediately with the created Statement using the provided previous
  ///     token.
  ///   - The actual write is queued in the background.
  ///   - If the optimistic concurrency check fails during the background write,
  ///     this callback is invoked.
  ///   If NOT provided, the push is done synchronously:
  ///   - The function waits for the write to complete before returning.
  ///
  /// Returns the created Statement.
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed});
}

/// A paired source+writer for a single stream. Callers use this when they need both.
///
/// [push] returns after the statement is signed and injected into the local cache —
/// the network write completes in the background. Write failures are delivered to
/// [ChannelFactory.onWriteError]. The app layer is responsible for registering a handler
/// and cleaning up its own state (e.g. statement caches, sign-in state) when called.
abstract class StatementChannel<T extends Statement>
    implements StatementSource<T>, StatementWriter<T> {
  /// Drains any pending background writes, then clears all cached state so the
  /// next [fetch] is guaranteed to come from the underlying store.
  ///
  /// This is the correct way to force a network re-fetch. Callers must await it.
  Future<void> clear();

  void resetRevokeAt();

  /// Returns true if [issuerId] is already in the cache (from a prior fetch, push, or seed).
  bool isCached(String issuerId);

  /// Prime the cache for [issuerId] without a network fetch.
  /// Asserts that the cache slot is not already populated.
  void seed(String issuerId, List<T> statements);
}
