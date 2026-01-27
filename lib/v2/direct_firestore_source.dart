import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/oneofus/distincter.dart' as d;
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/source_error.dart';

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

  DirectFirestoreSource(this._fire, {StatementVerifier? verifier})
      : verifier = verifier ?? OouVerifier();

  final List<SourceError> _errors = [];

  @override
  List<SourceError> get errors => List.unmodifiable(_errors);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    _errors.clear();
    final Map<String, List<T>> results = {};
    final bool skipVerify = Setting.get<bool>(SettingType.skipVerify).value;

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
          if (!skipVerify) {
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

/// Writes statements directly to Firestore.
class DirectFirestoreWriter implements StatementWriter {
  final FirebaseFirestore _fire;

  DirectFirestoreWriter(this._fire);

  @override
  Future<Statement> push(Json json, StatementSigner signer, {String? previous}) async {
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
    final statement = Statement.make(jsonish);

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
