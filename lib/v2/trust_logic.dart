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
  Map<String, List<TrustStatement>> byIssuer, {
  PathRequirement? pathRequirement,
}) {
  final Map<String, int> distances = {current.root: 0};
  final Map<String, String> replacements = Map.from(current.replacements);
  final Map<String, String> revokeAtConstraints = Map.from(current.revokeAtConstraints);
  final Set<String> blocked = {};
  final List<TrustNotification> notifications = [];
  final Map<String, List<TrustStatement>> edges = {};
  final Map<String, Set<String>> trustedBy = {};
  final Set<String> visited = {current.root};

  // --- 1. Index by Token (for revokeAt resolution) ---
  final Map<String, TrustStatement> byToken = {};
  for (var list in byIssuer.values) {
    for (var s in list) {
      byToken[s.token] = s;
    }
  }

  DateTime? resolveRevokeAt(String? revokeAtToken) {
    if (revokeAtToken == null) return null;
    return byToken[revokeAtToken]?.time ?? DateTime.fromMicrosecondsSinceEpoch(0);
  }

  int maxDegrees = 6;
  final req = pathRequirement ?? (d) => 1;

  var currentLayer = {current.root};

  while (currentLayer.isNotEmpty) {
    final int dist = distances[currentLayer.first]!;
    if (dist >= maxDegrees) break;

    // --- STAGE 1 & 2: BLOCKS & REPLACES ---
    // We loop until no more nodes are discovered via backward discovery (replaces)
    // in this layer.
    bool layerChanged;
    do {
      layerChanged = false;
      final Set<String> layerToProcess = Set.from(currentLayer);

      // 1. BLOCKS
      for (final issuer in layerToProcess) {
        var statements = byIssuer[issuer] ?? [];
        statements.sort((a, b) => b.time.compareTo(a.time));
        final decided = <String>{};
        for (var s in statements.where((s) => s.verb == TrustVerb.block)) {
          final subject = s.subjectToken;
          if (decided.contains(subject)) continue;
          decided.add(subject);

          if (distances.containsKey(subject) && distances[subject]! <= dist) {
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
      }

      // 2. REPLACES
      for (final issuer in layerToProcess) {
        var statements = byIssuer[issuer] ?? [];
        statements.sort((a, b) => b.time.compareTo(a.time));
        final decided = <String>{};
        for (var s in statements.where((s) => s.verb == TrustVerb.replace)) {
          final oldKey = s.subjectToken;
          if (decided.contains(oldKey)) continue;
          decided.add(oldKey);

          final alreadyNotified = notifications.any((n) => n.relatedStatements.contains(s.token));

          if (distances.containsKey(oldKey) && distances[oldKey]! <= dist && !alreadyNotified) {
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

          if (!distances.containsKey(oldKey)) {
            distances[oldKey] = dist;
            currentLayer.add(oldKey);
            layerChanged = true;
          }
        }
      }
    } while (layerChanged);

    // --- STAGE 3: TRUSTS ---
    final nextLayer = <String>{};
    for (final issuer in currentLayer) {
      var statements = byIssuer[issuer] ?? [];
      statements.sort((a, b) => b.time.compareTo(a.time));

      // Apply constraints discovered in STAGE 2
      if (revokeAtConstraints.containsKey(issuer)) {
        final limitTime = resolveRevokeAt(revokeAtConstraints[issuer]);
        if (limitTime != null) {
          statements = statements.where((s) => !s.time.isAfter(limitTime)).toList();
        }
      }
      edges[issuer] = statements;

      final decided = <String>{};
      for (var s in statements.where((s) => s.verb == TrustVerb.trust)) {
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
        
        String effectiveSubject = subject;
        if (replacements.containsKey(subject)) {
          effectiveSubject = replacements[subject]!;
        }
        
        if (blocked.contains(effectiveSubject)) continue;

        trustedBy.putIfAbsent(effectiveSubject, () => {}).add(issuer);
        
        final requiredPaths = req(dist + 1);
        if (trustedBy[effectiveSubject]!.length >= requiredPaths) {
          if (!visited.contains(effectiveSubject)) {
            visited.add(effectiveSubject);
            distances[effectiveSubject] = dist + 1;
            nextLayer.add(effectiveSubject);
          }
          
          if (effectiveSubject != subject) {
            distances[subject] = dist + 1;
          }
        }
      }
    }
    
    currentLayer = nextLayer;
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
