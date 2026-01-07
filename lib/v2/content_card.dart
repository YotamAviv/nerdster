import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nerdster/v2/keys.dart';import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/metadata_service.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/rate_dialog.dart';
import 'package:nerdster/v2/statement_tile.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/util.dart';

class ContentCard extends StatefulWidget {
  final SubjectAggregation aggregation;
  final V2FeedModel model;
  final VoidCallback? onRefresh;
  final ValueChanged<String?>? onPovChange;
  final ValueChanged<String?>? onTagTap;
  final ValueChanged<String?>? onGraphFocus;
  final String? markedSubjectToken;
  final ValueChanged<String?>? onMark;

  const ContentCard({
    super.key,
    required this.aggregation,
    required this.model,
    this.onRefresh,
    this.onPovChange,
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
    if (oldWidget.aggregation.canonicalToken != widget.aggregation.canonicalToken) {
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

  void _showInspectionSheet(String token) {
    var agg = widget.model.aggregation.subjects[token];

    if (agg == null) {
      // Check if it's an equivalent subject
      final canonical = widget.model.aggregation.equivalence[token];
      if (canonical != null) {
        final canonicalAgg = widget.model.aggregation.subjects[canonical];
        if (canonicalAgg != null) {
          // Found the canonical parent.
          // Try to find the subject object for 'token' in the statements.
          dynamic subjectObj;
          for (final s in canonicalAgg.statements) {
            if (s.subjectToken == token) {
              subjectObj = s.subject;
              break;
            }
            if (s.other != null && getToken(s.other) == token) {
              subjectObj = s.other;
              break;
            }
          }

          if (subjectObj == null) {
            subjectObj = token;
          }

          agg = SubjectAggregation(
            subject: subjectObj,
            statements: canonicalAgg.statements,
            likes: canonicalAgg.likes,
            dislikes: canonicalAgg.dislikes,
            related: canonicalAgg.related,
            tags: canonicalAgg.tags,
            lastActivity: canonicalAgg.lastActivity,
            isCensored: canonicalAgg.isCensored,
            myDelegateStatements: canonicalAgg.myDelegateStatements,
            povStatements: canonicalAgg.povStatements,
          );
        }
      }
    }

    if (agg == null) return;
    final safeAgg = agg;

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
                  aggregation: safeAgg,
                  model: widget.model,
                  onRefresh: widget.onRefresh,
                  onPovChange: widget.onPovChange,
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

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActionBar(),
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
                                    child: const Icon(Icons.image_not_supported,
                                        size: 20),
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
                                child:
                                    const Icon(Icons.image_not_supported, size: 20),
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
                                  final values = subject.values.where((v) => v != null).join(' ');
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
                            Text(type.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        if (widget.aggregation.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
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
    final comments =
        widget.aggregation.statements.where((s) => _shouldShowStatement(s, widget.model)).toList();

    // Sort by trust distance of the author (closest first)
    comments.sort((a, b) {
      final distA = widget.model.labeler.graph.distances[a.iToken] ?? 999;
      final distB = widget.model.labeler.graph.distances[b.iToken] ?? 999;
      return distA.compareTo(distB);
    });

    if (comments.isEmpty) return const SizedBox.shrink();

    final topComments = comments.take(2).toList();
    final hasMore = comments.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isHistoryExpanded)
          ...topComments.map((s) => StatementTile(
                statement: s,
                model: widget.model,
                depth: 0,
                aggregation: widget.aggregation,
                onGraphFocus: widget.onGraphFocus,
                onMark: widget.onMark,
                markedSubjectToken: widget.markedSubjectToken,
                onInspect: _showInspectionSheet,
                onRefresh: widget.onRefresh,
                onTagTap: widget.onTagTap,
                maxLines: 1,
              )),
        if (_isHistoryExpanded)
          SubjectDetailsView(
            aggregation: widget.aggregation,
            model: widget.model,
            onRefresh: widget.onRefresh,
            onPovChange: widget.onPovChange,
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
              label:
                  Text(_isHistoryExpanded ? 'Show less' : 'Show all history (${comments.length})'),
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
        .where((e) => e.value == widget.aggregation.canonicalToken && e.key != widget.aggregation.canonicalToken)
        .map((e) => e.key)
        .toSet();

    if (equivalentTokens.isNotEmpty) {
      final Map<ContentKey, String> tokenToTitle = {};

      // Try to find titles in current statements
      for (final s in widget.aggregation.statements) {
        if (equivalentTokens.contains(ContentKey(s.subjectToken))) {
          final subject = s.subject;
          final title = (subject is Map)
              ? subject['title']!
              : widget.model.labeler.getLabel(subject.toString());
          tokenToTitle[ContentKey(s.subjectToken)] = title;
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
        children.add(_buildRelationTile('=', entry.key.value, entry.value));
      }
    }

    // 2. Related
    final relatedTokens = widget.aggregation.related
        .where((token) =>
            widget.model.aggregation.equivalence[token] != widget.aggregation.canonicalToken)
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
      children.add(_buildRelationTile('≈', token.value, title));
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

  Widget _buildRelationTile(String iconText, String token, String title) {
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
    if (signInState.identity == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Text(
            'Sign in to rate or comment',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      );
    }

    final myStatements = widget.aggregation.statements
        .where((s) => widget.model.labeler.getIdentityForToken(s.iToken) == signInState.identity)
        .toList();

    // Sort by time descending to find the latest
    myStatements.sort((a, b) => b.time.compareTo(a.time));

    final hasPrior = myStatements.any((s) => s.verb == ContentVerb.rate);

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onMark != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.link,
              color: widget.markedSubjectToken == widget.aggregation.canonicalToken.value
                  ? Colors.orange
                  : Colors.grey,
            ),
            tooltip: widget.markedSubjectToken == widget.aggregation.canonicalToken.value
                ? 'Unmark'
                : 'Mark to Relate/Equate',
            onPressed: () async {
              if (bb(await checkSignedIn(context, trustGraph: widget.model.trustGraph))) {
                widget.onMark!(widget.aggregation.canonicalToken.value);
              }
            },
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: color),
          tooltip: tooltip,
          onPressed: _react,
        ),
        const SizedBox(width: 8),
        _buildTrustSummary(),
      ],
    );
  }

  Future<void> _react() async {
    await V2RateDialog.show(
      context,
      widget.aggregation,
      widget.model,
      intent: RateIntent.none,
      onRefresh: widget.onRefresh,
    );
  }
}

class SubjectDetailsView extends StatelessWidget {
  final SubjectAggregation aggregation;
  final V2FeedModel model;
  final VoidCallback? onRefresh;
  final ValueChanged<String?>? onPovChange;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<String?>? onGraphFocus;
  final ValueChanged<String>? onMark;
  final String? markedSubjectToken;
  final ValueChanged<String>? onInspect;

  const SubjectDetailsView({
    super.key,
    required this.aggregation,
    required this.model,
    this.onRefresh,
    this.onPovChange,
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
      final distA = model.labeler.graph.distances[a.iToken] ?? 999;
      final distB = model.labeler.graph.distances[b.iToken] ?? 999;
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
      depth: depth,
      aggregation: aggregation,
      onGraphFocus: onGraphFocus,
      onMark: onMark,
      markedSubjectToken: markedSubjectToken,
      onInspect: onInspect,
      onRefresh: onRefresh,
      onTagTap: onTagTap,
    ));

    final canonicalToken = model.aggregation.equivalence[s.token] ?? s.token;
    final replies = [
      ...aggregation.statements.where((other) => other.subjectToken == s.token),
      ...(model.aggregation.subjects[canonicalToken]?.statements ?? []),
    ];

    final seen = {s.token};
    final uniqueReplies = replies.where((r) => seen.add(r.token)).toList();

    uniqueReplies.sort((a, b) {
      final distA = model.labeler.graph.distances[a.iToken] ?? 999;
      final distB = model.labeler.graph.distances[b.iToken] ?? 999;
      return distA.compareTo(distB);
    });

    for (final reply in uniqueReplies) {
      _buildTreeRecursive(context, reply, depth + 1, tree);
    }
  }
}

bool _shouldShowStatement(ContentStatement s, V2FeedModel model) {
  final canonicalToken = model.aggregation.equivalence[s.token] ?? s.token;
  final subjectAgg = model.aggregation.subjects[canonicalToken];
  if (subjectAgg == null) return true;

  if (model.enableCensorship && subjectAgg.isCensored) return false;

  switch (model.filterMode) {
    case V2FilterMode.myDisses:
      return !subjectAgg.isUserDismissed;
    case V2FilterMode.povDisses:
      return !subjectAgg.isDismissed;
    case V2FilterMode.ignoreDisses:
      return true;
  }
}
