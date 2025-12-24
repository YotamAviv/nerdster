import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/delegates.dart';

dynamic _bestSubject(dynamic current, dynamic candidate) {
  if (candidate == null) return current;
  if (current is! Map && candidate is Map) return candidate;
  return current;
}

/// The Pure Function Core of the Content Aggregation Algorithm.
///
/// Input:
/// - A FollowNetwork
/// - A TrustGraph
/// - A DelegateResolver
/// - A map of org.nerdster statements by token
/// - Censorship toggle
/// Output: A ContentAggregation
ContentAggregation reduceContentAggregation(
  FollowNetwork followNetwork,
  TrustGraph trustGraph,
  DelegateResolver delegateResolver,
  Map<String, List<ContentStatement>> byToken, {
  bool enableCensorship = true,
}) {
  final Set<String> censored = {};
  
  // 1. Decentralized Censorship (Proximity Wins)
  if (enableCensorship) {
    // Process identities in trust order (discovery order in FollowNetwork)
    for (final String identity in followNetwork.identities) {
      final List<String> allKeys = [
        ...trustGraph.getEquivalenceGroup(identity),
        ...delegateResolver.getDelegatesForIdentity(identity),
      ];
      final List<Iterable<ContentStatement>> sources = [];
      for (final String key in allKeys) {
        if (byToken.containsKey(key)) sources.add(byToken[key]!);
      }
      final Iterable<ContentStatement> statements = Merger.merge(sources);

      for (final ContentStatement s
          in statements.where((s) => s.verb == ContentVerb.rate && s.censor == true)) {
        // If the censor statement itself is already censored (by someone more trusted obviously because
        // this already happened; we're working from most to least trusted), then it is censored, 
        // and we ignore the censorship its trying to apply.
        if (censored.contains(s.token)) continue;

        censored.add(s.subjectToken);
      }
    }
  }

  // 2. Collect and Filter Statements
  final List<ContentStatement> filteredStatements = [];
  final Map<String, List<ContentStatement>> filteredByIdentity = {};

  for (final String identity in followNetwork.identities) {
    final List<String> allKeys = [
      ...trustGraph.getEquivalenceGroup(identity),
      ...delegateResolver.getDelegatesForIdentity(identity),
    ];
    final List<Iterable<ContentStatement>> sources = [];
    for (final String key in allKeys) {
      if (byToken.containsKey(key)) {
        sources.add(byToken[key]!);
      }
    }
    final Iterable<ContentStatement> statements = Merger.merge(sources);

    for (final ContentStatement s in statements) {
      // Filter out follow statements (they are for network building)
      if (s.verb == ContentVerb.follow) continue;

      // Filter censored
      if (enableCensorship) {
        if (censored.contains(s.token)) continue;
        if (censored.contains(s.subjectToken)) continue;
        if (s.other != null && censored.contains(getToken(s.other))) continue;
      }

      filteredStatements.add(s);
      filteredByIdentity.putIfAbsent(identity, () => []).add(s);
    }
  }

  // 3. Equivalence Grouping
  final Map<String, Set<String>> egEdges = {};
  for (final ContentStatement s in filteredStatements.where((s) => s.verb == ContentVerb.equate)) {
    final String s1 = s.subjectToken;
    final String s2 = getToken(s.other);
    egEdges.putIfAbsent(s1, () => {}).add(s2);
    egEdges.putIfAbsent(s2, () => {}).add(s1);
  }

  final Map<String, String> equivalence = {};
  final Set<String> egVisited = {};
  for (final String subject in egEdges.keys) {
    if (egVisited.contains(subject)) continue;

    final Set<String> component = {};
    final List<String> queue = [subject];
    egVisited.add(subject);
    while (queue.isNotEmpty) {
      final String current = queue.removeAt(0);
      component.add(current);
      for (final String neighbor in egEdges[current] ?? <String>{}) {
        if (!egVisited.contains(neighbor)) {
          egVisited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    final List<String> sorted = component.toList()..sort();
    final String canonicalToken = sorted.first;
    for (final String s in component) {
      equivalence[s] = canonicalToken;
    }
  }

  // 4. Relational Discovery (Related)
  final Map<String, Set<String>> related = {};
  for (final ContentStatement s in filteredStatements.where((s) => s.verb == ContentVerb.relate)) {
    final String s1 = equivalence[s.subjectToken] ?? s.subjectToken;
    final String s2 = equivalence[getToken(s.other)] ?? getToken(s.other);
    if (s1 == s2) continue;
    related.putIfAbsent(s1, () => {}).add(s2);
    related.putIfAbsent(s2, () => {}).add(s1);
  }

  // 5. Subject Aggregation
  final Map<String, SubjectAggregation> subjects = {};
  final RegExp tagRegex = RegExp(r'#(\w+)');

  for (final String identity in followNetwork.identities) {
    final List<ContentStatement> statements = filteredByIdentity[identity] ?? [];
    for (final ContentStatement s in statements) {
      final String canonical1 = equivalence[s.subjectToken] ?? s.subjectToken;
      final String? canonical2 =
          s.other != null ? (equivalence[getToken(s.other)] ?? getToken(s.other)) : null;

      final List<String> targets = [canonical1];
      if (canonical2 != null && canonical2 != canonical1) {
        targets.add(canonical2);
      }

      for (final String canonical in targets) {
        final SubjectAggregation agg = subjects.putIfAbsent(canonical, () {
          return SubjectAggregation(
            canonicalToken: canonical,
            subject: s.subjectToken == canonical
                ? s.subject
                : (s.other != null && getToken(s.other) == canonical ? s.other : canonical),
            lastActivity: s.time,
          );
        });

        // Update stats
        int likes = agg.likes;
        int dislikes = agg.dislikes;
        if (s.verb == ContentVerb.rate) {
          if (s.like == true) likes++;
          if (s.like == false) dislikes++;
        }

        // Extract tags from comment
        final Set<String> tags = Set.from(agg.tags);
        if (s.comment != null) {
          for (final Match match in tagRegex.allMatches(s.comment!)) {
            tags.add(match.group(1)!.toLowerCase());
          }
        }

        // Update related
        final Set<String> relatedSet = Set.from(agg.related);
        if (s.verb == ContentVerb.relate) {
          if (canonical == canonical1 && canonical2 != null) {
            relatedSet.add(canonical2);
          } else if (canonical == canonical2) {
            relatedSet.add(canonical1);
          }
        }

        // Update dismissed
        bool isDismissed = agg.isDismissed;
        final String? signerIdentity = trustGraph.isTrusted(s.iToken)
            ? trustGraph.resolveIdentity(s.iToken)
            : delegateResolver.getIdentityForDelegate(s.iToken);

        if (signerIdentity == followNetwork.rootIdentity && s.dismiss == true) {
          isDismissed = true;
        }

        // Update the aggregation
        subjects[canonical] = SubjectAggregation(
          canonicalToken: agg.canonicalToken,
          subject: _bestSubject(
              agg.subject,
              s.subjectToken == canonical
                  ? s.subject
                  : (s.other != null && getToken(s.other) == canonical ? s.other : null)),
          statements: [...agg.statements, s],
          tags: tags,
          likes: likes,
          dislikes: dislikes,
          lastActivity: s.time.isAfter(agg.lastActivity) ? s.time : agg.lastActivity,
          related: relatedSet,
          isDismissed: isDismissed,
        );
      }
    }
  }

  return ContentAggregation(
    statements: filteredStatements,
    censored: censored,
    equivalence: equivalence,
    related: related,
    subjects: subjects,
  );
}
