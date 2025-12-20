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
class DirectFirestoreSource implements StatementSource {
  final String domain;

  DirectFirestoreSource(this.domain);

  FirebaseFirestore get _fire => FireFactory.find(domain);

  @override
  Future<Map<String, List<Statement>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<Statement>> results = {};

    await Future.wait(keys.entries.map((entry) async {
      final token = entry.key;
      final revokeAt = entry.value;

      try {
        final collectionRef = _fire
            .collection(token)
            .doc('statements')
            .collection('statements');

        DateTime? revokeAtTime;
        if (revokeAt != null) {
          final doc = await collectionRef.doc(revokeAt).get();
          if (doc.exists && doc.data() != null) {
            revokeAtTime = parseIso(doc.data()!['time']);
          } else {
            // If revokeAt token not found, return empty list
            results[token] = [];
            return; 
          }
        }

        Query<Map<String, dynamic>> query = collectionRef.orderBy('time', descending: true);
        
        if (revokeAtTime != null) {
          query = query.where('time', isLessThanOrEqualTo: formatIso(revokeAtTime));
        }

        final snapshot = await query.get();
        final List<Statement> chain = [];
        
        String? previousToken;
        DateTime? previousTime;
        bool first = true;

        for (var doc in snapshot.docs) {
          final json = doc.data();
          final jsonish = Jsonish(json);

          final time = parseIso(jsonish['time']);
          
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

          chain.add(Statement.make(jsonish));
        }
        
        // Apply distinct
        final distinctChain = d.distinct(chain).toList();
        results[token] = distinctChain;

      } catch (e) {
        print('Error fetching $token: $e');
        results[token] = [];
      }
    }));
    
    return results;
  }
}
