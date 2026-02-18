import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/dev/nerdster_menu.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/content_bar.dart';
import 'package:nerdster/ui/content_card.dart';
import 'package:nerdster/ui/etc_bar.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/ui/graph_view.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/ui/notifications_menu.dart';
import 'package:nerdster/ui/dialogs/relate_dialog.dart';
import 'package:nerdster/io/source_factory.dart';
import 'package:nerdster/ui/trust_settings_bar.dart';
import 'package:nerdster/verify.dart';

import 'submit.dart';

class ContentView extends StatefulWidget {
  final IdentityKey pov;
  final IdentityKey meIdentity;

  const ContentView({super.key, required this.pov, required this.meIdentity});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  late final FeedController _controller;
  final ValueNotifier<ContentKey?> _markedSubjectToken = ValueNotifier(null);
  final ValueNotifier<bool> _showFilters = ValueNotifier(false);
  final ValueNotifier<bool> _showEtc = ValueNotifier(false);
  final ValueNotifier<bool> _headerVisible = ValueNotifier(true);
  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = FeedController(
      trustSource: SourceFactory.get<TrustStatement>(kOneofusDomain),
      contentSource: SourceFactory.get<ContentStatement>(kNerdsterDomain),
      optimisticConcurrencyFunc: nerdsterOptimisticConcurrencyFunc,
    );
    _controller.addListener(() {
      if (_controller.value != null) {
        globalLabeler.value = _controller.value!.labeler;
      }
    });
    _controller.refresh();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      verifyInit(navigatorKey);
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    // Show header when scrolling up or near top; hide when scrolling down
    if (delta > 4 && offset > 60) {
      // Only hide if filters/etc are closed
      if (!_showFilters.value && !_showEtc.value) {
        _headerVisible.value = false;
      }
    } else if (delta < -4) {
      _headerVisible.value = true;
    }
  }

  @override
  void didUpdateWidget(ContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pov != widget.pov) {
      debugPrint('ContentView: povIdentity changed from ${oldWidget.pov} to ${widget.pov}');
      setState(() {
        _markedSubjectToken.value = null;
      });
      _onRefresh();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _showFilters.dispose();
    _showEtc.dispose();
    _headerVisible.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;
    await _controller.notify();
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

        final statement = await RelateDialog.show(
          context,
          subject1,
          subject2,
          _controller, // Changed from model
          onRefresh: null,
        );

        if (statement != null) {
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
    return ValueListenableBuilder<FeedModel?>(
      valueListenable: _controller,
      builder: (context, model, _) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
          ),
          body: SafeArea(
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                    valueListenable: Setting.get<bool>(SettingType.dev).notifier,
                    builder: (context, dev, child) {
                      if (!dev) return const SizedBox.shrink();
                      return NerdsterMenu();
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                _buildTrustSettingsBar(model),
                // Toolbar row: [Submit] [Filters] [Menu] — auto-hides on scroll
                ValueListenableBuilder<bool>(
                  valueListenable: _headerVisible,
                  builder: (context, visible, _) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      height: visible ? null : 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToolbar(context, model),
                          // Filters bar (slides in/out)
                          ValueListenableBuilder<bool>(
                            valueListenable: _showFilters,
                            builder: (context, show, _) {
                              return AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                child: show
                                    ? ContentBar(
                                        controller: _controller,
                                        tags: model?.aggregation.mostTags ?? [])
                                    : const SizedBox.shrink(),
                              );
                            },
                          ),
                          // Etc bar (slides in/out)
                          ValueListenableBuilder<bool>(
                            valueListenable: _showEtc,
                            builder: (context, show, _) {
                              return AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                child: show
                                    ? EtcBar(
                                        controller: _controller,
                                        notifications: Builder(builder: (context) {
                                          if (NotificationsMenu.shouldShow(model)) {
                                            if (model!.sourceErrors.isNotEmpty) {
                                              debugPrint(
                                                  'ContentView: Displaying ${model.sourceErrors.length} errors');
                                            }
                                            return NotificationsMenu(
                                              trustGraph: model.trustGraph,
                                              followNetwork: model.followNetwork,
                                              delegateResolver: model.delegateResolver,
                                              labeler: model.labeler,
                                              controller: _controller,
                                              sourceErrors: model.sourceErrors,
                                              systemNotifications: model.systemNotifications,
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        }),
                                      )
                                    : const SizedBox.shrink(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(child: _buildContent(model)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, FeedModel? model) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSmall,
      builder: (context, small, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _showFilters,
          builder: (context, showFilters, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _showEtc,
              builder: (context, showEtc, _) {
                final hasNotifications = NotificationsMenu.shouldShow(model);
                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      // Add button
                      if (model != null)
                        _toolbarButton(
                          context,
                          icon: Icons.add,
                          label: 'Submit',
                          small: small,
                          active: false,
                          onTap: () => submit(context, _controller),
                          tooltip: 'Submit new content',
                        ),
                      const Spacer(),
                      // Filters toggle
                      _toolbarButton(
                        context,
                        icon: Icons.tune,
                        label: 'Filters',
                        small: small,
                        active: showFilters,
                        onTap: () {
                          if (!_showFilters.value) _showEtc.value = false;
                          _showFilters.value = !_showFilters.value;
                        },
                        tooltip: 'Show/Hide Filters',
                      ),
                      // Menu toggle
                      _toolbarButton(
                        context,
                        icon: Icons.menu,
                        label: 'Menu',
                        small: small,
                        active: showEtc,
                        activeColor: hasNotifications ? Colors.pink : null,
                        onTap: () {
                          if (!_showEtc.value) _showFilters.value = false;
                          _showEtc.value = !_showEtc.value;
                        },
                        tooltip: 'Show/Hide Menu',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _toolbarButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool small,
    required bool active,
    required VoidCallback onTap,
    required String tooltip,
    Color? activeColor,
  }) {
    final color = active
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : (activeColor ?? Colors.grey.shade700);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              if (!small) ...[
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 13, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustSettingsBar(FeedModel? model) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0.0),
      child: TrustSettingsBar(
        availableIdentities: model?.trustGraph.orderedKeys ?? [],
        availableContexts: model?.availableContexts ?? [],
        activeContexts: model?.activeContexts ?? {},
        labeler: model?.labeler ?? Labeler(TrustGraph(pov: IdentityKey(''))),
      ),
    );
  }

  Widget _buildContent(FeedModel? model) {
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
      controller: _scrollController,
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        return ContentCard(
          aggregation: subjects[index],
          model: model,
          controller: _controller,
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
