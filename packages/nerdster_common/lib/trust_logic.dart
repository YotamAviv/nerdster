import 'dart:collection';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster_common/trust_graph.dart';

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

    for (int i = 1; i < path.length - 1; i++) {
      excludedNodes.add(path[i]);
    }
  }
  return paths;
}

List<IdentityKey>? _findShortestPath(IdentityKey start, IdentityKey end,
    Map<IdentityKey, Set<IdentityKey>> graph, Set<IdentityKey> excluded) {
  final Queue<List<IdentityKey>> queue = Queue<List<IdentityKey>>();
  queue.add([start]);
  final Set<IdentityKey> visited = {start, ...excluded};

  while (queue.isNotEmpty) {
    final List<IdentityKey> path = queue.removeFirst();
    final IdentityKey node = path.last;

    if (node == end) return path;

    final Set<IdentityKey>? neighbors = graph[node];
    if (neighbors != null) {
      for (final IdentityKey neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          final List<IdentityKey> newPath = List<IdentityKey>.from(path)..add(neighbor);
          queue.add(newPath);
        }
      }
    }
  }
  return null;
}

TrustGraph reduceTrustGraph(
  TrustGraph current,
  Map<IdentityKey, List<TrustStatement>> byIssuer, {
  PathRequirement? pathRequirement,
  int maxDegrees = 6,
}) {
  Statement.validateOrderTypess(byIssuer.values);

  final Map<IdentityKey, int> distances = {current.pov: 0};
  final List<IdentityKey> orderedKeys = [current.pov];
  final Map<IdentityKey, IdentityKey> equivalent2canonical = {};
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
    while (equivalent2canonical.containsKey(currentKey)) {
      currentKey = equivalent2canonical[currentKey]!;
      if (seen.contains(currentKey)) break;
      seen.add(currentKey);
    }
    return currentKey;
  }

  final PathRequirement req = pathRequirement ?? (d) => 1;

  Set<IdentityKey> currentLayer = {current.pov};

  for (int dist = 0; dist < maxDegrees && currentLayer.isNotEmpty; dist++) {
    final Set<IdentityKey> nextLayer = <IdentityKey>{};

    for (final IdentityKey issuer in currentLayer) {
      List<TrustStatement> statements = byIssuer[issuer] ?? [];
      final Set<IdentityKey> decided = <IdentityKey>{};

      for (final TrustStatement s
          in statements.where((TrustStatement s) => s.verb == TrustVerb.block)) {
        final IdentityKey subject = s.subjectAsIdentity;
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

    for (final IdentityKey issuer in currentLayer) {
      List<TrustStatement> statements =
          equivalent2canonical.containsKey(issuer) ? [] : (byIssuer[issuer] ?? []);

      edges[issuer] = statements.where((TrustStatement s) {
        if (s.verb == TrustVerb.clear) return false;
        if (s.verb != TrustVerb.replace && s.verb != TrustVerb.delegate && s.revokeAt != null)
          return false;
        return true;
      }).toList();

      final Set<IdentityKey> decided = <IdentityKey>{};
      for (final TrustStatement s
          in statements.where((TrustStatement s) => s.verb == TrustVerb.replace)) {
        final IdentityKey oldKey = s.subjectAsIdentity;
        if (decided.contains(oldKey)) continue;
        decided.add(oldKey);
        assert(s.revokeAt == kSinceAlways || s.revokeAt == null,
            'replace with revokeAt other than <since always> is not supported: ${s.revokeAt}');

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
          continue;
        }

        if (distances.containsKey(oldKey) && distances[oldKey]! < dist) {
          if (!equivalent2canonical.containsKey(oldKey)) {
            equivalent2canonical[oldKey] = issuer;
          }
          notifications.add(TrustNotification(
            reason:
                "Trusted key ${oldKey.value} is being replaced by ${issuer.value} (Replacement constraint ignored due to distance)",
            rejectedStatement: s,
            isConflict: false,
          ));
          continue;
        }

        if (equivalent2canonical.containsKey(oldKey)) {
          final IdentityKey? existingNewKey = equivalent2canonical[oldKey];
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

        equivalent2canonical[oldKey] = issuer;
        graphForPathfinding.putIfAbsent(issuer, () => {}).add(oldKey);

        if (!visited.contains(oldKey)) {
          visited.add(oldKey);
          distances[oldKey] = dist + 1;
          orderedKeys.add(oldKey);
          nextLayer.add(oldKey);
        }
      }
    }

    for (final IdentityKey issuer in currentLayer) {
      final List<TrustStatement> statements =
          equivalent2canonical.containsKey(issuer) ? [] : (edges[issuer] ?? []);

      final Set<IdentityKey> decided = <IdentityKey>{};
      for (final TrustStatement s
          in statements.where((TrustStatement s) => s.verb == TrustVerb.trust)) {
        final IdentityKey subject = s.subjectAsIdentity;
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

        if (blocked.contains(effectiveSubject)) continue;

        trustedBy.putIfAbsent(effectiveSubject, () => {}).add(issuer);

        final int requiredPaths = req(dist + 1);

        for (final IdentityKey i in trustedBy[effectiveSubject]!) {
          graphForPathfinding.putIfAbsent(i, () => {}).add(effectiveSubject);
        }

        final List<List<IdentityKey>> foundPaths = _findNodeDisjointPaths(
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

  final Map<String, TrustNotification> uniqueNotifications = {};
  for (final TrustNotification n in notifications) {
    final String key = "${n.subject.value}:${n.reason}";
    if (!uniqueNotifications.containsKey(key)) {
      uniqueNotifications[key] = n;
    }
  }

  return TrustGraph(
    pov: current.pov,
    distances: distances,
    orderedKeys: orderedKeys,
    equivalent2canonical: equivalent2canonical,
    blocked: blocked,
    paths: paths,
    notifications: uniqueNotifications.values.toList(),
    edges: edges,
  );
}
