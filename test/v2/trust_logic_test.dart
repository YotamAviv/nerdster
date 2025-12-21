import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:test/test.dart';

Json keyJson(String name) => {'kid': name, 'crv': 'Ed25519', 'kty': 'OKP', 'x': 'mock_$name'};
String keyToken(String name) => Jsonish(keyJson(name)).token;
DateTime t(int seconds) => DateTime.fromMillisecondsSinceEpoch(1000000 + seconds * 1000);

TrustStatement makeTrust({
  required String issuer,
  required TrustVerb verb,
  required dynamic subject,
  required DateTime time,
  String? revokeAt,
  String? moniker,
  String? domain,
}) {
  final iJson = keyJson(issuer);
  final otherJson = (subject is String) ? keyJson(subject) : subject;
  
  final json = TrustStatement.make(iJson, otherJson, verb, revokeAt: revokeAt, moniker: moniker, domain: domain);
  json['time'] = time.toIso8601String();
  
  return TrustStatement(Jsonish(json));
}

void main() {
  setUpAll(() {
    TrustStatement.init();
  });

  group('V2 Trust Logic', () {
    test('Basic Trust Propagation', () {
      final alice = keyToken('Alice');
      final bob = keyToken('Bob');
      final charlie = keyToken('Charlie');
      
      final root = alice;
      final statements = [
        makeTrust(issuer: 'Alice', verb: TrustVerb.trust, subject: 'Bob', time: t(10)),
        makeTrust(issuer: 'Bob', verb: TrustVerb.trust, subject: 'Charlie', time: t(10)),
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
        makeTrust(issuer: 'Alice', verb: TrustVerb.trust, subject: 'Bob', time: t(10)),
        makeTrust(issuer: 'Alice', verb: TrustVerb.block, subject: 'Charlie', time: t(11)),
        makeTrust(issuer: 'Bob', verb: TrustVerb.trust, subject: 'Charlie', time: t(10)),
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
        makeTrust(issuer: 'Alice', verb: TrustVerb.trust, subject: 'Bob', time: t(10)),
        makeTrust(issuer: 'Alice', verb: TrustVerb.trust, subject: 'Charlie', time: t(10)),
        
        // Bob claims he replaces OldKey
        makeTrust(issuer: 'Bob', verb: TrustVerb.replace, subject: 'OldKey', time: t(20)),
        
        // Charlie claims he replaces OldKey
        makeTrust(issuer: 'Charlie', verb: TrustVerb.replace, subject: 'OldKey', time: t(20)),
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
