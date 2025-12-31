
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/content/dialogs/relate_dialog.dart';

import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/metadata_service.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/rate_dialog.dart';
import 'package:nerdster/comment_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/json_display.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/setting_type.dart';

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
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  @override
  void didUpdateWidget(ContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aggregation.token != widget.aggregation.token) {
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

  void _showInspectionSheet(String token) {
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
                  aggregation: agg,
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

  void _showStatementDialog(BuildContext context, ContentStatement s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statement Details'),
        content: SingleChildScrollView(
          child: Text(s.jsonish.ppJson),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
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

    final imageUrl = metaImage ?? 'https://picsum.photos/seed/${widget.aggregation.token}/600/400';

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: _toggleExpand,
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
                ],
              ),
              _buildEquivalentSubjects(),
              if (widget.aggregation.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: widget.aggregation.tags.map((tag) => Text('#$tag', style: const TextStyle(color: Colors.blue))).toList(),
                  ),
                ),
              _buildRelatedSubjects(),
              const Divider(),
              _buildBriefHistory(),
              if (_expanded) ...[
                const Divider(),
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

  Widget _buildBriefHistory() {
    final comments = widget.aggregation.statements
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
        
        // Icons for reaction
        final List<Widget> icons = [];
        if (s.like == true) icons.add(const Icon(Icons.thumb_up, size: 12, color: Colors.green));
        if (s.like == false) icons.add(const Icon(Icons.thumb_down, size: 12, color: Colors.red));
        if (s.comment != null && s.comment!.isNotEmpty) icons.add(const Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey));
        if (s.dismiss == true) icons.add(const Icon(Icons.swipe_left, size: 12, color: Colors.brown));

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              InkWell(
                onTap: () => widget.onGraphFocus?.call(s.iToken),
                child: Text(
                  '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (icons.isNotEmpty) ...[
                const Text('[', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ...icons.expand((i) => [i, const SizedBox(width: 2)]).take(icons.length * 2 - 1),
                const Text('] ', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
              Expanded(
                child: Text(
                  s.comment ?? (s.like == true ? 'Liked' : (s.like == false ? 'Disliked' : 'Reacted')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEquivalentSubjects() {
    // Find all subjects that are equivalent to this one
    final equivalentTokens = widget.model.aggregation.equivalence.entries
        .where((e) => e.value == widget.aggregation.token && e.key != widget.aggregation.token)
        .map((e) => e.key)
        .toSet();

    if (equivalentTokens.isEmpty) return const SizedBox.shrink();

    // We need to find the titles for these tokens.
    // We can look at the statements in the aggregation to find the subjects.
    final Map<String, String> tokenToTitle = {};
    final equateStatements = <String, List<ContentStatement>>{};

    for (final s in widget.aggregation.statements) {
      if (equivalentTokens.contains(s.subjectToken)) {
        final subject = s.subject;
        final title = (subject is Map) ? (subject['title'] ?? 'Untitled') : widget.model.labeler.getLabel(subject.toString());
        tokenToTitle[s.subjectToken] = title;
      }
      
      if (s.verb == ContentVerb.equate) {
        final otherToken = getToken(s.other);
        if (equivalentTokens.contains(s.subjectToken)) {
          equateStatements.putIfAbsent(s.subjectToken, () => []).add(s);
        }
        if (equivalentTokens.contains(otherToken)) {
          equateStatements.putIfAbsent(otherToken, () => []).add(s);
        }
      }
    }

    return ExpansionTile(
      title: Text('Equivalents: ${equivalentTokens.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      children: tokenToTitle.entries.map((e) {
        final statements = equateStatements[e.key] ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              title: InkWell(
                onTap: () => _showInspectionSheet(e.key),
                child: Text(
                  e.value,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.black,
                  ),
                ),
              ),
              trailing: widget.onMark != null
                  ? IconButton(
                      icon: Icon(
                        Icons.link,
                        color: widget.markedSubjectToken == e.key ? Colors.orange : Colors.grey,
                      ),
                      onPressed: () => widget.onMark!(e.key),
                      tooltip: widget.markedSubjectToken == e.key ? 'Unmark' : 'Mark to Un-Equate',
                    )
                  : null,
            ),
            ...statements.map((s) {
               final identity = widget.model.labeler.getIdentityForToken(s.iToken);
               final authorName = widget.model.labeler.getLabel(s.iToken);
               return Padding(
                 padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                 child: Row(
                   children: [
                     InkWell(
                       onTap: () => _showStatementDialog(context, s),
                       child: const Icon(Icons.verified_user, color: Colors.blue, size: 16),
                     ),
                     const SizedBox(width: 4),
                     const Text('Equated by: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                     InkWell(
                       onTap: () {
                         widget.onGraphFocus?.call(identity);
                       },
                       child: Text(authorName, style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline)),
                     ),
                   ],
                 ),
               );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRelatedSubjects() {
    if (widget.aggregation.related.isEmpty) return const SizedBox.shrink();

    // Find statements that established these relationships
    final relatedStatements = <String, List<ContentStatement>>{};
    
    for (final token in widget.aggregation.related) {
      relatedStatements[token] = [];
    }

    // Check statements in this aggregation (where subject == this card)
    for (final s in widget.aggregation.statements) {
      if (s.verb == ContentVerb.relate && s.other != null) {
        final otherToken = getToken(s.other);
        // Filter out if it's an equivalent subject
        if (widget.model.aggregation.equivalence[otherToken] == widget.aggregation.token) {
          continue;
        }
        if (widget.aggregation.related.contains(otherToken)) {
          relatedStatements[otherToken]?.add(s);
        }
      }
    }

    // Filter related tokens to exclude equivalents
    final relatedTokens = widget.aggregation.related.where((token) => 
      widget.model.aggregation.equivalence[token] != widget.aggregation.token
    ).toList();

    if (relatedTokens.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Related:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ...relatedTokens.map((token) {
            final relatedAgg = widget.model.aggregation.subjects[token];
            if (relatedAgg == null) return const SizedBox.shrink();
            
            final subject = relatedAgg.subject;
            final title = (subject is Map) ? (subject['title'] ?? 'Untitled') : widget.model.labeler.getLabel(subject.toString());
            
            final statements = relatedStatements[token] ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: widget.onMark != null 
                      ? IconButton(
                          icon: Icon(
                            Icons.link, 
                            color: widget.markedSubjectToken == token ? Colors.orange : Colors.grey
                          ),
                          onPressed: () => widget.onMark!(token),
                          tooltip: widget.markedSubjectToken == token ? 'Unmark' : 'Mark to Relate/Equate',
                        ) 
                      : null,
                  title: InkWell(
                    onTap: () => _showInspectionSheet(token),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                ...statements.map((s) {
                   final identity = widget.model.labeler.getIdentityForToken(s.iToken);
                   final authorName = widget.model.labeler.getLabel(s.iToken);
                   final isMe = identity == signInState.identity;
                   return Padding(
                     padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                     child: Row(
                       children: [
                         InkWell(
                           onTap: () => _showStatementDialog(context, s),
                           child: const Icon(Icons.verified_user, color: Colors.blue, size: 16),
                         ),
                         const SizedBox(width: 4),
                         const Text('Related by: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                         InkWell(
                           onTap: () {
                             widget.onGraphFocus?.call(identity);
                           },
                           child: Text(authorName, style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline)),
                         ),
                         if (isMe) ...[
                           const SizedBox(width: 8),
                           InkWell(
                             onTap: () async {
                               Json? json = await RelateDialog(
                                 widget.aggregation.subject,
                                 relatedAgg.subject,
                                 s,
                                 initialVerb: ContentVerb.clear,
                               ).show(context);
                               if (json != null) {
                                 try {
                                   await SourceFactory.getWriter(kNerdsterDomain, context: context).push(json, signInState.signer!);
                                   widget.onRefresh?.call();
                                 } catch (_) {
                                   // Cancelled
                                 }
                               }
                             },
                             child: const Icon(Icons.close, color: Colors.red, size: 16),
                           ),
                         ],
                       ],
                     ),
                   );
                }),
              ],
            );
          }),
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

    final myStatements = widget.aggregation.statements.where((s) => 
      widget.model.labeler.getIdentityForToken(s.iToken) == signInState.identity
    ).toList();
    
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
              color: widget.markedSubjectToken == widget.aggregation.token
                  ? Colors.orange
                  : Colors.grey,
            ),
            tooltip: widget.markedSubjectToken == widget.aggregation.token
                ? 'Unmark'
                : 'Mark to Relate/Equate',
            onPressed: () => widget.onMark!(widget.aggregation.token),
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

  Future<void> _react() async {
    if (!_checkDelegate()) return;
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

    // Determine current user's reaction to this statement
    final myReplies = aggregation.statements.where((r) => 
      r.subjectToken == s.token && 
      signInState.identity != null && 
      model.labeler.getIdentityForToken(r.iToken) == signInState.identity
    ).toList();

    IconData icon = Icons.rate_review_outlined;
    Color? color;
    String tooltip;
    
    if (myReplies.isNotEmpty) {
      color = Colors.blue;
      tooltip = 'You replied to this';
    } else {
      color = Colors.grey;
      tooltip = 'React';
    }

    // Construct the action text (Verb)
    String actionText = '';
    String? otherTitle;
    
    if (s.verb == ContentVerb.rate) {
      if (s.like == true) actionText = 'liked';
      else if (s.like == false) actionText = 'disliked';
      else if (s.dismiss == true) actionText = 'dismissed';
      else actionText = 'commented on';
    } else if (s.verb == ContentVerb.relate) {
      actionText = 'related';
    } else if (s.verb == ContentVerb.dontRelate) {
      actionText = 'un-related';
    } else if (s.verb == ContentVerb.equate) {
      actionText = 'equated';
    } else if (s.verb == ContentVerb.dontEquate) {
      actionText = 'un-equated';
    } else {
      actionText = s.verb.label;
    }

    if (s.other != null) {
      final otherToken = getToken(s.other);
      final otherAgg = model.aggregation.subjects[otherToken];
      if (otherAgg != null) {
        final subject = otherAgg.subject;
        otherTitle = (subject is Map) ? (subject['title'] ?? 'Untitled') : model.labeler.getLabel(subject.toString());
      } else {
        otherTitle = model.labeler.getLabel(otherToken);
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        color: isMe ? Colors.blue[50] : Colors.grey[50],
        child: ListTile(
          dense: true,
          title: Row(
            children: [
              InkWell(
                onTap: () => onGraphFocus?.call(s.iToken),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (s.like == true) ...[
                const Icon(Icons.thumb_up, size: 12, color: Colors.green),
                const SizedBox(width: 2),
              ],
              if (s.like == false) ...[
                const Icon(Icons.thumb_down, size: 12, color: Colors.red),
                const SizedBox(width: 2),
              ],
              if (s.comment != null && s.comment!.isNotEmpty) ...[
                const Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
              ],
              const SizedBox(width: 2),
              Text(actionText, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              if (otherTitle != null) ...[
                const SizedBox(width: 4),
                const Text('to', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Flexible(
                  child: InkWell(
                    onTap: () {
                      if (s.other != null && onInspect != null) {
                         onInspect!(getToken(s.other));
                      }
                    },
                    child: Text(
                      otherTitle,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (onPovChange != null)
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  tooltip: 'View from this POV',
                  onPressed: () => onPovChange!(s.iToken),
                  visualDensity: VisualDensity.compact,
                ),
              if (onMark != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.link,
                    size: 16,
                    color: markedSubjectToken == s.token ? Colors.orange : Colors.grey,
                  ),
                  tooltip: markedSubjectToken == s.token ? 'Unmark' : 'Mark to Relate/Equate',
                  onPressed: () => onMark!(s.token),
                ),
              IconButton(
                icon: Icon(icon, size: 16, color: color),
                tooltip: tooltip,
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    subject: s.json,
                    lastActivity: s.time,
                  ),
                  model,
                  intent: RateIntent.none,
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
