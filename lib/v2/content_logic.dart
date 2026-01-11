import 'package:nerdster/most_strings.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/tag.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/merger.dart';
import 'package:nerdster/oneofus/distincter.dart';
import 'package:nerdster/oneofus/statement.dart';
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

  // 2. Collect and Filter Statements (Merge All Sources)
  final List<Iterable<ContentStatement>> identityStreams = [];
  for (final IdentityKey identity in followNetwork.identities) {
    final List<Iterable<ContentStatement>> sources = _collectSources(
      identity,
      delegateResolver,
      contentResult,
    );

    identityStreams.add(distinct(
      Merger.merge(sources),
      iTransformer: (_) => identity.value,
    ).cast<ContentStatement>());
  }

  final List<ContentStatement> filteredStatements =
      distinct(Merger.merge(identityStreams)).where((s) {
    // Filter out follow statements (they are for network building)
    if (s.verb == ContentVerb.follow) return false;
    if (s.verb == ContentVerb.clear) return false;

    // Filter censored
    if (enableCensorship) {
      if (censored.contains(s.token)) return false;
      if (censored.contains(s.subjectToken)) return false;
      if (s.other != null && censored.contains(getToken(s.other))) return false;
    }
    return true;
  }).toList();

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

  final Map<ContentKey, Json> subjectDefinitions = {};
  for (final statement in filteredStatements) {
    if (statement.subject is Map) {
      subjectDefinitions[ContentKey(statement.subjectToken)] = statement.subject as Json;
    }
    if (statement.other != null && statement.other is Map) {
      subjectDefinitions[ContentKey(getToken(statement.other))] = statement.other as Json;
    }
  }

  // TODO: The AI invented its own notion of tag processing. Restore my (the human's) intentions.
  // Tag Equivalence Grouping
  final Map<String, String> tagEquivalence = {};
  final Map<String, Set<String>> tagEdges = {};
  for (final s in filteredStatements) {
    if (s.comment != null) {
      final tags = extractTags(s.comment!).map((t) => t.toLowerCase()).toList();
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
    // TODO: Why are we sorting tags. I want them by most, there is no canonical tag.
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
  final Map<ContentKey, SubjectGroup> literalSubject2group = {};
  final Map<ContentKey, List<ContentStatement>> canonicalSubject2statements = {};
  final Map<ContentKey, List<ContentStatement>> literalSubject2statements = {};
  for (final ContentStatement s in filteredStatements) {
    final ContentKey literalSubject = ContentKey(s.subjectToken);
    final ContentKey canonical = subjectEquivalence[literalSubject] ?? literalSubject;
    canonicalSubject2statements.putIfAbsent(canonical, () => []).add(s);
    literalSubject2statements.putIfAbsent(literalSubject, () => []).add(s);
    if (s.other != null) {
      final ContentKey literalOther = ContentKey(getToken(s.other));
      final ContentKey canonicalOther = subjectEquivalence[literalOther] ?? literalOther;
      if (canonicalOther != canonical) {
        canonicalSubject2statements.putIfAbsent(canonicalOther, () => []).add(s);
      }
      literalSubject2statements.putIfAbsent(literalOther, () => []).add(s);
    }
  }

  // Pass 1: Identify all tokens that should be top-level subjects or recognized variants.
  final Set<ContentKey> topLevelSubjects = {};
  final Set<ContentKey> recognizedLiteralSubjects = {};

  for (final ContentStatement s in filteredStatements) {
    for (final String token in s.involvedTokens) {
      recognizedLiteralSubjects.add(ContentKey(token));
    }

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
        topLevelSubjects
            .add(subjectEquivalence[ContentKey(s.subjectToken)] ?? ContentKey(s.subjectToken));
      }
    }
  }

  // Pass 2: Aggregate all statements into those subjects.
  for (final ContentStatement s in filteredStatements) {
    final ContentKey literalSubject = ContentKey(s.subjectToken);
    final ContentKey canonicalSubject = subjectEquivalence[literalSubject] ?? literalSubject;

    final List<ContentKey> canonicalTokens =
        s.involvedTokens.map((t) => subjectEquivalence[ContentKey(t)] ?? ContentKey(t)).toList();
    final ContentKey c1 = canonicalTokens[0];
    final ContentKey? c2 = canonicalTokens.length > 1 ? canonicalTokens[1] : null;

    final IdentityKey signerIdentity =
        delegateResolver.getIdentityForDelegate(DelegateKey(s.iToken))!;

    void update(Map<ContentKey, SubjectGroup> map, ContentKey key, bool isCanonical) {
      if (isCanonical && !topLevelSubjects.contains(key)) return;
      if (!isCanonical && !recognizedLiteralSubjects.contains(key)) return;

      final SubjectGroup group = map[key] ??
          SubjectGroup(
            canonical: isCanonical ? key : canonicalSubject,
            lastActivity: s.time,
          );

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
        if (isCanonical) {
          if (key == c1 && c2 != null) {
            relatedSet.add(c2);
          } else if (key == c2) {
            relatedSet.add(c1);
          }
        } else {
          // For literal, we still add the CANONICAL related token
          if (key == literalSubject && s.other != null) {
            relatedSet.add(
                subjectEquivalence[ContentKey(getToken(s.other))] ?? ContentKey(getToken(s.other)));
          } else if (s.other != null && key == ContentKey(getToken(s.other))) {
            relatedSet.add(canonicalSubject);
          }
        }
      }

      List<ContentStatement> newPovStatements = group.povStatements;
      if (signerIdentity == followNetwork.povIdentity) {
        newPovStatements = [...newPovStatements, s];
      }

      final DateTime lastActivity =
          s.time.isAfter(group.lastActivity) ? s.time : group.lastActivity;

      map[key] = SubjectGroup(
        canonical: isCanonical ? key : canonicalSubject,
        statements: [...group.statements, s],
        tags: group.tags, // Will be updated in Pass 3
        likes: likes,
        dislikes: dislikes,
        lastActivity: lastActivity,
        related: relatedSet,
        povStatements: newPovStatements,
        isCensored:
            group.isCensored || censored.contains(key.value) || censored.contains(s.subjectToken),
      );
    }

    // Update Canonical map
    for (final canonical in canonicalTokens.toSet()) {
      update(canonicalSubject2group, canonical, true);
    }

    // Update Literal map
    for (final String t in s.involvedTokens) {
      update(literalSubject2group, ContentKey(t), false);
    }
  }

  // Pass 2b: Aggregate My Statements (For [RateDialog, V2RelateDialog, NodeDetails] and "My Disses")
  final List<Iterable<ContentStatement>> mySources = meDelegateKeys
          ?.map((k) => contentResult.delegateContent[k])
          .whereType<Iterable<ContentStatement>>()
          .toList() ??
      [];

  final List<ContentStatement> mergedMyStatements = distinct(
    Merger.merge(mySources),
    iTransformer: (_) => 'me',
  ).cast<ContentStatement>().toList();

  final Map<ContentKey, List<ContentStatement>> myLiteralStatements = {};
  final Map<ContentKey, List<ContentStatement>> myCanonicalDisses = {};

  for (final ContentStatement s in mergedMyStatements) {
    for (final String token in s.involvedTokens) {
      final ContentKey literalKey = ContentKey(token);
      myLiteralStatements.putIfAbsent(literalKey, () => []).add(s);

      final ContentKey canonicalKey = subjectEquivalence[literalKey] ?? literalKey;
      if (s.verb == ContentVerb.rate) {
        myCanonicalDisses.putIfAbsent(canonicalKey, () => []).add(s);
      }
    }
  }

  // Pass 3: Recursive Tag Collection and Most Frequent Tags
  final MostStrings mostStrings = MostStrings({});

  Set<String> collectTagsRecursive(ContentKey token, Set<ContentKey> visited,
      Map<ContentKey, List<ContentStatement>> statementsMap) {
    Statement.validateOrderTypess(statementsMap.values);
    if (visited.contains(token)) return {};
    visited.add(token);

    final Set<String> tags = {};

    final subject = subjectDefinitions[token];
    if (subject != null && subject['comment'] != null) {
      tags.addAll(extractTags(subject['comment']));
    }

    // Tags from statements about this token
    for (final s in statementsMap[token] ?? []) {
      if (s.comment != null) {
        tags.addAll(extractTags(s.comment!));
      }
      tags.addAll(collectTagsRecursive(ContentKey(s.token), visited, statementsMap));
    }
    return tags;
  }

  void updateTags(Map<ContentKey, SubjectGroup> targetMap,
      Map<ContentKey, List<ContentStatement>> statementsMap,
      {bool updateMostStrings = false}) {
    Statement.validateOrderTypess(statementsMap.values);
    for (final ContentKey key in targetMap.keys.toList()) {
      final SubjectGroup group = targetMap[key]!;
      final Set<String> recursiveTags = collectTagsRecursive(key, {}, statementsMap);
      targetMap[key] = group.copyWith(tags: recursiveTags);
      if (updateMostStrings) mostStrings.process(recursiveTags);
    }
  }

  updateTags(canonicalSubject2group, canonicalSubject2statements, updateMostStrings: true);

  // Pass 4: Final flavored aggregation Map.
  final Map<ContentKey, SubjectAggregation> subjects = {};

  void createAggregation(ContentKey token, Json subjectJson) {
    final ContentKey canonical = subjectEquivalence[token] ?? token;

    SubjectGroup? group = canonicalSubject2group[canonical];
    SubjectGroup? narrowGroup = literalSubject2group[token];

    if (group != null) {
      narrowGroup ??= SubjectGroup(
        canonical: canonical,
        lastActivity: group.lastActivity,
      );

      subjects[token] = SubjectAggregation(
        subject: subjectJson,
        group: group,
        narrowGroup: narrowGroup,
      );
    }
  }

  for (final MapEntry<ContentKey, Json> entry in subjectDefinitions.entries) {
    createAggregation(entry.key, entry.value);
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
    myCanonicalDisses: myCanonicalDisses,
    myLiteralStatements: myLiteralStatements,
  );
}
