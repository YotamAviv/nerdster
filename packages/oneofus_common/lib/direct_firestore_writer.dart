import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_writer.dart';

/// A brief history of how we got here
///
/// 1) Jsonish.makeSign creates a signed statement Jsonish from [Json, signer]
/// This seemed clean at the time.
///
/// 2) Statement type (and probably ContentStatement and TrustStatement types) added.
///
/// Now I want to create the Statement earlier, async so that I don't have to wait to update the UI.
///
/// Both Statement and Jsonish instances are cached by token.
/// It seems dangerous to have invalid instances.
/// And so if I create the Statement before verifying the optimistic concurrency, I should
/// clear all caches, crash, or something like that.

class DirectFirestoreWriter<T extends Statement> implements StatementWriter<T> {
  final FirebaseFirestore _fire;

  // A map of issuer tokens to the latest write operation for that issuer.
  // This effectively acts as a per-issuer serialization queue.
  // Each new write attaches itself to the end of the existing chain via .then(),
  // creating a linked list of Futures. This ensures that writes for a specific
  // issuer are processed in strict FIFO order, preventing race conditions
  // (e.g. "fast dismissals") that would otherwise break the optimistic hash chain
  // if a later request finished signing before an earlier one.
  final Map<String, Future<void>> _writeQueues = {};

  DirectFirestoreWriter(this._fire);

  @override
  Future<T> push(Json json, StatementSigner signer,
      {ExpectedPrevious? previous, VoidCallback? optimisticConcurrencyFailed}) async {
    assert(!json.containsKey('previous'), 'unexpected');
    assert(optimisticConcurrencyFailed == null || previous != null,
        'optimisticConcurrencyFailed requires previous');
    final String issuerToken = getToken(json['I']);
    final CollectionReference<Map<String, dynamic>> fireStatements =
        _fire.collection(issuerToken).doc('statements').collection('statements');

    if (optimisticConcurrencyFailed != null) {
      // Optimistic Path: Return immediately, write in background.

      // 1. Synchronously reserve a spot in the write queue.
      // We must establish the order of writes *before* any async operations (like signing)
      // to ensure the database writes happen in the exact same order as the push() calls.
      final Completer<Jsonish> signingCompleter = Completer();

      // Get the current "tail" of the write chain for this issuer.
      final Future<void> previousWrite = _writeQueues[issuerToken] ?? Future.value();

      // Append our write task to the chain.
      final Future<void> currentWrite = previousWrite
          .catchError(
              (_) {}) // Swallow errors from the *previous* write so this one still attempts to run.
          .then((_) async {
        // Wait for the statement to be signed (step 2 below).
        final Jsonish jsonish = await signingCompleter.future;
        // Perform the actual Firestore transaction.
        return _writeOptimistic(fireStatements, jsonish, json['time']);
      }).onError((error, stackTrace) {
        optimisticConcurrencyFailed();
        return;
      });

      _writeQueues[issuerToken] = currentWrite;

      // 2. Perform async signing
      try {
        if (previous != null && previous.token != null) {
          json['previous'] = previous.token!; // Trust the caller (cache)
        }

        final Jsonish jsonish = await Jsonish.makeSign(json, signer);

        // 3. Hand off to the write queue
        signingCompleter.complete(jsonish);

        // 4. Return optimistic result immediately
        return Statement.make(jsonish) as T;
      } catch (e) {
        signingCompleter.completeError(e);
        rethrow;
      }
    } else {
      // Standard Path
      // 1. Find the latest statement (Non-Atomic)
      // Note: This is not truly transactional because the Flutter SDK does not
      // support queries inside transactions.
      final latestSnapshot =
          await fireStatements.orderBy('time', descending: true).limit(1).get();
      String? previousToken;
      DateTime? prevTime;
      if (latestSnapshot.docs.isNotEmpty) {
        final latestDoc = latestSnapshot.docs.first;
        previousToken = latestDoc.id;
        prevTime = DateTime.parse(latestDoc.data()['time']);
      }

      // 2. Optimistic Concurrency Check
      if (previous != null && previous.token != previousToken) {
        throw Exception(
            'Push Rejected: Optimistic locking failure. Expected previous=${previous.token}, found=$previousToken');
      }

      // 3. Set previous and sign
      if (previousToken != null) {
        json['previous'] = previousToken;
      }

      final Jsonish jsonish = await Jsonish.makeSign(json, signer);
      final T statement = Statement.make(jsonish) as T;

      // 3. Write statement (transactional check for existence)
      await _fire.runTransaction((transaction) async {
        final docRef = fireStatements.doc(jsonish.token);
        final doc = await transaction.get(docRef);
        if (doc.exists) {
          throw Exception('Statement already exists: ${jsonish.token}');
        }

        if (prevTime != null) {
          final DateTime thisTime = DateTime.parse(json['time']!);
          if (!thisTime.isAfter(prevTime)) {
            throw Exception(
                'Timestamp must be after previous statement ($thisTime <= $prevTime)');
          }
        }

        transaction.set(docRef, jsonish.json);
      });

      return statement;
    }
  }

  Future<void> _writeOptimistic(CollectionReference<Map<String, dynamic>> fireStatements,
      Jsonish jsonish, String timeString) async {
    final latestSnapshot = await fireStatements.orderBy('time', descending: true).limit(1).get();
    String? previousToken;
    DateTime? prevTime;
    if (latestSnapshot.docs.isNotEmpty) {
      final latestDoc = latestSnapshot.docs.first;
      previousToken = latestDoc.id;
      prevTime = DateTime.parse(latestDoc.data()['time']);
    }

    final String? signedPrevious = jsonish['previous'];

    if (signedPrevious != previousToken) {
      throw Exception(
          'Optimistic locking failure. Expected previous=$signedPrevious, found=$previousToken');
    }

    await _fire.runTransaction((transaction) async {
      final docRef = fireStatements.doc(jsonish.token);
      final doc = await transaction.get(docRef);
      if (doc.exists) {
        throw Exception('Statement already exists: ${jsonish.token}');
      }

      if (prevTime != null) {
        final DateTime thisTime = DateTime.parse(timeString);
        if (!thisTime.isAfter(prevTime)) {
          throw Exception('Timestamp must be after previous statement ($thisTime <= $prevTime)');
        }
      }

      transaction.set(docRef, jsonish.json);
    });
  }
}
