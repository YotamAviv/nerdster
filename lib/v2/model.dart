import 'package:nerdster/oneofus/trust_statement.dart';

/// Represents a notification or conflict discovered during graph construction.
class TrustNotification {
  final String subject;
  final String reason;
  final List<String> relatedStatements;
  final bool isConflict;

  TrustNotification({
    required this.subject,
    required this.reason,
    this.relatedStatements = const [],
    this.isConflict = false,
  });

  @override
  String toString() => '${isConflict ? "Conflict" : "Notification"}($subject): $reason';
}

/// The immutable result of the Trust Algorithm.
class TrustGraph {
  final String root;
  final Map<String, int> distances; // Token -> Distance
  final List<String> orderedKeys; // Tokens in discovery order (BFS)
  final Map<String, String> replacements; // OldToken -> NewToken
  final Map<String, String> replacementConstraints; // Token -> RevokeAtToken (Time constraint)
  final Set<String> blocked; // Tokens blocked by the graph
  final List<TrustNotification> notifications; // Structured notifications and conflicts
  final Map<String, List<TrustStatement>> edges; // Adjacency list: Issuer -> List<TrustStatement> (Valid statements)

  TrustGraph({
    required this.root,
    this.distances = const {},
    this.orderedKeys = const [],
    this.replacements = const {},
    this.replacementConstraints = const {},
    this.blocked = const {},
    this.notifications = const [],
    this.edges = const {},
  });

  bool isTrusted(String token) => distances.containsKey(token);
  
  List<TrustNotification> get conflicts => notifications.where((n) => n.isConflict).toList();

  /// Returns the active identity token for a given key.
  /// If the key is replaced, returns the replacement (recursively).
  String resolveIdentity(String token) {
    if (replacements.containsKey(token)) {
      return resolveIdentity(replacements[token]!);
    }
    return token;
  }

  /// Groups all trusted tokens by their canonical identity.
  Map<String, List<String>> getEquivalenceGroups() {
    final Map<String, List<String>> groups = {};
    for (final token in distances.keys) {
      final canonical = resolveIdentity(token);
      groups.putIfAbsent(canonical, () => []).add(token);
    }
    // Sort tokens within each group by distance (canonical first usually)
    for (final group in groups.values) {
      group.sort((a, b) => distances[a]!.compareTo(distances[b]!));
    }
    return groups;
  }

  /// Returns all shortest paths from root to [target].
  List<List<String>> getPathsTo(String target) {
    if (target == root) return [[root]];
    if (!distances.containsKey(target)) return [];

    final targetDist = distances[target]!;
    final List<List<String>> results = [];

    // Find all issuers that trust this target at distance targetDist - 1
    // We look at all edges in the graph.
    for (final issuer in edges.keys) {
      if (distances[issuer] == targetDist - 1) {
        for (final s in edges[issuer]!) {
          if (s.subjectToken == target) {
            final subPaths = getPathsTo(issuer);
            for (final p in subPaths) {
              results.add([...p, target]);
            }
          }
        }
      }
    }
    return results;
  }
}

