import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:nerdster/io/fire_factory.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:nerdster/models/content_types.dart';

class MetadataResult {
  final String? title;
  final String? image;
  final List<String>? images;
  final String? error;

  MetadataResult({this.title, this.image, this.images, this.error});
}

String getFallbackImageUrl(String? url, String contentType, String? title, {List<String>? tags}) {
  // 1. YouTube
  if (url != null && (url.contains('youtube.com') || url.contains('youtu.be'))) {
    final videoId = _extractYoutubeId(url);
    if (videoId != null) return 'https://img.youtube.com/vi/$videoId/0.jpg';
  }

  // 2. NYT & WSJ
  if (url != null) {
    if (url.contains('nytimes.com')) {
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/The_New_York_Times_logo.png/800px-The_New_York_Times_logo.png';
    }
    if (url.contains('wsj.com')) {
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/WSJ_Logo.svg/512px-WSJ_Logo.svg.png';
    }
  }

  // 3. Hard-coded Content Type Fallbacks
  final ContentType type = ContentType.values.byName(contentType);
  // Weird: switching on the type seemed to reveal a Flutter bug. It ended up in default!?
  switch (type.name) {
    case 'album':
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Music_font_awesome.svg/512px-Music_font_awesome.svg.png';
    case 'video':
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Video_camera_font_awesome.svg/512px-Video_camera_font_awesome.svg.png';
    case 'movie':
      // return 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/Clapperboard.svg/600px-Clapperboard.svg.png';
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/No_image_available.svg/600px-No_image_available.svg.png';
    case 'book':
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Book_font_awesome.svg/512px-Book_font_awesome.svg.png';
    case 'article':
      return 'https://tile.loc.gov/storage-services/service/pnp/fsa/8b07000/8b07900/8b07923v.jpg';
    case 'recipe':
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Fork_and_knife_icon.svg/512px-Fork_and_knife_icon.svg.png';
    case 'podcast':
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Podcast_font_awesome.svg/512px-Podcast_font_awesome.svg.png';
    case 'event':
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c9/Calendar_font_awesome.svg/512px-Calendar_font_awesome.svg.png';
    case 'resource':
      return 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Feed-icon.svg/512px-Feed-icon.svg.png';
    default:
      assert(false,
          'contentType: $contentType, ${contentType.runtimeType}. type: $type, ${type.runtimeType}');
      break;
  }

  assert(false,
      'contentType: $contentType, ${contentType.runtimeType}. type: $type, ${type.runtimeType}');
  return 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/No_image_available.svg/600px-No_image_available.svg.png';
}

String? _extractYoutubeId(String url) {
  RegExp regExp = RegExp(
    r'.*(?:(?:youtu\.be\/|v\/|vi\/|u\/\w\/|embed\/|e\/)|(?:(?:watch)?\?v(?:i)?=|\&v(?:i)?=))([^#\&\?]*).*',
    caseSensitive: false,
    multiLine: false,
  );
  final match = regExp.firstMatch(url);
  if (match != null && match.groupCount >= 1) {
    return match.group(1);
  }
  return null;
}

FirebaseFunctions? get _functions => FireFactory.findFunctions(kNerdsterDomain);

// Simple in-memory cache to prevent redundant fetches on scroll
final Map<String, MetadataResult> _metadataCache = {};

/// Use Case 2: Magic Paste
/// Fetches metadata from a URL to auto-populate the Establish Subject form.
/// On web, calls the Firebase cloud function (required to avoid CORS).
/// On native (Android/iOS), fetches the URL directly via HTTP.
Future<Map<String, dynamic>?> magicPaste(String url) async {
  if (url.isEmpty || !url.startsWith('http')) return null;

  if (!kIsWeb) {
    // Try direct HTTP first (faster, no cloud function cold start).
    // If the title is empty — e.g. the site returned a bot-challenge page — fall through
    // to the cloud function, which fetches from a GCP IP with better site reputation.
    final direct = await _magicPasteDirect(url);
    final hasTitle = direct != null && (direct['title'] as String?)?.isNotEmpty == true;
    if (hasTitle) return direct;
    debugPrint('magicPasteDirect returned no title, falling back to cloud function');
  }

  // Web: use cloud function (CORS requires server-side fetch).
  if (_functions == null) return null;
  try {
    debugPrint('magicPaste calling cloud function...');
    try {
      final retval = await _functions!.httpsCallable('magicPaste').call({
        "url": url,
      });
      debugPrint('magicPaste raw data: ${retval.data}');
      debugPrint('magicPaste data type: ${retval.data.runtimeType}');

      if (retval.data == null) return null;
      return retval.data as Map<String, dynamic>;
    } catch (e, stack) {
      debugPrint('magicPaste error: $e');
      debugPrint('magicPaste stack: $stack');
      return {'title': 'Error', 'error': e.toString()};
    }
  } catch (e) {
    debugPrint('magicPaste error: $e');
    return {'title': 'Error', 'error': e.toString()};
  }
}

/// Fetches high-quality images for a subject to enhance the visual presentation.
/// On native (Android/iOS), fetches directly via HTTP (YouTube, og:image, OpenLibrary, Wikipedia).
/// On web, calls the Firebase cloud function (CORS requires server-side fetch).
/// Falls back to cloud function if the direct path returns no images.
Future<void> fetchImages({
  required Map<String, dynamic> subject,
  required Function(MetadataResult result) onResult,
}) async {
  // Fail Fast: Ensure we have the required fields for a subject
  assert(subject['contentType'] != null, 'Subject must have a contentType');
  if (subject.isEmpty) return;

  final cacheKey = subject['url'] ?? subject['title'] ?? subject.toString();
  if (_metadataCache.containsKey(cacheKey)) {
    onResult(_metadataCache[cacheKey]!);
    return;
  }

  if (!kIsWeb) {
    // Try direct HTTP on native (faster, no cold start, no CORS restriction).
    final direct = await _fetchImagesDirect(subject);
    if (direct != null && (direct.image != null || (direct.images?.isNotEmpty ?? false))) {
      _metadataCache[cacheKey] = direct;
      onResult(direct);
      return;
    }
    debugPrint('fetchImagesDirect returned no images, falling back to cloud function');
  }

  // Cloud function path (web always, native as fallback).
  if (_functions == null) {
    debugPrint('MetadataService: Firebase Functions not initialized');
    return;
  }

  try {
    debugPrint(
        'MetadataService: Calling fetchImages cloud function for ${subject['url'] ?? subject['title']}');
    final retval = await _functions!.httpsCallable('fetchImages').call({
      "subject": subject,
    });

    debugPrint('MetadataService: Received response: ${retval.data}');

    List<String>? images;
    if (retval.data["images"] != null) {
      final rawImages = retval.data["images"] as List;
      images = rawImages.map<String>((e) {
        return e['url'] as String;
      }).toList();
    }

    final result = MetadataResult(
      title: retval.data["title"],
      image: images != null && images.isNotEmpty ? images.first : null,
      images: images,
    );
    _metadataCache[cacheKey] = result;
    onResult(result);
  } on FirebaseFunctionsException catch (e) {
    String error = [e.message, if (e.details != null) e.details].join(', ');
    debugPrint('fetchImages error: $error');
    final result = MetadataResult(error: error);
    _metadataCache[cacheKey] = result;
    onResult(result);
  } catch (e) {
    debugPrint('fetchImages unexpected error: $e');
    final result = MetadataResult(error: e.toString());
    _metadataCache[cacheKey] = result;
    onResult(result);
  }
}

// ---------------------------------------------------------------------------
// fetchImages helpers — direct HTTP implementation for non-web platforms.
//
// DUAL IMPLEMENTATION WARNING
// This is the Dart port of the cloud function logic in:
//   functions/core_logic.js        (executeFetchImages)
//   functions/metadata_fetchers.js (fetchFromYouTube, fetchFromOpenLibrary, fetchFromWikipedia)
//
// Sources covered: YouTube thumbnails, HTML og:image scraping, OpenLibrary (books), Wikipedia.
// OMDB and TMDB are intentionally omitted — they require API keys not configured in this project.
// See TODO.md.
//
// Keep in sync with the JS counterparts when changing fetch logic.
// ---------------------------------------------------------------------------

/// Fetches images for a subject directly via HTTP (no cloud function).
Future<MetadataResult?> _fetchImagesDirect(Map<String, dynamic> subject) async {
  final url = (subject['url'] as String?) ?? '';
  final title = (subject['title'] as String?) ?? '';
  final contentType = (subject['contentType'] as String?) ?? '';
  final author = (subject['author'] as String?) ?? '';

  final images = <String>[];

  try {
    // 1. YouTube: thumbnail URL from video ID.
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final ytImages = _youTubeThumbnails(url);
      images.addAll(ytImages);
    }

    // 2. Fetch og:image from the subject URL.
    if (images.isEmpty && url.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }).timeout(const Duration(seconds: 8));
        final ogImage = _extractMeta(response.body, 'og:image');
        if (ogImage != null && ogImage.startsWith('http')) images.add(ogImage);
      } catch (_) {}
    }

    // 3. OpenLibrary for books.
    if (contentType == 'book') {
      final olImage = await _fetchFromOpenLibrary(title, author);
      if (olImage != null) images.add(olImage);
    }

    // 4. Wikipedia image (general fallback).
    if (images.isEmpty && title.isNotEmpty) {
      final wikiImage = await _fetchFromWikipedia(title, contentType);
      if (wikiImage != null) images.add(wikiImage);
    }
  } catch (e) {
    debugPrint('fetchImagesDirect error: $e');
  }

  if (images.isEmpty) return null;
  return MetadataResult(image: images.first, images: images);
}

/// Returns YouTube thumbnail URLs for a given video URL.
List<String> _youTubeThumbnails(String url) {
  String? videoId;
  if (url.contains('youtu.be/')) {
    videoId = url.split('youtu.be/')[1].split(RegExp(r'[?#]'))[0];
  } else if (url.contains('v=')) {
    videoId = url.split('v=')[1].split(RegExp(r'[&?#]'))[0];
  } else if (url.contains('embed/')) {
    videoId = url.split('embed/')[1].split(RegExp(r'[?#]'))[0];
  } else if (url.contains('shorts/')) {
    videoId = url.split('shorts/')[1].split(RegExp(r'[?#]'))[0];
  }
  if (videoId == null || videoId.isEmpty) return [];
  return [
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
    'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
  ];
}

/// Fetches a book cover URL from OpenLibrary by title (and optional author).
Future<String?> _fetchFromOpenLibrary(String title, String author) async {
  if (title.isEmpty) return null;
  try {
    var searchUrl =
        'https://openlibrary.org/search.json?title=${Uri.encodeComponent(title)}&limit=1';
    if (author.isNotEmpty) searchUrl += '&author=${Uri.encodeComponent(author)}';
    final response = await http.get(Uri.parse(searchUrl), headers: {
      'User-Agent': 'NerdsterApp/1.0',
    }).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = data['docs'] as List?;
    if (docs != null && docs.isNotEmpty) {
      final coverId = docs[0]['cover_i'];
      if (coverId != null) {
        return 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
      }
    }
  } catch (e) {
    debugPrint('fetchFromOpenLibrary error: $e');
  }
  return null;
}

/// Fetches a representative image from Wikipedia for the given title.
Future<String?> _fetchFromWikipedia(String title, String contentType) async {
  if (title.isEmpty) return null;
  try {
    // Add "(film)" qualifier for movies to improve search accuracy.
    final searchTerm =
        contentType == 'movie' && !title.toLowerCase().contains('film') ? '$title (film)' : title;
    // Search for the best page title.
    final searchUrl = 'https://en.wikipedia.org/w/api.php?action=query&list=search'
        '&srsearch=${Uri.encodeComponent(searchTerm)}&format=json&origin=*';
    final searchResponse = await http.get(Uri.parse(searchUrl), headers: {
      'User-Agent': 'NerdsterApp/1.0',
    }).timeout(const Duration(seconds: 8));
    final searchData = jsonDecode(searchResponse.body) as Map<String, dynamic>;
    final results = (searchData['query']?['search'] as List?);
    if (results == null || results.isEmpty) return null;
    final pageTitle = results[0]['title'] as String;

    // Fetch the page thumbnail via PageImages API.
    final imageUrl = 'https://en.wikipedia.org/w/api.php?action=query'
        '&titles=${Uri.encodeComponent(pageTitle)}'
        '&prop=pageimages&format=json&pithumbsize=1000&origin=*';
    final imageResponse = await http.get(Uri.parse(imageUrl), headers: {
      'User-Agent': 'NerdsterApp/1.0',
    }).timeout(const Duration(seconds: 8));
    final imageData = jsonDecode(imageResponse.body) as Map<String, dynamic>;
    final pages = imageData['query']?['pages'] as Map?;
    if (pages != null) {
      final page = pages.values.first as Map?;
      final thumbnail = page?['thumbnail'] as Map?;
      return thumbnail?['source'] as String?;
    }
  } catch (e) {
    debugPrint('fetchFromWikipedia error: $e');
  }
  return null;
}

// ---------------------------------------------------------------------------
// magicPaste helpers — direct HTTP implementation for non-web platforms.
//
// DUAL IMPLEMENTATION WARNING
// This is the Dart port of the cloud function logic in:
//   functions/url_metadata_parser.js  (parseUrlMetadata and helpers)
//
// Why two implementations?
//   - Web: CORS prevents the browser from fetching arbitrary URLs directly, so
//     the cloud function fetches server-side and returns the parsed metadata.
//   - Native (Android/iOS): No CORS restriction; the phone fetches directly via
//     HTTP, bypassing the cloud function for speed and cost.
//
// If you change the parsing logic here (JSON-LD handling, OpenGraph fallbacks,
// content-type inference, year extraction, etc.), update the JS counterpart
// too, and vice versa.
// ---------------------------------------------------------------------------

/// Fetches URL metadata directly via HTTP (no cloud function).
Future<Map<String, dynamic>?> _magicPasteDirect(String url) async {
  try {
    // YouTube: use oEmbed API (reliable; scraping fails from many IPs).
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      try {
        final oembedUrl =
            'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json';
        final r = await http.get(Uri.parse(oembedUrl)).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          return {'contentType': 'video', 'title': data['title'], 'canonicalUrl': url};
        }
      } catch (_) {}
    }

    // Fetch HTML.
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
    }).timeout(const Duration(seconds: 15));

    final html = response.body;
    final metadata = <String, dynamic>{
      'contentType': null,
      'title': null,
      'year': null,
      'author': null,
      'image': null,
      'canonicalUrl': url,
    };

    // 1. JSON-LD (schema.org) — highest priority.
    final jsonLdRegex = RegExp(
      r'''<script[^>]*type=['"]application/ld\+json['"][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    );
    for (final m in jsonLdRegex.allMatches(html)) {
      try {
        _processJsonLd(jsonDecode(m.group(1)!.trim()), metadata);
      } catch (_) {}
    }

    // 2. OpenGraph fallbacks.
    metadata['title'] ??= _extractMeta(html, 'og:title') ?? _extractHtmlTitle(html);
    metadata['image'] ??= _extractMeta(html, 'og:image');

    // 3. Infer content type.
    metadata['contentType'] ??= _inferContentType(url, metadata);

    // 4. Normalise year to YYYY.
    if (metadata['year'] != null) {
      final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(metadata['year'].toString());
      metadata['year'] = ym?.group(0);
    }
    // Extract year from title, e.g. "The Matrix (1999)".
    if (metadata['year'] == null && metadata['title'] != null) {
      final ym = RegExp(r'\(((?:19|20)\d{2})\)').firstMatch(metadata['title'] as String);
      if (ym != null) metadata['year'] = ym.group(1);
    }

    if (metadata['title'] != null && metadata['contentType'] == null) {
      metadata['contentType'] = 'article';
    }
    return metadata;
  } catch (e) {
    debugPrint('magicPasteDirect error: $e');
    return null;
  }
}

void _processJsonLd(dynamic json, Map<String, dynamic> metadata) {
  if (json is List) {
    for (final item in json) _processJsonLd(item, metadata);
    return;
  }
  if (json is Map) {
    if (json.containsKey('@graph')) {
      _processJsonLd(json['@graph'], metadata);
      return;
    }
    _processJsonLdItem(Map<String, dynamic>.from(json), metadata);
  }
}

void _processJsonLdItem(Map<String, dynamic> item, Map<String, dynamic> metadata) {
  final rawType = item['@type'];
  final typeStr = rawType is List ? rawType.join(',') : (rawType as String? ?? '');

  String? val(String key) {
    final v = item[key];
    if (v is String) return v;
    if (v is Map) return v['name'] as String?;
    return null;
  }

  String? getAuthor() {
    final a = item['author'] ?? item['creator'];
    if (a == null) return null;
    if (a is Map) return a['name'] as String?;
    if (a is List) return a.map((x) => x is Map ? x['name'] : x.toString()).join(', ');
    return null;
  }

  String? getImage() {
    final img = item['image'];
    if (img is String) return img;
    if (img is Map) return img['url'] as String?;
    if (img is List && img.isNotEmpty) {
      final first = img[0];
      return first is String ? first : (first as Map?)?['url'] as String?;
    }
    return null;
  }

  if (typeStr == 'Movie' || typeStr == 'Film') {
    metadata['contentType'] = 'movie';
    metadata['title'] ??= val('name');
    metadata['year'] ??= val('datePublished');
    metadata['image'] ??= getImage();
  } else if (typeStr == 'Book') {
    metadata['contentType'] = 'book';
    metadata['title'] ??= val('name');
    metadata['author'] ??= getAuthor();
    metadata['year'] ??= val('datePublished');
    metadata['image'] ??= getImage();
  } else if (typeStr == 'Recipe') {
    metadata['contentType'] = 'recipe';
    metadata['title'] ??= val('name');
    metadata['image'] ??= getImage();
  } else if (typeStr == 'MusicAlbum') {
    metadata['contentType'] = 'album';
    metadata['title'] ??= val('name');
    metadata['year'] ??= val('datePublished');
    metadata['image'] ??= getImage();
    final artist = item['byArtist'];
    metadata['author'] ??= artist is Map ? artist['name'] as String? : null;
  } else if (typeStr.contains('NewsArticle') ||
      typeStr.contains('BlogPosting') ||
      typeStr.contains('Article')) {
    if (metadata['contentType'] == null) {
      metadata['contentType'] = 'article';
      metadata['title'] ??= val('headline') ?? val('name');
      metadata['author'] ??= getAuthor();
      metadata['year'] ??= val('datePublished');
      metadata['image'] ??= getImage();
    }
  }
}

/// Extracts a `<meta property="..." content="...">` value from raw HTML.
String? _extractMeta(String html, String property) {
  final p = RegExp.escape(property);
  final pattern = RegExp(
    '''property=['"]$p['"][^>]*content=['"]([^'"]+)['"]'''
    '''|content=['"]([^'"]+)['"][^>]*property=['"]$p['"]''',
    caseSensitive: false,
  );
  final m = pattern.firstMatch(html);
  return m?.group(1) ?? m?.group(2);
}

/// Extracts the HTML <title> tag content.
String? _extractHtmlTitle(String html) {
  final m = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false).firstMatch(html);
  return m?.group(1)?.trim();
}

/// Infers content type from URL patterns.
String _inferContentType(String url, Map<String, dynamic> metadata) {
  if (url.contains('imdb.com/title/')) return 'movie';
  if (url.contains('youtube.com') || url.contains('youtu.be')) return 'video';
  if (url.contains('spotify.com/album')) return 'album';
  if (url.contains('allrecipes.com')) return 'recipe';
  if (url.contains('goodreads.com') ||
      url.contains('google.com/books') ||
      url.contains('books.google.')) return 'book';
  return 'article';
}
