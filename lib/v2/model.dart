import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/util.dart'; // For getToken
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/source_error.dart';
import 'package:nerdster/v2/delegates.dart';

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
  final String reason;
  final Statement rejectedStatement; // TODO: TrustStatement!
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

/// The immutable result of the Trust Algorithm.
class TrustGraph {
  final IdentityKey pov;
  final Map<IdentityKey, int> distances; // Token -> Distance
  final List<IdentityKey> orderedKeys; // Tokens in discovery order (BFS)
  final Map<IdentityKey, IdentityKey> replacements; // OldToken -> NewToken
  final Map<IdentityKey, String> replacementConstraints; // Token -> RevokeAtToken (Time constraint works on Token string)
  final Set<IdentityKey> blocked; // Tokens blocked by the graph
  final Map<IdentityKey, List<List<IdentityKey>>> paths; // Target -> List of node-disjoint paths from pov
  /// Notifications: key rotation issues, attempt to claim a delegate that's already been claimed.
  final List<TrustNotification> notifications;
  final Map<IdentityKey, List<TrustStatement>>
      edges; // Adjacency list: Issuer -> List<TrustStatement> (Valid statements)

  TrustGraph({
    required this.pov,
    this.distances = const {},
    this.orderedKeys = const [],
    this.replacements = const {},
    this.replacementConstraints = const {},
    this.blocked = const {},
    this.paths = const {},
    this.notifications = const [],
    this.edges = const {},
  });

  bool isTrusted(IdentityKey token) => distances.containsKey(token);

  List<TrustNotification> get conflicts => notifications.where((n) => n.isConflict).toList();

  TrustGraph copyWith({
    IdentityKey? pov,
    Map<IdentityKey, int>? distances,
    List<IdentityKey>? orderedKeys,
    Map<IdentityKey, IdentityKey>? replacements,
    Map<IdentityKey, String>? replacementConstraints,
    Set<IdentityKey>? blocked,
    Map<IdentityKey, List<List<IdentityKey>>>? paths,
    List<TrustNotification>? notifications,
    Map<IdentityKey, List<TrustStatement>>? edges,
  }) {
    return TrustGraph(
      pov: pov ?? this.pov,
      distances: distances ?? this.distances,
      orderedKeys: orderedKeys ?? this.orderedKeys,
      replacements: replacements ?? this.replacements,
      replacementConstraints: replacementConstraints ?? this.replacementConstraints,
      blocked: blocked ?? this.blocked,
      paths: paths ?? this.paths,
      notifications: notifications ?? this.notifications,
      edges: edges ?? this.edges,
    );
  }

  /// Returns the active identity token for a given key.
  /// If the key is replaced, returns the replacement (recursively).
  IdentityKey resolveIdentity(IdentityKey token) {
    IdentityKey current = token;
    final Set<IdentityKey> seen = {token};
    while (replacements.containsKey(current)) {
      current = replacements[current]!;
      if (seen.contains(current)) break;
      seen.add(current);
    }
    return current;
  }

  /// Groups all trusted tokens by their canonical identity.
  Map<IdentityKey, List<IdentityKey>> getEquivalenceGroups() {
    final Map<IdentityKey, List<IdentityKey>> groups = {};
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
  List<IdentityKey> getEquivalenceGroup(IdentityKey canonical) {
    return distances.keys.where((token) => resolveIdentity(token) == canonical).toList()
      ..sort((a, b) => distances[a]!.compareTo(distances[b]!));
  }

  /// Returns all shortest paths from pov to [target].
  List<List<IdentityKey>> getPathsTo(IdentityKey target) {
    if (target == pov)
      return [
        [pov]
      ];
    if (!distances.containsKey(target)) return [];

    final targetDist = distances[target]!;
    final List<List<IdentityKey>> results = [];

    // Find all issuers that trust this target at distance targetDist - 1
    // We look at all edges in the graph.
    for (final issuer in edges.keys) {
      if ((distances[issuer] ?? -1) == targetDist - 1) {
        for (final s in edges[issuer]!) {
          // Only trust/replace edges constitute a path in the identity graph.
          if (s.verb == TrustVerb.trust && s.subjectAsIdentity == target) {
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
  final IdentityKey povIdentity; // The identity from whose POV this network was built
  final List<IdentityKey> identities; // Canonical identity tokens in discovery order
  final Map<IdentityKey, List<IdentityKey>> paths; // Identity -> Path from pov
  /// Notifications: attempt to claim a delegate that's already been claimed.
  final List<TrustNotification> notifications;
  final Map<IdentityKey, List<ContentStatement>>
      edges; // IssuerIdentity -> List of accepted follow/block statements

  FollowNetwork({
    required this.fcontext,
    required this.povIdentity,
    this.identities = const [],
    this.paths = const {},
    this.notifications = const [],
    this.edges = const {},
  });

  bool contains(IdentityKey identity) => identities.contains(identity);
}

/// Aggregated data for a single subject (or equivalence group).
class SubjectAggregation {
  // A complete proper Json subject
  // must have "contentType" which must be a ContentType name (see: enum ContentType)
  // and all of those have a "title" field.
  final Json subject;
  final List<ContentStatement> statements; // Who needs all statements?
  final Set<String> tags;
  final int likes;
  final int dislikes;
  final DateTime lastActivity;
  final Set<ContentKey> related; // Canonical tokens of related subjects
  final List<ContentStatement> myDelegateStatements;
  final List<ContentStatement> povStatements;

  final bool isCensored;
  // TODO: Ensure that canonicalToken is accurate
  final ContentKey canonicalToken;

  SubjectAggregation({
    required this.subject,
    ContentKey? canonicalTokenIn,
    this.statements = const [],
    this.tags = const {},
    this.likes = 0,
    this.dislikes = 0,
    required this.lastActivity,
    this.related = const {},
    this.myDelegateStatements = const [],
    this.povStatements = const [],
    this.isCensored = false,
  }) : canonicalToken = canonicalTokenIn ?? ContentKey(getToken(subject)) {
    // FAILS: TODO: DOC and make sure: assert(canonicalToken == null || canonicalToken == getToken(subject));
    assert(Statement.validateStatementTimesAndTypes(statements));
    assert(Statement.validateStatementTimesAndTypes(myDelegateStatements));
    assert(Statement.validateStatementTimesAndTypes(povStatements));
  }

  DateTime? get userDismissalTimestamp => _getDismissalTimestamp(myDelegateStatements);
  DateTime? get povDismissalTimestamp => _getDismissalTimestamp(povStatements);

  bool get isRated => povStatements.any((s) => s.verb == ContentVerb.rate);

  bool get isDismissed => _checkIsDismissed(povStatements);
  bool get isUserDismissed => _checkIsDismissed(myDelegateStatements);

  bool _checkIsDismissed(List<ContentStatement> dispositionStatements) {
    final dismissalTimestamp = _getDismissalTimestamp(dispositionStatements);
    if (dismissalTimestamp == null) return false;

    // If dismissed forever (timestamp is far future), it's dismissed regardless of activity
    if (dismissalTimestamp.year >= 3000) return true;

    // If snoozed (timestamp is the time of snooze), check for qualified new activity
    if (lastActivity.isAfter(dismissalTimestamp)) {
      // Find the statement that caused the last activity
      // We assume statements are sorted or we just find the one matching lastActivity
      // Since lastActivity is the max time, we can just look for it.
      // Note: There could be multiple statements with the same time, but they would be from different
      // identities or about different things.
      // We need to check if *any* statement at lastActivity is a "Qualified New Activity".
      
      // TODO: This makes no sense to me.
      final activityStatements = statements.where((s) => s.time.isAtSameMomentAs(lastActivity));
      for (final activityStatement in activityStatements) {
         // Qualified New Activity:
         // - Rate with comment or recommend (true/false)
         // - Relate
         if (activityStatement.verb == ContentVerb.relate) return false; // Wakes up
         
         if (activityStatement.verb == ContentVerb.rate) {
           // Disqualified: censor or dismiss
           if (activityStatement.censor == true || activityStatement.dismiss != null) continue; // Does not wake up
           
           // Qualified: comment or recommend
           if (activityStatement.comment != null || activityStatement.like != null) return false; // Wakes up
         }
         // Equate/DontEquate/DontRelate are disqualified (they don't wake up)
      }
      // If we found no qualified activity among the statements at lastActivity, it remains dismissed.
      return true;
    }

    return true;
  }

  DateTime? _getDismissalTimestamp(List<ContentStatement> stmts) {
    // The user's disposition is singular. The first rate statement encountered
    // is the effective one.
    for (final s in stmts) {
      if (s.verb == ContentVerb.rate) {
        if (s.dismiss == 'forever') {
          return DateTime(3000);
        } else if (s.dismiss == 'snooze') {
          return s.time;
        }
        return null;
      }
    }
    return null;
  }
}

/// The result of aggregating content for a Follow Network.
class ContentAggregation {
  final List<ContentStatement> statements;
  final Set<String> censored;
  final Map<ContentKey, ContentKey> equivalence; // SubjectToken -> CanonicalSubjectToken
  final Map<ContentKey, Set<ContentKey>> related; // SubjectToken -> Set of RelatedSubjectTokens
  final Map<String, String> tagEquivalence; // Tag -> Canonical Tag
  final List<String> mostTags; // Tags ordered by frequency
  final Map<ContentKey, SubjectAggregation> subjects; // CanonicalToken -> Aggregation

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
  final DelegateResolver delegateResolver;
  final V2Labeler labeler;
  final ContentAggregation aggregation;
  final IdentityKey povToken;
  final String fcontext;
  final V2SortMode sortMode;
  final V2FilterMode filterMode;
  final String? tagFilter;
  final String? typeFilter;
  final bool enableCensorship;
  final List<String> availableContexts;
  final Set<String> activeContexts;
  final List<SubjectAggregation> effectiveSubjects; // Filtered and sorted
  final List<SourceError> sourceErrors;

  V2FeedModel({
    required this.trustGraph,
    required this.followNetwork,
    required this.delegateResolver,
    required this.labeler,
    required this.aggregation,
    required this.povToken,
    required this.fcontext,
    required this.sortMode,
    required this.filterMode,
    this.tagFilter,
    this.typeFilter,
    required this.enableCensorship,
    this.availableContexts = const [],
    this.activeContexts = const {},
    this.effectiveSubjects = const [],
    this.sourceErrors = const [],
  });
}

/// The result of fetching content for specific keys.
class ContentResult {
  final Map<DelegateKey, List<ContentStatement>> delegateContent;

  ContentResult({
    this.delegateContent = const {},
  });
}
