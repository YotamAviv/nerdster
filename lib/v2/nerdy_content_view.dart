import 'package:flutter/material.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/content_card.dart';
import 'package:nerdster/nerdster_menu.dart';
import 'package:nerdster/verify.dart';
import 'package:nerdster/v2/graph_view.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/app.dart';

class NerdyContentView extends StatefulWidget {
  final String? rootToken;

  const NerdyContentView({super.key, this.rootToken});

  @override
  State<NerdyContentView> createState() => _NerdyContentViewState();
}

class _NerdyContentViewState extends State<NerdyContentView> {
  late final V2FeedController _controller;
  String? _currentPov;

  @override
  void initState() {
    super.initState();
    _currentPov = widget.rootToken;
    _controller = V2FeedController(
      trustSource: SourceFactory.get<TrustStatement>(kOneofusDomain),
      identityContentSource: SourceFactory.get<ContentStatement>(kOneofusDomain),
      appContentSource: SourceFactory.get<ContentStatement>(kNerdsterDomain),
    );
    _controller.refresh(_currentPov, meToken: signInState.identity);
    Setting.get<bool>(SettingType.hideSeen).addListener(_onSettingChanged);
    Setting.get<String>(SettingType.fcontext).addListener(_onRefresh);
    contentBase.addListener(_onRefresh);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      verifyInit(navigatorKey);
    });
  }

  @override
  void didUpdateWidget(NerdyContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootToken != widget.rootToken) {
      debugPrint('NerdyContentView: rootToken changed from ${oldWidget.rootToken} to ${widget.rootToken}');
      setState(() {
        _currentPov = widget.rootToken;
      });
      // We use a small delay to ensure the previous refresh (if any) has a chance to see the loading state
      // or we can just call _controller.refresh directly which we will make smarter.
      _onRefresh();
    }
  }

  @override
  void dispose() {
    Setting.get<bool>(SettingType.hideSeen).removeListener(_onSettingChanged);
    Setting.get<String>(SettingType.fcontext).removeListener(_onRefresh);
    contentBase.removeListener(_onRefresh);
    _controller.dispose();
    super.dispose();
  }

  void _onSettingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;

    // The controller handles overlapping refreshes internally.
    await _controller.refresh(_currentPov, meToken: signInState.identity);
  }

  void _changePov(String? newToken) {
    Setting.get<String?>(SettingType.pov).value = newToken;
    setState(() {
      _currentPov = newToken;
    });
    _onRefresh();
  }

  void _onTagTap(String? tag) {
    _controller.tagFilter = tag;
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
                NerdsterMenu(),
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
                Expanded(
                  child: _buildContent(model, hideSeen),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(V2FeedModel? model) {
    final fcontext = Setting.get<String>(SettingType.fcontext).value;
    final isSpecial = fcontext == kOneofusContext || fcontext == kNerdsterContext;
    final isActive = model?.activeContexts.contains(fcontext) ?? false;
    final hasError = !isSpecial && !isActive && model != null;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              const Text('PoV: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Flexible(
                flex: 3,
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: (model?.trustGraph.distances.containsKey(_currentPov) == true
                          ? _currentPov
                          : null),
                  hint: _controller.loading && model?.rootToken != _currentPov
                      ? const Text('Loading...')
                      : Text(model != null && _currentPov != null
                          ? model.labeler.getLabel(_currentPov!)
                          : (_currentPov ?? '')),
                  items: [
                    if (signInState.pov != null)
                      DropdownMenuItem(
                        value: signInState.pov!,
                        child: Text('Me (${model?.labeler.getLabel(signInState.pov!) ?? "Signed In"})'),
                      ),
                    if (model != null)
                      ...model.trustGraph.orderedKeys
                          .where((k) => k != signInState.pov)
                          .map((k) {
                        return DropdownMenuItem(
                          value: k,
                          child: Text(model.labeler.getLabel(k)),
                        );
                      }),
                  ],
                  onChanged: (val) {
                    if (val != null) _changePov(val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Text('Context: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Flexible(
                flex: 2,
                child: Row(
                  children: [
                    if (hasError)
                      const Tooltip(
                        message: 'This PoV does not use this follow context.',
                        child: Icon(Icons.error_outline, color: Colors.red, size: 16),
                      ),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: fcontext,
                        style: hasError ? const TextStyle(color: Colors.red) : null,
                        items: [
                          const DropdownMenuItem(value: kOneofusContext, child: Text(kOneofusContext)),
                          const DropdownMenuItem(value: kNerdsterContext, child: Text(kNerdsterContext)),
                          if (model != null)
                            ...model.availableContexts
                                .where((c) => c != kOneofusContext && c != kNerdsterContext)
                                .map((c) {
                              final isContextActive = model.activeContexts.contains(c);
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    color: isContextActive ? null : Colors.grey,
                                    fontStyle: isContextActive ? null : FontStyle.italic,
                                  ),
                                ),
                              );
                            }),
                          // Ensure the current fcontext is always in the list to avoid Dropdown errors
                          if (fcontext != kOneofusContext && 
                              fcontext != kNerdsterContext && 
                              (model == null || !model.availableContexts.contains(fcontext)))
                            DropdownMenuItem(value: fcontext, child: Text(fcontext)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            Setting.get<String>(SettingType.fcontext).value = val;
                            _onRefresh();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              const SizedBox(width: 16),
              const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<V2FilterMode>(
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
              const SizedBox(width: 16),
              const Text('Tag: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _controller.tagFilter ?? '-',
                items: [
                  const DropdownMenuItem(value: '-', child: Text('All')),
                  ...((model?.aggregation.subjects.values
                          .expand((s) => s.tags)
                          .toSet()
                          .toList() ?? [])
                        ..sort())
                      .map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (val) {
                  _controller.tagFilter = (val == '-' ? null : val);
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.auto_graph),
                tooltip: 'Network Graph',
                onPressed: () {
                  if (model != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NerdyGraphView(
                          feedModel: model,
                          onPovChanged: _changePov,
                        ),
                      ),
                    );
                  }
                },
              ),
              const Text('Censor'),
              Switch(
                value: _controller.enableCensorship,
                onChanged: (val) => _controller.enableCensorship = val,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _onRefresh,
              ),
            ],
          ),
        ],
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

    if (model == null || model.aggregation.subjects.isEmpty) {
      return const Center(child: Text('No content found.'));
    }

    final subjects = model.aggregation.subjects.values.where((s) {
      return _controller.shouldShow(
        s,
        model.filterMode,
        model.enableCensorship,
        tagFilter: model.tagFilter,
        tagEquivalence: model.aggregation.tagEquivalence,
      );
    }).toList();

    // Sort using the controller's logic
    _controller.sortSubjects(subjects);

    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        return ContentCard(
          aggregation: subjects[index],
          model: model,
          onRefresh: _onRefresh,
          onPovChange: _changePov,
          onTagTap: _onTagTap,
          onGraphFocus: (identity) {
            if (model != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NerdyGraphView(
                    feedModel: model,
                    onPovChanged: _changePov,
                    initialFocus: identity,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
