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

final FirebaseFunctions? _functions = FireFactory.findFunctions(kNerdsterDomain);

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
  if (_functions == null) return;
  
  // Fail Fast: Ensure we have the required fields for a subject
  assert(subject['contentType'] != null, 'Subject must have a contentType');
  
  // Basic validation to avoid unnecessary cloud calls
  if (subject.isEmpty) return;

  try {
    final retval = await _functions!.httpsCallable('fetchImages').call({
      "subject": subject,
    });

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
