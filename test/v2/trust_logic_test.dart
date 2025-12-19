import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:test/test.dart';

String keyToken(String name) => Jsonish({'kid': name}).token;
DateTime t(int seconds) => DateTime.fromMillisecondsSinceEpoch(1000000 + seconds * 1000);

void main() {
  group('V2 Trust Logic', () {
    test('Basic Trust Propagation', () {
      final alice = keyToken('Alice');
      final bob = keyToken('Bob');
      final charlie = keyToken('Charlie');
      
      final root = alice;
      final statements = [
        TrustStatement.build(issuer: 'Alice', verb: TrustVerb.trust, subject: bob, time: t(10)),
        TrustStatement.build(issuer: 'Bob', verb: TrustVerb.trust, subject: charlie, time: t(10)),
      ];
      
      statements.sort((a, b) => b.time.compareTo(a.time));

      final graph = reduceTrustGraph(TrustGraph(root: root), statements);

      expect(graph.isTrusted(alice), isTrue);
      expect(graph.isTrusted(bob), isTrue);
      expect(graph.isTrusted(charlie), isTrue);
      expect(graph.distances[charlie], 2);
    });

    test('Blocking stops propagation', () {
      final alice = keyToken('Alice');
      final bob = keyToken('Bob');
      final charlie = keyToken('Charlie');

      final root = alice;
      final statements = [
        TrustStatement.build(issuer: 'Alice', verb: TrustVerb.trust, subject: bob, time: t(10)),
        TrustStatement.build(issuer: 'Alice', verb: TrustVerb.block, subject: charlie, time: t(11)),
        TrustStatement.build(issuer: 'Bob', verb: TrustVerb.trust, subject: charlie, time: t(10)),
      ];

      statements.sort((a, b) => b.time.compareTo(a.time));

      final graph = reduceTrustGraph(TrustGraph(root: root), statements);

      expect(graph.isTrusted(bob), isTrue);
      expect(graph.isTrusted(charlie), isFalse, reason: "Alice blocked Charlie, so Bob's trust should be ignored");
      expect(graph.blocked.contains(charlie), isTrue);
    });

    test('Conflict: Two keys replace the same key', () {
      final alice = keyToken('Alice');
      final bob = keyToken('Bob');
      final charlie = keyToken('Charlie');
      final oldKey = keyToken('OldKey');

      final root = alice;
      
      final statements = [
        // Alice trusts Bob and Charlie, who are the "New Keys"
        TrustStatement.build(issuer: 'Alice', verb: TrustVerb.trust, subject: bob, time: t(10)),
        TrustStatement.build(issuer: 'Alice', verb: TrustVerb.trust, subject: charlie, time: t(10)),
        
        // Bob claims he replaces OldKey
        TrustStatement.build(issuer: 'Bob', verb: TrustVerb.replace, subject: oldKey, time: t(20)),
        
        // Charlie claims he replaces OldKey
        TrustStatement.build(issuer: 'Charlie', verb: TrustVerb.replace, subject: oldKey, time: t(20)),
      ];

      statements.sort((a, b) => b.time.compareTo(a.time));

      final graph = reduceTrustGraph(TrustGraph(root: root), statements);

      // Both Bob and Charlie are trusted
      expect(graph.isTrusted(bob), isTrue);
      expect(graph.isTrusted(charlie), isTrue);
      
      // One replacement should succeed, the other should conflict.
      // Since OldKey is NOT directly trusted, the replacement is valid.
      expect(graph.replacements[oldKey], isNotNull);
      expect(graph.conflicts, isNotEmpty);
      expect(graph.conflicts.first.reason, contains('Replaced by both'));
    });
  });
}
