import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nerdster/v2/cached_source.dart';
import 'package:nerdster/v2/content_pipeline.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/v2/orchestrator.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/delegates.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:nerdster/v2/content_logic.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/content/dialogs/establish_subject_dialog.dart';

class FancyShadowView extends StatefulWidget {
  final String rootToken;

  const FancyShadowView({super.key, required this.rootToken});

  @override
  State<FancyShadowView> createState() => _FancyShadowViewState();
}

class _FancyShadowViewState extends State<FancyShadowView> {
  V2Labeler? _labeler;
  ContentAggregation? _aggregation;
  bool _loading = false;
  String? _error;

  // Cache for dynamically fetched image URLs
  static final Map<String, String> _imageUrlCache = {};

  final CachedSource<TrustStatement> _cachedIdentity =
      CachedSource(SourceFactory.get<TrustStatement>(kOneofusDomain));
  final CachedSource<ContentStatement> _cachedIdentityContent =
      CachedSource(SourceFactory.get<ContentStatement>(kOneofusDomain));
  final CachedSource<ContentStatement> _cachedAppContent =
      CachedSource(SourceFactory.get<ContentStatement>(kNerdsterDomain));

  @override
  void initState() {
    super.initState();
    _runPipeline();
  }

  Future<void> _runPipeline() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final trustPipeline = TrustPipeline(_cachedIdentity);
      final graph = await trustPipeline.build(widget.rootToken);
      final delegateResolver = DelegateResolver(graph);

      final contentPipeline = ContentPipeline(
        identitySource: _cachedIdentityContent,
        appSource: _cachedAppContent,
      );
      final contentMap =
          await contentPipeline.fetchContentMap(graph, delegateResolver);

      final followNetwork = reduceFollowNetwork(
          graph, delegateResolver, contentMap, kNerdsterContext);
      final aggregation = reduceContentAggregation(
          followNetwork, graph, delegateResolver, contentMap);

      if (mounted) {
        setState(() {
          _labeler = V2Labeler(graph);
          _aggregation = aggregation;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fancy Shadow Pipeline Error: $e');
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Nerdster Feed', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : _runPipeline,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _aggregation == null
                  ? const Center(child: Text('No content', style: TextStyle(color: Colors.white)))
                  : _buildFeed(),
    );
  }

  Widget _buildFeed() {
    final subjects = _aggregation!.subjects.values.toList();
    subjects.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        return ContentBox(
          aggregation: subjects[index],
          labeler: _labeler!,
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

  String _getFallbackUrl() {
    final subject = aggregation.subject;
    String localTitle = 'Unknown';
    String localType = 'article';

    if (subject is Map || subject is Jsonish) {
      localTitle = subject['title']?.toString() ?? 'Unknown';
      localType = subject['contentType']?.toString() ?? 'article';
    }

    // Use specific keywords based on content type
    String keyword = 'abstract';
    if (localType == 'book') keyword = 'book';
    if (localType == 'movie') keyword = 'movie';
    if (localType == 'article') keyword = 'news';
    if (localType == 'album') keyword = 'music';
    if (localType == 'recipe') keyword = 'food';

    // Use a hash of the title to get a consistent image from LoremFlickr
    // We use the keyword and the first word of the title to increase relevance
    final firstWord = localTitle.split(' ').firstWhere((w) => w.length > 3, orElse: () => localTitle.split(' ').first);
    final tags = '${Uri.encodeComponent(keyword)},${Uri.encodeComponent(firstWord)}';
    final seed = localTitle.hashCode.abs() % 1000;
    final url = 'https://loremflickr.com/600/600/$tags?lock=$seed';

    if (kIsWeb) {
      // Use wsrv.nl as a CORS proxy for web to avoid "No 'Access-Control-Allow-Origin' header" errors.
      return 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}&w=600&h=600&fit=cover';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final subject = aggregation.subject;
    final title = (subject is Map || subject is Jsonish) ? (subject['title'] ?? 'Unknown') : subject.toString();
    final type = (subject is Map || subject is Jsonish) ? (subject['contentType'] ?? 'unknown') : 'unknown';
    final url = (subject is Map || subject is Jsonish) ? subject['url']?.toString() : null;

    return Dismissible(
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
                        Text('Rate "$title"', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(5, (index) => IconButton(
                            icon: const Icon(Icons.star_border, color: Colors.amber, size: 40),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
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
                      fallbackUrl: _getFallbackUrl(),
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
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    icon: aggregation.likes > 0 ? Icons.favorite : Icons.favorite_border,
                    color: aggregation.likes > 0 ? Colors.red : Colors.white,
                    onTap: () {},
                  ),
                  _ActionButton(
                    icon: Icons.mode_comment_outlined,
                    onTap: () {},
                  ),
                  _ActionButton(
                    icon: Icons.repeat,
                    onTap: () {},
                  ),
                  const Spacer(),
                  _ActionButton(
                    icon: Icons.bookmark_border,
                    onTap: () {},
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
                        children: aggregation.tags.map((tag) => Text(
                          '#$tag',
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                        )).toList(),
                      ),
                    ),
                  ...aggregation.statements.take(2).map((s) {
                    final label = labeler.getLabel(s.iToken);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13),
                          children: [
                            TextSpan(
                              text: '$label ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            TextSpan(
                              text: s.comment ?? s.verb.label,
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                          ],
                        ),
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
      case 'movie': return Colors.redAccent;
      case 'book': return Colors.blueAccent;
      case 'article': return Colors.greenAccent;
      case 'album': return Colors.purpleAccent;
      default: return Colors.blueGrey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'movie': return Icons.movie;
      case 'book': return Icons.book;
      case 'article': return Icons.description;
      case 'album': return Icons.album;
      default: return Icons.star;
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
  final String fallbackUrl;
  final Map<String, String> imageCache;

  const DynamicImage({
    super.key,
    required this.url,
    required this.fallbackUrl,
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
    _checkCacheAndFetch();
  }

  @override
  void didUpdateWidget(DynamicImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _checkCacheAndFetch();
    }
  }

  void _checkCacheAndFetch() {
    if (widget.url == null) {
      setState(() {
        _fetchedUrl = null;
      });
      return;
    }

    if (widget.imageCache.containsKey(widget.url)) {
      setState(() {
        _fetchedUrl = widget.imageCache[widget.url];
      });
    } else {
      _fetchImage();
    }
  }

  void _fetchImage() {
    tryFetchTitle(widget.url!, (url, {title, image, error}) {
      if (mounted && url == widget.url && image != null) {
        String finalUrl = image;
        if (kIsWeb) {
          // Use wsrv.nl as a CORS proxy and image resizer for web
          finalUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(image)}&w=600&h=600&fit=cover';
        }
        widget.imageCache[url] = finalUrl;
        setState(() {
          _fetchedUrl = finalUrl;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _fetchedUrl ?? widget.fallbackUrl;

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

