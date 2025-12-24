import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/oneofus/distincter.dart' as d;
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/io.dart';

/// Fetches statements directly from Firestore.
/// This is used for:
/// 1. Unit tests (using FakeFirestore).
/// 2. Legacy/Fallback modes.
///
/// It replicates the logic of the Cloud Function (revokeAt filtering, distinct collapsing)
/// on the client side.
class DirectFirestoreSource<T extends Statement> implements StatementSource<T> {
  final String domain;

  DirectFirestoreSource(this.domain);

  FirebaseFirestore get _fire => FireFactory.find(domain);

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<T>> results = {};

    await Future.wait(keys.entries.map((MapEntry<String, String?> entry) async {
      final String token = entry.key;
      final String? limitToken = entry.value;

      try {
        final CollectionReference<Map<String, dynamic>> collectionRef = _fire
            .collection(token)
            .doc('statements')
            .collection('statements');

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

        Query<Map<String, dynamic>> query =
            collectionRef.orderBy('time', descending: true);

        if (limitTime != null) {
          query =
              query.where('time', isLessThanOrEqualTo: formatIso(limitTime));
        }

        final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
        final List<T> chain = [];

        String? previousToken;
        DateTime? previousTime;
        bool first = true;

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final Map<String, dynamic> json = doc.data();
          final Jsonish jsonish = Jsonish(json);

          final DateTime time = parseIso(jsonish['time']);

          if (first) {
            first = false;
          } else {
            if (previousToken != null && jsonish.token != previousToken) {
              print('Notary Chain Violation ($token)');
              // Stop processing this chain on violation
              break;
            }
            if (previousTime != null && !time.isBefore(previousTime)) {
              print('Time Violation ($token)');
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
