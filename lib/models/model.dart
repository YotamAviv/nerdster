import 'package:flutter/foundation.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:oneofus_common/source_error.dart';

enum SortMode {
  recentActivity,
  netLikes,
  mostComments,
}

enum DisFilterMode {
  my,
  pov,
  ignore;

  static DisFilterMode fromString(String val) {
    try {
      return DisFilterMode.values.byName(val);
    } catch (_) {
      return my;
    }
  }
}

/// Represents a generic system notification (e.g. Invisibility, Delegate issues)
class SystemNotification {
  final String title;
  final String description;
  final bool isError;
  final String? icon; // Optional custom icon?

  SystemNotification({
    required this.title, 
    required this.description, 
    this.isError = false,
    this.icon,
  });
}

/// Represents a notification or conflict discovered during graph construction.
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

/// The immutable result of the Trust Algorithm.
class TrustGraph {
  final IdentityKey pov;
  final Map<IdentityKey, int> distances; // Token -> Distance
  final List<IdentityKey> orderedKeys; // Tokens in discovery order (BFS)
  final Map<IdentityKey, IdentityKey> replacements; // OldToken -> NewToken
  final Map<IdentityKey, String>
      replacementConstraints; // Token -> RevokeAtToken (Time constraint works on Token string)
  final Set<IdentityKey> blocked; // Tokens blocked by the graph
  final Map<IdentityKey, List<List<IdentityKey>>>
      paths; // Target -> List of node-disjoint paths from pov
  /// Notifications: key rotation issues, attempt to claim a delegate that's already been claimed.
  final List<TrustNotification> notifications;
  final Map<IdentityKey, List<TrustStatement>>
      edges; // Adjacency list: Issuer -> List<TrustStatement> (Valid statements)

  TrustGraph({
    required this.pov,
    this.distances = const {},
    List<IdentityKey> orderedKeys = const [],
    this.replacements = const {},
    this.replacementConstraints = const {},
    this.blocked = const {},
    Map<IdentityKey, List<List<IdentityKey>>> paths = const {},
    List<TrustNotification> notifications = const [],
    Map<IdentityKey, List<TrustStatement>> edges = const {},
  })  : orderedKeys = List.unmodifiable(orderedKeys),
        paths = Map<IdentityKey, List<List<IdentityKey>>>.unmodifiable(paths.map((k, v) => MapEntry(
            k,
            List<List<IdentityKey>>.unmodifiable(
                v.map((p) => List<IdentityKey>.unmodifiable(p)))))),
        notifications = List<TrustNotification>.unmodifiable(notifications),
        edges = Map<IdentityKey, List<TrustStatement>>.unmodifiable(
            edges.map((k, v) => MapEntry(k, List<TrustStatement>.unmodifiable(v))));

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
    for (final IdentityKey token in distances.keys) {
      final IdentityKey canonical = resolveIdentity(token);
      groups.putIfAbsent(canonical, () => []).add(token);
    }
    // Sort tokens within each group by distance (canonical first usually)
    for (final List<IdentityKey> group in groups.values) {
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
    for (final IdentityKey issuer in edges.keys) {
      if ((distances[issuer] ?? -1) == targetDist - 1) {
        for (final TrustStatement s in edges[issuer]!) {
          // Only trust/replace edges constitute a path in the identity graph.
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
    List<IdentityKey> identities = const [],
    Map<IdentityKey, List<IdentityKey>> paths = const {},
    List<TrustNotification> notifications = const [],
    Map<IdentityKey, List<ContentStatement>> edges = const {},
  })  : identities = List<IdentityKey>.unmodifiable(identities),
        paths = Map<IdentityKey, List<IdentityKey>>.unmodifiable(
            paths.map((k, v) => MapEntry(k, List<IdentityKey>.unmodifiable(v)))),
        notifications = List<TrustNotification>.unmodifiable(notifications),
        edges = Map<IdentityKey, List<ContentStatement>>.unmodifiable(
            edges.map((k, v) => MapEntry(k, List<ContentStatement>.unmodifiable(v))));

  bool contains(IdentityKey identity) => identities.contains(identity);
}

/// Shared data for an entire equivalence group of subjects.
class SubjectGroup {
  final List<ContentStatement> statements;
  final Set<String> tags;
  final int likes;
  final int dislikes;
  final DateTime lastActivity;
  final Set<ContentKey> related; // Canonical tokens of related subjects
  final List<ContentStatement> povStatements;
  final bool isCensored;
  final ContentKey canonical;
  SubjectGroup({
    required this.canonical,
    List<ContentStatement> statements = const [],
    this.tags = const {},
    this.likes = 0,
    this.dislikes = 0,
    required this.lastActivity,
    this.related = const {},
    List<ContentStatement> povStatements = const [],
    this.isCensored = false,
  })  : statements = List.unmodifiable(statements),
        povStatements = List.unmodifiable(povStatements) {
    Statement.validateOrderTypes(this.statements);
    Statement.validateOrderTypes(this.povStatements);
  }

  SubjectGroup copyWith({
    List<ContentStatement>? statements,
    Set<String>? tags,
    int? likes,
    int? dislikes,
    DateTime? lastActivity,
    Set<ContentKey>? related,
    List<ContentStatement>? povStatements,
    bool? isCensored,
    ContentKey? canonical,
  }) {
    return SubjectGroup(
      canonical: canonical ?? this.canonical,
      statements: statements ?? this.statements,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      lastActivity: lastActivity ?? this.lastActivity,
      related: related ?? this.related,
      povStatements: povStatements ?? this.povStatements,
      isCensored: isCensored ?? this.isCensored,
    );
  }

  DateTime? get povDismissalTimestamp => _getDismissalTimestamp(povStatements);

  bool get isRated => povStatements.any((s) => s.verb == ContentVerb.rate);

  bool get isDismissed => _checkIsDismissed(povStatements);

  bool _checkIsDismissed(List<ContentStatement> dispositionStatements) {
    Statement.validateOrderTypes(dispositionStatements);
    final DateTime? dismissalTimestamp = _getDismissalTimestamp(dispositionStatements);
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
      final Iterable<ContentStatement> activityStatements =
          statements.where((ContentStatement s) => s.time.isAtSameMomentAs(lastActivity));
      for (final ContentStatement activityStatement in activityStatements) {
        // Qualified New Activity:
        // - Rate with comment or recommend (true/false)
        // - Relate
        if (activityStatement.verb == ContentVerb.relate) return false; // Wakes up
        if (activityStatement.verb == ContentVerb.rate) {
          // Disqualified: censor or dismiss
          if (activityStatement.censor == true || activityStatement.dismiss != null)
            continue; // Does not wake up

          // Qualified: comment or recommend
          if (activityStatement.comment != null || activityStatement.like != null)
            return false; // Wakes up
        }
        // Equate/DontEquate/DontRelate are disqualified (they don't wake up)
      }
      // If we found no qualified activity among the statements at lastActivity, it remains dismissed.
      return true;
    }
    return true;
  }

  DateTime? _getDismissalTimestamp(List<ContentStatement> stmts) {
    Statement.validateOrderTypes(stmts);
    // The user's disposition is singular. The first rate statement encountered
    // is the effective one.
    for (final ContentStatement s in stmts) {
      if (s.verb == ContentVerb.rate) {
        if (s.dismiss == 'forever') {
          return DateTime(3000);
        } else if (s.dismiss == 'snooze') {
          return s.time;
        }
        return null; // A rate statement without dismissal ends the search and returns null
      }
    }
    return null;
  }

  static bool checkIsDismissed(List<ContentStatement> myStmts, SubjectAggregation agg) {
    Statement.validateOrderTypes(myStmts);
    final DateTime? dismissalTimestamp = getDismissalTimestamp(myStmts);
    if (dismissalTimestamp == null) return false;
    if (dismissalTimestamp.year >= 3000) return true;

    if (agg.lastActivity.isAfter(dismissalTimestamp)) {
      final Iterable<ContentStatement> activityStatements =
          agg.statements.where((ContentStatement s) => s.time.isAtSameMomentAs(agg.lastActivity));
      for (final ContentStatement activityStatement in activityStatements) {
        if (activityStatement.verb == ContentVerb.relate) return false;
        if (activityStatement.verb == ContentVerb.rate) {
          if (activityStatement.censor == true || activityStatement.dismiss != null) continue;
          if (activityStatement.comment != null || activityStatement.like != null) return false;
        }
      }
      return true;
    }
    return true;
  }

  static DateTime? getDismissalTimestamp(List<ContentStatement> stmts) {
    Statement.validateOrderTypes(stmts);
    for (final ContentStatement s in stmts) {
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

/// A specific view of a subject, bound to a literal identity but sharing group data.
class SubjectAggregation {
  final Json subject;
  final SubjectGroup group; // Canonical aggregation
  final SubjectGroup narrowGroup; // Literal aggregation
  final bool isNarrowMode;

  SubjectAggregation({
    required this.subject,
    required this.group,
    required this.narrowGroup,
    this.isNarrowMode = false,
  });

  SubjectAggregation toNarrow() => SubjectAggregation(
        subject: subject,
        group: group,
        narrowGroup: narrowGroup,
        isNarrowMode: true,
      );

  SubjectAggregation toWide() => SubjectAggregation(
        subject: subject,
        group: group,
        narrowGroup: narrowGroup,
        isNarrowMode: false,
      );

  SubjectGroup get activeGroup => isNarrowMode ? narrowGroup : group;

  // Proxy getters for active group data
  ContentKey get token => ContentKey(getToken(subject));
  ContentKey get canonical => group.canonical;
  List<ContentStatement> get statements => activeGroup.statements;
  Set<String> get tags => activeGroup.tags;
  int get likes => activeGroup.likes;
  int get dislikes => activeGroup.dislikes;
  DateTime get lastActivity => activeGroup.lastActivity;
  Set<ContentKey> get related => activeGroup.related;
  List<ContentStatement> get povStatements => activeGroup.povStatements;
  bool get isCensored => activeGroup.isCensored;

  // Proxy getters for disposition
  bool get isRated => activeGroup.isRated;
  bool get isDismissed => activeGroup.isDismissed;
  DateTime? get povDismissalTimestamp => activeGroup.povDismissalTimestamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectAggregation &&
          mapEquals(subject, other.subject) &&
          group.canonical == other.group.canonical &&
          isNarrowMode == other.isNarrowMode;

  @override
  int get hashCode => subject.hashCode ^ group.canonical.hashCode ^ isNarrowMode.hashCode;
}

/// The result of aggregating content for a Follow Network.
class ContentAggregation {
  final List<ContentStatement> statements;
  final Set<String> censored;
  final Map<ContentKey, ContentKey> equivalence; // SubjectToken -> CanonicalSubjectToken
  final Map<ContentKey, Set<ContentKey>> related; // SubjectToken -> Set of RelatedSubjectTokens
  final Map<String, String> tagEquivalence; // Tag -> Canonical Tag
  final List<String> mostTags; // Tags ordered by frequency

  /// Map of every known literal subject token to its flavored Aggregation.
  final Map<ContentKey, SubjectAggregation> subjects;

  /// Map of canonical subject tokens to the list of my own merged rate statements.
  /// Used for dismissal logic so that a dismissal of any token in an
  /// equivalence group applies to the whole group.
  final Map<ContentKey, List<ContentStatement>> myCanonicalDisses;

  /// Map of literal subject tokens to the list of my own merged statements.
  /// Used for UI hydration (RateDialog, etc) regardless of canonicalization.
  final Map<ContentKey, List<ContentStatement>> myLiteralStatements;

  ContentAggregation({
    List<ContentStatement> statements = const [],
    this.censored = const {},
    this.equivalence = const {},
    this.related = const {},
    this.tagEquivalence = const {},
    List<String> mostTags = const [],
    this.subjects = const {},
    Map<ContentKey, List<ContentStatement>> myCanonicalDisses = const {},
    Map<ContentKey, List<ContentStatement>> myLiteralStatements = const {},
  })  : statements = List<ContentStatement>.unmodifiable(statements),
        mostTags = List<String>.unmodifiable(mostTags),
        myCanonicalDisses = Map<ContentKey, List<ContentStatement>>.unmodifiable(
            myCanonicalDisses.map((k, v) => MapEntry(k, List<ContentStatement>.unmodifiable(v)))),
        myLiteralStatements = Map<ContentKey, List<ContentStatement>>.unmodifiable(
            myLiteralStatements.map((k, v) => MapEntry(k, List<ContentStatement>.unmodifiable(v))));
}

/// A complete snapshot of the feed data, ready for display.
class FeedModel {
  final TrustGraph trustGraph;
  final FollowNetwork followNetwork;
  final DelegateResolver delegateResolver;
  final Labeler labeler;
  final ContentAggregation aggregation;
  final IdentityKey povIdentity;
  final String fcontext;
  final SortMode sortMode;
  final DisFilterMode filterMode;
  final String? tagFilter;
  final String? typeFilter;
  final bool enableCensorship;
  final List<String> availableContexts;
  final Set<String> activeContexts;
  final List<SubjectAggregation> effectiveSubjects; // Filtered and sorted
  final List<SourceError> sourceErrors;
  final List<SystemNotification> systemNotifications;

  FeedModel({
    required this.trustGraph,
    required this.followNetwork,
    required this.delegateResolver,
    required this.labeler,
    required this.aggregation,
    required this.povIdentity,
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
    this.systemNotifications = const [],
  });
}

/// The result of fetching content for specific keys.
class ContentResult {
  final Map<DelegateKey, List<ContentStatement>> delegateContent;

  ContentResult({
    Map<DelegateKey, List<ContentStatement>> delegateContent = const {},
  }) : delegateContent = Map<DelegateKey, List<ContentStatement>>.unmodifiable(
            delegateContent.map((k, v) => MapEntry(k, List<ContentStatement>.unmodifiable(v))));
}
