import 'package:flutter/foundation.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/trust_logic.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/most_strings.dart';
import 'package:nerdster/singletons.dart';

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
  }

  void _onSettingChanged() {
    refresh(_latestRequestedToken, meToken: _latestRequestedMeToken);
  }

  void _onPovChanged() {
    final newPov = signInState.pov;
    if (newPov != null) {
      refresh(newPov, meToken: _latestRequestedMeToken);
    }
  }

  @override
  void dispose() {
    Setting.get(SettingType.identityPathsReq).notifier.removeListener(_onSettingChanged);
    signInState.povNotifier.removeListener(_onPovChanged);
    Setting.get(SettingType.fcontext).notifier.removeListener(_onSettingChanged);
    super.dispose();
  }

  bool _loading = false;
  bool get loading => _loading;
  String? _latestRequestedToken;
  String? _latestRequestedMeToken;

  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<String?> loadingMessage = ValueNotifier(null);

  String? _error;
  String? get error => _error;

  V2SortMode _sortMode = V2SortMode.recentActivity;
  V2SortMode get sortMode => _sortMode;

  set sortMode(V2SortMode mode) {
    if (_sortMode != mode) {
      _sortMode = mode;
      if (value != null) {
        _updateValueWithSettings();
      }
    }
  }

  V2FilterMode _filterMode = V2FilterMode.myDisses;
  V2FilterMode get filterMode => _filterMode;

  set filterMode(V2FilterMode mode) {
    if (_filterMode != mode) {
      _filterMode = mode;
      if (value != null) {
        _updateValueWithSettings();
      }
    }
  }

  String? _tagFilter;
  String? get tagFilter => _tagFilter;

  set tagFilter(String? tag) {
    if (_tagFilter != tag) {
      _tagFilter = tag;
      if (value != null) {
        _updateValueWithSettings();
      }
    }
  }

  String? _typeFilter;
  String? get typeFilter => _typeFilter;

  set typeFilter(String? type) {
    if (_typeFilter != type) {
      _typeFilter = type;
      if (value != null) {
        _updateValueWithSettings();
      }
    }
  }

  bool _enableCensorship = true;
  bool get enableCensorship => _enableCensorship;

  set enableCensorship(bool enabled) {
    if (_enableCensorship != enabled) {
      _enableCensorship = enabled;
      // Censorship affects the aggregation pipeline, so we need a full refresh.
      refresh(_latestRequestedToken, meToken: _latestRequestedMeToken);
    }
  }

  void _updateValueWithSettings() {
    if (value == null) return;
    
    value = V2FeedModel(
      trustGraph: value!.trustGraph,
      followNetwork: value!.followNetwork,
      labeler: value!.labeler,
      aggregation: value!.aggregation,
      rootToken: value!.rootToken,
      fcontext: value!.fcontext,
      sortMode: _sortMode,
      filterMode: _filterMode,
      tagFilter: _tagFilter,
      typeFilter: _typeFilter,
      enableCensorship: _enableCensorship,
      availableContexts: value!.availableContexts,
      activeContexts: value!.activeContexts,
    );
  }

  void sortSubjects(List<SubjectAggregation> subjects) {
    switch (_sortMode) {
      case V2SortMode.recentActivity:
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
          final commentsA = a.statements.where((s) => s.comment != null && s.comment!.isNotEmpty).length;
          final commentsB = b.statements.where((s) => s.comment != null && s.comment!.isNotEmpty).length;
          if (commentsA != commentsB) return commentsB.compareTo(commentsA);
          return b.lastActivity.compareTo(a.lastActivity);
        });
        break;
    }
  }

  bool shouldShow(SubjectAggregation subject, V2FilterMode mode, bool censorshipEnabled, {String? tagFilter, Map<String, String>? tagEquivalence, String? typeFilter}) {
    // Don't show statements as top-level cards
    final s = subject.subject;
    if (s is Map && s.containsKey('statement')) return false;
    if (s is String) {
      final j = Jsonish.find(s);
      if (j != null && j.containsKey('statement')) return false;
    }

    if (censorshipEnabled && subject.isCensored) return false;

    if (typeFilter != null && typeFilter != 'all') {
       String? subjectType;
       if (s is Map) {
         subjectType = s['contentType'];
       } else if (s is String) {
         final j = Jsonish.find(s);
         if (j != null) {
           subjectType = j['contentType'];
         }
       }
       
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
        if (subject.userDismissalTimestamp == null) return true;
        return subject.lastActivity.isAfter(subject.userDismissalTimestamp!);
      case V2FilterMode.povDisses:
        if (subject.povDismissalTimestamp == null) return true;
        return subject.lastActivity.isAfter(subject.povDismissalTimestamp!);
      case V2FilterMode.ignoreDisses:
        return true;
    }
  }

  Future<void> refresh(String? rootToken, {String? meToken}) async {
    _latestRequestedToken = rootToken;
    _latestRequestedMeToken = meToken;
    
    if (_loading) {
      debugPrint('V2FeedController: Already loading, updated target to $rootToken (me: $meToken)');
      return;
    }
    
    _loading = true;
    loadingMessage.value = 'Starting refresh...';
    progress.value = 0;
    notifyListeners();

    try {
      while (true) {
        final currentToken = _latestRequestedToken;
        final currentMeToken = _latestRequestedMeToken;
        
        List<String>? meKeys;
        List<String>? additionalIdentityKeys;
        List<String>? additionalAppKeys;

        if (currentMeToken != null && currentMeToken == signInState.identity) {
           final delegate = signInState.delegate;
           meKeys = [currentMeToken];
           additionalIdentityKeys = [currentMeToken];
           // Also fetch meToken from App Source (nerdster.org)
           // This allows identities to host content on the app even if they are identities.
           additionalAppKeys = [currentMeToken];
           
           if (delegate != null) {
             meKeys.add(delegate);
             additionalAppKeys.add(delegate);
           }
        }
        
        if (currentToken == null) {
          debugPrint('V2FeedController: rootToken is null, clearing model');
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
        debugPrint('V2FeedController: Building TrustGraph for $currentToken');
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
        final graph = await trustPipeline.build(currentToken);
        debugPrint('V2FeedController: TrustGraph has ${graph.orderedKeys.length} keys');
        final delegateResolver = DelegateResolver(graph);
        progress.value = 0.3;

      // 2. Content Pipeline
      debugPrint('V2FeedController: Fetching ContentMap');
      loadingMessage.value = 'Loading signed content from nerdster.org (Content)';
      progress.value = 0.4;
      final contentPipeline = ContentPipeline(
        contentSource: contentSource,
      );
      final contentMap = await contentPipeline.fetchContentMap(
        graph, 
        delegateResolver,
        additionalKeys: additionalAppKeys,
      );
      debugPrint('V2FeedController: ContentMap has ${contentMap.length} entries');
      progress.value = 0.6;

      // 3. Follow Network
      debugPrint('V2FeedController: Reducing FollowNetwork');
      loadingMessage.value = 'Processing follow network...';
      progress.value = 0.7;
      final followNetwork = reduceFollowNetwork(
        graph,
        delegateResolver,
        contentMap,
        fcontext,
      );
      debugPrint('V2FeedController: FollowNetwork has ${followNetwork.identities.length} identities');
      progress.value = 0.8;

      // 4. Content Aggregation
      debugPrint('V2FeedController: Reducing ContentAggregation');
      loadingMessage.value = 'Aggregating content...';
      progress.value = 0.9;
      final aggregation = reduceContentAggregation(
        followNetwork,
        graph,
        delegateResolver,
        contentMap,
        enableCensorship: _enableCensorship,
        meToken: currentMeToken,
        meKeys: meKeys,
      );
      debugPrint('V2FeedController: Aggregation has ${aggregation.statements.length} statements');
      progress.value = 0.95;

      // 5. Labeling
      loadingMessage.value = 'Finalizing...';
      final labeler = V2Labeler(graph,
          delegateResolver: delegateResolver, meToken: currentMeToken);

      // 6. Contexts
      final mostContexts = MostStrings({kOneofusContext, kNerdsterContext});
      for (final statements in contentMap.values) {
        for (final s in statements) {
          if (s.verb == ContentVerb.follow && s.contexts != null) {
            mostContexts.process(s.contexts!.keys);
          }
        }
      }
      final availableContexts = mostContexts.most().toList();

      final activeContexts = <String>{};
      final rootIdentity = graph.root;
      final rootKeys = [
        ...graph.getEquivalenceGroup(rootIdentity),
        ...delegateResolver.getDelegatesForIdentity(rootIdentity),
      ];
      for (final key in rootKeys) {
        final statements = contentMap[key];
        if (statements != null) {
          for (final s in statements) {
            if (s.verb == ContentVerb.follow && s.contexts != null) {
              activeContexts.addAll(s.contexts!.entries.where((e) => e.value > 0).map((e) => e.key));
            }
          }
        }
      }

      if (_latestRequestedToken == currentToken && _latestRequestedMeToken == currentMeToken) {
        value = V2FeedModel(
          trustGraph: graph,
          followNetwork: followNetwork,
          labeler: labeler,
          aggregation: aggregation,
          rootToken: currentToken,
          fcontext: fcontext,
          sortMode: _sortMode,
          filterMode: _filterMode,
          enableCensorship: _enableCensorship,
          availableContexts: availableContexts,
          activeContexts: activeContexts,
        );
        progress.value = 1.0;
        debugPrint('V2FeedController: Refresh complete for $currentToken');
        break;
      }
      debugPrint('V2FeedController: Token changed during refresh, retrying (root: $_latestRequestedToken, me: $_latestRequestedMeToken)');
    }
  } catch (e, stack) {
    debugPrint('V2FeedController Error: $e\n$stack');
    _error = e.toString();
  } finally {
    _loading = false;
    loadingMessage.value = null;
    notifyListeners();
  }
}
}
