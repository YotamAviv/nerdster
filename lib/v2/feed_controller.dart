import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/lgtm.dart';
import 'package:nerdster/most_strings.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/trust_logic.dart';

class V2FeedController extends ValueNotifier<V2FeedModel?> {
  final CachedSource<TrustStatement> trustSource;
  final CachedSource<ContentStatement> contentSource;

  /// Pushes a new content statement through the write-through cache.
  /// Handles LGTM check, Writing, Caching, and UI Update (Partial Refresh).
  /// Returns the posted statement if successful, or null if cancelled (LGTM).
  Future<Statement?> push(Json json, StatementSigner signer,
      {required BuildContext context}) async {
    final model = value;
    if (model == null) return null; // Cannot push if feed not loaded

    // 1. LGTM Check
    if (await Lgtm.check(json, context, labeler: model.labeler) != true) {
      return null;
    }

    // 2. Write & Cache
    try {
      final statement = await contentSource.push(json, signer);
      // 3. Update UI (Partial Refresh)
      notify();
      return statement;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error publishing: $e')));
      }
      rethrow;
    }
  }

  V2FeedController({
    required StatementSource<TrustStatement> trustSource,
    required StatementSource<ContentStatement> contentSource,
  })  : trustSource = CachedSource(trustSource, SourceFactory.getWriter(kOneofusDomain)),
        contentSource = CachedSource(contentSource, SourceFactory.getWriter(kNerdsterDomain)),
        super(null) {
    Setting.get(SettingType.identityPathsReq).notifier.addListener(_onSettingChanged);
    signInState.povNotifier.addListener(_onSettingChanged);
    Setting.get(SettingType.fcontext).notifier.addListener(_onSettingChanged);

    Setting.get(SettingType.sort).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.dis).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.tag).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.contentType).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.censor).notifier.addListener(_onSettingChanged);
  }

  void _onSettingChanged() {
    notify();
  }

  void _onDisplaySettingChanged() {
    if (value != null) {
      _updateValueWithSettings();
    }
  }

  @override
  void dispose() {
    Setting.get(SettingType.identityPathsReq).notifier.removeListener(_onSettingChanged);
    signInState.povNotifier.removeListener(_onSettingChanged);
    Setting.get(SettingType.fcontext).notifier.removeListener(_onSettingChanged);

    Setting.get(SettingType.sort).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.dis).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.tag).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.contentType).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.censor).notifier.removeListener(_onSettingChanged);
    super.dispose();
  }

  bool _loading = false;
  bool get loading => _loading;

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

  DisFilterMode get filterMode {
    return DisFilterMode.fromString(Setting.get(SettingType.dis).value as String);
  }

  set filterMode(DisFilterMode mode) {
    Setting.get(SettingType.dis).value = mode.name;
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

  ValueNotifier<bool> get enableCensorshipNotifier =>
      Setting.get<bool>(SettingType.censor).notifier;

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
    DisFilterMode mode,
    bool censorshipEnabled, {
    String? tagFilter,
    String? typeFilter,
  }) {
    final List<SubjectAggregation> results = aggregation.subjects.values.where((s) {
      // Only show canonical tokens in the main feed to avoid duplicates.
      if (s.token != s.canonical) return false;

      return shouldShow(s, mode, censorshipEnabled,
          tagFilter: tagFilter, typeFilter: typeFilter, aggregation: aggregation);
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

  bool shouldShow(SubjectAggregation subject, DisFilterMode mode, bool censorshipEnabled,
      {String? tagFilter, String? typeFilter, required ContentAggregation aggregation}) {
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
      final canonicalFilter = aggregation.tagEquivalence[tagFilter] ?? tagFilter;
      if (!subject.tags.any((t) => (aggregation.tagEquivalence[t] ?? t) == canonicalFilter)) {
        return false;
      }
    }

    switch (mode) {
      case DisFilterMode.my:
        final myStmts = aggregation.myCanonicalDisses[subject.canonical] ?? [];
        return !SubjectGroup.checkIsDismissed(myStmts, subject);
      case DisFilterMode.pov:
        return !subject.isDismissed;
      case DisFilterMode.ignore:
        return true;
    }
  }

  Future<void> refresh() {
    trustSource.clear();
    contentSource.clear();
    return _load();
  }

  Future<void> notify() {
    return _load(showLoading: false);
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_loading) {
      return;
    }

    _loading = true;
    loadingMessage.value = 'Starting refresh...';
    progress.value = 0;
    if (showLoading) notifyListeners();

    try {
      while (true) {
        if (!signInState.isSignedIn && signInState.povNotifier.value == null) {
          value = null;
          break;
        }

        final IdentityKey currentPovIdentity = IdentityKey(signInState.pov);
        final IdentityKey? currentMeIdentity =
            signInState.isSignedIn ? IdentityKey(signInState.identity) : null;

        List<DelegateKey>? meDelegateKeys;

        _error = null;
        loadingMessage.value = 'Initializing...';
        if (showLoading) notifyListeners();

        final fcontext = Setting.get<String>(SettingType.fcontext).value;

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

        if (currentPovIdentity == IdentityKey(signInState.pov) &&
            currentMeIdentity?.value == (signInState.isSignedIn ? signInState.identity : null)) {
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
