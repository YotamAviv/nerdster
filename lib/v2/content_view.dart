import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/notifications_menu.dart';
import 'package:nerdster/v2/trust_settings_bar.dart';
import 'package:nerdster/v2/content_card.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/nerdster_menu.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/v2/graph_view.dart';
import 'package:nerdster/v2/relate_dialog.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_types.dart';
import 'refresh_signal.dart';
import 'submit.dart';

class ContentView extends StatefulWidget {
  final IdentityKey? pov;

  const ContentView({super.key, this.pov});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  late final V2FeedController _controller;
  IdentityKey? _currentPov;
  final ValueNotifier<ContentKey?> _markedSubjectToken = ValueNotifier(null);
  final ValueNotifier<bool> _showFilters = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _currentPov = widget.pov;
    _controller = V2FeedController(
      trustSource: SourceFactory.get<TrustStatement>(kOneofusDomain),
      contentSource: SourceFactory.get<ContentStatement>(kNerdsterDomain),
    );
    _controller.addListener(() {
      if (_controller.value != null) {
        globalLabeler.value = _controller.value!.labeler;
      }
    });
    _controller.refresh(_currentPov,
        meIdentity: signInState.identity != null ? IdentityKey(signInState.identity!) : null);
    Setting.get<bool>(SettingType.hideSeen).addListener(_onSettingChanged);
    v2RefreshSignal.addListener(_onRefresh);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      verifyInit(navigatorKey);
    });
  }

  @override
  void didUpdateWidget(ContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pov != widget.pov) {
      debugPrint('ContentView: povIdentity changed from ${oldWidget.pov} to ${widget.pov}');
      setState(() {
        _currentPov = widget.pov;
        _markedSubjectToken.value = null;
      });
      // We use a small delay to ensure the previous refresh (if any) has a chance to see the loading state
      // or we can just call _controller.refresh directly which we will make smarter.
      _onRefresh();
    }
  }

  @override
  void dispose() {
    Setting.get<bool>(SettingType.hideSeen).removeListener(_onSettingChanged);
    v2RefreshSignal.removeListener(_onRefresh);
    _controller.dispose();
    _showFilters.dispose();
    super.dispose();
  }

  void _onSettingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;

    // The controller handles overlapping refreshes internally.
    await _controller.refresh(_currentPov,
        meIdentity: signInState.identity != null ? IdentityKey(signInState.identity!) : null);
  }

  void _changePov(String? newToken) {
    signInState.pov = newToken;
    setState(() {
      _currentPov = newToken != null ? IdentityKey(newToken) : null;
      _markedSubjectToken.value = null;
    });
    _onRefresh();
  }

  void _onTagTap(String? tag) {
    _controller.tagFilter = tag;
    _showFilters.value = true;
  }

  void _onMark(ContentKey? token) {
    if (token == null) {
      _markedSubjectToken.value = null;
      return;
    }

    final currentMarked = _markedSubjectToken.value;

    if (currentMarked == token) {
      // Unmark
      _markedSubjectToken.value = null;
    } else if (currentMarked == null) {
      // Mark
      _markedSubjectToken.value = token;
    } else {
      // Relate
      final model = _controller.value;
      if (model != null) {
        final SubjectAggregation subject1 = model.aggregation.subjects[currentMarked]!;
        final SubjectAggregation subject2 = model.aggregation.subjects[token]!;

        V2RelateDialog.show(
          context,
          subject1,
          subject2,
          model,
          onRefresh: () {
            _onRefresh();
            _markedSubjectToken.value = null;
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V2FeedModel?>(
      valueListenable: _controller,
      builder: (context, model, _) {
        final hideSeen = Setting.get<bool>(SettingType.hideSeen).value;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0, // Hide the default AppBar
          ),
          body: SafeArea(
            child: Column(
              children: [
                NerdsterMenu(
                  v2Notifications: Builder(builder: (context) {
                    final hasErrors = model?.sourceErrors.isNotEmpty ?? false;
                    final hasTrust = model?.trustGraph.notifications.isNotEmpty ?? false;
                    final hasFollow = model?.followNetwork.notifications.isNotEmpty ?? false;

                    if (model != null && (hasTrust || hasFollow || hasErrors)) {
                      if (hasErrors) {
                        debugPrint('ContentView: Displaying ${model.sourceErrors.length} errors');
                      }
                      return V2NotificationsMenu(
                        trustGraph: model.trustGraph,
                        followNetwork: model.followNetwork,
                        delegateResolver: model.delegateResolver,
                        labeler: model.labeler,
                        sourceErrors: model.sourceErrors,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ),
                if (_controller.loading)
                  Column(
                    children: [
                      ValueListenableBuilder<double>(
                        valueListenable: _controller.progress,
                        builder: (context, p, _) => LinearProgressIndicator(value: p),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: _controller.loadingMessage,
                        builder: (context, msg, _) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            msg ?? '',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 18), // Match height of progress + text
                _buildControls(model),
                ValueListenableBuilder<bool>(
                  valueListenable: _showFilters,
                  builder: (context, show, _) {
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: show ? _buildFilterDrawer(model) : const SizedBox.shrink(),
                    );
                  },
                ),
                Expanded(
                  child: _buildContent(model, hideSeen),
                ),
              ],
            ),
          ),
          floatingActionButton: null,
        );
      },
    );
  }

  Widget _buildControls(V2FeedModel? model) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Submit Button (Prominent)
          Tooltip(
            message: 'Submit new content',
            child: FloatingActionButton.small(
              onPressed:
                  model == null ? null : () => v2Submit(context, model, onRefresh: _onRefresh),
              child: const Icon(Icons.add),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.blue),
            onPressed: () => _showFilters.value = !_showFilters.value,
            tooltip: 'Show/Hide Filters',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TrustSettingsBar(
              availableIdentities: model?.trustGraph.orderedKeys ?? [],
              availableContexts: model?.availableContexts ?? [],
              activeContexts: model?.activeContexts ?? {},
              labeler: model?.labeler ?? V2Labeler(TrustGraph(pov: IdentityKey(''))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDrawer(V2FeedModel? model) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Sort
            Row(
              children: [
                const Text('Sort: ', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<V2SortMode>(
                  value: _controller.sortMode,
                  items: const [
                    DropdownMenuItem(value: V2SortMode.recentActivity, child: Text('Recent')),
                    DropdownMenuItem(value: V2SortMode.netLikes, child: Text('Net Likes')),
                    DropdownMenuItem(value: V2SortMode.mostComments, child: Text('Comments')),
                  ],
                  onChanged: (val) {
                    if (val != null) _controller.sortMode = val;
                  },
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Type Filter
            Row(
              children: [
                const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _controller.typeFilter ?? 'all',
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All')),
                    ...ContentType.values
                        .map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))),
                  ],
                  onChanged: (val) {
                    _controller.typeFilter = (val == 'all' ? null : val);
                  },
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Tag Filter
            Tooltip(
              message: 'Filter by tag',
              child: Row(
                children: [
                  const Text('Tag: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _controller.tagFilter ?? '-',
                    items: [
                      const DropdownMenuItem(value: '-', child: Text('All')),
                      ...(model?.aggregation.mostTags ?? [])
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (val) {
                      _controller.tagFilter = (val == '-' ? null : val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Dismissal Filter (formerly "Filter")
            Tooltip(
              message: 'Filter dismissed content',
              child: DropdownButton<V2FilterMode>(
                value: _controller.filterMode,
                items: const [
                  DropdownMenuItem(value: V2FilterMode.myDisses, child: Text('My Disses')),
                  DropdownMenuItem(value: V2FilterMode.povDisses, child: Text("PoV's Disses")),
                  DropdownMenuItem(value: V2FilterMode.ignoreDisses, child: Text('Ignore Disses')),
                ],
                onChanged: (val) {
                  if (val != null) _controller.filterMode = val;
                },
              ),
            ),
            const SizedBox(width: 8),

            // Censor Switch
            Tooltip(
              message: 'Rely on my network to censor content I should not see',
              child: Row(
                children: [
                  const Text('Censor'),
                  Switch(
                    value: _controller.enableCensorship,
                    onChanged: (val) => _controller.enableCensorship = val,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(V2FeedModel? model, bool hideSeen) {
    if (_controller.loading && model == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _controller.progress,
              builder: (context, p, _) => Column(
                children: [
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(value: p),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String?>(
                    valueListenable: _controller.loadingMessage,
                    builder: (context, msg, _) => Text(
                      msg ?? 'Loading...',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${_controller.error}', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _onRefresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (model == null || model.effectiveSubjects.isEmpty) {
      return const Center(child: Text('No content found.'));
    }

    final subjects = model.effectiveSubjects;

    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        return ContentCard(
          aggregation: subjects[index],
          model: model,
          onRefresh: _onRefresh,
          onPovChange: _changePov,
          onTagTap: _onTagTap,
          onMark: _onMark,
          markedSubjectToken: _markedSubjectToken,
          onGraphFocus: (identity) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NerdyGraphView(
                  controller: _controller,
                  initialFocus: identity,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
