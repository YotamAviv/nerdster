import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/v2/labeler.dart';

enum V2SortMode {
  recentActivity,
  netLikes,
  mostComments,
}

enum V2FilterMode {
  myDisses,
  povDisses,
  ignoreDisses,
}

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
  final Map<String, List<List<String>>> paths; // Target -> List of node-disjoint paths from root
  /// Notifications: key rotation issues, attempt to claim a delegate that's already been claimed.
  final List<TrustNotification> notifications;
  final Map<String, List<TrustStatement>> edges; // Adjacency list: Issuer -> List<TrustStatement> (Valid statements)

  TrustGraph({
    required this.root,
    this.distances = const {},
    this.orderedKeys = const [],
    this.replacements = const {},
    this.replacementConstraints = const {},
    this.blocked = const {},
    this.paths = const {},
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

  /// Returns all trusted tokens that belong to the given canonical identity.
  List<String> getEquivalenceGroup(String canonical) {
    return distances.keys.where((token) => resolveIdentity(token) == canonical).toList()
      ..sort((a, b) => distances[a]!.compareTo(distances[b]!));
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

/// The result of building a Follow Network for a specific context.
class FollowNetwork {
  final String fcontext;
  final List<String> identities; // Canonical identity tokens in discovery order
  final String rootIdentity; // The identity from whose POV this network was built
  final Map<String, List<String>> paths; // Identity -> Path from root
  /// Notifications: attempt to claim a delegate that's already been claimed.
  final List<TrustNotification> notifications;
  final Map<String, List<ContentStatement>> edges; // IssuerIdentity -> List of accepted follow/block statements

  FollowNetwork({
    required this.fcontext,
    this.identities = const [],
    required this.rootIdentity,
    this.paths = const {},
    this.notifications = const [],
    this.edges = const {},
  });

  bool contains(String identity) => identities.contains(identity);
}

/// Aggregated data for a single subject (or equivalence group).
class SubjectAggregation {
  final String canonicalToken;
  final dynamic subject; // The subject JSON or token
  final List<ContentStatement> statements;
  final Set<String> tags;
  final int likes;
  final int dislikes;
  final DateTime lastActivity;
  final Set<String> related; // Canonical tokens of related subjects
  final List<ContentStatement> myDelegateStatements;
  final DateTime? userDismissalTimestamp;
  final DateTime? povDismissalTimestamp;
  final bool isCensored;
  final bool isDismissed; // Dismissed by the POV (lastActivity <= povDismissalTimestamp)
  final bool isRated; // Rated by the POV

  SubjectAggregation({
    required this.canonicalToken,
    this.subject,
    this.statements = const [],
    this.tags = const {},
    this.likes = 0,
    this.dislikes = 0,
    required this.lastActivity,
    this.related = const {},
    this.myDelegateStatements = const [],
    this.userDismissalTimestamp,
    this.povDismissalTimestamp,
    this.isCensored = false,
    this.isDismissed = false,
    this.isRated = false,
  });
}

/// The result of aggregating content for a Follow Network.
class ContentAggregation {
  final List<ContentStatement> statements;
  final Set<String> censored;
  final Map<String, String> equivalence; // SubjectToken -> CanonicalSubjectToken
  final Map<String, Set<String>> related; // SubjectToken -> Set of RelatedSubjectTokens
  final Map<String, String> tagEquivalence; // Tag -> Canonical Tag
  final List<String> mostTags; // Tags ordered by frequency
  final Map<String, SubjectAggregation> subjects; // CanonicalToken -> Aggregation

  ContentAggregation({
    this.statements = const [],
    this.censored = const {},
    this.equivalence = const {},
    this.related = const {},
    this.tagEquivalence = const {},
    this.mostTags = const [],
    this.subjects = const {},
  });
}

/// A complete snapshot of the feed data, ready for display.
class V2FeedModel {
  final TrustGraph trustGraph;
  final FollowNetwork followNetwork;
  final V2Labeler labeler;
  final ContentAggregation aggregation;
  final String rootToken;
  final String fcontext;
  final V2SortMode sortMode;
  final V2FilterMode filterMode;
  final String? tagFilter;
  final bool enableCensorship;
  final List<String> availableContexts;
  final Set<String> activeContexts;

  V2FeedModel({
    required this.trustGraph,
    required this.followNetwork,
    required this.labeler,
    required this.aggregation,
    required this.rootToken,
    required this.fcontext,
    required this.sortMode,
    required this.filterMode,
    this.tagFilter,
    required this.enableCensorship,
    this.availableContexts = const [],
    this.activeContexts = const {},
  });
}

