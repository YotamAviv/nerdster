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
  final List<String> orderedKeys = [current.root];
  final Map<String, String> replacements = Map.from(current.replacements);
  final Map<String, String> replacementConstraints = Map.from(current.replacementConstraints);
  final Set<String> blocked = {};
  final List<TrustNotification> notifications = [];
  final Map<String, List<TrustStatement>> edges = {};
  final Map<String, Set<String>> trustedBy = {};
  final Set<String> visited = {current.root};

  // --- 1. Index by Token (for replacement limit resolution) ---
  final Map<String, TrustStatement> byToken = {};
  for (var list in byIssuer.values) {
    for (var s in list) {
      byToken[s.token] = s;
    }
  }

  DateTime? resolveReplacementLimit(String? limitToken) {
    if (limitToken == null) return null;
    return byToken[limitToken]?.time ?? DateTime.fromMicrosecondsSinceEpoch(0);
  }

  int maxDegrees = 6;
  final req = pathRequirement ?? (d) => 1;

  var currentLayer = {current.root};

  for (int dist = 0; dist < maxDegrees && currentLayer.isNotEmpty; dist++) {
    final nextLayer = <String>{};

    // --- STAGE 1: BLOCKS ---
    // Blocks are processed first for the entire layer.
    for (final issuer in currentLayer) {
      var statements = byIssuer[issuer] ?? [];
      statements.sort((a, b) => b.time.compareTo(a.time));
      final decided = <String>{};
      
      // Process Blocks
      for (var s in statements.where((s) => s.verb == TrustVerb.block)) {
        final subject = s.subjectToken;
        if (decided.contains(subject)) continue;
        decided.add(subject);

        if (subject == current.root) {
          notifications.add(TrustNotification(
            subject: subject,
            reason: "Attempt to block your key.",
            relatedStatements: [s.token],
            isConflict: true,
          ));
          continue;
        }

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

    // --- STAGE 2: REPLACES & TRUSTS ---
    // These discover nodes for the NEXT layer.
    
    // 1. First pass: Process all REPLACES in this layer to establish identity links and constraints.
    for (final issuer in currentLayer) {
      var statements = byIssuer[issuer] ?? [];
      statements.sort((a, b) => b.time.compareTo(a.time));

      // Apply constraints discovered in previous layers
      if (replacementConstraints.containsKey(issuer)) {
        final limitTime = resolveReplacementLimit(replacementConstraints[issuer]);
        if (limitTime != null) {
          statements = statements.where((s) => !s.time.isAfter(limitTime)).toList();
        }
      }
      edges[issuer] = statements;

      final decided = <String>{};
      for (var s in statements.where((s) => s.verb == TrustVerb.replace)) {
        final oldKey = s.subjectToken;
        if (decided.contains(oldKey)) continue;
        decided.add(oldKey);

        if (oldKey == current.root) {
          notifications.add(TrustNotification(
            subject: oldKey,
            reason: "Attempt to replace your key.",
            relatedStatements: [s.token],
            isConflict: true,
          ));
          continue;
        }

        if (blocked.contains(oldKey)) {
          notifications.add(TrustNotification(
            subject: oldKey,
            reason: "Blocked key $oldKey is being replaced by $issuer",
            relatedStatements: [s.token],
            isConflict: false,
          ));
        }

        if (distances.containsKey(oldKey) && distances[oldKey]! < dist) {
          if (!replacements.containsKey(oldKey)) {
            replacements[oldKey] = issuer;
          }
          notifications.add(TrustNotification(
            subject: oldKey,
            reason: "Trusted key $oldKey is being replaced by $issuer (Replacement constraint ignored due to distance)",
            relatedStatements: [s.token],
            isConflict: false,
          ));
          continue;
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

        if (distances.containsKey(oldKey)) {
          notifications.add(TrustNotification(
            subject: oldKey,
            reason: "Trusted key $oldKey is being replaced by $issuer",
            relatedStatements: [s.token],
            isConflict: false,
          ));
        }

        replacements[oldKey] = issuer;
        if (s.revokeAt != null) {
          replacementConstraints[oldKey] = s.revokeAt!;
        }

        if (!visited.contains(oldKey)) {
          visited.add(oldKey);
          distances[oldKey] = dist + 1;
          orderedKeys.add(oldKey);
          nextLayer.add(oldKey);
        }
      }
    }

    // 2. Second pass: Process all TRUSTS in this layer, now that replacements are known.
    for (final issuer in currentLayer) {
      var statements = edges[issuer] ?? [];
      
      // Re-filter statements if a replacement was found in THIS layer
      if (replacementConstraints.containsKey(issuer)) {
        final limitTime = resolveReplacementLimit(replacementConstraints[issuer]);
        if (limitTime != null) {
          statements = statements.where((s) => !s.time.isAfter(limitTime)).toList();
        }
      }

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
          notifications.add(TrustNotification(
            subject: subject,
            reason: "You trust a non-canonical key directly (replaced by $effectiveSubject)",
            relatedStatements: [s.token],
            isConflict: false,
          ));
        }

        if (blocked.contains(effectiveSubject)) continue;

        trustedBy.putIfAbsent(effectiveSubject, () => {}).add(issuer);

        final requiredPaths = req(dist + 1);
        if (trustedBy[effectiveSubject]!.length >= requiredPaths) {
          if (!visited.contains(effectiveSubject)) {
            visited.add(effectiveSubject);
            distances[effectiveSubject] = dist + 1;
            orderedKeys.add(effectiveSubject);
            nextLayer.add(effectiveSubject);
          }
          if (effectiveSubject != subject) {
            distances[subject] = dist + 1;
            if (!visited.contains(subject)) {
              visited.add(subject);
              orderedKeys.add(subject);
              nextLayer.add(subject);
            }
          }
        }
      }
    }
    
    currentLayer = nextLayer;
  }
  
  return TrustGraph(
    root: current.root,
    distances: distances,
    orderedKeys: orderedKeys,
    replacements: replacements,
    replacementConstraints: replacementConstraints,
    blocked: blocked,
    notifications: notifications,
    edges: edges,
  );
}
