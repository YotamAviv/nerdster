import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/model.dart';

/// The Pure Function Core of the Trust Algorithm.
///
/// Input: A starting graph (or empty) and a list of statements.
/// Output: A new TrustGraph.
///
/// This function is deterministic and synchronous.
TrustGraph reduceTrustGraph(TrustGraph current, List<TrustStatement> statements) {
  final Map<String, int> distances = {current.root: 0};
  final Map<String, String> replacements = {};
  final Map<String, String> revokeAtConstraints = Map.from(current.revokeAtConstraints); // Inherit constraints
  final Set<String> blocked = {};
  final List<TrustConflict> conflicts = [];
  final Map<String, List<TrustStatement>> edges = {};
  
  // Index statements
  final Map<String, List<TrustStatement>> byIssuer = {};
  final Map<String, TrustStatement> byToken = {};
  
  for (var s in statements) {
    byIssuer.putIfAbsent(s.iToken, () => []).add(s);
    byToken[s.token] = s;
  }

  // Helper to resolve revokeAt token to DateTime
  DateTime? resolveRevokeAt(String? revokeAtToken) {
    if (revokeAtToken == null) return null;
    final atom = byToken[revokeAtToken];
    return atom?.time;
  }

  // BFS Queue
  final queue = [current.root];
  final visited = {current.root};
  
  int maxDegrees = 6;
  
  while (queue.isNotEmpty) {
    final issuer = queue.removeAt(0);
    final dist = distances[issuer]!;
    
    if (dist >= maxDegrees) continue;
    
    var issuerStatements = byIssuer[issuer] ?? [];
    
    // Assert sorted (Newest First / Descending)
    // The source must provide them in this order.
    for (int i = 0; i < issuerStatements.length - 1; i++) {
       if (issuerStatements[i].time.isBefore(issuerStatements[i+1].time)) {
          throw 'Statements not sorted (expected Newest First) for $issuer';
       }
    }

    // --- FILTER by revokeAt (External Constraint) ---
    if (revokeAtConstraints.containsKey(issuer)) {
      final limitToken = revokeAtConstraints[issuer];
      final limitTime = resolveRevokeAt(limitToken);
      if (limitTime != null) {
        issuerStatements = issuerStatements.where((s) => !s.time.isAfter(limitTime)).toList();
      }
    }

    // --- FILTER by Self-Revocation (Delegate) ---
    DateTime? selfRevokeTime;
    for (var s in issuerStatements) {
       if (s.verb == TrustVerb.delegate && s.revokeAt != null) {
          final t = resolveRevokeAt(s.revokeAt);
          if (t != null) {
             if (selfRevokeTime == null || t.isBefore(selfRevokeTime)) {
                selfRevokeTime = t;
             }
          }
       }
    }
    
    if (selfRevokeTime != null) {
       issuerStatements = issuerStatements.where((s) => !s.time.isAfter(selfRevokeTime!)).toList();
    }

    // Store valid edges for this issuer
    edges[issuer] = issuerStatements;
    
    // --- STEP 1: Process BLOCKS ---
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.block)) {
      if (distances.containsKey(s.subjectToken)) {
        conflicts.add(TrustConflict(
          s.subjectToken,
          "Attempt to block trusted key by $issuer",
          [s.token]
        ));
      } else {
        blocked.add(s.subjectToken);
      }
    }
    
    // --- STEP 2: Process REPLACES (New -> Old) ---
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.replace)) {
      final oldKey = s.subjectToken;
      
      if (distances.containsKey(oldKey)) {
        conflicts.add(TrustConflict(
          oldKey,
          "Attempt to replace trusted key by $issuer",
          [s.token]
        ));
        continue;
      }

      if (replacements.containsKey(oldKey)) {
        final existingNewKey = replacements[oldKey];
        if (existingNewKey != issuer) {
           conflicts.add(TrustConflict(
             oldKey, 
             "Replaced by both $existingNewKey and $issuer",
             [s.token]
           ));
           continue;
        }
      }
      
      replacements[oldKey] = issuer;
      if (s.revokeAt != null) {
        revokeAtConstraints[oldKey] = s.revokeAt!;
      }
    }

    // --- STEP 3: Process DELEGATES (Old -> New) ---
    // NOTE: We do NOT traverse delegates as trust edges.
    // Delegates are for signing, not for expanding the trust graph.
    // (Unless we decide otherwise, but per docs/trust_semantics.md, they are service keys).
    
    /* 
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.delegate)) {
       // Logic for delegate traversal removed per semantics.
    }
    */

    // --- STEP 4: Process TRUSTS ---
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.trust)) {
      final subject = s.subjectToken;
      if (blocked.contains(subject)) {
        conflicts.add(TrustConflict(
          subject,
          "Attempt to trust blocked key by $issuer",
          [s.token]
        ));
        continue;
      }
      
      String effectiveSubject = subject;
      if (replacements.containsKey(subject)) {
        effectiveSubject = replacements[subject]!;
      }
      
      if (!visited.contains(effectiveSubject) && !blocked.contains(effectiveSubject)) {
        visited.add(effectiveSubject);
        distances[effectiveSubject] = dist + 1;
        queue.add(effectiveSubject);
      }
      
      // Also traverse the original subject if it's different (to catch pre-revocation statements)
      if (effectiveSubject != subject) {
         if (!visited.contains(subject) && !blocked.contains(subject)) {
            visited.add(subject);
            distances[subject] = dist + 1;
            queue.add(subject);
         }
      }
    }
  }
  
  return TrustGraph(
    root: current.root,
    distances: distances,
    replacements: replacements,
    revokeAtConstraints: revokeAtConstraints,
    blocked: blocked,
    conflicts: conflicts,
    edges: edges,
  );
}