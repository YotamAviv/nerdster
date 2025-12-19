import 'package:test/test.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

void main() {
  group('Revocation Logic', () {
    test('Delegate with revokeAt filters subsequent statements', () {
      final root = 'ROOT';
      final oldKey = 'OLD';
      final newKey = 'NEW';
      final target = 'TARGET';
      
      final t1 = DateTime(2020);
      final t2 = DateTime(2021);
      final t3 = DateTime(2022);
      
      final statements = [
        // Root trusts Old
        TrustStatement.build(issuer: root, verb: TrustVerb.trust, subject: oldKey, time: t1),
        
        // Old trusts Target (at t1)
        TrustStatement.build(issuer: oldKey, verb: TrustVerb.trust, subject: target, time: t1),
        
        // Old delegates to New (at t2) and revokes itself at t2 (s3)
        TrustStatement.build(issuer: oldKey, verb: TrustVerb.delegate, subject: newKey, time: t2, revokeAt: 's3'),
        
        // Old tries to block Target (at t3) - Should be ignored!
        TrustStatement.build(issuer: oldKey, verb: TrustVerb.block, subject: target, time: t3),
      ];
      
      final graph = reduceTrustGraph(TrustGraph(root: root), statements);
      
      expect(graph.distances.containsKey(oldKey), isTrue);
      expect(graph.distances.containsKey(newKey), isTrue);
      expect(graph.distances.containsKey(target), isTrue, reason: "Target should be trusted because block was revoked");
      expect(graph.blocked.contains(target), isFalse, reason: "Block should be ignored");
    });

    test('Replace with revokeAt filters old key statements', () {
      final root = 'ROOT';
      final oldKey = 'OLD';
      final newKey = 'NEW';
      final target = 'TARGET';
      
      final t1 = DateTime(2020);
      final t2 = DateTime(2021);
      final t3 = DateTime(2022);
      
      final statements = [
        // Root trusts Old
        TrustStatement.build(issuer: root, verb: TrustVerb.trust, subject: oldKey, time: t1),
        
        // Old trusts Target (at t3) - Should be ignored due to revocation at t2
        TrustStatement.build(issuer: oldKey, verb: TrustVerb.trust, subject: target, time: t3),
        
        // New replaces Old (at t2) with revokeAt t2 (s3)
        // Note: We need a path to New for this to take effect? 
        // Or does replace work if we just see the statement?
        // In V2 logic, we process 'replace' from 'issuer' (New).
        // So we need to trust New.
        
        // Root trusts New (directly or via delegate)
        TrustStatement.build(issuer: root, verb: TrustVerb.trust, subject: newKey, time: t2),
        
        // New replaces Old
        TrustStatement.build(issuer: newKey, verb: TrustVerb.replace, subject: oldKey, time: t2, revokeAt: 's4'),
      ];
      
      var graph = reduceTrustGraph(TrustGraph(root: root), statements);
      // Run again to apply discovered constraints (convergence)
      graph = reduceTrustGraph(graph, statements);
      
      expect(graph.distances.containsKey(oldKey), isTrue);
      expect(graph.replacements[oldKey], equals(newKey));
      expect(graph.distances.containsKey(target), isFalse, reason: "Old key's trust should be ignored due to revocation");
    });
  });
}
