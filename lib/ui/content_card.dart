import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/dismiss_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/dialogs/check_signed_in.dart';
import 'package:nerdster/ui/dialogs/lgtm.dart';
import 'package:nerdster/ui/util/dis_toggle.dart';
import 'package:oneofus_common/keys.dart';
import 'package:oneofus_common/statement.dart';
import 'package:nerdster/logic/metadata_service.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/ui/dialogs/rate_dialog.dart';
import 'package:nerdster/ui/statement_tile.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/ui/tag_chip.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class ContentCard extends StatefulWidget {
  final SubjectAggregation aggregation;
  final FeedModel model;
  final FeedController controller;
  final ValueChanged<String?>? onTagTap;
  final ValueChanged<String?>? onGraphFocus;
  final ValueNotifier<ContentKey?>? markedSubjectToken;
  final ValueChanged<ContentKey?>? onMark;

  const ContentCard({
    super.key,
    required this.aggregation,
    required this.model,
    required this.controller,
    this.onTagTap,
    this.onGraphFocus,
    this.markedSubjectToken,
    this.onMark,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> with TickerProviderStateMixin {
  MetadataResult? _metadata;
  bool _isHistoryExpanded = false;
  bool _isRelationshipsExpanded = false;

  // Dismiss sweep animation — used on both isSmall and !isSmall
  String? _committedDis;
  String? _pendingDis;
  late final AnimationController _sweepController;
  final ValueNotifier<String?> _disNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener(_onSweepStatus);
    _syncDisFromModel();
  }

  void _syncDisFromModel() {
    final stmts =
        widget.model.aggregation.myDismissStatements[widget.aggregation.canonical] ?? [];
    _committedDis = stmts.isEmpty ? null : stmts.first.dismiss;
    _pendingDis = _committedDis;
    _disNotifier.value = _committedDis;
  }

  @override
  void didUpdateWidget(ContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aggregation.canonical != widget.aggregation.canonical) {
      _metadata = null;
      _fetchMetadata();
      _sweepController.stop();
      _sweepController.reset();
      _syncDisFromModel();
    } else {
      // Sync committed state after a write resolves
      final stmts =
          widget.model.aggregation.myDismissStatements[widget.aggregation.canonical] ?? [];
      final newCommitted = stmts.isEmpty ? null : stmts.first.dismiss;
      if (newCommitted != _committedDis) {
        _committedDis = newCommitted;
        if (_pendingDis == _committedDis) {
          _sweepController.stop();
          _sweepController.reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _sweepController.removeStatusListener(_onSweepStatus);
    _sweepController.dispose();
    _disNotifier.dispose();
    if (_pendingDis != _committedDis) {
      unawaited(_commitDis()); // fire-and-forget on scroll-away
    }
    super.dispose();
  }

  void _onSweepStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _commitDisAfterLgtm();
    }
  }

  Future<void> _commitDisAfterLgtm() async {
    if (!mounted) {
      await _commitDis();
      return;
    }
    final iJson = signInState.delegatePublicKeyJson;
    if (iJson != null) {
      final Json json =
          DismissStatement.make(iJson, widget.aggregation.canonical.value, _pendingDis);
      if (await Lgtm.check(json, context, labeler: widget.model.labeler) != true) {
        if (!mounted) return;
        setState(() {
          _disNotifier.value = _committedDis;
          _pendingDis = _committedDis;
        });
        _sweepController.reset();
        return;
      }
    }
    final signedJson = await _commitDis();
    if (signedJson != null && mounted) {
      await Lgtm.showPublished(signedJson, context, labeler: widget.model.labeler);
    }
  }

  Future<void> _onDisToggle() async {
    if (!mounted) return;
    if ((await checkSignedIn(context, trustGraph: widget.model.trustGraph)) != true) {
      _disNotifier.value = _pendingDis; // revert toggle
      return;
    }
    _pendingDis = _disNotifier.value;
    if (_pendingDis == _committedDis) {
      _sweepController.stop();
      _sweepController.reset();
      setState(() {});
    } else if (_pendingDis == null) {
      // Un-dismiss: commit immediately, no animation needed.
      setState(() {});
      await _commitDis();
    } else {
      _sweepController.forward(from: 0);
      setState(() {});
    }
  }

  Future<Json?> _commitDis() async {
    if (_pendingDis == _committedDis) return null;
    final iJson = signInState.delegatePublicKeyJson;
    final signer = signInState.signer;
    if (iJson == null || signer == null) return null;
    final String canonical = widget.aggregation.canonical.value;
    final Json json = DismissStatement.make(iJson, canonical, _pendingDis);
    try {
      final published = await widget.controller.disSource.push(json, signer);
      _committedDis = _pendingDis;
      await widget.controller.notify();
      return published.json;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchMetadata() async {
    final subject = widget.aggregation.subject;
    final expectedToken = widget.aggregation.token;
    if (subject.containsKey('url') || subject.containsKey('title')) {
      await fetchImages(
        subject: subject,
        onResult: (result) {
          if (mounted && widget.aggregation.token == expectedToken) {
            setState(() {
              _metadata = result;
            });
          }
        },
      );
    }
  }

  void _showInspectionSheet(ContentKey token) {
    // Lookup using ContentKey. This is now dense and literal-subject aware.
    final agg = widget.model.aggregation.subjects[token];
    if (agg == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                controller: scrollController,
                child: ContentCard(
                  aggregation: agg.toNarrow(),
                  model: widget.model,
                  controller: widget.controller,
                  onTagTap: widget.onTagTap,
                  onGraphFocus: widget.onGraphFocus,
                  markedSubjectToken: widget.markedSubjectToken,
                  onMark: widget.onMark,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: isSmall,
        builder: (context, isSmall, _) {
          final subject = widget.aggregation.subject;
          final String title = subject['title']!;
          final String type = subject['contentType']!;

          String? metaImage = _metadata?.image;
          if (metaImage != null && metaImage.isEmpty) metaImage = null;

          final imageUrl = metaImage ??
              getFallbackImageUrl(
                subject['url'],
                type,
                title,
                tags: widget.aggregation.tags.toList(),
              );

          if (isSmall) {
            return Card(
              margin: const EdgeInsets.all(8.0),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Dismissible(
                    key: Key(widget.aggregation.canonical.value),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (!context.mounted) return false;
                      if ((await checkSignedIn(context,
                              trustGraph: widget.model.trustGraph)) !=
                          true) { return false; }
                      final String dis =
                          direction == DismissDirection.startToEnd ? 'snooze' : 'forever';
                      final Json iJson = signInState.delegatePublicKeyJson!;
                      final Json json = DismissStatement.make(
                          iJson, widget.aggregation.canonical.value, dis);
                      await widget.controller.disSource.push(json, signInState.signer!);
                      _committedDis = dis;
                      _pendingDis = dis;
                      _disNotifier.value = dis;
                      await widget.controller.notify();
                      return false; // keep in tree; visibility controlled by filter
                    },
                    background: Container(
                      color: Colors.green,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20.0),
                      child: const Icon(Icons.snooze, color: Colors.white, size: 32),
                    ),
                    secondaryBackground: Container(
                      color: Colors.brown,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20.0),
                      child: const Icon(Icons.swipe_left, color: Colors.white, size: 32),
                    ),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: kIsWeb
                              ? Image.network(
                                  'https://wsrv.nl/?url=${Uri.encodeComponent(imageUrl)}&w=800&fit=cover',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.network(imageUrl, fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image_not_supported, size: 32),
                                        ),
                                      ),
                                )
                              : Image.network(imageUrl, fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image_not_supported, size: 32),
                                  ),
                                ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildActionBar(),
                        ),
                        if (_pendingDis != _committedDis)
                          Positioned.fill(child: _buildSweepOverlay()),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  final subject = widget.aggregation.subject;
                                  String? url = subject['url'];
                                  if (url == null) {
                                    final values = subject.values.where((v) => v != null).join(' ');
                                    url =
                                        'https://www.google.com/search?q=${Uri.encodeComponent(values)}';
                                  }
                                  launchUrl(Uri.parse(url));
                                },
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    type.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTrustSummary(onDark: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.aggregation.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Wrap(
                              spacing: 8.0,
                              children: widget.aggregation.tags.map((tag) => TagChip(
                                tag: tag,
                                aggregation: widget.model.aggregation,
                                controller: widget.controller,
                                onTap: () => widget.onTagTap?.call(tag),
                              )).toList(),
                            ),
                          ),
                        _buildHistorySection(),
                        _buildRelationshipsSection(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: kIsWeb
                              ? Image.network(
                                  'https://wsrv.nl/?url=${Uri.encodeComponent(imageUrl)}&w=200&h=200&fit=cover',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback: Try loading directly if proxy fails
                                    return Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image_not_supported, size: 20),
                                        );
                                      },
                                    );
                                  },
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported, size: 20),
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final subject = widget.aggregation.subject;
                                      String? url = subject['url'];
                                      if (url == null) {
                                        final values =
                                            subject.values.where((v) => v != null).join(' ');
                                        url =
                                            'https://www.google.com/search?q=${Uri.encodeComponent(values)}';
                                      }
                                      launchUrl(Uri.parse(url));
                                    },
                                    child: Text(
                                      title,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                            decoration: TextDecoration.underline,
                                          ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(type.toUpperCase(),
                                          style: Theme.of(context).textTheme.labelSmall),
                                      const SizedBox(width: 8),
                                      _buildTrustSummary(),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: widget.aggregation.tags.isNotEmpty
                                        ? Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Wrap(
                                              spacing: 8.0,
                                              children: widget.aggregation.tags.map((tag) => TagChip(
                                                tag: tag,
                                                aggregation: widget.model.aggregation,
                                                controller: widget.controller,
                                                onTap: () => widget.onTagTap?.call(tag),
                                              )).toList(),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildActionBar(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildHistorySection(),
                  _buildRelationshipsSection(),
                ],
              ),
            ),
          ),
              if (_pendingDis != _committedDis)
                Positioned.fill(
                  left: 8, top: 8, right: 8, bottom: 8,
                  child: _buildSweepOverlay(),
                ),
            ],
          );
        });
  }

  Widget _buildSweepOverlay() {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _sweepController,
        builder: (context, _) {
          final Color color = _pendingDis == 'snooze'
              ? Colors.green
              : _pendingDis == 'forever'
                  ? Colors.brown
                  : Colors.blue;
          final String label = _pendingDis == 'snooze'
              ? 'Snooze'
              : _pendingDis == 'forever'
                  ? 'Dismiss'
                  : 'Un-dismiss';
          return IgnorePointer(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _sweepController.value,
              heightFactor: 1.0,
              child: Container(
                color: color.withValues(alpha: 0.8),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Small, grey, non-interactive counters shown to the right of the content type label.
  // onDark: white-toned icons/text for use over dark image backgrounds (isSmall).
  Widget _buildTrustSummary({bool onDark = false}) {
    final likes = widget.aggregation.likes;
    final dislikes = widget.aggregation.dislikes;
    final comments = widget.aggregation.comments;
    if (likes == 0 && dislikes == 0 && comments == 0) return const SizedBox.shrink();
    final Color color = onDark ? Colors.white70 : Colors.grey;
    final TextStyle numStyle = TextStyle(fontSize: 11, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (likes > 0) ...[
          Icon(Icons.thumb_up, size: 13, color: color),
          const SizedBox(width: 3),
          Text('$likes', style: numStyle),
        ],
        if (likes > 0 && dislikes > 0) const SizedBox(width: 8),
        if (dislikes > 0) ...[
          Icon(Icons.thumb_down, size: 13, color: color),
          const SizedBox(width: 3),
          Text('$dislikes', style: numStyle),
        ],
        if ((likes > 0 || dislikes > 0) && comments > 0) const SizedBox(width: 8),
        if (comments > 0) ...[
          Icon(Icons.chat_bubble_outline, size: 13, color: color),
          const SizedBox(width: 3),
          Text('$comments', style: numStyle),
        ],
      ],
    );
  }

  Widget _buildHistorySection() {
    final allStatements =
        widget.aggregation.statements.where((s) => _shouldShowStatement(s, widget.model)).toList();

    if (allStatements.isEmpty) return const SizedBox.shrink();

    // Sort by trust distance of the author (closest first)
    allStatements.sort((a, b) {
      final distA = widget.model.labeler.graph.distances[IdentityKey(a.iToken)] ?? 999;
      final distB = widget.model.labeler.graph.distances[IdentityKey(b.iToken)] ?? 999;
      return distA.compareTo(distB);
    });

    final roots = allStatements.where((s) {
      final isReplyToOtherInAgg = allStatements.any((other) => other.token == s.subjectToken);
      return !isReplyToOtherInAgg;
    }).toList();

    final topRoots = roots.take(2).toList();
    // Check if comments are truncated. We pass maxLines: 1 to the tiles below.
    final bool anyCommentTruncated = topRoots.any((s) {
      if (s.comment == null) return false;
      // Heuristic: If comment has newlines or is long, assume truncated by maxLines: 1
      return s.comment!.contains('\n') || s.comment!.length > 50;
    });

    final hasMore = allStatements.length > topRoots.length;
    final showExpandButton = hasMore || anyCommentTruncated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isHistoryExpanded)
          ...topRoots.map((s) => StatementTile(
                statement: s,
                model: widget.model,
                controller: widget.controller,
                depth: 0,
                aggregation: widget.aggregation,
                onGraphFocus: widget.onGraphFocus,
                onMark: (token) => widget.onMark?.call(token),
                markedSubjectToken: widget.markedSubjectToken,
                onInspect: _showInspectionSheet,
                onTagTap: widget.onTagTap,
                maxLines: 1,
              )),
        if (_isHistoryExpanded)
          SubjectDetailsView(
            aggregation: widget.aggregation,
            model: widget.model,
            controller: widget.controller,
            onTagTap: widget.onTagTap,
            onGraphFocus: widget.onGraphFocus,
            onMark: widget.onMark,
            markedSubjectToken: widget.markedSubjectToken,
            onInspect: _showInspectionSheet,
          ),
        if (showExpandButton || _isHistoryExpanded)
          Center(
            child: TextButton.icon(
              icon: Icon(_isHistoryExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
              label: Text(_isHistoryExpanded ? 'Show less' : 'Show more'),
              onPressed: () {
                setState(() {
                  _isHistoryExpanded = !_isHistoryExpanded;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRelationshipsSection() {
    final List<Widget> children = [];

    // 1. Equivalents
    final equivalentTokens = widget.model.aggregation.equivalence.entries
        .where((e) => e.value == widget.aggregation.canonical && e.key != widget.aggregation.token)
        .map((e) => e.key)
        .toSet();

    if (widget.aggregation.token != widget.aggregation.canonical) {
      equivalentTokens.add(widget.aggregation.canonical);
    }

    if (equivalentTokens.isNotEmpty) {
      final Map<ContentKey, String> tokenToTitle = {};

      // Try to find titles in current statements
      for (final s in widget.aggregation.statements) {
        // Check Subject
        final subjectKey = ContentKey(s.subjectToken);
        if (equivalentTokens.contains(subjectKey)) {
          final subject = s.subject;
          final title = (subject is Map)
              ? subject['title']!
              : widget.model.labeler.getLabel(subject.toString());
          tokenToTitle[subjectKey] = title;
        }

        // Check Other
        if (s.other != null) {
          final otherKey = ContentKey(getToken(s.other));
          if (equivalentTokens.contains(otherKey)) {
            final other = s.other;
            assert(other is Map);
            final title = other['title'];
            tokenToTitle[otherKey] = title;
          }
        }
      }

      // Also check global aggregation map if missing
      for (final token in equivalentTokens) {
        if (!tokenToTitle.containsKey(token)) {
          final agg = widget.model.aggregation.subjects[token];
          if (agg != null) {
            final subject = agg.subject;
            final title = subject['title']!;
            tokenToTitle[token] = title;
          } else {
            tokenToTitle[token] = widget.model.labeler.getLabel(token.value);
          }
        }
      }

      for (final entry in tokenToTitle.entries) {
        String icon = '=';
        if (widget.aggregation.token == widget.aggregation.canonical) {
          icon = '<=';
        } else if (entry.key == widget.aggregation.canonical) {
          icon = '=>';
        }
        children.add(_buildRelationTile(icon, entry.key, entry.value));
      }
    }

    // 2. Related
    final relatedTokens = widget.aggregation.related
        .where(
            (token) => widget.model.aggregation.equivalence[token] != widget.aggregation.canonical)
        .toList();

    for (final token in relatedTokens) {
      final relatedAgg = widget.model.aggregation.subjects[token];
      String title;
      if (relatedAgg != null) {
        final subject = relatedAgg.subject;
        title = subject['title']!;
      } else {
        title = widget.model.labeler.getLabel(token.value);
      }
      children.add(_buildRelationTile('≈', token, title));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    final topChildren = children.take(2).toList();
    final hasMore = children.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        ...(_isRelationshipsExpanded ? children : topChildren),
        if (hasMore)
          Center(
            child: TextButton.icon(
              icon:
                  Icon(_isRelationshipsExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
              label: Text(
                  _isRelationshipsExpanded ? 'Show less' : 'Show all related (${children.length})'),
              onPressed: () {
                setState(() {
                  _isRelationshipsExpanded = !_isRelationshipsExpanded;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRelationTile(String iconText, ContentKey token, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child:
                Text(iconText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => _showInspectionSheet(token),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final List<ContentStatement> myLiteralStatements =
        List.from(widget.model.aggregation.myLiteralStatements[widget.aggregation.token] ?? []);
    Statement.validateOrderTypes(myLiteralStatements);
    final hasPrior = myLiteralStatements.any((s) => s.verb == ContentVerb.rate);

    IconData icon = Icons.rate_review_outlined;
    String tooltip;

    if (hasPrior) {
      tooltip = 'You reacted to this';
    } else {
      tooltip = 'React';
    }

    // Counters are below the content type label in both views — not in the action chip.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Link icon — subtle
          if (widget.onMark != null)
            ValueListenableBuilder<ContentKey?>(
              valueListenable: widget.markedSubjectToken ?? ValueNotifier(null),
              builder: (context, marked, _) {
                final isMarked = marked == widget.aggregation.token;
                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.link,
                      color: isMarked ? Colors.orange : Colors.grey[500],
                      size: 22,
                    ),
                    tooltip: isMarked ? 'Unmark' : 'Mark to Relate/Equate',
                    onPressed: () async {
                      if ((await checkSignedIn(context, trustGraph: widget.model.trustGraph)) ==
                          true) {
                        widget.onMark!(widget.aggregation.token);
                      }
                    },
                  ),
                );
              },
            ),
          // Dismiss/snooze toggle — both views
          DisToggle(notifier: _disNotifier, callback: _onDisToggle),
          const SizedBox(width: 2),
          // React button — filled, inviting, rightmost
          Tooltip(
            message: tooltip,
            child: GestureDetector(
              onTap: _react,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasPrior ? linkColorAlready : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );

  }

  Future<void> _react() async {
    final ContentStatement? statement = await RateDialog.show(
      context,
      widget.aggregation,
      widget.controller,
    );
    if (statement != null) {
      // Handled by controller.push
    }
  }
}


class SubjectDetailsView extends StatelessWidget {
  final SubjectAggregation aggregation;
  final FeedModel model;
  final FeedController controller;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<String?>? onGraphFocus;
  final ValueChanged<ContentKey?>? onMark;
  final ValueNotifier<ContentKey?>? markedSubjectToken;
  final ValueChanged<ContentKey>? onInspect;

  const SubjectDetailsView({
    super.key,
    required this.aggregation,
    required this.model,
    required this.controller,
    this.onTagTap,
    this.onGraphFocus,
    this.onMark,
    this.markedSubjectToken,
    this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    // Build the tree
    final List<Widget> tree = [];

    final roots = aggregation.statements.where((s) {
      final isReplyToOtherInAgg =
          aggregation.statements.any((other) => other.token == s.subjectToken);
      return !isReplyToOtherInAgg;
    }).toList();

    roots.sort((a, b) {
      final distA = model.labeler.graph.distances[IdentityKey(a.iToken)] ?? 999;
      final distB = model.labeler.graph.distances[IdentityKey(b.iToken)] ?? 999;
      return distA.compareTo(distB);
    });

    for (final root in roots) {
      _buildTreeRecursive(context, root, 0, tree);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...tree,
      ],
    );
  }

  void _buildTreeRecursive(BuildContext context, ContentStatement s, int depth, List<Widget> tree) {
    if (!_shouldShowStatement(s, model)) return;

    tree.add(StatementTile(
      statement: s,
      model: model,
      controller: controller,
      depth: depth,
      aggregation: aggregation,
      onGraphFocus: onGraphFocus,
      onMark: onMark,
      markedSubjectToken: markedSubjectToken,
      onInspect: onInspect,
      onTagTap: onTagTap,
    ));

    final canonicalToken =
        model.aggregation.equivalence[ContentKey(s.token)] ?? ContentKey(s.token);
    final replies = [
      ...aggregation.statements.where((other) => other.subjectToken == s.token),
      ...(model.aggregation.subjects[canonicalToken]?.statements ?? []),
    ];

    final seen = {s.token};
    final uniqueReplies = replies.where((r) => seen.add(r.token)).toList();

    uniqueReplies.sort((a, b) {
      final distA = model.labeler.graph.distances[IdentityKey(a.iToken)] ?? 999;
      final distB = model.labeler.graph.distances[IdentityKey(b.iToken)] ?? 999;
      return distA.compareTo(distB);
    });

    for (final reply in uniqueReplies) {
      _buildTreeRecursive(context, reply, depth + 1, tree);
    }
  }
}

bool _shouldShowStatement(ContentStatement s, FeedModel model) {
  final canonicalToken = model.aggregation.equivalence[ContentKey(s.token)] ?? ContentKey(s.token);
  final subjectAgg = model.aggregation.subjects[canonicalToken];
  if (subjectAgg == null) return true;

  if (model.enableCensorship && subjectAgg.isCensored) return false;

  switch (model.filterMode) {
    case DisFilterMode.my:
      final myDis = model.aggregation.myDismissStatements[subjectAgg.canonical] ?? [];
      return !SubjectGroup.checkIsDismissed(myDis, subjectAgg);
    case DisFilterMode.ignore:
      return true;
  }
}
