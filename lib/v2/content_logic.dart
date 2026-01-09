import 'package:nerdster/most_strings.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/tag.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/equivalence/equivalence.dart';
import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/eg.dart';

List<Iterable<ContentStatement>> _collectSources(
    IdentityKey identity, DelegateResolver delegateResolver, ContentResult contentResult) {
  final List<Iterable<ContentStatement>> sources = [];
  for (final DelegateKey key in delegateResolver.getDelegatesForIdentity(identity)) {
    if (contentResult.delegateContent.containsKey(key)) {
      sources.add(contentResult.delegateContent[key]!);
    }
  }
  return sources;
}

/// The Pure Function Core of the Content Aggregation Algorithm.
/// - no awaits, all the content is already fetched and passed in.
ContentAggregation reduceContentAggregation(
  FollowNetwork followNetwork,
  TrustGraph trustGraph,
  DelegateResolver delegateResolver,
  ContentResult contentResult, {
  bool enableCensorship = true,
  List<DelegateKey>? meDelegateKeys,
  required V2Labeler labeler,
}) {
  final Set<String> censored = {};

  // 1. Decentralized Censorship (Proximity Wins)
  if (enableCensorship) {
    // Process identities in trust order (discovery order in FollowNetwork)
    for (final IdentityKey identity in followNetwork.identities) {
      final List<Iterable<ContentStatement>> sources = _collectSources(
        identity,
        delegateResolver,
        contentResult,
      );

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
  final Map<IdentityKey, List<ContentStatement>> filteredByIdentity = {};

  for (final IdentityKey identity in followNetwork.identities) {
    final List<Iterable<ContentStatement>> sources = _collectSources(
      identity,
      delegateResolver,
      contentResult,
    );

    final Iterable<ContentStatement> statements = distinct(
      Merger.merge(sources),
      iTransformer: (_) => identity.value,
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


  // 3. Equivalence Grouping
  final Map<ContentKey, ContentKey> subjectEquivalence = {};
  final Equivalence eqLogic = Equivalence();
  for (final ContentStatement s in filteredStatements) {
    if (s.verb == ContentVerb.equate || s.verb == ContentVerb.dontEquate) {
      final String s1 = s.subjectToken;
      final String s2 = getToken(s.other);
      assert(s1 != s2) ;
        // It's decided! 
        // - s1 is canonical, s2 equivalent.
        // - this statement is about both.
      eqLogic.process(EquateStatement(s1, s2, dont: s.verb == ContentVerb.dontEquate));
    }
  }
  final Set<EquivalenceGroup> groups = eqLogic.createGroups();
  for (final EquivalenceGroup group in groups) {
    final ContentKey canonical = ContentKey(group.canonical);
    for (final String token in group.all) {
      subjectEquivalence[ContentKey(token)] = canonical;
    }
  }

  // Tag Equivalence Grouping
  final Map<String, String> tagEquivalence = {};
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
  final Map<ContentKey, Set<ContentKey>> related = {};
  for (final ContentStatement s in filteredStatements) {
    if (s.verb == ContentVerb.relate) {
      final ContentKey s1 =
          subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
      final ContentKey s2 =
          subjectEquivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other));
      if (s1 != s2) {
        related.putIfAbsent(s1, () => {}).add(s2);
        related.putIfAbsent(s2, () => {}).add(s1);
      }
    }
  }

  // 5. Aggregation
  final Map<ContentKey, SubjectGroup> canonicalSubject2group = {};
  final Map<ContentKey, List<ContentStatement>> subject2statements = {};
  for (final s in filteredStatements) {
    final canonical = subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
    subject2statements.putIfAbsent(canonical, () => []).add(s);
    if (s.other != null) {
      final ContentKey canonicalOther =
          subjectEquivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other));
      if (canonicalOther != canonical) {
        subject2statements.putIfAbsent(canonicalOther, () => []).add(s);
      }
    }
  }

  Map<ContentKey, Json> subjectDefinitions = {};
  for (final statement in filteredStatements) {
    if (statement.subject is Map) {
      subjectDefinitions[ContentKey(statement.subjectToken)] = statement.subject as Json;
    }
    if (statement.other != null) {
      assert(statement.other is Map);
      subjectDefinitions[ContentKey(getToken(statement.other))] = statement.other as Json;
    }
  }
  Json? findSubject(ContentKey subjectKey) => subjectDefinitions[subjectKey];

  // Pass 1: Identify all canonical tokens that should be top-level subjects.
  final Set<ContentKey> topLevelSubjects = {};
  void processPass1(Iterable<ContentStatement> stmts) {
    for (final ContentStatement s in stmts) {
      if ((s.verb == ContentVerb.clear && s.subject is Map) ||
          s.verb == ContentVerb.relate ||
          s.verb == ContentVerb.dontRelate ||
          s.verb == ContentVerb.equate) {
        for (final token in s.involvedTokens) {
          topLevelSubjects.add(subjectEquivalence[ContentKey(token)] ?? ContentKey(token));
        }
      } else if (s.verb == ContentVerb.rate) {
        // Only make it a top-level subject if we have a definition for it,
        // otherwise it might be a rating-of-a-rating.
        if (s.subject is Map || subjectDefinitions.containsKey(ContentKey(s.subjectToken))) {
          topLevelSubjects.add(subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken));
        }
      }
    }
  }

  processPass1(filteredStatements);

  // Pass 2: Aggregate all statements into those subjects.
  for (final IdentityKey identity in followNetwork.identities) {
    final List<ContentStatement> statements = filteredByIdentity[identity] ?? [];
    for (final ContentStatement s in statements) {
      final List<ContentKey> tokens = s.involvedTokens
          .map((t) => subjectEquivalence[ContentKey(t)] ?? ContentKey(t))
          .toList();
      final ContentKey c1 = tokens[0];
      final ContentKey? c2 = tokens.length > 1 ? tokens[1] : null;

      for (final ContentKey canonical in tokens.toSet()) {
        // Only aggregate if this canonical token is a top-level subject.
        if (!topLevelSubjects.contains(canonical)) continue;

        SubjectGroup? group = canonicalSubject2group[canonical];
        if (group == null) {
          group = SubjectGroup(
            canonical: canonical,
            lastActivity: s.time,
          );
          canonicalSubject2group[canonical] = group;
        }

        // Update stats
        int likes = group.likes;
        int dislikes = group.dislikes;
        if (s.verb == ContentVerb.rate) {
          if (s.like == true) likes++;
          if (s.like == false) dislikes++;
        }

        // Update related
        final Set<ContentKey> relatedSet = Set.from(group.related);
        if (s.verb == ContentVerb.relate) {
          if (canonical == c1 && c2 != null) {
            relatedSet.add(c2);
          } else if (canonical == c2) {
            relatedSet.add(c1);
          }
        }

        final IdentityKey signerIdentity =
            delegateResolver.getIdentityForDelegate(DelegateKey(s.iToken))!;
        assert(trustGraph.isTrusted(signerIdentity));

        List<ContentStatement> newPovStatements = group.povStatements;
        if (signerIdentity == followNetwork.povIdentity) {
          newPovStatements = [...newPovStatements, s]..sort((a, b) => b.time.compareTo(a.time));
        }

        final DateTime lastActivity = s.time.isAfter(group.lastActivity) ? s.time : group.lastActivity;

        // Update the aggregation
        canonicalSubject2group[canonical] = SubjectGroup(
          canonical: canonical,
          // TODO: We shouldn't sort.
          statements: [...group.statements, s]..sort((a, b) => b.time.compareTo(a.time)),
          tags: group.tags, // Will be updated in Pass 3
          likes: likes,
          dislikes: dislikes,
          lastActivity: lastActivity,
          related: relatedSet,
          myDelegateStatements: group.myDelegateStatements,
          povStatements: newPovStatements,
          isCensored: censored.contains(canonical.value) || censored.contains(s.subjectToken),
        );
      }
    }
  }
  // QUESTIONABLE.. This is hard to implement, and I'm not sure if the app is more correct
  // with or without this feature (of having my own delegates impact a view that I'm not a part of).
  // If I'm viewing as PoV, and in that PoV A=>B is known, and I've thumbed A, then should I or shouldn't 
  // I see it (or B) thumbed by me? Shouldn't I see it thumbed the same way PoV would?
  // Decided!
  // - I should see it thumbed the same way PoV would. 
  // - I should only see the impact of my stament when I rate (or ralate) the same exact subject
  //   that I already have regardless of equivalence.
  // - All we'd need for that is to gather my own delegate statements (merged if have multiple) by key.

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
  // and overlay them into the `myStatements` map (and subsequent `SubjectAggregation` proxies).
  //
  // This ensures:
  // 1. Purity of the PoV's view (no pollution from untrusted "Me").
  // 2. Availability of "Me's" data for UI widgets.
  //
  // Pass 2b: Aggregate My Statements (For UI Overlays)
  // - This isn't just for RateDialog, it should also support RelateDialog whatever we use to edit/issue Follow.
  // - The outcome needs to remain: singular disposition and sorted (we merge, we don't sort).
  // - We should not canonicalize the subject here. If we have A=>B, you still need to know what you said about each.
  final List<Iterable<ContentStatement>> mySources = meDelegateKeys
      ?.map((k) => contentResult.delegateContent[k]) // returns Iterable?
      .whereType<Iterable<ContentStatement>>()      // skips nulls, returns Iterable (non-nullable)
      .toList() ?? [];

  // Map/Reduce:
  // 1. Merge sources into one sorted timeline.
  // 2. Distinct them to collapse delegate-specific redundancy.
  // 3. Fold and Map into a subject-keyed map of unmodifiable lists.
  // - We key by canonical token to enforce "Singular Disposition" at the group level.
  final Map<ContentKey, List<ContentStatement>> myStatements = distinct(
    Merger.merge(mySources),
    iTransformer: (_) => 'me', // like signInState.identity, but hard coded.
  ).cast<ContentStatement>().fold<Map<ContentKey, List<ContentStatement>>>({}, (map, s) {
    for (final token in s.involvedTokens) {
      final canonical = subjectEquivalence[ContentKey(token)] ?? ContentKey(token);
      map.putIfAbsent(canonical, () => [s]);
    }
    return map;
  }).map((k, v) => MapEntry(k, List.unmodifiable(v)));

  // Pass 3: Recursive Tag Collection and Most Frequent Tags
  final MostStrings mostStrings = MostStrings({});

  Set<String> collectTagsRecursive(ContentKey token, Set<ContentKey> visited) {
    if (visited.contains(token)) return {};
    visited.add(token);

    final Set<String> tags = {};

    // Tags from the subject itself if it has a comment
    final subject = findSubject(token);
    if (subject != null && subject['comment'] != null) {
      tags.addAll(extractTags(subject['comment']));
    }

    // Tags from statements about this token
    for (final s in subject2statements[token] ?? []) {
      if (s.comment != null) {
        tags.addAll(extractTags(s.comment!));
      }
      tags.addAll(collectTagsRecursive(ContentKey(s.token), visited));
    }
    return tags;
  }

  for (final group in canonicalSubject2group.values.toList()) {
    final Set<String> recursiveTags = collectTagsRecursive(group.canonical, {});
    canonicalSubject2group[group.canonical] = SubjectGroup(
      canonical: group.canonical,
      statements: group.statements,
      tags: recursiveTags,
      likes: group.likes,
      dislikes: group.dislikes,
      lastActivity: group.lastActivity,
      related: group.related,
      myDelegateStatements: group.myDelegateStatements,
      povStatements: group.povStatements,
      isCensored: group.isCensored,
    );

    mostStrings.process(recursiveTags);
  }

  // Pass 4: Final flavored aggregation Map.
  // We create a SubjectAggregation for EVERY literal token we know about.
  final Map<ContentKey, SubjectAggregation> subjects = {};
  for (final entry in subjectDefinitions.entries) {
    final token = entry.key;
    final subjectJson = entry.value;
    final canonical = subjectEquivalence[token] ?? token;
    final group = canonicalSubject2group[canonical];
    if (group != null) {
      subjects[token] = SubjectAggregation(
        subject: subjectJson,
        group: group,
      );
    }
  }

  // Ensure that even tokens without definitions but with group data are included
  // (using their token value as title if needed).
  for (final group in canonicalSubject2group.values) {
     if (!subjects.containsKey(group.canonical)) {
        subjects[group.canonical] = SubjectAggregation(
           subject: {'title': labeler.getLabel(group.canonical.value), 'contentType': 'unknown'},
           group: group,
        );
     }
  }

  final List<String> mostTags = mostStrings.most().toList();

  return ContentAggregation(
    statements: filteredStatements,
    censored: censored,
    equivalence: subjectEquivalence,
    related: related,
    tagEquivalence: tagEquivalence,
    mostTags: mostTags,
    subjects: subjects,
    myStatements: myStatements,
  );
}
