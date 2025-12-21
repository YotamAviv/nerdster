import 'package:test/test.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/content/content_statement.dart';

class MockContentSource implements StatementSource {
  final Map<String, List<ContentStatement>> data;
  List<String>? lastRequestedKeys;

  MockContentSource(this.data);

  @override
  Future<Map<String, List<Statement>>> fetch(Map<String, String?> keys) async {
    lastRequestedKeys = keys.keys.toList();
    final results = <String, List<Statement>>{};
    for (var key in keys.keys) {
      if (data.containsKey(key)) {
        results[key] = data[key]!;
      }
    }
    return results;
  }
}

void main() {
  group('Content Pipeline', () {
    test('Fetches content only from trusted users', () async {
      final root = 'ROOT';
      final alice = 'ALICE';
      final bob = 'BOB'; // Blocked
      final charlie = 'CHARLIE'; // Trusted via Alice
      final dave = 'DAVE'; // Unknown

      // Setup Trust Graph
      final graph = TrustGraph(
        root: root,
        distances: {
          root: 0,
          alice: 1,
          charlie: 2,
        },
        blocked: {bob},
      );

      // Setup Content Data
      final t1 = DateTime(2023);
      final data = {
        root: [ContentStatement.build(issuer: root, verb: ContentVerb.rate, subject: 'book1', time: t1)],
        alice: [ContentStatement.build(issuer: alice, verb: ContentVerb.rate, subject: 'book1', time: t1)],
        bob: [ContentStatement.build(issuer: bob, verb: ContentVerb.rate, subject: 'book1', time: t1)],
        charlie: [ContentStatement.build(issuer: charlie, verb: ContentVerb.rate, subject: 'book1', time: t1)],
        dave: [ContentStatement.build(issuer: dave, verb: ContentVerb.rate, subject: 'book1', time: t1)],
      };

      final source = MockContentSource(data);
      final pipeline = ContentPipeline(source);

      final content = await pipeline.fetchContent(graph);

      // Verify requested keys
      expect(source.lastRequestedKeys, containsAll([root, alice, charlie]));
      expect(source.lastRequestedKeys, isNot(contains(bob)));
      expect(source.lastRequestedKeys, isNot(contains(dave)));

      // Verify returned content
      final issuers = content.map((c) => c.iToken).toSet();
      expect(issuers, containsAll([root, alice, charlie]));
      expect(issuers, isNot(contains(bob)));
      expect(issuers, isNot(contains(dave)));
    });
  });
}
