import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/metadata_service.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';

import 'refresh_signal.dart';
import 'submit.dart';

class PhoneView extends StatefulWidget {
  final String? povToken;

  const PhoneView({super.key, this.povToken});

  @override
  State<PhoneView> createState() => _PhoneViewState();
}

class _PhoneViewState extends State<PhoneView> {
  late final V2FeedController _controller;

  // Cache for dynamically fetched image URLs
  static final Map<String, String> _imageUrlCache = {};

  @override
  void initState() {
    super.initState();
    _controller = V2FeedController(
      trustSource: SourceFactory.get<TrustStatement>(kOneofusDomain),
      contentSource: SourceFactory.get<ContentStatement>(kNerdsterDomain),
    );
    _controller.refresh(widget.povToken, meIdentityToken: signInState.identity);
    v2RefreshSignal.addListener(_onRefresh);
    Setting.get<String>(SettingType.tag).addListener(_onSettingChanged);
  }

  @override
  void dispose() {
    v2RefreshSignal.removeListener(_onRefresh);
    Setting.get<String>(SettingType.tag).removeListener(_onSettingChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSettingChanged() {
    if (mounted) setState(() {});
  }

  void _onRefresh() {
    _controller.refresh(widget.povToken, meIdentityToken: signInState.identity);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V2FeedModel?>(
      valueListenable: _controller,
      builder: (context, model, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: const Text('Nerdster Feed', style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _controller.loading ? null : _onRefresh,
              ),
            ],
          ),
          body: _controller.loading
              ? const Center(child: CircularProgressIndicator())
              : _controller.error != null
                  ? Center(
                      child: Text(_controller.error!, style: const TextStyle(color: Colors.red)))
                  : (model == null || model.aggregation.subjects.isEmpty)
                      ? const Center(
                          child: Text('No content', style: TextStyle(color: Colors.white)))
                      : _buildFeed(model),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              if (model != null) {
                await v2Submit(context, model, onRefresh: _onRefresh);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildFeed(V2FeedModel model) {
    final subjects = model.aggregation.subjects.values.where((s) {
      return _controller.shouldShow(
        s,
        model.filterMode,
        model.enableCensorship,
        tagFilter: model.tagFilter,
        tagEquivalence: model.aggregation.tagEquivalence,
        typeFilter: model.typeFilter,
      );
    }).toList();

    _controller.sortSubjects(subjects);

    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        return ContentBox(
          aggregation: subjects[index],
          labeler: model.labeler,
          imageCache: _imageUrlCache,
        );
      },
    );
  }
}

class ContentBox extends StatelessWidget {
  final SubjectAggregation aggregation;
  final V2Labeler labeler;
  final Map<String, String> imageCache;

  const ContentBox({
    super.key,
    required this.aggregation,
    required this.labeler,
    required this.imageCache,
  });

  @override
  Widget build(BuildContext context) {
    final Json subject = aggregation.subject;
    final String title = subject['title'];
    final String type = subject['contentType'];

    final url = subject['url']?.toString();
    final author = subject['author'];
    final List<String> images =
        subject['images'] != null ? List<String>.from(subject['images']) : [];

    return Dismissible(
      // TODO: Careful here. Should we use getToken(aggregation.subject) instead?
      key: Key(aggregation.canonicalToken),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        child: const Icon(Icons.favorite, color: Colors.white, size: 32),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.visibility_off, color: Colors.white, size: 32),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // Like
        } else {
          // Dismiss
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getTypeColor(type),
                    child: Icon(_getTypeIcon(type), color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: Colors.white),
                ],
              ),
            ),
            // Image Area with Overlay
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rate "$title"',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                              5,
                              (index) => IconButton(
                                    icon: const Icon(Icons.star_border,
                                        color: Colors.amber, size: 40),
                                    onPressed: () => Navigator.pop(context),
                                  )),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: Colors.grey[850],
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50)),
                          child: const Text('Post Review'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: DynamicImage(
                      url: url,
                      title: title,
                      author: author,
                      initialImage: images.isNotEmpty ? images[0] : null,
                      contentType: type,
                      tags: aggregation.tags.toList(),
                      imageCache: imageCache,
                    ),
                  ),
                  // Bottom Gradient Overlay for text readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Quick Action Overlay (e.g. Rating)
                  if (aggregation.likes > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${aggregation.likes}',
                              style:
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.rate_review_outlined,
                    onTap: () {},
                  ),
                  const Spacer(),
                  if (aggregation.likes > 0 || aggregation.dislikes > 0)
                    Row(
                      children: [
                        if (aggregation.likes > 0) ...[
                          const Icon(Icons.thumb_up, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text('${aggregation.likes}',
                              style: const TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                        ],
                        if (aggregation.dislikes > 0) ...[
                          const Icon(Icons.thumb_down, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          Text('${aggregation.dislikes}',
                              style: const TextStyle(color: Colors.white)),
                        ],
                        const SizedBox(width: 8),
                      ],
                    ),
                ],
              ),
            ),
            // Comments Section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (aggregation.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Wrap(
                        spacing: 6,
                        children: aggregation.tags
                            .map((tag) => Text(
                                  tag,
                                  style: const TextStyle(color: Colors.blue, fontSize: 12),
                                ))
                            .toList(),
                      ),
                    ),
                  ...aggregation.statements.take(2).map((s) {
                    final label = labeler.getLabel(s.iToken);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Text(
                            '$label ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          if (s.like == true) ...[
                            const Icon(Icons.thumb_up, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                          ],
                          if (s.like == false) ...[
                            const Icon(Icons.thumb_down, size: 12, color: Colors.red),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              s.comment ?? s.verb.label,
                              style: TextStyle(color: Colors.grey[300], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.rate_review_outlined, size: 16, color: Colors.grey),
                        ],
                      ),
                    );
                  }),
                  if (aggregation.statements.length > 2)
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'View all ${aggregation.statements.length} reviews',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'movie':
        return Colors.redAccent;
      case 'book':
        return Colors.blueAccent;
      case 'article':
        return Colors.greenAccent;
      case 'album':
        return Colors.purpleAccent;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'movie':
        return Icons.movie;
      case 'book':
        return Icons.book;
      case 'article':
        return Icons.description;
      case 'album':
        return Icons.album;
      default:
        return Icons.star;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 26),
      onPressed: onTap,
    );
  }
}

class DynamicImage extends StatefulWidget {
  final String? url;
  final String? title;
  final String? author;
  final String? initialImage;
  final String contentType;
  final List<String> tags;
  final Map<String, String> imageCache;

  const DynamicImage({
    super.key,
    required this.url,
    this.title,
    this.author,
    this.initialImage,
    required this.contentType,
    this.tags = const [],
    required this.imageCache,
  });

  @override
  State<DynamicImage> createState() => _DynamicImageState();
}

class _DynamicImageState extends State<DynamicImage> {
  String? _fetchedUrl;

  @override
  void initState() {
    super.initState();
    _fetchedUrl = widget.initialImage;
    _checkCacheAndFetch();
  }

  @override
  void didUpdateWidget(DynamicImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.title != widget.title ||
        oldWidget.author != widget.author ||
        oldWidget.initialImage != widget.initialImage ||
        oldWidget.contentType != widget.contentType) {
      _fetchedUrl = widget.initialImage;
      _checkCacheAndFetch();
    }
  }

  void _checkCacheAndFetch() {
    if (_fetchedUrl != null) return;

    final cacheKey = widget.url ?? widget.title;
    if (cacheKey == null) {
      setState(() {
        _fetchedUrl = null;
      });
      return;
    }

    if (widget.imageCache.containsKey(cacheKey)) {
      setState(() {
        _fetchedUrl = widget.imageCache[cacheKey];
      });
    } else {
      _fetchImage();
    }
  }

  void _fetchImage() {
    fetchImages(
      subject: {
        'url': widget.url,
        'title': widget.title,
        'author': widget.author,
        'contentType': widget.contentType,
      },
      onResult: (result) {
        if (mounted && (result.image != null)) {
          String finalUrl = result.image!;
          if (kIsWeb) {
            // Use wsrv.nl as a CORS proxy and image resizer for web
            finalUrl =
                'https://wsrv.nl/?url=${Uri.encodeComponent(finalUrl)}&w=600&h=600&fit=cover';
          }
          final cacheKey = widget.url ?? widget.title;
          if (cacheKey != null) {
            widget.imageCache[cacheKey] = finalUrl;
          }
          setState(() {
            _fetchedUrl = finalUrl;
          });
        }
      },
    );
  }

  String _getFallbackUrl() {
    return getFallbackImageUrl(widget.url, widget.contentType, widget.title, tags: widget.tags);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _fetchedUrl ?? _getFallbackUrl();

    return ClipRRect(
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[850],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white24,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[850],
          child: const Icon(Icons.broken_image, color: Colors.white24, size: 80),
        ),
      ),
    );
  }
}
