import 'package:nerdster/content/content_types.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

/// A globally accessible counter for unique test titles
int _testSubjectCount = 0;

/// Creates a valid subject Map for testing.
/// 
/// Ensures strict adherence to Subject Integrity rules:
/// - Must have 'contentType'
/// - Must have 'title'
/// - Does not use stubs/tokens.
Map<String, dynamic> createTestSubject({
  ContentType type = ContentType.article,
  String? title,
  String? url,
  int? year,
  String? author,
  String? artist,
  String? location,
}) {
  _testSubjectCount++;
  final effectiveTitle = title ?? 'Test Title $_testSubjectCount';
  final effectiveUrl = url ?? 'https://bogus.com/$_testSubjectCount';
  
  final Map<String, dynamic> subject = {
    'contentType': type.name,
    'title': effectiveTitle,
  };

  switch (type) {
    case ContentType.article:
    case ContentType.video:
    case ContentType.podcast:
    case ContentType.recipe:
    case ContentType.resource:
      subject['url'] = effectiveUrl;
      break;
    case ContentType.book:
      subject['author'] = author ?? 'Test Author';
      break;
    case ContentType.movie:
      subject['year'] = year ?? 2000;
      break;
    case ContentType.album:
      subject['artist'] = artist ?? 'Test Artist';
      subject['year'] = year ?? 2000;
      break;
    case ContentType.event:
      subject['url'] = effectiveUrl;
      subject['location'] = location ?? 'Test Location';
      subject['time'] = '2022-01-01T12:00:00Z';
      break;
  }
  
  return subject;
}
