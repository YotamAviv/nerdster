import 'package:cloud_firestore/cloud_firestore.dart';
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
/// 
/// The plan is to pass in a function to do that if needed.
/// If that function is supplied, then the writer will 
/// - return a Statement quickly, 
/// - queue up the actual write,
/// - and if the write fails due to optimistic concurrency, call the function to clear caches.
/// If that function is not supplied, the writer will do the current behavior of 
/// - synchronously verifying optimistic concurrency,
/// - waiting for the write to complete.
/// - returning the Statement,
///

class DirectFirestoreWriter<T extends Statement> implements StatementWriter<T> {
  final FirebaseFirestore _fire;

  DirectFirestoreWriter(this._fire);

  @override
  Future<T> push(Json json, StatementSigner signer,
      {String? previous, OptimisticConcurrencyFunc? func}) async {
    assert(func == null, 'TODO');
    final String issuerToken = getToken(json['I']);
    final fireStatements = _fire.collection(issuerToken).doc('statements').collection('statements');

    // 1. Find the latest statement (Non-Atomic)
    // Note: This is not truly transactional because the Flutter SDK does not
    // support queries inside transactions.
    final latestSnapshot = await fireStatements.orderBy('time', descending: true).limit(1).get();
    String? previousToken;
    DateTime? prevTime;
    if (latestSnapshot.docs.isNotEmpty) {
      final latestDoc = latestSnapshot.docs.first;
      previousToken = latestDoc.id;
      prevTime = DateTime.parse(latestDoc.data()['time']);
    }

    // 2. Optimistic Concurrency Check
    if (previous != null) {
      if (previous.isEmpty) {
        if (previousToken != null) {
          throw Exception(
              'Push Rejected: Optimistic locking failure. Expected Genesis (no previous), found=$previousToken');
        }
      } else if (previousToken != previous) {
        throw Exception(
            'Push Rejected: Optimistic locking failure. Expected previous=$previous, found=$previousToken');
      }
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
          throw Exception('Timestamp must be after previous statement ($thisTime <= $prevTime)');
        }
      }

      transaction.set(docRef, jsonish.json);
    });

    return statement;
  }
}
