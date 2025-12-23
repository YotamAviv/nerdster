import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/model.dart';

typedef PathRequirement = int Function(int distance);

/// The Pure Function Core of the Trust Algorithm.
///
/// Input: A starting graph (or empty) and a list of statements.
/// Output: A new TrustGraph.
///
/// This function is deterministic and synchronous.
/// It implements a Greedy BFS with support for:
/// - Key Rotations (Replace statements)
/// - Conflicts (Trust vs Block)
/// - Confidence Levels (Multiple paths for distant nodes)
/// - Notifications
TrustGraph reduceTrustGraph(
  TrustGraph current, 
  List<TrustStatement> statements, {
  PathRequirement? pathRequirement,
}) {
  final Map<String, int> distances = {current.root: 0};
  final Map<String, String> replacements = Map.from(current.replacements);
  final Map<String, String> revokeAtConstraints = Map.from(current.revokeAtConstraints);
  final Set<String> blocked = {};
  final List<TrustNotification> notifications = [];
  final Map<String, List<TrustStatement>> edges = {};
  
  // --- 1. Index Statements ---
  final Map<String, List<TrustStatement>> byIssuer = {};
  final Map<String, TrustStatement> byToken = {};
  
  for (var s in statements) {
    byIssuer.putIfAbsent(s.iToken, () => []).add(s);
    byToken[s.token] = s;
  }

  DateTime? resolveRevokeAt(String? revokeAtToken) {
    if (revokeAtToken == null) return null;
    return byToken[revokeAtToken]?.time;
  }

  // --- 2. BFS Traversal ---
  final queue = [current.root];
  final visited = {current.root};
  
  // Track paths for confidence levels (Node -> Set of Issuers who trust it)
  final Map<String, Set<String>> trustedBy = {};

  int maxDegrees = 6;
  final req = pathRequirement ?? (d) => 1;
  
  while (queue.isNotEmpty) {
    final issuer = queue.removeAt(0);
    final dist = distances[issuer]!;
    
    if (dist >= maxDegrees) continue;
    
    var issuerStatements = byIssuer[issuer] ?? [];
    
    // Sort Newest First (Descending)
    issuerStatements.sort((a, b) => b.time.compareTo(a.time));

    // --- FILTER by revokeAt (External Constraint) ---
    // This handles 'replace' statements where a new key revokes an old one.
    if (revokeAtConstraints.containsKey(issuer)) {
      final limitTime = resolveRevokeAt(revokeAtConstraints[issuer]);
      if (limitTime != null) {
        issuerStatements = issuerStatements.where((s) => !s.time.isAfter(limitTime)).toList();
      }
    }

    // Store valid edges for this issuer
    edges[issuer] = issuerStatements;
    
    final Set<String> decided = {};

    // --- STEP 0: Process CLEARS ---
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.clear)) {
      decided.add(s.subjectToken);
    }

    // --- STEP 1: Process BLOCKS ---
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.block)) {
      final subject = s.subjectToken;
      if (decided.contains(subject)) continue;
      decided.add(subject);

      if (distances.containsKey(subject)) {
        notifications.add(TrustNotification(
          subject: subject,
          reason: "Attempt to block trusted key by $issuer",
          relatedStatements: [s.token],
          isConflict: true,
        ));
      } else {
        blocked.add(subject);
      }
    }
    
    // --- STEP 2: Process REPLACES (New -> Old) ---
    for (var s in issuerStatements.where((s) => s.verb == TrustVerb.replace)) {
      final oldKey = s.subjectToken;
      if (decided.contains(oldKey)) continue;
      // We don't add to 'decided' here because a key can be replaced 
      // and then subsequently blocked or trusted in the same history? 
      // Actually, newest-first means if it's replaced, that's the latest word.
      decided.add(oldKey);
      
      final alreadyNotified = notifications.any((n) => n.relatedStatements.contains(s.token));

      if (distances.containsKey(oldKey) && !alreadyNotified) {
        notifications.add(TrustNotification(
          subject: oldKey,
          reason: "Trusted key $oldKey is being replaced by $issuer",
          relatedStatements: [s.token],
          isConflict: false,
        ));
      }

      if (blocked.contains(oldKey) && !alreadyNotified) {
        notifications.add(TrustNotification(
          subject: oldKey,
          reason: "Blocked key $oldKey is being replaced by $issuer (Benefit of the doubt given to $issuer)",
          relatedStatements: [s.token],
          isConflict: false,
        ));
      }

      if (replacements.containsKey(oldKey)) {
        final existingNewKey = replacements[oldKey];
        if (existingNewKey != issuer) {
           notifications.add(TrustNotification(
             subject: oldKey, 
             reason: "Key $oldKey replaced by both $existingNewKey and $issuer",
             relatedStatements: [s.token],
             isConflict: true,
           ));
           continue;
        }
      }
      
      replacements[oldKey] = issuer;
      if (s.revokeAt != null) {
        revokeAtConstraints[oldKey] = s.revokeAt!;
      }

      // --- BACKWARD DISCOVERY ---
      // If we trust the new key, we must also trust the old key it replaces
      // so we can discover the history of that identity.
      if (!distances.containsKey(oldKey)) {
        distances[oldKey] = dist; // Same distance as the issuer
        queue.add(oldKey);
      }
    }

    // --- STEP 3: Process TRUSTS ---
    final trustStatements = issuerStatements.where((s) => s.verb == TrustVerb.trust);
    for (var s in trustStatements) {
      final subject = s.subjectToken;
      if (decided.contains(subject)) continue;
      decided.add(subject);
      
      if (blocked.contains(subject)) {
        notifications.add(TrustNotification(
          subject: subject,
          reason: "Attempt to trust blocked key by $issuer",
          relatedStatements: [s.token],
          isConflict: true,
        ));
        continue;
      }
      
      // Resolve identity (if replaced)
      String effectiveSubject = subject;
      if (replacements.containsKey(subject)) {
        effectiveSubject = replacements[subject]!;
      }
      
      if (blocked.contains(effectiveSubject)) continue;

      // Track paths for confidence levels
      trustedBy.putIfAbsent(effectiveSubject, () => {}).add(issuer);
      
      final requiredPaths = req(dist + 1);
      if (trustedBy[effectiveSubject]!.length >= requiredPaths) {
        if (!visited.contains(effectiveSubject)) {
          visited.add(effectiveSubject);
          distances[effectiveSubject] = dist + 1;
          queue.add(effectiveSubject);
        }
        
        // Always ensure the original subject is marked as trusted if the identity is trusted.
        // This ensures backward discovery and correct notifications.
        if (effectiveSubject != subject) {
          distances[subject] = dist + 1;
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
    notifications: notifications,
    edges: edges,
  );
}
