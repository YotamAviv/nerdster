import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/oneofus/distincter.dart' as d;
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/refresh_signal.dart';

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

  final List<TrustNotification> _notifications = [];

  @override
  List<TrustNotification> get notifications => _notifications;

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    _notifications.clear();
    final Map<String, List<T>> results = {};
    final bool skipVerify = Setting.get<bool>(SettingType.skipVerify).value;

    await Future.wait(keys.entries.map((MapEntry<String, String?> entry) async {
      final String token = entry.key;
      final String? limitToken = entry.value;

      try {
        final CollectionReference<Map<String, dynamic>> collectionRef =
            _fire.collection(token).doc('statements').collection('statements');

        DateTime? limitTime;
        if (limitToken != null) {
          final DocumentSnapshot<Map<String, dynamic>> doc =
              await collectionRef.doc(limitToken).get();
          if (doc.exists && doc.data() != null) {
            limitTime = parseIso(doc.data()!['time']);
          } else {
            // If limit token not found, return empty list
            results[token] = [];
            return;
          }
        }

        Query<Map<String, dynamic>> query = collectionRef.orderBy('time', descending: true);

        if (limitTime != null) {
          query = query.where('time', isLessThanOrEqualTo: formatIso(limitTime));
        }

        final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
        final List<T> chain = [];

        String? previousToken;
        DateTime? previousTime;
        bool first = true;

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
          final Map<String, dynamic> json = doc.data();

          Jsonish jsonish;
          if (!skipVerify) {
            try {
              jsonish = await Jsonish.makeVerify(json, verifier);
            } catch (e) {
              _notifications.add(TrustNotification(
                reason: 'Invalid Signature: $e',
                relatedStatement: Statement.make(Jsonish(json)),
                isConflict: true,
              ));
              continue;
            }
          } else {
            jsonish = Jsonish(json);
          }

          // Verify Integrity (Doc ID matches Content Hash)
          if (jsonish.token != doc.id) {
            _notifications.add(TrustNotification(
              reason:
                  'Integrity Violation: Document ID ${doc.id} does not match content hash ${jsonish.token}',
              relatedStatement: Statement.make(jsonish),
              isConflict: true,
            ));
          }

          final DateTime time = parseIso(jsonish['time']);

          assert(previousTime == null || !time.isAfter(previousTime));
          if (first) {
            first = false;
          } else {
            // TODO: These aren't TrustNotifications, and they never show up.
            // BUG: The reduceTrustGraph function (in trust_logic.dart) rebuilds the graph from scratch and initializes a new, empty list of notifications, ignoring the ones passed in via the graph argument.
            if (previousToken == null) {
              print(
                  'Notary Chain Violation: Expected previous $previousToken, got ${jsonish.token}');
              _notifications.add(TrustNotification(
                reason:
                    'Notary Chain Violation: Broken chain. Statement ${jsonish.token} is not linked from previous.',
                relatedStatement: Statement.make(jsonish),
                isConflict: true,
              ));
              break;
            }
            if (jsonish.token != previousToken) {
              print(
                  'Notary Chain Violation: Expected previous $previousToken, got ${jsonish.token}');
              _notifications.add(TrustNotification(
                reason:
                    'Notary Chain Violation: Expected previous $previousToken, got ${jsonish.token}',
                relatedStatement: Statement.make(jsonish),
                isConflict: true,
              ));
              // Stop processing this chain on violation
              // TODO: BUG: return 0 statements instead.
              break;
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
        results[token] = distinctChain;
      } catch (e) {
        print('Error fetching $token: $e');
        results[token] = [];
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
  Future<Statement> push(Json json, StatementSigner signer) async {
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
      prevTime = parseIso(latestDoc.data()['time']);
    }

    // 2. Set previous and sign
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
        final DateTime thisTime = parseIso(json['time']!);
        if (!thisTime.isAfter(prevTime)) {
          throw Exception('Timestamp must be after previous statement ($thisTime <= $prevTime)');
        }
      }

      transaction.set(docRef, jsonish.json);
    });

    v2RefreshSignal.signal();
    return statement;
  }
}
