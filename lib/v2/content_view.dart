import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/nerdster_menu.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/content_bar.dart';
import 'package:nerdster/v2/content_card.dart';
import 'package:nerdster/v2/etc_bar.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/graph_view.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/notifications_menu.dart';
import 'package:nerdster/v2/relate_dialog.dart';
import 'package:nerdster/v2/sign_in_widget.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/trust_settings_bar.dart';
import 'package:nerdster/verify.dart';

import 'refresh_signal.dart';
import 'submit.dart';

class ContentView extends StatefulWidget {
  final IdentityKey pov;
  final IdentityKey meIdentity;

  const ContentView({super.key, required this.pov, required this.meIdentity});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  late final V2FeedController _controller;
  IdentityKey? _currentPov;
  final ValueNotifier<ContentKey?> _markedSubjectToken = ValueNotifier(null);
  final ValueNotifier<bool> _showFilters = ValueNotifier(false);
  final ValueNotifier<bool> _showEtc = ValueNotifier(false);

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
    _controller.refresh(_currentPov, meIdentity: IdentityKey(signInState.identity));
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
    v2RefreshSignal.removeListener(_onRefresh);
    _controller.dispose();
    _showFilters.dispose();
    _showEtc.dispose();
    super.dispose();
  }

  void _onStatementPublished(ContentStatement s) {
    _controller.push(s);
    _onRefresh(clearCache: false);
  }

  Future<void> _onRefresh({bool clearCache = true}) async {
    if (!mounted) return;

    // The controller handles overlapping refreshes internally.
    await _controller.refresh(_currentPov,
        meIdentity: IdentityKey(signInState.identity), clearCache: clearCache);
  }

  void _changePov(String? newToken) {
    if (newToken != null) signInState.pov = newToken;
    setState(() {
      _currentPov = newToken != null ? IdentityKey(newToken) : null;
      _markedSubjectToken.value = null;
    });
    _onRefresh();
  }

  void _onTagTap(String? tag) {
    _controller.tagFilter = tag;
    if (!_showFilters.value) _showFilters.value = true;
  }

  Future<void> _onMark(ContentKey? token) async {
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

        final statement = await V2RelateDialog.show(
          context,
          subject1,
          subject2,
          model,
          onRefresh: null,
        );

        if (statement != null) {
          _onStatementPublished(statement);
          _markedSubjectToken.value = null;
        } else {
          // If the dialog was just closed or failed without statement, usually we do nothing.
          // Unless we want to clear selection? Probably not.
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V2FeedModel?>(
      valueListenable: _controller,
      builder: (context, model, _) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0, // Hide the default AppBar
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    ValueListenableBuilder<bool>(
                        valueListenable: Setting.get<bool>(SettingType.dev).notifier,
                        builder: (context, dev, child) {
                          if (!dev) return const SizedBox.shrink();
                          return NerdsterMenu(
                            v2Notifications: Builder(builder: (context) {
                              final hasErrors = model?.sourceErrors.isNotEmpty ?? false;
                              final hasTrust = model?.trustGraph.notifications.isNotEmpty ?? false;
                              final hasFollow =
                                  model?.followNetwork.notifications.isNotEmpty ?? false;

                              if (model != null && (hasTrust || hasFollow || hasErrors)) {
                                if (hasErrors) {
                                  debugPrint(
                                      'ContentView: Displaying ${model.sourceErrors.length} errors');
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
                          );
                        }),
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
                                style:
                                    Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 18), // Match height of progress + text
                    _buildTrustSettingsBar(model),
                    // Filters Dropdown
                    ValueListenableBuilder<bool>(
                      valueListenable: _showFilters,
                      builder: (context, show, _) {
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: show
                              ? ContentBar(
                                  controller: _controller, tags: model?.aggregation.mostTags ?? [])
                              : const SizedBox.shrink(),
                        );
                      },
                    ),
                    // Etc Dropdown
                    ValueListenableBuilder<bool>(
                      valueListenable: _showEtc,
                      builder: (context, show, _) {
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: show
                              ? EtcBar(
                                  notifications: Builder(builder: (context) {
                                    final hasErrors = model?.sourceErrors.isNotEmpty ?? false;
                                    final hasTrust =
                                        model?.trustGraph.notifications.isNotEmpty ?? false;
                                    final hasFollow =
                                        model?.followNetwork.notifications.isNotEmpty ?? false;

                                    if (model != null && (hasTrust || hasFollow || hasErrors)) {
                                      if (hasErrors) {
                                        debugPrint(
                                            'ContentView: Displaying ${model.sourceErrors.length} errors');
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
                                )
                              : const SizedBox.shrink(),
                        );
                      },
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildContent(model),
                          ),
                          // Floating Controls (Left)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (model != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).canvasColor.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add),
                                      onPressed: () => v2Submit(context, model,
                                          onRefresh: _onRefresh,
                                          onStatementPublished: _onStatementPublished),
                                      tooltip: 'Submit new content',
                                    ),
                                  ),
                                if (model != null) const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).canvasColor.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.tune, color: Colors.blue),
                                    onPressed: () {
                                      if (!_showFilters.value) _showEtc.value = false;
                                      _showFilters.value = !_showFilters.value;
                                    },
                                    tooltip: 'Show/Hide Filters',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).canvasColor.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.menu),
                                    onPressed: () {
                                      if (!_showEtc.value) _showFilters.value = false;
                                      _showEtc.value = !_showEtc.value;
                                    },
                                    tooltip: 'Show/Hide Menu',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Floating SignInWidget (Right)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).canvasColor.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const SignInWidget(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrustSettingsBar(V2FeedModel? model) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
      child: TrustSettingsBar(
        availableIdentities: model?.trustGraph.orderedKeys ?? [],
        availableContexts: model?.availableContexts ?? [],
        activeContexts: model?.activeContexts ?? {},
        labeler: model?.labeler ?? V2Labeler(TrustGraph(pov: IdentityKey(''))),
      ),
    );
  }

  Widget _buildContent(V2FeedModel? model) {
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
          onPovChange: _changePov,
          onTagTap: _onTagTap,
          onMark: _onMark,
          markedSubjectToken: _markedSubjectToken,
          onStatementPublished: _onStatementPublished,
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
