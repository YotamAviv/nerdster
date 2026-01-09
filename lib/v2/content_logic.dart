import 'package:nerdster/most_strings.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/tag.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/delegates.dart';
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
      transformer: (_) => identity.value,
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

  // QUESTIONABLE.. This is hard to do, and I'm not sure if it's better with or without this feature.
  // If I'm viewing as PoV, and in that  PoV A=>B, and I've thumbed A, then should I or shouldn't 
  // I see it thumbed by me? Shouldn't I see it thumbed by PoV?
  // TODO: B. I should see it thumbed by PoV. I should only see the impact of my stament when I rate (or ralate) the same exact thing that I already have.
  // All we'd need for that is to gather my own statements by key.

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
  final List<Iterable<ContentStatement>> mySources = [];

  if (meDelegateKeys != null) {
    for (final DelegateKey key in meDelegateKeys) {
      if (contentResult.delegateContent.containsKey(key)) {
        mySources.add(contentResult.delegateContent[key]!);
      } else {
        print('reduceContentAggregation: meDelegateKey ${key.value} not found in byToken');
      }
    }
  }

  if (mySources.isNotEmpty) {
    final Iterable<ContentStatement> statements = Merger.merge(mySources);
    for (final ContentStatement s in statements) {
      // Note: We DO include follow statements here so they appear in NodeDetails
      if (enableCensorship) {
        if (censored.contains(s.token)) continue;
        if (censored.contains(s.subjectToken)) continue;
        if (s.other != null && censored.contains(getToken(s.other))) continue;
      }
      myFilteredStatements.add(s);
    }
  }

  // 3. Equivalence Grouping
  final Map<ContentKey, ContentKey> subjectEquivalence = {};
  final Equivalence eqLogic = Equivalence();
  for (final ContentStatement s in filteredStatements) {
    if (s.verb == ContentVerb.equate || s.verb == ContentVerb.dontEquate) {
      final String s1 = s.subjectToken;
      final String s2 = getToken(s.other);
      assert(s1 != s2);
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
      assert(s1 != s2);
      related.putIfAbsent(s1, () => {}).add(s2);
      related.putIfAbsent(s2, () => {}).add(s1);
    }
  }

  // 5. Aggregation
  final Map<ContentKey, SubjectAggregation> subjects = {};
  // TODO: Be clear: Is by canonical token or original token or all merged (it looks like all merged)?
  final Map<ContentKey, List<ContentStatement>> statementsBySubject = {};
  for (final s in filteredStatements) {
    final canonical = subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
    statementsBySubject.putIfAbsent(canonical, () => []).add(s);
    if (s.other != null) {
      final ContentKey canonicalOther =
          subjectEquivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other));
      statementsBySubject.putIfAbsent(canonicalOther, () => []).add(s);
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
      final ContentKey canonical1 =
          subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
      final ContentKey? canonical2 = s.other != null
          ? (subjectEquivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other)))
          : null;

      if ((s.verb == ContentVerb.clear && s.subject is Map) ||
          s.verb == ContentVerb.rate ||
          s.verb == ContentVerb.relate ||
          s.verb == ContentVerb.dontRelate ||
          s.verb == ContentVerb.equate) {
        topLevelSubjects.add(canonical1);
        if (canonical2 != null) {
          topLevelSubjects.add(canonical2);
        }
      }
    }
  }

  processPass1(filteredStatements);
  processPass1(myFilteredStatements);

  // Pass 2: Aggregate all statements into those subjects.
  for (final IdentityKey identity in followNetwork.identities) {
    final List<ContentStatement> statements = filteredByIdentity[identity] ?? [];
    for (final ContentStatement s in statements) {
      final ContentKey canonical1 =
          subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
      final ContentKey? canonical2 = s.other != null
          ? (subjectEquivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other)))
          : null;

      final List<ContentKey> targets = [canonical1];
      if (canonical2 != null && canonical2 != canonical1) {
        targets.add(canonical2);
      }

      for (final ContentKey canonical in targets) {
        // Only aggregate if this canonical token is a top-level subject.
        if (!topLevelSubjects.contains(canonical)) continue;

        SubjectAggregation? agg = subjects[canonical];
        if (agg == null) {
          Json? subject = findSubject(canonical);
          // If we can't find a subject, skip it.
          // This can happen if the subject is only referenced in "other"
          // but we have no statements that define it.
          if (subject == null) continue;

          agg = SubjectAggregation(
            canonicalTokenIn: canonical,
            subject: subject,
            lastActivity: s.time,
          );
          subjects[canonical] = agg;
        }

        // Update stats
        int likes = agg.likes;
        int dislikes = agg.dislikes;
        if (s.verb == ContentVerb.rate) {
          if (s.like == true) likes++;
          if (s.like == false) dislikes++;
        }

        // Update related
        final Set<ContentKey> relatedSet = Set.from(agg.related);
        if (s.verb == ContentVerb.relate) {
          if (canonical == canonical1 && canonical2 != null) {
            relatedSet.add(canonical2);
          } else if (canonical == canonical2) {
            relatedSet.add(canonical1);
          }
        }

        final IdentityKey signerIdentity =
            delegateResolver.getIdentityForDelegate(DelegateKey(s.iToken))!;
        assert(trustGraph.isTrusted(signerIdentity));

        List<ContentStatement> newPovStatements = agg.povStatements;
        if (signerIdentity == followNetwork.povIdentity) {
          newPovStatements = [...newPovStatements, s]..sort((a, b) => b.time.compareTo(a.time));
        }

        final DateTime lastActivity = s.time.isAfter(agg.lastActivity) ? s.time : agg.lastActivity;

        // Update the aggregation
        subjects[canonical] = SubjectAggregation(
          canonicalTokenIn: canonical,
          subject: agg.subject,
          // TODO: We shouldn't sort.
          statements: [...agg.statements, s]..sort((a, b) => b.time.compareTo(a.time)),
          tags: agg.tags, // Will be updated in Pass 3
          likes: likes,
          dislikes: dislikes,
          lastActivity: lastActivity,
          related: relatedSet,
          myDelegateStatements: agg.myDelegateStatements,
          povStatements: newPovStatements,
          isCensored: censored.contains(canonical.value) || censored.contains(s.subjectToken),
        );
      }
    }
  }

  // Pass 2b: Aggregate My Statements
  for (final ContentStatement s in myFilteredStatements) {
    final ContentKey canonical1 =
        subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken);
    final ContentKey? canonical2 = s.other != null
        ? (subjectEquivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other)))
        : null;

    final List<ContentKey> targets = [canonical1];
    if (canonical2 != null && canonical2 != canonical1) {
      targets.add(canonical2);
    }

    for (final ContentKey canonical in targets) {
      // Only aggregate if this canonical token is a top-level subject.
      if (!topLevelSubjects.contains(canonical)) continue;

      // If the subject doesn't exist in the aggregation (because PoV doesn't see it),
      // we create it if we have statements about it (e.g. I follow it).
      // But we initialize it with empty statements so it doesn't pollute the feed.
      SubjectAggregation? agg = subjects[canonical];
      if (agg == null) {
        // Find best definition from me (if available) or fallback
        Json subjectContent;
        if (s.subject is Map && s.subjectToken == canonical.value) {
          subjectContent = s.subject as Json;
        } else {
          Json? tmp = findSubject(canonical);
          if (tmp == null) {
            // If we can't find a definition for this subject, skip it.
            // This can happen if the subject is only referenced in "other"
            // but we have no statements that define it.
            continue;
          }
          subjectContent = tmp;
        }
        assert(getToken(subjectContent) == canonical.value, "was curious, seems to pass..");
        agg = SubjectAggregation(
          canonicalTokenIn: canonical,
          subject: subjectContent,
          lastActivity: s.time,
        );
        subjects[canonical] = agg;
      }

      // Update myDelegateStatements
      List<ContentStatement> myDelegateStatements = agg.myDelegateStatements;

      if (s.verb == ContentVerb.clear) {
        // Clear all my previous statements on this subject
        myDelegateStatements = [];
      } else {
        myDelegateStatements = [...myDelegateStatements, s]
          ..sort((a, b) => b.time.compareTo(a.time));
      }

      subjects[canonical] = SubjectAggregation(
        canonicalTokenIn: canonical,
        subject: agg.subject,
        statements: agg.statements,
        tags: agg.tags,
        likes: agg.likes,
        dislikes: agg.dislikes,
        lastActivity: agg.lastActivity,
        related: agg.related,
        myDelegateStatements: myDelegateStatements,
        povStatements: agg.povStatements,
        isCensored: agg.isCensored,
      );
    }
  }

  // Pass 3: Recursive Tag Collection and Most Frequent Tags
  final MostStrings mostStrings = MostStrings({});

  Set<String> collectTagsRecursive(ContentKey token, Set<ContentKey> visited) {
    if (visited.contains(token)) return {};
    visited.add(token);

    final Set<String> tags = {};

    // Tags from the subject itself if it has a comment
    final subject = Jsonish.find(token.value);
    if (subject != null && subject['comment'] != null) {
      tags.addAll(extractTags(subject['comment']));
    }

    // Tags from statements about this token
    for (final s in statementsBySubject[token] ?? []) {
      if (s.comment != null) {
        tags.addAll(extractTags(s.comment!));
      }
      tags.addAll(collectTagsRecursive(ContentKey(s.token), visited));
    }
    return tags;
  }

  for (final agg in subjects.values.toList()) {
    final Set<String> recursiveTags = collectTagsRecursive(agg.canonical, {});
    subjects[agg.canonical] = SubjectAggregation(
      canonicalTokenIn: agg.canonical,
      subject: agg.subject,
      statements: agg.statements,
      tags: recursiveTags,
      likes: agg.likes,
      dislikes: agg.dislikes,
      lastActivity: agg.lastActivity,
      related: agg.related,
      myDelegateStatements: agg.myDelegateStatements,
      povStatements: agg.povStatements,
      isCensored: agg.isCensored,
    );

    mostStrings.process(recursiveTags);
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
  );
}
