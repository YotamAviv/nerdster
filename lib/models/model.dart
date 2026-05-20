import 'package:flutter/foundation.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/models/equivalence_statement.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:oneofus_common/source_error.dart';
import 'package:nerdster_common/trust_graph.dart';
export 'package:nerdster_common/trust_graph.dart';

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

// TrustNotification and TrustGraph live in nerdster_common (exported above).

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

  /// Latest timestamp of any qualified activity statement (like, non-empty
  /// comment, relate, equate — but NOT censor-only). Used as the sort key
  /// and for snooze wake-up logic.
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
    Statement.validateOrderTypes(statements);
    Statement.validateOrderTypes(povStatements);
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

  bool get isRated => povStatements.any((s) => s.verb == ContentVerb.rate);

  int get comments =>
      statements.where((s) => s.comment != null && s.comment!.isNotEmpty).length;

  // TODO(deferred): PoV dismiss — once the PoV's dis stream is fetched, wire it
  // in here via a povDismissStatements field and delegate to checkIsDismissed.
  bool get isDismissed => false;
  DateTime? get povDismissalTimestamp => null;

  /// Returns whether the signed-in user has dismissed the subject.
  /// [myDis] is the list of DismissStatements for this canonical subject from
  /// the user's own dis stream (descending time order, one per delegate).
  static bool checkIsDismissed(List<DismissStatement> myDis, SubjectAggregation agg) {
    final DateTime? dismissalTimestamp = getDismissalTimestamp(myDis);
    if (dismissalTimestamp == null) return false;
    if (dismissalTimestamp.year >= 3000) return true;

    if (agg.lastActivity.isAfter(dismissalTimestamp)) {
      final Iterable<ContentStatement> activityStatements =
          agg.statements.where((s) => s.time.isAtSameMomentAs(agg.lastActivity));
      for (final ContentStatement s in activityStatements) {
        if (s.verb == ContentVerb.relate) return false;
        if (s.verb == ContentVerb.rate) {
          if (s.censor == true) continue;
          if (s.comment != null || s.like != null) return false;
        }
      }
      return true;
    }
    return true;
  }

  /// Returns the effective dismissal timestamp from a list of DismissStatements.
  /// The most recent statement wins. Returns null if not dismissed.
  static DateTime? getDismissalTimestamp(List<DismissStatement> stmts) {
    if (stmts.isEmpty) return null;
    final DismissStatement latest = stmts.first; // descending time order
    if (latest.isClear) return null;
    if (latest.dismiss == 'forever') return DateTime(3000);
    if (latest.dismiss == 'snooze') return latest.time;
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
  int get comments => activeGroup.comments;
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
  final List<String> mostTags; // Tags ordered by frequency (canonical only)
  /// Tag string -> canonical tag string (from org.nerdster.equivalence statements).
  /// Every tag maps to itself if it has no equivalence statement.
  final Map<String, String> tagEquivalence;

  /// Map of every known literal subject token to its flavored Aggregation.
  final Map<ContentKey, SubjectAggregation> subjects;

  /// Map of canonical subject tokens to the signed-in user's DismissStatements.
  /// Used for DisFilterMode.my and the card dismiss toggle.
  final Map<ContentKey, List<DismissStatement>> myDismissStatements;

  /// Map of literal subject tokens to the list of my own merged statements.
  /// Used for UI hydration (RateDialog, etc) regardless of canonicalization.
  final Map<ContentKey, List<ContentStatement>> myLiteralStatements;

  ContentAggregation({
    List<ContentStatement> statements = const [],
    this.censored = const {},
    this.equivalence = const {},
    this.related = const {},
    List<String> mostTags = const [],
    this.tagEquivalence = const {},
    this.subjects = const {},
    Map<ContentKey, List<DismissStatement>> myDismissStatements = const {},
    Map<ContentKey, List<ContentStatement>> myLiteralStatements = const {},
  })  : statements = List<ContentStatement>.unmodifiable(statements),
        mostTags = List<String>.unmodifiable(mostTags),
        myDismissStatements = Map<ContentKey, List<DismissStatement>>.unmodifiable(
            myDismissStatements.map((k, v) => MapEntry(k, List<DismissStatement>.unmodifiable(v)))),
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
  final Map<IdentityKey, TrustStatement> myTrustStatements;

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
    this.myTrustStatements = const {},
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

/// The result of fetching org.nerdster.equivalence statements for specific keys.
class EquivalenceResult {
  final Map<DelegateKey, List<EquivalenceStatement>> delegateContent;

  const EquivalenceResult({
    this.delegateContent = const {},
  });
}
