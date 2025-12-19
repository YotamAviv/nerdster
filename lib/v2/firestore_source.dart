import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/io.dart';

class FirestoreSource implements StatementSource, ContentSource {
  final String domain;

  FirestoreSource(this.domain);

  FirebaseFirestore get _fire => FireFactory.find(domain);

  @override
  Future<List<TrustStatement>> fetch(List<String> keys) async {
    final List<TrustStatement> results = [];

    // Parallel fetch
    await Future.wait(keys.map((key) async {
      try {
        final snapshot = await _fire
            .collection(key)
            .doc('statements')
            .collection('statements')
            .orderBy('time', descending: true)
            .get();

        final List<TrustStatement> chain = [];
        String? previousToken;
        DateTime? previousTime;

        for (var doc in snapshot.docs) {
          final json = doc.data();
          final jsonish = Jsonish(json);

          // Verify Notary Chain (See docs/notary_chain.md)
          if (previousToken != null) {
            if (jsonish.token != previousToken) {
              throw 'Notary Chain Violation ($key): ${jsonish.token} != $previousToken';
            }
          }

          final time = parseIso(jsonish['time']);
          if (previousTime != null) {
            if (!time.isBefore(previousTime)) {
              throw 'Time Violation ($key): $time >= $previousTime';
            }
          }

          previousToken = json['previous'];
          previousTime = time;

          if (jsonish['statement'] == 'net.one-of-us') {
            final statement = toTrustStatement(jsonish);
            chain.add(statement);
          }
        }
        results.addAll(chain);
      } catch (e) {
        print('Error fetching/verifying $key: $e');
        // Strict mode: Discard entire chain on error.
      }
    }));

    return results;
  }

  @override
  Future<List<ContentStatement>> fetchContent(List<String> keys) async {
    final List<ContentStatement> results = [];

    await Future.wait(keys.map((key) async {
      try {
        final snapshot = await _fire
            .collection(key)
            .doc('statements')
            .collection('statements')
            .orderBy('time', descending: true)
            .get();

        final List<ContentStatement> chain = [];
        String? previousToken;
        DateTime? previousTime;

        for (var doc in snapshot.docs) {
          final json = doc.data();
          final jsonish = Jsonish(json);

          // Verify Notary Chain (See docs/notary_chain.md)
          if (previousToken != null) {
            if (jsonish.token != previousToken) {
              throw 'Notary Chain Violation ($key): ${jsonish.token} != $previousToken';
            }
          }

          final time = parseIso(jsonish['time']);
          if (previousTime != null) {
            if (!time.isBefore(previousTime)) {
              throw 'Time Violation ($key): $time >= $previousTime';
            }
          }

          previousToken = json['previous'];
          previousTime = time;

          if (jsonish['statement'] == 'org.nerdster') {
            final statement = toContentStatement(jsonish);
            chain.add(statement);
          }
        }
        results.addAll(chain);
      } catch (e) {
        print('Error fetching/verifying $key: $e');
        // Strict mode: Discard entire chain on error.
      }
    }));

    return results;
  }
}
