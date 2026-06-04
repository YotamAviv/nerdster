import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nerdster/about.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/dev/just_sign.dart';
import 'package:nerdster/dev/nerdster_menu.dart';
import 'package:nerdster/models/content_types.dart';
import 'package:nerdster/nerdster_link.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/content_card.dart';
import 'package:nerdster/ui/tag_dropdown.dart';
import 'package:nerdster/ui/util/my_checkbox.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/ui/graph_view.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/ui/notifications_menu.dart';
import 'package:nerdster/ui/dialogs/relate_dialog.dart';
import 'package:nerdster/ui/trust_settings_bar.dart';
import 'package:nerdster/verify.dart';
import 'package:oneofus_common/keys.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import 'submit.dart';

class ContentView extends StatefulWidget {
  final IdentityKey pov;
  final IdentityKey? identity;

  const ContentView({super.key, required this.pov, this.identity});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  late final FeedController _controller;
  final ValueNotifier<ContentKey?> _markedSubjectToken = ValueNotifier(null);
  final ValueNotifier<bool> _headerVisible = ValueNotifier(true);
  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = FeedController(
      optimisticConcurrencyFunc: nerdsterOptimisticConcurrencyFunc,
    );
    _controller.addListener(() {
      if (_controller.value != null) {
        globalLabeler.value = _controller.value!.labeler;
      }
    });
    _controller.addListener(_maybeOpenStartupGraph);
    _controller.refresh();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      verifyInit(navigatorKey);
    });
  }

  bool _startupGraphOpened = false;

  void _maybeOpenStartupGraph() {
    if (_startupGraphOpened ||
        _controller.value == null ||
        startupTarget == null) return;
    _startupGraphOpened = true;
    final target = startupTarget!;
    startupTarget = null;
    _controller.removeListener(_maybeOpenStartupGraph);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                NerdyGraphView(controller: _controller, initialFocus: target),
          ));
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    if (delta > 4) {
      _headerVisible.value = false;
    } else if (delta < -4) {
      _headerVisible.value = true;
    }
  }

  @override
  void didUpdateWidget(ContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pov != widget.pov) {
      debugPrint(
          'ContentView: povIdentity changed from ${oldWidget.pov} to ${widget.pov}');
      setState(() {
        _markedSubjectToken.value = null;
      });
      _onRefresh();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
    _headerVisible.value = true;
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
        final SubjectAggregation subject1 =
            model.aggregation.subjects[currentMarked]!;
        final SubjectAggregation subject2 = model.aggregation.subjects[token]!;

        final statement = await RelateDialog.show(
          context,
          subject1,
          subject2,
          _controller,
          onRefresh: null,
        );

        if (statement != null) {
          _markedSubjectToken.value = null;
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
                    valueListenable:
                        Setting.get<bool>(SettingType.dev).notifier,
                    builder: (context, dev, child) {
                      if (!dev) return const SizedBox.shrink();
                      return NerdsterMenu();
                    }),
                if (_controller.loading)
                  Column(
                    children: [
                      ValueListenableBuilder<double>(
                        valueListenable: _controller.progress,
                        builder: (context, p, _) =>
                            LinearProgressIndicator(value: p),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: _controller.loadingMessage,
                        builder: (context, msg, _) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            msg ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                _buildTrustSettingsBar(model),
                ValueListenableBuilder<bool>(
                  valueListenable: _headerVisible,
                  builder: (context, visible, _) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      height: visible ? null : 0,
                      child: _buildMainBar(context, model),
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

  Widget _buildMainBar(BuildContext context, FeedModel? model) {
    final aggregation = model?.aggregation ?? ContentAggregation();
    final divider = Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: Colors.grey.shade400,
    );
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border:
            Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          // === LEFT: notifications, submit, share, refresh ===
          if (NotificationsMenu.shouldShow(model))
            MenuBar(
              style: const MenuStyle(
                elevation: WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                padding: WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              children: [
                NotificationsMenu(
                  trustGraph: model!.trustGraph,
                  followNetwork: model.followNetwork,
                  delegateResolver: model.delegateResolver,
                  labeler: model.labeler,
                  controller: _controller,
                  sourceErrors: model.sourceErrors,
                  systemNotifications: model.systemNotifications,
                ),
              ],
            ),
          if (model != null)
            Tooltip(
              message: 'Submit new content',
              child: IconButton(
                icon:
                    const Icon(Icons.add_circle, color: Colors.blue, size: 22),
                visualDensity: VisualDensity.compact,
                onPressed: () => submit(context, _controller),
              ),
            ),
          Tooltip(
            message: 'Share this view',
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.blue),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final link = generateLink();
                if (kIsWeb) {
                  _showShareDialog(context, link);
                } else {
                  try {
                    await SharePlus.instance.share(ShareParams(
                        text: link, subject: 'Check this out on Nerdster'));
                  } catch (_) {
                    if (context.mounted) _showShareDialog(context, link);
                  }
                }
              },
            ),
          ),
          Tooltip(
            message: 'Refresh',
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blue),
              visualDensity: VisualDensity.compact,
              onPressed: () => _controller.refresh(),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    divider,

                    // === MIDDLE: sort, type, tags ===
                    PopupMenuButton<SortMode>(
                      tooltip: switch (_controller.sortMode) {
                        SortMode.recentActivity => 'Sort: Recent',
                        SortMode.netLikes => 'Sort: Net Likes',
                        SortMode.mostComments => 'Sort: Comments',
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: switch (_controller.sortMode) {
                          SortMode.recentActivity =>
                            const Icon(Icons.history, size: 20),
                          SortMode.netLikes =>
                            const Icon(Icons.thumb_up_outlined, size: 20),
                          SortMode.mostComments =>
                            const Icon(Icons.chat_bubble_outline, size: 20),
                        },
                      ),
                      onSelected: (val) => _controller.sortMode = val,
                      itemBuilder: (context) => SortMode.values.map((mode) {
                        final selected = mode == _controller.sortMode;
                        final color = selected
                            ? Theme.of(context).colorScheme.primary
                            : null;
                        return PopupMenuItem<SortMode>(
                          value: mode,
                          child: Row(children: [
                            Icon(
                              switch (mode) {
                                SortMode.recentActivity => Icons.history,
                                SortMode.netLikes => Icons.thumb_up_outlined,
                                SortMode.mostComments =>
                                  Icons.chat_bubble_outline,
                              },
                              size: 20,
                              color: color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              switch (mode) {
                                SortMode.recentActivity => 'Recent',
                                SortMode.netLikes => 'Net Likes',
                                SortMode.mostComments => 'Comments',
                              },
                              style: TextStyle(
                                  fontWeight: selected ? FontWeight.bold : null,
                                  color: color),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                    PopupMenuButton<String>(
                      tooltip: _controller.typeFilter == null
                          ? 'Type: All'
                          : 'Type: ${_controller.typeFilter}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: _controller.typeFilter == null
                            ? const Text('*',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold))
                            : Icon(
                                ContentType.values
                                    .firstWhere(
                                        (t) => t.name == _controller.typeFilter)
                                    .iconDatas
                                    .$1,
                                size: 20,
                              ),
                      ),
                      onSelected: (val) =>
                          _controller.typeFilter = (val == 'all' ? null : val),
                      itemBuilder: (context) {
                        final primary = Theme.of(context).colorScheme.primary;
                        final current = _controller.typeFilter ?? 'all';
                        return [
                          PopupMenuItem<String>(
                            value: 'all',
                            child: Row(children: [
                              Text('*',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          current == 'all' ? primary : null)),
                              const SizedBox(width: 8),
                              Text('All',
                                  style: TextStyle(
                                      fontWeight: current == 'all'
                                          ? FontWeight.bold
                                          : null,
                                      color:
                                          current == 'all' ? primary : null)),
                            ]),
                          ),
                          ...ContentType.values.map((t) {
                            final selected = t.name == current;
                            final color = selected ? primary : null;
                            return PopupMenuItem<String>(
                              value: t.name,
                              child: Row(children: [
                                Icon(selected ? t.iconDatas.$1 : t.iconDatas.$2,
                                    size: 20, color: color),
                                const SizedBox(width: 8),
                                Text(t.name,
                                    style: TextStyle(
                                        fontWeight:
                                            selected ? FontWeight.bold : null,
                                        color: color)),
                              ]),
                            );
                          }),
                        ];
                      },
                    ),
                    TagDropdownButton(
                      mostTags: aggregation.mostTags,
                      tagEquivalence: aggregation.tagEquivalence,
                      tagRelate: aggregation.tagRelate,
                      tagEquivalenceStatements:
                          aggregation.tagEquivalenceStatements,
                      activeFilter: _controller.tagFilter,
                      onFilterChanged: (val) {
                        _controller.tagFilter =
                            (val == null || val.isEmpty) ? null : val;
                      },
                      controller: _controller,
                    ),

                    divider,
                  ],
                ),
              ),
            ),
          ),

          // === RIGHT: hamburger menu ===
          MenuAnchor(
            builder: (context, menuController, _) => IconButton(
              icon: const Icon(Icons.menu),
              visualDensity: VisualDensity.compact,
              tooltip: 'Menu',
              onPressed: () => menuController.isOpen
                  ? menuController.close()
                  : menuController.open(),
            ),
            menuChildren: [
              MenuItemButton(
                leadingIcon: Icon(
                  _controller.filterMode == DisFilterMode.my
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: Colors.brown,
                  size: 20,
                ),
                child: const Text("Hide dismissed"),
                onPressed: () {
                  _controller.filterMode =
                      _controller.filterMode == DisFilterMode.my
                          ? DisFilterMode.ignore
                          : DisFilterMode.my;
                },
              ),
              MenuItemButton(
                leadingIcon: Icon(
                  _controller.enableCensorship
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: Colors.red,
                  size: 20,
                ),
                child: const Text("Filter censored"),
                onPressed: () => _controller.enableCensorship =
                    !_controller.enableCensorship,
              ),
              const Divider(),
              ValueListenableBuilder<String>(
                valueListenable:
                    Setting.get<String>(SettingType.identityPathsReq).notifier,
                builder: (context, current, _) {
                  final (IconData icon, Color color) = switch (current) {
                    'permissive' => (Icons.shield_outlined, Colors.green),
                    'strict' => (Icons.security, Colors.red),
                    _ => (Icons.shield_sharp, Colors.blue),
                  };
                  return SubmenuButton(
                    menuChildren:
                        ['permissive', 'standard', 'strict'].map((val) {
                      return MenuItemButton(
                        closeOnActivate: false,
                        onPressed: () =>
                            Setting.get<String>(SettingType.identityPathsReq)
                                .value = val,
                        trailingIcon:
                            current == val ? const Icon(Icons.check) : null,
                        child: Text(val),
                      );
                    }).toList(),
                    child: Row(children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 8),
                      const Text('Identity strictness'),
                    ]),
                  );
                },
              ),
              const Divider(),
              MyCheckbox(Setting.get<bool>(SettingType.showCrypto).notifier,
                  'Show Crypto',
                  alwaysShowTitle: true),
              ValueListenableBuilder<bool>(
                valueListenable: isSmall,
                builder: (context, small, _) => MyCheckbox(
                  Setting.get<bool>(SettingType.lgtm).notifier, 'Show FYI',
                  alwaysShowTitle: true,
                  enabled: !small,
                ),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.border_color),
                child: const Text('Just Sign'),
                onPressed: () => JustSign.sign(context),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.verified_user),
                child: const Text('Just Verify'),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Navigator(
                        onGenerateRoute: (settings) =>
                            MaterialPageRoute(builder: (_) => Verify()),
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: SizedBox(
                  width: 20,
                  height: 20,
                  child: Image.asset('assets/images/nerd.png'),
                ),
                child: const Text('About'),
                onPressed: () => About.show(context),
              ),
              if (Setting.get<bool>(SettingType.dev).value) ...[
                const Divider(),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.timer_outlined),
                  child: const Text('Benchmark seeding'),
                  onPressed: () => _controller.runBenchmark(context),
                ),
              ],
            ],
          ),
        ],
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
            Text('Error: ${_controller.error}',
                style: const TextStyle(color: Colors.red)),
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
      findChildIndexCallback: (key) {
        final canonical = (key as ValueKey<String>).value;
        final index =
            subjects.indexWhere((s) => s.canonical.value == canonical);
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        return ContentCard(
          key: Key(subjects[index].canonical.value),
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

void _showShareDialog(BuildContext context, String link) {
  showDialog(
    context: context,
    builder: (ctx) {
      bool copied = false;
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 8),
              Text('Share link',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share with your current settings (PoV, tags, sort, etc.):',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade50,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: SelectableText(
                  link,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  maxLines: 4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: Icon(copied ? Icons.check : Icons.copy, size: 16),
              label: Text(copied ? 'Copied!' : 'Copy link'),
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: link));
                  setState(() => copied = true);
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Could not copy — long-press the link to copy manually.'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      });
    },
  );
}
