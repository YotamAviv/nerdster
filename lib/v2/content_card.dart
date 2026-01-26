import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/v2/metadata_service.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/rate_dialog.dart';
import 'package:nerdster/v2/statement_tile.dart';
import 'package:nerdster/v2/feed_controller.dart'; // Added
import 'package:url_launcher/url_launcher.dart';

class ContentCard extends StatefulWidget {
  final SubjectAggregation aggregation;
  final V2FeedModel model;
  final V2FeedController controller; // Added
  final ValueChanged<String?>? onTagTap;
  final ValueChanged<String?>? onGraphFocus;
  final ValueNotifier<ContentKey?>? markedSubjectToken;
  final ValueChanged<ContentKey?>? onMark;

  const ContentCard({
    super.key,
    required this.aggregation,
    required this.model,
    required this.controller, // Added
    this.onTagTap,
    this.onGraphFocus,
    this.markedSubjectToken,
    this.onMark,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  MetadataResult? _metadata;
  bool _isHistoryExpanded = false;
  bool _isRelationshipsExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  @override
  void didUpdateWidget(ContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aggregation.canonical != widget.aggregation.canonical) {
      _metadata = null;
      _fetchMetadata();
    }
  }

  Future<void> _fetchMetadata() async {
    final subject = widget.aggregation.subject;
    if (subject.containsKey('url') || subject.containsKey('title')) {
      await fetchImages(
        subject: subject,
        onResult: (result) {
          if (mounted) {
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                controller: scrollController,
                child: ContentCard(
                  aggregation: agg.toNarrow(),
                  model: widget.model,
                  controller: widget.controller, // Added
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
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: kIsWeb
                            ? Image.network(
                                'https://wsrv.nl/?url=${Uri.encodeComponent(imageUrl)}&w=800&fit=cover',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.network(imageUrl, fit: BoxFit.cover),
                              )
                            : Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.4),
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
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
                            Text(
                              type.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                              children: widget.aggregation.tags.map((tag) {
                                final displayTag = tag.startsWith('#') ? tag : '#$tag';
                                return InkWell(
                                  onTap: () => widget.onTagTap?.call(tag),
                                  child:
                                      Text(displayTag, style: const TextStyle(color: Colors.blue)),
                                );
                              }).toList(),
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

          return Card(
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
                                  Text(type.toUpperCase(),
                                      style: Theme.of(context).textTheme.labelSmall),
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
                                              children: widget.aggregation.tags.map((tag) {
                                                final displayTag =
                                                    tag.startsWith('#') ? tag : '#$tag';
                                                return InkWell(
                                                  onTap: () => widget.onTagTap?.call(tag),
                                                  child: Text(displayTag,
                                                      style: const TextStyle(color: Colors.blue)),
                                                );
                                              }).toList(),
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
          );
        });
  }

  Widget _buildTrustSummary() {
    final likes = widget.aggregation.likes;
    final dislikes = widget.aggregation.dislikes;
    if (likes == 0 && dislikes == 0) return const SizedBox.shrink();
    return Row(
      children: [
        if (likes > 0) ...[
          const Icon(Icons.thumb_up, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Text('$likes', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
        if (likes > 0 && dislikes > 0) const SizedBox(width: 8),
        if (dislikes > 0) ...[
          const Icon(Icons.thumb_down, size: 16, color: Colors.red),
          const SizedBox(width: 4),
          Text('$dislikes', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final hasMore = allStatements.length > topRoots.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isHistoryExpanded)
          ...topRoots.map((s) => StatementTile(
                statement: s,
                model: widget.model,
                controller: widget.controller, // Added
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
            controller: widget.controller, // Added
            onTagTap: widget.onTagTap,
            onGraphFocus: widget.onGraphFocus,
            onMark: widget.onMark,
            markedSubjectToken: widget.markedSubjectToken,
            onInspect: _showInspectionSheet,
          ),
        if (hasMore || _isHistoryExpanded)
          Center(
            child: TextButton.icon(
              icon: Icon(_isHistoryExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
              label: Text(_isHistoryExpanded
                  ? 'Show less'
                  : 'Show full history (${allStatements.length} total)'),
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
    Color? color;
    String tooltip;

    if (hasPrior) {
      color = Colors.blue;
      tooltip = 'You reacted to this';
    } else {
      color = Colors.grey;
      tooltip = 'React';
    }

    final likes = widget.aggregation.likes;
    final dislikes = widget.aggregation.dislikes;
    final hasTrustInfo = likes > 0 || dislikes > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onMark != null)
            ValueListenableBuilder<ContentKey?>(
              valueListenable: widget.markedSubjectToken ?? ValueNotifier(null),
              builder: (context, marked, _) {
                final isMarked = marked == widget.aggregation.token;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.link,
                      color: isMarked ? Colors.orange : Colors.grey,
                      size: 20,
                    ),
                    tooltip: isMarked ? 'Unmark' : 'Mark to Relate/Equate',
                    onPressed: () async {
                      if (bb(await checkSignedIn(context, trustGraph: widget.model.trustGraph))) {
                        widget.onMark!(widget.aggregation.token);
                      }
                    },
                  ),
                );
              },
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(icon, color: color, size: 20),
            tooltip: tooltip,
            onPressed: _react,
          ),
          if (hasTrustInfo) ...[
            const SizedBox(width: 12),
            _buildTrustSummary(),
          ],
        ],
      ),
    );
  }

  Future<void> _react() async {
    final ContentStatement? statement = await V2RateDialog.show(
      context,
      widget.aggregation,
      widget.controller, // Changed from model
      intent: RateIntent.none,
    );
    if (statement != null) {
      // Handled by controller.push
    }
  }
}

class SubjectDetailsView extends StatelessWidget {
  final SubjectAggregation aggregation;
  final V2FeedModel model;
  final V2FeedController controller; // Added
  final ValueChanged<String>? onTagTap;
  final ValueChanged<String?>? onGraphFocus;
  final ValueChanged<ContentKey?>? onMark;
  final ValueNotifier<ContentKey?>? markedSubjectToken;
  final ValueChanged<ContentKey>? onInspect;

  const SubjectDetailsView({
    super.key,
    required this.aggregation,
    required this.model,
    required this.controller, // Added
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
      controller: controller, // Added
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

bool _shouldShowStatement(ContentStatement s, V2FeedModel model) {
  final canonicalToken = model.aggregation.equivalence[ContentKey(s.token)] ?? ContentKey(s.token);
  final subjectAgg = model.aggregation.subjects[canonicalToken];
  if (subjectAgg == null) return true;

  if (model.enableCensorship && subjectAgg.isCensored) return false;

  switch (model.filterMode) {
    case DisFilterMode.my:
      final myStmts = model.aggregation.myCanonicalDisses[subjectAgg.canonical] ?? [];
      return !SubjectGroup.checkIsDismissed(myStmts, subjectAgg);
    case DisFilterMode.pov:
      return !subjectAgg.isDismissed;
    case DisFilterMode.ignore:
      return true;
  }
}
