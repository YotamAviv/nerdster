export 'package:nerdster/content/content_types.dart';
export 'package:nerdster/content/content_statement.dart';
export 'package:nerdster/oneofus/trust_statement.dart';
export 'package:nerdster/oneofus/jsonish.dart';
export 'package:nerdster/oneofus/keys.dart';
export 'package:nerdster/oneofus/util.dart';
export 'package:nerdster/demotest/test_clock.dart';
export 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
export 'package:nerdster/oneofus/fire_factory.dart';
export 'package:nerdster/app.dart';
export 'package:nerdster/oneofus/prefs.dart';
export 'package:nerdster/demotest/demo_key.dart';

import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/demotest/demo_key.dart';

/// A globally accessible counter for unique test titles
int _testSubjectCount = 0;
int _mockKeyCounter = 0;

/// Generates a mock key (Json map) for testing.
/// 
/// If [label] is provided, uses it as the value. 
/// Otherwise, generates a unique value using a counter.
Json mockKey([String? label]) {
  _mockKeyCounter++;
  return {'kty': 'mock', 'val': label ?? 'key_$_mockKeyCounter'};
}

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
  final String effectiveTitle = title ?? 'Test Title $_testSubjectCount';
  final String effectiveUrl = url ?? 'https://bogus.com/$_testSubjectCount';
  
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

/// Helper to enforce conditions even in release mode.
void check(bool condition, String reason) {
  if (!condition) {
    throw Exception('Verification Failed: $reason');
  }
}

/// Common helper for unit tests to generate a ContentStatement using the official factory.
ContentStatement makeContentStatement({
  required ContentVerb verb,
  required dynamic subject,
  Json? iJson,
  String? comment,
  dynamic other,
  bool? recommend,
  dynamic dismiss,
  bool? censor,
  Json? contexts,
  DateTime? time,
}) {
  final Json json = ContentStatement.make(
    iJson ?? mockKey(),
    verb,
    subject,
    comment: comment,
    other: other,
    recommend: recommend,
    dismiss: dismiss,
    censor: censor,
    contexts: contexts,
  );
  if (time != null) {
    json['time'] = time.toIso8601String();
  }
  return ContentStatement(Jsonish(json));
}

/// Common helper for unit tests to generate a TrustStatement using the official factory.
TrustStatement makeTrustStatement({
  required TrustVerb verb,
  required dynamic subject,
  Json? iJson,
  String? moniker,
  String? revokeAt,
  String? comment,
  String? domain,
  DateTime? time,
}) {
  // Production TrustStatement.make expects other to be a Json (Map).
  // If we have a String (e.g. for a delegate ID in a legacy test), we'll wrap it.
  final Json effectiveSubject = (subject is String) ? mockKey(subject) : (subject as Json);

  final Json json = TrustStatement.make(
    iJson ?? mockKey(),
    effectiveSubject,
    verb,
    moniker: moniker,
    revokeAt: revokeAt,
    comment: comment,
    domain: domain,
  );
  if (time != null) {
    json['time'] = time.toIso8601String();
  }
  return TrustStatement(Jsonish(json));
}

/// Helper to initialize the statement registry for tests.
void setUpTestRegistry({FakeFirebaseFirestore? firestore}) {
  fireChoice = FireChoice.fake;
  final FakeFirebaseFirestore fs = firestore ?? FakeFirebaseFirestore();
  FireFactory.register(kOneofusDomain, fs, null);
  FireFactory.register(kNerdsterDomain, fs, null);
  ContentStatement.init();
  TrustStatement.init();
  useClock(TestClock());
  _mockKeyCounter = 0;
  _testSubjectCount = 0;
  DemoKey.reset();
}
