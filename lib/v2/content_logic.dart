import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/tag.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';

bool _isStatement(String token) {
  final j = Jsonish.find(token);
  return j != null && j.containsKey('statement');
}

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
  String? meToken,
  List<String>? meKeys,
}) {
  final Set<String> censored = {};
  
  // 1. Decentralized Censorship (Proximity Wins)
  if (enableCensorship) {
    // Process identities in trust order (discovery order in FollowNetwork)
    final List<String> identitiesToProcess = [...followNetwork.identities];

    for (final String identity in identitiesToProcess) {
      final List<String> allKeys = [
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

  final List<String> identitiesToProcess = [...followNetwork.identities];

  for (final String identity in identitiesToProcess) {
    final List<String> allKeys = [
      identity,
      ...delegateResolver.getDelegatesForIdentity(identity),
    ];

    final List<Iterable<ContentStatement>> sources = [];
    for (final String key in allKeys) {
      if (byToken.containsKey(key)) {
        sources.add(byToken[key]!);
      }
    }
    final Iterable<ContentStatement> statements = distinct(
      Merger.merge(sources),
      transformer: (_) => identity,
    ).cast<ContentStatement>();

    for (final ContentStatement s in statements) {
      // Filter out follow statements (they are for network building)
      if (s.verb == ContentVerb.follow) continue;
      if (s.verb == ContentVerb.clear) continue;

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

  // 2b. Collect My Statements (Separately)
  //
  // Rationale:
  // When viewing the feed from another Point of View (PoV), the current user ("Me")
  // might not be in the PoV's trust network. If "Me" is not trusted, my statements
  // (ratings, comments) should NOT affect the feed's content, sort order, or aggregate scores
  // (likes/dislikes). The user should see the feed exactly as the PoV sees it.
  //
  // However, the UI still needs to display the user's own state (e.g., "You rated this",
  // "You commented"). Therefore, we fetch and aggregate "Me's" statements separately
  // and overlay them into the `myDelegateStatements` field of the SubjectAggregation.
  //
  // This ensures:
  // 1. Purity of the PoV's view (no pollution from untrusted "Me").
  // 2. Availability of "Me's" data for UI widgets.
  final List<ContentStatement> myFilteredStatements = [];
  if (meKeys != null) {
    final List<Iterable<ContentStatement>> sources = [];
    for (final String key in meKeys) {
      if (byToken.containsKey(key)) {
        sources.add(byToken[key]!);
      }
    }
    final Iterable<ContentStatement> statements = Merger.merge(sources);
    for (final ContentStatement s in statements) {
      if (s.verb == ContentVerb.follow) continue;
      if (enableCensorship) {
        if (censored.contains(s.token)) continue;
        if (censored.contains(s.subjectToken)) continue;
        if (s.other != null && censored.contains(getToken(s.other))) continue;
      }
      myFilteredStatements.add(s);
    }
  }

  // 3. Equivalence Grouping
  final Map<String, Set<String>> egEdges = {};

  for (final ContentStatement s in filteredStatements) {
    if (s.verb == ContentVerb.equate) {
      final String s1 = s.subjectToken;
      final String s2 = getToken(s.other);
      if (s1 == s2) continue;

      egEdges.putIfAbsent(s1, () => {}).add(s2);
      egEdges.putIfAbsent(s2, () => {}).add(s1);
    }
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

  // Tag Equivalence Grouping
  final Map<String, Set<String>> tagEdges = {};
  for (final s in filteredStatements) {
    if (s.comment != null) {
      final tags = tagRegExp.allMatches(s.comment!).map((m) => m.group(0)!.toLowerCase()).toList();
      if (tags.length > 1) {
        for (int i = 0; i < tags.length; i++) {
          for (int j = i + 1; j < tags.length; j++) {
            tagEdges.putIfAbsent(tags[i], () => {}).add(tags[j]);
            tagEdges.putIfAbsent(tags[j], () => {}).add(tags[i]);
          }
        }
      }
    }
  }

  final Map<String, String> tagEquivalence = {};
  final Set<String> tagVisited = {};
  for (final tag in tagEdges.keys) {
    if (tagVisited.contains(tag)) continue;

    final Set<String> component = {};
    final List<String> queue = [tag];
    tagVisited.add(tag);
    while (queue.isNotEmpty) {
      final String current = queue.removeAt(0);
      component.add(current);
      for (final String neighbor in tagEdges[current] ?? <String>{}) {
        if (!tagVisited.contains(neighbor)) {
          tagVisited.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    final List<String> sorted = component.toList()..sort();
    final String canonicalTag = sorted.first;
    for (final String t in component) {
      tagEquivalence[t] = canonicalTag;
    }
  }

  // 4. Relational Discovery (Related)
  final Map<String, Set<String>> related = {};

  for (final ContentStatement s in filteredStatements) {
    if (s.verb == ContentVerb.relate) {
      final String s1 = equivalence[s.subjectToken] ?? s.subjectToken;
      final String s2 = equivalence[getToken(s.other)] ?? getToken(s.other);
      if (s1 == s2) continue;

      related.putIfAbsent(s1, () => {}).add(s2);
      related.putIfAbsent(s2, () => {}).add(s1);
    }
  }

  // 5. Aggregation
  final Map<String, SubjectAggregation> subjects = {};
  final Map<String, List<ContentStatement>> statementsBySubject = {};
  for (final s in filteredStatements) {
    final canonical = equivalence[s.subjectToken] ?? s.subjectToken;
    statementsBySubject.putIfAbsent(canonical, () => []).add(s);
  }

  // Pass 1: Identify all canonical tokens that should be top-level subjects.
  final Set<String> topLevelSubjects = {};
  for (final ContentStatement s in filteredStatements) {
    final String canonical1 = equivalence[s.subjectToken] ?? s.subjectToken;
    final String? canonical2 =
        s.other != null ? (equivalence[getToken(s.other)] ?? getToken(s.other)) : null;

    if ((s.verb == ContentVerb.clear && s.subject is Map) ||
        s.verb == ContentVerb.rate ||
        s.verb == ContentVerb.relate ||
        s.verb == ContentVerb.dontRelate ||
        s.verb == ContentVerb.equate) {
      if (!_isStatement(canonical1)) {
        topLevelSubjects.add(canonical1);
      }
      if (canonical2 != null && !_isStatement(canonical2)) {
        topLevelSubjects.add(canonical2);
      }
    }
  }

  // Pass 2: Aggregate all statements into those subjects.
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
        // Only aggregate if this canonical token is a top-level subject.
        if (!topLevelSubjects.contains(canonical)) continue;

        final SubjectAggregation agg = subjects.putIfAbsent(canonical, () {
          return SubjectAggregation(
            canonicalToken: canonical,
            subject: canonical,
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

        // Update related
        final Set<String> relatedSet = Set.from(agg.related);
        if (s.verb == ContentVerb.relate) {
          if (canonical == canonical1 && canonical2 != null) {
            relatedSet.add(canonical2);
          } else if (canonical == canonical2) {
            relatedSet.add(canonical1);
          }
        }

        // Update dismissal timestamps
        DateTime? userDismissalTimestamp = agg.userDismissalTimestamp;
        DateTime? povDismissalTimestamp = agg.povDismissalTimestamp;
        bool isRated = agg.isRated;

        final String? signerIdentity = trustGraph.isTrusted(s.iToken)
            ? trustGraph.resolveIdentity(s.iToken)
            : delegateResolver.getIdentityForDelegate(s.iToken);

        if (s.verb == ContentVerb.clear) {
          // Remove prior statements by this identity
          final toRemove = agg.statements.where((existing) {
            final existingIdentity = trustGraph.isTrusted(existing.iToken)
                ? trustGraph.resolveIdentity(existing.iToken)
                : delegateResolver.getIdentityForDelegate(existing.iToken);
            return existingIdentity == signerIdentity;
          }).toList();

          int likesDelta = 0;
          int dislikesDelta = 0;
          for (final r in toRemove) {
            if (r.verb == ContentVerb.rate) {
              if (r.like == true) likesDelta--;
              if (r.like == false) dislikesDelta--;
            }
          }

          final newStatements = agg.statements.where((existing) => !toRemove.contains(existing)).toList();

          Set<String> newRelated = agg.related;
          if (toRemove.any((r) => r.verb == ContentVerb.relate)) {
            newRelated = {};
            for (final stmt in newStatements) {
              if (stmt.verb == ContentVerb.relate) {
                final c1 = equivalence[stmt.subjectToken] ?? stmt.subjectToken;
                final c2 = stmt.other != null ? (equivalence[getToken(stmt.other)] ?? getToken(stmt.other)) : null;
                if (canonical == c1 && c2 != null) {
                  newRelated.add(c2);
                } else if (canonical == c2) {
                  newRelated.add(c1);
                }
              }
            }
          }

          // Also clear isRated if the signer is the PoV
          bool isRated = agg.isRated;
          if (signerIdentity == followNetwork.rootIdentity) {
             // If we removed any rate statements, we might need to re-check isRated.
             // But simpler: just re-check from newStatements.
             isRated = newStatements.any((stmt) {
                final sid = trustGraph.isTrusted(stmt.iToken)
                    ? trustGraph.resolveIdentity(stmt.iToken)
                    : delegateResolver.getIdentityForDelegate(stmt.iToken);
                return sid == followNetwork.rootIdentity && stmt.verb == ContentVerb.rate;
             });
          }

          subjects[canonical] = SubjectAggregation(
            canonicalToken: canonical,
            subject: agg.subject,
            statements: newStatements,
            tags: agg.tags,
            likes: agg.likes + likesDelta,
            dislikes: agg.dislikes + dislikesDelta,
            lastActivity: s.time.isAfter(agg.lastActivity) ? s.time : agg.lastActivity,
            related: newRelated,
            myDelegateStatements: agg.myDelegateStatements,
            userDismissalTimestamp: agg.userDismissalTimestamp,
            povDismissalTimestamp: agg.povDismissalTimestamp,
            isCensored: agg.isCensored,
            isDismissed: agg.isDismissed,
            isRated: isRated,
          );
          continue;
        }

        if (signerIdentity == followNetwork.rootIdentity) {
          if (s.verb == ContentVerb.rate) isRated = true;
          if (s.dismiss == true) {
            if (povDismissalTimestamp == null || s.time.isAfter(povDismissalTimestamp)) {
              povDismissalTimestamp = s.time;
            }
          }
        }

        if (s.dismiss == true && meToken != null && signerIdentity == trustGraph.resolveIdentity(meToken)) {
          if (userDismissalTimestamp == null || s.time.isAfter(userDismissalTimestamp)) {
            userDismissalTimestamp = s.time;
          }
        }

        final DateTime lastActivity = s.time.isAfter(agg.lastActivity) ? s.time : agg.lastActivity;

        // Update the aggregation
        subjects[canonical] = SubjectAggregation(
          canonicalToken: canonical,
          subject: _bestSubject(
              agg.subject,
              (equivalence[s.subjectToken] ?? s.subjectToken) == canonical
                  ? s.subject
                  : (s.other != null && (equivalence[getToken(s.other)] ?? getToken(s.other)) == canonical ? s.other : null)),
          statements: [...agg.statements, s],
          tags: agg.tags, // Will be updated in Pass 3
          likes: likes,
          dislikes: dislikes,
          lastActivity: lastActivity,
          related: relatedSet,
          myDelegateStatements: agg.myDelegateStatements,
          userDismissalTimestamp: userDismissalTimestamp,
          povDismissalTimestamp: povDismissalTimestamp,
          isCensored: censored.contains(canonical) || censored.contains(s.subjectToken),
          isDismissed: povDismissalTimestamp != null && !lastActivity.isAfter(povDismissalTimestamp),
          isRated: isRated,
        );
      }
    }
  }

  // Pass 2b: Aggregate My Statements
  for (final ContentStatement s in myFilteredStatements) {
    final String canonical1 = equivalence[s.subjectToken] ?? s.subjectToken;
    final String? canonical2 =
        s.other != null ? (equivalence[getToken(s.other)] ?? getToken(s.other)) : null;

    final List<String> targets = [canonical1];
    if (canonical2 != null && canonical2 != canonical1) {
      targets.add(canonical2);
    }

    for (final String canonical in targets) {
      // Only aggregate if this canonical token is a top-level subject.
      if (!topLevelSubjects.contains(canonical)) continue;

      // If the subject doesn't exist in the aggregation (because PoV doesn't see it),
      // we skip it. "I should see their view exactly as they would".
      if (!subjects.containsKey(canonical)) continue;

      final SubjectAggregation agg = subjects[canonical]!;

      // Update dismissal timestamps
      DateTime? userDismissalTimestamp = agg.userDismissalTimestamp;
      if (s.dismiss == true) {
        if (userDismissalTimestamp == null || s.time.isAfter(userDismissalTimestamp)) {
          userDismissalTimestamp = s.time;
        }
      }

      // Update myDelegateStatements
      List<ContentStatement> myDelegateStatements = agg.myDelegateStatements;
      if (s.verb == ContentVerb.clear) {
        // Clear all my previous statements on this subject
        myDelegateStatements = [];
      } else {
        myDelegateStatements = [...myDelegateStatements, s];
      }

      subjects[canonical] = SubjectAggregation(
        canonicalToken: agg.canonicalToken,
        subject: agg.subject,
        statements: agg.statements,
        tags: agg.tags,
        likes: agg.likes,
        dislikes: agg.dislikes,
        lastActivity: agg.lastActivity,
        related: agg.related,
        myDelegateStatements: myDelegateStatements,
        userDismissalTimestamp: userDismissalTimestamp,
        povDismissalTimestamp: agg.povDismissalTimestamp,
        isCensored: agg.isCensored,
        isDismissed: agg.isDismissed,
        isRated: agg.isRated,
      );
    }
  }

  // Pass 3: Recursive Tag Collection and Most Frequent Tags
  final Map<String, int> tagCounts = {};
  
  Set<String> collectTagsRecursive(String token, Set<String> visited) {
    if (visited.contains(token)) return {};
    visited.add(token);
    
    final Set<String> tags = {};
    
    // Tags from the subject itself if it has a comment
    final subject = Jsonish.find(token);
    if (subject != null && subject['comment'] != null) {
      tags.addAll(extractTags(subject['comment']));
    }

    // Tags from statements about this token
    for (final s in statementsBySubject[token] ?? []) {
      if (s.comment != null) {
        tags.addAll(extractTags(s.comment!));
      }
      tags.addAll(collectTagsRecursive(s.token, visited));
    }
    return tags;
  }

  for (final agg in subjects.values) {
    final Set<String> recursiveTags = collectTagsRecursive(agg.canonicalToken, {});
    subjects[agg.canonicalToken] = SubjectAggregation(
      canonicalToken: agg.canonicalToken,
      subject: agg.subject,
      statements: agg.statements,
      tags: recursiveTags,
      likes: agg.likes,
      dislikes: agg.dislikes,
      lastActivity: agg.lastActivity,
      related: agg.related,
      myDelegateStatements: agg.myDelegateStatements,
      userDismissalTimestamp: agg.userDismissalTimestamp,
      povDismissalTimestamp: agg.povDismissalTimestamp,
      isCensored: agg.isCensored,
      isDismissed: agg.isDismissed,
      isRated: agg.isRated,
    );
    
    for (final tag in recursiveTags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  final List<String> mostTags = tagCounts.keys.toList()
    ..sort((a, b) => tagCounts[b]!.compareTo(tagCounts[a]!));

  return ContentAggregation(
    statements: filteredStatements,
    censored: censored,
    equivalence: equivalence,
    related: related,
    tagEquivalence: tagEquivalence,
    mostTags: mostTags,
    subjects: subjects,
  );
}
