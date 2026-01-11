import 'dart:collection';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/model.dart';

final Map<String, String> pathsReq = {
  'standard': '1-1-2',
  'strict': '1-2-2-3',
  'permissive': '1',
};

typedef PathRequirement = int Function(int distance);

List<List<IdentityKey>> _findNodeDisjointPaths(
    IdentityKey root, IdentityKey target, Map<IdentityKey, Set<IdentityKey>> graph, int limit) {
  final List<List<IdentityKey>> paths = [];
  final Set<IdentityKey> excludedNodes = {};
  final Set<String> usedPathStrings = {};

  while (paths.length < limit) {
    final path = _findShortestPath(root, target, graph, excludedNodes);
    if (path == null) break;

    final pathString = path.map((k) => k.value).join('->');
    if (usedPathStrings.contains(pathString)) break;

    paths.add(path);
    usedPathStrings.add(pathString);

    // Exclude intermediate nodes to ensure node-disjointness
    for (int i = 1; i < path.length - 1; i++) {
      excludedNodes.add(path[i]);
    }
  }
  return paths;
}

List<IdentityKey>? _findShortestPath(IdentityKey start, IdentityKey end,
    Map<IdentityKey, Set<IdentityKey>> graph, Set<IdentityKey> excluded) {
  final queue = Queue<List<IdentityKey>>();
  queue.add([start]);
  final visited = {start, ...excluded};

  while (queue.isNotEmpty) {
    final path = queue.removeFirst();
    final node = path.last;

    if (node == end) return path;

    final neighbors = graph[node];
    if (neighbors != null) {
      for (final neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          final newPath = List<IdentityKey>.from(path)..add(neighbor);
          queue.add(newPath);
        }
      }
    }
  }
  return null;
}

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
  Map<IdentityKey, List<TrustStatement>> byIssuer, {
  PathRequirement? pathRequirement,
  int maxDegrees = 6,
}) {
  Statement.validateOrderTypess(byIssuer.values);

  final Map<IdentityKey, int> distances = {current.pov: 0};
  final List<IdentityKey> orderedKeys = [current.pov];
  final Map<IdentityKey, IdentityKey> replacements = {};
  final Map<IdentityKey, String> replacementConstraints = {};
  final Set<IdentityKey> blocked = {};
  final Map<IdentityKey, List<List<IdentityKey>>> paths = {};
  final List<TrustNotification> notifications = [];
  final Map<IdentityKey, List<TrustStatement>> edges = {};
  final Map<IdentityKey, Set<IdentityKey>> trustedBy = {};
  final Map<IdentityKey, Set<IdentityKey>> graphForPathfinding = {};
  final Set<IdentityKey> visited = {current.pov};

  IdentityKey resolveCanonical(IdentityKey token) {
    IdentityKey currentKey = token;
    final Set<IdentityKey> seen = {token};
    while (replacements.containsKey(currentKey)) {
      currentKey = replacements[currentKey]!;
      if (seen.contains(currentKey)) break; // Cycle detected
      seen.add(currentKey);
    }
    return currentKey;
  }

  // --- 1. Index by Token (for replacement limit resolution) ---
  final Map<String, TrustStatement> byToken = {};
  for (var list in byIssuer.values) {
    for (var s in list) {
      byToken[s.token] = s;
    }
  }

  DateTime? resolveReplacementLimit(String? limitToken, IdentityKey expectedIssuer) {
    if (limitToken == null) return null;
    if (limitToken == kSinceAlways) return DateTime.fromMicrosecondsSinceEpoch(0);
    final s = byToken[limitToken];
    if (s != null && s.iKey == expectedIssuer) {
      return s.time;
    }
    return DateTime.fromMicrosecondsSinceEpoch(0);
  }

  final req = pathRequirement ?? (d) => 1;

  var currentLayer = {current.pov};

  for (int dist = 0; dist < maxDegrees && currentLayer.isNotEmpty; dist++) {
    final nextLayer = <IdentityKey>{};

    // --- STAGE 1: BLOCKS ---
    // Blocks are processed first for the entire layer.
    for (final issuer in currentLayer) {
      var statements = byIssuer[issuer] ?? [];
      final decided = <IdentityKey>{};

      // Process Blocks
      for (var s in statements.where((s) => s.verb == TrustVerb.block)) {
        final subject = s.subjectAsIdentity;
        if (decided.contains(subject)) continue;
        decided.add(subject);

        if (subject == current.pov) {
          notifications.add(TrustNotification(
            reason: "Attempt to block your key.",
            rejectedStatement: s,
            isConflict: true,
          ));
          continue;
        }

        if (distances.containsKey(subject) && distances[subject]! <= dist) {
          notifications.add(TrustNotification(
            reason: "Attempt to block trusted key by ${issuer.value}",
            rejectedStatement: s,
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

      // Apply constraints discovered in previous layers
      if (replacementConstraints.containsKey(issuer)) {
        final limitTime = resolveReplacementLimit(replacementConstraints[issuer], issuer);
        if (limitTime != null) {
          statements = statements.where((s) => !s.time.isAfter(limitTime)).toList();
        }
      }

      // Filter out revocations and clear statements from the resulting edges.
      // These are used by the algorithm to "decide" a subject (preventing older statements from applying),
      // but they shouldn't be considered "edges" in the final graph.
      edges[issuer] = statements.where((s) {
        if (s.verb == TrustVerb.clear) return false;
        // We keep replace and delegate statements with revokeAt because they are revocations.
        if (s.verb != TrustVerb.replace && s.verb != TrustVerb.delegate && s.revokeAt != null)
          return false;
        return true;
      }).toList();

      final decided = <IdentityKey>{};
      for (var s in statements.where((s) => s.verb == TrustVerb.replace)) {
        final oldKey = s.subjectAsIdentity;
        if (decided.contains(oldKey)) continue;
        decided.add(oldKey);

        if (oldKey == current.pov) {
          notifications.add(TrustNotification(
            reason: "Attempt to replace your key.",
            rejectedStatement: s,
            isConflict: true,
          ));
          continue;
        }

        if (blocked.contains(oldKey)) {
          notifications.add(TrustNotification(
            reason: "Blocked key ${oldKey.value} is being replaced by ${issuer.value}",
            rejectedStatement: s,
            isConflict: false,
          ));
          // Do not add blocked keys to the pathfinding graph
          continue;
        }

        if (distances.containsKey(oldKey) && distances[oldKey]! < dist) {
          if (!replacements.containsKey(oldKey)) {
            replacements[oldKey] = issuer;
          }
          notifications.add(TrustNotification(
            reason:
                "Trusted key ${oldKey.value} is being replaced by ${issuer.value} (Replacement constraint ignored due to distance)",
            rejectedStatement: s,
            isConflict: false,
          ));
          continue;
        }

        if (replacements.containsKey(oldKey)) {
          final existingNewKey = replacements[oldKey];
          if (existingNewKey != issuer) {
            notifications.add(TrustNotification(
              reason:
                  "Key ${oldKey.value} replaced by both ${existingNewKey!.value} and ${issuer.value}",
              rejectedStatement: s,
              isConflict: true,
            ));
            continue;
          }
        }

        if (distances.containsKey(oldKey)) {
          notifications.add(TrustNotification(
            reason: "Trusted key ${oldKey.value} is being replaced by ${issuer.value}",
            rejectedStatement: s,
            isConflict: false,
          ));
        }

        replacements[oldKey] = issuer;
        graphForPathfinding.putIfAbsent(issuer, () => {}).add(oldKey);

        // Default to kSinceAlways if revokeAt is missing, as per docs.
        replacementConstraints[oldKey] = s.revokeAt ?? kSinceAlways;

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
        final limitTime = resolveReplacementLimit(replacementConstraints[issuer], issuer);
        if (limitTime != null) {
          statements = statements.where((s) => !s.time.isAfter(limitTime)).toList();
        }
      }

      final decided = <IdentityKey>{};
      for (var s in statements.where((s) => s.verb == TrustVerb.trust)) {
        final subject = s.subjectAsIdentity;
        if (decided.contains(subject)) continue;
        decided.add(subject);

        if (blocked.contains(subject)) {
          notifications.add(TrustNotification(
            reason: "Attempt to trust blocked key by ${issuer.value}",
            rejectedStatement: s,
            isConflict: true,
          ));
          continue;
        }

        IdentityKey effectiveSubject = resolveCanonical(subject);
        // Non-canonical trusts by the POV are caught by the replacement logic as 'Trusted key ... is being replaced'.
        // Non-canonical trusts by others are ignored to reduce noise.

        if (blocked.contains(effectiveSubject)) continue;

        trustedBy.putIfAbsent(effectiveSubject, () => {}).add(issuer);

        final requiredPaths = req(dist + 1);

        // Temporarily add all potential edges for this subject to the pathfinding graph
        for (final i in trustedBy[effectiveSubject]!) {
          graphForPathfinding.putIfAbsent(i, () => {}).add(effectiveSubject);
        }

        final foundPaths = _findNodeDisjointPaths(
            current.pov, effectiveSubject, graphForPathfinding, requiredPaths);
        if (foundPaths.length >= requiredPaths) {
          paths[effectiveSubject] = foundPaths;
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

  // Deduplicate notifications
  final Map<String, TrustNotification> uniqueNotifications = {};
  for (final n in notifications) {
    // IdentityKey interpolation works
    final key = "${n.subject.value}:${n.reason}";
    if (!uniqueNotifications.containsKey(key)) {
      uniqueNotifications[key] = n;
    }
  }

  return TrustGraph(
    pov: current.pov,
    distances: distances,
    orderedKeys: orderedKeys,
    replacements: replacements,
    replacementConstraints: replacementConstraints,
    blocked: blocked,
    paths: paths,
    notifications: uniqueNotifications.values.toList(),
    edges: edges,
  );
}
