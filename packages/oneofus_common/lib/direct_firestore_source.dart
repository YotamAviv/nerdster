import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus_common/distincter.dart' as d;
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:oneofus_common/statement_source.dart';

/// Fetches statements directly from Firestore.
/// This is used for:
/// 1. Unit tests (using FakeFirestore).
/// 2. Legacy/Fallback modes.
///
/// It replicates the logic of the Cloud Function (revokeAt filtering, distinct collapsing)
/// on the client side.
class DirectFirestoreSource<T extends Statement> implements StatementSource<T> {
  final FirebaseFirestore _fire;
  final StatementVerifier verifier;
  final ValueListenable<bool>? skipVerify;

  DirectFirestoreSource(this._fire, {StatementVerifier? verifier, this.skipVerify})
      : verifier = verifier ?? OouVerifier();

  final List<SourceError> _errors = [];

  @override
  List<SourceError> get errors => List.unmodifiable(_errors);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    _errors.clear();
    final Map<String, List<T>> results = {};
    final bool skipCheck = skipVerify?.value ?? false;

    await Future.wait(keys.entries.map((MapEntry<String, String?> entry) async {
      final String token = entry.key;
      final String? limitToken = entry.value;

      try {
        final CollectionReference<Json> collectionRef =
            _fire.collection(token).doc('statements').collection('statements');

        DateTime? limitTime;
        if (limitToken != null) {
          final DocumentSnapshot<Json> doc = await collectionRef.doc(limitToken).get();
          if (doc.exists && doc.data() != null) {
            limitTime = DateTime.parse(doc.data()!['time']);
          } else {
            // If limit token not found, return empty list
            results[token] = [];
            return;
          }
        }

        Query<Json> query = collectionRef.orderBy('time', descending: true);

        if (limitTime != null) {
          query = query.where('time', isLessThanOrEqualTo: limitTime.toUtc().toIso8601String());
        }

        final QuerySnapshot<Json> snapshot = await query.get();
        final List<T> chain = [];

        String? previousToken;
        DateTime? previousTime;
        bool first = true;

        for (final QueryDocumentSnapshot<Json> doc in snapshot.docs) {
          final Json json = doc.data();

          Jsonish jsonish;
          if (!skipCheck) {
            try {
              jsonish = await Jsonish.makeVerify(json, verifier);
            } catch (e) {
              throw SourceError(
                'Invalid Signature: $e',
                token: token,
                originalError: e,
              );
            }
          } else {
            jsonish = Jsonish(json);
          }

          // Verify Integrity (Doc ID matches Content Hash)
          if (jsonish.token != doc.id) {
            throw SourceError(
              'Integrity Violation: Document ID ${doc.id} does not match content hash ${jsonish.token}',
              token: token,
            );
          }

          final DateTime time = DateTime.parse(jsonish['time']);

          assert(previousTime == null || !time.isAfter(previousTime));
          if (first) {
            first = false;
          } else {
            if (previousToken == null) {
              throw SourceError(
                'Notary Chain Violation: Broken chain. Statement ${jsonish.token} is not linked from previous.',
                token: token,
              );
            }
            if (jsonish.token != previousToken) {
              throw SourceError(
                'Notary Chain Violation: Expected previous $previousToken, got ${jsonish.token}',
                token: token,
              );
            }
          }

          previousToken = json['previous'];
          previousTime = time;

          final Statement statement = Statement.make(jsonish);
          if (statement is T) {
            chain.add(statement);
          }
        }

        // Apply distinct
        final List<T> distinctChain = d.distinct(chain).toList();
        results[token] = List.unmodifiable(distinctChain);
      } catch (e) {
        if (e is SourceError) {
          _errors.add(e);
        } else {
          _errors.add(SourceError(
            'Error fetching $token: $e',
            token: token,
            originalError: e,
          ));
        }
        print(
            'DirectFirestoreSource: Corruption detected for $token. Discarding all statements. Error: $e');
        results.remove(token);
      }
    }));

    return results;
  }
}
