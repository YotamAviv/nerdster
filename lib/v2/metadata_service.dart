import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/content/content_statement.dart';

class MetadataResult {
  final String? title;
  final String? image;
  final List<String>? images;
  final String? error;

  MetadataResult({this.title, this.image, this.images, this.error});
}

String getFallbackImageUrl(String? url, String? contentType, String? title, {List<String>? tags}) {
  // 1. YouTube
  if (url != null && (url.contains('youtube.com') || url.contains('youtu.be'))) {
    final videoId = _extractYoutubeId(url);
    if (videoId != null) return 'https://img.youtube.com/vi/$videoId/0.jpg';
  }

  // 2. NYT
  if (url != null && (url.contains('nytimes.com'))) {
    return 'https://upload.wikimedia.org/wikipedia/commons/4/40/New_York_Times_logo_variation.jpg';
  }

  // 3. Content Type / Tags
  String keywords;
  if (tags != null && tags.isNotEmpty) {
    keywords = tags.map((t) => t.replaceAll('#', '')).join(',');
  } else {
    // Map known types to better search terms
    switch (contentType?.toLowerCase()) {
      case 'movie':
        keywords = 'movie,film,poster';
        break;
      case 'book':
        keywords = 'book,cover';
        break;
      case 'article':
        keywords = 'news,newspaper,article';
        break;
      case 'video':
        keywords = 'cinema,video';
        break;
      case 'music':
      case 'album':
        keywords = 'music,album,art';
        break;
      default:
        keywords = contentType ?? 'abstract';
    }
  }

  // Deterministic lock based on title or URL
  final lock = (url ?? title ?? '').hashCode;
  return 'https://loremflickr.com/600/600/$keywords?lock=$lock';
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

  // TODO: Improve image relevance. 
  // Currently, we rely on the cloud function to find images. 
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
      images = List<String>.from(retval.data["images"]);
    }

    onResult(MetadataResult(
      title: retval.data["title"],
      image: retval.data["image"],
      images: images,
    ));
  } on FirebaseFunctionsException catch (e) {
    String error = [e.message, if (e.details != null) e.details].join(', ');
    debugPrint('fetchImages error: $error');
    onResult(MetadataResult(error: error));
  } catch (e) {
    debugPrint('fetchImages unexpected error: $e');
    onResult(MetadataResult(error: e.toString()));
  }
}
