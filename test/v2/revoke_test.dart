import 'package:test/test.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart';

Json keyJson(String name) => {'kid': name, 'crv': 'Ed25519', 'kty': 'OKP', 'x': 'mock_$name'};

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

  group('Revocation Logic', () {
    test('Delegate with revokeAt filters subsequent statements', () {
      final root = 'ROOT';
      final oldKey = 'OLD';
      final newKey = 'NEW';
      final target = 'TARGET';
      
      final t1 = DateTime(2020);
      final t2 = DateTime(2021);
      final t3 = DateTime(2022);
      
      // Root trusts Old
      final s1 = makeTrust(issuer: root, verb: TrustVerb.trust, subject: oldKey, time: t1);
      
      // Old trusts Target (at t1)
      final s2 = makeTrust(issuer: oldKey, verb: TrustVerb.trust, subject: target, time: t1);
      
      // Old delegates to New (at t2) and revokes itself at t2 (revokeAt s2)
      // This means s2 is the last valid statement.
      final s3 = makeTrust(issuer: oldKey, verb: TrustVerb.delegate, subject: newKey, time: t2, revokeAt: s2.token);
      
      // Old tries to block Target (at t3) - Should be ignored!
      final s4 = makeTrust(issuer: oldKey, verb: TrustVerb.block, subject: target, time: t3);
      
      final statements = [s1, s2, s3, s4];
      statements.sort((a, b) => b.time.compareTo(a.time));
      
      final rootToken = Jsonish(keyJson(root)).token;
      final oldToken = Jsonish(keyJson(oldKey)).token;
      final newToken = Jsonish(keyJson(newKey)).token;
      final targetToken = Jsonish(keyJson(target)).token;

      final graph = reduceTrustGraph(TrustGraph(root: rootToken), statements);
      
      expect(graph.distances.containsKey(oldToken), isTrue);
      expect(graph.distances.containsKey(newToken), isTrue);
      expect(graph.distances.containsKey(targetToken), isTrue, reason: "Target should be trusted because block was revoked");
      expect(graph.blocked.contains(targetToken), isFalse, reason: "Block should be ignored");
    });

    test('Replace with revokeAt filters old key statements', () {
      final root = 'ROOT';
      final oldKey = 'OLD';
      final newKey = 'NEW';
      final target = 'TARGET';
      
      final t1 = DateTime(2020);
      final t2 = DateTime(2021);
      final t3 = DateTime(2022);
      
      // Root trusts Old
      final s1 = makeTrust(issuer: root, verb: TrustVerb.trust, subject: oldKey, time: t1);
      
      // Old trusts Target (at t3) - Should be ignored due to revocation at t2
      final s2 = makeTrust(issuer: oldKey, verb: TrustVerb.trust, subject: target, time: t3);
      
      // Root trusts New
      final s3 = makeTrust(issuer: root, verb: TrustVerb.trust, subject: newKey, time: t2);
      
      // New replaces Old (at t2) with revokeAt pointing to s1
      // This means s1 is the last valid statement from Old.
      final s4 = makeTrust(issuer: newKey, verb: TrustVerb.replace, subject: oldKey, time: t2, revokeAt: s1.token);
      
      final statements = [s1, s2, s3, s4];
      statements.sort((a, b) => b.time.compareTo(a.time));
      
      final rootToken = Jsonish(keyJson(root)).token;
      final oldToken = Jsonish(keyJson(oldKey)).token;
      final newToken = Jsonish(keyJson(newKey)).token;
      final targetToken = Jsonish(keyJson(target)).token;

      var graph = reduceTrustGraph(TrustGraph(root: rootToken), statements);
      // Run again to apply discovered constraints (convergence)
      graph = reduceTrustGraph(graph, statements);
      
      expect(graph.distances.containsKey(oldToken), isTrue);
      expect(graph.replacements[oldToken], equals(newToken));
      expect(graph.distances.containsKey(targetToken), isFalse, reason: "Old key's trust should be ignored due to revocation");
    });
  });
}
