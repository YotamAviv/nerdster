import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/trust_statement.dart';

class TrustNotification {
  final String reason;
  final TrustStatement rejectedStatement;
  final bool isConflict;

  TrustNotification({
    required this.reason,
    required this.rejectedStatement,
    this.isConflict = false,
  });

  IdentityKey get subject => IdentityKey(rejectedStatement.subjectToken);
  IdentityKey get issuer => IdentityKey(getToken(rejectedStatement.i));

  @override
  String toString() => '${isConflict ? "Conflict" : "Notification"}(${subject.value}): $reason';
}

class TrustGraph {
  final IdentityKey pov;
  final Map<IdentityKey, int> distances;
  final List<IdentityKey> orderedKeys;
  final Map<IdentityKey, IdentityKey> equivalent2canonical;
  final Set<IdentityKey> blocked;
  final Map<IdentityKey, List<List<IdentityKey>>> paths;
  final List<TrustNotification> notifications;
  final Map<IdentityKey, List<TrustStatement>> edges;

  TrustGraph({
    required this.pov,
    this.distances = const {},
    List<IdentityKey> orderedKeys = const [],
    this.equivalent2canonical = const {},
    this.blocked = const {},
    Map<IdentityKey, List<List<IdentityKey>>> paths = const {},
    List<TrustNotification> notifications = const [],
    Map<IdentityKey, List<TrustStatement>> edges = const {},
  })  : orderedKeys = List.unmodifiable(orderedKeys),
        paths = Map.unmodifiable(paths.map((k, v) =>
            MapEntry(k, List<List<IdentityKey>>.unmodifiable(
                (v as List).map<List<IdentityKey>>((dynamic p) =>
                    List<IdentityKey>.unmodifiable((p as List).cast<IdentityKey>())))))),
        notifications = List.unmodifiable(notifications),
        edges = Map.unmodifiable(edges.map((k, v) =>
            MapEntry(k, List<TrustStatement>.unmodifiable((v as List).cast<TrustStatement>()))));

  bool isTrusted(IdentityKey token) => distances.containsKey(token);

  List<TrustNotification> get conflicts => notifications.where((n) => n.isConflict).toList();

  IdentityKey resolveIdentity(IdentityKey token) {
    IdentityKey current = token;
    final Set<IdentityKey> seen = {token};
    while (equivalent2canonical.containsKey(current)) {
      current = equivalent2canonical[current]!;
      if (seen.contains(current)) break;
      seen.add(current);
    }
    return current;
  }

  List<IdentityKey> getEquivalenceGroup(IdentityKey canonical) {
    return distances.keys.where((token) => resolveIdentity(token) == canonical).toList()
      ..sort((a, b) => distances[a]!.compareTo(distances[b]!));
  }

  Map<IdentityKey, List<IdentityKey>> getEquivalenceGroups() {
    final Map<IdentityKey, List<IdentityKey>> groups = {};
    for (final IdentityKey token in distances.keys) {
      final IdentityKey canonical = resolveIdentity(token);
      groups.putIfAbsent(canonical, () => []).add(token);
    }
    for (final List<IdentityKey> group in groups.values) {
      group.sort((a, b) => distances[a]!.compareTo(distances[b]!));
    }
    return groups;
  }

  List<List<IdentityKey>> getPathsTo(IdentityKey target) {
    if (target == pov) return [[pov]];
    if (!distances.containsKey(target)) return [];

    final targetDist = distances[target]!;
    final List<List<IdentityKey>> results = [];

    for (final IdentityKey issuer in edges.keys) {
      if ((distances[issuer] ?? -1) == targetDist - 1) {
        for (final TrustStatement s in edges[issuer]!) {
          if (s.verb == TrustVerb.trust && s.subjectAsIdentity == target) {
            final List<List<IdentityKey>> subPaths = getPathsTo(issuer);
            for (final List<IdentityKey> p in subPaths) {
              results.add([...p, target]);
            }
          }
        }
      }
    }
    return results;
  }

  TrustGraph copyWith({
    IdentityKey? pov,
    Map<IdentityKey, int>? distances,
    List<IdentityKey>? orderedKeys,
    Map<IdentityKey, IdentityKey>? equivalent2canonical,
    Set<IdentityKey>? blocked,
    Map<IdentityKey, List<List<IdentityKey>>>? paths,
    List<TrustNotification>? notifications,
    Map<IdentityKey, List<TrustStatement>>? edges,
  }) {
    return TrustGraph(
      pov: pov ?? this.pov,
      distances: distances ?? this.distances,
      orderedKeys: orderedKeys ?? this.orderedKeys,
      equivalent2canonical: equivalent2canonical ?? this.equivalent2canonical,
      blocked: blocked ?? this.blocked,
      paths: paths ?? this.paths,
      notifications: notifications ?? this.notifications,
      edges: edges ?? this.edges,
    );
  }
}
