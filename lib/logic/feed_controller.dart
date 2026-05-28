import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nerdster/config.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/logic/content_logic.dart';
import 'package:nerdster/logic/content_pipeline.dart';
import 'package:nerdster/logic/delegates.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/logic/trust_logic.dart';
import 'package:nerdster_common/trust_pipeline.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/models/equivalence_statement.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/dialogs/lgtm.dart';
import 'package:nerdster/utils/most_strings.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';

class FeedController extends ValueNotifier<FeedModel?> {
  final StatementChannel<TrustStatement> trustSource;
  final StatementChannel<ContentStatement> contentSource;
  final StatementChannel<DismissStatement> disSource;
  final StatementChannel<EquivalenceStatement> equivSource;
  final StatementChannel<ContentStatement> _peerContentChannel;
  final StatementChannel<EquivalenceStatement> _peerEquivChannel;
  final VoidCallback? _optimisticConcurrencyFunc;

  /// Pushes a new content statement through the write-through cache.
  /// Handles LGTM check, Writing, Caching, and UI Update (Partial Refresh).
  /// Returns the posted statement if successful, or null if cancelled (LGTM).
  Future<ContentStatement?> push(Json json, StatementSigner signer,
      {required BuildContext context}) async {
    final FeedModel? model = value;
    if (model == null) return null; // Cannot push if feed not loaded

    // 1. LGTM Check
    if (await Lgtm.check(json, context,
            labeler: model.labeler, overlayState: Overlay.of(context)) !=
        true) {
      return null;
    }

    // 2. Write & Cache
    try {
      final ContentStatement statement = await contentSource.push(json, signer,
          optimisticConcurrencyFailed: _optimisticConcurrencyFunc);
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

  Future<void> pushEquivalence(String equivalent, String canonical,
      {EquivalenceVerb verb = EquivalenceVerb.equate, required BuildContext context}) async {
    final FeedModel? model = value;
    if (model == null) return;
    final delegateJson = signInState.delegatePublicKeyJson;
    final signer = signInState.signer;
    if (delegateJson == null || signer == null) return;
    final Json json = EquivalenceStatement.make(delegateJson, equivalent, canonical, verb: verb);
    if (await Lgtm.check(json, context,
            labeler: model.labeler, overlayState: Overlay.of(context)) !=
        true) return;
    try {
      await equivSource.push(json, signer);
      unawaited(notify());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error publishing equivalence: $e')));
      }
    }
  }

  FeedController({
    VoidCallback? optimisticConcurrencyFunc,
  })  : trustSource = channelFactory.getChannel<TrustStatement>(kNativeUrl, 'statements'),
        contentSource = channelFactory.getChannel<ContentStatement>(kNerdsterExportUrl, 'statements'),
        disSource = channelFactory.getChannel<DismissStatement>(kNerdsterExportUrl, 'statements'),
        equivSource = channelFactory.getChannel<EquivalenceStatement>(kNerdsterExportUrl, 'statements'),
        _peerContentChannel = channelFactory.getChannel<ContentStatement>(kNerdsterExportUrl, 'statements', excludeTypes: ['org.nerdster.dis']),
        _peerEquivChannel = channelFactory.getChannel<EquivalenceStatement>(kNerdsterExportUrl, 'statements', excludeTypes: ['org.nerdster.dis']),
        _optimisticConcurrencyFunc = optimisticConcurrencyFunc,
        super(null) {
    _lastIdentity = signInState.hasIdentity ? signInState.identity : null;
    _lastPov = signInState.povNotifier.value;
    _lastDelegate = signInState.delegate;
    Setting.get(SettingType.identityPathsReq).notifier.addListener(_onSettingChanged);
    signInState.addListener(_onSignInStateChanged);
    Setting.get(SettingType.fcontext).notifier.addListener(_onSettingChanged);

    Setting.get(SettingType.sort).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.dis).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.tag).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.contentType).notifier.addListener(_onDisplaySettingChanged);
    Setting.get(SettingType.censor).notifier.addListener(_onSettingChanged);
  }

  IdentityKey? _lastIdentity;
  String? _lastPov;
  String? _lastDelegate;

  bool _seedingEnabled = true;
  int _lastOouMs = 0;
  int _lastDelegateMs = 0;
  int _lastCfFetchMs = 0;

  void _onSignInStateChanged() {
    final currentIdentity = signInState.hasIdentity ? signInState.identity : null;
    final currentPov = signInState.povNotifier.value;
    final currentDelegate = signInState.delegate;

    final identityChanged = currentIdentity != _lastIdentity;
    final povChanged = currentPov != _lastPov;
    final delegateChanged = currentDelegate != _lastDelegate;

    _lastIdentity = currentIdentity;
    _lastPov = currentPov;
    _lastDelegate = currentDelegate;

    if (identityChanged || delegateChanged) {
      refresh();
    } else if (povChanged) {
      notify();
    }
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
    signInState.removeListener(_onSignInStateChanged);
    Setting.get(SettingType.fcontext).notifier.removeListener(_onSettingChanged);

    Setting.get(SettingType.sort).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.dis).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.tag).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.contentType).notifier.removeListener(_onDisplaySettingChanged);
    Setting.get(SettingType.censor).notifier.removeListener(_onSettingChanged);
    super.dispose();
  }

  bool _loading = false;
  bool _reloadPending = false;
  bool get loading => _loading;

  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<String?> loadingMessage = ValueNotifier(null);

  String? _error;
  String? get error => _error;

  SortMode get sortMode {
    final val = Setting.get(SettingType.sort).value as String;
    return SortMode.values.firstWhere((e) => e.name == val, orElse: () => SortMode.recentActivity);
  }

  set sortMode(SortMode mode) {
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

    value = FeedModel(
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
      systemNotifications: value!.systemNotifications,
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
      case SortMode.recentActivity:
        // CONSIDER: Might be already sorted by lastActivity descending via the aggregation subjects map.
        subjects.sort((a, b) {
          return b.lastActivity.compareTo(a.lastActivity);
        });
        break;
      case SortMode.netLikes:
        subjects.sort((a, b) {
          final scoreA = a.likes - a.dislikes;
          final scoreB = b.likes - b.dislikes;
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          return b.lastActivity.compareTo(a.lastActivity);
        });
        break;
      case SortMode.mostComments:
        subjects.sort((a, b) {
          if (a.comments != b.comments) return b.comments.compareTo(a.comments);
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
      final String canonicalFilter = aggregation.tagEquivalence[tagFilter] ?? tagFilter;
      final Set<String> matchCanonicals = {
        canonicalFilter,
        ...aggregation.tagRelate.peersOf(canonicalFilter)
            .map((p) => aggregation.tagEquivalence[p] ?? p),
      };
      final bool hasTag = subject.tags
          .any((t) => matchCanonicals.contains(aggregation.tagEquivalence[t] ?? t));
      if (!hasTag) return false;
    }

    switch (mode) {
      case DisFilterMode.my:
        final myDis = aggregation.myDismissStatements[subject.canonical] ?? [];
        return !SubjectGroup.checkIsDismissed(myDis, subject);
      case DisFilterMode.ignore:
        return true;
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      trustSource.clear(),
      contentSource.clear(),
      _peerContentChannel.clear(),
    ]);
    return _load();
  }

  Future<void> notify() {
    return _load(showLoading: false);
  }

  Future<void> _seedFromCF(String povToken, String pathRequirement) async {
    if (!_seedingEnabled) return;
    if (channelFactory.fireChoice == FireChoice.fake) return;
    try {
      final sw = Stopwatch()..start();
      final uri = Uri.parse(FirebaseConfig.nerdsterSeedNerdsterUrl).replace(queryParameters: {
        'povToken': povToken,
        'pathRequirement': pathRequirement,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final fetchMs = sw.elapsedMilliseconds;
      _lastCfFetchMs = fetchMs;
      if (response.statusCode != 200) {
        debugPrint('[seed] CF returned ${response.statusCode} after ${fetchMs}ms');
        return;
      }

      final bag = jsonDecode(response.body) as Map<String, dynamic>;
      channelFactory.loadSeedBag(bag);
      debugPrint('[seed] CF fetch=${fetchMs}ms  bag=${bag.length} keys');
    } catch (e) {
      debugPrint('[seed] failed, falling back to direct fetch: $e');
    }
  }

  static int _median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }

  static int _average(List<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) ~/ values.length;
  }

  Future<void> runBenchmark(BuildContext context) async {
    final savedSeeding = _seedingEnabled;

    final List<int> seededTotal = [];
    final List<int> unseededTotal = [];
    final List<int> cfFetch = [];

    for (int i = 0; i < 10; i++) {
      _seedingEnabled = (i % 2 == 0);
      _lastCfFetchMs = 0;

      await channelFactory.clearAllChannelData();
      Jsonish.wipeCache();

      try {
        await _load(showLoading: false);
        final total = _lastOouMs + _lastDelegateMs;
        if (_seedingEnabled) {
          seededTotal.add(total);
          cfFetch.add(_lastCfFetchMs);
        } else {
          unseededTotal.add(total);
        }
      } catch (e) {
        debugPrint('[benchmark] run $i failed: $e');
      }
    }

    _seedingEnabled = savedSeeding;

    final String report = [
      'Total startup (ms):',
      '  Seeded:   median=${_median(seededTotal)}  avg=${_average(seededTotal)}  raw: ${seededTotal.join(', ')}',
      '  Unseeded: median=${_median(unseededTotal)}  avg=${_average(unseededTotal)}  raw: ${unseededTotal.join(', ')}',
      '',
      'CF fetch (ms):',
      '  median=${_median(cfFetch)}  avg=${_average(cfFetch)}  raw: ${cfFetch.join(', ')}',
    ].join('\n');

    debugPrint('[benchmark]\n$report');

    if (context.mounted) {
      unawaited(showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Benchmark Results'),
          content: SingleChildScrollView(
            child: SelectableText(report, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      ));
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (_loading) {
      _reloadPending = true;
      return;
    }

    _loading = true;
    loadingMessage.value = 'Starting refresh...';
    progress.value = 0;
    if (showLoading) notifyListeners();

    try {
      while (true) {
        if (signInState.povNotifier.value == null) {
          value = null;
          break;
        }

        final IdentityKey currentPovIdentity = IdentityKey(signInState.pov);
        final IdentityKey? myIdentity =
            signInState.hasIdentity ? signInState.identity : null;

        List<DelegateKey>? myDelegateKeys;
        Map<IdentityKey, TrustStatement> myTrustStatements = {};
        TrustGraph? myGraph;

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

        final swLoad = Stopwatch()..start();

        if (!trustSource.isCached(currentPovIdentity.value)) {
          await _seedFromCF(currentPovIdentity.value, identityPathsReq);
        }
        debugPrint('[load] seed phase: ${swLoad.elapsedMilliseconds}ms');

        final TrustPipeline trustPipeline = TrustPipeline(trustSource, channelFactory: channelFactory, pathRequirement: pathReq);
        final TrustGraph povGraph = await trustPipeline.build(currentPovIdentity);
        _lastOouMs = swLoad.elapsedMilliseconds;
        debugPrint('[load] OOU BFS: ${_lastOouMs}ms  (trust keys=${povGraph.distances.length})');
        final DelegateResolver delegateResolver = DelegateResolver(povGraph);

        if (myIdentity != null) {
          // Build my identity's trust graph (depth 1 only) to get:
          // 1. myTrustStatements: my literal trust/block statements, independent of PoV.
          // 2. myDelegateKeys: my delegate keys, even when not in the PoV's network.
          // trustSource is cached, so this involves no additional cloud fetch.
          // Note: replace chains for myIdentity are not chased.
          final TrustPipeline myPipeline =
              TrustPipeline(trustSource, channelFactory: channelFactory, pathRequirement: (_) => 0, maxDegrees: 1);
          myGraph = await myPipeline.build(myIdentity);
          final DelegateResolver myResolver = DelegateResolver(myGraph);

          // myTrustStatements: singular disposition (latest trust/block per subject).
          // clear statements are already filtered out by TrustPipeline.
          for (final TrustStatement s in myGraph.edges[myIdentity] ?? <TrustStatement>[]) {
            if (s.verb != TrustVerb.trust && s.verb != TrustVerb.block) continue;
            final IdentityKey subject = s.subjectAsIdentity;
            final TrustStatement? existing = myTrustStatements[subject];
            if (existing == null || s.time.isAfter(existing.time)) {
              myTrustStatements[subject] = s;
            }
          }

          // Delegates: combine what's in the PoV graph and myGraph.
          myDelegateKeys = <DelegateKey>{
            ...delegateResolver.getDelegatesForIdentity(myIdentity)
                .where((k) => delegateResolver.getDomainForDelegate(k) == kNerdsterDomain),
            ...myResolver.getDelegatesForIdentity(myIdentity)
                .where((k) => myResolver.getDomainForDelegate(k) == kNerdsterDomain),
            if (signInState.delegate != null) DelegateKey(signInState.delegate!),
          }.toList();
        }

        progress.value = 0.3;

        // 2. Content Pipeline (Delegate Layer)
        loadingMessage.value = 'Loading delegate content...';
        progress.value = 0.4;
        final contentPipeline = ContentPipeline(
          myDelegateSource: contentSource,
          peerDelegateSource: _peerContentChannel,
        );

        // Identify delegates for all trusted identities (to find follows and ratings)
        // Only nerdster.org delegates sign nerdster content statements.
        final Set<DelegateKey> delegateKeysToFetch = {};
        for (final IdentityKey trustedIdentity in povGraph.orderedKeys) {
          delegateKeysToFetch.addAll(
            delegateResolver.getDelegatesForIdentity(trustedIdentity)
                .where((k) => delegateResolver.getDomainForDelegate(k) == kNerdsterDomain),
          );
        }

        // Add my delegates
        if (myDelegateKeys != null) {
          delegateKeysToFetch.addAll(myDelegateKeys);
        }

        // Start dis + equiv fetches in parallel — both should complete before content pipeline finishes.
        final Map<String, String?> myDisFetchMap = {
          for (final k in myDelegateKeys ?? <DelegateKey>[]) k.value: null
        };
        final Future<Map<String, List<DismissStatement>>> disFuture = myDisFetchMap.isNotEmpty
            ? disSource.fetch(myDisFetchMap)
            : Future.value(const <String, List<DismissStatement>>{});

        final Set<DelegateKey> myDelegateKeySet = myDelegateKeys?.toSet() ?? {};
        final Iterable<DelegateKey> peerDelegateKeys =
            delegateKeysToFetch.where((k) => !myDelegateKeySet.contains(k));

        final Map<String, String?> myEquivFetchMap = {
          for (final k in myDelegateKeySet) k.value: null
        };
        final Map<String, String?> peerEquivFetchMap = {
          for (final k in peerDelegateKeys) k.value: null
        };
        final Future<Map<String, List<EquivalenceStatement>>> equivFuture = Future.wait([
          myEquivFetchMap.isNotEmpty
              ? equivSource.fetch(myEquivFetchMap)
              : Future.value(const <String, List<EquivalenceStatement>>{}),
          peerEquivFetchMap.isNotEmpty
              ? _peerEquivChannel.fetch(peerEquivFetchMap)
              : Future.value(const <String, List<EquivalenceStatement>>{}),
        ]).then((r) => {...r[0], ...r[1]});

        final swDelegate = Stopwatch()..start();
        final delegateContent = await contentPipeline.fetchDelegateContent(
          myDelegateKeySet,
          peerDelegateKeys,
          delegateResolver: delegateResolver,
          graph: povGraph,
        );
        final rawDisContent = await disFuture;
        final Map<DelegateKey, List<DismissStatement>> myDisContent = {
          for (final entry in rawDisContent.entries) DelegateKey(entry.key): entry.value,
        };

        final rawEquivContent = await equivFuture;
        final EquivalenceResult equivalenceResult = EquivalenceResult(
          delegateContent: {
            for (final k in delegateKeysToFetch) DelegateKey(k.value): rawEquivContent[k.value] ?? [],
          },
        );
        _lastDelegateMs = swDelegate.elapsedMilliseconds;
        debugPrint('[load] delegate content: ${_lastDelegateMs}ms (my=${myDelegateKeys?.length ?? 0} peer=${peerDelegateKeys.length} delegates)');

        final contentResult = ContentResult(
          delegateContent: delegateContent,
        );

        // 3. Follow Network
        loadingMessage.value = 'Processing follow network...';
        progress.value = 0.7;

        final followNetwork = reduceFollowNetwork(
          povGraph,
          delegateResolver,
          contentResult,
          fcontext,
        );

        progress.value = 0.8;

        // 5. Content Aggregation
        loadingMessage.value = 'Aggregating content...';
        progress.value = 0.9;

        // 6. Labeling
        final Labeler labeler =
            Labeler(povGraph, delegateResolver: delegateResolver, meIdentity: myIdentity);

        final aggregation = reduceContentAggregation(
          followNetwork,
          povGraph,
          delegateResolver,
          contentResult,
          equivalenceResult: equivalenceResult,
          enableCensorship: enableCensorship,
          meDelegateKeys: myDelegateKeys,
          myDisContent: myDisContent,
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

        for (final DelegateKey key in delegateResolver.getDelegatesForIdentity(currentPovIdentity)) {
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

        if (currentPovIdentity.value == signInState.pov &&
            myIdentity == (signInState.hasIdentity ? signInState.identity : null)) {
          final allErrors = [
            ...trustSource.errors,
            ...contentSource.errors,
          ];

          final systemNotifications = <SystemNotification>[];

          // 1. Invisibility / Unnamed
          // Note: We use the identity from the start of the refresh loop to ensure consistency
          if (myIdentity != null) {
            final bool isVisible =
                followNetwork.identities.any((k) => k.value == myIdentity!.value);

            if (!isVisible) {
              systemNotifications.add(SystemNotification(
                title: "You're invisible",
                description: "You're not in the network you're viewing.",
              ));
            }

            final IdentityKey canonicalMe = povGraph.resolveIdentity(myIdentity!);
            bool isNamed = false;

            for (final List<TrustStatement> edges in povGraph.edges.values) {
              for (final TrustStatement edge in edges) {
                if (edge.moniker != null) {
                  if (povGraph.resolveIdentity(IdentityKey(edge.subjectToken)) == canonicalMe) {
                    isNamed = true;
                    break;
                  }
                }
              }
              if (isNamed) break;
            }

            if (!isNamed) {
              systemNotifications.add(SystemNotification(
                title: "You're 'Me'",
                description: "You're 'Me' because no one has vouched for your identity.",
              ));
            }
          }

          // 2. Delegate Issues
          if (myIdentity != null && signInState.delegate != null) {
            final String myDelegate = signInState.delegate!;

            // Revoked
            if (povGraph.equivalent2canonical.containsKey(IdentityKey(myDelegate))) {
              systemNotifications.add(SystemNotification(
                title: "Your delegate key is revoked",
                description:
                    "Your current delegate key has been replaced or revoked by your identity.\n\n"
                    "You cannot perform actions (like posting or liking) until you sign in with a valid key.",
                isError: true,
              ));
            }

            // Not associated
            if (povGraph.isTrusted(myIdentity!)) {
              bool isAssociated = false;
              // Use myGraph for unfiltered delegate statements (independent of PoV's blocks).
              final List<TrustStatement> statements = myGraph?.edges[myIdentity!] ?? [];
              for (final TrustStatement s in statements) {
                if (s.verb == TrustVerb.delegate && s.subjectToken == myDelegate) {
                  isAssociated = true;
                  break;
                }
              }
              if (!isAssociated) {
                systemNotifications.add(SystemNotification(
                  title: "Delegate key not associated",
                  description: "Your current delegate key is not associated with your identity.",
                  isError: true,
                ));
              }
            }
          }

          final effectiveSubjects = _computeEffectiveSubjects(
            aggregation,
            filterMode,
            enableCensorship,
            tagFilter: tagFilter,
            typeFilter: typeFilter,
          );

          value = FeedModel(
            trustGraph: povGraph,
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
            systemNotifications: systemNotifications,
            myTrustStatements: myTrustStatements,
          );
          progress.value = 1.0;
          break;
        }
      }
    } catch (e, stack) {
      debugPrint('FeedController Error: $e\n$stack');
      _error = e.toString();
      rethrow;
    } finally {
      channelFactory.clearSeedBag();
      _loading = false;
      loadingMessage.value = null;
      notifyListeners();
      if (_reloadPending) {
        _reloadPending = false;
        unawaited(_load(showLoading: false));
      }
    }
  }
}
