import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/metadata_service.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/rate_dialog.dart';
import 'package:nerdster/comment_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/setting_type.dart';

class ContentCard extends StatefulWidget {
  final SubjectAggregation aggregation;
  final V2FeedModel model;
  final VoidCallback? onRefresh;
  final ValueChanged<String?>? onPovChange;
  final ValueChanged<String?>? onTagTap;

  const ContentCard({
    super.key,
    required this.aggregation,
    required this.model,
    this.onRefresh,
    this.onPovChange,
    this.onTagTap,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  MetadataResult? _metadata;
  bool _expanded = false;

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
    if (subject is Map && (subject.containsKey('url') || subject.containsKey('title'))) {
      await fetchImages(
        subject: Map<String, dynamic>.from(subject),
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

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.aggregation.subject;
    final String title = (subject is Map)
        ? (subject['title'] ?? 'Untitled')
        : widget.model.labeler.getLabel(subject.toString());
    final String type = (subject is Map) ? (subject['contentType'] ?? 'UNKNOWN') : 'IDENTITY';

    String? metaImage = _metadata?.image;
    if (metaImage != null && metaImage.isEmpty) metaImage = null;

    final imageUrl = metaImage ?? 'https://picsum.photos/seed/${widget.aggregation.canonicalToken}/600/400';

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: _toggleExpand,
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
                      child: Image.network(
                        kIsWeb 
                          ? 'https://wsrv.nl/?url=${Uri.encodeComponent(imageUrl)}&w=200&h=200&fit=cover'
                          : imageUrl,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            final subject = widget.aggregation.subject;
                            String? url;
                            if (subject is Map) {
                              url = subject['url'];
                              if (url == null) {
                                final values = subject.values.where((v) => v != null).join(' ');
                                url = 'https://www.google.com/search?q=${Uri.encodeComponent(values)}';
                              }
                            } else {
                              url = 'https://www.google.com/search?q=${Uri.encodeComponent(title)}';
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
                  ),
                  _buildTrustSummary(),
                ],
              ),
              if (widget.aggregation.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: widget.aggregation.tags.map((tag) => Text('#$tag', style: const TextStyle(color: Colors.blue))).toList(),
                  ),
                ),
              const Divider(),
              _buildTopComments(),
              _buildActionBar(),
              if (_expanded) ...[
                const Divider(),
                SubjectDetailsView(
                  aggregation: widget.aggregation,
                  model: widget.model,
                  onRefresh: widget.onRefresh,
                  onPovChange: widget.onPovChange,
                  onTagTap: widget.onTagTap,
                ),
              ],
            ],
          ),
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

  Widget _buildTopComments() {
    final comments = widget.aggregation.statements
        .where((s) => s.comment != null && s.comment!.isNotEmpty)
        .where((s) => _shouldShowStatement(s, widget.model))
        .toList();

    // Sort by trust distance of the author (closest first)
    comments.sort((a, b) {
      final distA = widget.model.labeler.graph.distances[a.iToken] ?? 999;
      final distB = widget.model.labeler.graph.distances[b.iToken] ?? 999;
      return distA.compareTo(distB);
    });

    final topComments = comments.take(2).toList();

    if (topComments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topComments.map((s) {
        final label = widget.model.labeler.getLabel(s.iToken);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Text(
                    '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                WidgetSpan(
                  child: CommentWidget(
                    text: s.comment!,
                    onHashtagTap: (tag, _) => widget.onTagTap?.call(tag),
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
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

    final userLike = widget.aggregation.statements.any((s) => 
      s.like == true && widget.model.labeler.getIdentityForToken(s.iToken) == signInState.identity);
    final userDislike = widget.aggregation.statements.any((s) => 
      s.like == false && widget.model.labeler.getIdentityForToken(s.iToken) == signInState.identity);
    final userDismissed = widget.aggregation.statements.any((s) => 
      s.dismiss == true && widget.model.labeler.getIdentityForToken(s.iToken) == signInState.identity);
    final hasPrior = widget.aggregation.statements.any((s) => 
      widget.model.labeler.getIdentityForToken(s.iToken) == signInState.identity);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasPrior)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Clear my rating',
            onPressed: _clear,
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            userLike ? Icons.thumb_up : Icons.thumb_up_outlined,
            color: userLike ? Colors.green : null,
          ),
          tooltip: 'Like',
          onPressed: () => _rate(true),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            userDislike ? Icons.thumb_down : Icons.thumb_down_outlined,
            color: userDislike ? Colors.red : null,
          ),
          tooltip: 'Dislike',
          onPressed: () => _rate(false),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.comment_outlined),
          tooltip: 'Comment',
          onPressed: _comment,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            userDismissed ? Icons.swipe_left : Icons.swipe_left_outlined,
            color: userDismissed ? Colors.brown : null,
          ),
          tooltip: 'Dismiss (I don\'t care to see this again)',
          onPressed: _dismiss,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Censor this subject for everybody (who cares)',
          onPressed: _censor,
        ),
      ],
    );
  }

  bool _checkDelegate() {
    if (signInState.delegate == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delegate Key Required'),
          content: const Text('You are signed in with an identity key, but you need a delegate key to sign content statements (likes, comments, etc.). Please sign in with a delegate key.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _rate(bool like) async {
    if (!_checkDelegate()) return;
    await V2RateDialog.show(
      context,
      widget.aggregation,
      widget.model,
      intent: like ? RateIntent.like : RateIntent.dislike,
      onRefresh: widget.onRefresh,
    );
  }

  Future<void> _clear() async {
    if (!_checkDelegate()) return;
    await V2RateDialog.show(
      context,
      widget.aggregation,
      widget.model,
      intent: RateIntent.clear,
      onRefresh: widget.onRefresh,
    );
  }

  Future<void> _dismiss() async {
    if (!_checkDelegate()) return;
    await V2RateDialog.show(
      context,
      widget.aggregation,
      widget.model,
      intent: RateIntent.dismiss,
      onRefresh: widget.onRefresh,
    );
  }

  Future<void> _comment() async {
    if (!_checkDelegate()) return;
    await V2RateDialog.show(
      context,
      widget.aggregation,
      widget.model,
      intent: RateIntent.comment,
      onRefresh: widget.onRefresh,
    );
  }

  Future<void> _censor() async {
    if (!_checkDelegate()) return;
    await V2RateDialog.show(
      context,
      widget.aggregation,
      widget.model,
      intent: RateIntent.censor,
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

  const SubjectDetailsView({
    super.key,
    required this.aggregation,
    required this.model,
    this.onRefresh,
    this.onPovChange,
    this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build the tree
    final List<Widget> tree = [];
    
    final roots = aggregation.statements.where((s) {
      final isReplyToOtherInAgg = aggregation.statements.any((other) => other.token == s.subjectToken);
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Full History', style: Theme.of(context).textTheme.titleMedium),
        ),
        ...tree,
      ],
    );
  }

  void _buildTreeRecursive(BuildContext context, ContentStatement s, int depth, List<Widget> tree) {
    if (!_shouldShowStatement(s, model)) return;
    
    tree.add(_buildStatementTile(context, s, depth));
    
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

  Widget _buildStatementTile(BuildContext context, ContentStatement s, int depth) {
    final label = model.labeler.getLabel(s.iToken);
    final isMe = signInState.identity != null && model.labeler.getIdentityForToken(s.iToken) == signInState.identity;

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        color: isMe ? Colors.blue[50] : Colors.grey[50],
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            child: Text(label.isNotEmpty ? label[0] : '?', style: const TextStyle(fontSize: 12)),
          ),
          title: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onPovChange != null)
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  tooltip: 'View from this POV',
                  onPressed: () => onPovChange!(s.iToken),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, size: 16),
                tooltip: 'Clear my rating',
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    canonicalToken: s.token,
                    subject: s.json,
                    lastActivity: s.time,
                  ),
                  model,
                  intent: RateIntent.clear,
                  onRefresh: onRefresh,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.thumb_up, size: 16, color: Colors.green),
                tooltip: 'Like',
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    canonicalToken: s.token,
                    subject: s.json,
                    lastActivity: s.time,
                  ),
                  model,
                  intent: RateIntent.like,
                  onRefresh: onRefresh,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.thumb_down, size: 16, color: Colors.orange),
                tooltip: 'Dislike',
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    canonicalToken: s.token,
                    subject: s.json,
                    lastActivity: s.time,
                  ),
                  model,
                  intent: RateIntent.dislike,
                  onRefresh: onRefresh,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.comment, size: 16, color: Colors.blue),
                tooltip: 'Comment',
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    canonicalToken: s.token,
                    subject: s.json,
                    lastActivity: s.time,
                  ),
                  model,
                  intent: RateIntent.comment,
                  onRefresh: onRefresh,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.swipe_left, size: 16, color: Colors.brown),
                tooltip: 'Dismiss (I don\'t care to see this again)',
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    canonicalToken: s.token,
                    subject: s.json,
                    lastActivity: s.time,
                  ),
                  model,
                  intent: RateIntent.dismiss,
                  onRefresh: onRefresh,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                tooltip: 'Censor this subject for everybody (who cares)',
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    canonicalToken: s.token,
                    subject: s.json,
                    lastActivity: s.time,
                  ),
                  model,
                  intent: RateIntent.censor,
                  onRefresh: onRefresh,
                ),
                visualDensity: VisualDensity.compact,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Setting.get<bool>(SettingType.showCrypto),
                builder: (context, showCrypto, _) {
                  if (!showCrypto) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.verified_user, size: 16, color: Colors.blue),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cryptographic Proof'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: JsonDisplay(s.json),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                        ],
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ],
          ),
          subtitle: s.comment != null && s.comment!.isNotEmpty 
              ? CommentWidget(
                  text: s.comment!,
                  onHashtagTap: (tag, _) => onTagTap?.call(tag),
                )
              : null,
          trailing: s.like == true
              ? const Icon(Icons.thumb_up, color: Colors.green, size: 16)
              : (s.like == false ? const Icon(Icons.thumb_down, color: Colors.red, size: 16) : null),
        ),
      ),
    );
  }
}

bool _shouldShowStatement(ContentStatement s, V2FeedModel model) {
  final canonicalToken = model.aggregation.equivalence[s.token] ?? s.token;
  final subjectAgg = model.aggregation.subjects[canonicalToken];
  if (subjectAgg == null) return true;

  if (model.enableCensorship && subjectAgg.isCensored) return false;

  switch (model.filterMode) {
    case V2FilterMode.myDisses:
      if (subjectAgg.userDismissalTimestamp == null) return true;
      return subjectAgg.lastActivity.isAfter(subjectAgg.userDismissalTimestamp!);
    case V2FilterMode.povDisses:
      if (subjectAgg.povDismissalTimestamp == null) return true;
      return subjectAgg.lastActivity.isAfter(subjectAgg.povDismissalTimestamp!);
    case V2FilterMode.ignoreDisses:
      return true;
  }
}
