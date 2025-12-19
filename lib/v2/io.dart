import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';

/// Interface for fetching trust statements.
abstract class StatementSource {
  Future<List<TrustStatement>> fetch(List<String> keys);
}

/// Interface for fetching content statements.
abstract class ContentSource {
  Future<List<ContentStatement>> fetchContent(List<String> keys);
}

/// A source that parses a raw JSON map (Token -> List<StatementJson>).
/// This matches the format of the 'export' Cloud Function.
class MemorySource implements StatementSource, ContentSource {
  final Map<String, List<TrustStatement>> trustData = {};
  final Map<String, List<ContentStatement>> contentData = {};

  MemorySource([Map<String, List<dynamic>>? jsonTrustData]) {
    if (jsonTrustData != null) {
      for (var entry in jsonTrustData.entries) {
        trustData[entry.key] = entry.value.map((json) {
          final jsonish = Jsonish(json);
          return _toTrustStatement(jsonish);
        }).toList();
      }
    }
  }

  // Adapter to convert Jsonish to V2 TrustStatement
  TrustStatement _toTrustStatement(Jsonish jsonish) => toTrustStatement(jsonish);

  @override
  Future<List<TrustStatement>> fetch(List<String> keys) async {
    final List<TrustStatement> results = [];
    for (var key in keys) {
      if (trustData.containsKey(key)) {
        results.addAll(trustData[key]!);
      }
    }
    return results;
  }

  @override
  Future<List<ContentStatement>> fetchContent(List<String> keys) async {
    final List<ContentStatement> results = [];
    for (var key in keys) {
      if (contentData.containsKey(key)) {
        results.addAll(contentData[key]!);
      }
    }
    return results;
  }
}

// Public Adapters
TrustStatement toTrustStatement(Jsonish jsonish) {
  return TrustStatement(jsonish);
}

ContentStatement toContentStatement(Jsonish jsonish) {
  return ContentStatement(jsonish);
}
