import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

/// Use Case 1: Establish Subject (Canonicalization)
/// Fetches ONLY the title from a URL to help the user create a canonical subject.
Future<String?> fetchTitle(String url) async {
  if (_functions == null || url.isEmpty) return null;
  if (!url.startsWith('http')) return null;

  try {
    final retval = await _functions!.httpsCallable('fetchTitle').call({
      "url": url,
    });
    return retval.data["title"];
  } catch (e) {
    debugPrint('fetchTitle error: $e');
    return null;
  }
}

/// Fetches high-quality images for a subject to enhance the visual presentation.
Future<void> fetchImages({
  required Map<String, dynamic> subject,
  required Function(MetadataResult result) onResult,
}) async {
  if (_functions == null) {
    debugPrint('MetadataService: Firebase Functions not initialized');
    return;
  }

  // Fail Fast: Ensure we have the required fields for a subject
  assert(subject['contentType'] != null, 'Subject must have a contentType');

  // Basic validation to avoid unnecessary cloud calls
  if (subject.isEmpty) return;

  final cacheKey = subject['url'] ?? subject['title'] ?? subject.toString();
  if (_metadataCache.containsKey(cacheKey)) {
    onResult(_metadataCache[cacheKey]!);
    return;
  }

  // TODO: Improve image relevance.
  // We should explore using more specific search queries (e.g., including author/year)
  // or using specialized APIs (Google Books, TMDB, etc.) based on contentType.

  try {
    debugPrint('MetadataService: Calling fetchImages for ${subject['url'] ?? subject['title']}');
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
