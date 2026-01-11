import 'package:flutter/foundation.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/most_strings.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/trust_logic.dart';

class V2FeedController extends ValueNotifier<V2FeedModel?> {
  final CachedSource<TrustStatement> trustSource;
  final CachedSource<ContentStatement> contentSource;

  V2FeedController({
    required StatementSource<TrustStatement> trustSource,
    required StatementSource<ContentStatement> contentSource,
  })  : trustSource = CachedSource(trustSource),
        contentSource = CachedSource(contentSource),
        super(null) {
    Setting.get(SettingType.identityPathsReq).notifier.addListener(_onSettingChanged);
    signInState.povNotifier.addListener(_onPovChanged);
    Setting.get(SettingType.fcontext).notifier.addListener(_onSettingChanged);

    Setting.get(SettingType.sort).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.dis).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.tag).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.contentType).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.censor).notifier.addListener(_onCensorChanged);
  }

  void _onSettingChanged() {
    refresh(_latestRequestedPov, meIdentity: _latestRequestedMeIdentity);
  }

  void _onDisplaySettingChanged() {
    if (value != null) {
      _updateValueWithSettings();
    }
  }

  void _onCensorChanged() {
    refresh(_latestRequestedPov, meIdentity: _latestRequestedMeIdentity);
  }

  void _onPovChanged() {
    final newPov = signInState.pov;
    if (newPov != null) {
      refresh(IdentityKey(newPov), meIdentity: _latestRequestedMeIdentity);
    }
  }

  @override
  void dispose() {
    Setting.get(SettingType.identityPathsReq).notifier.removeListener(_onSettingChanged);
    signInState.povNotifier.removeListener(_onPovChanged);
    Setting.get(SettingType.fcontext).notifier.removeListener(_onSettingChanged);

    Setting.get(SettingType.sort).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.dis).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.tag).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.contentType).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.censor).notifier.removeListener(_onCensorChanged);
    super.dispose();
  }

  bool _loading = false;
  bool get loading => _loading;
  IdentityKey? _latestRequestedPov;
  IdentityKey? _latestRequestedMeIdentity;

  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<String?> loadingMessage = ValueNotifier(null);

  String? _error;
  String? get error => _error;

  V2SortMode get sortMode {
    final val = Setting.get(SettingType.sort).value as String;
    return V2SortMode.values
        .firstWhere((e) => e.name == val, orElse: () => V2SortMode.recentActivity);
  }

  set sortMode(V2SortMode mode) {
    Setting.get(SettingType.sort).value = mode.name;
  }

  V2FilterMode get filterMode {
    final val = Setting.get(SettingType.dis).value as String;
    switch (val) {
      case 'me':
        return V2FilterMode.myDisses;
      case 'ignore':
        return V2FilterMode.ignoreDisses;
      case 'pov':
      default:
        return V2FilterMode.povDisses;
    }
  }

  set filterMode(V2FilterMode mode) {
    String val;
    switch (mode) {
      case V2FilterMode.myDisses:
        val = 'me';
        break;
      case V2FilterMode.ignoreDisses:
        val = 'ignore';
        break;
      case V2FilterMode.povDisses:
        val = 'pov';
        break;
    }
    Setting.get(SettingType.dis).value = val;
  }

  String? get tagFilter {
    final val = Setting.get(SettingType.tag).value as String;
    return val == '-' ? null : val;
  }

  set tagFilter(String? tag) {
    Setting.get(SettingType.tag).value = tag ?? '-';
  }

  String? get typeFilter {
    final val = Setting.get(SettingType.contentType).value as String;
    return val == 'all' ? null : val;
  }

  set typeFilter(String? type) {
    Setting.get(SettingType.contentType).value = type ?? 'all';
  }

  bool get enableCensorship => Setting.get(SettingType.censor).value as bool;

  set enableCensorship(bool enabled) {
    Setting.get(SettingType.censor).value = enabled;
  }

  void _updateValueWithSettings() {
    if (value == null) return;

    final effectiveSubjects = _computeEffectiveSubjects(
      value!.aggregation,
      filterMode,
      enableCensorship,
      tagFilter: tagFilter,
      typeFilter: typeFilter,
    );

    value = V2FeedModel(
      trustGraph: value!.trustGraph,
      followNetwork: value!.followNetwork,
      delegateResolver: value!.delegateResolver,
      labeler: value!.labeler,
      aggregation: value!.aggregation,
      povIdentity: value!.povIdentity,
      fcontext: value!.fcontext,
      sortMode: sortMode,
      filterMode: filterMode,
      tagFilter: tagFilter,
      typeFilter: typeFilter,
      enableCensorship: enableCensorship,
      availableContexts: value!.availableContexts,
      activeContexts: value!.activeContexts,
      effectiveSubjects: effectiveSubjects,
      sourceErrors: value!.sourceErrors,
    );
  }

  List<SubjectAggregation> _computeEffectiveSubjects(
    ContentAggregation aggregation,
    V2FilterMode mode,
    bool censorshipEnabled, {
    String? tagFilter,
    String? typeFilter,
  }) {
    final List<SubjectAggregation> results = aggregation.subjects.values.where((s) {
      // Only show canonical tokens in the main feed to avoid duplicates.
      if (s.token != s.canonical) return false;

      return shouldShow(s, mode, censorshipEnabled,
          tagFilter: tagFilter, tagEquivalence: aggregation.tagEquivalence, typeFilter: typeFilter);
    }).toList();

    sortSubjects(results);
    return results;
  }

  void sortSubjects(List<SubjectAggregation> subjects) {
    switch (sortMode) {
      case V2SortMode.recentActivity:
        // CONSIDER: Might be already sorted by lastActivity descending via the aggregation subjects map.
        subjects.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
        break;
      case V2SortMode.netLikes:
        subjects.sort((a, b) {
          final scoreA = a.likes - a.dislikes;
          final scoreB = b.likes - b.dislikes;
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          return b.lastActivity.compareTo(a.lastActivity);
        });
        break;
      case V2SortMode.mostComments:
        subjects.sort((a, b) {
          final commentsA =
              a.statements.where((s) => s.comment != null && s.comment!.isNotEmpty).length;
          final commentsB =
              b.statements.where((s) => s.comment != null && s.comment!.isNotEmpty).length;
          if (commentsA != commentsB) return commentsB.compareTo(commentsA);
          return b.lastActivity.compareTo(a.lastActivity);
        });
        break;
    }
  }

  bool shouldShow(SubjectAggregation subject, V2FilterMode mode, bool censorshipEnabled,
      {String? tagFilter, Map<String, String>? tagEquivalence, String? typeFilter}) {
    // Only show subjects that exist in the PoV's feed (have statements from the PoV's network)
    if (subject.statements.isEmpty) return false;

    // Only show valid subjects with a "contentType" as top-level cards
    // This effectively filters out statements (which don't have contentType) and other non-content data
    final s = subject.subject;
    bool hasContentType = false;
    if (s.containsKey('contentType')) {
      hasContentType = true;
    }
    if (!hasContentType) return false;

    if (censorshipEnabled && subject.isCensored) return false;

    if (typeFilter != null && typeFilter != 'all') {
      String? subjectType;
      subjectType = s['contentType'];

      if (subjectType != typeFilter) {
        return false;
      }
    }

    if (tagFilter != null && tagFilter != '-') {
      final canonicalFilter = tagEquivalence?[tagFilter] ?? tagFilter;
      if (!subject.tags.any((t) => (tagEquivalence?[t] ?? t) == canonicalFilter)) {
        return false;
      }
    }

    switch (mode) {
      case V2FilterMode.myDisses:
        final myStmts = value?.aggregation.myCanonicalDisses[subject.canonical] ?? [];
        return !SubjectGroup.checkIsDismissed(myStmts, subject);
      case V2FilterMode.povDisses:
        return !subject.isDismissed;
      case V2FilterMode.ignoreDisses:
        return true;
    }
  }

  Future<void> refresh(IdentityKey? povIdentity, {IdentityKey? meIdentity}) async {
    _latestRequestedPov = povIdentity;
    _latestRequestedMeIdentity = meIdentity;

    if (_loading) {
      return;
    }

    _loading = true;
    loadingMessage.value = 'Starting refresh...';
    progress.value = 0;
    notifyListeners();

    try {
      while (true) {
        final currentPovIdentity = _latestRequestedPov;
        final currentMeIdentity = _latestRequestedMeIdentity;

        List<DelegateKey>? meDelegateKeys;

        if (currentPovIdentity == null) {
          value = null;
          break;
        }

        _error = null;
        loadingMessage.value = 'Initializing...';
        notifyListeners();

        final fcontext = Setting.get<String>(SettingType.fcontext).value;

        // Clear caches to ensure we get the latest statements (e.g. after a new like/comment)
        trustSource.clear();
        contentSource.clear();

        // 1. Trust Pipeline
        loadingMessage.value = 'Loading signed content from one-of-us.net (Trust)';
        progress.value = 0.1;

        final identityPathsReq = Setting.get<String>(SettingType.identityPathsReq).value;
        PathRequirement? pathReq;

        final reqString = pathsReq[identityPathsReq] ?? pathsReq['standard']!;

        try {
          final parts = reqString.split(RegExp(r'[-,\s]+'));
          final reqs = parts.map(int.parse).toList();
          if (reqs.isNotEmpty) {
            pathReq = (int distance) {
              final index = distance - 1;
              if (index >= 0 && index < reqs.length) return reqs[index];
              return reqs.last;
            };
          }
        } catch (e) {
          debugPrint('Error parsing identityPathsReq: $e');
        }

        final trustPipeline = TrustPipeline(trustSource, pathRequirement: pathReq);
        final graph = await trustPipeline.build(currentPovIdentity);
        final delegateResolver = DelegateResolver(graph);

        // Fix for view-only mode where signInState.delegate is null but the identity has delegates in the graph
        if (currentMeIdentity != null && currentMeIdentity.value == signInState.identity) {
          final Set<DelegateKey> delegates = {};

          // 1. Try to find delegates in the current PoV graph
          delegates.addAll(delegateResolver.getDelegatesForIdentity(currentMeIdentity));

          // 2. If Me is not in the graph, we need to fetch Me's trust statements to find delegates.
          if (!graph.distances.containsKey(currentMeIdentity)) {
            // Use a separate pipeline to fetch Me's graph (depth 0)
            // We reuse the same trustSource (which is cached)
            final mePipeline = TrustPipeline(trustSource, pathRequirement: (_) => 0);
            final meGraph = await mePipeline.build(currentMeIdentity);
            final meResolver = DelegateResolver(meGraph);
            final fetchedDelegates = meResolver.getDelegatesForIdentity(currentMeIdentity);
            delegates.addAll(fetchedDelegates);
          }

          // Ensure the currently signed-in delegate is included, even if not in the graph
          // We convert the string delegate to a DelegateKey to check/add
          if (currentMeIdentity.value == signInState.identity && signInState.delegate != null) {
            delegates.add(DelegateKey(signInState.delegate!));
          }

          meDelegateKeys = delegates.toList();
        }

        progress.value = 0.3;

        // 2. Content Pipeline (Delegate Layer)
        loadingMessage.value = 'Loading delegate content...';
        progress.value = 0.4;
        final contentPipeline = ContentPipeline(
          delegateSource: contentSource,
        );

        // Identify delegates for all trusted identities (to find follows and ratings)
        final Set<DelegateKey> delegateKeysToFetch = {};
        for (final identity in graph.orderedKeys) {
          final delegates = delegateResolver.getDelegatesForIdentity(identity);
          delegateKeysToFetch.addAll(delegates);
        }

        // Add my delegates
        if (meDelegateKeys != null) {
          delegateKeysToFetch.addAll(meDelegateKeys);
        }

        final delegateContent = await contentPipeline.fetchDelegateContent(
          delegateKeysToFetch,
          delegateResolver: delegateResolver,
          graph: graph,
        );

        final contentResult = ContentResult(
          delegateContent: delegateContent,
        );

        // 3. Follow Network
        loadingMessage.value = 'Processing follow network...';
        progress.value = 0.7;

        final followNetwork = reduceFollowNetwork(
          graph,
          delegateResolver,
          contentResult,
          fcontext,
        );

        progress.value = 0.8;

        // 5. Content Aggregation
        loadingMessage.value = 'Aggregating content...';
        progress.value = 0.9;

        // 6. Labeling
        final labeler =
            V2Labeler(graph, delegateResolver: delegateResolver, meIdentity: currentMeIdentity);

        final aggregation = reduceContentAggregation(
          followNetwork,
          graph,
          delegateResolver,
          contentResult,
          enableCensorship: enableCensorship,
          meDelegateKeys: meDelegateKeys,
          labeler: labeler,
        );
        progress.value = 0.95;

        // 7. Finalizing
        loadingMessage.value = 'Finalizing...';

        // 6. Contexts
        final mostContexts = MostStrings({kFollowContextIdentity, kFollowContextNerdster});
        for (final statements in contentResult.delegateContent.values) {
          for (final s in statements) {
            if (s.verb == ContentVerb.follow && s.contexts != null) {
              mostContexts.process(s.contexts!.keys);
            }
          }
        }
        final availableContexts = mostContexts.most().toList();

        final activeContexts = <String>{};
        final povIdentity = graph.pov;

        for (final DelegateKey key in delegateResolver.getDelegatesForIdentity(povIdentity)) {
          final statements = contentResult.delegateContent[key];
          if (statements != null) {
            for (final s in statements) {
              if (s.verb == ContentVerb.follow && s.contexts != null) {
                activeContexts
                    .addAll(s.contexts!.entries.where((e) => e.value > 0).map((e) => e.key));
              }
            }
          }
        }

        if (_latestRequestedPov == currentPovIdentity &&
            _latestRequestedMeIdentity == currentMeIdentity) {
          final allErrors = [
            ...trustSource.errors,
            ...contentSource.errors,
          ];

          final effectiveSubjects = _computeEffectiveSubjects(
            aggregation,
            filterMode,
            enableCensorship,
            tagFilter: tagFilter,
            typeFilter: typeFilter,
          );

          value = V2FeedModel(
            trustGraph: graph,
            followNetwork: followNetwork,
            delegateResolver: delegateResolver,
            labeler: labeler,
            aggregation: aggregation,
            povIdentity: currentPovIdentity,
            fcontext: fcontext,
            sortMode: sortMode,
            filterMode: filterMode,
            tagFilter: tagFilter,
            typeFilter: typeFilter,
            enableCensorship: enableCensorship,
            availableContexts: availableContexts,
            activeContexts: activeContexts,
            effectiveSubjects: effectiveSubjects,
            sourceErrors: allErrors,
          );
          progress.value = 1.0;
          break;
        }
      }
    } catch (e, stack) {
      debugPrint('V2FeedController Error: $e\n$stack');
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      loadingMessage.value = null;
      notifyListeners();
    }
  }
}
