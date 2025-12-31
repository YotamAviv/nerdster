
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
             userDismissalTimestamp: canonicalAgg.userDismissalTimestamp,
             povDismissalTimestamp: canonicalAgg.povDismissalTimestamp,
             isDismissed: canonicalAgg.isDismissed,
             isRated: canonicalAgg.isRated,
             myDelegateStatements: canonicalAgg.myDelegateStatements,
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
    final String title = (subject is Map)
        ? (subject['title'] ?? 'Untitled')
        : widget.model.labeler.getLabel(subject.toString());
    final String type = (subject is Map) ? (subject['contentType'] ?? 'UNKNOWN') : 'IDENTITY';

    String? metaImage = _metadata?.image;
    if (metaImage != null && metaImage.isEmpty) metaImage = null;

    final imageUrl = metaImage ?? 'https://picsum.photos/seed/${widget.aggregation.token}/600/400';

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
            if (widget.aggregation.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Wrap(
                  spacing: 8.0,
                  children: widget.aggregation.tags.map((tag) => Text('#$tag', style: const TextStyle(color: Colors.blue))).toList(),
                ),
              ),
            const Divider(),
            _buildBriefHistory(),
            _buildRelationshipsSection(),
            ExpansionTile(
              title: const Text('History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              children: [
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
            ),
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
        
        // Relation icons
        if (s.verb == ContentVerb.relate) icons.add(const Text('≈', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
        if (s.verb == ContentVerb.dontRelate) icons.add(const Text('≉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
        if (s.verb == ContentVerb.equate) icons.add(const Text('=', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
        if (s.verb == ContentVerb.dontEquate) icons.add(const Text('≠', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));

        // Determine display text
        String displayText = '';
        String? targetToken;

        if (s.comment != null && s.comment!.isNotEmpty) {
          displayText = s.comment!;
        } else if (s.other != null) {
           String? otherToken;
           String? otherTitle;
           final sOtherToken = getToken(s.other);
           
           if (s.subjectToken == widget.aggregation.token) {
              otherToken = sOtherToken;
              if (s.other is Map && s.other['title'] != null) otherTitle = s.other['title'];
           } else if (sOtherToken == widget.aggregation.token) {
              otherToken = s.subjectToken;
              if (s.subject is Map && s.subject['title'] != null) otherTitle = s.subject['title'];
           } else {
              otherToken = sOtherToken;
           }
           
           targetToken = otherToken;

           if (otherTitle == null) {
              final otherAgg = widget.model.aggregation.subjects[otherToken];
              if (otherAgg != null) {
                final subject = otherAgg.subject;
                otherTitle = (subject is Map) ? (subject['title'] ?? 'Untitled') : widget.model.labeler.getLabel(subject.toString());
              } else {
                otherTitle = widget.model.labeler.getLabel(otherToken);
              }
           }
           displayText = otherTitle ?? '';
        } else if (s.like == true) {
           displayText = ''; 
        } else if (s.like == false) {
           displayText = ''; 
        } else {
           displayText = 'Reacted';
        }

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
              if (displayText.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: targetToken != null
                      ? InkWell(
                          onTap: () => _showInspectionSheet(targetToken!),
                          child: Text(
                            displayText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              color: Colors.blue,
                            ),
                          ),
                        )
                      : Text(
                          displayText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRelationshipsSection() {
    final List<Widget> children = [];

    // 1. Equivalents
    final equivalentTokens = widget.model.aggregation.equivalence.entries
        .where((e) => e.value == widget.aggregation.token && e.key != widget.aggregation.token)
        .map((e) => e.key)
        .toSet();

    if (equivalentTokens.isNotEmpty) {
      final Map<String, String> tokenToTitle = {};
      
      // Try to find titles in current statements
      for (final s in widget.aggregation.statements) {
        if (equivalentTokens.contains(s.subjectToken)) {
          final subject = s.subject;
          final title = (subject is Map) ? (subject['title'] ?? 'Untitled') : widget.model.labeler.getLabel(subject.toString());
          tokenToTitle[s.subjectToken] = title;
        }
      }
      
      // Also check global aggregation map if missing
      for (final token in equivalentTokens) {
         if (!tokenToTitle.containsKey(token)) {
             final agg = widget.model.aggregation.subjects[token];
             if (agg != null) {
                final subject = agg.subject;
                final title = (subject is Map) ? (subject['title'] ?? 'Untitled') : widget.model.labeler.getLabel(subject.toString());
                tokenToTitle[token] = title;
             } else {
                tokenToTitle[token] = widget.model.labeler.getLabel(token);
             }
         }
      }

      for (final entry in tokenToTitle.entries) {
         children.add(_buildRelationTile('=', entry.key, entry.value));
      }
    }

    // 2. Related
    final relatedTokens = widget.aggregation.related.where((token) => 
      widget.model.aggregation.equivalence[token] != widget.aggregation.token
    ).toList();

    for (final token in relatedTokens) {
        final relatedAgg = widget.model.aggregation.subjects[token];
        String title;
        if (relatedAgg != null) {
            final subject = relatedAgg.subject;
            title = (subject is Map) ? (subject['title'] ?? 'Untitled') : widget.model.labeler.getLabel(subject.toString());
        } else {
            title = widget.model.labeler.getLabel(token);
        }
        children.add(_buildRelationTile('≈', token, title));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return ExpansionTile(
      title: const Text('Relationships', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      initiallyExpanded: true,
      children: children,
    );
  }

  Widget _buildRelationTile(String iconText, String token, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(iconText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            onPressed: () {
              if (checkDelegate(context)) {
                widget.onMark!(widget.aggregation.token);
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
    if (!checkDelegate(context)) return;
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

    // Find the aggregation for this statement (s)
    final canonicalToken = model.aggregation.equivalence[s.token] ?? s.token;
    final statementAgg = model.aggregation.subjects[canonicalToken];
    
    // Combine statements from the main aggregation (if any are threaded there) and the statement's own aggregation
    final repliesInParent = aggregation.statements.where((r) => r.subjectToken == s.token).toList();
    final combinedStatements = [
        ...repliesInParent,
        ...(statementAgg?.statements ?? <ContentStatement>[]),
    ];
    // Deduplicate based on token
    final List<ContentStatement> uniqueStatements = {for (var s in combinedStatements) s.token: s}.values.toList();

    // Determine current user's reaction to this statement
    final myReplies = uniqueStatements.where((r) => 
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

    // Determine display elements based on verb
    Widget? verbIcon;
    String? displayText;
    String? otherToken;

    if (s.verb == ContentVerb.rate) {
      // Icons are handled in the row, text is handled in subtitle or here if comment
    } else {
      // Relations
      if (s.verb == ContentVerb.relate) {
        verbIcon = const Text('≈', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
      } else if (s.verb == ContentVerb.dontRelate) {
        verbIcon = const Text('≉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
      } else if (s.verb == ContentVerb.equate) {
        verbIcon = const Text('=', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
      } else if (s.verb == ContentVerb.dontEquate) {
        verbIcon = const Text('≠', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
      }

      // Determine target subject
      if (s.other != null) {
        final sOtherToken = getToken(s.other);
        // If the statement's subject is THIS card, then the target is s.other
        // If the statement's other is THIS card, then the target is s.subject
        
        if (s.subjectToken == aggregation.token) {
           otherToken = sOtherToken;
           // Try to get title from s.other if it's a map
           if (s.other is Map && s.other['title'] != null) {
             displayText = s.other['title'];
           }
        } else if (sOtherToken == aggregation.token) {
           otherToken = s.subjectToken;
           // Try to get title from s.subject if it's a map
           if (s.subject is Map && s.subject['title'] != null) {
             displayText = s.subject['title'];
           }
        } else {
           // Fallback
           otherToken = sOtherToken;
        }

        if (displayText == null) {
           final otherAgg = model.aggregation.subjects[otherToken];
           if (otherAgg != null) {
             final subject = otherAgg.subject;
             displayText = (subject is Map) ? (subject['title'] ?? 'Untitled') : model.labeler.getLabel(subject.toString());
           } else {
             displayText = model.labeler.getLabel(otherToken);
           }
        }
      }
    }

    return Container(
      color: isMe ? Colors.blue[50] : null,
      padding: EdgeInsets.only(
        left: 16.0 + (depth * 16.0), 
        right: 16.0, 
        top: 4.0, 
        bottom: 4.0
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              
              if (verbIcon != null) ...[
                const SizedBox(width: 4),
                verbIcon,
                const SizedBox(width: 4),
              ],

              if (displayText != null) ...[
                Flexible(
                  child: InkWell(
                    onTap: () {
                      if (otherToken != null && onInspect != null) {
                         onInspect!(otherToken);
                      }
                    },
                    child: Text(
                      displayText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],

              const Spacer(),
              if (onMark != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.link,
                    size: 16,
                    color: markedSubjectToken == s.token ? Colors.orange : Colors.grey,
                  ),
                  tooltip: markedSubjectToken == s.token ? 'Unmark' : 'Mark to Relate/Equate',
                  onPressed: () {
                    if (checkDelegate(context)) {
                      onMark!(s.token);
                    }
                  },
                ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(icon, size: 16, color: color),
                tooltip: tooltip,
                onPressed: () => V2RateDialog.show(
                  context,
                  SubjectAggregation(
                    subject: s.json,
                    lastActivity: s.time,
                    statements: uniqueStatements,
                  ),
                  model,
                  intent: RateIntent.none,
                  onRefresh: onRefresh,
                ),
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
          if (s.comment != null && s.comment!.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(left: 0.0, top: 2.0),
               child: CommentWidget(
                  text: s.comment!,
                  onHashtagTap: (tag, _) => onTagTap?.call(tag),
                  style: const TextStyle(fontSize: 13),
               ),
             ),
        ],
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

bool checkDelegate(BuildContext context) {
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
